import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class NutritionLabelAiSuggestion {
  const NutritionLabelAiSuggestion({
    required this.recognized,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.servingName,
    required this.servingGrams,
    required this.confidence,
    required this.reason,
  });

  final bool recognized;
  final String name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String servingName;
  final double servingGrams;
  final double confidence;
  final String reason;

  factory NutritionLabelAiSuggestion.fromJson(Map<String, dynamic> json) {
    double number(String key, double max) {
      final value = (json[key] as num?)?.toDouble() ??
          double.tryParse(json[key]?.toString() ?? '') ??
          0;
      if (!value.isFinite) return 0;
      return value.clamp(0, max).toDouble();
    }

    final calories = number('caloriesPer100g', 2000);
    final protein = number('proteinPer100g', 100);
    final carbs = number('carbsPer100g', 100);
    final fat = number('fatPer100g', 100);
    final name = json['name']?.toString().trim() ?? '';
    final hasUsefulValue = calories > 0 || protein > 0 || carbs > 0 || fat > 0;

    return NutritionLabelAiSuggestion(
      recognized: json['recognized'] == true && (hasUsefulValue || name.isNotEmpty),
      name: name,
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      servingName: json['servingName']?.toString().trim() ?? '',
      servingGrams: number('servingGrams', 5000),
      confidence: number('confidence', 1),
      reason: json['reason']?.toString().trim() ?? '',
    );
  }
}

class NutritionLabelAiException implements Exception {
  const NutritionLabelAiException(this.message, {this.code = ''});

  final String message;
  final String code;

  @override
  String toString() => message;
}

class NutritionLabelAiService {
  static const _configuredEndpoint = String.fromEnvironment(
    'NUTRITION_LABEL_AI_ENDPOINT',
    defaultValue: '',
  );

  static Uri get endpoint => _configuredEndpoint.trim().isNotEmpty
      ? Uri.parse(_configuredEndpoint.trim())
      : Uri.base.resolve('/api/nutrition-label-recognize');

  static Future<NutritionLabelAiSuggestion> recognize({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    if (imageBytes.isEmpty) {
      throw const NutritionLabelAiException('התמונה ריקה.', code: 'empty_image');
    }
    if (imageBytes.length > 4 * 1024 * 1024) {
      throw const NutritionLabelAiException(
        'התמונה גדולה מדי. אפשר לצלם מחדש מקרוב יותר.',
        code: 'image_too_large',
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
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw const NutritionLabelAiException(
        'לא הצלחתי להגיע לשירות פענוח התווית. אפשר לנסות שוב או להזין ידנית.',
        code: 'network_or_timeout',
      );
    }

    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is Map) decoded = Map<String, dynamic>.from(value);
    } catch (_) {
      // Handled below as an invalid response.
    }

    if (response.statusCode != 200) {
      final serverCode = decoded?['error']?.toString() ??
          'http_${response.statusCode}';
      if (response.statusCode == 413 || serverCode == 'image_too_large') {
        throw const NutritionLabelAiException(
          'התמונה גדולה מדי. אפשר לצלם מחדש מקרוב יותר.',
          code: 'image_too_large',
        );
      }
      if (serverCode == 'unsupported_image_type') {
        throw const NutritionLabelAiException(
          'סוג התמונה אינו נתמך. נסה צילום חדש או תמונת JPG/PNG.',
          code: 'unsupported_image_type',
        );
      }
      throw NutritionLabelAiException(
        'לא הצלחתי לפענח את התווית כרגע. אפשר לנסות שוב או להזין ידנית.',
        code: serverCode,
      );
    }

    if (decoded == null) {
      throw const NutritionLabelAiException(
        'קיבלתי תשובה לא תקינה משירות הפענוח. אפשר לנסות שוב.',
        code: 'invalid_response',
      );
    }

    return NutritionLabelAiSuggestion.fromJson(decoded);
  }
}
