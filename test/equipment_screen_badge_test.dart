import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_item.dart';
import 'package:healthy_lifestyle_stage9/features/equipment/equipment_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('AI-recognized equipment shows photo plus AI badge', (tester) async {
    final state = AppState();
    // EquipmentScreen reads AppState.customEquipment directly (no longer the
    // local-only EquipmentStore — see PROJECT_BRIEF.md section 6.6), so the
    // item is seeded through the same public API the screen itself uses.
    state.upsertCustomEquipmentItem(
      const CustomEquipmentItem(
        id: 'photo-ai-1',
        name: 'קטלבל מזוהה',
        category: 'קטלבל',
        source: 'photo_ai',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: state,
          child: const EquipmentScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final equipmentName = find.text('קטלבל מזוהה');
    await tester.scrollUntilVisible(
      equipmentName,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(equipmentName, findsOneWidget);
    expect(find.text('צילום + AI'), findsOneWidget);
  });
}
