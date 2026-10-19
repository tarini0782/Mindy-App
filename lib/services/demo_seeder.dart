import '../games/engine/adaptive_game_engine.dart';
import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../insights/worry_scale.dart';
import '../models/emotion_state.dart';
import 'account_service.dart';
import 'calm_service.dart';
import 'session_repository.dart';
import 'support_plan_service.dart';
import 'worry_service.dart';

/// Two clearly labelled SAMPLE histories so the Support plan can be shown in
/// a demo without waiting two weeks. They are invented, scripted examples.
/// This only ever runs for the DEMO child (id starts with "DEMO-"), whose
/// data is never uploaded, and it replaces that child's earlier demo data.
///
/// SYNTHETIC / DEVELOPMENT DATA — NOT REAL PARTICIPANT DATA.
enum DemoScenario { settlingIn, stillWorried }

class _Row {
  final int daysAgo;
  final EmotionState before;
  final EmotionState after;
  const _Row(this.daysAgo, this.before, this.after);
}

const _s = EmotionState.scared;
const _sd = EmotionState.sad;
const _n = EmotionState.neutral;
const _c = EmotionState.calm;
const _h = EmotionState.happy;

/// Starts scared or sad, gets steadily calmer. Expect: "Some worried
/// moments", an improving trend, a high settle-after-play share.
const List<_Row> _settling = [
  _Row(13, _s, _c), _Row(13, _sd, _n), _Row(12, _s, _c), _Row(11, _sd, _c),
  _Row(10, _s, _n), _Row(9, _sd, _sd), _Row(8, _s, _c), _Row(7, _n, _c),
  _Row(6, _sd, _c), _Row(5, _n, _h), _Row(4, _c, _h), _Row(3, _n, _c),
  _Row(2, _h, _h), _Row(1, _c, _c), _Row(0, _n, _h),
];

/// Stays scared or sad and play rarely changes it. Expect: "Many worried
/// moments lately" and the gentle "consider talking to a professional" prompt.
const List<_Row> _worried = [
  _Row(13, _s, _s), _Row(12, _sd, _sd), _Row(11, _s, _sd), _Row(10, _sd, _sd),
  _Row(9, _n, _n), _Row(8, _s, _s), _Row(7, _sd, _n), _Row(6, _s, _s),
  _Row(5, _sd, _sd), _Row(4, _s, _sd), _Row(3, _n, _sd), _Row(2, _sd, _sd),
  _Row(1, _s, _s),
];

class DemoSeeder {
  /// Returns an error message, or null on success.
  static Future<String?> seed(DemoScenario scenario, {DateTime? now}) async {
    final child = AccountService.instance.activeChild;
    if (child == null || !child.isDemo) {
      return 'Sample history can only be loaded into the demo child.';
    }
    final id = child.participantId;
    final today = now ?? DateTime.now();
    final rows = scenario == DemoScenario.settlingIn ? _settling : _worried;

    await SessionRepository.instance.deleteForChild(id);
    await WorryService.instance.deleteForChild(id);
    await CalmService.instance.deleteForChild(id);
    await SupportPlanService.instance.deleteForChild(id);
    // Make sure each store is pointed at this child (a no-op in the app, where
    // the account hooks have already done it).
    await WorryService.instance.load(id);
    await CalmService.instance.load(id);
    await SupportPlanService.instance.load(id);

    var i = 0;
    for (final r in rows) {
      final start = DateTime(today.year, today.month, today.day, 16, 10 + i)
          .subtract(Duration(days: r.daysAgo));
      final rec = AdaptiveGameEngine.recommend(emotion: r.before);
      final s = GameSession.fromRecommendation(
        // The child id is part of the session id on purpose. Without it,
        // two demo children seeded with the same scenario produce identical
        // session ids, and SessionRepository.add() silently discards a
        // duplicate id -- so the second child would end up with no sessions
        // and no error anywhere.
        sessionId: 'demo-$id-${scenario.name}-$i',
        anonymousChildId: id,
        emotion: r.before,
        emotionSource: 'APP',
        checkInDurationMs: 1800,
        previousEmotion: null,
        rec: rec,
        startTime: start,
      )
        ..completed = true
        ..completionPercent = 1
        ..successes = 7
        ..mistakes = 2
        ..interactions = 12
        ..durationSeconds = 120
        ..emotionAfter = r.after
        ..endTime = start.add(const Duration(minutes: 2));
      await SessionRepository.instance.add(s);
      i++;
    }

    // ---- task sessions, so the Research indicators have something to read --
    //
    // Why these are separate from the rows above: four of the six indicators
    // read PER-GAME EVENT data that only Sorting Stars and Sleepy Fox
    // produce (rule_change / commission / omission events). Without them the
    // indicator screen says "Not enough information" for everything, which
    // looks broken in a demo even though it is behaving correctly.
    //
    // They are dated 31-40 days ago ON PURPOSE. The Support plan only counts
    // the last 14 days (and 30 for recovery), so these add the indicator
    // evidence without shifting the plan's band, trend or signals.
    await _seedTaskSessions(scenario, id, today);

    if (scenario == DemoScenario.settlingIn) {
      final w = <(int, int, int)>[(12, 3, 2), (9, 3, 2), (6, 2, 1), (3, 2, 1), (1, 1, 0)];
      for (final (d, b, a) in w) {
        final t = DateTime(today.year, today.month, today.day, 15).subtract(Duration(days: d));
        await WorryService.instance.add(WorryPhase.before, b, at: t);
        await WorryService.instance.add(WorryPhase.after, a, at: t.add(const Duration(minutes: 8)));
      }
      for (final d in [11, 6, 2]) {
        await CalmService.instance.add(CalmVisit(
            at: DateTime(today.year, today.month, today.day, 19).subtract(Duration(days: d)),
            activity: 'breathing',
            seconds: 90,
            feelingBefore: 1,
            feelingAfter: 3));
      }
    } else {
      final w = <(int, int, int)>[(10, 3, 3), (6, 4, 3), (2, 3, 3)];
      for (final (d, b, a) in w) {
        final t = DateTime(today.year, today.month, today.day, 15).subtract(Duration(days: d));
        await WorryService.instance.add(WorryPhase.before, b, at: t);
        await WorryService.instance.add(WorryPhase.after, a, at: t.add(const Duration(minutes: 8)));
      }
    }
    return null;
  }

