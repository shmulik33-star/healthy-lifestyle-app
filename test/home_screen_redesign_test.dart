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

  testWidgets(
    'quick actions are trimmed to exactly eating, water and add-to-catalog per feedback '
    '-- weight/workout/coach are one tap away via the bottom nav instead',
    (tester) async {
      _useTallTestSurface(tester);
      await tester.pumpWidget(wrap(AppState()));
      expect(find.text('אכלתי'), findsOneWidget);
      expect(find.text('כוסות מים'), findsOneWidget);
      expect(find.text('הוסף מזון למאגר'), findsOneWidget);
      expect(find.text('משקל'), findsNothing);
      expect(find.text('אימון היום'), findsNothing);
      expect(find.text('המאמן שלי'), findsNothing);
    },
  );

  testWidgets('tapping "הוסף מזון למאגר" opens the add-to-catalog screen', (tester) async {
    _useTallTestSurface(tester);
    await tester.pumpWidget(wrap(AppState()));

    await tester.tap(find.text('הוסף מזון למאגר'));
    await tester.pumpAndSettle();

    // AddFoodToCatalogScreen's own AppBar title text is identical to the
    // button that opens it ("הוסף מזון למאגר"), so that alone wouldn't
    // prove navigation happened -- this heading is unique to that screen.
    expect(find.text('צילום תווית + AI'), findsOneWidget);
  });
}
