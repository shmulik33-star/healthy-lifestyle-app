import 'dart:async';
import 'package:flutter/material.dart';

import '../features/coach/coach_screen.dart';
import '../features/fitness/fitness_screen.dart';
import '../features/home/home_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/progress/progress_screen.dart';
import '../shared/models/app_state.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppState? state;
  Timer? _dayBoundaryTimer;
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppState.load().then((loaded) {
      if (!mounted) return;
      loaded.ensureCurrentDay();
      setState(() => state = loaded);
      _dayBoundaryTimer=Timer.periodic(
        const Duration(minutes:1),
        (_) => loaded.ensureCurrentDay(),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if(lifecycleState==AppLifecycleState.resumed){
      state?.ensureCurrentDay();
    }
  }

  @override
  void dispose() {
    _dayBoundaryTimer?.cancel();
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'היום',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: 'תזונה',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'כושר',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'התקדמות',
            ),
            NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              selectedIcon: Icon(Icons.smart_toy),
              label: 'המאמן',
            ),
          ],
        ),
      ),
    );
  }
}
