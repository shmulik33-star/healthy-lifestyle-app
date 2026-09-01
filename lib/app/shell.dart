import 'dart:async';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/coach/coach_screen.dart';
import '../features/equipment/equipment_item.dart';
import '../features/fitness/fitness_screen.dart';
import '../features/home/home_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/profile/cloud_sync_service.dart';
import '../features/profile/daily_progress_sync_service.dart';
import '../features/progress/progress_screen.dart';
import '../shared/models/app_state.dart';
import 'app.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppState? state;
  Timer? _dayBoundaryTimer;
  Timer? _waterReminderTimer;
  // Tracks the last waterReminderMinutes we scheduled a Timer for, so the
  // AppState.notifyListeners() that fires on every unrelated state change
  // (a meal logged, a cup of water added, ...) doesn't reset/restart this
  // timer every single time -- only an actual change to the setting itself
  // (edited in ProfileScreen) should reschedule it.
  int? _lastWaterReminderMinutes;
  int index = 0;

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
      _dayBoundaryTimer=Timer.periodic(
        const Duration(minutes:1),
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
    if(lifecycleState==AppLifecycleState.resumed){
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

  void _goTo(int destination) {
    if (destination < 0 || destination > 4) return;
    state?.ensureCurrentDay();
    if (destination == index) return;
    setState(() => index = destination);
  }

  Widget _pageFor(int pageIndex, AppState currentState) {
    switch (pageIndex) {
      case 0:
        return HomeScreen(onNavigate: _goTo);
      case 1:
        // Pass state explicitly here. This avoids relying on an inherited
        // lookup while the navigation body is being swapped on Flutter Web.
        return NutritionScreen(state: currentState);
      case 2:
        return const FitnessScreen();
      case 3:
        return ProgressScreen(state: currentState);
      case 4:
        return const CoachScreen();
      default:
        return HomeScreen(onNavigate: _goTo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentState = state;
    if (currentState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppStateScope(
      state: currentState,
      child: Scaffold(
        body: SafeArea(
          child: SizedBox.expand(
            child: _pageFor(index, currentState),
          ),
        ),
        bottomNavigationBar: _FloatingNavBar(selectedIndex: index, onSelect: _goTo),
      ),
    );
  }
}

/// Bottom navigation restyled to match the "energetic" home-screen
/// redesign: a rounded pill detached from the screen edges (per the
/// product owner's "שורת ניווט תחתונה צפה" request) instead of Material's
/// flat, edge-to-edge NavigationBar. Scaffold reserves exactly this
/// widget's height as the bottom-nav area, so the surrounding page
/// background shows through the margin around the pill -- no extendBody
/// or per-screen bottom-padding changes needed.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'היום'),
    (icon: Icons.restaurant_outlined, selectedIcon: Icons.restaurant, label: 'תזונה'),
    (icon: Icons.fitness_center_outlined, selectedIcon: Icons.fitness_center, label: 'כושר'),
    (icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'התקדמות'),
    (icon: Icons.smart_toy_outlined, selectedIcon: Icons.smart_toy, label: 'המאמן'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .10), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              for (final (i, d) in _destinations.indexed)
                Expanded(
                  child: _NavItem(
                    icon: i == selectedIndex ? d.selectedIcon : d.icon,
                    label: d.label,
                    selected: i == selectedIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.coral : AppTheme.warmMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppTheme.coral.withValues(alpha: .12) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
