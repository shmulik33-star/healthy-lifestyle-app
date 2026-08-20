import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'equipment_ai_service.dart';
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
              const Text(
                'צלם את הציוד או בחר תמונה מהגלריה. ננסה לזהות אותו אוטומטית, ואתה תאשר או תתקן לפני השמירה.',
              ),
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
        maxWidth: 1280,
        imageQuality: 78,
        requestFullMetadata: false,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'לא הצלחתי לפתוח את המצלמה או הגלריה. אפשר לנסות שוב.',
            ),
          ),
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
    final mimeType = image.mimeType ?? _mimeFromName(image.name);
    return showModalBottomSheet<CustomEquipmentItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EquipmentPhotoReviewSheet(
        imageBytes: bytes,
        mimeType: mimeType,
      ),
    );
  }

  static String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class _EquipmentPhotoReviewSheet extends StatefulWidget {
  const _EquipmentPhotoReviewSheet({
    required this.imageBytes,
    required this.mimeType,
  });

  final Uint8List imageBytes;
  final String mimeType;

  @override
  State<_EquipmentPhotoReviewSheet> createState() =>
      _EquipmentPhotoReviewSheetState();
}

class _EquipmentPhotoReviewSheetState
    extends State<_EquipmentPhotoReviewSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _detail = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _notes = TextEditingController();

  String _category = EquipmentStore.categories.first;
  String _error = '';
  String _aiStatus = 'מנסה לזהות את הציוד שבתמונה…';
  String _aiReason = '';
  String _diagnosticCode = '';
  bool _aiLoading = true;
  bool _aiApplied = false;
  double? _confidence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recognize());
  }

  Future<void> _recognize() async {
    if (_aiLoading && _confidence != null) return;
    setState(() {
      _aiLoading = true;
      _aiStatus = 'מנסה לזהות את הציוד שבתמונה…';
      _aiReason = '';
      _diagnosticCode = '';
      _confidence = null;
    });

    try {
      final suggestion = await EquipmentAiService.recognize(
        imageBytes: widget.imageBytes,
        mimeType: widget.mimeType,
      );
      if (!mounted) return;

      setState(() {
        _aiLoading = false;
        _confidence = suggestion.confidence;
        _aiReason = suggestion.reason;

        if (suggestion.recognized && suggestion.name.isNotEmpty) {
          _aiApplied = true;
          _name.text = suggestion.name;
          _category = suggestion.category;
          _detail.text = suggestion.category == 'אחר'
              ? suggestion.categoryDetail
              : '';
          if (suggestion.notes.isNotEmpty) _notes.text = suggestion.notes;
          _aiStatus = 'זיהינו כנראה: ${suggestion.name}';
        } else {
          _aiApplied = false;
          _aiStatus =
              'לא הצלחתי לזהות את הציוד בוודאות. אפשר לנסות שוב או למלא ידנית.';
        }
      });
    } on EquipmentAiException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiLoading = false;
        _aiApplied = false;
        _aiStatus = error.message;
        _diagnosticCode = error.code;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiLoading = false;
        _aiApplied = false;
        _aiStatus =
            'הזיהוי החכם לא זמין כרגע. אפשר לנסות שוב או להמשיך ידנית.';
        _diagnosticCode = 'unexpected_client_error';
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _detail.dispose();
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confidenceLabel = _confidence == null
        ? null
        : '${(_confidence! * 100).round()}%';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
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
                const Chip(
                  avatar: Icon(Icons.auto_awesome, size: 16),
                  label: Text('צילום + AI'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_aiLoading)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      Icon(
                        _aiApplied ? Icons.auto_awesome : Icons.info_outline,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _aiStatus,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (!_aiLoading && confidenceLabel != null) ...[
                            const SizedBox(height: 3),
                            Text('רמת ביטחון משוערת: $confidenceLabel'),
                          ],
                          if (_aiReason.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(_aiReason),
                          ],
                          if (_diagnosticCode.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'קוד אבחון: $_diagnosticCode',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (_aiApplied) ...[
                            const SizedBox(height: 5),
                            const Text(
                              'זו הצעה בלבד. אפשר לתקן כל פרט לפני השמירה.',
                            ),
                          ],
                          if (!_aiLoading && !_aiApplied) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: _recognize,
                              icon: const Icon(Icons.refresh),
                              label: const Text('נסה זיהוי שוב'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'שם הציוד / המכשיר',
                hintText: 'לדוגמה: דאמבלים 8 ק״ג',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_category),
              initialValue: _category,
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
                if (value != null) setState(() => _category = value);
              },
            ),
            if (_category == 'אחר') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _detail,
                decoration: const InputDecoration(
                  labelText: 'פרט סוג ציוד',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'כמות',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'הערות (אופציונלי)',
                hintText: 'לדוגמה: משקל, דרגת התנגדות, מיקום בבית...',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('אשר והוסף ציוד'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('בטל'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final cleanName = _name.text.trim();
    final cleanDetail = _detail.text.trim();
    if (cleanName.isEmpty) {
      setState(() => _error = 'יש להזין שם לציוד.');
      return;
    }
    if (_category == 'אחר' && cleanDetail.isEmpty) {
      setState(() => _error = 'בחרת ״אחר״ — יש לפרט את סוג הציוד.');
      return;
    }

    final count = (int.tryParse(_quantity.text) ?? 1).clamp(1, 99);
    Navigator.pop(
      context,
      CustomEquipmentItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: cleanName,
        category: _category,
        categoryDetail: _category == 'אחר' ? cleanDetail : '',
        quantity: count,
        notes: _notes.text.trim(),
        available: true,
        source: _aiApplied ? 'photo_ai' : 'photo',
      ),
    );
  }
}
