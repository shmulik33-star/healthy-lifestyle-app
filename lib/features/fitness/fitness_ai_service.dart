import 'dart:convert';

import 'package:http/http.dart' as http;

class FitnessAiException implements Exception {
  const FitnessAiException(this.message, {this.code = ''});
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// AI fitness planner, backed by functions/api/fitness-plan.ts. Mirrors
/// CoachAiService/MealEstimateAiService's injectable-http.Client design
/// (needed for the mocked-http tests below). Returns catalog exercise ids
/// only -- never names, sets, reps or images, which stay entirely
/// client-side (see ExerciseCatalogItem in app_state.dart) so the AI can
/// never introduce an exercise or a rep scheme the app doesn't already know.
class FitnessAiService {
  static const _configuredEndpoint = String.fromEnvironment(
    'FITNESS_AI_ENDPOINT',
    defaultValue: '',
  );

  static Uri get endpoint => _configuredEndpoint.trim().isNotEmpty
      ? Uri.parse(_configuredEndpoint.trim())
      : Uri.base.resolve('/api/fitness-plan');

  static Future<List<String>> pickWorkout({
    required Map<String, dynamic> context,
    required List<Map<String, dynamic>> catalog,
    http.Client? client,
  }) async {
    if (catalog.isEmpty) {
      throw const FitnessAiException('אין תרגילים זמינים לציוד שסימנת.', code: 'empty_catalog');
    }

    final ownedClient = client == null;
    final httpClient = client ?? http.Client();

    try {
      http.Response response;
      try {
        response = await httpClient
            .post(
              endpoint,
              headers: const {'content-type': 'application/json'},
              body: jsonEncode({'context': context, 'catalog': catalog}),
            )
            .timeout(const Duration(seconds: 45));
      } catch (_) {
        throw const FitnessAiException(
          'לא הצלחתי להגיע למאמן הכושר כרגע.',
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
        throw FitnessAiException(
          'לא הצלחתי להגיע למאמן הכושר כרגע.',
          code: serverCode,
        );
      }

      if (decoded == null) {
        throw const FitnessAiException(
          'קיבלתי תשובה לא תקינה ממאמן הכושר.',
          code: 'invalid_response',
        );
      }

      final rawIds = decoded['exerciseIds'];
      final catalogIds = catalog.map((item) => item['id']).whereType<String>().toSet();
      final exerciseIds = rawIds is List
          ? rawIds
              .whereType<String>()
              .where(catalogIds.contains)
              .toList()
          : <String>[];

      if (exerciseIds.isEmpty) {
        throw const FitnessAiException(
          'לא קיבלתי תוכנית אימון תקינה.',
          code: 'empty_reply',
        );
      }
      return exerciseIds;
    } on FitnessAiException {
      rethrow;
    } finally {
      if (ownedClient) httpClient.close();
    }
  }
}
