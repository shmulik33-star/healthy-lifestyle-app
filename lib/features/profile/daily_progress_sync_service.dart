import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/app_state.dart';

/// Conflict-safe automatic sync for daily counters.
///
/// Water, steps and workout completion are monotonic within a logical day, so
/// the server and client merge with max/max/OR instead of letting one device
/// overwrite progress recorded on another device.
class DailyProgressSyncService {
  DailyProgressSyncService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static AppState? _state;
  static StreamSubscription<AuthState>? _authSubscription;
  static Timer? _debounceTimer;
  static Timer? _pollTimer;
  static bool _running = false;
  static bool _pending = false;
  static bool _applyingRemote = false;
  static String _lastFingerprint = '';

  static bool get _isSignedIn => _client.auth.currentUser != null;

  static void startAutomaticSync(AppState state) {
    if (identical(_state, state)) {
      syncAutomaticallyNow();
      return;
    }

    stopAutomaticSync();
    _state = state;
    _lastFingerprint = _fingerprint(state);
    state.addListener(_handleStateChanged);

    _authSubscription = _client.auth.onAuthStateChange.listen((authState) {
      if (authState.session == null) {
        _debounceTimer?.cancel();
        _pending = false;
        return;
      }
      _schedule(immediate: true);
    });

    _pollTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _schedule(immediate: true),
    );

    if (_isSignedIn) {
      _schedule(immediate: true);
    }
  }

  static void stopAutomaticSync() {
    final state = _state;
    if (state != null) {
      state.removeListener(_handleStateChanged);
    }
    _state = null;
    _authSubscription?.cancel();
    _authSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _pending = false;
    _lastFingerprint = '';
  }

  static void syncAutomaticallyNow() {
    _schedule(immediate: true);
  }

  static void _handleStateChanged() {
    if (_applyingRemote) return;
    final state = _state;
    if (state == null) return;
    final fingerprint = _fingerprint(state);
    if (fingerprint == _lastFingerprint) return;
    _lastFingerprint = fingerprint;
    _schedule();
  }

  static String _fingerprint(AppState state) =>
      jsonEncode(state.exportDailyProgressForCloud());

  static void _schedule({bool immediate = false}) {
    if (_state == null || !_isSignedIn) return;
    _debounceTimer?.cancel();
    if (immediate) {
      unawaited(_runAutomaticSync());
      return;
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_runAutomaticSync()),
    );
  }

  static Future<void> _runAutomaticSync() async {
    if (_state == null || !_isSignedIn) return;
    if (_running) {
      _pending = true;
      return;
    }

    _running = true;
    try {
      await syncNow();
    } catch (error, stack) {
      debugPrint('DailyProgressSyncService: automatic sync failed: $error');
      debugPrintStack(stackTrace: stack);
    } finally {
      _running = false;
      if (_pending) {
        _pending = false;
        _schedule(immediate: true);
      }
    }
  }

  static Future<void> syncNow() async {
    final state = _state;
    final user = _client.auth.currentUser;
    if (state == null || user == null) return;

    final response = await _client
        .from('user_daily_progress')
        .select('day_key,water_cups,steps,workout_completed');

    final remoteByDay = <String, Map<String, dynamic>>{};
    for (final raw in response) {
      final row = Map<String, dynamic>.from(raw as Map);
      final dayKey = row['day_key']?.toString() ?? '';
      if (dayKey.isNotEmpty) remoteByDay[dayKey] = row;
    }

    final localRows = state.exportDailyProgressForCloud();
    for (final local in localRows) {
      final dayKey = local['dayKey']?.toString() ?? '';
      if (dayKey.isEmpty) continue;
      final remote = remoteByDay[dayKey];
      final localWater = (local['waterCups'] as num?)?.toInt() ?? 0;
      final localSteps = (local['steps'] as num?)?.toInt() ?? 0;
      final localWorkout = local['workoutCompleted'] == true;
      final remoteWater = (remote?['water_cups'] as num?)?.toInt() ?? 0;
      final remoteSteps = (remote?['steps'] as num?)?.toInt() ?? 0;
      final remoteWorkout = remote?['workout_completed'] == true;

      if (remote == null ||
          localWater > remoteWater ||
          localSteps > remoteSteps ||
          (localWorkout && !remoteWorkout)) {
        await _client.rpc(
          'merge_user_daily_progress',
          params: {
            'p_day_key': dayKey,
            'p_water_cups': localWater,
            'p_steps': localSteps,
            'p_workout_completed': localWorkout,
          },
        );
      }
    }

    final mergedByDay = <String, Map<String, dynamic>>{};
    for (final remote in remoteByDay.values) {
      final dayKey = remote['day_key']?.toString() ?? '';
      if (dayKey.isEmpty) continue;
      mergedByDay[dayKey] = {
        'dayKey': dayKey,
        'waterCups': (remote['water_cups'] as num?)?.toInt() ?? 0,
        'steps': (remote['steps'] as num?)?.toInt() ?? 0,
        'workoutCompleted': remote['workout_completed'] == true,
      };
    }

    for (final local in localRows) {
      final dayKey = local['dayKey']?.toString() ?? '';
      if (dayKey.isEmpty) continue;
      final existing = mergedByDay[dayKey];
      if (existing == null) {
        mergedByDay[dayKey] = Map<String, dynamic>.from(local);
        continue;
      }
      final localWater = (local['waterCups'] as num?)?.toInt() ?? 0;
      final localSteps = (local['steps'] as num?)?.toInt() ?? 0;
      final existingWater = (existing['waterCups'] as num?)?.toInt() ?? 0;
      final existingSteps = (existing['steps'] as num?)?.toInt() ?? 0;
      existing['waterCups'] =
          localWater > existingWater ? localWater : existingWater;
      existing['steps'] = localSteps > existingSteps ? localSteps : existingSteps;
      existing['workoutCompleted'] =
          existing['workoutCompleted'] == true || local['workoutCompleted'] == true;
    }

    final merged = mergedByDay.values.toList()
      ..sort((a, b) =>
          (a['dayKey'] as String).compareTo(b['dayKey'] as String));

    _applyingRemote = true;
    try {
      await state.applyDailyProgressFromCloud(merged);
    } finally {
      _applyingRemote = false;
      _lastFingerprint = _fingerprint(state);
    }
  }
}
