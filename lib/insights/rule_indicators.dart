import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../games/rule_shift_game.dart';
import '../games/sleepy_fox_game.dart';

/// RULE-BASED OBSERVATIONS (version [kRuleVersion]).
///
/// No machine learning and no dataset are needed: every observation is an
/// explicit IF-THEN rule on the event log, with the numbers written below so
/// a supervisor can read, challenge and change them. The cut-offs are
/// ENGINEERING RULES chosen to give cautious wording. They are NOT clinical
/// thresholds and have not been validated against any independent measure
/// (see docs/RULE_VALIDATION_PLAN.md).
///
/// These are descriptions of what happened in play. They never say that a
/// child has, or may have, any condition. A missed target, a tap at the wrong
/// moment or a slower response can have many ordinary explanations; each card
/// lists some in [Indicator.alternatives].
const String kRuleVersion = 'rules-v2';

enum IndicatorLevel {
  /// Not enough play yet. No score is shown.
  notEnoughInformation,

  /// Nothing stood out in this data.
  noNotablePattern,

  /// Worth looking at again across more sessions. NOT a finding.
  worthReviewing,
}

class Indicator {
  final String id;
  final String title;
  final IndicatorLevel level;
  final String headline; // one neutral sentence about what was observed
  final String evidence; // the numbers behind it
  final String rule; // the IF-THEN rule, in plain words
  final String alternatives; // other reasons for the same observation
  const Indicator({
    required this.id,
    required this.title,
    required this.level,
    required this.headline,
    required this.evidence,
    required this.rule,
    required this.alternatives,
  });
}

class IndicatorRules {
  IndicatorRules._();
  // Minimum evidence before any observation is shown.
  static const int minSessionsPerGame = 2; // finished sessions of that game
  static const int minAnswersPostSwitch = 6;
  static const int minAnswersOther = 12;
  static const int minFoxItems = 6;
  static const int minFriendItems = 12;
  static const int minRtSessions = 3;
  static const int minSessionsForMood = 4;
  static const int minSessionsForCompletion = 4;
  // v29 "after a slip": how many attempts counted as "just after a setback",
  // and the minimum evidence before anything is said.
  static const int setbackWindow = 3;
  static const int minAttemptsAfterSetback = 6;
  static const int minAttemptsOther = 12;

  // One cut-off each: at or above it the observation is "worth reviewing".
  static const double switchCost = 0.15; // error-rate difference
  static const double commission = 0.30; // share of fox items tapped
  static const double omission = 0.25; // share of friends missed
  static const double rtCv = 0.60; // sd / mean of response time
  static const double completionBelow = 0.70; // finished share
  static const double moodDownAtOrBelow = -0.4; // mean feeling change
  static const double setbackCost = 0.20; // error-rate rise after a slip
}

/// Attempts in the [IndicatorRules.setbackWindow] right after a mistake,
/// against every other attempt, plus how long the child waited before
/// trying again.
class SetbackStats {
  final int afterN, afterErr, otherN, otherErr;
  final List<int> pauseMs; // gap from the mistake to the next attempt
  const SetbackStats(
      this.afterN, this.afterErr, this.otherN, this.otherErr, this.pauseMs);

  double? get afterRate => afterN == 0 ? null : afterErr / afterN;
  double? get otherRate => otherN == 0 ? null : otherErr / otherN;

  int? get medianPauseMs {
    if (pauseMs.isEmpty) return null;
    final s = [...pauseMs]..sort();
    return s.length.isOdd
        ? s[s.length ~/ 2]
        : ((s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2).round();
  }
}

class SwitchStats {
  final int postN, postErr, otherN, otherErr;
  const SwitchStats(this.postN, this.postErr, this.otherN, this.otherErr);
  double? get postRate => postN == 0 ? null : postErr / postN;
  double? get otherRate => otherN == 0 ? null : otherErr / otherN;
}

class RuleIndicators {
  RuleIndicators._();

  /// Errors in the first [SortLogic.kWindow] answers after each rule_change
  /// versus all other answers, from the event log of one session.
  static SwitchStats switchStats(GameSession s) {
    var since = -1; // -1 = before any switch
    var postN = 0, postErr = 0, otherN = 0, otherErr = 0;
    for (final e in s.events) {
      if (e.type == 'rule_change') {
        since = 0;
        continue;
      }
      if (e.type != 'success' && e.type != 'mistake') continue;
      final post = since >= 0 && since < SortLogic.kWindow;
      final err = e.type == 'mistake';
      if (post) {
        postN++;
        if (err) postErr++;
      } else {
        otherN++;
        if (err) otherErr++;
      }
      if (since >= 0) since++;
    }
    return SwitchStats(postN, postErr, otherN, otherErr);
  }