  /// Sorting Stars and Sleepy Fox sessions carrying the event log that the
  /// Research indicators read. Dated well outside the Support plan's
  /// windows so the plan is unaffected (see the call site).
  ///
  /// The numbers differ by scenario on purpose, so a demo can show BOTH
  /// states of an indicator:
  ///   settlingIn    -> every indicator reads "nothing stood out"
  ///   stillWorried  -> switch cost, fox taps and missed friends all cross
  ///                    their cut-off and read "worth reviewing"
  ///
  /// These are invented demonstration values, not measurements.
  static Future<void> _seedTaskSessions(
      DemoScenario scenario, String id, DateTime today) async {
    final worried = scenario == DemoScenario.stillWorried;

    // Per Sorting Stars session: 4 answers in the 2-card window after each
    // rule change, and 8 answers elsewhere.
    final postErrPer = worried ? 2 : 0; // of 4 post-switch answers
    final otherErrPer = worried ? 1 : 1; // of 8 other answers
    // Per Sleepy Fox session at level 3: 5 fox items, 11 friend items.
    final foxTapsPer = worried ? 2 : 0; // commissions, of 5 foxes
    final missedPer = worried ? 3 : 1; // omissions, of 11 friends
    // Response-time spread: sd / mean. 0.60 and above is "worth reviewing".
    final avgMs = worried ? 1500.0 : 1200.0;
    final sdMs = worried ? 1020.0 : 400.0; // cv 0.68 vs 0.33

    var n = 0;
    Future<void> add(GameType game, int daysAgo, List<TrialEvent> events,
        int successes, int mistakes) async {
      final start = DateTime(today.year, today.month, today.day, 17, 5 + n)
          .subtract(Duration(days: daysAgo));
      // game and level are final on GameSession, so they have to come from
      // the recommendation. Restricting the pool to this one activity makes
      // the engine return it; a neutral check-in puts the level at 3, which
      // is what FoxParams/SortLogic are counted against above.
      final rec = AdaptiveGameEngine.recommend(
        emotion: EmotionState.neutral,
        pool: [game],
      );
      final s = GameSession.fromRecommendation(
        sessionId: 'demo-$id-task-${scenario.name}-$n',
        anonymousChildId: id,
        emotion: EmotionState.neutral,
        emotionSource: 'APP',
        checkInDurationMs: 1700,
        previousEmotion: null,
        rec: rec,
        startTime: start,
      )
        ..completed = true
        ..completionPercent = 1
        ..successes = successes
        ..mistakes = mistakes
        ..interactions = successes + mistakes
        ..durationSeconds = 150
        ..avgResponseMs = avgMs
        ..responseTimeVariabilityMs = sdMs
        ..emotionAfter = EmotionState.calm
        ..events = events
        ..endTime = start.add(const Duration(minutes: 3));
      await SessionRepository.instance.add(s);
      n++;
    }

    // --- Sorting Stars: 3 sessions, each with two rule changes -------------
    for (var i = 0; i < 3; i++) {
      final ev = <TrialEvent>[];
      var t = 0;
      void answer(bool ok) {
        ev.add(TrialEvent(t += 1400, ok ? 'success' : 'mistake'));
      }

      var postErrLeft = postErrPer, otherErrLeft = otherErrPer;
      for (var block = 0; block < 2; block++) {
        ev.add(TrialEvent(t += 900, 'rule_change'));
        for (var k = 0; k < 2; k++) {
          // the 2 cards after a switch count as post-switch
          final err = postErrLeft > 0;
          if (err) postErrLeft--;
          answer(!err);
        }
        for (var k = 0; k < 4; k++) {
          final err = otherErrLeft > 0 && k == 0;
          if (err) otherErrLeft--;
          answer(!err);
        }
      }
      final mistakes = postErrPer + otherErrPer;
      await add(GameType.ruleShift, 40 - i * 2, ev, 12 - mistakes, mistakes);
    }

    // --- Sleepy Fox: 3 sessions -------------------------------------------
    for (var i = 0; i < 3; i++) {
      final ev = <TrialEvent>[];
      var t = 0;
      for (var k = 0; k < foxTapsPer; k++) {
        ev.add(TrialEvent(t += 1600, 'commission'));
      }
      for (var k = 0; k < missedPer; k++) {
        ev.add(TrialEvent(t += 1600, 'omission'));
      }
      final mistakes = foxTapsPer + missedPer;
      await add(GameType.sleepyFox, 35 - i * 2, ev, 16 - mistakes, mistakes);
    }
  }
}
