import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/nutrition/open_food_facts_service.dart';

void main() {
  test('a found product prefers the Hebrew name when present', () {
    final product = OpenFoodFactsProduct.fromJson({
      'status': 1,
      'product': {
        'product_name_he': 'יוגורט טבעי 3%',
        'product_name': 'Natural Yogurt 3%',
        'nutriments': {
          'energy-kcal_100g': 62,
          'proteins_100g': 3.5,
          'carbohydrates_100g': 4.7,
          'fat_100g': 3,
        },
      },
    });

    expect(product.found, isTrue);
    expect(product.name, 'יוגורט טבעי 3%');
    expect(product.caloriesPer100g, 62);
    expect(product.proteinPer100g, 3.5);
    expect(product.carbsPer100g, 4.7);
    expect(product.fatPer100g, 3);
  });

  test('falls back through product_name then generic_name when there is no '
      'Hebrew name', () {
    final withGeneric = OpenFoodFactsProduct.fromJson({
      'status': 1,
      'product': {
        'product_name_he': '',
        'product_name': 'Natural Yogurt 3%',
        'generic_name': 'Yogurt',
        'nutriments': <String, dynamic>{},
      },
    });
    expect(withGeneric.name, 'Natural Yogurt 3%');

    final onlyGeneric = OpenFoodFactsProduct.fromJson({
      'status': 1,
      'product': {
        'product_name': '',
        'generic_name': 'Yogurt',
        'nutriments': <String, dynamic>{},
      },
    });
    expect(onlyGeneric.name, 'Yogurt');
  });

  test('missing nutriment fields stay null, not invented as 0', () {
    final product = OpenFoodFactsProduct.fromJson({
      'status': 1,
      'product': {
        'product_name': 'מוצר חלקי',
        'nutriments': {
          'proteins_100g': 5,
          // calories, carbs, fat are entirely absent.
        },
      },
    });

    expect(product.found, isTrue);
    expect(product.proteinPer100g, 5);
    expect(product.caloriesPer100g, isNull);
    expect(product.carbsPer100g, isNull);
    expect(product.fatPer100g, isNull);
  });

  test('never reads the plain "energy" field for calories -- it is kJ, not '
      'kcal', () {
    final product = OpenFoodFactsProduct.fromJson({
      'status': 1,
      'product': {
        'product_name': 'מוצר',
        'nutriments': {
          // No energy-kcal at all, only the kJ field -- must stay null
          // rather than being misread as a kcal value.
          'energy_100g': 260,
        },
      },
    });

    expect(product.caloriesPer100g, isNull);
  });

  test('prefers the _100g nutriment key over the bare key', () {
    final product = OpenFoodFactsProduct.fromJson({
      'status': 1,
      'product': {
        'product_name': 'מוצר',
        'nutriments': {
          'energy-kcal_100g': 100,
          'energy-kcal': 999,
        },
      },
    });

    expect(product.caloriesPer100g, 100);
  });

  test('falls back to the bare nutriment key when the _100g one is missing', () {
    final product = OpenFoodFactsProduct.fromJson({
      'status': 1,
      'product': {
        'product_name': 'מוצר',
        'nutriments': {
          'energy-kcal': 150,
        },
      },
    });

    expect(product.caloriesPer100g, 150);
  });

  test('status 0 (product not found) parses as not found, not an error', () {
    final product = OpenFoodFactsProduct.fromJson({
      'status': 0,
      'status_verbose': 'product not found',
    });

    expect(product.found, isFalse);
    expect(product.name, '');
    expect(product.caloriesPer100g, isNull);
  });

  test('a missing product object with status 1 still parses as not found '
      'instead of crashing', () {
    final product = OpenFoodFactsProduct.fromJson({'status': 1});

    expect(product.found, isFalse);
  });

  test('OpenFoodFactsProduct.notFound() matches a fresh not-found parse', () {
    const notFound = OpenFoodFactsProduct.notFound();

    expect(notFound.found, isFalse);
    expect(notFound.name, '');
    expect(notFound.caloriesPer100g, isNull);
    expect(notFound.proteinPer100g, isNull);
    expect(notFound.carbsPer100g, isNull);
    expect(notFound.fatPer100g, isNull);
  });
}
