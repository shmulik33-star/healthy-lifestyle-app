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
      recognized: json['recognized'] == true &&
          (json['name']?.toString().trim().isNotEmpty ?? false),
      name: json['name']?.toString().trim() ?? '',
      category: category,
      categoryDetail: category == 'אחר'
          ? json['categoryDetail']?.toString().trim() ?? ''
          : '',
      notes: json['notes']?.toString().trim() ?? '',
      confidence: rawConfidence.clamp(0, 1).toDouble(),
      reason: json['reason']?.toString().trim() ?? '',
    );
  }
}

class EquipmentAiException implements Exception {
  const EquipmentAiException(this.message, {this.code = ''});

  final String message;
  final String code;

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
    http.Client? client,
  }) async {
    if (imageBytes.isEmpty) {
      throw const EquipmentAiException('התמונה ריקה.', code: 'empty_image');
    }
    if (imageBytes.length > 4 * 1024 * 1024) {
      throw const EquipmentAiException(
        'התמונה גדולה מדי לזיהוי. אפשר לצלם מחדש מקרוב יותר.',
        code: 'image_too_large',
      );
    }

    final ownedClient = client == null;
    final httpClient = client ?? http.Client();
    final encodedBody = jsonEncode({
      'imageBase64': base64Encode(imageBytes),
      'mimeType': mimeType,
    });

    try {
      var response = await _post(httpClient, encodedBody);
      var decoded = _decodeResponse(response);

      // Workers AI can occasionally return an empty model payload even though
      // the runtime and AI binding are healthy. Retry this one transient shape
      // once automatically so the user does not have to take the photo again.
      if (response.statusCode != 200 &&
          decoded?['error']?.toString() == 'empty_model_response') {
        response = await _post(httpClient, encodedBody);
        decoded = _decodeResponse(response);
      }

      if (response.statusCode != 200) {
        final serverCode = decoded?['error']?.toString() ??
            'http_${response.statusCode}';
        if (response.statusCode == 413 || serverCode == 'image_too_large') {
          throw const EquipmentAiException(
            'התמונה גדולה מדי לזיהוי. אפשר לצלם מחדש מקרוב יותר.',
            code: 'image_too_large',
          );
        }
        throw EquipmentAiException(
          'שירות הזיהוי לא הצליח לנתח את התמונה. אפשר לנסות שוב או למלא ידנית.',
          code: serverCode,
        );
      }

      if (decoded == null) {
        throw const EquipmentAiException(
          'קיבלתי תשובה לא תקינה משירות הזיהוי. אפשר לנסות שוב.',
          code: 'invalid_response',
        );
      }

      return EquipmentAiSuggestion.fromJson(decoded);
    } on EquipmentAiException {
      rethrow;
    } catch (_) {
      throw const EquipmentAiException(
        'לא הצלחתי להגיע לשירות הזיהוי כרגע. אפשר לנסות שוב או למלא ידנית.',
        code: 'network_or_timeout',
      );
    } finally {
      if (ownedClient) httpClient.close();
    }
  }

  static Future<http.Response> _post(http.Client client, String body) => client
      .post(
        endpoint,
        headers: const {'content-type': 'application/json'},
        body: body,
      )
      .timeout(const Duration(seconds: 45));

  static Map<String, dynamic>? _decodeResponse(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {
      // Handled by the caller as an invalid server response.
    }
    return null;
  }
}
