import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_ai_service.dart';

void main() {
  test('known equipment category is accepted', () {
    final suggestion = EquipmentAiSuggestion.fromJson({
      'recognized': true,
      'name': 'משקולות יד',
      'category': 'משקולות',
      'categoryDetail': '',
      'notes': '',
      'confidence': 0.91,
      'reason': 'נראות שתי משקולות יד',
    });

    expect(suggestion.recognized, isTrue);
    expect(suggestion.name, 'משקולות יד');
    expect(suggestion.category, 'משקולות');
    expect(suggestion.confidence, 0.91);
  });

  test('unknown category falls back safely to Other', () {
    final suggestion = EquipmentAiSuggestion.fromJson({
      'recognized': true,
      'name': 'אביזר אחיזה',
      'category': 'קטגוריה שהומצאה',
      'categoryDetail': 'מחזק אחיזה',
      'confidence': 2.4,
    });

    expect(suggestion.recognized, isTrue);
    expect(suggestion.category, 'אחר');
    expect(suggestion.categoryDetail, 'מחזק אחיזה');
    expect(suggestion.confidence, 1);
  });

  test('recognized requires a non-empty name', () {
    final suggestion = EquipmentAiSuggestion.fromJson({
      'recognized': true,
      'name': '   ',
      'category': 'מכשירי כוח',
      'confidence': -1,
    });

    expect(suggestion.recognized, isFalse);
    expect(suggestion.confidence, 0);
  });
}
