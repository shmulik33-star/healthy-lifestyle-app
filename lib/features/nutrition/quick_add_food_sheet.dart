import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';
import 'add_food_to_catalog_screen.dart';
import 'add_food_to_meal_sheet.dart';
import 'barcode_scanner_screen.dart';
import 'meal_estimate_ai_service.dart';
import 'nutrition_label_ai_service.dart';
import 'open_food_facts_service.dart';
import 'quick_log_ai_estimate_sheet.dart';

/// How the barcode-scan option gets a barcode back. The real implementation
/// pushes [BarcodeScannerScreen] (a live camera); tests substitute a
/// function that hands back a barcode directly, so the pop -> scan ->
/// continue-navigating sequence in [QuickAddFoodSheet._scanBarcode] itself
/// gets exercised without needing real camera hardware.
typedef BarcodeScan = Future<String?> Function(NavigatorState navigator);

Future<String?> _pushBarcodeScanner(NavigatorState navigator) =>
    navigator.push<String>(
      MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
    );

/// Unified "quick add" entry point with two kinds of shortcuts:
/// - Packaged food (barcode scan, via Open Food Facts) -- goes to the
///   catalog form to review before it's saved.
/// - Home-cooked / unpackaged meals (a plate photo or a free-text
///   description, both via AI estimate) -- these skip the catalog form
///   entirely and go straight to logging "אכלתי" (see
///   [QuickLogAiEstimateSheet]), since a one-off home meal isn't a catalog
///   item the way a packaged product is.
/// Structured as a list of options so a future PR can add more without
/// redesigning the entry point itself.
class QuickAddFoodSheet extends StatelessWidget {
  const QuickAddFoodSheet({
    super.key,
    required this.state,
    this.scanBarcode = _pushBarcodeScanner,
  });

  final AppState state;
  final BarcodeScan scanBarcode;

  static Future<void> show(BuildContext context, AppState state) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickAddFoodSheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('הוסף מהיר', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'מזון ארוז — סריקה ישר למאגר. ארוחה ביתית — הערכת AI ישר ליומן.',
            ),
            const SizedBox(height: 14),
            _QuickAddOptionTile(
              key: const Key('quick_add_barcode_option'),
              icon: Icons.qr_code_scanner,
              title: 'סרוק ברקוד',
              subtitle: 'זיהוי אוטומטי של המוצר לפי מאגר Open Food Facts',
              onTap: () => _scanBarcode(context, state),
            ),
            const SizedBox(height: 8),
            _QuickAddOptionTile(
              key: const Key('quick_add_photo_option'),
              icon: Icons.restaurant_outlined,
              title: 'צלם צלחת',
              subtitle: 'הערכת AI לארוחה ביתית לפי תמונה, ישר ליומן',
              onTap: () => _photoEstimate(context, state),
            ),
            const SizedBox(height: 8),
            _QuickAddOptionTile(
              key: const Key('quick_add_describe_option'),
              icon: Icons.edit_note_outlined,
              title: 'הקלד תיאור',
              subtitle: 'הערכת AI לארוחה ביתית לפי תיאור חופשי, ישר ליומן',
              onTap: () => _textEstimate(context, state),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanBarcode(BuildContext context, AppState state) async {
    // Resolve the app's shared NavigatorState *before* popping this sheet.
    // `context` itself belongs to the sheet and is torn down once it
    // closes, so using it again after the scan (which can take several
    // seconds) would find `context.mounted == false` and silently no-op --
    // exactly the bug this fixes. `navigator` belongs to the app's
    // persistent Navigator and stays valid for the rest of this flow.
    final navigator = Navigator.of(context);
    navigator.pop();
    final barcode = await scanBarcode(navigator);
    if (barcode == null || barcode.isEmpty || !navigator.mounted) return;

    // Local check first, no network: a barcode already in the catalog/
    // custom foods skips straight to "add to meal" instead of the add-food
    // form.
    final existing = state.foodByBarcode(barcode);
    if (existing != null) {
      await showAddFoodToMealSheet(navigator.context, state, existing);
      return;
    }

    await _lookUpAndOpenForm(navigator, state, barcode);
  }

  Future<void> _lookUpAndOpenForm(
    NavigatorState navigator,
    AppState state,
    String barcode,
  ) async {
    unawaited(
      showDialog<void>(
        context: navigator.context,
        // showDialog defaults to the ROOT navigator, but `navigator` here is
        // whichever (branch) Navigator go_router's StatefulShellRoute gave
        // this tab -- without this, the dialog opens on a different
        // Navigator than the one `navigator.pop()` below actually closes,
        // so it never visibly goes away (this is exactly what broke after
        // the go_router migration: same code, but root and nearest
        // Navigator used to always be the same single Navigator).
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('בודק מול Open Food Facts…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    OpenFoodFactsProduct? product;
    String? errorMessage;
    try {
      product = await OpenFoodFactsService.lookup(barcode);
    } on OpenFoodFactsException catch (error) {
      errorMessage = error.message;
    }

    if (!navigator.mounted) return;
    navigator.pop(); // close the loading dialog

    // Prefill only -- AddFoodToCatalogScreen never saves on its own (same
    // rule as the nutrition-label AI flow), and kosher status is
    // deliberately left at its unknown/manual default here rather than
    // copied from anything Open Food Facts reports (see CLAUDE.md golden
    // rule #4: kosher status is never inferred from an external source).
    final prefill = FoodItem(
      id: '',
      name: product?.name ?? '',
      category: 'אחר',
      type: KosherFoodType.pareve,
      kosherStatus: KosherStatus.unknown,
      caloriesPer100g: product?.caloriesPer100g ?? 0,
      proteinPer100g: product?.proteinPer100g ?? 0,
      carbsPer100g: product?.carbsPer100g ?? 0,
      fatPer100g: product?.fatPer100g ?? 0,
      units: const {'מנה': 100},
      barcode: barcode,
    );

    if (product?.found != true) {
      ScaffoldMessenger.of(navigator.context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage != null
                ? '$errorMessage אפשר למלא ידנית — בפעם הבאה נזהה את המוצר הזה אוטומטית.'
                : 'לא מצאנו את המוצר הזה במאגר Open Food Facts. אפשר למלא ידנית — בפעם הבאה נזהה אותו אוטומטית.',
          ),
        ),
      );
    }

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AppStateScope(
          state: state,
          child: AddFoodToCatalogScreen(state: state, prefill: prefill),
        ),
      ),
    );
  }

