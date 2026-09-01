import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/fitness/fitness_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final catalog = [
    {'id': 'Plank', 'nameHe': 'פלאנק', 'muscleGroup': 'ליבה'},
    {'id': 'Pushups', 'nameHe': 'שכיבות סמיכה', 'muscleGroup': 'חזה'},
  ];

  test('a successful response returns the exercise ids', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/fitness-plan');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['catalog'], catalog);
      expect(body['context'], {'primaryGoal': 'ירידה במשקל'});

      return http.Response(
        jsonEncode({'exerciseIds': ['Plank', 'Pushups']}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final ids = await FitnessAiService.pickWorkout(
      context: const {'primaryGoal': 'ירידה במשקל'},
      catalog: catalog,
      client: client,
    );

    expect(ids, ['Plank', 'Pushups']);
  });

  test('an id the server returns that is not in the request catalog is dropped', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'exerciseIds': ['Plank', 'Some_Hallucinated_Id']}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final ids = await FitnessAiService.pickWorkout(
      context: const {},
      catalog: catalog,
      client: client,
    );

    expect(ids, ['Plank']);
  });

  test('an empty catalog throws before any network call', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });

    await expectLater(
      FitnessAiService.pickWorkout(context: const {}, catalog: const [], client: client),
      throwsA(isA<FitnessAiException>().having((e) => e.code, 'code', 'empty_catalog')),
    );
    expect(calls, 0);
  });

  test('a malformed (non-JSON) response throws invalid_response', () async {
    final client = MockClient((request) async {
      return http.Response('not json', 200);
    });

    await expectLater(
      FitnessAiService.pickWorkout(context: const {}, catalog: catalog, client: client),
      throwsA(isA<FitnessAiException>().having((e) => e.code, 'code', 'invalid_response')),
    );
  });

  test('a network failure/timeout surfaces as network_or_timeout', () async {
    final client = MockClient((request) async {
      throw Exception('simulated network failure');
    });

    await expectLater(
      FitnessAiService.pickWorkout(context: const {}, catalog: catalog, client: client),
      throwsA(isA<FitnessAiException>().having((e) => e.code, 'code', 'network_or_timeout')),
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
      FitnessAiService.pickWorkout(context: const {}, catalog: catalog, client: client),
      throwsA(isA<FitnessAiException>().having((e) => e.code, 'code', 'ai_binding_missing')),
    );
  });

  test('a response with only invalid/empty ids throws empty_reply', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'exerciseIds': ['Not_In_Catalog']}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      FitnessAiService.pickWorkout(context: const {}, catalog: catalog, client: client),
      throwsA(isA<FitnessAiException>().having((e) => e.code, 'code', 'empty_reply')),
    );
  });
}
