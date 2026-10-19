import 'dart:math';
import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../models/caregiver_observation.dart';
import '../models/emotion_state.dart';
import '../games/models/game_difficulty.dart';

/// How much evidence backs a statement. Mindy never presents three sessions
/// as an established pattern.
enum EvidenceLevel {
  insufficient, // fewer than 3 sessions: "Mindy is still learning"
  currentObservation, // 3-6 sessions: what happened recently
  emergingPattern, // 7-29 sessions
  longerTerm, // 30+ sessions
}

extension EvidenceLevelX on EvidenceLevel {
  String get label {
    switch (this) {
      case EvidenceLevel.insufficient:
        return 'Mindy is still learning';
      case EvidenceLevel.currentObservation:
        return 'Current observation';
      case EvidenceLevel.emergingPattern:
        return 'Emerging pattern';
      case EvidenceLevel.longerTerm:
        return 'Longer-term view';
    }
  }
}

/// Evidence level for a window of [size] sessions when [available] exist.
/// Rules (engineering choices, documented in the README):
///  * fewer than 3 available            -> insufficient
///  * window of 3                       -> never more than a current observation
///  * window of 7: needs 7 available    -> emerging pattern
///  * window of 30: 30 -> longer-term, 7-29 -> emerging pattern
///  * otherwise, with 3+ available      -> current observation
EvidenceLevel evidenceLevelFor(int size, int available) {
  if (available < 3) return EvidenceLevel.insufficient;
  if (size <= 3) return EvidenceLevel.currentObservation;
  if (size >= 30 && available >= 30) return EvidenceLevel.longerTerm;
  if (available >= 7) return EvidenceLevel.emergingPattern;
  return EvidenceLevel.currentObservation;
}

class ParticipationInsight {
  final int started;
  final int completed;
  final int abandoned;
  final double? completionRate; // null when nothing started
  final double? avgDurationSeconds;
  final int totalPauses;
  final int playAgainYes;
  final int playAgainAnswered;
  const ParticipationInsight({
    required this.started,
    required this.completed,
    required this.abandoned,
    required this.completionRate,
    required this.avgDurationSeconds,
    required this.totalPauses,
    required this.playAgainYes,
    required this.playAgainAnswered,
  });
}

class EmotionalInsight {
  final List<String> recentSequence; // e.g. "Sad -> Calm" or "Okay -> ?"
  final int pairs; // sessions with BOTH a before and an after feeling
  final int improved;
  final int unchanged;
  final int worsened;
  final String? mostFrequent; // only with enough evidence
  final int mostFrequentCount;
  final int checkIns;
  const EmotionalInsight({
    required this.recentSequence,
    required this.pairs,
    required this.improved,
    required this.unchanged,
    required this.worsened,
    required this.mostFrequent,
    required this.mostFrequentCount,
    required this.checkIns,
  });
}

class RegulationInsight {
  final int completedWithPair;
  final int improved;
  final Map<String, List<int>> perActivity; // id -> [improved, total]
  const RegulationInsight({
    required this.completedWithPair,
    required this.improved,
    required this.perActivity,
  });
}

class BehaviourInsight {
  final int sessionsWithAccuracy;
  final double? meanAccuracy;
  final int sessionsWithResponse;
  final double? meanResponseMs;
  final String? variabilityNote; // descriptive, never evaluative
  final double? meanInteractions;
  const BehaviourInsight({
    required this.sessionsWithAccuracy,
    required this.meanAccuracy,
    required this.sessionsWithResponse,
    required this.meanResponseMs,
    required this.variabilityNote,
    required this.meanInteractions,
  });
}

class JourneyEntry {
  final DateTime when;
  final String activityTitle;
  final String activityId;
  final int level;
  final String difficulty;
  final String reason;
  final bool completed;
  final MoodChange moodChange;
  final bool recovery;
  const JourneyEntry({
    required this.when,
    required this.activityTitle,
    required this.activityId,
    required this.level,
    required this.difficulty,
    required this.reason,
    required this.completed,
    required this.moodChange,
    required this.recovery,
  });
}

class WindowInsights {
  final String name; // Recent | Developing | Longer-term
  final int requestedSize;
  final int sessionsInWindow;
  final EvidenceLevel level;
  final ParticipationInsight participation;
  final EmotionalInsight emotional;
  final RegulationInsight regulation;
  final BehaviourInsight behaviour;

  /// Plain-language statements. Each is generated from the counts above and
  /// only when the evidence supports it.
  final List<String> statements;

