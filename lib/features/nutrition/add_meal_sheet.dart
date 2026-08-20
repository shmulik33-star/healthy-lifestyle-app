import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';

class AddMealSheet extends StatefulWidget {
  const AddMealSheet({super.key});

  @override
  State<AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<AddMealSheet> {
  FoodItem? food;
  double quantity = 1;
  String? unit;
  final quantityController = TextEditingController(text: '1');

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final foods = state.allFoods;
    final current = food;
    final currentUnit = unit;
    final cal = current != null && currentUnit != null
        ? current.caloriesFor(currentUnit, quantity)
        : 0;
    final protein = current != null && currentUnit != null
        ? current.proteinFor(currentUnit, quantity)
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('אכלתי', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text(
                'התחל להקליד את שם המזון ובחר מההשלמות. מזון חדש מוסיפים בנפרד ל“מאגר המזונות”.',
              ),
              const SizedBox(height: 14),
              Autocomplete<FoodItem>(
                displayStringForOption: (option) => option.name,
                optionsBuilder: (textEditingValue) =>
                    _searchFoods(foods, textEditingValue.text),
                onSelected: (selected) {
                  setState(() {
                    food = selected;
                    unit = selected.units.keys.first;
                    quantity = 1;
                    quantityController.text = '1';
                  });
                },
                fieldViewBuilder: (
                  context,
                  textController,
                  focusNode,
                  onFieldSubmitted,
                ) {
                  return TextFormField(
                    key: const Key('meal_food_search'),
                    controller: textController,
                    focusNode: focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'חפש מזון',
                      hintText: 'לדוגמה: טונה, ביצה, קציצות...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: current == null
                          ? null
                          : const Icon(Icons.check_circle_outline),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final selected = food;
                      if (selected != null && value.trim() != selected.name) {
                        setState(() {
                          food = null;
                          unit = null;
                          quantity = 1;
                          quantityController.text = '1';
                        });
                      }
                    },
                    onFieldSubmitted: (_) => onFieldSubmitted(),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final matches = options.toList();
                  if (matches.isEmpty) return const SizedBox.shrink();
                  final width = MediaQuery.sizeOf(context).width - 40;
                  return Align(
                    alignment: Alignment.topRight,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 300,
                          maxWidth: width,
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: matches.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final option = matches[index];
                            return ListTile(
                              dense: true,
                              title: Text(option.name),
                              subtitle: Text(option.displayCategory),
                              trailing: option.userCreated
                                  ? const Icon(Icons.person_outline, size: 18)
                                  : null,
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (current == null) ...[
                const SizedBox(height: 10),
                Text(
                  'אפשר לחפש לפי שם או קטגוריה.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (current != null && currentUnit != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: currentUnit,
                        decoration: const InputDecoration(
                          labelText: 'מידה',
                          border: OutlineInputBorder(),
                        ),
                        items: current.units.keys
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => unit = value),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 135,
                      child: TextFormField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'כמות',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => setState(() {
                          quantity = double.tryParse(
                                value.replaceAll(',', '.'),
                              ) ??
                              1;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${kosherStatusLabel(current.kosherStatus)}'
                          '${current.kosherStatus == KosherStatus.kosher ? ' · ${kosherLabel(current.type)}' : ''}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'כ־$cal קלוריות · ${protein.toStringAsFixed(1)} גרם חלבון',
                        ),
                        Text(
                          'אומדן משקל: '
                          '${current.gramsFor(currentUnit, quantity).round()} גרם',
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.kosherEnabled &&
                    current.kosherStatus != KosherStatus.kosher) ...[
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        current.kosherStatus == KosherStatus.notKosher
                            ? 'שים לב: המזון מסומן כלא כשר. ניתן לתעד מה שנאכל בפועל, אך הוא לא יוצע אוטומטית.'
                            : 'שים לב: כשרות המזון אינה ידועה. ניתן לתעד מה שנאכל בפועל, אך הוא לא יוצע אוטומטית.',
                      ),
                    ),
                  ),
                ],
                if (current.type == KosherFoodType.dairy &&
                    !state.dairyAllowed) ...[
                  const SizedBox(height: 10),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'שים לב: לפי הגדרת הכשרות האישית שלך טרם הסתיימה ההמתנה מבשר לחלב. '
                        'אפשר לתעד מה שאכלת בפועל, אך האפליקציה לא תציע חלבי בזמן ההמתנה.',
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('meal_save_button'),
                  onPressed: current == null || currentUnit == null
                      ? null
                      : () {
                          state.addFood(current, quantity, currentUnit);
                          Navigator.pop(context);
                        },
                  child: const Text('שמור ביומן'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Iterable<FoodItem> _searchFoods(List<FoodItem> foods, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return const Iterable<FoodItem>.empty();

    final matches = foods.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.categoryDetail.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final aStarts = aName.startsWith(query);
        final bStarts = bName.startsWith(query);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
        return aName.compareTo(bName);
      });

    return matches.take(10);
  }
}
