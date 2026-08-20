import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'equipment_item.dart';

class EquipmentAiSuggestion {
  const EquipmentAiSuggestion({
    required this.recognized,
    required this.name,
    required this.category,
    required this.categoryDetail,
    required this.notes,
    required this.confidence,
    required this.reason,
  });

  final bool recognized;
  final String name;
  final String category;
  final String categoryDetail;
  final String notes;
  final double confidence;
  final String reason;

  factory EquipmentAiSuggestion.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category']?.toString().trim() ?? 'אחר';
    final category = EquipmentStore.categories.contains(rawCategory)
        ? rawCategory
        : 'אחר';
    final rawConfidence = (json['confidence'] as num?)?.toDouble() ?? 0;
    return EquipmentAiSuggestion(
      recognized: json['recognized'] == true,
      name: json['name']?.toString().trim() ?? '',
      category: category,
      categoryDetail: json['categoryDetail']?.toString().trim() ?? '',
      notes: json['notes']?.toString().trim() ?? '',
      confidence: rawConfidence.clamp(0, 1).toDouble(),
      reason: json['reason']?.toString().trim() ?? '',
    );
  }
}

class EquipmentAiException implements Exception {
  const EquipmentAiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class EquipmentAiService {
  static const _configuredEndpoint = String.fromEnvironment(
    'EQUIPMENT_AI_ENDPOINT',
    defaultValue: '',
  );

  static Uri get endpoint => _configuredEndpoint.trim().isNotEmpty
      ? Uri.parse(_configuredEndpoint.trim())
      : Uri.base.resolve('/api/equipment-recognize');

  static Future<EquipmentAiSuggestion> recognize({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    if (imageBytes.isEmpty) {
      throw const EquipmentAiException('התמונה ריקה.');
    }
    if (imageBytes.length > 4 * 1024 * 1024) {
      throw const EquipmentAiException(
        'התמונה גדולה מדי לזיהוי. אפשר לצלם מחדש מקרוב יותר.',
      );
    }

    http.Response response;
    try {
      response = await http
          .post(
            endpoint,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'imageBase64': base64Encode(imageBytes),
              'mimeType': mimeType,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const EquipmentAiException(
        'לא הצלחתי להגיע לשירות הזיהוי כרגע. אפשר להמשיך בהזנה ידנית.',
      );
    }

    if (response.statusCode != 200) {
      if (response.statusCode == 413) {
        throw const EquipmentAiException(
          'התמונה גדולה מדי לזיהוי. אפשר לצלם מחדש מקרוב יותר.',
        );
      }
      throw const EquipmentAiException(
        'הזיהוי החכם לא זמין כרגע. אפשר להמשיך בהזנה ידנית.',
      );
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return EquipmentAiSuggestion.fromJson(decoded);
    } catch (_) {
      throw const EquipmentAiException(
        'קיבלתי תשובה לא תקינה מהזיהוי. אפשר להמשיך בהזנה ידנית.',
      );
    }
  }
}