  Future<void> _photoEstimate(BuildContext context, AppState state) async {
    final navigator = Navigator.of(context);
    navigator.pop();

    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 82,
      );
    } catch (_) {
      file = null;
    }
    if (file == null || !navigator.mounted) return;

    final bytes = await file.readAsBytes();
    if (!navigator.mounted) return;
    final mimeType = _mimeTypeFor(file);

    await _runEstimateAndOpenLogSheet(
      navigator,
      state,
      () => MealEstimateAiService.estimateFromImage(
        imageBytes: bytes,
        mimeType: mimeType,
      ),
    );
  }

  Future<void> _textEstimate(BuildContext context, AppState state) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (!navigator.mounted) return;

    final description = await showDialog<String>(
      context: navigator.context,
      // Keep every dialog in this flow on the same (branch) Navigator as
      // `navigator` -- see the comment on the loading dialog in
      // _lookUpAndOpenForm for why this matters.
      useRootNavigator: false,
      builder: (_) => const _DescribeMealDialog(),
    );
    if (description == null || description.trim().isEmpty || !navigator.mounted) {
      return;
    }

    await _runEstimateAndOpenLogSheet(
      navigator,
      state,
      () => MealEstimateAiService.estimateFromText(text: description),
    );
  }

  /// Shared by both the photo and free-text estimate flows: runs the AI
  /// call behind a loading dialog, then either surfaces an error (network
  /// failure or a too-vague photo/description) or opens
  /// [QuickLogAiEstimateSheet] straight to "אכלתי" -- never through
  /// [AddFoodToCatalogScreen].
  Future<void> _runEstimateAndOpenLogSheet(
    NavigatorState navigator,
    AppState state,
    Future<NutritionLabelAiSuggestion> Function() run,
  ) async {
    unawaited(
      showDialog<void>(
        context: navigator.context,
        // See the comment on the loading dialog in _lookUpAndOpenForm --
        // same fix, same reason: this must land on the same (branch)
        // Navigator that `navigator.pop()` below actually closes.
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('מעריך את הארוחה…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    NutritionLabelAiSuggestion? suggestion;
    String? errorMessage;
    try {
      suggestion = await run();
    } on MealEstimateAiException catch (error) {
      errorMessage = error.message;
    }

    if (!navigator.mounted) return;
    navigator.pop(); // close the loading dialog

    if (suggestion == null || !suggestion.recognized) {
      ScaffoldMessenger.of(navigator.context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage ??
                (suggestion != null && suggestion.reason.isNotEmpty
                    ? suggestion.reason
                    : 'לא הצלחנו להעריך את הארוחה. אפשר לנסות שוב או לתעד ידנית.'),
          ),
        ),
      );
      return;
    }

    await QuickLogAiEstimateSheet.show(navigator.context, state, suggestion);
  }

  static String _mimeTypeFor(XFile file) {
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
}

class _DescribeMealDialog extends StatefulWidget {
  const _DescribeMealDialog();

  @override
  State<_DescribeMealDialog> createState() => _DescribeMealDialogState();
}

class _DescribeMealDialogState extends State<_DescribeMealDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('מה אכלת?'),
      content: TextField(
        key: const Key('quick_add_meal_description_field'),
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'לדוגמה: קערת אורז עם עדשים וסלט ירקות',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ביטול'),
        ),
        FilledButton(
          key: const Key('quick_add_meal_description_continue'),
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('המשך'),
        ),
      ],
    );
  }
}

class _QuickAddOptionTile extends StatelessWidget {
  const _QuickAddOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
