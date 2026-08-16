import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/app_state.dart';
import '../../shared/widgets/metric_card.dart';
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${state.caloriesEaten}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.green,
                    ),
                  ),
                  Text('מתוך ${state.calorieTarget} קלוריות'),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: state.calorieTarget <= 0
                        ? 0
                        : (state.caloriesEaten / state.calorieTarget).clamp(0, 1),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              MetricCard(
                icon: Icons.restaurant,
                value: '${state.proteinEaten.toStringAsFixed(0)}/${state.proteinTarget}',
                label: 'גרם חלבון',
              ),
              const SizedBox(width: 8),
              MetricCard(
                icon: Icons.water_drop_outlined,
                value: '${state.waterCups}/${state.waterTarget}',
                label: 'כוסות מים',
              ),
              const SizedBox(width: 8),
              MetricCard(
                icon: Icons.directions_walk,
                value: '${state.steps}',
                label: 'צעדים',
              ),
            ],
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AppStateScope(
                    state: state,
                    child: const AddMealSheet(),
                  ),
                ),
                icon: const Icon(Icons.restaurant),
                label: const Text('אכלתי'),
              ),
              OutlinedButton.icon(
                onPressed: () => _snack(context, state),
                icon: const Icon(Icons.cookie_outlined),
                label: const Text('בא לי לנשנש'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addWater(context, state),
                icon: const Icon(Icons.water_drop_outlined),
                label: const Text('שתיתי מים'),
              ),
              OutlinedButton.icon(
                onPressed: () => onNavigate(2),
                icon: const Icon(Icons.fitness_center),
                label: Text(state.workoutCompleted ? 'האימון בוצע ✓' : 'לאימון של היום'),
              ),
              OutlinedButton.icon(
                onPressed: () => onNavigate(4),
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Text('דבר עם המאמן'),
              ),
            ],
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
