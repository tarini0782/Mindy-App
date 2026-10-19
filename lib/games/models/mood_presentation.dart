import '../../models/emotion_state.dart';
import 'game_type.dart';

/// How the check-in feeling changes the way EVERY game is presented.
///
/// The engine already uses the check-in to choose *which* activity and at
/// *what level* (`levelRange`, `_restricted` in `AdaptiveGameEngine`).
/// This is the layer underneath that: the same activity, presented more
/// gently. One place, applied by the shell, so all 27 games follow it
/// without 27 edits.
///
/// Implements these rules from the rule catalogue:
///
///   EMO-02  a worried child is offered calm, not challenge
///   EMO-05  a negative feeling with good play does NOT raise difficulty
///   EMO-06  a positive feeling with poor play stays supportive
///   ATT-05  reduce visual clutter when performance may be affected
///   RT-02   offer a longer response window rather than a harder task
///   SAFE-07 address the reported feeling first; good performance is not
///           evidence of wellbeing
///
/// EMO-05 and SAFE-07 are the ones that matter most, and the engine
/// already satisfies them structurally rather than by policy:
/// `levelRange(scared)` and `levelRange(sad)` both return `(1, 1)`, so a
/// level rise is arithmetically impossible while the reported feeling is
/// negative, however well the child is playing. That is worth knowing —
/// it means the safety property holds even if someone later changes the
/// scoring weights.
enum MoodMode {
  /// Scared, sad, or no answer. Everything softer and slower.
  gentle,

  /// Okay. Standard presentation with a little extra room.
  steady,

  /// Calm or happy. The full experience.
  full,
}

class MoodPresentation {
  final MoodMode mode;

  /// Background animation and decorative movement are reduced.
  final bool reducedMotion;

  /// Non-essential decoration is dropped, so the task is what stands out.
  final bool fewerDistractions;

  /// Multiplier for touch-target size. A worried or upset child is not
  /// necessarily less able; a bigger target simply removes one source of
  /// frustration that has nothing to do with the task.
  final double targetScale;

  /// Multiplier for how long the child has to respond. **Never applied to
  /// a research-linked task** — see [windowScaleFor].
  final double windowScale;

  /// The support ladder starts offering help sooner.
  final bool offerHelpEarly;

  /// False while the reported feeling is negative. EMO-05 / SAFE-07: good
  /// play is not a reason to make things harder for a child who has just
  /// said they feel scared or sad.
  final bool allowDifficultyRise;

  const MoodPresentation._({
    required this.mode,
    required this.reducedMotion,
    required this.fewerDistractions,
    required this.targetScale,
    required this.windowScale,
    required this.offerHelpEarly,
    required this.allowDifficultyRise,
  });

  static const gentlePreset = MoodPresentation._(
    mode: MoodMode.gentle,
    reducedMotion: true,
    fewerDistractions: true,
    targetScale: 1.15,
    windowScale: 1.25,
    offerHelpEarly: true,
    allowDifficultyRise: false,
  );

  static const steadyPreset = MoodPresentation._(
    mode: MoodMode.steady,
    reducedMotion: false,
    fewerDistractions: false,
    targetScale: 1.07,
    windowScale: 1.10,
    offerHelpEarly: true,
    allowDifficultyRise: true,
  );

  static const fullPreset = MoodPresentation._(
    mode: MoodMode.full,
    reducedMotion: false,
    fewerDistractions: false,
    targetScale: 1.0,
    windowScale: 1.0,
    offerHelpEarly: false,
    allowDifficultyRise: true,
  );

  /// The presentation for a reported feeling. A skipped check-in is
  /// treated exactly like "scared": the safest reading of no answer.
  static MoodPresentation forEmotion(EmotionState? e) {
    switch (e) {
      case null:
      case EmotionState.scared:
      case EmotionState.sad:
        return gentlePreset;
      case EmotionState.neutral:
        return steadyPreset;
      case EmotionState.calm:
      case EmotionState.happy:
        return fullPreset;
    }
  }

  /// The response-window multiplier for one activity.
  ///
  /// Returns 1.0 — no change at all — for any task whose timing feeds a
  /// research indicator. Sleepy Fox's stimulus window IS the go/no-go
  /// parameter: stretching it by 25% because the child reported feeling
  /// scared would change the commission and omission rates for a reason
  /// that has nothing to do with the child, and sessions would stop being
  /// comparable with each other. Sorting Stars is excluded for the same
  /// reason.
  ///
  /// Comfort is applied to how a task *looks*, never to what it measures.
  double windowScaleFor(GameType game) =>
      _timingLocked.contains(game) ? 1.0 : windowScale;

  /// Activities whose timing must stay fixed across sessions because an
  /// indicator is computed from it.
  static const Set<GameType> _timingLocked = {
    GameType.sleepyFox, // go / no-go: commission + omission
    GameType.ruleShift, // rule switching: switch cost
  };

  /// True when this activity's timing is held fixed for research.
  static bool timingLocked(GameType game) => _timingLocked.contains(game);

  /// A short line for the decision trace and the researcher view.
  String get traceNote => switch (mode) {
        MoodMode.gentle => 'gentle presentation: reduced motion, larger '
            'targets, longer windows (except research-timed tasks), help '
            'offered early, no difficulty rise',
        MoodMode.steady => 'steady presentation: a little extra room, help '
            'offered early',
        MoodMode.full => 'full presentation',
      };
}
