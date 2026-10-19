import '../games/models/game_session.dart';
import '../models/emotion_state.dart';

/// Plain counts of what the child actually did or said. Nothing here is
/// inferred: every field is an OBSERVED event, and the wording that shows it
/// (see [lines]) never says what it means. Answers the child skipped are
/// simply not counted.
class CaregiverSummary {
  final int sessions;
  final int finished;
  final int scaredOrSadBefore; // chose scared or sad at the start
  final int breaksTaken; // pause button presses (child-initiated)
  final int easierRequests; // child asked for an easier game
  final int automaticSupports; // hints the app offered
  final int enjoyedYes, enjoyedOk, enjoyedNo; // end-of-game answers
  final int feltEasy, feltJustRight, feltHard;
  final int feelingBetter, feelingSame, feelingLower; // between two check-ins
  final int feelingPairs;

  const CaregiverSummary({
    required this.sessions,
    required this.finished,
    required this.scaredOrSadBefore,
    required this.breaksTaken,
    required this.easierRequests,
    required this.automaticSupports,
    required this.enjoyedYes,
    required this.enjoyedOk,
    required this.enjoyedNo,
    required this.feltEasy,
    required this.feltJustRight,
    required this.feltHard,
    required this.feelingBetter,
    required this.feelingSame,
    required this.feelingLower,
    required this.feelingPairs,
  });

  static CaregiverSummary from(Iterable<GameSession> list) {
    var n = 0, fin = 0, sad = 0, br = 0, ez = 0, sup = 0;
    var ey = 0, eo = 0, en = 0, fe = 0, fj = 0, fh = 0;
    var up = 0, same = 0, down = 0, pairs = 0;
    for (final s in list) {
      n++;
      if (s.completed) fin++;
      if (s.emotionBefore == EmotionState.scared ||
          s.emotionBefore == EmotionState.sad) {
        sad++;
      }
      br += s.pausedCount;
      ez += s.childEasierRequests;
      sup += s.supportCount;
      if (s.enjoyment == 3) ey++;
      if (s.enjoyment == 2) eo++;
      if (s.enjoyment == 1) en++;
      if (s.perceivedDifficulty == 1) fe++;
      if (s.perceivedDifficulty == 2) fj++;
      if (s.perceivedDifficulty == 3) fh++;
      final d = s.moodDelta;
      if (d != null) {
        pairs++;
        if (d > 0) {
          up++;
        } else if (d < 0) {
          down++;
        } else {
          same++;
        }
      }
    }
    return CaregiverSummary(
      sessions: n,
      finished: fin,
      scaredOrSadBefore: sad,
      breaksTaken: br,
      easierRequests: ez,
      automaticSupports: sup,
      enjoyedYes: ey,
      enjoyedOk: eo,
      enjoyedNo: en,
      feltEasy: fe,
      feltJustRight: fj,
      feltHard: fh,
      feelingBetter: up,
      feelingSame: same,
      feelingLower: down,
      feelingPairs: pairs,
    );
  }

  bool get isEmpty => sessions == 0;

  /// Observed facts only. A count of zero is omitted rather than shown as
  /// "no problem".
  List<String> get lines {
    final out = <String>[];
    if (sessions == 0) return out;
    out.add('Played $sessions ${sessions == 1 ? 'activity' : 'activities'}; finished $finished.');
    if (scaredOrSadBefore > 0) {
      out.add('Picked "scared" or "sad" before $scaredOrSadBefore '
          '${scaredOrSadBefore == 1 ? 'activity' : 'activities'}.');
    }
    if (breaksTaken > 0) out.add('Took $breaksTaken ${breaksTaken == 1 ? 'break' : 'breaks'} during play.');
    if (easierRequests > 0) {
      out.add('Asked for an easier game $easierRequests ${easierRequests == 1 ? 'time' : 'times'}.');
    }
    if (automaticSupports > 0) {
      out.add('The app offered a hint or help $automaticSupports ${automaticSupports == 1 ? 'time' : 'times'}.');
    }
    final answered = enjoyedYes + enjoyedOk + enjoyedNo;
    if (answered > 0) {
      out.add('Said the game was fun $enjoyedYes, okay $enjoyedOk, not fun $enjoyedNo '
          '(out of $answered answers).');
    }
    final dAnswered = feltEasy + feltJustRight + feltHard;
    if (dAnswered > 0) {
      out.add('Said it was easy $feltEasy, just right $feltJustRight, hard $feltHard '
          '(out of $dAnswered answers).');
    }
    if (feelingPairs > 0) {
      out.add('Feeling picked before vs after play: higher $feelingBetter, '
          'same $feelingSame, lower $feelingLower (out of $feelingPairs).');
    }
    return out;
  }
}
