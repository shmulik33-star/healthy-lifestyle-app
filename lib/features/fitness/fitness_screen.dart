import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/app_state.dart';
import '../equipment/equipment_screen.dart';
import '../equipment/equipment_workout.dart';
import 'fitness_ai_service.dart';

/// How FitnessScreen asks the AI fitness planner for today's exercise ids.
/// The real implementation is FitnessAiService.pickWorkout; tests substitute
/// a function that resolves or throws directly, so the "AI call fails ->
/// silently keep the rule-based workout" path is exercised without needing
/// real network. Mirrors CoachScreen's askAi seam.
typedef FitnessPickWorkout = Future<List<String>> Function({
  required Map<String, dynamic> context,
  required List<Map<String, dynamic>> catalog,
});

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key, this.pickWorkout = FitnessAiService.pickWorkout});

  final FitnessPickWorkout pickWorkout;

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  final Set<int> _completedExercises = <int>{};
  List<WorkoutExercise>? _aiWorkout;
  bool _planningAi = false;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final customEquipment = state.customEquipment;
        final workout = _aiWorkout ??
            EquipmentWorkoutBuilder.combine(
              state.todayWorkout,
              customEquipment,
            );
        final availableEquipment = <String>[
          ...state.equipment.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key),
          ...customEquipment.where((item) => item.available).map((item) => item.name),
        ];
        final completedCount = state.workoutCompleted
            ? workout.length
            : _completedExercises.where((index) => index < workout.length).length;
        final progress = workout.isEmpty ? 0.0 : completedCount / workout.length;
        final estimatedMinutes =
            workout.fold<int>(0, (sum, exercise) => sum + exercise.sets * 3);
        final muscleGroupsLabel = workout.isEmpty
            ? 'אין אימון'
            : {for (final exercise in workout) exercise.muscleGroup}.join(' + ');

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
                      const Text('האימון נבנה לפי הציוד שסימנת והציוד שהוספת.'),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    // No manual refresh needed on return: EquipmentScreen
                    // edits the same shared AppState instance, whose
                    // notifyListeners already rebuilds this AnimatedBuilder.
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => AppStateScope(
                          state: state,
                          child: const EquipmentScreen(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune),
                  label: const Text('הציוד שלי'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _planningAi ? null : () => _planWithAi(state),
                icon: _planningAi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_planningAi ? 'מתכנן אימון...' : 'תכנן לי אימון AI להיום'),
              ),
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
                              Text(
                                'האימון של היום',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('$muscleGroupsLabel · כ־$estimatedMinutes דקות'),
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
                    Text(
                      'ציוד זמין: ${availableEquipment.isEmpty ? 'ללא ציוד' : availableEquipment.take(6).join(' · ')}',
                    ),
                    if (customEquipment.any((item) => item.available)) ...[
                      const SizedBox(height: 6),
                      Text(
                        'כולל ${customEquipment.where((item) => item.available).length} פריטי ציוד שהוספת בעצמך.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (workout.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'לא נמצא כרגע אימון מתאים לציוד שסומן. היכנס ל״הציוד שלי״ ועדכן מה עומד לרשותך.',
                  ),
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
                          if (exercise.imageUrl != null) ...[
                            _ExerciseThumbnail(
                              imageUrl: exercise.imageUrl!,
                              imageUrl2: exercise.imageUrl2,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _InfoChip(
                                      icon: Icons.repeat,
                                      text: '${exercise.sets} סטים × ${exercise.reps} חזרות',
                                    ),
                                    _InfoChip(
                                      icon: Icons.accessibility_new,
                                      text: exercise.muscleGroup,
                                    ),
                                    _InfoChip(
                                      icon: Icons.precision_manufacturing_outlined,
                                      text: exercise.equipment,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showAlternative(context, state, exercise),
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
                        ..addAll(
                          List<int>.generate(workout.length, (index) => index),
                        ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('האימון נשמר כהושלם. כל הכבוד!')),
                      );
                    },
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                state.workoutCompleted ? 'האימון הושלם ✓' : 'סיים ושמור את האימון',
              ),
            ),
            const SizedBox(height: 10),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'ציוד שהוספת יכול להשתלב אוטומטית כאשר ניתן לזהות בבטחה תרגיל מתאים. ציוד כללי יותר נשמר כזמין, ובהמשך נוסיף מיפוי חכם וזיהוי בצילום.',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _planWithAi(AppState state) async {
    final catalog = eligibleExerciseCatalog(state);
    setState(() => _planningAi = true);

    List<WorkoutExercise>? picked;
    try {
      final ids = await widget.pickWorkout(
        context: state.fitnessAiContext(),
        catalog: catalog.map((item) => item.toAiJson()).toList(),
      );
      final byId = {for (final item in catalog) item.id: item};
      picked = ids
          .map((id) => byId[id])
          .whereType<ExerciseCatalogItem>()
          .map((item) => item.toWorkoutExercise())
          .toList();
    } catch (_) {
      // Silent fallback -- keep whatever was already shown (the rule-based
      // default, or a previous AI pick), same as CoachScreen's askAi
      // failure handling. No error surfaced to the user.
      picked = null;
    }

    if (!mounted) return;
    setState(() {
      _planningAi = false;
      if (picked != null && picked.isNotEmpty) {
        _aiWorkout = picked;
        _completedExercises.clear();
        state.recordWorkoutMuscleGroups(
          picked.map((e) => e.muscleGroup).toSet().toList(),
        );
      }
    });
  }

  void _showAlternative(
    BuildContext context,
    AppState state,
    WorkoutExercise exercise,
  ) {
    WorkoutExercise? alt;
    for (final item in state.customEquipment.where((item) => item.available)) {
      final candidate = EquipmentWorkoutBuilder.exerciseFor(item);
      if (candidate != null &&
          candidate.muscleGroup == exercise.muscleGroup &&
          candidate.equipment != exercise.equipment) {
        alt = candidate;
        break;
      }
    }
    alt ??= state.alternativeFor(exercise);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('חלופה לתרגיל'),
        content: Text(
          'במקום ${exercise.name}, אפשר לבצע ${alt!.name}: ${alt.sets} סטים × ${alt.reps} חזרות. ציוד: ${alt.equipment}.',
        ),
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

/// Demo-image thumbnail next to an exercise. free-exercise-db (the source
/// -- see ExerciseCatalogItem) only has two static reference frames per
/// exercise (start/end position), not a real animated GIF, so this fakes
/// the motion by alternating imageUrl/imageUrl2 on a timer -- a simple
/// 2-frame loop reads much more like "what the movement looks like" than a
/// single still frame. Tapping it opens a larger view for anyone who still
/// can't tell what's going on at list-row size. Falls back to a plain icon
/// while loading or if an image fails to load, so a slow/broken image host
/// never blocks or breaks the exercise list itself.
class _ExerciseThumbnail extends StatefulWidget {
  const _ExerciseThumbnail({required this.imageUrl, this.imageUrl2});
  final String imageUrl;
  final String? imageUrl2;

  @override
  State<_ExerciseThumbnail> createState() => _ExerciseThumbnailState();
}

class _ExerciseThumbnailState extends State<_ExerciseThumbnail> {
  Timer? _timer;
  bool _showSecondFrame = false;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl2 != null) {
      _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        if (!mounted) return;
        setState(() => _showSecondFrame = !_showSecondFrame);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl =
        (_showSecondFrame && widget.imageUrl2 != null) ? widget.imageUrl2! : widget.imageUrl;
    return GestureDetector(
      onTap: () => _openLarge(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          currentUrl,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _placeholder(),
          errorBuilder: (context, error, stackTrace) => _placeholder(),
        ),
      ),
    );
  }

  void _openLarge(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  widget.imageUrl,
                  width: 260,
                  height: 260,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 260,
                    height: 260,
                    child: Icon(Icons.fitness_center, size: 48, color: Colors.grey),
                  ),
                ),
              ),
              if (widget.imageUrl2 != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.imageUrl2!,
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('סגור'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.fitness_center, size: 30, color: Colors.grey),
      );
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
