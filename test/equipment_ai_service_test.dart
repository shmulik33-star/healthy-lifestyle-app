import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_ai_service.dart';

void main() {
  test('AI suggestion accepts a known equipment category', () {
    final suggestion = EquipmentAiSuggestion.fromJson({
      'recognized': true,
      'name': 'דאמבלים 8 ק״ג',
      'category': 'משקולות',
      'categoryDetail': '',
      'notes': 'זוג משקולות',
      'confidence': 0.91,
      'reason': 'נראות שתי משקולות יד בתמונה',
    });

    expect(suggestion.recognized, isTrue);
    expect(suggestion.name, 'דאמבלים 8 ק״ג');
    expect(suggestion.category, 'משקולות');
    expect(suggestion.confidence, closeTo(0.91, 0.001));
  });

  test('AI suggestion falls back safely for an unknown category', () {
    final suggestion = EquipmentAiSuggestion.fromJson({
      'recognized': true,
      'name': 'מכשיר לא מוכר',
      'category': 'קטגוריה שהמודל המציא',
      'confidence': 2.5,
    });

    expect(suggestion.category, 'אחר');
    expect(suggestion.confidence, 1);
  });

  test('AI suggestion clamps negative confidence to zero', () {
    final suggestion = EquipmentAiSuggestion.fromJson({
      'recognized': false,
      'name': '',
      'category': 'אחר',
      'confidence': -0.5,
    });

    expect(suggestion.recognized, isFalse);
    expect(suggestion.confidence, 0);
  });
}
