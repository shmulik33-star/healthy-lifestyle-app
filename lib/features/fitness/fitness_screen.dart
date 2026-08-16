import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/app_state.dart';
import '../equipment/equipment_screen.dart';

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key});

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  final Set<int> _completedExercises = <int>{};

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final workout = state.todayWorkout;
        final availableEquipment = state.equipment.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();
        final completedCount = state.workoutCompleted
            ? workout.length
            : _completedExercises.where((index) => index < workout.length).length;
        final progress = workout.isEmpty ? 0.0 : completedCount / workout.length;
        final estimatedMinutes = workout.fold<int>(0, (sum, exercise) => sum + exercise.sets * 3);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('כושר', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 3),
                      const Text('האימון נבנה לפי הציוד שסימנת כזמין.'),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AppStateScope(
                        state: state,
                        child: const EquipmentScreen(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.tune),
                  label: const Text('הציוד שלי'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFF0E9FF),
                          foregroundColor: AppTheme.purple,
                          child: Icon(Icons.fitness_center),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('האימון של היום', style: Theme.of(context).textTheme.titleMedium),
                              Text('גב + יד קדמית · כ־$estimatedMinutes דקות'),
                            ],
                          ),
                        ),
                        Text('$completedCount/${workout.length}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: state.workoutCompleted ? 1 : progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 12),
                    Text('ציוד זמין: ${availableEquipment.isEmpty ? 'ללא ציוד' : availableEquipment.take(6).join(' · ')}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (workout.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('לא נמצא כרגע אימון מתאים לציוד שסומן. היכנס ל״הציוד שלי״ ועדכן מה עומד לרשותך.'),
                ),
              )
            else
              ...workout.asMap().entries.map((entry) {
                final index = entry.key;
                final exercise = entry.value;
                final done = state.workoutCompleted || _completedExercises.contains(index);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: done,
                            onChanged: state.workoutCompleted
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value == true) {
                                        _completedExercises.add(index);
                                      } else {
                                        _completedExercises.remove(index);
                                      }
                                    });
                                  },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _InfoChip(icon: Icons.repeat, text: '${exercise.sets} סטים × ${exercise.reps} חזרות'),
                                    _InfoChip(icon: Icons.accessibility_new, text: exercise.muscleGroup),
                                    _InfoChip(icon: Icons.precision_manufacturing_outlined, text: exercise.equipment),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => _showAlternative(context, state, exercise),
                                  icon: const Icon(Icons.swap_horiz),
                                  label: const Text('המכשיר תפוס / החלף תרגיל'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: workout.isEmpty || state.workoutCompleted
                  ? null
                  : () {
                      state.completeWorkout();
                      setState(() => _completedExercises
                        ..clear()
                        ..addAll(List<int>.generate(workout.length, (index) => index)));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('האימון נשמר כהושלם. כל הכבוד!')),
                      );
                    },
              icon: const Icon(Icons.check_circle_outline),
              label: Text(state.workoutCompleted ? 'האימון הושלם ✓' : 'סיים ושמור את האימון'),
            ),
            const SizedBox(height: 10),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('בשלבים הבאים נוכל להוסיף משקל וחזרות לכל סט, טיימר מנוחה, היסטוריית ביצועים ותוכנית לפי ימים וחלקי גוף — בלי לשנות את המבנה שכבר בנינו.'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAlternative(BuildContext context, AppState state, WorkoutExercise exercise) {
    final alt = state.alternativeFor(exercise);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('חלופה לתרגיל'),
        content: Text('במקום ${exercise.name}, אפשר לבצע ${alt.name}: ${alt.sets} סטים × ${alt.reps} חזרות. ציוד: ${alt.equipment}.'),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
