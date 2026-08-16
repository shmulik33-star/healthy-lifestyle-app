import 'package:flutter/material.dart';
import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';

class MealPlanScreen extends StatelessWidget {
  const MealPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('התפריט השבועי'),
        actions: [
          IconButton(
            tooltip: 'בנה תפריט חדש',
            onPressed: () => state.generateWeeklyPlan(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'התפריט נבנה לפי יעד של ${state.calorieTarget} קלוריות, עם דגש על חלבון ושמירה על הפרדה בין בשר לחלב. אחרי ארוחת צהריים בשרית, ארוחת הערב נשארת פרווה.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...state.weeklyPlan.map((day) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ExpansionTile(
                  initiallyExpanded: day.day == 'ראשון',
                  title: Text(day.day, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${day.meals.fold<int>(0, (sum, meal) => sum + meal.calories)} קלוריות מתוכננות'),
                  children: day.meals.map((meal) => ListTile(
                    leading: CircleAvatar(child: Text(_icon(meal.type))),
                    title: Text('${meal.title} · ${meal.description}'),
                    subtitle: Text('${meal.calories} קלוריות · ${kosherLabel(meal.type)}'),
                  )).toList(),
                ),
              ),
            )),
            FilledButton.icon(
              onPressed: () => state.generateWeeklyPlan(),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('בנה לי תפריט חדש'),
            ),
          ],
        ),
      ),
    );
  }

  String _icon(KosherFoodType type) => switch(type){
    KosherFoodType.meat => '🥩',
    KosherFoodType.dairy => '🥛',
    KosherFoodType.pareve => '🥚',
  };
}
