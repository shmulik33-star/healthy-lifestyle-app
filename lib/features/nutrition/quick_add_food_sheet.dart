import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';
import '../../shared/models/food.dart';
import 'add_food_to_catalog_screen.dart';
import 'add_food_to_meal_sheet.dart';
import 'barcode_scanner_screen.dart';
import 'open_food_facts_service.dart';

/// Unified "quick add" entry point for getting a packaged food into the
/// catalog fast, instead of the full 9-field manual form.
///
/// Only the barcode-scan option is wired up in this PR, but the sheet is
/// structured as a list of options precisely so a future PR can add photo
/// capture / free-text lookup by appending another `_QuickAddOptionTile`
/// here -- no redesign of the entry point itself.
class QuickAddFoodSheet extends StatelessWidget {
  const QuickAddFoodSheet({super.key, required this.state});

  final AppState state;

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
              'הדרך המהירה להוסיף מזון ארוז למאגר, בלי למלא טופס שלם.',
            ),
            const SizedBox(height: 14),
            _QuickAddOptionTile(
              key: const Key('quick_add_barcode_option'),
              icon: Icons.qr_code_scanner,
              title: 'סרוק ברקוד',
              subtitle: 'זיהוי אוטומטי של המוצר לפי מאגר Open Food Facts',
              onTap: () => _scanBarcode(context, state),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanBarcode(BuildContext context, AppState state) async {
    // Close this sheet before pushing the scanner, rather than stacking a
    // full-screen camera route on top of a modal sheet.
    Navigator.pop(context);
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || barcode.isEmpty || !context.mounted) return;

    // Local check first, no network: a barcode already in the catalog/
    // custom foods skips straight to "add to meal" instead of the add-food
    // form.
    final existing = state.foodByBarcode(barcode);
    if (existing != null) {
      await showAddFoodToMealSheet(context, state, existing);
      return;
    }

    await _lookUpAndOpenForm(context, state, barcode);
  }

  Future<void> _lookUpAndOpenForm(
    BuildContext context,
    AppState state,
    String barcode,
  ) async {
    unawaited(
      showDialog<void>(
        context: context,
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

    if (!context.mounted) return;
    Navigator.pop(context); // close the loading dialog

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage != null
                ? '$errorMessage אפשר למלא ידנית — בפעם הבאה נזהה את המוצר הזה אוטומטית.'
                : 'לא מצאנו את המוצר הזה במאגר Open Food Facts. אפשר למלא ידנית — בפעם הבאה נזהה אותו אוטומטית.',
          ),
        ),
      );
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AppStateScope(
          state: state,
          child: AddFoodToCatalogScreen(state: state, prefill: prefill),
        ),
      ),
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