  /// Attempts just after a mistake versus every other attempt, from one
  /// session's event log. Works for ANY activity, because every game logs a
  /// timestamped 'success' / 'mistake' through the same controller -- which
  /// is why this needed no change to the 27 games.
  static SetbackStats setbackStats(GameSession s) {
    var since = -1; // -1 = no mistake yet
    var afterN = 0, afterErr = 0, otherN = 0, otherErr = 0;
    int? lastMistakeMs;
    final pauses = <int>[];
    for (final e in s.events) {
      if (e.type != 'success' && e.type != 'mistake') continue;
      if (lastMistakeMs != null) {
        pauses.add(e.tMs - lastMistakeMs);
        lastMistakeMs = null;
      }
      final isAfter = since >= 0 && since < IndicatorRules.setbackWindow;
      final err = e.type == 'mistake';
      if (isAfter) {
        afterN++;
        if (err) afterErr++;
      } else {
        otherN++;
        if (err) otherErr++;
      }
      if (since >= 0) since++;
      if (err) {
        since = 0; // a new slip restarts the window
        lastMistakeMs = e.tMs;
      }
    }
    return SetbackStats(afterN, afterErr, otherN, otherErr, pauses);
  }

  static List<GameSession> _done(List<GameSession> all, GameType g) =>
      all.where((s) => s.game == g && s.completed).toList();

  static String _pct(double v) => '${(v * 100).round()}%';

  static Indicator _none(String id, String title, String rule, String alt,
          String need) =>
      Indicator(
        id: id,
        title: title,
        level: IndicatorLevel.notEnoughInformation,
        headline: 'Still learning. $need',
        evidence: '',
        rule: rule,
        alternatives: alt,
      );

  static Indicator _make(String id, String title, bool review, String quiet,
          String noted, String evidence, String rule, String alt) =>
      Indicator(
        id: id,
        title: title,
        level: review
            ? IndicatorLevel.worthReviewing
            : IndicatorLevel.noNotablePattern,
        headline: review ? noted : quiet,
        evidence: evidence,
        rule: rule,
        alternatives: alt,
      );

  /// All observations for ONE child's research sessions (practice is never
  /// stored, so every session here is research data).
  static List<Indicator> compute(List<GameSession> sessions) => [
        flexibility(sessions),
        stopping(sessions),
        lapses(sessions),
        steadiness(sessions),
        finishing(sessions),
        mood(sessions),
        recovery(sessions),
      ];

  // ------------------------------------- 7. what happens after a setback
  /// The "obstacle" observation: in games with something to get wrong, does
  /// a slip tend to be followed by more slips, and does the child pause
  /// longer before trying again?
  ///
  /// This describes play. It is not a measure of frustration tolerance,
  /// resilience, or any trait, and must never be written up as one.
  static Indicator recovery(List<GameSession> all) {
    const rule =
        'Any activity with right/wrong moments. Error rate in the 3 attempts '
        'after a mistake versus all other attempts. IF the rise is >= 20 '
        'percentage points THEN "worth reviewing". Needs 2 finished sessions, '
        '6 attempts after a mistake and 12 other attempts.';
    const alt = 'A harder patch of the game, a new rule just introduced, '
        'wanting to hurry, losing interest, tiredness, or an awkward hand '
        'position. A pause can also simply be the child thinking.';
    const title = 'What happened after a slip';

    var afterN = 0, afterErr = 0, otherN = 0, otherErr = 0, sessions = 0;
    final pauses = <int>[];
    for (final s in all) {
      if (!s.completed) continue;
      final st = setbackStats(s);
      if (st.afterN == 0 && st.otherN == 0) continue;
      sessions++;
      afterN += st.afterN;
      afterErr += st.afterErr;
      otherN += st.otherN;
      otherErr += st.otherErr;
      pauses.addAll(st.pauseMs);
    }
    if (sessions < IndicatorRules.minSessionsPerGame ||
        afterN < IndicatorRules.minAttemptsAfterSetback ||
        otherN < IndicatorRules.minAttemptsOther) {
      return _none('recovery', title, rule, alt,
          'A few more activities with right and wrong moments are needed.');
    }
    final afterRate = afterErr / afterN;
    final otherRate = otherErr / otherN;
    final rise = afterRate - otherRate;
    final med = SetbackStats(0, 0, 0, 0, pauses).medianPauseMs;
    final pauseText = med == null
        ? ''
        : ' Typical wait before trying again: '
            '${(med / 1000).toStringAsFixed(1)} s.';
    return _make(
        'recovery',
        title,
        rise >= IndicatorRules.setbackCost,
        'After a slip, play carried on much as before.',
        'Slips tended to be followed by more slips.',
        'Mistakes: ${_pct(afterRate)} in the $afterN attempts after a slip, '
            'against ${_pct(otherRate)} in $otherN other attempts.$pauseText',
        rule,
        alt);
  }

