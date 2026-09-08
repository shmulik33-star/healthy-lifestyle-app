import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/features/profile/auth_gate_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

/// AuthGateScreen's sign-in/sign-up buttons call CloudSyncService, which
/// needs a real Supabase.initialize() this test suite doesn't set up (no
/// network in CI) -- so these tests only cover client-side validation,
/// which runs and fails *before* any Supabase call would be reached.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget wrap() => MaterialApp(
        home: AuthGateScreen(state: AppState()),
      );

  testWidgets('rejects an invalid email before attempting sign-in', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byKey(const Key('auth_gate_email')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('auth_gate_password')), '123456');
    await tester.tap(find.byKey(const Key('auth_gate_sign_in')));
    await tester.pump();

    expect(find.text('יש להזין כתובת אימייל תקינה.'), findsOneWidget);
  });

  testWidgets('rejects a too-short password before attempting sign-up', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.enterText(find.byKey(const Key('auth_gate_email')), 'user@example.com');
    await tester.enterText(find.byKey(const Key('auth_gate_password')), '123');
    await tester.tap(find.byKey(const Key('auth_gate_sign_up')));
    await tester.pump();

    expect(find.text('הסיסמה צריכה להכיל לפחות 6 תווים.'), findsOneWidget);
  });

  testWidgets('shows both sign-in and sign-up actions', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.byKey(const Key('auth_gate_sign_in')), findsOneWidget);
    expect(find.byKey(const Key('auth_gate_sign_up')), findsOneWidget);
  });
}
