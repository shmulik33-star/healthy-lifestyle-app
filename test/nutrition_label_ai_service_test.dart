import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/nutrition_label_ai_service.dart';

void main() {
  test('recognized nutrition label keeps normalized values', () {
    final suggestion = NutritionLabelAiSuggestion.fromJson({
      'recognized': true,
      'name': 'יוגורט טבעי',
      'caloriesPer100g': 82,
      'proteinPer100g': 9.5,
      'carbsPer100g': 5.2,
      'fatPer100g': 2.1,
      'servingName': 'גביע',
      'servingGrams': 150,
      'confidence': 0.91,
      'reason': 'טבלת הערכים ברורה.',
    });

    expect(suggestion.recognized, isTrue);
    expect(suggestion.name, 'יוגורט טבעי');
    expect(suggestion.caloriesPer100g, 82);
    expect(suggestion.proteinPer100g, 9.5);
    expect(suggestion.servingName, 'גביע');
    expect(suggestion.servingGrams, 150);
    expect(suggestion.confidence, 0.91);
  });

  test('recognized requires a useful value or visible name', () {
    final suggestion = NutritionLabelAiSuggestion.fromJson({
      'recognized': true,
      'name': '',
      'caloriesPer100g': 0,
      'proteinPer100g': 0,
      'carbsPer100g': 0,
      'fatPer100g': 0,
      'confidence': 0.2,
    });

    expect(suggestion.recognized, isFalse);
  });

  test('unsafe numeric values are clamped before reaching the form', () {
    final suggestion = NutritionLabelAiSuggestion.fromJson({
      'recognized': true,
      'name': 'בדיקה',
      'caloriesPer100g': 99999,
      'proteinPer100g': 220,
      'carbsPer100g': -5,
      'fatPer100g': 150,
      'servingGrams': 9000,
      'confidence': 7,
    });

    expect(suggestion.caloriesPer100g, 2000);
    expect(suggestion.proteinPer100g, 100);
    expect(suggestion.carbsPer100g, 0);
    expect(suggestion.fatPer100g, 100);
    expect(suggestion.servingGrams, 5000);
    expect(suggestion.confidence, 1);
  });
}
