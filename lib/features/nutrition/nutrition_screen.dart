import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';
import '../meal_plan/meal_plan_screen.dart';
import '../shopping/shopping_screen.dart';
import '../shopping/pantry_screen.dart';
import 'add_meal_sheet.dart';
import 'add_food_to_catalog_screen.dart';
import 'smart_nutrition_screen.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final meals = state.todayMeals;
        final calorieProgress = state.calorieTarget <= 0
            ? 0.0
            : (state.caloriesEaten / state.calorieTarget)
                .clamp(0.0, 1.0)
                .toDouble();

        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'תזונה',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openAddMeal(context),
                      icon: const Icon(Icons.add),
                      label: const Text('אכלתי'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.caloriesEaten} מתוך ${state.calorieTarget} קלוריות',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: calorieProgress,
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 10),
                      Text('${state.proteinEaten.toStringAsFixed(0)} מתוך ${state.proteinTarget} גרם חלבון'),
                      const SizedBox(height: 4),
                      Text('פחמימות: ${state.carbsEaten.toStringAsFixed(0)} גרם · שומן: ${state.fatEaten.toStringAsFixed(0)} גרם'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AppStateScope(
                            state: state,
                            child: const MealPlanScreen(),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('תפריט שבועי'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AppStateScope(
                            state: state,
                            child: const ShoppingScreen(),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('קניות'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children:[
                  Expanded(
                    child:FilledButton.tonalIcon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AppStateScope(
                            state: state,
                            child: SmartNutritionScreen(state: state),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.search),
                      label: const Text('חיפוש במאגר'),
                    ),
                  ),
                  const SizedBox(width:8),
                  Expanded(
                    child:OutlinedButton.icon(
                      onPressed:()=>Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder:(_)=>AppStateScope(
                            state:state,
                            child:AddFoodToCatalogScreen(state:state),
                          ),
                        ),
                      ),
                      icon:const Icon(Icons.add_box_outlined),
                      label:const Text('הוסף מזון למאגר'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:()=>Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder:(_)=>AppStateScope(state:state,child:const PantryScreen()),
                  ),
                ),
                icon:const Icon(Icons.inventory_2_outlined),
                label:const Text('המזווה שלי'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text('הארוחות של היום', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const _KosherLegend(),
                ],
              ),
              const SizedBox(height: 8),
              if (meals.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('עדיין לא תיעדת אוכל היום.', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        const Text('אפשר להזין כמות בכף, כפית, כוס, יחידה או חתיכה — אין צורך במשקל אוכל.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _openAddMeal(context),
                          icon: const Icon(Icons.add),
                          label: const Text('תעד ארוחה ראשונה'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...meals.map(
                  (meal) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _kosherBackground(meal.type),
                          foregroundColor: _kosherForeground(meal.type),
                          child: Text(
                            _kosherInitial(meal.type),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        title: Text('${meal.name} — ${_formatQuantity(meal.quantity)} ${meal.unit}'),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('${meal.calories} קלוריות · ${meal.protein.toStringAsFixed(1)} גרם חלבון'),
                              _KosherBadge(type: meal.type),
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') state.removeMeal(meal);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('מחק מהיומן'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openAddMeal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AppStateScope(
        state: state,
        child: const AddMealSheet(),
      ),
    );
  }

  static String _kosherInitial(KosherFoodType type) {
    switch (type) {
      case KosherFoodType.meat:
        return 'ב';
      case KosherFoodType.dairy:
        return 'ח';
      case KosherFoodType.pareve:
        return 'פ';
    }
  }

  static Color _kosherBackground(KosherFoodType type) {
    switch (type) {
      case KosherFoodType.meat:
        return const Color(0xFFFDE8E8);
      case KosherFoodType.dairy:
        return const Color(0xFFE7F0FF);
      case KosherFoodType.pareve:
        return const Color(0xFFE4F7EA);
    }
  }

  static Color _kosherForeground(KosherFoodType type) {
    switch (type) {
      case KosherFoodType.meat:
        return const Color(0xFFB42318);
      case KosherFoodType.dairy:
        return const Color(0xFF175CD3);
      case KosherFoodType.pareve:
        return const Color(0xFF18794E);
    }
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _KosherBadge extends StatelessWidget {
  const _KosherBadge({required this.type});
  final KosherFoodType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: NutritionScreen._kosherBackground(type),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        kosherLabel(type),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: NutritionScreen._kosherForeground(type),
        ),
      ),
    );
  }
}

class _KosherLegend extends StatelessWidget {
  const _KosherLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 4,
      children: [
        _KosherBadge(type: KosherFoodType.meat),
        _KosherBadge(type: KosherFoodType.dairy),
        _KosherBadge(type: KosherFoodType.pareve),
      ],
    );
  }
}
