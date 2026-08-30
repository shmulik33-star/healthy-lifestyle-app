import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';
import 'nutrition_label_ai_service.dart';

/// Logs an AI-estimated home meal (from a plate photo or a free-text
/// description, see [MealEstimateAiService]) straight to "אכלתי" -- no
/// detour through [AddFoodToCatalogScreen]. All fields start from the AI
/// suggestion but stay fully editable: this is an estimate, not a scanned
/// label, so it needs the same "review before saving" treatment as every
/// other AI-filled form in the app (CLAUDE.md golden rule #5).
///
/// [suggestion] must already be `recognized` -- the caller decides what to
/// do with an unrecognized estimate (show an error, let the user retry),
/// this sheet doesn't handle that case.
class QuickLogAiEstimateSheet extends StatefulWidget {
  const QuickLogAiEstimateSheet({
    super.key,
    required this.state,
    required this.suggestion,
  });

  final AppState state;
  final NutritionLabelAiSuggestion suggestion;

  static Future<void> show(
    BuildContext context,
    AppState state,
    NutritionLabelAiSuggestion suggestion,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          QuickLogAiEstimateSheet(state: state, suggestion: suggestion),
    );
  }

  @override
  State<QuickLogAiEstimateSheet> createState() =>
      _QuickLogAiEstimateSheetState();
}

class _QuickLogAiEstimateSheetState extends State<QuickLogAiEstimateSheet> {
  final name = TextEditingController();
  final grams = TextEditingController();
  final calories = TextEditingController();
  final protein = TextEditingController();
  final carbs = TextEditingController();
  final fat = TextEditingController();

  bool fromHome = true;
  bool saveToCatalog = false;
  KosherFoodType? kosherType;
  bool _typeRequiredError = false;

  @override
  void initState() {
    super.initState();
    final suggestion = widget.suggestion;
    name.text = suggestion.name;
    grams.text = _formatNumber(suggestion.servingGrams > 0 ? suggestion.servingGrams : 100);
    calories.text = _formatNumber(suggestion.caloriesPer100g);
    protein.text = _formatNumber(suggestion.proteinPer100g);
    carbs.text = _formatNumber(suggestion.carbsPer100g);
    fat.text = _formatNumber(suggestion.fatPer100g);
  }

  @override
  void dispose() {
    for (final c in [name, grams, calories, protein, carbs, fat]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  double _num(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

  bool get _requiresTypeChoice =>
      widget.state.kosherEnabled && widget.state.meatDairySeparationEnabled;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final gramsValue = _num(grams);
    final caloriesPer100g = _num(calories);
    final proteinPer100g = _num(protein);
    final carbsPer100g = _num(carbs);
    final fatPer100g = _num(fat);
    final totalCalories = (gramsValue * caloriesPer100g / 100).round();
    final totalProtein = gramsValue * proteinPer100g / 100;
    final totalCarbs = gramsValue * carbsPer100g / 100;
    final totalFat = gramsValue * fatPer100g / 100;

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
              Text('אכלתי — הערכת AI', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'זו הערכה, לא תווית סרוקה — אפשר ואפשר לתקן כל שדה לפני השמירה.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'שם המנה',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('quick_log_ai_grams_field'),
                controller: grams,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'כמות (גרם)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _macroField(calories, 'קלוריות ל-100 גרם')),
                  const SizedBox(width: 8),
                  Expanded(child: _macroField(protein, 'חלבון ל-100 גרם')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _macroField(carbs, 'פחמימות ל-100 גרם')),
                  const SizedBox(width: 8),
                  Expanded(child: _macroField(fat, 'שומן ל-100 גרם')),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('כ־$totalCalories קלוריות'),
                      Text('${totalProtein.toStringAsFixed(1)} גרם חלבון'),
                      Text('${totalCarbs.toStringAsFixed(1)} גרם פחמימות'),
                      Text('${totalFat.toStringAsFixed(1)} גרם שומן'),
                    ],
                  ),
                ),
              ),
              if (_requiresTypeChoice) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<KosherFoodType>(
                  key: const Key('quick_log_ai_kosher_type_field'),
                  initialValue: kosherType,
                  decoration: InputDecoration(
                    labelText: 'סוג (בשרי / חלבי / פרווה)',
                    border: const OutlineInputBorder(),
                    errorText: _typeRequiredError ? 'יש לבחור סוג לפני השמירה' : null,
                  ),
                  hint: const Text('בחר סוג'),
                  items: KosherFoodType.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(kosherLabel(v)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    kosherType = v;
                    _typeRequiredError = false;
                  }),
                ),
                if (kosherType == KosherFoodType.dairy && !state.dairyAllowed) ...[
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
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('quick_log_ai_from_home_checkbox'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: fromHome,
                onChanged: (value) => setState(() => fromHome = value ?? true),
                title: const Text('אכלתי מהבית'),
                subtitle: const Text(
                  'בטל אם אכלת בחוץ / הזמנת — לא ינוכה מהמזווה',
                ),
              ),
              CheckboxListTile(
                key: const Key('quick_log_ai_save_to_catalog_checkbox'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: saveToCatalog,
                onChanged: (value) => setState(() => saveToCatalog = value ?? false),
                title: const Text('שמור גם למאגר לפעם הבאה'),
                subtitle: const Text('יווצר פריט קבוע במאגר המזונות שלך'),
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                key: const Key('quick_log_ai_save_button'),
                onPressed: () => _save(context),
                icon: const Icon(Icons.add),
                label: const Text('הוסף ליומן'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroField(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
      );

  void _save(BuildContext context) {
    final trimmedName = name.text.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להזין שם למנה.')),
      );
      return;
    }
    final gramsValue = _num(grams);
    if (gramsValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להזין כמות בגרם גדולה מ-0.')),
      );
      return;
    }
    // Kosher status is never inferred from the AI estimate (CLAUDE.md golden
    // rule #4) -- when meat/dairy separation matters, the user must choose
    // explicitly before this can be saved.
    if (_requiresTypeChoice && kosherType == null) {
      setState(() => _typeRequiredError = true);
      return;
    }
    final effectiveType = kosherType ?? KosherFoodType.pareve;

    final logFood = FoodItem(
      id: 'ai_estimate_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmedName,
      category: 'אחר',
      type: effectiveType,
      kosherStatus: KosherStatus.kosher,
      caloriesPer100g: _num(calories),
      proteinPer100g: _num(protein),
      carbsPer100g: _num(carbs),
      fatPer100g: _num(fat),
      units: const {'גרם': 1},
    );
    widget.state.addFood(logFood, gramsValue, 'גרם', fromHome: fromHome);

    if (saveToCatalog) {
      // Reuses AppState.addCustomFood -- the same single save path the
      // manual/AI-label catalog form uses -- instead of a parallel one.
      widget.state.addCustomFood(
        FoodItem(
          id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
          name: trimmedName,
          category: 'אחר',
          type: effectiveType,
          kosherStatus: KosherStatus.kosher,
          caloriesPer100g: _num(calories),
          proteinPer100g: _num(protein),
          carbsPer100g: _num(carbs),
          fatPer100g: _num(fat),
          units: {'מנה': gramsValue, 'גרם': 1},
          userCreated: true,
        ),
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saveToCatalog
              ? '$trimmedName נוסף ליומן ונשמר גם למאגר'
              : '$trimmedName נוסף ליומן',
        ),
      ),
    );
  }
}
