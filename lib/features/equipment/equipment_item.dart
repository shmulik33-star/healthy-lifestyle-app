import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<List<CustomEquipmentItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <CustomEquipmentItem>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => CustomEquipmentItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .where((e) => e.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return <CustomEquipmentItem>[];
    }
  }

  static Future<void> save(List<CustomEquipmentItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
