import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../models/emotion_state.dart';
import '../services/calm_service.dart' show CalmVisit;
import 'what_helps.dart' show WhatHelps;
import 'worry_scale.dart';

/// How the last two weeks of check-ins look, in plain words.
/// This describes what the child SAID in Mindy. It is not a diagnosis and not
/// a measure of any condition.
enum StateBand { settled, mixed, unsettled, notEnough }

enum SignalTone { good, neutral, attention }

/// When a suggestion is worth doing. `consider` is a gentle prompt to talk to
/// a professional, never an instruction.
enum ActionKind { now, thisWeek, consider }

class PlanSignal {
  final String ruleId;
  final String title;
  final String detail;
  final String evidence;
  final SignalTone tone;
  const PlanSignal(this.ruleId, this.title, this.detail, this.evidence, this.tone);
}

class PlanAction {
  /// Stable id, also the rule that produced it (used to remember the
  /// caregiver's choice: trying / not now).
  final String id;
  final ActionKind kind;
  final String title;
  final String why; // the rule's reason, in plain words
  final List<String> steps;

  /// Filled only when the caregiver said "I'll try this" earlier: a plain
  /// before/after description of check-ins, with its limits.
  final String? followUp;
  const PlanAction({
    required this.id,
    required this.kind,
    required this.title,
    required this.why,
    required this.steps,
    this.followUp,
  });
}

/// One day of the 14-day strip: average feeling (1 scared .. 5 happy) or null.
class DayFeeling {
  final DateTime day;
  final int checkIns;
  final double? mean;
  const DayFeeling(this.day, this.checkIns, this.mean);
}

class SupportPlan {
  final StateBand band;
  final String headline;
  final String summary;
  final String confidence;
  final int checkIns;
  final int lowCount;
  final List<PlanSignal> signals;
  final List<PlanAction> actions;
  final List<DayFeeling> days; // oldest first, always [windowDays] long
  final String caution;

  /// The child's nickname, as it was woven into [headline], [summary] and
  /// the signal and action wording. Stored so anything that leaves the
  /// device can strip it back out again -- see InsightSummaryService.
  /// Null when no nickname was given (the wording then says "your child").
  final String? childName;

  const SupportPlan({
    required this.band,
    required this.headline,
    required this.summary,
    required this.confidence,
    required this.checkIns,
    required this.lowCount,
    required this.signals,
    required this.actions,
    required this.days,
    required this.caution,
    this.childName,
  });

  // ---------------------------------------------------------------- rules
  // Engineering thresholds chosen for a prototype. They are NOT clinical
  // cut-offs and have not been validated; they should be reviewed with the
  // supervisors and revisited once pilot data exists.
  static const int windowDays = 14;
  static const int minCheckIns = 4;
  static const double unsettledShare = 0.6;
  static const double mixedShare = 0.3;
  static const int minPerHalf = 3;
  static const double trendGap = 0.25;
  static const int minForProfessionalPrompt = 8;
  static const String _caution =
      'This plan is built from what your child tapped in Mindy. It cannot '
      'diagnose anything or say why a feeling appears. Tiredness, hunger, '
      'school and family changes all matter. You know your child best: if you '
      'are worried, speak to your child\'s doctor or school counsellor. If '
      'your child talks about hurting themselves, or you feel they are not '
      'safe, contact a doctor or emergency services straight away.';

  static bool _isLow(EmotionState e) => e.moodScore <= 2;

  static bool _countable(GameSession s) =>
      s.trigger != 'feed' &&
      s.emotionBefore != null &&
      s.emotionSource != 'KARA_SIMULATED';

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  static int _daysAgo(DateTime t, DateTime now) =>
      _day(now).difference(_day(t)).inDays;

