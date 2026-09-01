import 'dart:convert';

import 'package:http/http.dart' as http;

enum CoachRole { user, coach }

class CoachMessage {
  const CoachMessage({required this.role, required this.text});
  final CoachRole role;
  final String text;
}

class CoachAiException implements Exception {
  const CoachAiException(this.message, {this.code = ''});
  final String message;
  final String code;
  @override
  String toString() => message;
}

/// AI coach chat, backed by functions/api/coach-chat.ts. Mirrors
/// EquipmentAiService's injectable-http.Client design (needed for the
/// mocked-http tests below).
class CoachAiService {
  static const _configuredEndpoint = String.fromEnvironment(
    'COACH_AI_ENDPOINT',
    defaultValue: '',
  );

  static Uri get endpoint => _configuredEndpoint.trim().isNotEmpty
      ? Uri.parse(_configuredEndpoint.trim())
      : Uri.base.resolve('/api/coach-chat');

  static Future<String> ask({
    required String question,
    required List<CoachMessage> history,
    required Map<String, dynamic> context,
    http.Client? client,
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      throw const CoachAiException('השאלה ריקה.', code: 'empty_question');
    }

    final ownedClient = client == null;
    final httpClient = client ?? http.Client();
    // Same defensive cap as the server applies -- keeps the request small
    // regardless of how long the on-screen conversation has grown.
    final recentHistory =
        history.length > 8 ? history.sublist(history.length - 8) : history;

    try {
      http.Response response;
      try {
        response = await httpClient
            .post(
              endpoint,
              headers: const {'content-type': 'application/json'},
              body: jsonEncode({
                'question': trimmed,
                'history': recentHistory
                    .map((m) => {
                          'role': m.role == CoachRole.user ? 'user' : 'coach',
                          'text': m.text,
                        })
                    .toList(),
                'context': context,
              }),
            )
            .timeout(const Duration(seconds: 45));
      } catch (_) {
        throw const CoachAiException(
          'לא הצלחתי להגיע למאמן כרגע.',
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
        throw CoachAiException(
          'לא הצלחתי להגיע למאמן כרגע.',
          code: serverCode,
        );
      }

      if (decoded == null) {
        throw const CoachAiException(
          'קיבלתי תשובה לא תקינה מהמאמן.',
          code: 'invalid_response',
        );
      }

      final reply = decoded['reply']?.toString().trim() ?? '';
      if (reply.isEmpty) {
        throw const CoachAiException(
          'לא קיבלתי תשובה מהמאמן.',
          code: 'empty_reply',
        );
      }
      return reply;
    } on CoachAiException {
      rethrow;
    } finally {
      if (ownedClient) httpClient.close();
    }
  }
}
