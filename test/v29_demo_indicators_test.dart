import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/insights/rule_indicators.dart';
import 'package:mindy_app/insights/support_plan.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/services/account_service.dart';
import 'package:mindy_app/services/calm_service.dart';
import 'package:mindy_app/services/demo_seeder.dart';
import 'package:mindy_app/services/session_repository.dart';
import 'package:mindy_app/services/worry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v29: the demo child must produce a FULL Research indicators screen.
///
/// Why this test exists: the indicator screen reads per-game event data that
/// only Sorting Stars and Sleepy Fox produce. The demo seeder used to create
/// generic sessions with no events, so four of the six indicators stayed on
/// "Not enough information" even after seeding -- which looks broken in a
/// panel demo even though the app is behaving correctly.
///
/// If this test fails, the demo is broken. Do not present without fixing it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 15, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionRepository.instance.load();
  });

  Future<List<Indicator>> seedAndCompute(DemoScenario sc) async {
    expect(await AccountService.instance.startDemo(), isNull);
    expect(await DemoSeeder.seed(sc, now: now), isNull);
    final id = AccountService.instance.activeChild!.participantId;
    final mine = SessionRepository.instance.allChronological
        .where((s) => s.anonymousChildId == id)
        .toList();
    return RuleIndicators.compute(mine);
  }

  for (final sc in DemoScenario.values) {
    test('${sc.name}: every indicator has enough evidence to say something',
        () async {
      final list = await seedAndCompute(sc);
      expect(list.length, 7); // six original + "What happened after a slip" (v29)
      final stuck = list
          .where((i) => i.level == IndicatorLevel.notEnoughInformation)
          .map((i) => i.title)
          .toList();
      expect(stuck, isEmpty,
          reason: 'these indicators would still read "Not enough '
              'information" in a demo: $stuck');
    });
  }

  test('settling in: nothing crosses a cut-off', () async {
    final list = await seedAndCompute(DemoScenario.settlingIn);
    expect(list.every((i) => i.level == IndicatorLevel.noNotablePattern), isTrue,
        reason: 'the calm scenario should read as unremarkable throughout');
  });

  test('still worried: the three task indicators cross their cut-offs',
      () async {
    final list = await seedAndCompute(DemoScenario.stillWorried);
    Indicator byId(String id) => list.firstWhere((i) => i.id == id);
    // Switch cost, fox taps and missed friends are the three the scenario
    // deliberately pushes over the line, so a demo can show both states.
    expect(byId('flexibility').level, IndicatorLevel.worthReviewing);
    expect(byId('stopping').level, IndicatorLevel.worthReviewing);
    expect(byId('lapses').level, IndicatorLevel.worthReviewing);
  });

  test('the task sessions do not disturb the Support plan', () async {
    // They are dated 31-40 days ago precisely so the plan cannot see them.
    // If this fails, the demo plan and the demo indicators are fighting.
    expect(await AccountService.instance.startDemo(), isNull);
    expect(await DemoSeeder.seed(DemoScenario.settlingIn, now: now), isNull);
    final id = AccountService.instance.activeChild!.participantId;
    final mine = SessionRepository.instance.allChronological
        .where((s) => s.anonymousChildId == id)
        .toList();
    final plan = SupportPlan.build(
      sessions: mine,
      worry: WorryService.instance.entries,
      calm: CalmService.instance.visits,
      now: now,
      childName: 'Demo child',
    );
    expect(plan.band, StateBand.mixed);
    expect(plan.checkIns, 15, reason: 'only the 15 in-window rows should count');
  });

  test('no indicator ever uses diagnostic language', () async {
    const banned = [
      'diagnos', 'disorder', 'adhd', 'autism', 'anxiety', 'anxious',
      'depress', 'symptom', 'condition', 'impair', 'deficit', 'abnormal',
    ];
    for (final sc in DemoScenario.values) {
      final list = await seedAndCompute(sc);
      for (final i in list) {
        final text =
            '${i.title} ${i.headline} ${i.evidence} ${i.alternatives}'
                .toLowerCase();
        for (final b in banned) {
          expect(text.contains(b), isFalse,
              reason: '"$b" appeared in indicator ${i.id} (${sc.name})');
        }
      }
    }
  });
}
