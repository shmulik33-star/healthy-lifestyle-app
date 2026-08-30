import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/meal_estimate_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('estimateFromImage returns a recognized suggestion on a valid response', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/meal-estimate');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['imageBase64'], isNotEmpty);
      expect(body['mimeType'], 'image/jpeg');

      return http.Response(
        jsonEncode({
          'recognized': true,
          'name': 'חזה עוף עם אורז וירקות',
          'caloriesPer100g': 145,
          'proteinPer100g': 12,
          'carbsPer100g': 15,
          'fatPer100g': 4,
          'servingName': 'מנה כפי שנראתה בתמונה',
          'servingGrams': 350,
          'confidence': 0.72,
          'reason': 'צלחת עם עוף, אורז וירקות',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await MealEstimateAiService.estimateFromImage(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/jpeg',
      client: client,
    );

    expect(result.recognized, isTrue);
    expect(result.name, 'חזה עוף עם אורז וירקות');
    expect(result.servingGrams, 350);
    expect(result.servingName, 'מנה כפי שנראתה בתמונה');
  });

  test('estimateFromText returns a recognized suggestion without throwing', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['text'], 'קערת סלט עם טונה וביצה');

      return http.Response(
        jsonEncode({
          'recognized': true,
          'name': 'סלט טונה וביצה',
          'caloriesPer100g': 110,
          'proteinPer100g': 9,
          'carbsPer100g': 4,
          'fatPer100g': 6,
          'servingName': 'מנה כפי שתוארה',
          'servingGrams': 300,
          'confidence': 0.6,
          'reason': '',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await MealEstimateAiService.estimateFromText(
      text: 'קערת סלט עם טונה וביצה',
      client: client,
    );

    expect(result.recognized, isTrue);
    expect(result.name, 'סלט טונה וביצה');
  });

  test('a not-recognized (too vague) response does not throw', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'recognized': false,
          'name': '',
          'caloriesPer100g': 0,
          'proteinPer100g': 0,
          'carbsPer100g': 0,
          'fatPer100g': 0,
          'servingName': '',
          'servingGrams': 0,
          'confidence': 0.1,
          'reason': 'התיאור מעורפל מדי כדי להעריך ארוחה.',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final result = await MealEstimateAiService.estimateFromText(
      text: 'אכלתי משהו',
      client: client,
    );

    expect(result.recognized, isFalse);
    expect(result.reason, isNotEmpty);
  });

  test('text_too_short is thrown before any network call', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });

    await expectLater(
      MealEstimateAiService.estimateFromText(text: ' א ', client: client),
      throwsA(
        isA<MealEstimateAiException>().having((e) => e.code, 'code', 'text_too_short'),
      ),
    );
    expect(calls, 0);
  });

  test('a network failure/timeout surfaces as network_or_timeout', () async {
    final client = MockClient((request) async {
      throw Exception('simulated network failure');
    });

    await expectLater(
      MealEstimateAiService.estimateFromText(text: 'קערת אורז ועדשים', client: client),
      throwsA(
        isA<MealEstimateAiException>().having((e) => e.code, 'code', 'network_or_timeout'),
      ),
    );
  });

  test('an oversized image is rejected before any network call', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });

    final oversized = Uint8List(4 * 1024 * 1024 + 1);
    await expectLater(
      MealEstimateAiService.estimateFromImage(
        imageBytes: oversized,
        mimeType: 'image/jpeg',
        client: client,
      ),
      throwsA(
        isA<MealEstimateAiException>().having((e) => e.code, 'code', 'image_too_large'),
      ),
    );
    expect(calls, 0);
  });

  test('server-reported image_too_large maps to the same friendly error', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'error': 'image_too_large'}),
        413,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      MealEstimateAiService.estimateFromImage(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/jpeg',
        client: client,
      ),
      throwsA(
        isA<MealEstimateAiException>().having((e) => e.code, 'code', 'image_too_large'),
      ),
    );
  });
}
