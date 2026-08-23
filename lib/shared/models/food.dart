enum KosherFoodType { meat, dairy, pareve }

enum KosherStatus { kosher, notKosher, unknown }

const foodCategories = <String>[
  'בשר ועוף',
  'דגים',
  'ביצים',
  'מוצרי חלב',
  'לחמים ודגנים',
  'קטניות',
  'ירקות',
  'פירות',
  'אגוזים וזרעים',
  'ממרחים ורטבים',
  'חטיפים וממתקים',
  'משקאות',
  'מאפים ומזון מוכן',
  'מזון קפוא',
  'אחר',
];

String kosherLabel(KosherFoodType type) => switch (type) {
  KosherFoodType.meat => 'בשרי',
  KosherFoodType.dairy => 'חלבי',
  KosherFoodType.pareve => 'פרווה',
};

String kosherStatusLabel(KosherStatus status) => switch (status) {
  KosherStatus.kosher => 'כשר',
  KosherStatus.notKosher => 'לא כשר',
  KosherStatus.unknown => 'כשרות לא ידועה',
};

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.units,
    this.categoryDetail = '',
    this.kosherStatus = KosherStatus.kosher,
    this.userCreated = false,
  });

  final String id;
  final String name;
  final String category;
  final String categoryDetail;
  final KosherFoodType type;
  final KosherStatus kosherStatus;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final Map<String, double> units;
  final bool userCreated;

  String get displayCategory =>
      category == 'אחר' && categoryDetail.trim().isNotEmpty
          ? 'אחר · ${categoryDetail.trim()}'
          : category;

  double gramsFor(String unit, double quantity) => (units[unit] ?? 1) * quantity;
  int caloriesFor(String unit, double quantity) =>
      (gramsFor(unit, quantity) * caloriesPer100g / 100).round();
  double proteinFor(String unit, double quantity) =>
      gramsFor(unit, quantity) * proteinPer100g / 100;
  double carbsFor(String unit, double quantity) =>
      gramsFor(unit, quantity) * carbsPer100g / 100;
  double fatFor(String unit, double quantity) =>
      gramsFor(unit, quantity) * fatPer100g / 100;

  Map<String,dynamic> toJson()=> {
    'id':id,'name':name,'category':category,'categoryDetail':categoryDetail,
    'type':type.name,'kosherStatus':kosherStatus.name,
    'caloriesPer100g':caloriesPer100g,'proteinPer100g':proteinPer100g,
    'carbsPer100g':carbsPer100g,'fatPer100g':fatPer100g,
    'units':units,'userCreated':userCreated,
  };

  factory FoodItem.fromJson(Map<String,dynamic> j)=>FoodItem(
    id:j['id']??'custom_${DateTime.now().microsecondsSinceEpoch}',
    name:j['name']??'מזון חדש',
    category:j['category']??'אחר',
    categoryDetail:j['categoryDetail']??'',
    type:KosherFoodType.values.firstWhere(
      (e)=>e.name==j['type'],orElse:()=>KosherFoodType.pareve),
    kosherStatus:KosherStatus.values.firstWhere(
      (e)=>e.name==j['kosherStatus'],orElse:()=>KosherStatus.unknown),
    caloriesPer100g:(j['caloriesPer100g']??0).toDouble(),
    proteinPer100g:(j['proteinPer100g']??0).toDouble(),
    carbsPer100g:(j['carbsPer100g']??0).toDouble(),
    fatPer100g:(j['fatPer100g']??0).toDouble(),
    units:Map<String,double>.from(
      ((j['units'] as Map?)??{'מנה':100}).map(
        (k,v)=>MapEntry(k.toString(),(v as num).toDouble()))),
    userCreated:j['userCreated']==true,
  );
}
