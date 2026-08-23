import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';

class CustomFoodSyncResult {
  const CustomFoodSyncResult({
    required this.uploaded,
    required this.downloaded,
    required this.total,
  });

  final int uploaded;
  final int downloaded;
  final int total;
}

class CloudSyncService {
  CloudSyncService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static bool get isSignedIn => currentUser != null;

  static AppState? _automaticState;
  static StreamSubscription<AuthState>? _authSubscription;
  static Timer? _debounceTimer;
  static Timer? _pollTimer;
  static bool _automaticSyncRunning = false;
  static bool _automaticSyncPending = false;
  static String _lastObservedFoodFingerprint = '';

  static String? get _emailRedirectTo {
    if (!kIsWeb) return null;
    final uri = Uri.base;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri.origin;
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _emailRedirectTo,
      );

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  static Future<void> signOut() => _client.auth.signOut();

  /// Starts background sync for the currently loaded AppState.
  ///
  /// Sync runs when the app starts with an existing session, after auth changes,
  /// shortly after custom foods change locally, once per minute while the app is
  /// open, and whenever the app is resumed. Failures stay silent and preserve the
  /// local copy; the next automatic attempt retries.
  static void startAutomaticSync(AppState state) {
    if (identical(_automaticState, state)) {
      syncAutomaticallyNow();
      return;
    }

    stopAutomaticSync();
    _automaticState = state;
    _lastObservedFoodFingerprint = _foodFingerprint(state);
    state.addListener(_handleLocalStateChanged);

    _authSubscription = _client.auth.onAuthStateChange.listen((authState) {
      if (authState.session == null) {
        _debounceTimer?.cancel();
        _automaticSyncPending = false;
        return;
      }
      _scheduleAutomaticSync(immediate: true);
    });

    _pollTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _scheduleAutomaticSync(immediate: true),
    );

    if (isSignedIn) {
      _scheduleAutomaticSync(immediate: true);
    }
  }

  static void stopAutomaticSync() {
    final state = _automaticState;
    if (state != null) {
      state.removeListener(_handleLocalStateChanged);
    }
    _automaticState = null;
    _authSubscription?.cancel();
    _authSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _automaticSyncPending = false;
    _lastObservedFoodFingerprint = '';
  }

  /// Requests an immediate background sync without surfacing an error dialog.
  static void syncAutomaticallyNow() {
    _scheduleAutomaticSync(immediate: true);
  }

  static void _handleLocalStateChanged() {
    final state = _automaticState;
    if (state == null) return;
    final fingerprint = _foodFingerprint(state);
    if (fingerprint == _lastObservedFoodFingerprint) return;
    _lastObservedFoodFingerprint = fingerprint;
    _scheduleAutomaticSync();
  }

  static String _foodFingerprint(AppState state) {
    final foods = state.customFoods
        .map((food) => <String, dynamic>{
              'id': food.id,
              'payload': food.toJson(),
            })
        .toList()
      ..sort((a, b) =>
          (a['id'] as String).compareTo(b['id'] as String));
    return jsonEncode(foods);
  }

  static void _scheduleAutomaticSync({bool immediate = false}) {
    if (_automaticState == null || !isSignedIn) return;

    _debounceTimer?.cancel();
    if (immediate) {
      unawaited(_runAutomaticSync());
      return;
    }

    _debounceTimer = Timer(
      const Duration(milliseconds: 900),
      () => unawaited(_runAutomaticSync()),
    );
  }

  static Future<void> _runAutomaticSync() async {
    final state = _automaticState;
    if (state == null || !isSignedIn) return;

    if (_automaticSyncRunning) {
      _automaticSyncPending = true;
      return;
    }

    _automaticSyncRunning = true;
    try {
      await syncCustomFoods(state);
      _lastObservedFoodFingerprint = _foodFingerprint(state);
    } catch (error, stack) {
      debugPrint('CloudSyncService: automatic sync failed: $error');
      debugPrintStack(stackTrace: stack);
    } finally {
      _automaticSyncRunning = false;
      if (_automaticSyncPending) {
        _automaticSyncPending = false;
        _scheduleAutomaticSync(immediate: true);
      }
    }
  }

  /// First cloud-sync stage: safely unions user-created foods across devices.
  ///
  /// Existing cloud rows are treated as authoritative when the same food id
  /// already exists on both sides. New local ids are uploaded, and cloud ids
  /// missing locally are added to the local AppState. This deliberately avoids
  /// destructive conflict resolution until per-food edit timestamps are added.
  static Future<CustomFoodSyncResult> syncCustomFoods(AppState state) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('cloud_sync_requires_sign_in');
    }

    final localBeforeSync = List<FoodItem>.from(state.customFoods);
    final response = await _client
        .from('user_custom_foods')
        .select('food_id,payload,updated_at');

    final cloudById = <String, FoodItem>{};
    for (final raw in response) {
      final row = Map<String, dynamic>.from(raw as Map);
      final payload = row['payload'];
      if (payload is! Map) continue;
      try {
        final food = FoodItem.fromJson(Map<String, dynamic>.from(payload));
        if (food.id.trim().isNotEmpty) {
          cloudById[food.id] = food;
        }
      } catch (_) {
        // Ignore one malformed remote row rather than blocking all sync.
      }
    }

    final localIds = localBeforeSync.map((food) => food.id).toSet();
    var downloaded = 0;
    for (final entry in cloudById.entries) {
      if (localIds.contains(entry.key)) continue;
      state.addCustomFood(entry.value);
      downloaded++;
    }

    final uploads = <Map<String, dynamic>>[];
    for (final food in localBeforeSync) {
      if (cloudById.containsKey(food.id)) continue;
      uploads.add({
        'user_id': user.id,
        'food_id': food.id,
        'payload': food.toJson(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    if (uploads.isNotEmpty) {
      await _client.from('user_custom_foods').upsert(
            uploads,
            onConflict: 'user_id,food_id',
          );
    }

    final totalIds = <String>{
      ...cloudById.keys,
      ...localBeforeSync.map((food) => food.id),
    };

    return CustomFoodSyncResult(
      uploaded: uploads.length,
      downloaded: downloaded,
      total: totalIds.length,
    );
  }
}
