import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/features/progress/progress_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget wrap(AppState state) => MaterialApp(
        home: AppStateScope(state: state, child: ProgressScreen(state: state)),
      );

  testWidgets('the steps row is dropped from the progress screen per feedback', (tester) async {
    await tester.pumpWidget(wrap(AppState()));
    expect(find.text('צעדים'), findsNothing);
  });

  testWidgets(
    'the consistency score no longer changes with steps -- it stays fixed '
    'once nutrition, workout and water are, regardless of the steps count',
    (tester) async {
      final state = AppState()..steps = 0;
      await tester.pumpWidget(wrap(state));
      final scoreWithNoSteps = tester.widget<Text>(find.byKey(const Key('consistency_score'))).data;

      state.steps = state.stepsTarget;
      // Rebuild the tree directly rather than relying on notifyListeners --
      // `steps` is a plain field with no custom setter, so nothing notifies
      // on assignment; a fresh build re-reads the field either way.
      await tester.pumpWidget(wrap(state));
      final scoreWithFullSteps =
          tester.widget<Text>(find.byKey(const Key('consistency_score'))).data;

      expect(scoreWithFullSteps, scoreWithNoSteps);
    },
  );
}
