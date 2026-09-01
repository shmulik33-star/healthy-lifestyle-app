import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/coach/coach_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('a successful response returns the reply text', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/coach-chat');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['question'], 'אני רעב, מה כדאי לאכול?');
      expect(body['context'], {'calorieTarget': 1900});

      return http.Response(
        jsonEncode({'reply': 'כדאי לך לנסות משהו עשיר בחלבון עכשיו.'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final reply = await CoachAiService.ask(
      question: 'אני רעב, מה כדאי לאכול?',
      history: const [],
      context: const {'calorieTarget': 1900},
      client: client,
    );

    expect(reply, 'כדאי לך לנסות משהו עשיר בחלבון עכשיו.');
  });

  test('sends only the last 8 history messages, mapped to role/text', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final history = (body['history'] as List).cast<Map<String, dynamic>>();
      // 9 generated messages (msg0..msg8) -> last 8 kept are msg1..msg8.
      expect(history, hasLength(8));
      expect(history.first['text'], 'msg1');
      expect(history.last['text'], 'msg8');
      expect(history.first['role'], 'coach');
      expect(history.last['role'], 'user');

      return http.Response(
        jsonEncode({'reply': 'תשובה'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final history = List.generate(
      9,
      (i) => CoachMessage(
        role: i.isEven ? CoachRole.user : CoachRole.coach,
        text: 'msg$i',
      ),
    );

    await CoachAiService.ask(
      question: 'שאלה',
      history: history,
      context: const {},
      client: client,
    );
  });

  test('an empty question throws before any network call', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });

    await expectLater(
      CoachAiService.ask(question: '   ', history: const [], context: const {}, client: client),
      throwsA(isA<CoachAiException>().having((e) => e.code, 'code', 'empty_question')),
    );
    expect(calls, 0);
  });

  test('a malformed (non-JSON) response throws invalid_response', () async {
    final client = MockClient((request) async {
      return http.Response('not json', 200);
    });

    await expectLater(
      CoachAiService.ask(question: 'שאלה', history: const [], context: const {}, client: client),
      throwsA(isA<CoachAiException>().having((e) => e.code, 'code', 'invalid_response')),
    );
  });

  test('a network failure/timeout surfaces as network_or_timeout', () async {
    final client = MockClient((request) async {
      throw Exception('simulated network failure');
    });

    await expectLater(
      CoachAiService.ask(question: 'שאלה', history: const [], context: const {}, client: client),
      throwsA(isA<CoachAiException>().having((e) => e.code, 'code', 'network_or_timeout')),
    );
  });

  test('a server error status throws with the server-reported code', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'ai_binding_missing'}),
        503,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      CoachAiService.ask(question: 'שאלה', history: const [], context: const {}, client: client),
      throwsA(isA<CoachAiException>().having((e) => e.code, 'code', 'ai_binding_missing')),
    );
  });
}
