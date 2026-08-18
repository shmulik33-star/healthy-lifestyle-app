import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

void main() {
  test('Other food category keeps its custom detail through JSON', () {
    const food = FoodItem(
      id: 'custom_test',
      name: 'קוגל',
      category: 'אחר',
      categoryDetail: 'מאכלי שבת',
      type: KosherFoodType.pareve,
      kosherStatus: KosherStatus.kosher,
      caloriesPer100g: 200,
      proteinPer100g: 4,
      carbsPer100g: 30,
      fatPer100g: 7,
      units: {'מנה': 120, 'גרם': 1},
      userCreated: true,
    );

    final restored = FoodItem.fromJson(food.toJson());

    expect(restored.category, 'אחר');
    expect(restored.categoryDetail, 'מאכלי שבת');
    expect(restored.displayCategory, 'אחר · מאכלי שבת');
  });

  test('Old saved foods without category detail remain compatible', () {
    final restored = FoodItem.fromJson({
      'id': 'legacy',
      'name': 'מזון ישן',
      'category': 'אחר',
      'type': 'pareve',
      'kosherStatus': 'unknown',
      'caloriesPer100g': 100,
      'proteinPer100g': 1,
      'carbsPer100g': 20,
      'fatPer100g': 1,
      'units': {'מנה': 100},
      'userCreated': true,
    });

    expect(restored.categoryDetail, isEmpty);
    expect(restored.displayCategory, 'אחר');
  });
}
