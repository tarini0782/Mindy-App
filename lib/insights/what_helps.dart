import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../models/emotion_state.dart';

/// One plain-language finding with the evidence behind it.
class HelpLine {
  final String title;
  final String detail;
  final String evidence; // e.g. "Based on 5 activities"
  const HelpLine(this.title, this.detail, this.evidence);
}

/// "What seems to help <child>": a per-child pattern report built only from
/// the child's own stored sessions. This is the part of Mindy that other
/// children's apps do not give: it compares activity TYPES by how the child
/// said they felt before and after, only when they started feeling low, and
/// it says how little evidence it has.
///
/// It is a description of what happened, never a diagnosis and never a
/// prediction. Small numbers are reported as small numbers.
class WhatHelps {
  final List<HelpLine> lines;
  final List<String> engineReasons; // why Mindy picked the latest activities
  final String caution;
  final bool enoughData;
  const WhatHelps({
    required this.lines,
    required this.engineReasons,
    required this.caution,
    required this.enoughData,
  });

  static const int minLowStarts = 2; // per activity type
  static const int minForTrend = 6; // total sessions with hint data
  static const double clearGap = 0.5; // mood-step difference worth mentioning

  static String roleName(ActivityRole r) {
    switch (r) {
      case ActivityRole.regulation:
        return 'calming activities';
      case ActivityRole.supportive:
        return 'gentle activities';
      case ActivityRole.standard:
        return 'thinking games';
      case ActivityRole.engaging:
        return 'action games';
    }
  }

  static WhatHelps from(List<GameSession> sessions, {String? childName}) {
    final who = (childName == null || childName.trim().isEmpty) ? 'your child' : childName.trim();
    const caution = 'These are patterns in a small number of play sessions. '
        'Tiredness, hunger, the time of day and many other things also change '
        'how a child feels. Mindy cannot tell why a pattern appears.';
    final lines = <HelpLine>[];

    // ---- 1. When they started low, which activity types were followed by a
    //         higher feeling? (self-reported before/after only)
    final lowStarts = sessions.where((s) =>
        s.emotionBefore != null &&
        s.emotionAfter != null &&
        s.emotionBefore!.moodScore <= 2);
    final byRole = <ActivityRole, List<GameSession>>{};
    for (final s in lowStarts) {
      byRole.putIfAbsent(s.game.role, () => []).add(s);
    }
    final stats = <ActivityRole, _Stat>{};
    byRole.forEach((r, list) {
      if (list.length >= minLowStarts) {
        final mean = list.map((s) => s.moodDelta!).reduce((a, b) => a + b) / list.length;
        final higher = list.where((s) => s.moodDelta! > 0).length;
        stats[r] = _Stat(list.length, mean, higher);
      }
    });
    if (stats.length >= 2) {
      final ranked = stats.entries.toList()
        ..sort((a, b) => b.value.mean.compareTo(a.value.mean));
      final best = ranked.first;
      final worst = ranked.last;
      if (best.value.mean - worst.value.mean >= clearGap && best.value.mean > 0) {
        lines.add(HelpLine(
          'When $who felt low, ${roleName(best.key)} went with the best change',
          'After ${roleName(best.key)}, the feeling $who picked was higher in '
              '${best.value.higher} of ${best.value.n} activities that started '
              'with "scared" or "sad". For ${roleName(worst.key)} it was higher in '
              '${worst.value.higher} of ${worst.value.n}.',
          'Based on ${best.value.n + worst.value.n} activities that started low',
        ));
      } else {
        lines.add(HelpLine(
          'No activity type stood out yet',
          'When $who started feeling low, the change in feeling was similar '
              'across the activity types tried so far.',
          'Based on ${stats.values.fold<int>(0, (a, b) => a + b.n)} activities that started low',
        ));
      }
    } else if (lowStarts.isNotEmpty) {
      lines.add(HelpLine(
        'Not enough low-feeling starts to compare',
        'Mindy needs at least $minLowStarts activities of two different types that '
            'started with "scared" or "sad" before it can compare them.',
        'So far: ${lowStarts.length} such activit${lowStarts.length == 1 ? 'y' : 'ies'}',
      ));
    }

    // ---- 2. Growing independence: hints per activity, first half vs second.
    final hinted = sessions.where((s) => s.game.hasPerformanceData).toList();
    if (hinted.length >= minForTrend) {
      final mid = hinted.length ~/ 2;
      double avg(List<GameSession> l) =>
          l.map((s) => s.supportCount).reduce((a, b) => a + b) / l.length;
      final first = avg(hinted.sublist(0, mid));
      final second = avg(hinted.sublist(mid));
      final String detail;
      if (second <= first - 0.5) {
        detail = '$who needed fewer hints in the later activities '
            '(${second.toStringAsFixed(1)} per activity) than in the earlier '
            'ones (${first.toStringAsFixed(1)}).';
      } else if (second >= first + 0.5) {
        detail = '$who needed more hints in the later activities '
            '(${second.toStringAsFixed(1)} per activity) than in the earlier '
            'ones (${first.toStringAsFixed(1)}). Harder levels can do this.';
      } else {
        detail = 'The number of hints stayed about the same '
            '(${first.toStringAsFixed(1)} then ${second.toStringAsFixed(1)} per activity).';
      }
      lines.add(HelpLine('Hints over time', detail, 'Based on ${hinted.length} activities'));
    }

    // ---- 3. Did Mindy's difficulty choice match how it felt to the child?
    final rated = sessions.where((s) => s.perceivedDifficulty != null).toList();
    if (rated.length >= 3) {
      final right = rated.where((s) => s.perceivedDifficulty == 2).length;
      final hard = rated.where((s) => s.perceivedDifficulty == 3).length;
      final easy = rated.where((s) => s.perceivedDifficulty == 1).length;
      lines.add(HelpLine(
        'Did the level feel right to $who?',
        '$who said "just right" for $right of ${rated.length}, "too hard" for '
            '$hard and "too easy" for $easy. Mindy uses these answers when it '
            'picks the next level.',
        'Based on ${rated.length} answers from $who',
      ));
    }

    // ---- Why Mindy chose the latest activities (transparent engine).
    final reasons = <String>[];
    for (final s in sessions.reversed.take(3)) {
      final why = s.trace.humanReason.trim();
      if (why.isNotEmpty) reasons.add('${s.game.title}: $why');
    }

    return WhatHelps(
      lines: lines,
      engineReasons: reasons,
      caution: caution,
      enoughData: lines.isNotEmpty,
    );
  }
}

class _Stat {
  final int n;
  final double mean;
  final int higher;
  const _Stat(this.n, this.mean, this.higher);
}
