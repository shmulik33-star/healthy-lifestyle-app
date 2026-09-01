import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/app_state.dart';
import '../kosher/kosher_card.dart';
import '../nutrition/add_meal_sheet.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('היום שלי', style: Theme.of(context).textTheme.headlineSmall),
                    Text('שלום ${state.firstName}, כל צעד קטן מצטרף לתמונה הגדולה.'),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AppStateScope(
                      state: state,
                      child: const ProfileScreen(),
                    ),
                  ),
                ),
                child: const CircleAvatar(
                  backgroundColor: AppTheme.softGreen,
                  child: Icon(Icons.person_outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Quick actions -- the most-used, fastest-to-reach things on this
          // screen, front and center as colorful tappable tiles instead of
          // buried in the button row at the bottom (per the redesign brief:
          // "אכלתי", "כוסות מים", and whatever's most valuable to have handy
          // -- weight logging had no home-screen entry point at all before,
          // and today's workout status is worth a glance without a tab
          // switch. "צעדים" is dropped here per the brief; the underlying
          // step data/screen are untouched, this is a home-screen-only cut).
          SizedBox(
            height: 104,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickActionTile(
                    color: AppTheme.green,
                    icon: Icons.restaurant,
                    label: 'אכלתי',
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AppStateScope(
                        state: state,
                        child: const AddMealSheet(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QuickActionTile(
                    key: const Key('water_metric_card'),
                    color: AppTheme.blue,
                    icon: Icons.water_drop_outlined,
                    label: 'כוסות מים',
                    value: '${state.waterCups}/${state.waterTarget}',
                    onTap: () => _addWater(context, state),
                  ),
                  const SizedBox(width: 10),
                  _QuickActionTile(
                    color: AppTheme.purple,
                    icon: Icons.monitor_weight_outlined,
                    label: 'משקל',
                    value: '${state.currentWeight.toStringAsFixed(1)} ק״ג',
                    onTap: () => _logWeight(context, state),
                  ),
                  const SizedBox(width: 10),
                  _QuickActionTile(
                    color: AppTheme.orange,
                    icon: Icons.fitness_center,
                    label: state.workoutCompleted ? 'אימון בוצע ✓' : 'אימון היום',
                    onTap: () => onNavigate(2),
                  ),
                  const SizedBox(width: 10),
                  _QuickActionTile(
                    color: AppTheme.green,
                    icon: Icons.smart_toy_outlined,
                    label: 'המאמן שלי',
                    onTap: () => onNavigate(4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _CalorieRing(
                    eaten: state.caloriesEaten,
                    target: state.calorieTarget,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${state.caloriesEaten}',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.green,
                          ),
                        ),
                        Text('מתוך ${state.calorieTarget} קלוריות'),
                        const SizedBox(height: 8),
                        Text(
                          'חלבון: ${state.proteinEaten.toStringAsFixed(0)}/${state.proteinTarget} גרם',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('התמונה האישית שלי', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${state.primaryGoal} · ${state.workoutDaysPerWeek} אימונים בשבוע · פעילות ${state.activityLevel}'),
                const SizedBox(height: 6),
                Text(state.dailyInsight),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const KosherCard(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ההמלצה שלי עכשיו', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(state.coachResponse('מה כדאי לי לאכול עכשיו?')),
                  const SizedBox(height: 10),
                  ...state.smartFoodSuggestions.take(3).map(
                        (suggestion) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $suggestion'),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _snack(context, state),
            icon: const Icon(Icons.cookie_outlined),
            label: const Text('בא לי לנשנש'),
          ),
        ],
      ),
    );
  }

  void _addWater(BuildContext context, AppState state) {
    final before = state.waterCups;
    state.addWater();
    final reachedGoal = before < state.waterTarget && state.waterCups >= state.waterTarget;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            reachedGoal
                ? 'מעולה! הגעת ליעד המים היומי שלך 💧'
                : 'נוספה כוס מים · ${state.waterCups}/${state.waterTarget}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _logWeight(BuildContext context, AppState state) {
    final controller = TextEditingController(text: state.currentWeight.toStringAsFixed(1));

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('הוסף שקילה'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'משקל בק״ג',
            helperText: 'אפשר להזין לדוגמה 92.4',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () {
              final normalized = controller.text.trim().replaceAll(',', '.');
              final value = double.tryParse(normalized);
              if (value == null || value <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('נא להזין משקל תקין.')),
                );
                return;
              }
              state.addWeight(value);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('השקילה נשמרה.')),
              );
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מה אפשר לנשנש?'),
        content: Text(state.smartFoodSuggestions.join('\n\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('סגור'),
          ),
        ],
      ),
    );
  }
}

/// Prominent, colorful tappable tile for a home-screen quick action --
/// deliberately more visually distinct than a plain card+icon (per the
/// redesign brief's "עיצוב מעניין"): a tinted background in the action's
/// own accent color rather than a uniform neutral card, so the row reads
/// as a set of choices at a glance instead of a wall of identical tiles.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(
                  value ?? label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13),
                ),
                if (value != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular calorie-progress ring for the hero card -- a lighter full-circle
/// track behind the actual progress arc, same idea as the old
/// LinearProgressIndicator but reads as more "designed" at a glance.
class _CalorieRing extends StatelessWidget {
  const _CalorieRing({required this.eaten, required this.target});
  final int eaten;
  final int target;

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (eaten / target).clamp(0, 1).toDouble();
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 8,
              color: AppTheme.softGreen,
            ),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              color: AppTheme.green,
              backgroundColor: Colors.transparent,
            ),
          ),
          const Icon(Icons.local_fire_department, color: AppTheme.green, size: 26),
        ],
      ),
    );
  }
}
