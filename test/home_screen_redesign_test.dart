import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/features/home/home_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

/// Sliver-backed ListViews only build widgets within the test viewport --
/// same fix water_reminder_test.dart already uses for this same screen.
void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget wrap(AppState state) => MaterialApp(
        home: AppStateScope(
          state: state,
          // HomeScreen relies on an ancestor Scaffold for its Material --
          // see water_reminder_test.dart's note on the same requirement.
          child: Scaffold(body: HomeScreen(onNavigate: (_) {})),
        ),
      );

  testWidgets('the redesigned home screen drops the steps quick action entirely', (tester) async {
    _useTallTestSurface(tester);
    await tester.pumpWidget(wrap(AppState()));
    expect(find.text('צעדים'), findsNothing);
    expect(find.byIcon(Icons.directions_walk), findsNothing);
  });

  testWidgets('quick actions for eating, water, weight and today\'s workout are all present', (tester) async {
    _useTallTestSurface(tester);
    await tester.pumpWidget(wrap(AppState()));
    expect(find.text('אכלתי'), findsOneWidget);
    expect(find.text('כוסות מים'), findsOneWidget);
    expect(find.text('משקל'), findsOneWidget);
    expect(find.text('אימון היום'), findsOneWidget);
  });

  testWidgets('tapping the weight quick action logs a new weight entry', (tester) async {
    final state = AppState()..currentWeight = 80;
    final before = state.weights.length;

    _useTallTestSurface(tester);
    await tester.pumpWidget(wrap(state));

    await tester.tap(find.text('משקל'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '79.5');
    await tester.tap(find.text('שמור'));
    await tester.pumpAndSettle();

    expect(state.currentWeight, 79.5);
    expect(state.weights.length, before + 1);
    expect(find.textContaining('השקילה נשמרה'), findsOneWidget);
  });

  testWidgets('an invalid weight is rejected without saving', (tester) async {
    final state = AppState()..currentWeight = 80;
    final before = state.weights.length;

    _useTallTestSurface(tester);
    await tester.pumpWidget(wrap(state));

    await tester.tap(find.text('משקל'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not a number');
    await tester.tap(find.text('שמור'));
    await tester.pumpAndSettle();

    expect(state.weights.length, before);
    expect(find.textContaining('נא להזין משקל תקין'), findsOneWidget);
  });
}
