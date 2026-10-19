import 'package:flutter/material.dart';
import '../art/sprites.dart';
import '../insights/insight_dashboard.dart';
import '../models/emotion_state.dart';
import '../theme/app_theme.dart';
import '../games/models/game_type.dart';

/// Charts for the parent page. Built from plain boxes (no chart package) so
/// they behave the same everywhere. Every chart has a one-line explanation.
class InsightCharts extends StatelessWidget {
  final InsightDashboard d;
  const InsightCharts({super.key, required this.d});

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Widget _card(String title, String explain, Widget child) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(explain, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );

  Widget _stat(String big, String small) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: AppColors.softLavender, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(big, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            Text(small, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (d.totalSessions == 0) {
      return _card('Charts', 'Charts appear after the first activity.',
          const Text('Nothing to show yet.'));
    }
    final maxMin = d.week.map((x) => x.minutes).fold<double>(1, (a, b) => b > a ? b : a);
    final maxFeel = [...d.before.values, ...d.after.values].fold<int>(1, (a, b) => b > a ? b : a);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _stat('${d.totalSessions}', 'activities'),
        const SizedBox(width: 8),
        _stat('${d.totalMinutes.round()}', 'minutes played'),
        const SizedBox(width: 8),
        _stat('${d.daysPlayedThisWeek}/7', 'days this week'),
      ]),
      _card('This week', 'Minutes of play each day.',
          SizedBox(
            height: 130,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final x in d.week)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(x.minutes < 0.5 ? '' : '${x.minutes.round()}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 6 + 80 * (x.minutes / maxMin),
                      decoration: BoxDecoration(
                        color: x.sessions == 0
                            ? Colors.black12
                            : AppColors.grapePurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_dayNames[x.day.weekday - 1],
                        style: const TextStyle(fontSize: 11)),
                  ]),
                ),
            ]),
          )),
      _card('How they said they felt',
          'The feeling picked before playing (grey) and after playing (colour).',
          Column(children: [
            for (final e in EmotionState.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(
                      width: 78,
                      child: Text('${e.faceEmoji} ${e.label}',
                          style: const TextStyle(fontSize: 13))),
                  Expanded(
                    child: Column(children: [
                      _bar(d.before[e]! / maxFeel, Colors.black26, d.before[e]!),
                      const SizedBox(height: 3),
                      _bar(d.after[e]! / maxFeel, _feelColour(e), d.after[e]!),
                    ]),
                  ),
                ]),
              ),
          ])),
      _card('Games played',
          'How many times, how many were finished, and whether they said it was fun.',
          Column(children: [
            for (final g in d.games)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Sprite('host_${g.game.character.name}', width: 40, height: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.game.title,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: g.finishedShare,
                          minHeight: 8,
                          backgroundColor: Colors.black12,
                          color: AppColors.meadowGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                          'Played ${g.plays}, finished ${g.finished}'
                          '${g.saidHard > 0 ? ', said hard ${g.saidHard}' : ''}'
                          '${g.needsHelp > 0 ? ', needed hints ${g.needsHelp}' : ''}',
                          style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(_funFace(g.fun), style: const TextStyle(fontSize: 26)),
                ]),
              ),
          ])),
    ]);
  }

  static String _funFace(double? fun) {
    if (fun == null) return '➖'; // no answer yet
    if (fun >= 2.5) return '\u{1F604}';
    if (fun >= 1.75) return '\u{1F610}';
    return '\u{1F641}';
  }

  static Color _feelColour(EmotionState e) {
    switch (e) {
      case EmotionState.scared:
        return const Color(0xFF9575CD);
      case EmotionState.sad:
        return const Color(0xFF64B5F6);
      case EmotionState.neutral:
        return const Color(0xFFFFB74D);
      case EmotionState.calm:
        return const Color(0xFF4DB6AC);
      case EmotionState.happy:
        return const Color(0xFFFF8A65);
    }
  }

  Widget _bar(double frac, Color c, int n) => Row(children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 10,
                width: (box.maxWidth * frac).clamp(n == 0 ? 0.0 : 6.0, box.maxWidth).toDouble(),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)),
              ),
            ),
          ),
        ),
        SizedBox(
            width: 22,
            child: Text('$n', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
      ]);
}
