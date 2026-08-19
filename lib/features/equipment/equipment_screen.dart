import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';
import 'equipment_item.dart';
import 'equipment_workout.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  List<CustomEquipmentItem> _custom = <CustomEquipmentItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCustom();
  }

  Future<void> _loadCustom() async {
    final items = await EquipmentStore.load();
    if (!mounted) return;
    setState(() {
      _custom = items;
      _loading = false;
    });
  }

  Future<void> _saveCustom() => EquipmentStore.save(_custom);

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('הציוד שלי')),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const Text(
              'סמן את המכשירים והציוד שבאמת זמינים לך. האימון ייבנה לפי הציוד שסימנת וגם לפי ציוד שתוסיף בעצמך.',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('הוסף ציוד'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showPhotoBeta,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('הוסף בצילום'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('ציוד מובנה', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: state.equipment.entries
                    .map(
                      (entry) => CheckboxListTile(
                        value: entry.value,
                        title: Text(entry.key),
                        onChanged: (value) =>
                            state.toggleEquipment(entry.key, value ?? false),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ציוד שהוספתי',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_custom.isNotEmpty)
                  Text(
                    '${_custom.where((e) => e.available).length}/${_custom.length} זמין',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_custom.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.fitness_center_outlined, size: 34),
                      const SizedBox(height: 8),
                      const Text('עדיין לא הוספת ציוד משלך.'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('הוסף את המכשיר הראשון'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._custom.map(_customEquipmentCard),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('סיימתי'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customEquipmentCard(CustomEquipmentItem item) {
    final affectsWorkout = EquipmentWorkoutBuilder.canSuggestExercise(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: item.available,
                onChanged: (value) => _setAvailable(item, value ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text('${item.displayCategory} · כמות ${item.quantity}'),
                      if (item.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(item.notes.trim()),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        affectsWorkout
                            ? '✓ יכול להשתלב אוטומטית באימון'
                            : 'נשמר כציוד זמין; התאמת תרגיל אוטומטית תתווסף בהמשך',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _openEditor(existing: item);
                  if (value == 'delete') _confirmDelete(item);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('ערוך')),
                  PopupMenuItem(value: 'delete', child: Text('מחק')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setAvailable(CustomEquipmentItem item, bool value) async {
    final index = _custom.indexWhere((e) => e.id == item.id);
    if (index < 0) return;
    setState(() => _custom[index] = item.copyWith(available: value));
    await _saveCustom();
  }

  Future<void> _openEditor({CustomEquipmentItem? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final detail = TextEditingController(text: existing?.categoryDetail ?? '');
    final quantity = TextEditingController(text: '${existing?.quantity ?? 1}');
    final notes = TextEditingController(text: existing?.notes ?? '');
    var category = existing?.category ?? EquipmentStore.categories.first;
    var error = '';

    final result = await showModalBottomSheet<CustomEquipmentItem>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            18,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? 'הוספת ציוד' : 'עריכת ציוד',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'שם הציוד / המכשיר',
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
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setSheetState(() => category = value);
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
                    hintText: 'לדוגמה: דאמבלים 5 ק״ג, גומייה בינונית...',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    final cleanName = name.text.trim();
                    final cleanDetail = detail.text.trim();
                    if (cleanName.isEmpty) {
                      setSheetState(() => error = 'יש להזין שם לציוד.');
                      return;
                    }
                    if (category == 'אחר' && cleanDetail.isEmpty) {
                      setSheetState(() => error = 'בחרת ״אחר״ — יש לפרט את סוג הציוד.');
                      return;
                    }
                    final count = (int.tryParse(quantity.text) ?? 1).clamp(1, 99);
                    Navigator.pop(
                      sheetContext,
                      CustomEquipmentItem(
                        id: existing?.id ??
                            DateTime.now().microsecondsSinceEpoch.toString(),
                        name: cleanName,
                        category: category,
                        categoryDetail: category == 'אחר' ? cleanDetail : '',
                        quantity: count,
                        notes: notes.text.trim(),
                        available: existing?.available ?? true,
                        source: existing?.source ?? 'manual',
                      ),
                    );
                  },
                  child: Text(existing == null ? 'הוסף ציוד' : 'שמור שינויים'),
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

    if (result == null || !mounted) return;
    setState(() {
      final index = _custom.indexWhere((e) => e.id == result.id);
      if (index >= 0) {
        _custom[index] = result;
      } else {
        _custom.add(result);
      }
    });
    await _saveCustom();
  }

  Future<void> _confirmDelete(CustomEquipmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מחיקת ציוד'),
        content: Text('למחוק את ״${item.name}״ מרשימת הציוד שלך?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('מחק'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _custom.removeWhere((e) => e.id == item.id));
    await _saveCustom();
  }

  Future<void> _showPhotoBeta() async {
    final continueManually = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 28,
              child: Icon(Icons.photo_camera_outlined, size: 28),
            ),
            const SizedBox(height: 12),
            Text('הוספה בצילום · Beta', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'מסלול הצילום כבר נמצא באפליקציה. בשלב הבא נחבר זיהוי תמונה שיציע את שם המכשיר והקטגוריה, ורק לאחר אישור שלך הציוד יישמר.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'כרגע אפשר להמשיך מכאן לטופס ההוספה הידני ולא לאבד את האפשרות להוסיף ציוד שאינו ברשימה.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(sheetContext, true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('המשך להוספה ידנית'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('סגור'),
            ),
          ],
        ),
      ),
    );
    if (continueManually == true && mounted) await _openEditor();
  }
}
