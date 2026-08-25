// Custom equipment used to live only in the local-only EquipmentStore
// (features/equipment/equipment_item.dart), untouched by cloud sync — see
// PROJECT_BRIEF.md section 6.6. It now lives on AppState like pantry/shopping
// items. These tests cover the public API added for that: add/update/delete
// with tombstones, local persistence round-trip, and one-time migration of
// pre-existing local data.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('upsertCustomEquipmentItem adds a new item by id', () {
    final state = AppState();
    state.upsertCustomEquipmentItem(
      const CustomEquipmentItem(
        id: 'equip-1',
        name: 'משקולת יד 5 ק״ג',
        category: 'משקולות',
      ),
    );

    expect(state.customEquipment, hasLength(1));
    expect(state.customEquipment.single.name, 'משקולת יד 5 ק״ג');
  });

  test('upsertCustomEquipmentItem replaces the existing item with the same id', () {
    final state = AppState();
    state.upsertCustomEquipmentItem(
      const CustomEquipmentItem(
        id: 'equip-1',
        name: 'משקולת יד 5 ק״ג',
        category: 'משקולות',
        available: true,
      ),
    );
    state.upsertCustomEquipmentItem(
      const CustomEquipmentItem(
        id: 'equip-1',
        name: 'משקולת יד 5 ק״ג',
        category: 'משקולות',
        available: false,
        notes: 'תפוסה כרגע',
      ),
    );

    expect(state.customEquipment, hasLength(1));
    expect(state.customEquipment.single.available, isFalse);
    expect(state.customEquipment.single.notes, 'תפוסה כרגע');
  });

  test('deleteCustomEquipmentItem removes the item and records a tombstone', () {
    final state = AppState();
    const item = CustomEquipmentItem(
      id: 'equip-1',
      name: 'ספסל',
      category: 'ספסלים',
    );
    state.upsertCustomEquipmentItem(item);
    state.deleteCustomEquipmentItem(item);

    expect(state.customEquipment, isEmpty);
    expect(state.deletedCustomEquipmentIds, contains('equip-1'));
  });

  test('custom equipment and its tombstones survive a local save/load round-trip', () async {
    // upsert/delete trigger AppState._save() without awaiting it (same
    // fire-and-forget pattern as addPantryItem/deletePantryItem). Firing
    // several of these back-to-back races their writes to the same storage
    // key — whichever finishes last wins, which isn't necessarily the last
    // one called. Flushing the microtask queue after each mutation lets each
    // save land before the next one starts, so they apply in order.
    final state = AppState();
    state.upsertCustomEquipmentItem(
      const CustomEquipmentItem(
        id: 'equip-1',
        name: 'TRX',
        category: 'גומיות התנגדות',
        source: 'photo_ai',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    const deletedItem = CustomEquipmentItem(
      id: 'equip-2',
      name: 'מכשיר ישן',
      category: 'אחר',
    );
    state.upsertCustomEquipmentItem(deletedItem);
    await Future<void>.delayed(Duration.zero);

    state.deleteCustomEquipmentItem(deletedItem);
    await Future<void>.delayed(Duration.zero);

    final reloaded = await AppState.load();

    expect(reloaded.customEquipment, hasLength(1));
    expect(reloaded.customEquipment.single.id, 'equip-1');
    expect(reloaded.customEquipment.single.source, 'photo_ai');
    expect(reloaded.deletedCustomEquipmentIds, contains('equip-2'));
  });

  test(
      'migrateLegacyCustomEquipment imports pre-existing local equipment exactly once',
      () {
    final state = AppState();
    const legacyItem = CustomEquipmentItem(
      id: 'legacy-1',
      name: 'קטלבל 12 ק״ג',
      category: 'קטלבל',
    );

    state.migrateLegacyCustomEquipment([legacyItem]);
    expect(state.customEquipment, hasLength(1));
    expect(state.customEquipment.single.id, 'legacy-1');

    // A second call (e.g. app restart) must not duplicate the item, and must
    // not resurrect one the user has since deleted. Guarded by
    // customEquipmentMigrated, not by "customEquipment is empty" — the list
    // IS empty again right here, which is exactly the case that must not
    // trigger a re-import.
    state.deleteCustomEquipmentItem(legacyItem);
    state.migrateLegacyCustomEquipment([legacyItem]);
    expect(state.customEquipment, isEmpty);
  });

  test(
      'migrateLegacyCustomEquipment does not resurrect a deleted item across a real app restart',
      () async {
    // Same scenario as above, but through an actual local save/load cycle
    // (shell.dart calls EquipmentStore.load() + migrateLegacyCustomEquipment
    // fresh on every app start) rather than reusing one in-memory AppState —
    // this is the scenario the "is empty" heuristic actually broke.
    final state = AppState();
    const legacyItem = CustomEquipmentItem(
      id: 'legacy-1',
      name: 'קטלבל 12 ק״ג',
      category: 'קטלבל',
    );
    state.migrateLegacyCustomEquipment([legacyItem]);
    await Future<void>.delayed(Duration.zero);

    state.deleteCustomEquipmentItem(legacyItem);
    await Future<void>.delayed(Duration.zero);

    // Simulate the next app start: a fresh AppState loaded from local
    // storage, then shell.dart's migration call fires again with the same
    // (never-cleared) legacy EquipmentStore contents.
    final restarted = await AppState.load();
    restarted.migrateLegacyCustomEquipment([legacyItem]);

    expect(restarted.customEquipment, isEmpty);
  });

  test('migrateLegacyCustomEquipment is a no-op when nothing legacy exists', () {
    final state = AppState();
    state.migrateLegacyCustomEquipment(const []);
    expect(state.customEquipment, isEmpty);
  });

  test('CustomEquipmentItem round-trips through toJson/fromJson', () {
    const item = CustomEquipmentItem(
      id: 'equip-3',
      name: 'מוט משקולות אולימפי',
      category: 'מוטות',
      categoryDetail: '',
      quantity: 2,
      notes: 'אורך 220 ס״מ',
      available: false,
      source: 'photo',
    );

    final decoded = CustomEquipmentItem.fromJson(
      jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
    );

    expect(decoded.id, item.id);
    expect(decoded.name, item.name);
    expect(decoded.category, item.category);
    expect(decoded.quantity, item.quantity);
    expect(decoded.notes, item.notes);
    expect(decoded.available, item.available);
    expect(decoded.source, item.source);
  });
}
