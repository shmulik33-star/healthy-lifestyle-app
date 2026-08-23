import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../shared/storage/app_local_storage.dart';

class CustomEquipmentItem {
  const CustomEquipmentItem({
    required this.id,
    required this.name,
    required this.category,
    this.categoryDetail = '',
    this.quantity = 1,
    this.notes = '',
    this.available = true,
    this.source = 'manual',
  });

  final String id;
  final String name;
  final String category;
  final String categoryDetail;
  final int quantity;
  final String notes;
  final bool available;
  final String source;

  CustomEquipmentItem copyWith({
    String? name,
    String? category,
    String? categoryDetail,
    int? quantity,
    String? notes,
    bool? available,
    String? source,
  }) =>
      CustomEquipmentItem(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        categoryDetail: categoryDetail ?? this.categoryDetail,
        quantity: quantity ?? this.quantity,
        notes: notes ?? this.notes,
        available: available ?? this.available,
        source: source ?? this.source,
      );

  String get displayCategory =>
      category == 'אחר' && categoryDetail.trim().isNotEmpty
          ? 'אחר · ${categoryDetail.trim()}'
          : category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'categoryDetail': categoryDetail,
        'quantity': quantity,
        'notes': notes,
        'available': available,
        'source': source,
      };

  factory CustomEquipmentItem.fromJson(Map<String, dynamic> json) =>
      CustomEquipmentItem(
        id: json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name']?.toString() ?? '',
        category: json['category']?.toString() ?? 'אחר',
        categoryDetail: json['categoryDetail']?.toString() ?? '',
        quantity: ((json['quantity'] as num?) ?? 1)
            .toInt()
            .clamp(1, 99)
            .toInt(),
        notes: json['notes']?.toString() ?? '',
        available: json['available'] != false,
        source: json['source']?.toString() ?? 'manual',
      );
}

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
    if (previous != null && previous != encoded && _isValid(previous)) {
      await AppLocalStorage.writeString(backupStorageKey, previous);
    }
    await AppLocalStorage.writeString(storageKey, encoded);
  }
}
