import '../../shared/models/app_state.dart';
import 'equipment_item.dart';

class EquipmentWorkoutBuilder {
  static List<WorkoutExercise> combine(
    List<WorkoutExercise> base,
    List<CustomEquipmentItem> custom,
  ) {
    final result = <WorkoutExercise>[...base];
    final usedNames = result.map((e) => e.name).toSet();

    for (final item in custom.where((e) => e.available)) {
      final exercise = exerciseFor(item);
      if (exercise == null || usedNames.contains(exercise.name)) continue;
      result.add(exercise);
      usedNames.add(exercise.name);
      if (result.length >= 5) break;
    }

    return result.take(5).toList();
  }

  static bool canSuggestExercise(CustomEquipmentItem item) =>
      exerciseFor(item) != null;

  static WorkoutExercise? exerciseFor(CustomEquipmentItem item) {
    final name = item.name.trim();
    final normalized = name.toLowerCase();

    if (item.category == 'גומיות התנגדות' ||
        normalized.contains('גומ') ||
        normalized.contains('band')) {
      return WorkoutExercise(
        'חתירה עם $name',
        3,
        15,
        name,
        'גב',
        imageUrl: exerciseCatalogById('Band_Pull_Apart')?.imageUrl,
        imageUrl2: exerciseCatalogById('Band_Pull_Apart')?.imageUrl2,
      );
    }

    if (item.category == 'משקולות' ||
        normalized.contains('דאמבל') ||
        normalized.contains('משקול') ||
        normalized.contains('dumbbell')) {
      return WorkoutExercise(
        'כפיפת מרפקים עם $name',
        3,
        10,
        name,
        'יד קדמית',
        imageUrl: exerciseCatalogById('Dumbbell_Bicep_Curl')?.imageUrl,
        imageUrl2: exerciseCatalogById('Dumbbell_Bicep_Curl')?.imageUrl2,
      );
    }

    if (item.category == 'קטלבל' || normalized.contains('קטלבל')) {
      return WorkoutExercise(
        'חתירה ביד אחת עם $name',
        3,
        12,
        name,
        'גב',
      );
    }

    if (item.category == 'מוטות' ||
        normalized.contains('מוט') ||
        normalized.contains('barbell')) {
      return WorkoutExercise(
        'חתירה עם $name',
        3,
        10,
        name,
        'גב',
      );
    }

    if (normalized.contains('פולי') ||
        normalized.contains('lat') ||
        normalized.contains('pulldown')) {
      return WorkoutExercise(
        'משיכת פולי עליון ב־$name',
        3,
        12,
        name,
        'גב',
        imageUrl: exerciseCatalogById('Full_Range-Of-Motion_Lat_Pulldown')?.imageUrl,
        imageUrl2: exerciseCatalogById('Full_Range-Of-Motion_Lat_Pulldown')?.imageUrl2,
      );
    }

    if (normalized.contains('חתירה') || normalized.contains('row')) {
      return WorkoutExercise(
        'חתירה ב־$name',
        3,
        12,
        name,
        'גב',
        imageUrl: exerciseCatalogById('Seated_Cable_Rows')?.imageUrl,
        imageUrl2: exerciseCatalogById('Seated_Cable_Rows')?.imageUrl2,
      );
    }

    if (normalized.contains('כבל') || normalized.contains('cable')) {
      return WorkoutExercise(
        'כפיפת מרפקים ב־$name',
        3,
        10,
        name,
        'יד קדמית',
        imageUrl: exerciseCatalogById('High_Cable_Curls')?.imageUrl,
        imageUrl2: exerciseCatalogById('High_Cable_Curls')?.imageUrl2,
      );
    }

    return null;
  }
}
