import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/parent_summary.dart';
import 'package:mindy_app/screens/calm_corner_screen.dart';
import 'package:mindy_app/services/calm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('visits are stored per child and survive a reload', () async {
    final s = CalmService.instance;
    await s.load('P-AAAAAA');
    await s.add(CalmVisit(
        at: DateTime(2026, 1, 1), activity: 'breathing', seconds: 40,
        feelingBefore: 1, feelingAfter: 3));
    await s.load('P-BBBBBB');
    expect(s.visits, isEmpty);
    await s.load('P-AAAAAA');
    expect(s.visits.length, 1);
    expect(s.visits.first.activity, 'breathing');
  });

  test('delete removes the child\'s visits', () async {
    final s = CalmService.instance;
    await s.load('P-CCCCCC');
    await s.add(CalmVisit(
        at: DateTime(2026, 1, 1), activity: 'grounding', seconds: 20,
        feelingBefore: 0, feelingAfter: 0));
    await s.deleteForChild('P-CCCCCC');
    await s.load('P-CCCCCC');
    expect(s.visits, isEmpty);
  });

  test('caregiver line is plain, self-reported and not clinical', () async {
    final s = CalmService.instance;
    await s.load('P-DDDDDD');
    expect(s.caregiverLine(DateTime(2026, 1, 2)), contains('not used'));
    final now = DateTime(2026, 1, 2);
    await s.add(CalmVisit(at: now, activity: 'breathing', seconds: 30,
        feelingBefore: 1, feelingAfter: 3));
    await s.add(CalmVisit(at: now, activity: 'breathing', seconds: 30,
        feelingBefore: 2, feelingAfter: 2));
    final line = s.caregiverLine(now);
    expect(line, contains('2 times'));
    expect(line, contains('50%'));
    expect(line, contains('their own answer'));
    expect(s.feltBetterShare, 0.5);
  });

  test('unrated visits give no "felt better" figure', () async {
    final s = CalmService.instance;
    await s.load('P-EEEEEE');
    await s.add(CalmVisit(at: DateTime(2026, 1, 1), activity: 'grounding',
        seconds: 10, feelingBefore: 0, feelingAfter: 0));
    expect(s.feltBetterShare, isNull);
  });

  test('plain-text summary has no diagnostic wording', () {
    final list = [for (var i = 0; i < 4; i++) makeSession(GameType.carrotCatch)];
    final t = ParentSummary.from(list, childName: 'Mia').toPlainText().toLowerCase();
    expect(t, contains('does not diagnose'));
    for (final banned in ['adhd', 'autis', 'depress', 'disorder']) {
      expect(t.contains(banned), isFalse);
    }
  });

  testWidgets('calm corner flow: feeling, activity, grounding, after, done',
      (tester) async {
    await CalmService.instance.load('P-FFFFFF');
    await tester.pumpWidget(const MaterialApp(home: CalmCornerScreen()));
    await tester.tap(find.byKey(const Key('calm_feel_1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('calm_pick_grounding')));
    await tester.pump();
    for (var step = 0; step < 6; step++) {
      for (var i = 0; i < 3; i++) {
        final f = find.byKey(Key('calm_ground_$i'));
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f, warnIfMissed: false);
          await tester.pump();
        }
      }
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.tap(find.byKey(const Key('calm_feel_3')));
    await tester.pump(const Duration(seconds: 1)); // SkyBackground animates forever
    expect(find.byKey(const Key('calm_done')), findsOneWidget);
    expect(CalmService.instance.visits.length, 1);
    expect(CalmService.instance.visits.first.feelingAfter, 3);
  });
}
