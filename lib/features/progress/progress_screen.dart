import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final nutrition = _percent(state.caloriesEaten, state.calorieTarget);
        final workout = state.workoutCompleted ? 100 : 0;
        final water = _percent(state.waterCups, state.waterTarget);
        // Steps dropped from the score (and the row below) per feedback --
        // weight redistributed among the remaining three so the score stays
        // consistent with what's actually displayed.
        final score = (nutrition * .5 + workout * .3 + water * .2).round();
        final history = state.weights.reversed.take(8).toList();

        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'התקדמות',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _addWeight(context),
                      icon: const Icon(Icons.monitor_weight_outlined),
                      label: const Text('שקילה'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('ציון עקביות יומי'),
                      const SizedBox(height: 4),
                      Text(
                        '$score%',
                        key: const Key('consistency_score'),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'משקל נוכחי: ${state.currentWeight.toStringAsFixed(1)} ק״ג · '
                        'יעד: ${state.targetWeight.toStringAsFixed(1)} ק״ג',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.trending_down)),
                title: const Text('מגמת משקל'),
                subtitle: Text(state.weightTrend),
              )),
              const SizedBox(height: 8),
              _progressRow(context, 'תזונה', nutrition),
              _progressRow(context, 'אימון', workout),
              _progressRow(context, 'מים', water),
              const SizedBox(height: 18),
              Text(
                'היסטוריית שקילות',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (history.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'עדיין אין שקילות שמורות.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'הוסף שקילה ראשונה כדי להתחיל לראות מגמה לאורך זמן.',
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _addWeight(context),
                          icon: const Icon(Icons.add),
                          label: const Text('הוסף שקילה'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...history.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.monitor_weight_outlined),
                        ),
                        title: Text('${entry.weight.toStringAsFixed(1)} ק״ג'),
                        subtitle: Text(
                          '${entry.date.day}/${entry.date.month}/${entry.date.year}',
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

  static int _percent(num current, num target) {
    if (target <= 0) return 0;
    return ((current / target) * 100).clamp(0, 100).round();
  }

  static Widget _progressRow(
    BuildContext context,
    String name,
    int value,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 70, child: Text(name)),
            Expanded(
              child: LinearProgressIndicator(
                value: (value / 100).clamp(0.0, 1.0).toDouble(),
                minHeight: 9,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              child: Text('$value%', textAlign: TextAlign.end),
            ),
          ],
        ),
      ),
    );
  }

  void _addWeight(BuildContext context) {
    final controller =
        TextEditingController(text: state.currentWeight.toStringAsFixed(1));

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('הוסף שקילה'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'משקל בק״ג',
            helperText: 'אפשר להזין לדוגמה 92.4',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () {
              final normalized = controller.text.trim().replaceAll(',', '.');
              final value = double.tryParse(normalized);
              if (value == null || value <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('נא להזין משקל תקין.')),
                );
                return;
              }
              state.addWeight(value);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('השקילה נשמרה.')),
              );
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}
