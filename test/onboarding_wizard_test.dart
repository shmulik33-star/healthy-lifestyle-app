import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/features/onboarding/onboarding_wizard_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AppState.finishOnboarding', () {
    test('sets onboardingCompleted and persists it', () async {
      final state = AppState();
      expect(state.onboardingCompleted, isFalse);
      state.finishOnboarding();
      expect(state.onboardingCompleted, isTrue);

      await pumpEventQueue();
      final reloaded = await AppState.load();
      expect(reloaded.onboardingCompleted, isTrue);
    });

    test('rides along in the cloud sync profile snapshot', () async {
      final state = AppState();
      state.finishOnboarding();
      final exported = state.exportCloudSyncState();

      final other = AppState();
      expect(other.onboardingCompleted, isFalse);
      await other.applyCloudSyncState(exported);
      expect(other.onboardingCompleted, isTrue);
    });

    test('resetForNewAccount clears it back to false, like other profile fields', () async {
      final state = AppState();
      state.finishOnboarding();
      expect(state.onboardingCompleted, isTrue);
      await state.resetForNewAccount();
      expect(state.onboardingCompleted, isFalse);
    });
  });

  group('OnboardingWizardScreen', () {
    testWidgets('tapping "דלג" on the welcome page finishes onboarding without touching profile fields',
        (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(state: state, child: OnboardingWizardScreen(state: state)),
        ),
      );
      await tester.pump();

      expect(find.text('בואו נכיר אותך'), findsOneWidget);
      await tester.tap(find.text('דלג'));
      await tester.pump();

      expect(state.onboardingCompleted, isTrue);
      expect(state.currentWeight, 0);
    });

    testWidgets('walking through every page and tapping "סיים" saves the entered fields and finishes',
        (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(state: state, child: OnboardingWizardScreen(state: state)),
        ),
      );
      await tester.pump();

      // Welcome -> Goals
      await tester.tap(find.text('בוא נתחיל'));
      await tester.pumpAndSettle();
      expect(find.text('מה המטרות שלך?'), findsOneWidget);

      // Select an extra goal, then move on.
      await tester.tap(find.text('עלייה במסת שריר'));
      await tester.pump();
      await tester.tap(find.text('הבא'));
      await tester.pumpAndSettle();

      // Profile page: fill in weight.
      expect(find.text('קצת עליך'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'משקל נוכחי (ק״ג)'), '71');
      await tester.tap(find.text('הבא'));
      await tester.pumpAndSettle();

      // Equipment page.
      expect(find.text('איזה ציוד יש לך?'), findsOneWidget);
      await tester.tap(find.text('הבא'));
      await tester.pumpAndSettle();

      // How-it-works page.
      expect(find.text('איך התזונה עובדת כאן'), findsOneWidget);
      await tester.tap(find.text('הבא'));
      await tester.pumpAndSettle();

      // Summary page -> finish.
      expect(find.text('הכול מוכן!'), findsOneWidget);
      await tester.tap(find.text('סיים'));
      await tester.pump();

      expect(state.onboardingCompleted, isTrue);
      expect(state.currentWeight, 71);
    });
  });
}
