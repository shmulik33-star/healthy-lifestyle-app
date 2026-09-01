part of 'app_state.dart';

List<WorkoutExercise> _fitnessTodayWorkout(AppState state) {
  final result = <WorkoutExercise>[];

  void addIf(String equipmentName, WorkoutExercise exercise) {
    if (state.equipment[equipmentName] == true) result.add(exercise);
  }

  addIf(
    'Lat Pulldown',
    WorkoutExercise(
      'משיכת פולי עליון',
      3,
      12,
      'Lat Pulldown',
      'גב',
      imageUrl: exerciseCatalogById('Full_Range-Of-Motion_Lat_Pulldown')?.imageUrl,
    ),
  );
  addIf(
    'Seated Row',
    WorkoutExercise(
      'חתירה בישיבה',
      3,
      12,
      'Seated Row',
      'גב',
      imageUrl: exerciseCatalogById('Seated_Cable_Rows')?.imageUrl,
    ),
  );
  addIf(
    'Cable Machine',
    WorkoutExercise(
      'כפיפת מרפקים בכבל',
      3,
      10,
      'Cable Machine',
      'יד קדמית',
      imageUrl: exerciseCatalogById('High_Cable_Curls')?.imageUrl,
    ),
  );
  addIf(
    'משקולות יד',
    WorkoutExercise(
      'כפיפת מרפקים עם משקולות',
      3,
      10,
      'משקולות יד',
      'יד קדמית',
      imageUrl: exerciseCatalogById('Dumbbell_Bicep_Curl')?.imageUrl,
    ),
  );

  if (result.length < 3 && state.equipment['גומיות התנגדות'] == true) {
    result.add(
      WorkoutExercise(
        'חתירה עם גומייה',
        3,
        15,
        'גומיות התנגדות',
        'גב',
        imageUrl: exerciseCatalogById('Band_Pull_Apart')?.imageUrl,
      ),
    );
  }
  if (result.length < 3) {
    result.add(
      const WorkoutExercise(
        'יד־רגל נגדית (Bird Dog)',
        3,
        10,
        'ללא ציוד',
        'ליבה וגב',
      ),
    );
  }

  return result.take(5).toList();
}

WorkoutExercise _fitnessAlternativeFor(
  AppState state,
  WorkoutExercise current,
) {
  if (current.muscleGroup == 'גב' &&
      state.equipment['Cable Machine'] == true &&
      current.equipment != 'Cable Machine') {
    return const WorkoutExercise(
      'משיכה בזרועות ישרות בכבל',
      3,
      12,
      'Cable Machine',
      'גב',
    );
  }
  if (current.muscleGroup == 'יד קדמית' &&
      state.equipment['משקולות יד'] == true) {
    return WorkoutExercise(
      'כפיפת פטיש עם משקולות',
      3,
      10,
      'משקולות יד',
      'יד קדמית',
      imageUrl: exerciseCatalogById('Alternate_Hammer_Curl')?.imageUrl,
    );
  }
  if (state.equipment['גומיות התנגדות'] == true) {
    return WorkoutExercise(
      'תרגיל חלופי עם גומייה',
      3,
      15,
      'גומיות התנגדות',
      current.muscleGroup,
    );
  }
  return WorkoutExercise(
    'תרגיל משקל גוף חלופי',
    3,
    12,
    'ללא ציוד',
    current.muscleGroup,
  );
}

// How many recent muscle-group entries AppState.recentWorkoutMuscleGroups
// keeps -- same LRU-window idea as `_recentMealKeysWindow` in
// app_state_nutrition.dart, sized for roughly 3 weeks of AI-picked workout
// days (a handful of muscle groups per day).
const _recentWorkoutGroupsWindow = 21 * 4;

const _hebrewWeekdayNames = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת'];

/// Compact snapshot fed to the AI fitness planner Worker as `context` (see
/// FitnessAiService) -- the same goal facts the rule-based planner above
/// already uses, plus recent muscle groups so the AI can actually rotate
/// the split. The exercise catalog itself travels separately as `catalog`
/// (see eligibleExerciseCatalog + ExerciseCatalogItem.toAiJson), the same
/// context/catalog split the Worker expects. Pure and synchronous, unit
/// tested on its own apart from any HTTP call.
Map<String, dynamic> _fitnessAiContext(AppState state) => {
      'primaryGoal': state.primaryGoal,
      'activityLevel': state.activityLevel,
      'workoutDaysPerWeek': state.workoutDaysPerWeek,
      'dayOfWeek': _hebrewWeekdayNames[DateTime.now().weekday % 7],
      'recentMuscleGroups': state.recentWorkoutMuscleGroups,
    };

void _fitnessRecordMuscleGroups(AppState state, List<String> groups) {
  final history = List<String>.from(state.recentWorkoutMuscleGroups)..addAll(groups);
  final overflow = history.length - _recentWorkoutGroupsWindow;
  state.recentWorkoutMuscleGroups
    ..clear()
    ..addAll(overflow > 0 ? history.sublist(overflow) : history);
  state._save();
}
