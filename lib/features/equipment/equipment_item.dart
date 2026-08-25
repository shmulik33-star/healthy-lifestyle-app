import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../shared/models/app_state.dart';
import '../../shared/storage/app_local_storage.dart';

// `CustomEquipmentItem` now lives on `AppState`
// (shared/models/app_state.dart) so custom equipment rides the same
// cloud-sync snapshot + tombstone path as pantry/shopping items — see
// PROJECT_BRIEF.md section 6.6. This re-export keeps every existing
// `import '.../equipment_item.dart'` in feature code and tests working
// unchanged.
export '../../shared/models/app_state.dart' show CustomEquipmentItem;

/// Legacy device-local store. Kept only so a device that already has custom
/// equipment saved here (from before this data moved onto `AppState`) can
/// have it imported once via `AppState.migrateLegacyCustomEquipment` — see
/// `AppShell.initState` in `lib/app/shell.dart`. Nothing writes to this store
/// anymore; `EquipmentScreen` reads/writes `AppState.customEquipment`
/// instead.
class EquipmentStore {
  static const storageKey = 'stage12_custom_equipment_v1';
  static const backupStorageKey = 'stage12_custom_equipment_v1_backup';

  static const categories = <String>[
    'משקולות',
    'מוטות',
    'ספסלים',
    'גומיות התנגדות',
    'קטלבל',
    'מכשירי אירובי',
    'מכשירי כוח',
    'מזרן / אביזרים',
    'אחר',
  ];

  static List<CustomEquipmentItem> _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved equipment is not a JSON list');
    }
    return decoded
        .map(
          (entry) => CustomEquipmentItem.fromJson(
            Map<String, dynamic>.from(entry as Map),
          ),
        )
        .where((item) => item.name.trim().isNotEmpty)
        .toList();
  }

  static bool _isValid(String raw) {
    try {
      _decode(raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<CustomEquipmentItem>> load() async {
    final primary = await AppLocalStorage.readString(storageKey);
    final backup = await AppLocalStorage.readString(backupStorageKey);

    if (primary != null && primary.isNotEmpty) {
      try {
        return _decode(primary);
      } catch (error) {
        debugPrint('EquipmentStore: failed to load primary data: $error');
      }
    }

    if (backup != null && backup.isNotEmpty) {
      try {
        final recovered = _decode(backup);
        await AppLocalStorage.writeString(storageKey, backup);
        debugPrint('EquipmentStore: recovered custom equipment from backup.');
        return recovered;
      } catch (error) {
        debugPrint('EquipmentStore: failed to load backup data: $error');
      }
    }

    return <CustomEquipmentItem>[];
  }

  static Future<void> save(List<CustomEquipmentItem> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    final previous = await AppLocalStorage.readString(storageKey);

    if (previous == null || previous.isEmpty || !_isValid(previous)) {
      await AppLocalStorage.writeString(backupStorageKey, encoded);
    } else if (previous != encoded) {
      await AppLocalStorage.writeString(backupStorageKey, previous);
    }

    await AppLocalStorage.writeString(storageKey, encoded);
  }
}
