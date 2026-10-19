import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/screens/wellbeing_full_summary_screen.dart';
import 'package:mindy_app/screens/wellbeing_insights_screen.dart';
import 'package:mindy_app/services/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

/// v27 (user-requested rewrite): the old "Parent summary" screen stacked
/// eight dense, jargon-heavy cards in one long scroll. This checks the
/// split instead: a short plain-language screen first, with the detailed
/// activity-by-activity breakdown (charts, participation stats, the
/// adaptive journey) only one tap away.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionRepository.instance.load();
    SessionRepository.instance.activeChildId = null;
  });

  Future<void> seedSessions() async {
    for (var i = 0; i < 6; i++) {
      await SessionRepository.instance.add(makeSession(
        GameType.breathingGarden,
        before: EmotionState.sad,
        after: EmotionState.calm,
        at: DateTime(2026, 10, 1).add(Duration(days: i)),
      ));
    }
  }

  group('Parent summary (short screen)', () {
    testWidgets('with no data: says Mindy is still learning, no dense content',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: WellbeingInsightsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Mindy is still learning.'), findsOneWidget);
      expect(find.textContaining('Adaptive journey'), findsNothing);
      expect(find.textContaining('Participation'), findsNothing);
    });

    testWidgets('with data: shows the plain summary and a link to the full one, '
        'but none of the dense detail inline', (tester) async {
      await seedSessions();
      await tester.pumpWidget(
          const MaterialApp(home: WellbeingInsightsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('parentSummary')), findsOneWidget);
      expect(find.textContaining('See the full summary of how'), findsOneWidget);
      // The dense, jargon-heavy stuff must NOT be on this first screen.
      expect(find.textContaining('Adaptive journey'), findsNothing);
      expect(find.textContaining('Participation'), findsNothing);
      expect(find.byKey(const Key('whatHelps')), findsNothing);
    });

    testWidgets('tapping the link opens the full summary screen', (tester) async {
      await seedSessions();
      await tester.pumpWidget(
          const MaterialApp(home: WellbeingInsightsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.textContaining('See the full summary of how'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(WellbeingFullSummaryScreen), findsOneWidget);
      expect(find.byKey(const Key('whatHelps')), findsOneWidget);
      // Asserted on the screen's FIRST paragraph: items further down a
      // ListView are not built until scrolled into view, so a finder
      // for a lower section would fail even though it renders fine.
      expect(find.textContaining('detailed, activity-by-activity view'),
          findsOneWidget);
    });
  });
}
