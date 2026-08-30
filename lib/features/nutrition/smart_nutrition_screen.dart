import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';
import 'add_food_to_catalog_screen.dart';
import 'add_food_to_meal_sheet.dart';
import 'quick_add_food_sheet.dart';

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
      appBar: AppBar(
        title: const Text('מאגר המזונות'),
        actions: [
          IconButton(
            key: const Key('quick_add_food_button'),
            tooltip: 'הוסף מהיר',
            icon: const Icon(Icons.qr_code_scanner_outlined),
            onPressed: () => QuickAddFoodSheet.show(context, state),
          ),
        ],
      ),
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
            ...results.map((food) {
              final disliked = state.foodDislikes.contains(food.id);
              return Card(
                child: ListTile(
                  title: Text(food.name),
                  subtitle: Text(
                    '${food.category} · ${kosherStatusLabel(food.kosherStatus)}'
                    '${food.kosherStatus==KosherStatus.kosher?' · ${kosherLabel(food.type)}':''}'
                    '${disliked ? ' · מדורג נמוך יותר בהמלצות' : ''}\n'
                    '${food.caloriesPer100g.toStringAsFixed(0)} קל׳ · '
                    '${food.proteinPer100g.toStringAsFixed(1)} גרם חלבון ל־100 גרם',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('food_dislike_${food.id}'),
                        icon: Icon(
                          disliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                        ),
                        tooltip: disliked
                            ? 'הסר מרשימת המזונות שלא אוהב'
                            : 'סמן כמזון שלא אוהב',
                        onPressed: () => _toggleDislike(food, !disliked),
                      ),
                      if (food.userCreated)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'ערוך מזון',
                          onPressed: () => _editFood(context, food),
                        )
                      else
                        const Icon(Icons.chevron_left),
                    ],
                  ),
                  onTap: () => _openFood(context, food),
                ),
              );
            }),
        ],
      ),
    );
  }

  List<FoodItem> _recommendations(AppState state) {
    final allowed = state.allFoods.where(state.foodAllowedForRecommendations).toList();

    allowed.sort((a, b) {
      // Preference is a ranking tier, not a filter on `allowed` above -- see
      // AppState.foodAllowedForRecommendations's docstring. A disliked food
      // ranks below an otherwise-equal one, but still shows up if nothing
      // better is available.
      final dislikedCompare = state.isFoodDisliked(a) == state.isFoodDisliked(b)
          ? 0
          : (state.isFoodDisliked(a) ? 1 : -1);
      if (dislikedCompare != 0) return dislikedCompare;

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

  void _toggleDislike(FoodItem food, bool disliked) {
    widget.state.setFoodDisliked(food, disliked);
    // Same rebuild workaround as `_editFood`: `state` is a plain constructor
    // param here, not read through AppStateScope.of(context), so this screen
    // never rebuilds on its own from notifyListeners().
    setState(() {});
  }

  Future<void> _openFood(BuildContext context, FoodItem food) =>
      showAddFoodToMealSheet(context, widget.state, food);
}
