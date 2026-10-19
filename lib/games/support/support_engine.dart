/// REUSABLE HINT AND SUPPORT ENGINE (no Flutter, fully unit-testable).
///
/// The ladder, in order of strength:
///   independent -> visualCue -> smallHint -> demonstration -> easier -> breakOffer
///
/// Rules (engineering rules for gentle support, NOT clinical thresholds):
///  * Evidence = consecutive errors since the last success. One isolated
///    mistake never triggers anything.
///  * A success resets the ladder: the child continues independently.
///  * Idle (no attempt for [SupportConfig.idleSeconds]) offers a visual cue only.
///  * The child can ask for help: each request moves one step up the ladder
///    (never below smallHint, never past demonstration).
///  * "easier" is skipped when the study mode does not allow difficulty change
///    (fixed research mode), so nothing changes silently.
///  * At most [SupportConfig.maxAutomatic] automatic offers per session.
///  * Needing help is never treated as a sign of low ability or ill health.
enum SupportStage {
  independent,
  visualCue,
  smallHint,
  demonstration,
  easier,
  breakOffer,
}

enum SupportTrigger { errors, idle, requested }

class SupportConfig {
  final int errorsForCue;
  final int errorsForHint;
  final int errorsForDemo;
  final int errorsForEasier;
  final int errorsForBreak;
  final int idleSeconds;
  final int maxAutomatic;
  const SupportConfig({
    this.errorsForCue = 3,
    this.errorsForHint = 4,
    this.errorsForDemo = 5,
    this.errorsForEasier = 6,
    this.errorsForBreak = 8,
    this.idleSeconds = 15,
    this.maxAutomatic = 10,
  });
}

/// One support offer, as it is logged.
class SupportEvent {
  final SupportStage stage;
  final SupportTrigger trigger;
  final int consecutiveErrors;
  const SupportEvent(this.stage, this.trigger, this.consecutiveErrors);
}

class SupportEngine {
  SupportEngine({
    this.config = const SupportConfig(),
    this.allowDifficultyChange = true,
  });

  final SupportConfig config;
  final bool allowDifficultyChange;

  int consecutiveErrors = 0;
  SupportStage current = SupportStage.independent;
  SupportStage highest = SupportStage.independent;
  int offers = 0; // all offers
  int automaticOffers = 0;
  int attemptsAfterSupport = 0;
  int successesAfterSupport = 0;
  bool _supportGiven = false;
  final List<SupportEvent> history = [];

  /// Record an attempt. Returns the support to offer now, or null.
  SupportEvent? onAttempt({required bool ok}) {
    if (_supportGiven) {
      attemptsAfterSupport++;
      if (ok) successesAfterSupport++;
    }
    if (ok) {
      consecutiveErrors = 0;
      current = SupportStage.independent;
      return null;
    }
    consecutiveErrors++;
    final stage = _stageForErrors(consecutiveErrors);
    if (stage == null || stage.index <= current.index) return null;
    return _offer(stage, SupportTrigger.errors);
  }

  SupportStage? _stageForErrors(int n) {
    if (n >= config.errorsForBreak) return SupportStage.breakOffer;
    if (n >= config.errorsForEasier && allowDifficultyChange) {
      return SupportStage.easier;
    }
    if (n >= config.errorsForDemo) return SupportStage.demonstration;
    if (n >= config.errorsForHint) return SupportStage.smallHint;
    if (n >= config.errorsForCue) return SupportStage.visualCue;
    return null;
  }

  /// No attempt for a while: the gentlest support only.
  SupportEvent? onIdle() {
    if (current != SupportStage.independent) return null;
    return _offer(SupportStage.visualCue, SupportTrigger.idle);
  }

  /// The child asked for help (the light-bulb button).
  SupportEvent? request() {
    final next = current.index < SupportStage.smallHint.index
        ? SupportStage.smallHint
        : SupportStage.demonstration;
    return _offer(next, SupportTrigger.requested, countsAsAutomatic: false);
  }

  SupportEvent? _offer(SupportStage stage, SupportTrigger trigger,
      {bool countsAsAutomatic = true}) {
    if (countsAsAutomatic && automaticOffers >= config.maxAutomatic) {
      return null;
    }
    if (countsAsAutomatic) automaticOffers++;
    offers++;
    current = stage;
    if (stage.index > highest.index) highest = stage;
    _supportGiven = true;
    final e = SupportEvent(stage, trigger, consecutiveErrors);
    history.add(e);
    return e;
  }
}
