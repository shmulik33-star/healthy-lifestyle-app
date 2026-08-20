part of 'app_state.dart';

List<WorkoutExercise> _fitnessTodayWorkout(AppState state) {
  final result = <WorkoutExercise>[];

  void addIf(String equipmentName, WorkoutExercise exercise) {
    if (state.equipment[equipmentName] == true) result.add(exercise);
  }

  addIf(
    'Lat Pulldown',
    const WorkoutExercise('משיכת פולי עליון', 3, 12, 'Lat Pulldown', 'גב'),
  );
  addIf(
    'Seated Row',
    const WorkoutExercise('חתירה בישיבה', 3, 12, 'Seated Row', 'גב'),
  );
  addIf(
    'Cable Machine',
    const WorkoutExercise(
      'כפיפת מרפקים בכבל',
      3,
      10,
      'Cable Machine',
      'יד קדמית',
    ),
  );
  addIf(
    'משקולות יד',
    const WorkoutExercise(
      'כפיפת מרפקים עם משקולות',
      3,
      10,
      'משקולות יד',
      'יד קדמית',
    ),
  );

  if (result.length < 3 && state.equipment['גומיות התנגדות'] == true) {
    result.add(
      const WorkoutExercise(
        'חתירה עם גומייה',
        3,
        15,
        'גומיות התנגדות',
        'גב',
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
    return const WorkoutExercise(
      'כפיפת פטיש עם משקולות',
      3,
      10,
      'משקולות יד',
      'יד קדמית',
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
