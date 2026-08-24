import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';
import 'add_food_to_catalog_screen.dart';

class SmartNutritionScreen extends StatefulWidget {
  const SmartNutritionScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SmartNutritionScreen> createState() => _SmartNutritionScreenState();
}

class _SmartNutritionScreenState extends State<SmartNutritionScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final results = state.allFoods.where((food) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return food.name.toLowerCase().contains(q) ||
          food.category.toLowerCase().contains(q);
    }).toList();

    final recommendations = _recommendations(state);

    return Scaffold(
      appBar: AppBar(title: const Text('מאגר המזונות')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'חיפוש מזון',
              hintText: 'למשל: טונה, ביצה, אורז',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'מה מתאים עכשיו?',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'נשארו היום ${state.remainingCalories} קלוריות '
                    'וכ-${state.remainingProtein.toStringAsFixed(0)} גרם חלבון.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: recommendations
                        .map(
                          (food) => ActionChip(
                            avatar: Icon(
                              food.type == KosherFoodType.meat
                                  ? Icons.restaurant
                                  : food.type == KosherFoodType.dairy
                                      ? Icons.local_drink_outlined
                                      : Icons.eco_outlined,
                              size: 18,
                            ),
                            label: Text(food.name),
                            onPressed: () => _openFood(context, food),
                          ),
                        )
                        .toList(),
                  ),
                  if (!state.dairyAllowed) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'מזונות חלביים אינם מוצעים כרגע בגלל זמן ההמתנה מבשר לחלב.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'כל המזונות',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          if (results.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('לא נמצא מזון מתאים לחיפוש.'),
              ),
            )
          else
            ...results.map(
              (food) => Card(
                child: ListTile(
                  title: Text(food.name),
                  subtitle: Text(
                    '${food.category} · ${kosherStatusLabel(food.kosherStatus)}'
                    '${food.kosherStatus==KosherStatus.kosher?' · ${kosherLabel(food.type)}':''}\n'
                    '${food.caloriesPer100g.toStringAsFixed(0)} קל׳ · '
                    '${food.proteinPer100g.toStringAsFixed(1)} גרם חלבון ל־100 גרם',
                  ),
                  isThreeLine: true,
                  trailing: food.userCreated
                      ? IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'ערוך מזון',
                          onPressed: () => _editFood(context, food),
                        )
                      : const Icon(Icons.chevron_left),
                  onTap: () => _openFood(context, food),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<FoodItem> _recommendations(AppState state) {
    final allowed = state.allFoods.where(state.foodAllowedForRecommendations).toList();

    allowed.sort((a, b) {
      double score(FoodItem f) {
        var value = f.proteinPer100g * 5;
        if (state.remainingProtein > 30) value += f.proteinPer100g * 3;
        if (f.caloriesPer100g > state.remainingCalories && state.remainingCalories > 0) {
          value -= 40;
        }
        return value;
      }

      return score(b).compareTo(score(a));
    });

    return allowed.take(4).toList();
  }

  Future<void> _editFood(BuildContext context, FoodItem food) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AppStateScope(
          state: widget.state,
          child: AddFoodToCatalogScreen(state: widget.state, editingFood: food),
        ),
      ),
    );
    // This screen holds `state` as a plain constructor param, not through
    // AppStateScope.of(context), so it never subscribes to notifyListeners()
    // and won't rebuild on its own when the edit/delete screen changes the
    // food list. The edit/save itself already persisted correctly — this
    // just forces the "מאגר המזונות" list to re-read state.allFoods so the
    // change is visible without leaving and re-entering the screen.
    if (mounted) setState(() {});
  }

  Future<void> _openFood(BuildContext context, FoodItem food) async {
    final state = widget.state;
    var unit = food.units.keys.first;
    var quantity = 1.0;

    await showModalBottomSheet<void>(
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
                          '${food.kosherStatus==KosherStatus.kosher?' · ${kosherLabel(food.type)}':''}'),
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
                            onPressed: () =>
                                setSheetState(() => quantity += 0.5),
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
                      if (food.type == KosherFoodType.dairy &&
                          !state.dairyAllowed) ...[
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
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          state.addFood(food, quantity, unit);
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${food.name} נוסף ליומן'),
                            ),
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

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
