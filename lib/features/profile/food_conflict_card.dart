import 'package:flutter/material.dart';

import '../../shared/models/food.dart';
import 'food_sync_conflict.dart';

class FoodConflictCard extends StatelessWidget {
  const FoodConflictCard({
    super.key,
    required this.conflict,
    required this.onKeepBoth,
  });
  final FoodSyncConflict conflict;
  final VoidCallback? onKeepBoth;

  Widget _version(String label, FoodItem food) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(food.name),
        Text(
          '${food.displayCategory} · ${kosherLabel(food.type)} · ${kosherStatusLabel(food.kosherStatus)}',
        ),
        Text(
          'ל־100 גרם: ${food.caloriesPer100g} קלוריות, ${food.proteinPer100g} גרם חלבון, '
          '${food.carbsPer100g} גרם פחמימות, ${food.fatPer100g} גרם שומן',
        ),
        Text(
          'יחידות: ${food.units.entries.map((entry) => '${entry.key}: ${entry.value} גרם').join(', ')}',
        ),
        if (food.barcode != null) Text('ברקוד: ${food.barcode}'),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'למזון הזה יש שתי גרסאות',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          _version('במכשיר הזה', conflict.local),
          _version('בענן', conflict.remote),
          const Text(
            'לא נדרוס גרסה בלי אישורך. בשמירת שתיהן, הגרסה המקומית תישאר '
            'בפריט המקורי וגרסת הענן תתווסף כפריט נפרד. ארוחות קיימות לא ישתנו.',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onKeepBoth,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('שמור את שתי הגרסאות'),
          ),
          const Text('אפשר להשאיר ללא שינוי ולחזור להחלטה מאוחר יותר.'),
        ],
      ),
    ),
  );
}
