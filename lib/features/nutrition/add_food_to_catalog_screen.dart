import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';
import 'nutrition_label_ai_service.dart';

class AddFoodToCatalogScreen extends StatefulWidget {
  const AddFoodToCatalogScreen({super.key, required this.state});
  final AppState state;

  @override
  State<AddFoodToCatalogScreen> createState() => _AddFoodToCatalogScreenState();
}

class _AddFoodToCatalogScreenState extends State<AddFoodToCatalogScreen> {
  final name = TextEditingController();
  final categoryDetail = TextEditingController();
  final calories = TextEditingController();
  final protein = TextEditingController();
  final carbs = TextEditingController();
  final fat = TextEditingController();
  final unitName = TextEditingController(text: 'מנה');
  final unitGrams = TextEditingController(text: '100');
  final labelText = TextEditingController();

  String category = 'אחר';
  KosherStatus kosherStatus = KosherStatus.unknown;
  KosherFoodType kosherType = KosherFoodType.pareve;

  Uint8List? _labelImageBytes;
  bool _scanningLabel = false;
  String _aiMessage = '';
  String _aiCode = '';
  double _aiConfidence = 0;

  @override
  void dispose() {
    for (final c in [
      name,
      categoryDetail,
      calories,
      protein,
      carbs,
      fat,
      unitName,
      unitGrams,
      labelText,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  String _mimeTypeFor(XFile file) {
    final reported = file.mimeType?.toLowerCase();
    if (reported == 'image/jpeg' ||
        reported == 'image/png' ||
        reported == 'image/webp') {
      return reported!;
    }
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickLabelPhoto(ImageSource source) async {
    if (_scanningLabel) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _labelImageBytes = bytes;
        _aiMessage = '';
        _aiCode = '';
        _aiConfidence = 0;
      });
      await _recognizeLabel(bytes, _mimeTypeFor(file));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiMessage = 'לא הצלחתי לפתוח את התמונה. אפשר לנסות שוב או להזין ידנית.';
        _aiCode = 'image_pick_failed';
      });
    }
  }

  Future<void> _recognizeLabel(Uint8List bytes, String mimeType) async {
    setState(() {
      _scanningLabel = true;
      _aiMessage = 'מפענח את התווית…';
      _aiCode = '';
      _aiConfidence = 0;
    });

    try {
      final suggestion = await NutritionLabelAiService.recognize(
        imageBytes: bytes,
        mimeType: mimeType,
      );
      if (!mounted) return;

      if (!suggestion.recognized) {
        setState(() {
          _aiMessage = suggestion.reason.isNotEmpty
              ? suggestion.reason
              : 'לא זוהתה טבלת ערכים תזונתיים ברורה. אפשר לצלם מקרוב יותר או להזין ידנית.';
          _aiConfidence = suggestion.confidence;
        });
        return;
      }

      if (name.text.trim().isEmpty && suggestion.name.isNotEmpty) {
        name.text = suggestion.name;
      }
      if (suggestion.caloriesPer100g > 0) {
        calories.text = _formatNumber(suggestion.caloriesPer100g);
      }
      if (suggestion.proteinPer100g > 0) {
        protein.text = _formatNumber(suggestion.proteinPer100g);
      }
      if (suggestion.carbsPer100g > 0) {
        carbs.text = _formatNumber(suggestion.carbsPer100g);
      }
      if (suggestion.fatPer100g > 0) {
        fat.text = _formatNumber(suggestion.fatPer100g);
      }
      if (suggestion.servingName.isNotEmpty && suggestion.servingGrams > 0) {
        unitName.text = suggestion.servingName;
        unitGrams.text = _formatNumber(suggestion.servingGrams);
      }

      setState(() {
        _aiConfidence = suggestion.confidence;
        _aiMessage = suggestion.reason.isNotEmpty
            ? suggestion.reason
            : 'הערכים זוהו והועתקו לטופס. יש לבדוק אותם לפני השמירה.';
      });
    } on NutritionLabelAiException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiMessage = error.message;
        _aiCode = error.code;
      });
    } finally {
      if (mounted) setState(() => _scanningLabel = false);
    }
  }

  void _parseLabel() {
    final text = labelText.text;
    double? find(List<String> keys) {
      for (final key in keys) {
        final re = RegExp(
          '$key[^0-9]{0,15}([0-9]+(?:[.,][0-9]+)?)',
          caseSensitive: false,
        );
        final match = re.firstMatch(text);
        if (match != null) {
          return double.tryParse(match.group(1)!.replaceAll(',', '.'));
        }
      }
      return null;
    }

    final c = find(['קלוריות', 'kcal']);
    final p = find(['חלבון']);
    final cb = find(['פחמימות']);
    final f = find(['שומן']);
    if (c != null) calories.text = _formatNumber(c);
    if (p != null) protein.text = _formatNumber(p);
    if (cb != null) carbs.text = _formatNumber(cb);
    if (f != null) fat.text = _formatNumber(f);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('הפענוח הידני הושלם. יש לבדוק את הנתונים לפני שמירה.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showKosherFields = widget.state.kosherEnabled;
    return Scaffold(
      appBar: AppBar(title: const Text('הוסף מזון למאגר')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'צילום תווית + AI',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'צלם את טבלת הערכים התזונתיים מקרוב. ה־AI יציע ערכים ל־100 גרם, '
                    'אבל לא ישמור דבר לבד — אפשר לתקן הכול לפני הלחיצה על „שמור במאגר”.',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          key: const Key('nutrition_label_camera'),
                          onPressed: _scanningLabel
                              ? null
                              : () => _pickLabelPhoto(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('צלם תווית'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('nutrition_label_gallery'),
                          onPressed: _scanningLabel
                              ? null
                              : () => _pickLabelPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('מהגלריה'),
                        ),
                      ),
                    ],
                  ),
                  if (_labelImageBytes != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        _labelImageBytes!,
                        key: const Key('nutrition_label_preview'),
                        height: 170,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  if (_scanningLabel || _aiMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const Key('nutrition_label_ai_status'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_scanningLabel)
                            const LinearProgressIndicator()
                          else
                            Text(_aiMessage),
                          if (!_scanningLabel && _aiConfidence > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'רמת ביטחון: ${(_aiConfidence * 100).round()}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (!_scanningLabel && _aiCode.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'קוד אבחון: $_aiCode',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),
                  const Text(
                    'אפשר גם להדביק טקסט מהתווית',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelText,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'טקסט מתווית המזון',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _parseLabel,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('פענח טקסט ידנית'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('פרטי המזון', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'שם המזון',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(
              labelText: 'קטגוריה',
              border: OutlineInputBorder(),
            ),
            items: foodCategories
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => category = v ?? 'אחר'),
          ),
          if (category == 'אחר') ...[
            const SizedBox(height: 10),
            TextField(
              controller: categoryDetail,
              decoration: const InputDecoration(
                labelText: 'פרט קטגוריה',
                hintText: 'לדוגמה: מאכלי שבת, אוכל מוכן, תוספות',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (showKosherFields) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<KosherStatus>(
              initialValue: kosherStatus,
              decoration: const InputDecoration(
                labelText: 'מצב כשרות',
                border: OutlineInputBorder(),
              ),
              items: KosherStatus.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(kosherStatusLabel(v)),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => kosherStatus = v ?? KosherStatus.unknown),
            ),
            if (kosherStatus == KosherStatus.kosher) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<KosherFoodType>(
                initialValue: kosherType,
                decoration: const InputDecoration(
                  labelText: 'סיווג כשרותי',
                  border: OutlineInputBorder(),
                ),
                items: KosherFoodType.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(kosherLabel(v)),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => kosherType = v ?? KosherFoodType.pareve),
              ),
            ],
          ],
          const SizedBox(height: 16),
          const Text(
            'ערכים ל־100 גרם',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _num(calories, 'קלוריות')),
              const SizedBox(width: 8),
              Expanded(child: _num(protein, 'חלבון')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _num(carbs, 'פחמימות')),
              const SizedBox(width: 8),
              Expanded(child: _num(fat, 'שומן')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'מידה ביתית ראשונה',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: unitName,
                  decoration: const InputDecoration(
                    labelText: 'שם המידה',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _num(unitGrams, 'גרם למידה')),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('שמור במאגר'),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  void _save() {
    final n = name.text.trim();
    if (n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להזין שם מזון.')),
      );
      return;
    }
    final detail = categoryDetail.text.trim();
    if (category == 'אחר' && detail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('בחרת „אחר”. יש לפרט את הקטגוריה.')),
      );
      return;
    }
    final grams = double.tryParse(unitGrams.text.replaceAll(',', '.')) ?? 100;
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    final food = FoodItem(
      id: id,
      name: n,
      category: category,
      categoryDetail: category == 'אחר' ? detail : '',
      type: kosherType,
      kosherStatus: kosherStatus,
      caloriesPer100g:
          double.tryParse(calories.text.replaceAll(',', '.')) ?? 0,
      proteinPer100g: double.tryParse(protein.text.replaceAll(',', '.')) ?? 0,
      carbsPer100g: double.tryParse(carbs.text.replaceAll(',', '.')) ?? 0,
      fatPer100g: double.tryParse(fat.text.replaceAll(',', '.')) ?? 0,
      units: {
        unitName.text.trim().isEmpty ? 'מנה' : unitName.text.trim(): grams,
        'גרם': 1,
      },
      userCreated: true,
    );
    widget.state.addCustomFood(food);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$n נוסף למאגר')),
    );
    Navigator.pop(context);
  }
}
