import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';
import '../../shared/storage/app_local_storage.dart';
import 'profile_goals_store.dart';

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

class CloudSyncResult {
  const CloudSyncResult({
    required this.foods,
    required this.stateUploaded,
    required this.stateDownloaded,
    required this.stateMerged,
  });

  final CustomFoodSyncResult foods;
  final bool stateUploaded;
  final bool stateDownloaded;
  final bool stateMerged;
}

class _StateSyncResult {
  const _StateSyncResult({
    this.uploaded = false,
    this.downloaded = false,
    this.merged = false,
  });

  final bool uploaded;
  final bool downloaded;
  final bool merged;
}

class CloudSyncService {
  CloudSyncService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static bool get isSignedIn => currentUser != null;

  static const _syncMetaKey = 'cloud_sync_meta_v2';

  static AppState? _automaticState;
  static StreamSubscription<AuthState>? _authSubscription;
  static Timer? _debounceTimer;
  static Timer? _pollTimer;
  static bool _automaticSyncRunning = false;
  static bool _automaticSyncPending = false;
  static bool _applyingRemoteState = false;
  static String _lastObservedCombinedFingerprint = '';

  static bool _metaLoaded = false;
  static String? _metaUserId;
  static int? _lastCloudRevision;
  static String _lastSyncedStateFingerprint = '';

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