  const WindowInsights({
    required this.name,
    required this.requestedSize,
    required this.sessionsInWindow,
    required this.level,
    required this.participation,
    required this.emotional,
    required this.regulation,
    required this.behaviour,
    required this.statements,
  });
}

class WellbeingInsights {
  final int totalSessions;
  final List<WindowInsights> windows;
  final List<JourneyEntry> journey; // newest first, up to 10
  final int repeatedActivityTransitions; // same activity twice in a row
  final int difficultyChanges;
  final int recoveryDecisions;
  final Map<String, int> observationCounts; // last 30 days, by type name
  final List<CaregiverObservation> observations; // newest first

  const WellbeingInsights({
    required this.totalSessions,
    required this.windows,
    required this.journey,
    required this.repeatedActivityTransitions,
    required this.difficultyChanges,
    required this.recoveryDecisions,
    required this.observationCounts,
    required this.observations,
  });

  bool get hasAnyData => totalSessions > 0;
}

class InsightsCalculator {
  InsightsCalculator._();

  static const String disclaimer =
      "Mindy's insights are based on information reported and recorded during "
      'app activities. They are intended to help caregivers understand '
      "patterns in the child's interaction with the application and are not a "
      'medical, psychological or diagnostic assessment.';

  static const List<(String, int)> windowSpecs = [
    ('Recent', 3),
    ('Developing', 7),
    ('Longer-term', 30),
  ];

  /// [sessions] chronological (oldest first).
  static WellbeingInsights compute(
    List<GameSession> sessions,
    List<CaregiverObservation> observations, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final windows = [
      for (final spec in windowSpecs) _window(spec.$1, spec.$2, sessions),
    ];

    // Adaptive journey (all from stored traces).
    final newest = sessions.reversed.take(10).toList();
    final journey = [
      for (final s in newest)
        JourneyEntry(
          when: s.startTime,
          activityTitle: s.game.title,
          activityId: s.game.id,
          level: s.level,
          difficulty: s.difficulty.label,
          reason: s.trace.humanReason,
          completed: s.completed,
          moodChange: s.moodChange,
          recovery: s.trace.recovery,
        ),
    ];
    var repeats = 0, changes = 0, recov = 0;
    for (var i = 1; i < sessions.length; i++) {
      if (sessions[i].game == sessions[i - 1].game) repeats++;
      if (sessions[i].level != sessions[i - 1].level) changes++;
    }
    for (final s in sessions) {
      if (s.trace.recovery) recov++;
    }

    final cutoff = t.subtract(const Duration(days: 30));
    final counts = <String, int>{};
    for (final o in observations) {
      if (o.timestamp.isAfter(cutoff)) {
        counts[o.type.name] = (counts[o.type.name] ?? 0) + 1;
      }
    }

    return WellbeingInsights(
      totalSessions: sessions.length,
      windows: windows,
      journey: journey,
      repeatedActivityTransitions: repeats,
      difficultyChanges: changes,
      recoveryDecisions: recov,
      observationCounts: counts,
      observations: observations.reversed.toList(),
    );
  }

  // ----------------------------------------------------------- windows

  static WindowInsights _window(
      String name, int size, List<GameSession> all) {
    final subset =
        all.length > size ? all.sublist(all.length - size) : List.of(all);
    final level = evidenceLevelFor(size, subset.length);
    final part = _participation(subset);
    final emo = _emotional(subset, level);
    final reg = _regulation(subset);
    final beh = _behaviour(subset);
    final statements = level == EvidenceLevel.insufficient
        ? <String>[]
        : _statements(name, size, subset, level, part, emo, reg, beh);
    return WindowInsights(
      name: name,
      requestedSize: size,
      sessionsInWindow: subset.length,
      level: level,
      participation: part,
      emotional: emo,
      regulation: reg,
      behaviour: beh,
      statements: statements,
    );
  }

  static ParticipationInsight _participation(List<GameSession> s) {
    final completed = s.where((x) => x.completed).length;
    final answered = s.where((x) => x.playAgain != null).toList();
    return ParticipationInsight(
      started: s.length,
      completed: completed,
      abandoned: s.length - completed,
      completionRate: s.isEmpty ? null : completed / s.length,
      avgDurationSeconds: s.isEmpty
          ? null
          : s.map((x) => x.durationSeconds).reduce((a, b) => a + b) / s.length,
      totalPauses: s.fold<int>(0, (a, b) => a + b.pausedCount),
      playAgainYes: answered.where((x) => x.playAgain == true).length,
      playAgainAnswered: answered.length,
    );
  }

