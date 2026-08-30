import 'dart:convert';

import 'package:http/http.dart' as http;

/// A parsed Open Food Facts product lookup result. `found == false` means
/// the barcode isn't in Open Food Facts (not an error) -- the caller falls
/// back to the manual form either way, with or without prefilled values.
class OpenFoodFactsProduct {
  const OpenFoodFactsProduct({
    required this.found,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  const OpenFoodFactsProduct.notFound()
      : found = false,
        name = '',
        caloriesPer100g = null,
        proteinPer100g = null,
        carbsPer100g = null,
        fatPer100g = null;

  final bool found;
  final String name;

  /// Null (not 0) when Open Food Facts doesn't report a value -- the
  /// caller must leave that form field empty for manual entry rather than
  /// invent a number (see CLAUDE.md golden rule #5).
  final double? caloriesPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;

  factory OpenFoodFactsProduct.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    // OFF returns HTTP 200 with status: 0 for "no such product", not a 404.
    final foundStatus = status == 1 || status == '1';
    final productRaw = json['product'];
    if (!foundStatus || productRaw is! Map) {
      return const OpenFoodFactsProduct.notFound();
    }
    final product = Map<String, dynamic>.from(productRaw);

    // Prefer the Hebrew name when OFF has one; fall back through the
    // generic product name and then the free-text generic name.
    final nameHe = product['product_name_he']?.toString().trim() ?? '';
    final nameGeneric = product['product_name']?.toString().trim() ?? '';
    final nameFallback = product['generic_name']?.toString().trim() ?? '';
    final name = nameHe.isNotEmpty
        ? nameHe
        : (nameGeneric.isNotEmpty ? nameGeneric : nameFallback);

    final nutrimentsRaw = product['nutriments'];
    final nutriments =
        nutrimentsRaw is Map ? Map<String, dynamic>.from(nutrimentsRaw) : <String, dynamic>{};

    // Each field prefers its "_100g" key (values normalized per 100g by
    // OFF) and falls back to the bare key only if that's missing.
    double? number(String key) {
      for (final candidate in ['${key}_100g', key]) {
        final raw = nutriments[candidate];
        final value =
            raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
        if (value != null && value.isFinite && value >= 0) return value;
      }
      return null;
    }

    return OpenFoodFactsProduct(
      found: true,
      name: name,
      // OFF's plain "energy" field is in kJ, not kcal -- only the
      // dedicated kcal field is safe to use directly, never that one.
      caloriesPer100g: number('energy-kcal'),
      proteinPer100g: number('proteins'),
      carbsPer100g: number('carbohydrates'),
      fatPer100g: number('fat'),
    );
  }
}

class OpenFoodFactsException implements Exception {
  const OpenFoodFactsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OpenFoodFactsService {
  static Uri _endpointFor(String barcode) => Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/'
        '${Uri.encodeComponent(barcode)}.json',
      );

  /// Looks up [barcode] directly against the public Open Food Facts API
  /// (no API key, no server round-trip through our own Worker). Throws
  /// [OpenFoodFactsException] on a network failure/timeout or a malformed
  /// response; a barcode Open Food Facts simply doesn't know about is
  /// *not* an exception -- it comes back as `OpenFoodFactsProduct.notFound()`.
  static Future<OpenFoodFactsProduct> lookup(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      throw const OpenFoodFactsException('לא זוהה ברקוד תקין.');
    }

    http.Response response;
    try {
      response = await http
          .get(_endpointFor(trimmed))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const OpenFoodFactsException(
        'לא הצלחנו להתחבר ל-Open Food Facts כרגע.',
      );
    }

    if (response.statusCode == 404) {
      return const OpenFoodFactsProduct.notFound();
    }
    if (response.statusCode != 200) {
      throw OpenFoodFactsException(
        'Open Food Facts החזיר שגיאה (קוד ${response.statusCode}).',
      );
    }

    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is Map) decoded = Map<String, dynamic>.from(value);
    } catch (_) {
      // Handled below as an invalid response.
    }
    if (decoded == null) {
      throw const OpenFoodFactsException(
        'קיבלנו תשובה לא תקינה מ-Open Food Facts.',
      );
    }

    return OpenFoodFactsProduct.fromJson(decoded);
  }
}
