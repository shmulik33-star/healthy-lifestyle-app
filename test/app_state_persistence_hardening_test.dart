import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('legacy AppState is migrated and saved with a schema version', () async {
    SharedPreferences.setMockInitialValues({
      'stage10_state_v1': jsonEncode({
        'firstName': 'משתמש ישן',
        'currentWeight': 88.0,
      }),
    });

    final state = await AppState.load();
    expect(state.firstName, 'משתמש ישן');
    expect(state.currentWeight, 88.0);

    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString('stage10_state_v1')!)
        as Map<String, dynamic>;
    expect(saved['schemaVersion'], 1);
    expect(prefs.getString('stage10_state_v1_backup'), isNotNull);
  });

  test('corrupt primary AppState is recovered from the last valid backup', () async {
    SharedPreferences.setMockInitialValues({
      'stage10_state_v1': '{broken-json',
      'stage10_state_v1_backup': jsonEncode({
        'schemaVersion': 1,
        'firstName': 'שוחזר מגיבוי',
        'currentWeight': 92.0,
      }),
    });

    final state = await AppState.load();
    expect(state.firstName, 'שוחזר מגיבוי');
    expect(state.currentWeight, 92.0);

    final prefs = await SharedPreferences.getInstance();
    final repaired = jsonDecode(prefs.getString('stage10_state_v1')!)
        as Map<String, dynamic>;
    expect(repaired['schemaVersion'], 1);
    expect(repaired['firstName'], 'שוחזר מגיבוי');

    final backup = jsonDecode(prefs.getString('stage10_state_v1_backup')!)
        as Map<String, dynamic>;
    expect(backup['firstName'], 'שוחזר מגיבוי');
  });
}
