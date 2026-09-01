import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:healthy_lifestyle_stage9/features/coach/coach_ai_service.dart';
import 'package:healthy_lifestyle_stage9/features/coach/coach_screen.dart';
import 'package:healthy_lifestyle_stage9/shared/models/app_state.dart';

/// Sliver-backed ListViews only build widgets within the test viewport --
/// same fix as elsewhere in this suite.
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

  testWidgets(
    'when the AI coach call fails, the screen silently falls back to '
    'coachResponse() -- no error shown to the user',
    (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();
      const question = 'אני רעב, מה כדאי לאכול?';
      final expectedFallback = state.coachResponse(question);

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: state,
            child: Scaffold(
              body: CoachScreen(
                askAi: ({
                  required String question,
                  required List<CoachMessage> history,
                  required Map<String, dynamic> context,
                }) async =>
                    throw const CoachAiException('boom', code: 'network_or_timeout'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('אני רעב'));
      await tester.pumpAndSettle();

      expect(find.textContaining(expectedFallback), findsOneWidget);
      // No loading spinner left behind, and no visible error text.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'a successful AI reply is shown instead of the rule-based fallback',
    (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: state,
            child: Scaffold(
              body: CoachScreen(
                askAi: ({
                  required String question,
                  required List<CoachMessage> history,
                  required Map<String, dynamic> context,
                }) async =>
                    'תשובה חמה מה-AI',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('אני רעב'));
      await tester.pumpAndSettle();

      expect(find.textContaining('תשובה חמה מה-AI'), findsOneWidget);
    },
  );

  testWidgets(
    'voice chat degrades gracefully when speech recognition is unavailable '
    '(as in this widget-test environment, with no real browser speech API) '
    '-- no mic button, and typing still works',
    (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: state,
            child: Scaffold(
              body: CoachScreen(
                askAi: ({
                  required String question,
                  required List<CoachMessage> history,
                  required Map<String, dynamic> context,
                }) async =>
                    'תשובה',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);

      await tester.enterText(find.byType(TextField), 'שאלה שהוקלדה');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.textContaining('שאלה שהוקלדה'), findsOneWidget);
    },
  );

  testWidgets(
    'the speaker mute toggle flips its icon and does not crash the screen '
    '-- flutter_tts has no real browser speech-synthesis engine in this '
    'widget-test environment, so speaking a reply is expected to silently '
    'no-op rather than throw',
    (tester) async {
      _useTallTestSurface(tester);
      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateScope(
            state: state,
            child: Scaffold(
              body: CoachScreen(
                askAi: ({
                  required String question,
                  required List<CoachMessage> history,
                  required Map<String, dynamic> context,
                }) async =>
                    'תשובה חמה מה-AI',
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pump();
      expect(find.byIcon(Icons.volume_off), findsOneWidget);

      // With replies-aloud now off, a real reply still arrives normally.
      await tester.tap(find.text('אני רעב'));
      await tester.pumpAndSettle();
      expect(find.textContaining('תשובה חמה מה-AI'), findsOneWidget);
    },
  );
}
