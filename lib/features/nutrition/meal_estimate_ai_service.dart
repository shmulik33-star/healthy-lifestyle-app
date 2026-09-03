import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'nutrition_label_ai_service.dart';

class MealEstimateAiException implements Exception {
  const MealEstimateAiException(this.message, {this.code = ''});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// AI estimation for a home-cooked / unpackaged meal, from either a plate
/// photo or a free-text description -- as opposed to [NutritionLabelAiService],
/// which reads a packaged product's printed nutrition label. Both return the
/// same [NutritionLabelAiSuggestion] shape (values per 100g + an estimated
/// serving), so the rest of the app treats an AI meal estimate exactly like
/// an AI label read: a prefill to review and correct, never auto-saved.
class MealEstimateAiService {
  static const _configuredEndpoint = String.fromEnvironment(
    'MEAL_ESTIMATE_AI_ENDPOINT',
    defaultValue: '',
  );

  static Uri get endpoint => _configuredEndpoint.trim().isNotEmpty
      ? Uri.parse(_configuredEndpoint.trim())
      : Uri.base.resolve('/api/meal-estimate');

  static Future<NutritionLabelAiSuggestion> estimateFromImage({
    required Uint8List imageBytes,
    required String mimeType,
    http.Client? client,
  }) async {
    if (imageBytes.isEmpty) {
      throw const MealEstimateAiException('התמונה ריקה.', code: 'empty_image');
    }
    if (imageBytes.length > 4 * 1024 * 1024) {
      throw const MealEstimateAiException(
        'התמונה גדולה מדי. אפשר לצלם מחדש מקרוב יותר.',
        code: 'image_too_large',
      );
    }

    return _run(
      client,
      jsonEncode({
        'imageBase64': base64Encode(imageBytes),
        'mimeType': mimeType,
      }),
    );
  }

  static Future<NutritionLabelAiSuggestion> estimateFromText({
    required String text,
    http.Client? client,
  }) async {
    final trimmed = text.trim();
    if (trimmed.length < 2) {
      throw const MealEstimateAiException(
        'התיאור קצר מדי. אפשר לתאר את הארוחה בכמה מילים נוספות.',
        code: 'text_too_short',
      );
    }

    return _run(client, jsonEncode({'text': trimmed}));
  }

  static Future<NutritionLabelAiSuggestion> _run(
    http.Client? client,
    String encodedBody,
  ) async {
    final ownedClient = client == null;
    final httpClient = client ?? http.Client();

    try {
      http.Response response;
      try {
        response = await httpClient
            .post(
              endpoint,
              headers: const {'content-type': 'application/json'},
              body: encodedBody,
            )
            .timeout(const Duration(seconds: 90));
      } catch (_) {
        throw const MealEstimateAiException(
          'לא הצלחתי להגיע לשירות ההערכה כרגע. אפשר לנסות שוב או להזין ידנית.',
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
        final serverCode =
            decoded?['error']?.toString() ?? 'http_${response.statusCode}';
        if (response.statusCode == 413 || serverCode == 'image_too_large') {
          throw const MealEstimateAiException(
            'התמונה גדולה מדי. אפשר לצלם מחדש מקרוב יותר.',
            code: 'image_too_large',
          );
        }
        if (serverCode == 'unsupported_image_type') {
          throw const MealEstimateAiException(
            'סוג התמונה אינו נתמך. נסה צילום חדש או תמונת JPG/PNG.',
            code: 'unsupported_image_type',
          );
        }
        throw MealEstimateAiException(
          'לא הצלחתי להעריך את הארוחה כרגע. אפשר לנסות שוב או להזין ידנית.',
          code: serverCode,
        );
      }

      if (decoded == null) {
        throw const MealEstimateAiException(
          'קיבלתי תשובה לא תקינה משירות ההערכה. אפשר לנסות שוב.',
          code: 'invalid_response',
        );
      }

      try {
        return NutritionLabelAiSuggestion.fromJson(decoded);
      } catch (_) {
        // Same reasoning as NutritionLabelAiService.recognize: a malformed
        // field must surface as our typed exception, not a raw TypeError --
        // _runEstimateAndOpenLogSheet only catches MealEstimateAiException,
        // so anything else propagates uncaught and leaves its loading
        // dialog stuck on screen forever instead of showing an error.
        throw const MealEstimateAiException(
          'קיבלתי תשובה לא תקינה משירות ההערכה. אפשר לנסות שוב.',
          code: 'invalid_response',
        );
      }
    } finally {
      if (ownedClient) httpClient.close();
    }
  }
}
