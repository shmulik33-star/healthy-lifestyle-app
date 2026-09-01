part of 'app_state.dart';

/// A single real, curated exercise with a verified demo image -- the fixed
/// pool both the rule-based planner and the AI planner pick from. Keeping a
/// closed catalog (instead of letting either planner invent exercise names
/// freely) is what makes the demo image reliable: only catalog entries ever
/// get one, so there's nothing to hallucinate a mismatched picture for.
///
/// Images come from free-exercise-db (github.com/yuhonas/free-exercise-db,
/// Unlicense/public domain) -- two static reference frames per exercise
/// (start/end position). There's no real animated GIF in this source, so
/// the UI fakes the motion by alternating imageUrl/imageUrl2 on a timer
/// (see _ExerciseThumbnail in fitness_screen.dart) instead.
class ExerciseCatalogItem {
  const ExerciseCatalogItem({
    required this.id,
    required this.nameHe,
    required this.muscleGroup,
    required this.equipmentKey,
    required this.sets,
    required this.reps,
  });

  final String id;
  final String nameHe;
  final String muscleGroup;
  // Matches a key in AppState.equipment, a CustomEquipmentItem name, or the
  // literal 'ללא ציוד' for bodyweight exercises (always available).
  final String equipmentKey;
  final int sets;
  final int reps;

  static const _imageBase =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises';

  String get imageUrl => '$_imageBase/$id/0.jpg';
  String get imageUrl2 => '$_imageBase/$id/1.jpg';

  WorkoutExercise toWorkoutExercise() => WorkoutExercise(
        nameHe,
        sets,
        reps,
        equipmentKey,
        muscleGroup,
        imageUrl: imageUrl,
        imageUrl2: imageUrl2,
      );

  // Wire shape sent to the AI fitness planner Worker -- see
  // functions/api/fitness-plan.ts's CatalogItem. Deliberately excludes
  // sets/reps/equipmentKey/imageUrl: the AI only ever picks *which* ids to
  // use, never anything about how they're performed or displayed.
  Map<String, dynamic> toAiJson() => {'id': id, 'nameHe': nameHe, 'muscleGroup': muscleGroup};
}

const kNoEquipmentKey = 'ללא ציוד';

