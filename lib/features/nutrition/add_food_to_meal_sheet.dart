import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';

/// Bottom sheet to log [food] to today's meals: pick a home unit and
/// quantity, toggle "from home" (pantry deduction), then save. Shared by
/// every entry point that already knows *which* food to add -- the food
/// catalog screen's own list/recommendations, and the "quick add" flow's
/// existing-barcode-match case -- so this UI and its behavior (including
/// the kosher/dairy-wait warnings) stays in exactly one place.
Future<void> showAddFoodToMealSheet(
  BuildContext context,
  AppState state,
  FoodItem food,
) {
  var unit = food.units.keys.first;
  var quantity = 1.0;
  var fromHome = true;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final calories = food.caloriesFor(unit, quantity);
          final protein = food.proteinFor(unit, quantity);
          final carbs = food.carbsFor(unit, quantity);
          final fat = food.fatFor(unit, quantity);

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      food.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text('${food.category} · ${kosherStatusLabel(food.kosherStatus)}'
                        '${food.kosherStatus == KosherStatus.kosher ? ' · ${kosherLabel(food.type)}' : ''}'),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'מידה ביתית',
                        border: OutlineInputBorder(),
                      ),
                      items: food.units.keys
                          .map(
                            (u) => DropdownMenuItem<String>(
                              value: u,
                              child: Text(u),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          unit = value;
                          quantity = 1;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: quantity > 0.5
                              ? () => setSheetState(() => quantity -= 0.5)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '${_formatQuantity(quantity)} × $unit',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setSheetState(() => quantity += 0.5),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('כ־$calories קלוריות'),
                            Text('${protein.toStringAsFixed(1)} גרם חלבון'),
                            Text('${carbs.toStringAsFixed(1)} גרם פחמימות'),
                            Text('${fat.toStringAsFixed(1)} גרם שומן'),
                            Text(
                              'אומדן משקל: '
                              '${food.gramsFor(unit, quantity).round()} גרם',
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (food.type == KosherFoodType.dairy && !state.dairyAllowed) ...[
                      const SizedBox(height: 8),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'שים לב: עדיין לא הסתיימה תקופת ההמתנה '
                            'מבשר לחלב. אפשר לתעד מה שנאכל בפועל, '
                            'אבל האפליקציה לא תציע מזון חלבי בזמן ההמתנה.',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      key: const Key('meal_from_home_checkbox'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: fromHome,
                      onChanged: (value) => setSheetState(() => fromHome = value ?? true),
                      title: const Text('אכלתי מהבית'),
                      subtitle: const Text(
                        'בטל אם אכלת בחוץ / הזמנת — לא ינוכה מהמזווה',
                      ),
                    ),
                    const SizedBox(height: 4),
                    FilledButton.icon(
                      onPressed: () {
                        state.addFood(
                          food,
                          quantity,
                          unit,
                          fromHome: fromHome,
                        );
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${food.name} נוסף ליומן')),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('הוסף ליומן'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}
