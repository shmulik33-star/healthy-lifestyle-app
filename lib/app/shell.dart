import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/coach/coach_screen.dart';
import '../features/fitness/fitness_screen.dart';
import '../features/home/home_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/progress/progress_screen.dart';
import '../shared/models/app_state.dart';

/// go_router config for the 5 bottom-nav tabs. Each branch is its own tiny
/// Navigator with its own back stack, so every push a screen already does
/// (Navigator.push for Profile/Equipment/AddFoodToCatalogScreen/...) keeps
/// working completely unchanged -- this only replaces how the TAB switch
/// itself is driven (StatefulNavigationShell.goBranch instead of a raw
/// setState(index)). The payoff: with a real Router at the root, browser/
/// Android back now has actual history to pop through instead of exiting
/// the app on the very first back-press (see PR discussion) -- tab
/// switches and every Navigator.push both register real history entries.
/// Hash-based URLs (Flutter's web default, not usePathUrlStrategy) on
/// purpose: Cloudflare Pages has no SPA rewrite rule (`_redirects`) for
/// this app, and hash URLs need no server-side routing config at all, so
/// this doesn't add a deploy-time risk on top of the navigation fix.
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _AppScaffold(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => HomeScreen(
              onNavigate: (i) => StatefulNavigationShell.of(context).goBranch(i),
            ),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/nutrition',
            // Pass state explicitly here. This avoids relying on an
            // inherited lookup while the navigation body is being swapped
            // on Flutter Web.
            builder: (context, state) => NutritionScreen(state: AppStateScope.of(context)),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/fitness', builder: (context, state) => const FitnessScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/progress',
            builder: (context, state) => ProgressScreen(state: AppStateScope.of(context)),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/coach', builder: (context, state) => const CoachScreen()),
        ]),
      ],
    ),
  ],
);

class _AppScaffold extends StatelessWidget {
  const _AppScaffold({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: shell),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: shell.currentIndex,
        onSelect: (i) {
          AppStateScope.of(context).ensureCurrentDay();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
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