  static EmotionalInsight _emotional(List<GameSession> s, EvidenceLevel level) {
    var imp = 0, same = 0, worse = 0, pairs = 0;
    final seq = <String>[];
    final freq = <String, int>{};
    var checkIns = 0;
    for (final x in s) {
      seq.add('${x.emotionBefore?.label ?? '?'} \u2192 ${x.emotionAfter?.label ?? '?'}');
      if (x.emotionBefore != null) {
        freq[x.emotionBefore!.label] = (freq[x.emotionBefore!.label] ?? 0) + 1;
        checkIns++;
      }
      final d = x.moodDelta;
      if (d != null) {
        pairs++;
        if (d > 0) {
          imp++;
        } else if (d < 0) {
          worse++;
        } else {
          same++;
        }
      }
    }
    String? top;
    var topCount = 0;
    freq.forEach((k, v) {
      if (v > topCount) {
        top = k;
        topCount = v;
      }
    });
    final enough = level == EvidenceLevel.emergingPattern ||
        level == EvidenceLevel.longerTerm;
    return EmotionalInsight(
      recentSequence: seq,
      pairs: pairs,
      improved: imp,
      unchanged: same,
      worsened: worse,
      mostFrequent: (enough && topCount >= 3) ? top : null,
      mostFrequentCount: (enough && topCount >= 3) ? topCount : 0,
      checkIns: checkIns,
    );
  }

  static RegulationInsight _regulation(List<GameSession> s) {
    var total = 0, imp = 0;
    final per = <String, List<int>>{};
    for (final x in s) {
      if (!x.completed || !x.game.isRegulation) continue;
      final d = x.moodDelta;
      if (d == null) continue;
      total++;
      final entry = per.putIfAbsent(x.game.title, () => [0, 0]);
      entry[1]++;
      if (d > 0) {
        imp++;
        entry[0]++;
      }
    }
    return RegulationInsight(
        completedWithPair: total, improved: imp, perActivity: per);
  }

  static BehaviourInsight _behaviour(List<GameSession> s) {
    final acc = [for (final x in s) if (x.accuracy != null) x.accuracy!];
    final rt = [
      for (final x in s)
        if (x.avgResponseMs != null) x.avgResponseMs!,
    ];
    final inter = [for (final x in s) x.interactions.toDouble()];
    String? note;
    if (rt.length >= 3) {
      final mean = rt.reduce((a, b) => a + b) / rt.length;
      var sum = 0.0;
      for (final v in rt) {
        sum += (v - mean) * (v - mean);
      }
      final cv = mean == 0 ? 0 : sqrt(sum / rt.length) / mean;
      note = cv > 0.4
          ? 'Interaction speed has varied across these sessions.'
          : 'Interaction speed has been fairly steady across these sessions.';
    }
    double? mean(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    return BehaviourInsight(
      sessionsWithAccuracy: acc.length,
      meanAccuracy: mean(acc),
      sessionsWithResponse: rt.length,
      meanResponseMs: mean(rt),
      variabilityNote: note,
      meanInteractions: mean(inter),
    );
  }

  static List<String> _statements(
    String name,
    int size,
    List<GameSession> subset,
    EvidenceLevel level,
    ParticipationInsight part,
    EmotionalInsight emo,
    RegulationInsight reg,
    BehaviourInsight beh,
  ) {
    final n = subset.length;
    final span = n < size
        ? 'In the $n activities so far'
        : 'In the last $n activities';
    final out = <String>[];

    out.add('$span, the child started ${part.started} and finished '
        '${part.completed}.');

    if (emo.pairs >= 3) {
      out.add('$span with a before and after feeling (${emo.pairs}), the '
          'child reported feeling more positive afterwards ${emo.improved} '
          'time${emo.improved == 1 ? '' : 's'}, the same ${emo.unchanged}, '
          'and less positive ${emo.worsened}.');
    } else {
      out.add('Fewer than 3 activities here have both a "before" and "after" '
          'feeling, so emotional change cannot be summarised yet.');
    }

    if (reg.completedWithPair >= 3) {
      out.add('Calming activities were followed by a more positive '
          'self-reported feeling in ${reg.improved} of '
          '${reg.completedWithPair} finished sessions with a before/after '
          'answer.');
    }

    if (emo.mostFrequent != null) {
      out.add('The most frequently reported feeling was ${emo.mostFrequent} '
          '(${emo.mostFrequentCount} of ${emo.checkIns} check-ins).');
    }

    if (beh.variabilityNote != null) out.add(beh.variabilityNote!);

    if (level == EvidenceLevel.currentObservation) {
      out.add('This is a current observation only. More sessions are needed '
          'before a pattern can be described.');
    }
    return out;
  }
}
