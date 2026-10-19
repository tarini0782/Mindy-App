import '../games/models/game_session.dart';
import '../games/models/game_type.dart';
import '../models/emotion_state.dart';
import 'rule_indicators.dart';

/// A plain-language summary written for a parent or carer. Everything in it
/// is computed from stored sessions. It states WHAT HAPPENED and offers
/// everyday suggestions; it never says what the child "has" or is "at risk
/// of", and it says so on the page.
class ParentSummary {
  final String headline; // one sentence
  final List<String> enjoyed; // games the child liked / chose to repeat
  final List<String> tricky; // games that needed more help or felt hard
  final List<String> feelings; // before-vs-after sentences
  final List<String> tryNext; // practical, non-clinical suggestions
  final String? talkToSomeone; // shown only if something is worth a chat
  final bool enoughData;

  /// Plain text version for sharing with a teacher, doctor or other carer.
  /// Contains only what the app observed and what the child said.
  String toPlainText() {
    final b = StringBuffer()..writeln(headline);
    void sec(String title, List<String> items) {
      if (items.isEmpty) return;
      b.writeln('\n$title');
      for (final i in items) {
        b.writeln('- $i');
      }
    }
    sec('Games your child enjoyed', enjoyed);
    sec('Games that felt tricky', tricky);
    sec('Feelings before and after play', feelings);
    sec('Things you could try', tryNext);
    if (talkToSomeone != null) b.writeln('\n$talkToSomeone');
    b.writeln('\nMindy is a play app. It does not diagnose anything.');
    return b.toString();
  }

  const ParentSummary({
    required this.headline,
    required this.enjoyed,
    required this.tricky,
    required this.feelings,
    required this.tryNext,
    required this.talkToSomeone,
    required this.enoughData,
  });

  static const int minSessions = 3;

  static ParentSummary from(List<GameSession> sessions, {String? childName}) {
    final who = (childName == null || childName.trim().isEmpty)
        ? 'Your child'
        : childName.trim();
    if (sessions.length < minSessions) {
      return ParentSummary(
        headline: sessions.isEmpty
            ? '$who has not played yet.'
            : '$who has played ${sessions.length} '
                '${sessions.length == 1 ? 'activity' : 'activities'} so far.',
        enjoyed: const [],
        tricky: const [],
        feelings: const [],
        tryNext: const [
          'Play a few more times, ideally together. A summary appears after '
              '$minSessions activities.'
        ],
        talkToSomeone: null,
        enoughData: false,
      );
    }

    // per-game tallies
    final byGame = <GameType, List<GameSession>>{};
    for (final s in sessions) {
      byGame.putIfAbsent(s.game, () => []).add(s);
    }
    final enjoyed = <String>[];
    final tricky = <String>[];
    byGame.forEach((g, list) {
      final liked = list.where((s) => s.enjoyment == 3 || s.playAgain == true).length;
      final notLiked = list.where((s) => s.enjoyment == 1 || s.playAgain == false).length;
      final hard = list.where((s) => s.perceivedDifficulty == 3).length;
      final helped = list.where((s) => s.supportCount >= 2).length;
      final unfinished = list.where((s) => !s.completed).length;
      if (liked > 0 && liked >= notLiked) {
        enjoyed.add('${g.title} ${g.emoji}: said it was fun or wanted to play again '
            '$liked of ${list.length} ${list.length == 1 ? 'time' : 'times'}.');
      }
      if (hard > 0 || helped > 0 || unfinished * 2 > list.length) {
        final why = <String>[];
        if (hard > 0) why.add('said it felt hard $hard ${hard == 1 ? 'time' : 'times'}');
        if (helped > 0) why.add('needed several hints $helped ${helped == 1 ? 'time' : 'times'}');
        if (unfinished * 2 > list.length) why.add('stopped before the end $unfinished of ${list.length}');
        tricky.add('${g.title} ${g.emoji}: ${why.join('; ')}.');
      }
    });

    // feelings
    var up = 0, same = 0, down = 0, pairs = 0;
    var scaredSad = 0;
    for (final s in sessions) {
      if (s.emotionBefore == EmotionState.scared || s.emotionBefore == EmotionState.sad) scaredSad++;
      final d = s.moodDelta;
      if (d == null) continue;
      pairs++;
      if (d > 0) {
        up++;
      } else if (d < 0) {
        down++;
      } else {
        same++;
      }
    }
    final feelings = <String>[];
    if (pairs > 0) {
      feelings.add('Feeling picked after playing was higher than before in $up of '
          '$pairs activities, the same in $same and lower in $down.');
    }
    if (scaredSad > 0) {
      feelings.add('$who picked "scared" or "sad" before $scaredSad of ${sessions.length} activities.');
    }

    // practical suggestions (never clinical)
    final tryNext = <String>[];
    if (enjoyed.isNotEmpty) {
      tryNext.add('Let $who choose a favourite game and play it together for a few minutes.');
    }
    if (tricky.isNotEmpty) {
      tryNext.add('For the tricky games, sit beside $who and take turns. The Games tab lets '
          'you pick an easier level.');
    }
    if (down > 0 && down * 2 >= pairs && pairs >= 3) {
      tryNext.add('Feelings often dropped after play. Try shorter sessions and a calming game '
          'such as Breathing Garden or Puffy\'s Day.');
    }
    if (tryNext.isEmpty) {
      tryNext.add('Keep playing at your own pace. There is nothing to act on right now.');
    }

    // only if the rule observations flag something to look at again
    final worth = RuleIndicators.compute(sessions)
        .where((i) => i.level == IndicatorLevel.worthReviewing)
        .toList();
    final talk = worth.isEmpty
        ? null
        : 'A few things were worth looking at again over more sessions '
            '(${worth.map((i) => i.title.toLowerCase()).join(', ')}). '
            'This is NOT a finding and many ordinary things can cause it, such as '
            'tiredness or not understanding the game. If you are ever worried about '
            'your child, talk to their teacher, doctor or another health professional.';

    final liked = enjoyed.length;
    return ParentSummary(
      headline: '$who played ${sessions.length} activities'
          '${liked > 0 ? ' and enjoyed $liked ${liked == 1 ? 'game' : 'games'}' : ''}.',
      enjoyed: enjoyed,
      tricky: tricky,
      feelings: feelings,
      tryNext: tryNext,
      talkToSomeone: talk,
      enoughData: true,
    );
  }
}
