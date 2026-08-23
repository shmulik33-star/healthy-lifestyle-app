import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:healthy_lifestyle_stage9/shared/models/food.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cloud state snapshot restores profile meals pantry and shopping', () async {
    final source = AppState();
    source.firstName = 'בדיקה';
    source.currentWeight = 91.5;
    source.targetWeight = 82;
    source.calorieTarget = 2050;
    source.kosherEnabled = true;
    source.meatWaitMinutes = 360;
    source.activityLevel = 'גבוהה';
    source.equipment['TRX'] = true;
    source.meals.add(
      MealEntry(
        foodId: 'egg',
        name: 'ביצה',
        quantity: 2,
        unit: 'יחידה',
        grams: 100,
        calories: 140,
        protein: 12,
        carbs: 1,
        fat: 10,
        type: KosherFoodType.pareve,
        time: DateTime(2026, 8, 23, 12, 30),
      ),
    );
    source.pantryItems.add(
      PantryItem(
        id: 'pantry-1',
        foodId: 'egg',
        name: 'ביצים',
        quantity: 8,
        unit: 'יחידות',
        category: 'חלבון',
      ),
    );
    source.shoppingItems.add(
      ShoppingItem(
        id: 'shop-1',
        name: 'מלפפון',
        quantity: 3,
        unit: 'יחידות',
        category: 'ירקות',
        checked: true,
      ),
    );
    source.shoppingChecked['מלפפון'] = true;
    source.shoppingInitialized = true;

    final payload = source.exportCloudSyncState();
    final restored = AppState();
    await restored.applyCloudSyncState(payload);

    expect(restored.firstName, 'בדיקה');
    expect(restored.currentWeight, 91.5);
    expect(restored.targetWeight, 82);
    expect(restored.calorieTarget, 2050);
    expect(restored.meatWaitMinutes, 360);
    expect(restored.activityLevel, 'גבוהה');
    expect(restored.equipment['TRX'], isTrue);

    expect(restored.meals, hasLength(1));
    expect(restored.meals.single.foodId, 'egg');
    expect(restored.meals.single.quantity, 2);

    expect(restored.pantryItems, hasLength(1));
    expect(restored.pantryItems.single.id, 'pantry-1');
    expect(restored.pantryItems.single.quantity, 8);

    expect(restored.shoppingItems, hasLength(1));
    expect(restored.shoppingItems.single.id, 'shop-1');
    expect(restored.shoppingItems.single.checked, isTrue);
    expect(restored.shoppingChecked['מלפפון'], isTrue);
    expect(restored.shoppingInitialized, isTrue);
  });
}
