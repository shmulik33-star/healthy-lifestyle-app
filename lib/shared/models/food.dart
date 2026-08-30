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

bool isKnownFoodCategory(String category) => foodCategories.contains(category);

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
    this.barcode,
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

  /// Product barcode (EAN/UPC), when this food was added via barcode scan
  /// (see the "quick add" flow). Null for hand-entered and built-in catalog
  /// foods -- optional and additive, so existing saved foods without one
  /// keep loading exactly as before.
  final String? barcode;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'categoryDetail': categoryDetail,
        'type': type.name,
        'kosherStatus': kosherStatus.name,
        'caloriesPer100g': caloriesPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'units': units,
        'userCreated': userCreated,
        'barcode': barcode,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category']?.toString().trim() ?? '';
    final rawDetail = json['categoryDetail']?.toString().trim() ?? '';
    final category = isKnownFoodCategory(rawCategory) ? rawCategory : 'אחר';
    final categoryDetail = category == 'אחר'
        ? (rawDetail.isNotEmpty
            ? rawDetail
            : rawCategory != 'אחר'
                ? rawCategory
                : '')
        : rawDetail;

    return FoodItem(
      id: json['id']?.toString() ??
          'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name']?.toString() ?? 'מזון חדש',
      category: category,
      categoryDetail: categoryDetail,
      type: KosherFoodType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => KosherFoodType.pareve,
      ),
      kosherStatus: KosherStatus.values.firstWhere(
        (value) => value.name == json['kosherStatus'],
        orElse: () => KosherStatus.unknown,
      ),
      caloriesPer100g: (json['caloriesPer100g'] ?? 0).toDouble(),
      proteinPer100g: (json['proteinPer100g'] ?? 0).toDouble(),
      carbsPer100g: (json['carbsPer100g'] ?? 0).toDouble(),
      fatPer100g: (json['fatPer100g'] ?? 0).toDouble(),
      units: Map<String, double>.from(
        ((json['units'] as Map?) ?? {'מנה': 100}).map(
          (key, value) => MapEntry(
            key.toString(),
            (value as num).toDouble(),
          ),
        ),
      ),
      userCreated: json['userCreated'] == true,
      barcode: json['barcode']?.toString(),
    );
  }
}
