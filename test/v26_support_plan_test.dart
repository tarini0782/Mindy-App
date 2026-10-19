import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_session.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/support_plan.dart';
import 'package:mindy_app/insights/worry_scale.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/services/account_service.dart';
import 'package:mindy_app/services/calm_service.dart';
import 'package:mindy_app/services/demo_seeder.dart';
import 'package:mindy_app/services/session_repository.dart';
import 'package:mindy_app/services/support_plan_service.dart';
import 'package:mindy_app/services/worry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

final _now = DateTime(2026, 10, 15, 12);

GameSession mk(int daysAgo, EmotionState b, EmotionState? a,
        {GameType g = GameType.breathingGarden, bool completed = true}) =>
    makeSession(g,
        before: b,
        after: a,
        completed: completed,
        at: _now.subtract(Duration(days: daysAgo, hours: 1)));

SupportPlan plan(List<GameSession> s,
        {List<WorryEntry> worry = const [],
        List<CalmVisit> calm = const [],
        Map<String, DateTime> trying = const {}}) =>
    SupportPlan.build(
        sessions: s, worry: worry, calm: calm, now: _now, childName: 'Tee', tryingSince: trying);

Set<String> ids(SupportPlan p) => p.actions.map((a) => a.id).toSet();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('band', () {
    test('no data: not enough, asks for check-ins, no claims', () {
      final p = plan(const []);
      expect(p.band, StateBand.notEnough);
      expect(p.signals, isEmpty);
      expect(ids(p), {'A_MORE_CHECKINS'});
      expect(p.days.length, SupportPlan.windowDays);
    });
    test('three check-ins is still not enough', () {
      final p = plan([for (var i = 0; i < 3; i++) mk(i, EmotionState.sad, EmotionState.calm)]);
      expect(p.band, StateBand.notEnough);
    });
    test('mostly okay/calm/happy is settled and gets the keep-going action', () {
      final p = plan([
        mk(6, EmotionState.neutral, EmotionState.calm),
        mk(5, EmotionState.calm, EmotionState.happy),
        mk(3, EmotionState.happy, EmotionState.happy),
        mk(2, EmotionState.neutral, EmotionState.neutral),
        mk(1, EmotionState.calm, EmotionState.calm),
      ]);
      expect(p.band, StateBand.settled);
      expect(ids(p), contains('A_KEEP_GOING'));
      expect(ids(p), isNot(contains('A_CONSIDER_TALKING')));
    });
    test('thresholds: 30% low is mixed, 60% low is unsettled', () {
      final mixed = plan([
        mk(5, EmotionState.sad, EmotionState.calm),
        mk(4, EmotionState.sad, EmotionState.calm),
        mk(3, EmotionState.calm, EmotionState.calm),
        mk(2, EmotionState.calm, EmotionState.calm),
        mk(1, EmotionState.happy, EmotionState.happy),
      ]);
      expect(mixed.band, StateBand.mixed); // 2 of 5 = 40%
      final un = plan([
        mk(5, EmotionState.sad, EmotionState.sad),
        mk(4, EmotionState.scared, EmotionState.scared),
        mk(3, EmotionState.sad, EmotionState.sad),
        mk(2, EmotionState.calm, EmotionState.calm),
        mk(1, EmotionState.scared, EmotionState.scared),
      ]);
      expect(un.band, StateBand.unsettled); // 4 of 5 = 80%
    });
    test('check-ins older than 14 days are ignored', () {
      final p = plan([for (var i = 0; i < 6; i++) mk(20 + i, EmotionState.sad, EmotionState.calm)]);
      expect(p.band, StateBand.notEnough);
      expect(p.checkIns, 0);
    });
    test('a skipped check-in (no feeling) is never counted or guessed', () {
      final s = [for (var i = 0; i < 5; i++) mk(i, EmotionState.calm, EmotionState.calm)];
      final skipped = GameSession.fromJson({...mk(1, EmotionState.calm, null).toJson(), 'emotionBefore': null});
      final p = plan([...s, skipped]);
      expect(p.checkIns, 5);
    });
  });

  group('sample histories from the demo seeder', () {
    Future<List<GameSession>> seed(DemoScenario sc) async {
      final acc = AccountService.instance;
      expect(await acc.startDemo(), isNull);
      expect(await DemoSeeder.seed(sc, now: _now), isNull);
      final id = acc.activeChild!.participantId;
      expect(id.startsWith('DEMO-'), isTrue);
      return SessionRepository.instance.allChronological
          .where((s) => s.anonymousChildId == id)
          .toList();
    }

    test('settling in: mixed, improving, settles after play, no professional prompt', () async {
      final list = await seed(DemoScenario.settlingIn);
      // 15 scripted check-in rows + 6 task sessions (Sorting Stars,
      // Sleepy Fox) dated 31-40 days ago, which feed the Research
      // indicators and sit outside every Support plan window.
      expect(list.length, 21);
      final p = SupportPlan.build(
        sessions: list,
        worry: WorryService.instance.entries,
        calm: CalmService.instance.visits,
        now: _now,
        childName: 'Demo child',
      );
      expect(p.band, StateBand.mixed);
      final t = p.signals.firstWhere((s) => s.ruleId == 'S_TREND');
      expect(t.title, contains('less often'));
      expect(t.tone, SignalTone.good);
      expect(p.signals.any((s) => s.ruleId == 'S_RECOVERY' && s.tone == SignalTone.good), isTrue);
      expect(p.signals.any((s) => s.ruleId == 'S_WORRY' && s.tone == SignalTone.good), isTrue);
      expect(p.signals.any((s) => s.ruleId == 'S_CALM'), isTrue);
      expect(ids(p), isNot(contains('A_CONSIDER_TALKING')));
    });

    test('still worried: unsettled and the gentle professional prompt appears', () async {
      final list = await seed(DemoScenario.stillWorried);
      // 13 scripted rows + the same 6 task sessions.
      expect(list.length, 19);
      final p = SupportPlan.build(
        sessions: list,
        worry: WorryService.instance.entries,
        calm: CalmService.instance.visits,
        now: _now,
        childName: 'Demo child',
      );
      expect(p.band, StateBand.unsettled);
      expect(ids(p), contains('A_CONSIDER_TALKING'));
      expect(ids(p), contains('A_NAME_THE_FEELING'));
      expect(ids(p), contains('A_TRY_CALM_CORNER'));
      // "consider" is always listed last
      expect(p.actions.last.id, 'A_CONSIDER_TALKING');
    });

    test('seeding replaces earlier demo data and refuses non-demo children', () async {
      await seed(DemoScenario.stillWorried);
      final acc = AccountService.instance;
      expect(await DemoSeeder.seed(DemoScenario.settlingIn, now: _now), isNull);
      final id = acc.activeChild!.participantId;
      final n = SessionRepository.instance.allChronological.where((s) => s.anonymousChildId == id).length;
      expect(n, 21);
      // A normal (non-demo) child is refused.
      expect(await acc.register(username: 'parent3', password: 'abcdefg1'), isNull);
      expect(await acc.addChild(nickname: 'Sam', birthYear: DateTime.now().year - 6), isNull);
      expect(acc.activeChild!.isDemo, isFalse);
      expect(await DemoSeeder.seed(DemoScenario.settlingIn, now: _now), isNotNull);
    });
  });

  group('rules', () {
    test('worry staying high after play prompts a gentle talk even with few check-ins', () {
      final s = [
        mk(4, EmotionState.sad, EmotionState.sad),
        mk(3, EmotionState.neutral, EmotionState.neutral),
        mk(2, EmotionState.calm, EmotionState.calm),
        mk(1, EmotionState.calm, EmotionState.calm),
      ];
      final w = [
        WorryEntry(_now.subtract(const Duration(days: 4)), WorryPhase.before, 3),
        WorryEntry(_now.subtract(const Duration(days: 4, minutes: -5)), WorryPhase.after, 3),
        WorryEntry(_now.subtract(const Duration(days: 1)), WorryPhase.before, 4),
        WorryEntry(_now.subtract(const Duration(days: 1, minutes: -5)), WorryPhase.after, 4),
      ];
      final p = plan(s, worry: w);
      expect(ids(p), contains('A_CONSIDER_TALKING'));
      expect(p.signals.any((x) => x.ruleId == 'S_WORRY_HIGH'), isTrue);
    });

    test('one bad week alone never triggers the professional prompt', () {
      // 8 check-ins, all within 5 days (span < 7 days)
      final s = [
        for (var i = 0; i < 8; i++)
          mk(i % 5, EmotionState.sad, EmotionState.sad),
      ];
      final p = plan(s);
      expect(p.band, StateBand.unsettled);
      expect(ids(p), isNot(contains('A_CONSIDER_TALKING')));
    });

    test('best activity type needs 2 low starts and a clear gap', () {
      final s = [
        mk(6, EmotionState.sad, EmotionState.calm, g: GameType.breathingGarden),
        mk(5, EmotionState.scared, EmotionState.calm, g: GameType.breathingGarden),
        mk(4, EmotionState.sad, EmotionState.sad, g: GameType.fruitSlice),
        mk(3, EmotionState.scared, EmotionState.scared, g: GameType.fruitSlice),
        mk(2, EmotionState.calm, EmotionState.calm),
      ];
      final p = plan(s);
      final a = p.actions.firstWhere((x) => x.id == 'A_USE_WHAT_HELPS');
      expect(a.title, contains('calming activities'));
    });

    test('every action carries a reason and at least one concrete step', () {
      final s = [for (var i = 0; i < 10; i++) mk(i, i.isEven ? EmotionState.sad : EmotionState.scared, EmotionState.sad)];
      final p = plan(s);
      expect(p.actions, isNotEmpty);
      for (final a in p.actions) {
        expect(a.why.trim(), isNotEmpty, reason: a.id);
        expect(a.steps, isNotEmpty, reason: a.id);
      }
    });

    test('wording never diagnoses or labels the child', () {
      final s = [for (var i = 0; i < 12; i++) mk(i, EmotionState.sad, EmotionState.sad)];
      final text = plan(s).toPlainText(now: _now).toLowerCase();
      for (final bad in ['depress', 'disorder', 'you have', 'is anxious', 'is depressed', 'adhd', 'autis']) {
        expect(text.contains(bad), isFalse, reason: bad);
      }
      expect(text, contains('cannot'));
    });

    test('same inputs give the same plan', () {
      final s = [for (var i = 0; i < 8; i++) mk(i, EmotionState.sad, EmotionState.calm)];
      expect(plan(s).toPlainText(now: _now), plan(s).toPlainText(now: _now));
    });
  });

  group('trying a suggestion', () {
    test('follow-up compares check-ins before and after, without claiming cause', () {
      final s = [
        mk(10, EmotionState.sad, EmotionState.sad),
        mk(9, EmotionState.scared, EmotionState.scared),
        mk(8, EmotionState.sad, EmotionState.sad),
        mk(3, EmotionState.calm, EmotionState.calm),
        mk(2, EmotionState.neutral, EmotionState.calm),
        mk(1, EmotionState.sad, EmotionState.calm),
      ];
      final since = _now.subtract(const Duration(days: 5));
      final p = plan(s, trying: {'A_NAME_THE_FEELING': since});
      final a = p.actions.firstWhere((x) => x.id == 'A_NAME_THE_FEELING');
      expect(a.followUp, contains('3 of 3'));
      expect(a.followUp, contains('1 of 3'));
      expect(a.followUp, contains('not proof'));
    });
    test('follow-up says so when there is not enough to compare', () {
      final s = [for (var i = 0; i < 6; i++) mk(i, EmotionState.sad, EmotionState.sad)];
      final p = plan(s, trying: {'A_NAME_THE_FEELING': _now});
      expect(p.actions.firstWhere((x) => x.id == 'A_NAME_THE_FEELING').followUp,
          contains('Not enough'));
    });
    test('choices are saved per child and can be changed', () async {
      final svc = SupportPlanService.instance;
      await svc.load('child-a');
      await svc.set('A_NAME_THE_FEELING', PlanChoice.trying);
      await svc.set('A_TRY_CALM_CORNER', PlanChoice.notNow);
      await svc.load('child-b');
      expect(svc.choiceFor('A_NAME_THE_FEELING'), isNull);
      await svc.load('child-a');
      expect(svc.choiceFor('A_NAME_THE_FEELING'), PlanChoice.trying);
      expect(svc.choiceFor('A_TRY_CALM_CORNER'), PlanChoice.notNow);
      expect(svc.tryingSince.keys, ['A_NAME_THE_FEELING']);
      await svc.clear('A_NAME_THE_FEELING');
      expect(svc.choiceFor('A_NAME_THE_FEELING'), isNull);
      await svc.deleteForChild('child-a');
      await svc.load('child-a');
      expect(svc.decisions, isEmpty);
    });
  });

  test('plain-text copy includes the headline and the caution', () {
    final p = plan([for (var i = 0; i < 6; i++) mk(i, EmotionState.calm, EmotionState.happy)]);
    final t = p.toPlainText(childLabel: 'Tee', now: _now);
    expect(t, contains(p.headline));
    expect(t, contains('2026-10-15'));
    expect(t, contains('doctor'));
  });
}
