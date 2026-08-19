import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'equipment_item.dart';

class EquipmentPhotoFlow {
  static final ImagePicker _picker = ImagePicker();

  static Future<CustomEquipmentItem?> open(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'הוסף ציוד בצילום',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text('בחר אם לצלם עכשיו או להשתמש בתמונה שכבר נמצאת בטלפון.'),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('צלם עכשיו'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('בחר מהגלריה'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('ביטול'),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !context.mounted) return null;

    XFile? image;
    try {
      image = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא הצלחתי לפתוח את המצלמה או הגלריה. אפשר לנסות שוב.')),
        );
      }
      return null;
    }

    if (image == null || !context.mounted) return null;

    Uint8List bytes;
    try {
      bytes = await image.readAsBytes();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא הצלחתי לקרוא את התמונה שנבחרה.')),
        );
      }
      return null;
    }

    if (!context.mounted) return null;
    return _review(context, bytes);
  }

  static Future<CustomEquipmentItem?> _review(
    BuildContext context,
    Uint8List imageBytes,
  ) async {
    final name = TextEditingController();
    final detail = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final notes = TextEditingController();
    var category = EquipmentStore.categories.first;
    var error = '';

    final result = await showModalBottomSheet<CustomEquipmentItem>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'אישור הציוד שבתמונה',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const Chip(label: Text('צילום')),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'בשלב הזה התמונה משמשת לאישור חזותי. מלא את שם הציוד והקטגוריה; בשלב ה־AI המערכת תציע אותם אוטומטית מתוך אותה תמונה.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'שם הציוד / המכשיר',
                    hintText: 'לדוגמה: דאמבלים 8 ק״ג',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'קטגוריה',
                    border: OutlineInputBorder(),
                  ),
                  items: EquipmentStore.categories
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => category = value);
                    }
                  },
                ),
                if (category == 'אחר') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: detail,
                    decoration: const InputDecoration(
                      labelText: 'פרט סוג ציוד',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'כמות',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'הערות (אופציונלי)',
                    hintText: 'לדוגמה: משקל, דרגת התנגדות, מיקום בבית...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    final cleanName = name.text.trim();
                    final cleanDetail = detail.text.trim();
                    if (cleanName.isEmpty) {
                      setSheetState(() => error = 'יש להזין שם לציוד.');
                      return;
                    }
                    if (category == 'אחר' && cleanDetail.isEmpty) {
                      setSheetState(
                        () => error = 'בחרת ״אחר״ — יש לפרט את סוג הציוד.',
                      );
                      return;
                    }
                    final count = (int.tryParse(quantity.text) ?? 1).clamp(1, 99);
                    Navigator.pop(
                      sheetContext,
                      CustomEquipmentItem(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        name: cleanName,
                        category: category,
                        categoryDetail: category == 'אחר' ? cleanDetail : '',
                        quantity: count,
                        notes: notes.text.trim(),
                        available: true,
                        source: 'photo',
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('אשר והוסף ציוד'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('בטל'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    name.dispose();
    detail.dispose();
    quantity.dispose();
    notes.dispose();
    return result;
  }
}
