import 'package:flutter/material.dart';
import '../../shared/models/app_state.dart';

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('המזווה שלי'),
        actions: [
          IconButton(
            tooltip: 'הוסף מוצר',
            onPressed: () => _edit(context, state),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, state),
        icon: const Icon(Icons.add),
        label: const Text('הוסף מוצר'),
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          final items = [...state.pantryItems]..sort((a, b) {
            if (a.isLow != b.isLow) return a.isLow ? -1 : 1;
            final c = a.category.compareTo(b.category);
            return c != 0 ? c : a.name.compareTo(b.name);
          });
          final groups = <String, List<PantryItem>>{};
          for (final item in items) {
            (groups[item.category] ??= []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'מצב המלאי',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(state.pantryInsight),
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: state.shoppingItems.any((x) => x.checked)
                            ? state.addPurchasedShoppingToPantry
                            : null,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('העבר מוצרים שסומנו “נקנו” למזווה'),
                      ),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'עדיין אין מוצרים במזווה. הוסף מוצר ידנית או העבר מוצרים שנקנו מרשימת הקניות.',
                    ),
                  ),
                ),
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 4),
                  child: Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...entry.value.map(
                  (item) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          item.isLow
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined,
                        ),
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        '${_fmt(item.quantity)} ${item.unit}'
                        '${item.isLow ? ' · מלאי נמוך' : ''}\n'
                        'התראה מתחת ל־${_fmt(item.lowStockThreshold)} ${item.unit}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'plus') {
                            state.updatePantryItem(
                              item,
                              quantity: item.quantity + 1,
                            );
                          }
                          if (v == 'minus') {
                            state.updatePantryItem(
                              item,
                              quantity: (item.quantity - 1)
                                  .clamp(0, double.infinity)
                                  .toDouble(),
                            );
                          }
                          if (v == 'edit') {
                            _edit(context, state, item: item);
                          }
                          if (v == 'delete') {
                            state.deletePantryItem(item);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'plus',
                            child: Text('הוסף 1 למלאי'),
                          ),
                          PopupMenuItem(
                            value: 'minus',
                            child: Text('הפחת 1 מהמלאי'),
                          ),
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('ערוך'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('מחק'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static Future<void> _edit(
    BuildContext context,
    AppState state, {
    PantryItem? item,
  }) async {
    final name = TextEditingController(text: item?.name ?? '');
    final qty = TextEditingController(
      text: item == null ? '1' : _fmt(item.quantity),
    );
    final unit = TextEditingController(text: item?.unit ?? 'יחידות');
    final low = TextEditingController(
      text: item == null ? '1' : _fmt(item.lowStockThreshold),
    );
    var category = item?.category ?? 'אחר';
    final categories = [
      'ירקות ופירות',
      'בשר ועוף',
      'דגים',
      'מוצרי חלב',
      'ביצים',
      'מזווה',
      'קפואים',
      'נשנושים',
      'אחר',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(item == null ? 'הוסף למזווה' : 'עריכת מלאי'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'שם המוצר'),
                ),
                TextField(
                  controller: qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'כמות שיש בבית'),
                ),
                TextField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'יחידה'),
                ),
                TextField(
                  controller: low,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'התראה כשנשאר פחות מ־',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'קטגוריה'),
                  items: categories
                      .map(
                        (x) => DropdownMenuItem(
                          value: x,
                          child: Text(x),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setLocal(() => category = v ?? category),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) return;
                final q =
                    double.tryParse(qty.text.replaceAll(',', '.')) ?? 0;
                final threshold =
                    double.tryParse(low.text.replaceAll(',', '.')) ?? 1;
                final u =
                    unit.text.trim().isEmpty ? 'יחידות' : unit.text.trim();

                if (item == null) {
                  state.addPantryItem(
                    n,
                    q,
                    u,
                    category,
                    lowStockThreshold: threshold,
                  );
                } else {
                  state.updatePantryItem(
                    item,
                    name: n,
                    quantity: q,
                    unit: u,
                    category: category,
                    lowStockThreshold: threshold,
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('שמור'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    qty.dispose();
    unit.dispose();
    low.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