  // ---------------------------------------------------- 1. rule changes
  static Indicator flexibility(List<GameSession> all) {
    const rule =
        'Sorting Stars. Switch cost = error rate in the first 2 cards after a '
        'rule change minus error rate at other times. IF switch cost >= 0.15 '
        'THEN "worth reviewing". Needs 2 finished sessions, 6 cards after a '
        'change and 12 other cards.';
    const alt = 'Not yet understanding the new rule, tapping the wrong box by '
        'accident, tiredness, a slow or unresponsive screen, or just chance with so few cards.';
    const title = 'Mistakes right after a rule change';
    final sessions = _done(all, GameType.ruleShift);
    var a = 0, b = 0, c = 0, d = 0;
    for (final s in sessions) {
      final st = switchStats(s);
      a += st.postN;
      b += st.postErr;
      c += st.otherN;
      d += st.otherErr;
    }
    if (sessions.length < IndicatorRules.minSessionsPerGame ||
        a < IndicatorRules.minAnswersPostSwitch ||
        c < IndicatorRules.minAnswersOther) {
      return _none('flexibility', title, rule, alt,
          'Play Sorting Stars a few more times.');
    }
    final cost = b / a - d / c;
    return _make(
        'flexibility',
        title,
        cost >= IndicatorRules.switchCost,
        'No notable difference in mistakes after a rule change.',
        'More mistakes happened right after the rule changed than at other times.',
        'After a change: ${_pct(b / a)} ($b of $a). Otherwise: ${_pct(d / c)} ($d of $c). Difference ${_pct(cost)}.',
        rule,
        alt);
  }

  // ------------------------------------------------- 2. stopping a tap
  static Indicator stopping(List<GameSession> all) {
    const rule =
        'Sleepy Fox. Tap rate = taps on the sleeping fox / fox items. IF >= 30% '
        'THEN "worth reviewing". Needs 2 finished sessions and 6 fox items.';
    const alt = 'Not noticing the fox in time, a fast tapping habit from other '
        'games, excitement, not understanding the instruction, or screen delay.';
    const title = 'Tapping when asked to wait';
    final sessions = _done(all, GameType.sleepyFox);
    var foxes = 0, taps = 0;
    for (final s in sessions) {
      foxes += FoxParams.forLevel(s.level).foxCount;
      taps += s.events.where((e) => e.type == 'commission').length;
    }
    if (sessions.length < IndicatorRules.minSessionsPerGame ||
        foxes < IndicatorRules.minFoxItems) {
      return _none('stopping', title, rule, alt, 'Play Sleepy Fox a few more times.');
    }
    final r = taps / foxes;
    return _make(
        'stopping',
        title,
        r >= IndicatorRules.commission,
        'The sleeping fox was mostly left alone.',
        'The sleeping fox was tapped fairly often.',
        'Tapped the sleeping fox $taps of $foxes times (${_pct(r)}).',
        rule,
        alt);
  }

  // ------------------------------------------------ 3. attention lapses
  static Indicator lapses(List<GameSession> all) {
    const rule =
        'Sleepy Fox. Miss rate = friends not tapped / friend items. IF >= 25% '
        'THEN "worth reviewing". Needs 2 finished sessions and 12 friend items.';
    const alt = 'Looking away, a hand covering the screen, a very short answer '
        'time at higher levels, motor difficulty, tiredness, or screen delay.';
    const title = 'Friends that were not tapped';
    final sessions = _done(all, GameType.sleepyFox);
    var friends = 0, missed = 0;
    for (final s in sessions) {
      final p = FoxParams.forLevel(s.level);
      friends += p.items - p.foxCount;
      missed += s.events.where((e) => e.type == 'omission').length;
    }
    if (sessions.length < IndicatorRules.minSessionsPerGame ||
        friends < IndicatorRules.minFriendItems) {
      return _none('lapses', title, rule, alt, 'Play Sleepy Fox a few more times.');
    }
    final r = missed / friends;
    return _make(
        'lapses',
        title,
        r >= IndicatorRules.omission,
        'Most friends were tapped in time.',
        'A number of friends were not tapped before they left.',
        'Not tapped: $missed of $friends friends (${_pct(r)}).',
        rule,
        alt);
  }