/// Curated subset of free-exercise-db, picked to cover every muscle group
/// with at least one exercise per equipment type this app already knows
/// about (see AppState.equipment) plus bodyweight-only options that are
/// always available. IDs are verified to exist in the source dataset.
const List<ExerciseCatalogItem> kExerciseCatalog = [
  // גב (back)
  ExerciseCatalogItem(
    id: 'Full_Range-Of-Motion_Lat_Pulldown',
    nameHe: 'משיכת פולי עליון',
    muscleGroup: 'גב',
    equipmentKey: 'Lat Pulldown',
    sets: 3,
    reps: 12,
  ),
  ExerciseCatalogItem(
    id: 'Seated_Cable_Rows',
    nameHe: 'חתירה בישיבה',
    muscleGroup: 'גב',
    equipmentKey: 'Seated Row',
    sets: 3,
    reps: 12,
  ),
  ExerciseCatalogItem(
    id: 'Bent_Over_Two-Dumbbell_Row',
    nameHe: 'חתירה עם משקולות בהרכנה',
    muscleGroup: 'גב',
    equipmentKey: 'משקולות יד',
    sets: 3,
    reps: 10,
  ),
  ExerciseCatalogItem(
    id: 'Band_Pull_Apart',
    nameHe: 'משיכת גומייה לפתיחת גב עליון',
    muscleGroup: 'גב',
    equipmentKey: 'גומיות התנגדות',
    sets: 3,
    reps: 15,
  ),

  // יד קדמית (biceps)
  ExerciseCatalogItem(
    id: 'High_Cable_Curls',
    nameHe: 'כפיפת מרפקים בכבל',
    muscleGroup: 'יד קדמית',
    equipmentKey: 'Cable Machine',
    sets: 3,
    reps: 10,
  ),
  ExerciseCatalogItem(
    id: 'Dumbbell_Bicep_Curl',
    nameHe: 'כפיפת מרפקים עם משקולות',
    muscleGroup: 'יד קדמית',
    equipmentKey: 'משקולות יד',
    sets: 3,
    reps: 10,
  ),
  ExerciseCatalogItem(
    id: 'Alternate_Hammer_Curl',
    nameHe: 'כפיפת פטיש עם משקולות',
    muscleGroup: 'יד קדמית',
    equipmentKey: 'משקולות יד',
    sets: 3,
    reps: 10,
  ),

  // יד אחורית (triceps)
  ExerciseCatalogItem(
    id: 'Cable_Rope_Overhead_Triceps_Extension',
    nameHe: 'פשיטת מרפקים בכבל מעל הראש',
    muscleGroup: 'יד אחורית',
    equipmentKey: 'Cable Machine',
    sets: 3,
    reps: 12,
  ),
  ExerciseCatalogItem(
    id: 'Body_Tricep_Press',
    nameHe: 'לחיצת יד אחורית במשקל גוף',
    muscleGroup: 'יד אחורית',
    equipmentKey: kNoEquipmentKey,
    sets: 3,
    reps: 12,
  ),

  // חזה (chest)
  ExerciseCatalogItem(
    id: 'Cable_Chest_Press',
    nameHe: 'לחיצת חזה בכבל',
    muscleGroup: 'חזה',
    equipmentKey: 'Cable Machine',
    sets: 3,
    reps: 10,
  ),
  ExerciseCatalogItem(
    id: 'Dumbbell_Bench_Press',
    nameHe: 'לחיצת חזה עם משקולות',
    muscleGroup: 'חזה',
    equipmentKey: 'משקולות יד',
    sets: 3,
    reps: 10,
  ),
  ExerciseCatalogItem(
    id: 'Pushups',
    nameHe: 'שכיבות סמיכה',
    muscleGroup: 'חזה',
    equipmentKey: kNoEquipmentKey,
    sets: 3,
    reps: 12,
  ),

  // כתפיים (shoulders)
  ExerciseCatalogItem(
    id: 'Cable_Shoulder_Press',
    nameHe: 'לחיצת כתפיים בכבל',
    muscleGroup: 'כתפיים',
    equipmentKey: 'Cable Machine',
    sets: 3,
    reps: 10,
  ),
  ExerciseCatalogItem(
    id: 'Shoulder_Press_-_With_Bands',
    nameHe: 'לחיצת כתפיים עם גומייה',
    muscleGroup: 'כתפיים',
    equipmentKey: 'גומיות התנגדות',
    sets: 3,
    reps: 15,
  ),
  ExerciseCatalogItem(
    id: 'Cable_Seated_Lateral_Raise',
    nameHe: 'הרמות צד בכבל',
    muscleGroup: 'כתפיים',
    equipmentKey: 'Cable Machine',
    sets: 3,
    reps: 12,
  ),
  ExerciseCatalogItem(
    id: 'Arnold_Dumbbell_Press',
    nameHe: 'לחיצת ארנולד עם משקולות',
    muscleGroup: 'כתפיים',
    equipmentKey: 'משקולות יד',
    sets: 3,
    reps: 10,
  ),

  // רגליים (legs)
  ExerciseCatalogItem(
    id: 'Dumbbell_Squat',
    nameHe: 'סקוואט עם משקולות',
    muscleGroup: 'רגליים',
    equipmentKey: 'משקולות יד',
    sets: 3,
    reps: 12,
  ),
  ExerciseCatalogItem(
    id: 'Bodyweight_Squat',
    nameHe: 'סקוואט במשקל גוף',
    muscleGroup: 'רגליים',
    equipmentKey: kNoEquipmentKey,
    sets: 3,
    reps: 15,
  ),
  ExerciseCatalogItem(
    id: 'Dumbbell_Lunges',
    nameHe: 'לאנג׳ עם משקולות',
    muscleGroup: 'רגליים',
    equipmentKey: 'משקולות יד',
    sets: 3,
    reps: 10,
  ),
  ExerciseCatalogItem(
    id: 'Calf_Raise_On_A_Dumbbell',
    nameHe: 'הרמת עקבים עם משקולות',
    muscleGroup: 'רגליים',
    equipmentKey: 'משקולות יד',
    sets: 3,
    reps: 15,
  ),

  // ליבה (core)
  ExerciseCatalogItem(
    id: 'Plank',
    nameHe: 'פלאנק',
    muscleGroup: 'ליבה',
    equipmentKey: kNoEquipmentKey,
    sets: 3,
    reps: 1,
  ),
  ExerciseCatalogItem(
    id: 'Crunches',
    nameHe: 'כפיפות בטן',
    muscleGroup: 'ליבה',
    equipmentKey: kNoEquipmentKey,
    sets: 3,
    reps: 15,
  ),
  ExerciseCatalogItem(
    id: 'Cable_Seated_Crunch',
    nameHe: 'כפיפות בטן בכבל',
    muscleGroup: 'ליבה',
    equipmentKey: 'Cable Machine',
    sets: 3,
    reps: 15,
  ),
  ExerciseCatalogItem(
    id: 'Superman',
    nameHe: 'סופרמן לחיזוק גב תחתון',
    muscleGroup: 'ליבה וגב',
    equipmentKey: kNoEquipmentKey,
    sets: 3,
    reps: 10,
  ),
];

ExerciseCatalogItem? exerciseCatalogById(String id) {
  for (final item in kExerciseCatalog) {
    if (item.id == id) return item;
  }
  return null;
}

/// The catalog entries this user can actually do right now: bodyweight
/// items are always included, everything else needs its equipmentKey
/// toggled on in AppState.equipment or present as an available custom
/// equipment item with a matching name.
List<ExerciseCatalogItem> eligibleExerciseCatalog(AppState state) {
  final availableNames = <String>{
    ...state.equipment.entries.where((e) => e.value).map((e) => e.key),
    ...state.customEquipment.where((item) => item.available).map((item) => item.name),
  };
  return kExerciseCatalog
      .where((item) =>
          item.equipmentKey == kNoEquipmentKey || availableNames.contains(item.equipmentKey))
      .toList();
}