  /// Starts automatic cross-device sync for the currently loaded AppState.
  ///
  /// Local changes are uploaded after a short debounce. Remote changes are
  /// checked on app start, auth changes, app resume, and once per minute.
  /// Local SharedPreferences remain the offline copy and are never cleared by
  /// the sync layer.
  static void startAutomaticSync(AppState state) {
    if (identical(_automaticState, state)) {
      syncAutomaticallyNow();
      return;
    }

    stopAutomaticSync();
    _automaticState = state;
    _lastObservedCombinedFingerprint = _combinedFingerprint(state);
    state.addListener(_handleLocalStateChanged);

    _authSubscription = _client.auth.onAuthStateChange.listen((authState) {
      final userId = authState.session?.user.id;
      if (userId == null) {
        _debounceTimer?.cancel();
        _automaticSyncPending = false;
        _resetLoadedMeta();
        return;
      }
      if (_metaUserId != null && _metaUserId != userId) {
        _resetLoadedMeta();
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
    _lastObservedCombinedFingerprint = '';
  }

  /// Requests an immediate background refresh without surfacing an error dialog.
  static void syncAutomaticallyNow() {
    _scheduleAutomaticSync(immediate: true);
  }

  static void _handleLocalStateChanged() {
    if (_applyingRemoteState) return;
    final state = _automaticState;
    if (state == null) return;
    final fingerprint = _combinedFingerprint(state);
    if (fingerprint == _lastObservedCombinedFingerprint) return;
    _lastObservedCombinedFingerprint = fingerprint;
    _scheduleAutomaticSync();
  }

  static String _combinedFingerprint(AppState state) =>
      jsonEncode(_canonicalize({
        'foods': state.customFoods
            .map((food) => <String, dynamic>{
                  'id': food.id,
                  'payload': food.toJson(),
                })
            .toList()
          ..sort((a, b) =>
              (a['id'] as String).compareTo(b['id'] as String)),
        'state': state.exportCloudSyncState(),
      }));

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
      await syncAllNow(state);
      _lastObservedCombinedFingerprint = _combinedFingerprint(state);
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

  /// Full sync used by both automatic sync and the optional manual refresh.
  static Future<CloudSyncResult> syncAllNow(AppState state) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('cloud_sync_requires_sign_in');
    }

    await _loadMetaForUser(user.id);
    // App-state sync runs first so that a custom-food deletion tombstone
    // recorded on another device (carried inside the app-state snapshot,
    // see `deletedCustomFoodIds`) is merged in locally before we decide
    // which custom foods to download below — otherwise a food deleted on
    // device A could still be re-downloaded by device B for one more cycle.
    final stateResult = await _syncAppState(state, user.id);
    final foods = await syncCustomFoods(state);

    return CloudSyncResult(
      foods: foods,
      stateUploaded: stateResult.uploaded,
      stateDownloaded: stateResult.downloaded,
      stateMerged: stateResult.merged,
    );
  }

  static Future<Map<String, dynamic>> _buildStatePayload(AppState state) async {
    final payload = Map<String, dynamic>.from(state.exportCloudSyncState());
    payload['selectedGoals'] = await ProfileGoalsStore.load(
      fallbackGoal: state.primaryGoal,
    );
    return payload;
  }

  static String _stateFingerprint(Map<String, dynamic> payload) =>
      jsonEncode(_canonicalize(payload));

  static dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final entries = value.entries
          .map((entry) => MapEntry(entry.key.toString(), entry.value))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return <String, dynamic>{
        for (final entry in entries) entry.key: _canonicalize(entry.value),
      };
    }
    if (value is List) {
      return value.map(_canonicalize).toList();
    }
    return value;
  }

  static Future<_StateSyncResult> _syncAppState(
    AppState state,
    String userId,
  ) async {
    final localPayload = await _buildStatePayload(state);
    final localFingerprint = _stateFingerprint(localPayload);

    final rawRemote = await _client
        .from('user_app_state')
        .select('payload,revision,updated_at')
        .eq('user_id', userId)
        .maybeSingle();

    if (rawRemote == null) {
      final saved = await _writeStateRow(userId, localPayload);
      await _rememberSyncedState(
        userId: userId,
        revision: saved.$1,
        fingerprint: localFingerprint,
      );
      return const _StateSyncResult(uploaded: true);
    }

    final remoteRow = Map<String, dynamic>.from(rawRemote);
    final remoteRevision = (remoteRow['revision'] as num?)?.toInt() ?? 1;
    final remotePayloadRaw = remoteRow['payload'];
    final remotePayload = remotePayloadRaw is Map
        ? Map<String, dynamic>.from(remotePayloadRaw)
        : <String, dynamic>{};
    final remoteFingerprint = _stateFingerprint(remotePayload);

    // First use on this browser/device: the existing cloud profile is the
    // canonical profile, while list-like legacy local data is unioned so old
    // meals/pantry/shopping entries are not silently thrown away.
    if (_lastCloudRevision == null || _lastSyncedStateFingerprint.isEmpty) {
      final merged = _mergeInitialPayloads(remotePayload, localPayload);
      final mergedFingerprint = _stateFingerprint(merged);
      if (mergedFingerprint != remoteFingerprint) {
        await _applyRemotePayload(state, merged);
        final saved = await _writeStateRow(userId, merged);
        await _rememberSyncedState(
          userId: userId,
          revision: saved.$1,
          fingerprint: mergedFingerprint,
        );
        return const _StateSyncResult(
          uploaded: true,
          downloaded: true,
          merged: true,
        );
      }

      await _applyRemotePayload(state, remotePayload);
      await _rememberSyncedState(
        userId: userId,
        revision: remoteRevision,
        fingerprint: remoteFingerprint,
      );
      return const _StateSyncResult(downloaded: true);
    }

    final localChanged = localFingerprint != _lastSyncedStateFingerprint;
    final remoteChanged = remoteRevision != _lastCloudRevision;

    if (localChanged && remoteChanged) {
      final merged = _mergeConcurrentPayloads(remotePayload, localPayload);
      final mergedFingerprint = _stateFingerprint(merged);
      await _applyRemotePayload(state, merged);
      final saved = await _writeStateRow(userId, merged);
      await _rememberSyncedState(
        userId: userId,
        revision: saved.$1,
        fingerprint: mergedFingerprint,
      );
      return const _StateSyncResult(
        uploaded: true,
        downloaded: true,
        merged: true,
      );
    }

    if (localChanged) {
      final saved = await _writeStateRow(userId, localPayload);
      await _rememberSyncedState(
        userId: userId,
        revision: saved.$1,
        fingerprint: localFingerprint,
      );
      return const _StateSyncResult(uploaded: true);
    }

    if (remoteChanged) {
      await _applyRemotePayload(state, remotePayload);
      await _rememberSyncedState(
        userId: userId,
        revision: remoteRevision,
        fingerprint: remoteFingerprint,
      );
      return const _StateSyncResult(downloaded: true);
    }

    return const _StateSyncResult();
  }

  static Future<(int, Map<String, dynamic>)> _writeStateRow(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final raw = await _client
        .from('user_app_state')
        .upsert(
          {
            'user_id': userId,
            'payload': payload,
          },
          onConflict: 'user_id',
        )
        .select('payload,revision,updated_at')
        .single();
    final row = Map<String, dynamic>.from(raw);
    return (
      (row['revision'] as num?)?.toInt() ?? 1,
      row,
    );
  }

  static Future<void> _applyRemotePayload(
    AppState state,
    Map<String, dynamic> payload,
  ) async {
    _applyingRemoteState = true;
    try {
      final goalsRaw = payload['selectedGoals'];
      if (goalsRaw is List) {
        final goals = goalsRaw
            .whereType<String>()
            .where(ProfileGoalsStore.options.contains)
            .toList();
        if (goals.isNotEmpty) {
          await ProfileGoalsStore.save(goals);
        }
      }
      await state.applyCloudSyncState(payload);
    } finally {
      _applyingRemoteState = false;
      _lastObservedCombinedFingerprint = _combinedFingerprint(state);
    }
  }

  static Map<String, dynamic> _mergeInitialPayloads(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) {
    final merged = Map<String, dynamic>.from(remote);
    merged['version'] = 1;
    // Existing cloud profile/goals win on a newly connected device.
    merged['profile'] = remote['profile'] ?? local['profile'];
    merged['selectedGoals'] =
        remote['selectedGoals'] ?? local['selectedGoals'];

    final deletedPantryIds = _mergeTombstoneMaps(
      remote['deletedPantryItemIds'],
      local['deletedPantryItemIds'],
    );
    final deletedShoppingIds = _mergeTombstoneMaps(
      remote['deletedShoppingItemIds'],
      local['deletedShoppingItemIds'],
    );
    final deletedMeals = _mergeTombstoneMaps(
      remote['deletedMealKeys'],
      local['deletedMealKeys'],
    );
    final deletedCustomFoods = _mergeTombstoneMaps(
      remote['deletedCustomFoodIds'],
      local['deletedCustomFoodIds'],
    );

    merged['weights'] = _mergeListByKey(
      remote['weights'],
      local['weights'],
      _weightKey,
      preferLocal: false,
    );
    merged['meals'] = _mergeListByKey(
      remote['meals'],
      local['meals'],
      _mealKey,
      preferLocal: false,
      deletedKeys: deletedMeals.keys.toSet(),
    );
    merged['pantryItems'] = _mergeListByKey(
      remote['pantryItems'],
      local['pantryItems'],
      _idKey,
      preferLocal: false,
      deletedKeys: deletedPantryIds.keys.toSet(),
    );
    merged['shoppingItems'] = _mergeListByKey(
      remote['shoppingItems'],
      local['shoppingItems'],
      _idKey,
      preferLocal: false,
      deletedKeys: deletedShoppingIds.keys.toSet(),
    );
    merged['shoppingChecked'] = _mergeBoolMaps(
      local['shoppingChecked'],
      remote['shoppingChecked'],
    );
    merged['shoppingInitialized'] =
        remote['shoppingInitialized'] == true ||
            local['shoppingInitialized'] == true;
    merged['deletedPantryItemIds'] = deletedPantryIds;
    merged['deletedShoppingItemIds'] = deletedShoppingIds;
    merged['deletedMealKeys'] = deletedMeals;
    merged['deletedCustomFoodIds'] = deletedCustomFoods;
    return merged;
  }

  static Map<String, dynamic> _mergeConcurrentPayloads(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) {
    final merged = Map<String, dynamic>.from(remote);
    merged['version'] = 1;
    // If this device also changed since its last successful sync, its profile
    // edit is treated as the user's latest local intent.
    merged['profile'] = local['profile'] ?? remote['profile'];
    merged['selectedGoals'] =
        local['selectedGoals'] ?? remote['selectedGoals'];

    final deletedPantryIds = _mergeTombstoneMaps(
      remote['deletedPantryItemIds'],
      local['deletedPantryItemIds'],
    );
    final deletedShoppingIds = _mergeTombstoneMaps(
      remote['deletedShoppingItemIds'],
      local['deletedShoppingItemIds'],
    );
    final deletedMeals = _mergeTombstoneMaps(
      remote['deletedMealKeys'],
      local['deletedMealKeys'],
    );
    final deletedCustomFoods = _mergeTombstoneMaps(
      remote['deletedCustomFoodIds'],
      local['deletedCustomFoodIds'],
    );

    merged['weights'] = _mergeListByKey(
      remote['weights'],
      local['weights'],
      _weightKey,
      preferLocal: true,
    );
    merged['meals'] = _mergeListByKey(
      remote['meals'],
      local['meals'],
      _mealKey,
      preferLocal: true,
      deletedKeys: deletedMeals.keys.toSet(),
    );
    merged['pantryItems'] = _mergeListByKey(
      remote['pantryItems'],
      local['pantryItems'],
      _idKey,
      preferLocal: true,
      deletedKeys: deletedPantryIds.keys.toSet(),
    );
    merged['shoppingItems'] = _mergeListByKey(
      remote['shoppingItems'],
      local['shoppingItems'],
      _idKey,
      preferLocal: true,
      deletedKeys: deletedShoppingIds.keys.toSet(),
    );
    merged['shoppingChecked'] = _mergeBoolMaps(
      remote['shoppingChecked'],
      local['shoppingChecked'],
    );
    merged['shoppingInitialized'] =
        remote['shoppingInitialized'] == true ||
            local['shoppingInitialized'] == true;
    merged['deletedPantryItemIds'] = deletedPantryIds;
    merged['deletedShoppingItemIds'] = deletedShoppingIds;
    merged['deletedMealKeys'] = deletedMeals;
    merged['deletedCustomFoodIds'] = deletedCustomFoods;
    return merged;
  }

  /// Unions two `{key: isoDateString}` tombstone maps, keeping the later
  /// (most recent) timestamp when a key appears on both sides. This is what
  /// lets a deletion made on one device survive being merged with a device
  /// that hasn't seen it yet, instead of the union-by-key list merge quietly
  /// bringing the deleted item back.
  static Map<String, String> _mergeTombstoneMaps(
    dynamic remoteRaw,
    dynamic localRaw,
  ) {
    final result = <String, DateTime>{};
    for (final raw in [remoteRaw, localRaw]) {
      if (raw is! Map) continue;
      for (final entry in raw.entries) {
        final parsed = DateTime.tryParse(entry.value?.toString() ?? '');
        if (parsed == null) continue;
        final key = entry.key.toString();
        final existing = result[key];
        if (existing == null || parsed.isAfter(existing)) {
          result[key] = parsed;
        }
      }
    }
    return result.map((key, value) => MapEntry(key, value.toIso8601String()));
  }

  static List<Map<String, dynamic>> _mergeListByKey(
    dynamic firstRaw,
    dynamic secondRaw,
    String Function(Map<String, dynamic>) keyOf, {
    required bool preferLocal,
    Set<String> deletedKeys = const {},
  }) {
    final first = _mapList(firstRaw);
    final second = _mapList(secondRaw);
    final byKey = <String, Map<String, dynamic>>{};
    for (final item in first) {
      final key = keyOf(item);
      if (deletedKeys.contains(key)) continue;
      byKey[key] = item;
    }
    for (final item in second) {
      final key = keyOf(item);
      if (deletedKeys.contains(key)) continue;
      if (preferLocal || !byKey.containsKey(key)) {
        byKey[key] = item;
      }
    }
    return byKey.values.toList();
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String _idKey(Map<String, dynamic> item) {
    final id = item['id']?.toString().trim() ?? '';
    return id.isNotEmpty ? id : jsonEncode(_canonicalize(item));
  }

  static String _weightKey(Map<String, dynamic> item) => jsonEncode({
        'date': item['date'],
        'weight': item['weight'],
      });

  static String _mealKey(Map<String, dynamic> item) => jsonEncode({
        'foodId': item['foodId'],
        'name': item['name'],
        'quantity': item['quantity'],
        'unit': item['unit'],
        'grams': item['grams'],
        'time': item['time'],
      });

  static Map<String, bool> _mergeBoolMaps(dynamic firstRaw, dynamic secondRaw) {
    final result = <String, bool>{};
    if (firstRaw is Map) {
      for (final entry in firstRaw.entries) {
        result[entry.key.toString()] = entry.value == true;
      }
    }
    if (secondRaw is Map) {
      for (final entry in secondRaw.entries) {
        result[entry.key.toString()] = entry.value == true;
      }
    }
    return result;
  }

  static Future<void> _loadMetaForUser(String userId) async {
    if (_metaLoaded && _metaUserId == userId) return;
    _resetLoadedMeta();
    _metaLoaded = true;
    _metaUserId = userId;

    final raw = await AppLocalStorage.readString(_syncMetaKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      if (data['userId'] != userId) return;
      _lastCloudRevision = (data['revision'] as num?)?.toInt();
      _lastSyncedStateFingerprint =
          data['stateFingerprint'] as String? ?? '';
    } catch (_) {
      // A broken sync marker never blocks local app data or cloud sync.
    }
  }

  static Future<void> _rememberSyncedState({
    required String userId,
    required int revision,
    required String fingerprint,
  }) async {
    _metaLoaded = true;
    _metaUserId = userId;
    _lastCloudRevision = revision;
    _lastSyncedStateFingerprint = fingerprint;
    await AppLocalStorage.writeString(
      _syncMetaKey,
      jsonEncode({
        'userId': userId,
        'revision': revision,
        'stateFingerprint': fingerprint,
      }),
    );
  }

  static void _resetLoadedMeta() {
    _metaLoaded = false;
    _metaUserId = null;
    _lastCloudRevision = null;
    _lastSyncedStateFingerprint = '';
  }

  /// User-created food sync. New items sync as a simple union; deletions are
  /// tracked as tombstones (see `state.deletedCustomFoodIds`); and — the part
  /// that used to be missing — **edits to an existing food now sync too**,
  /// resolved by last-writer-wins using `state.customFoodUpdatedAt` (local
  /// edit times) against each row's own `updated_at` column (cloud edit
  /// times). Previously an id present on both sides was never touched again
  /// after its first sync, so an edit on one device silently never reached
  /// the other. See PROJECT_BRIEF.md section 6.3.
  static Future<CustomFoodSyncResult> syncCustomFoods(AppState state) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('cloud_sync_requires_sign_in');
    }

    final localBeforeSync = List<FoodItem>.from(state.customFoods);
    final deletedIds = state.deletedCustomFoodIds.keys.toSet();
    final response = await _client
        .from('user_custom_foods')
        .select('food_id,payload,updated_at');

    final cloudById = <String, FoodItem>{};
    final cloudUpdatedAt = <String, DateTime>{};
    for (final raw in response) {
      final row = Map<String, dynamic>.from(raw as Map);
      final payload = row['payload'];
      if (payload is! Map) continue;
      try {
        final food = FoodItem.fromJson(Map<String, dynamic>.from(payload));
        if (food.id.trim().isNotEmpty) {
          cloudById[food.id] = food;
          final ts = DateTime.tryParse(row['updated_at']?.toString() ?? '');
          if (ts != null) cloudUpdatedAt[food.id] = ts;
        }
      } catch (_) {
        // Ignore one malformed remote row rather than blocking all sync.
      }
    }

    final localById = {for (final food in localBeforeSync) food.id: food};
    var downloaded = 0;
    var edited = 0;
    _applyingRemoteState = true;
    try {
      for (final entry in cloudById.entries) {
        final id = entry.key;
        // Don't resurrect a food this device (or another, via the merged
        // tombstone set) has already deleted.
        if (deletedIds.contains(id)) continue;

        final remoteTs = cloudUpdatedAt[id];
        if (!localById.containsKey(id)) {
          // New to this device.
          state.applyRemoteCustomFood(
            entry.value,
            remoteTs ?? DateTime.now().toUtc(),
          );
          downloaded++;
          continue;
        }

        // Present on both sides: only overwrite the local copy if the cloud
        // row is genuinely newer than what we last edited or last pulled.
        // A never-tracked local timestamp (food synced before this fix
        // shipped) is treated as older than any cloud timestamp, so it
        // reconciles once and is tracked normally from then on.
        final localTs = state.customFoodUpdatedAt[id];
        if (remoteTs != null &&
            (localTs == null || remoteTs.isAfter(localTs))) {
          state.applyRemoteCustomFood(entry.value, remoteTs);
          edited++;
        }
      }
    } finally {
      _applyingRemoteState = false;
    }

    final uploads = <Map<String, dynamic>>[];
    for (final food in localBeforeSync) {
      final id = food.id;
      final remoteTs = cloudUpdatedAt[id];
      final localTs = state.customFoodUpdatedAt[id];
      final isNewToCloud = !cloudById.containsKey(id);
      // Push when the cloud doesn't have it yet, or when our local edit is
      // strictly newer than the cloud row (the mirror image of the pull
      // check above — never push a local copy we just overwrote from cloud).
      final localIsNewer =
          !isNewToCloud && localTs != null && (remoteTs == null || localTs.isAfter(remoteTs));
      if (!isNewToCloud && !localIsNewer) continue;

      uploads.add({
        'user_id': user.id,
        'food_id': id,
        'payload': food.toJson(),
        'updated_at':
            (localTs ?? DateTime.now().toUtc()).toIso8601String(),
      });
    }

    if (uploads.isNotEmpty) {
      await _client.from('user_custom_foods').upsert(
            uploads,
            onConflict: 'user_id,food_id',
          );
    }

    // Propagate local deletions to the cloud row itself, so the table
    // doesn't accumulate rows that every device has already tombstoned.
    // This is a cleanup step, not the correctness mechanism — the tombstone
    // map above is what actually prevents resurrection, so a failure here
    // (offline, RLS, etc.) is safe to ignore and retry on the next sync.
    final idsToDeleteFromCloud =
        deletedIds.where(cloudById.containsKey).toList();
    if (idsToDeleteFromCloud.isNotEmpty) {
      try {
        await _client
            .from('user_custom_foods')
            .delete()
            .eq('user_id', user.id)
            .inFilter('food_id', idsToDeleteFromCloud);
        for (final id in idsToDeleteFromCloud) {
          cloudById.remove(id);
        }
      } catch (_) {
        // Leave the tombstone in place; it still blocks re-download above,
        // and we'll retry the cloud cleanup on the next sync.
      }
    }

    final totalIds = <String>{
      ...cloudById.keys,
      ...localBeforeSync.map((food) => food.id),
    };

    return CustomFoodSyncResult(
      uploaded: uploads.length,
      downloaded: downloaded + edited,
      total: totalIds.length,
    );
  }
}