  // ------------------------------------------ 4. steadiness of speed
  static Indicator steadiness(List<GameSession> all) {
    const rule =
        'All games. For each finished session: sd / mean of response times. '
        'Take the middle value across sessions. IF >= 0.60 THEN "worth '
        'reviewing". Needs 3 finished sessions with 3+ timed responses.';
    const alt = 'Different games ask for different speeds, difficulty changed '
        'between sessions, pauses, learning during the session, or device speed.';
    const title = 'How even the response speed was';
    final cvs = <double>[];
    for (final s in all) {
      final m = s.avgResponseMs, sd = s.responseTimeVariabilityMs;
      if (s.completed && m != null && sd != null && m > 0) cvs.add(sd / m);
    }
    if (cvs.length < IndicatorRules.minRtSessions) {
      return _none('steadiness', title, rule, alt,
          'A few more finished activities are needed.');
    }
    cvs.sort();
    final mid = cvs.length.isOdd
        ? cvs[cvs.length ~/ 2]
        : (cvs[cvs.length ~/ 2 - 1] + cvs[cvs.length ~/ 2]) / 2;
    return _make(
        'steadiness',
        title,
        mid >= IndicatorRules.rtCv,
        'Response speed was fairly even within sessions.',
        'Response speed varied quite a lot within sessions.',
        'Middle variability across ${cvs.length} sessions: ${mid.toStringAsFixed(2)}.',
        rule,
        alt);
  }

  // ------------------------------------------------ 5. finishing
  static Indicator finishing(List<GameSession> all) {
    const rule =
        'Share of started activities that were finished. IF below 70% THEN '
        '"worth reviewing". Needs 4 sessions. Support used during a finished '
        'activity is reported in the evidence line, not counted against it.';
    const alt = 'A game that was too easy or too hard, being called away, '
        'wanting a different game, tiredness, or an accidental exit.';
    const title = 'Finishing activities';
    if (all.length < IndicatorRules.minSessionsForCompletion) {
      return _none('finishing', title, rule, alt, 'A few more activities are needed.');
    }
    final done = all.where((s) => s.completed).length;
    final withSupport = all.where((s) => s.completed && s.supportCount > 0).length;
    final r = done / all.length;
    return _make(
        'finishing',
        title,
        r < IndicatorRules.completionBelow,
        'Most activities were finished.',
        'Several activities were stopped before the end.',
        'Finished $done of ${all.length} (${_pct(r)}). '
            'Finished with some help from Mindy: $withSupport.',
        rule,
        alt);
  }

  // ------------------------------------------------ 6. feelings
  static Indicator mood(List<GameSession> all) {
    const rule =
        'The feeling the child picked before and after play (1 to 5). Mean '
        'change over sessions with both answers. IF mean <= -0.4 THEN "worth '
        'reviewing". Needs 4 sessions with both check-ins. Self-report only.';
    const alt = 'How the child felt before the game, which game it was, a '
        'tired end of day, picking a picture quickly, or not understanding the faces.';
    const title = 'Feelings picked before and after play';
    final ds = [
      for (final s in all)
        if (s.moodDelta != null) s.moodDelta!
    ];
    if (ds.length < IndicatorRules.minSessionsForMood) {
      return _none('mood', title, rule, alt,
          'More check-ins before and after play are needed.');
    }
    final mean = ds.reduce((a, b) => a + b) / ds.length;
    return _make(
        'mood',
        title,
        mean <= IndicatorRules.moodDownAtOrBelow,
        mean >= 0.4
            ? 'The feeling picked after play was usually the same or brighter.'
            : 'The feeling picked stayed about the same after play.',
        'The feeling picked after play was often lower than before.',
        'Average change ${mean >= 0 ? '+' : ''}${mean.toStringAsFixed(2)} over ${ds.length} sessions.',
        rule,
        alt);
  }
}
