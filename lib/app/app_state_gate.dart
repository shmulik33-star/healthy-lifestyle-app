import 'dart:async';
import 'package:flutter/material.dart';

import '../features/equipment/equipment_item.dart';
import '../features/profile/cloud_sync_service.dart';
import '../features/profile/daily_progress_sync_service.dart';
import '../shared/models/app_state.dart';
import 'root_messenger.dart';

/// Loads AppState and starts its background services (cloud sync, the
/// day-boundary timer, the water-reminder timer) once, before anything
/// that needs `AppStateScope.of(context)` renders -- shows a loading
/// spinner until then. Split out from the old AppShell (which used to own
/// both this loading and the tab/bottom-nav UI) so it can wrap the whole
/// go_router `MaterialApp.router` tree via the app's `builder:`, the same
/// place Directionality is applied -- every route, not just the tab
/// screens, needs AppState to be ready. This file's actual loading/timer
/// logic is unchanged from the old AppShell, just relocated.
class AppStateGate extends StatefulWidget {
  const AppStateGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppStateGate> createState() => _AppStateGateState();
}

class _AppStateGateState extends State<AppStateGate> with WidgetsBindingObserver {
  AppState? state;
  Timer? _dayBoundaryTimer;
  Timer? _waterReminderTimer;
  // Tracks the last waterReminderMinutes we scheduled a Timer for, so the
  // AppState.notifyListeners() that fires on every unrelated state change
  // (a meal logged, a cup of water added, ...) doesn't reset/restart this
  // timer every single time -- only an actual change to the setting itself
  // (edited in ProfileScreen) should reschedule it.
  int? _lastWaterReminderMinutes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppState.load().then((loaded) async {
      if (!mounted) return;
      loaded.ensureCurrentDay();
      // One-time import of equipment saved before it moved onto AppState
      // (see PROJECT_BRIEF.md section 6.6). Must run before automatic sync
      // starts so a first-time migration on this device is included in the
      // very first sync round instead of waiting a cycle.
      final legacyEquipment = await EquipmentStore.load();
      if (!mounted) return;
      loaded.migrateLegacyCustomEquipment(legacyEquipment);
      CloudSyncService.startAutomaticSync(loaded);
      DailyProgressSyncService.startAutomaticSync(loaded);
      setState(() => state = loaded);
      _dayBoundaryTimer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => loaded.ensureCurrentDay(),
      );
      loaded.addListener(_onStateChangedForWaterReminder);
      _lastWaterReminderMinutes = loaded.waterReminderMinutes;
      _scheduleWaterReminderTimer();
    });
  }

  void _onStateChangedForWaterReminder() {
    final current = state;
    if (current == null) return;
    if (current.waterReminderMinutes != _lastWaterReminderMinutes) {
      _lastWaterReminderMinutes = current.waterReminderMinutes;
      _scheduleWaterReminderTimer();
    }
  }

  // Reminder is in-app only: a SnackBar shown via the root ScaffoldMessenger
  // while this tab/window is open. There is no real push notification here
  // -- it does nothing while the app is closed or backgrounded for long,
  // which is the accepted, deliberate scope of this feature (see PR
  // description); a true push reminder would need a service worker /
  // platform notification channel this app doesn't have.
  void _scheduleWaterReminderTimer() {
    _waterReminderTimer?.cancel();
    final minutes = state?.waterReminderMinutes ?? 0;
    if (minutes <= 0) return;
    _waterReminderTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      final current = state;
      if (current == null || !current.shouldRemindToDrink) return;
      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('זמן לשתות כוס מים 💧'),
            duration: Duration(seconds: 4),
          ),
        );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      state?.ensureCurrentDay();
      CloudSyncService.syncAutomaticallyNow();
      DailyProgressSyncService.syncAutomaticallyNow();
    }
  }

  @override
  void dispose() {
    _dayBoundaryTimer?.cancel();
    _waterReminderTimer?.cancel();
    state?.removeListener(_onStateChangedForWaterReminder);
    CloudSyncService.stopAutomaticSync();
    DailyProgressSyncService.stopAutomaticSync();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentState = state;
    if (currentState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AppStateScope(state: currentState, child: widget.child);
  }
}
