import '../models/decision_trace.dart';

/// Turns a stored [DecisionTrace] into an explanation of why ONE activity
/// was chosen over the others.
///
/// Everything here is derived from the trace the engine actually wrote. It
/// computes nothing of its own and makes no decision: if the engine's
/// reasoning changes, this changes with it, and if the trace is incomplete
/// this says so rather than inventing a tidy story.
///
/// Two audiences, two levels:
///   [caregiverLines]  plain sentences, no scores, no internal names
///   [researcherRows]  the score breakdown, the runner-up, the tie-break
class DecisionExplanation {
  final DecisionTrace trace;
  const DecisionExplanation(this.trace);

  /// The winning candidate's score row, if the trace recorded scores.
  ActivityScoreTrace? get winner {
    for (final s in trace.scores) {
      if (s.activityId == trace.selectedActivity) return s;
    }
    return null;
  }

  /// The highest-scoring candidate that was NOT selected. This is the one
  /// worth naming: "why this and not that".
  ActivityScoreTrace? get runnerUp {
    ActivityScoreTrace? best;
    for (final s in trace.scores) {
      if (!s.allowed || s.activityId == trace.selectedActivity) continue;
      if (best == null || s.total > best.total) best = s;
    }
    return best;
  }

  int get eligibleCount => trace.scores.where((s) => s.allowed).length;
  int get excludedCount => trace.scores.where((s) => !s.allowed).length;

  /// True when the margin over the runner-up was zero, i.e. the tie-break
  /// decided it rather than the score. Worth surfacing: a tie-broken choice
  /// is a weaker claim than a clear win.
  bool get decidedByTieBreak {
    final w = winner, r = runnerUp;
    if (w == null || r == null) return false;
    return (w.total - r.total).abs() < 0.0001;
  }

  double? get margin {
    final w = winner, r = runnerUp;
    if (w == null || r == null) return null;
    return w.total - r.total;
  }

  /// Components that pushed the winner above the runner-up, largest first.
  /// Only components that actually differ are listed.
  List<({String name, double winnerValue, double rivalValue, double diff})>
      decidingComponents() {
    final w = winner, r = runnerUp;
    if (w == null || r == null) return const [];
    final out = <({
      String name,
      double winnerValue,
      double rivalValue,
      double diff
    })>[];
    for (final key in {...w.components.keys, ...r.components.keys}) {
      final a = w.components[key] ?? 0;
      final b = r.components[key] ?? 0;
      if ((a - b).abs() < 0.0001) continue;
      out.add((name: key, winnerValue: a, rivalValue: b, diff: a - b));
    }
    out.sort((x, y) => y.diff.abs().compareTo(x.diff.abs()));
    return out;
  }

  /// Plain-language component names. An unknown key falls through as itself
  /// rather than being hidden, so a new component cannot silently vanish
  /// from the explanation.
  static String componentLabel(String key) {
    switch (key) {
      case 'emotionalCompatibility':
        return 'how well it suits the feeling picked';
      case 'recentMoodResponse':
        return 'how your child felt after it before';
      case 'engagementHistory':
        return 'whether they finished it before';
      case 'performanceFit':
        return 'whether it was the right stretch last time';
      case 'regulationNeed':
        return 'a calmer activity was wanted';
      case 'gentleStepUp':
        return 'a gentle step up after a calming activity';
      case 'previousActivity':
        return 'it was the activity just played';
      case 'repetitionAvoidance':
        return 'it was played recently';
      case 'recoveryPenalty':
        return 'the last try at it did not go well';
      case 'alreadyThisAdventure':
        return 'it was already played in this adventure';
      case 'novelty':
        return 'it has not been tried yet';
      default:
        return key;
    }
  }

  // ------------------------------------------------------------ caregiver

