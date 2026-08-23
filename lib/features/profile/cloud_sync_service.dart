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
