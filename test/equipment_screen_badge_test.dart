import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_item.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const item = CustomEquipmentItem(
      id: 'photo-ai-1',
      name: 'קטלבל מזוהה',
      category: 'קטלבל',
      source: 'photo_ai',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      EquipmentStore.storageKey: jsonEncode([item.toJson()]),
    });
  });

  testWidgets('AI-recognized equipment shows photo plus AI badge', (tester) async {
    final state = AppState();
    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: state,
          child: const EquipmentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('קטלבל מזוהה'), findsOneWidget);
    expect(find.text('צילום + AI'), findsOneWidget);
  });
}