  /// Builds the plan. Pure function of its inputs: same data, same plan.
  /// [tryingSince] maps an action id to the day the caregiver chose to try it.
  /// Suggestions the caregiver set aside are still shown (just marked) by the
  /// screen, so nothing is hidden from the grown-up.
  static SupportPlan build({
    required List<GameSession> sessions,
    required List<WorryEntry> worry,
    required List<CalmVisit> calm,
    required DateTime now,
    String? childName,
    Map<String, DateTime> tryingSince = const {},
  }) {
    final who = (childName == null || childName.trim().isEmpty)
        ? 'your child'
        : childName.trim();

    final all = sessions.where(_countable).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final win = all.where((s) => _daysAgo(s.startTime, now) < windowDays).toList();
    final n = win.length;
    final low = win.where((s) => _isLow(s.emotionBefore!)).length;
    final lowShare = n == 0 ? 0.0 : low / n;

    // ---- 14-day strip
    final days = <DayFeeling>[];
    for (var i = windowDays - 1; i >= 0; i--) {
      final d = _day(now).subtract(Duration(days: i));
      final dayList = win.where((s) => _day(s.startTime) == d).toList();
      days.add(DayFeeling(
          d,
          dayList.length,
          dayList.isEmpty
              ? null
              : dayList.map((s) => s.emotionBefore!.moodScore).reduce((a, b) => a + b) /
                  dayList.length));
    }

    // ---- band
    final StateBand band;
    if (n < minCheckIns) {
      band = StateBand.notEnough;
    } else if (lowShare >= unsettledShare) {
      band = StateBand.unsettled;
    } else if (lowShare >= mixedShare) {
      band = StateBand.mixed;
    } else {
      band = StateBand.settled;
    }

    // ---- trend: last 7 days vs the 7 before (both need enough check-ins)
    final last7 = win.where((s) => _daysAgo(s.startTime, now) < 7).toList();
    final prev7 = win.where((s) => _daysAgo(s.startTime, now) >= 7).toList();
    String trend = 'unknown'; // improving | worsening | steady | unknown
    double? lastShare, prevShare;
    if (last7.length >= minPerHalf && prev7.length >= minPerHalf) {
      lastShare = last7.where((s) => _isLow(s.emotionBefore!)).length / last7.length;
      prevShare = prev7.where((s) => _isLow(s.emotionBefore!)).length / prev7.length;
      if (lastShare <= prevShare - trendGap) {
        trend = 'improving';
      } else if (lastShare >= prevShare + trendGap) {
        trend = 'worsening';
      } else {
        trend = 'steady';
      }
    }

    // ---- recovery + best activity type (last 30 days, low starts only)
    final lowStarts = all
        .where((s) =>
            _daysAgo(s.startTime, now) < 30 &&
            _isLow(s.emotionBefore!) &&
            s.emotionAfter != null)
        .toList();
    double? recovery;
    if (lowStarts.length >= 3) {
      recovery = lowStarts.where((s) => s.moodDelta! > 0).length / lowStarts.length;
    }
    ActivityRole? bestRole;
    {
      final by = <ActivityRole, List<GameSession>>{};
      for (final s in lowStarts) {
        by.putIfAbsent(s.game.role, () => []).add(s);
      }
      final means = <ActivityRole, double>{};
      by.forEach((r, l) {
        if (l.length >= 2) {
          means[r] = l.map((s) => s.moodDelta!).reduce((a, b) => a + b) / l.length;
        }
      });
      if (means.isNotEmpty) {
        final ranked = means.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = ranked.first;
        final clear = ranked.length == 1 ||
            top.value - ranked[1].value >= WhatHelps.clearGap;
        if (top.value > 0 && clear) bestRole = top.key;
      }
    }

    // ---- worry scale (last 30 days)
    final w30 = worry.where((e) => _daysAgo(e.at, now) < 30).toList();
    final wChanges = worryChanges(w30);
    final wMean = wChanges.length >= 2
        ? wChanges.reduce((a, b) => a + b) / wChanges.length
        : null;
    final befores = (w30.where((e) => e.phase == WorryPhase.before).toList()
          ..sort((a, b) => a.at.compareTo(b.at)));
    final latestBefore = befores.isEmpty ? null : befores.last.level;
    // "stays high": the last two AFTER answers were both 3 or 4.
    final afters = (w30.where((e) => e.phase == WorryPhase.after).toList()
          ..sort((a, b) => a.at.compareTo(b.at)));
    final worryStaysHigh = afters.length >= 2 &&
        afters[afters.length - 1].level >= 3 &&
        afters[afters.length - 2].level >= 3;

    // ---- Calm Corner (self-chosen)
    final calm14 = calm.where((v) => _daysAgo(v.at, now) < windowDays).toList();
    final ratedCalm =
        calm14.where((v) => v.feelingBefore > 0 && v.feelingAfter > 0).toList();
    final calmBetter = ratedCalm.length >= 2
        ? ratedCalm.where((v) => v.feelingAfter > v.feelingBefore).length /
            ratedCalm.length
        : null;

    // ---- stopping early (adventure sessions only)
    double? quitLast, quitPrev;
    {
      final adv = all.where((s) => _daysAgo(s.startTime, now) < windowDays).toList();
      final l = adv.where((s) => _daysAgo(s.startTime, now) < 7).toList();
      final p = adv.where((s) => _daysAgo(s.startTime, now) >= 7).toList();
      if (l.length >= minPerHalf && p.length >= minPerHalf) {
        quitLast = l.where((s) => !s.completed).length / l.length;
        quitPrev = p.where((s) => !s.completed).length / p.length;
      }
    }

    // ============================================================ headline
    final String headline;
    final String summary;
    switch (band) {
      case StateBand.notEnough:
        headline = 'Getting to know $who';
        summary = 'Mindy needs at least $minCheckIns feeling check-ins from the '
            'last $windowDays days before it can say anything useful. So far: $n.';
        break;
      case StateBand.settled:
        headline = 'Mostly settled';
        summary = 'In the last $windowDays days $who said they felt scared or sad '
            'at $low of $n check-ins. Most check-ins were okay, calm or happy.';
        break;
      case StateBand.mixed:
        headline = 'Some worried moments';
        summary = '$who said they felt scared or sad at $low of $n check-ins in '
            'the last $windowDays days. Some days were easier than others.';
        break;
      case StateBand.unsettled:
        headline = 'Many worried moments lately';
        summary = '$who said they felt scared or sad at $low of $n check-ins in '
            'the last $windowDays days. That is more than half of them.';
        break;
    }
    final confidence = n == 0
        ? 'No check-ins in the last $windowDays days'
        : 'Based on $n check-in${n == 1 ? '' : 's'} in the last $windowDays days'
            '${n < 8 ? ' (a small number, so treat this loosely)' : ''}';

    // ============================================================ signals
    final signals = <PlanSignal>[];
    if (n >= minCheckIns) {
      signals.add(PlanSignal(
        'S_FEELINGS',
        'How $who has been feeling',
        'Scared or sad at $low of $n check-ins; okay, calm or happy at ${n - low}.',
        confidence,
        band == StateBand.settled
            ? SignalTone.good
            : band == StateBand.mixed
                ? SignalTone.neutral
                : SignalTone.attention,
      ));
    }
    if (trend != 'unknown') {
      final a = (lastShare! * 100).round();
      final b = (prevShare! * 100).round();
      signals.add(PlanSignal(
        'S_TREND',
        trend == 'improving'
            ? 'Feeling lower less often than last week'
            : trend == 'worsening'
                ? 'Feeling lower more often than last week'
                : 'About the same as last week',
        'Scared or sad at $a% of check-ins in the last 7 days, compared with '
            '$b% in the 7 days before.',
        'Based on ${last7.length} and ${prev7.length} check-ins',
        trend == 'improving'
            ? SignalTone.good
            : trend == 'worsening'
                ? SignalTone.attention
                : SignalTone.neutral,
      ));
    }
    if (recovery != null) {
      final better = lowStarts.where((s) => s.moodDelta! > 0).length;
      final pct = (recovery * 100).round();
      signals.add(PlanSignal(
        'S_RECOVERY',
        recovery >= 0.6
            ? '$who usually feels better after playing'
            : recovery >= 0.4
                ? 'Playing sometimes helps $who feel better'
                : 'Playing has not often changed how $who feels',
        'When $who started scared or sad, the feeling they picked afterwards was '
            'higher in $better of ${lowStarts.length} activities ($pct%).'
            '${bestRole == null ? '' : ' ${_cap(WhatHelps.roleName(bestRole))} went with the biggest lift.'}',
        'Based on ${lowStarts.length} activities that started low (last 30 days)',
        recovery >= 0.6
            ? SignalTone.good
            : recovery >= 0.4
                ? SignalTone.neutral
                : SignalTone.attention,
      ));
    }
    if (wMean != null) {
      signals.add(PlanSignal(
        'S_WORRY',
        wMean <= -0.5
            ? 'Worry picture scale: lower after play'
            : wMean >= 0.5
                ? 'Worry picture scale: higher after play'
                : 'Worry picture scale: about the same after play',
        'Across ${wChanges.length} before/after pairs, the worry faces moved by '
            '${wMean >= 0 ? '+' : ''}${wMean.toStringAsFixed(1)} on average '
            '(0 = not worried, 4 = the most worried).',
        'Based on ${wChanges.length} pairs. This simple scale is a prototype, not a validated test.',
        wMean <= -0.5
            ? SignalTone.good
            : wMean >= 0.5
                ? SignalTone.attention
                : SignalTone.neutral,
      ));
    }
    if (latestBefore != null && latestBefore >= 3) {
      signals.add(PlanSignal(
        'S_WORRY_HIGH',
        'Worry was high before the last play',
        '$who chose "${kWorryLabels[latestBefore]}" on the worry faces before playing.',
        'Latest "before" answer',
        SignalTone.attention,
      ));
    }
    if (calm14.isNotEmpty) {
      signals.add(PlanSignal(
        'S_CALM',
        '$who used the Calm Corner by choice',
        'Visited ${calm14.length} time${calm14.length == 1 ? '' : 's'} in the last $windowDays days.'
            '${calmBetter == null ? '' : ' Felt better afterwards at ${(calmBetter * 100).round()}% of the visits that asked.'}',
        'Self-chosen calming, not a research session',
        calmBetter != null && calmBetter >= 0.5
            ? SignalTone.good
            : SignalTone.neutral,
      ));
    }
    if (quitLast != null && quitPrev != null && quitLast >= quitPrev + 0.34) {
      signals.add(PlanSignal(
        'S_QUIT',
        'Stopping activities early more often',
        'Activities were left unfinished ${(quitLast * 100).round()}% of the time this '
            'week, up from ${(quitPrev * 100).round()}% the week before. Tiredness, '
            'boredom or a level that is too hard are all common reasons.',
        'Based on activities in the last $windowDays days',
        SignalTone.neutral,
      ));
    }

    // ============================================================ actions
    final actions = <PlanAction>[];
    String? follow(String id) {
      final since = tryingSince[id];
      if (since == null) return null;
      final before = all.where((s) {
        final d = _day(s.startTime);
        return d.isBefore(_day(since)) && _day(since).difference(d).inDays <= 14;
      }).toList();
      final after = all.where((s) => !_day(s.startTime).isBefore(_day(since))).toList();
      if (before.length < minPerHalf || after.length < minPerHalf) {
        return 'Not enough check-ins yet to compare before and after '
            '(need $minPerHalf on each side; so far ${before.length} before, '
            '${after.length} after).';
      }
      final lb = before.where((s) => _isLow(s.emotionBefore!)).length;
      final la = after.where((s) => _isLow(s.emotionBefore!)).length;
      return 'Scared or sad at $lb of ${before.length} check-ins before you started, '
          'and $la of ${after.length} since. This is a comparison, not proof that '
          'it was the cause.';
    }

    void add(String id, ActionKind kind, String title, String why, List<String> steps) =>
        actions.add(PlanAction(
            id: id, kind: kind, title: title, why: why, steps: steps, followUp: follow(id)));

    if (band == StateBand.notEnough) {
      add(
        'A_MORE_CHECKINS',
        ActionKind.now,
        'Play a few short Calm Quest sessions',
        'There are only $n check-ins in the last $windowDays days, which is too few to see a pattern.',
        [
          'Open Calm Quest and let $who pick a feeling before each game.',
          'Try about 4 check-ins over a few days. Short sessions are fine.',
          'Come back here and the plan will fill in.',
        ],
      );
    }
    if (band == StateBand.settled) {
      add(
        'A_KEEP_GOING',
        ActionKind.now,
        'Keep the routine going and notice the good days',
        'Most check-ins were okay, calm or happy.',
        [
          'Keep short, regular play sessions. Little and often works better than long.',
          'Praise the effort ("You tried the breathing game, well done"), not just the score.',
          'Before any medical visit, play one calm game together the evening before.',
        ],
      );
    }
    if (bestRole != null) {
      final r = WhatHelps.roleName(bestRole);
      add(
        'A_USE_WHAT_HELPS',
        ActionKind.now,
        'Start with $r when $who feels low',
        'After $r, $who\'s feeling was higher more often than after other types when they started scared or sad.',
        [
          'When $who says they feel scared or sad, open Calm Quest or the Games tab and pick $r first.',
          'Keep it short: 2 to 3 minutes is enough.',
          'Mindy already leans this way on its own. You can help by choosing it too.',
        ],
      );
    }
    if (band == StateBand.mixed || band == StateBand.unsettled) {
      add(
        'A_NAME_THE_FEELING',
        ActionKind.now,
        'Talk about the feeling in three small steps',
        'Naming a feeling and noticing it in the body is a basic step in child-friendly CBT-style coping.',
        [
          'Name it: "It looks like you feel scared. That is okay. Lots of children feel that before a doctor visit."',
          'Locate it: "Where do you feel it? Tummy? Chest? Hands?"',
          'Calm it: breathe together slowly, in through the nose like smelling a flower, out like blowing a bubble. Then play the calm game.',
        ],
      );
    }
    if ((band == StateBand.mixed || band == StateBand.unsettled) && calm14.isEmpty) {
      add(
        'A_TRY_CALM_CORNER',
        ActionKind.now,
        'Show $who the Calm Corner',
        '$who has not used the Calm Corner in the last $windowDays days. It is a quiet breathing and grounding space the child can choose themselves.',
        [
          'Open the Calm Corner from the Home screen together.',
          'Do one round side by side. Children copy the grown-up\'s calm.',
          'Remind $who it is always there if they want a quiet moment.',
        ],
      );
    }
    if (band != StateBand.notEnough &&
        (band != StateBand.settled || (latestBefore != null && latestBefore >= 2))) {
      add(
        'A_PRE_VISIT_ROUTINE',
        ActionKind.thisWeek,
        'Build a calm routine before the visit',
        band == StateBand.settled
            ? 'The latest worry answer was ${kWorryLabels[latestBefore!].toLowerCase()}.'
            : 'There have been worried moments recently, and practising before a stressful event usually helps more than starting on the day.',
        [
          'Two to three days before: play one calm game a day (about 5 minutes).',
          'Evening before: tell $who simply what will happen ("The doctor will look in your ears and listen to your chest").',
          'In the waiting room: do the breathing game or Calm Corner together.',
          'Afterwards: use the worry faces again to see how it went.',
        ],
      );
    }
    if (trend == 'worsening') {
      add(
        'A_STEADY_ROUTINE',
        ActionKind.thisWeek,
        'Look at what changed this week',
        'The share of scared or sad check-ins went up compared with last week.',
        const [
          'Think about sleep, meals, school, and any news or changes at home.',
          'Keep a fixed short calm-play time each day, such as after dinner.',
          'Note what you find. It can help if you talk to a doctor later.',
        ],
      );
    }
    final professional = (band == StateBand.unsettled &&
            n >= minForProfessionalPrompt &&
            win.last.startTime.difference(win.first.startTime).inDays >= 7 &&
            trend != 'improving' &&
            (recovery == null || recovery < 0.5)) ||
        (worryStaysHigh && n >= minCheckIns);
    if (professional) {
      add(
        'A_CONSIDER_TALKING',
        ActionKind.consider,
        'Consider talking to your child\'s doctor or school counsellor',
        worryStaysHigh && band != StateBand.unsettled
            ? 'The last two worry answers after play were both high.'
            : 'Worried moments have been frequent over more than a week and playing has not often helped.',
        const [
          'You do not need to wait for a bad day. Mention it at the next check-up or call the clinic.',
          'You can copy this plan from the button below and show it to them.',
          'Mindy cannot tell why this is happening. A professional can.',
        ],
      );
    }

    // Order: do now, this week, consider.
    actions.sort((a, b) => a.kind.index.compareTo(b.kind.index));

    return SupportPlan(
      band: band,
      headline: headline,
      summary: summary,
      confidence: confidence,
      checkIns: n,
      lowCount: low,
      signals: signals,
      actions: actions,
      days: days,
      caution: _caution,
      childName: (childName == null || childName.trim().isEmpty)
          ? null
          : childName.trim(),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// A plain-text copy a caregiver can paste into a message or show to a
  /// doctor or teacher. Contains no name and no identifier unless the caller
  /// passes one.
  String toPlainText({String? childLabel, DateTime? now}) {
    final b = StringBuffer();
    b.writeln('Mindy support plan${childLabel == null ? '' : ' for $childLabel'}');
    if (now != null) b.writeln('Created ${now.toIso8601String().substring(0, 10)}');
    b.writeln();
    b.writeln(headline);
    b.writeln(summary);
    b.writeln(confidence);
    if (signals.isNotEmpty) {
      b.writeln();
      b.writeln('What was noticed:');
      for (final s in signals) {
        b.writeln('- ${s.title}: ${s.detail}');
      }
    }
    if (actions.isNotEmpty) {
      b.writeln();
      b.writeln('Suggestions:');
      for (final a in actions) {
        b.writeln('- ${a.title} (${a.why})');
      }
    }
    b.writeln();
    b.writeln(caution);
    return b.toString();
  }
}