  /// Short sentences for a caregiver. No numbers, no component names, no
  /// mention of scores.
  List<String> caregiverLines() {
    final out = <String>[];
    final feeling = trace.emotion?.toLowerCase() ?? 'not answered';
    out.add(trace.emotion == null
        ? 'Your child skipped the feelings question, so Mindy stayed with a '
            'calm activity.'
        : 'Your child picked "$feeling" before playing.');

    if (trace.condition != 'ADAPTIVE') {
      out.add('This session was part of the fixed comparison set, so the '
          'activity order was decided in advance rather than by the feeling.');
      return out;
    }

    out.add('Mindy chose ${trace.selectedActivity.replaceAll('_', ' ')} '
        'at level ${trace.selectedLevel} (${trace.selectedDifficulty.toLowerCase()}), '
        '${trace.selectedPace} pace.');

    final deciders = decidingComponents().take(2).toList();
    if (deciders.isNotEmpty) {
      final reasons = deciders
          .where((d) => d.diff > 0)
          .map((d) => componentLabel(d.name))
          .toList();
      if (reasons.isNotEmpty) {
        out.add('It came out ahead of the next choice mainly on '
            '${reasons.join(', and ')}.');
      }
    }

    if (decidedByTieBreak) {
      out.add('Two activities were an equal fit, so Mindy picked the one '
          'played least often.');
    }

    if (trace.modifier == 0) {
      out.add('The level stayed the same: ${trace.modifierReason}.');
    } else {
      out.add('The level moved ${trace.modifier > 0 ? 'up' : 'down'} one step '
          'because ${trace.modifierReason}.');
    }

    if (trace.recovery) {
      out.add('The previous activity did not go well, so Mindy offered '
          'something different rather than repeating it.');
    }
    return out;
  }

  /// What would have to happen before the level could move again. Answers
  /// the "what is missing" question honestly instead of leaving a caregiver
  /// guessing why nothing changed.
  String whatWouldChangeNext() {
    final r = trace.modifierReason.toLowerCase();
    if (r.contains('comfort first')) {
      return 'While your child is picking scared, sad, or skipping the '
          'question, Mindy keeps the easiest level on purpose. The level can '
          'move again once they pick okay, calm or happy.';
    }
    if (r.contains('not enough recent sessions')) {
      return 'Mindy needs a couple more finished sessions of the same '
          'activity before it will change the level.';
    }
    if (r.contains('mixed')) {
      return 'Recent sessions pointed in different directions, so Mindy held '
          'the level. A consistent run either way would move it.';
    }
    if (r.contains('already at the highest')) {
      return 'This is already the highest level offered for that feeling.';
    }
    if (r.contains('already at the lowest')) {
      return 'This is already the easiest level.';
    }
    if (r.contains('step limited')) {
      return 'The level only ever moves one step at a time, so it will '
          'continue climbing gradually if play stays smooth.';
    }
    return 'The level changes only after several sessions agree, so one '
        'session on its own will not move it.';
  }

  // ----------------------------------------------------------- researcher

  /// Rows for the technical view: the full ranking with totals.
  List<({String activity, bool allowed, double total, bool selected})>
      researcherRows() {
    final rows = [
      for (final s in trace.scores)
        (
          activity: s.activityId,
          allowed: s.allowed,
          total: s.total,
          selected: s.activityId == trace.selectedActivity,
        )
    ];
    rows.sort((a, b) {
      if (a.allowed != b.allowed) return a.allowed ? -1 : 1;
      return b.total.compareTo(a.total);
    });
    return rows;
  }

  /// What the trace cannot answer. Stating this is the point: an
  /// explanation that hides its own gaps is worse than none.
  List<String> traceGaps() {
    final gaps = <String>[];
    if (trace.scores.isEmpty) {
      gaps.add('No candidate scores were recorded for this decision, so the '
          'ranking cannot be reconstructed. This is expected for the fixed '
          'and shared-safety-floor conditions, which do not score.');
    }
    if (winner == null && trace.scores.isNotEmpty) {
      gaps.add('The selected activity does not appear in the recorded '
          'scores, so the trace is inconsistent with its own result.');
    }
    if (trace.stateSnapshot.isEmpty) {
      gaps.add('No state snapshot was stored, so the history the engine saw '
          'cannot be replayed exactly.');
    }
    return gaps;
  }
}
