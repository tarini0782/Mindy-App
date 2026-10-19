import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_session_controller.dart';

/// WORLD 4 -- SUPERHERO ACADEMY (Nova). Pattern completion.
///
/// Nova uses "Power Patterns": a row of objects repeats and the last one is
/// hidden. The child taps the missing object. Not a combat game, no timer.
/// A wrong pick just wiggles away -- Nova says "That's okay! Let's try
/// again!" and the child may try again as often as they like.
///
/// (The hidden item moves around from round to round, so it is never
/// simply "the first symbol".)
///
///   Level  pattern  choices  rounds
///   1      A B          2       3
///   2      A A B        3       3
///   3      A B C        3       4
///   4      A B B C      4       5
///   5      A B C C B    5       6    (longest row, look-alike choices)
class PatternPowerGame extends StatefulWidget {
  final GameSessionController controller;
  const PatternPowerGame({super.key, required this.controller});

  @override
  State<PatternPowerGame> createState() => _PatternPowerGameState();
}

/// Pure logic (no Flutter) so it is easy to unit test.
class PatternLogic {
  PatternLogic._();

  /// Index template per level, e.g. level 2 -> [0, 0, 1] ("AAB").
  static List<int> unitFor(int level) {
    switch (level) {
      case 1:
        return [0, 1];
      case 2:
        return [0, 0, 1];
      case 3:
        return [0, 1, 2];
      case 4:
        return [0, 1, 1, 2];
      default:
        return [0, 1, 2, 2, 1];
    }
  }

  static int choicesFor(int level) {
    switch (level) {
      case 1:
        return 2;
      case 2:
      case 3:
        return 3;
      case 4:
        return 4;
      default:
        return 5;
    }
  }

  static int roundsFor(int level) {
    switch (level) {
      case 1:
      case 2:
        return 3;
      case 3:
        return 4;
      case 4:
        return 5;
      default:
        return 6;
    }
  }

  /// Extra items shown before the hidden one, so the missing symbol is not
  /// always the first of the pattern (it moves around from round to round).
  static int extraFor(int level, int round) {
    final u = unitFor(level).length;
    final span = u > 3 ? 3 : u;
    return round % span;
  }

  /// Total length shown INCLUDING the hidden last item.
  static int totalLength(int level, {int round = 0}) =>
      unitFor(level).length * 2 + 1 + extraFor(level, round);

  /// Which template index is hidden (the answer).
  static int answerSlot(int level, {int round = 0}) {
    final u = unitFor(level);
    return u[(totalLength(level, round: round) - 1) % u.length];
  }
}

const List<String> _patternPool = [
  '\u2B50', // star
  '\u{1F308}', // rainbow
  '\u{1F984}', // unicorn
  '\u{1F338}', // flower
  '\u{1F409}', // dragon
  '\u{1F36D}', // candy
  '\u{1F9DA}', // fairy
  '\u{1F451}', // crown
  '\u{1F430}', // bunny
  '\u{1F319}', // moon
];

class _PatternPowerGameState extends State<PatternPowerGame> {
  final _rand = Random();
  late final List<int> _unit;
  late final int _rounds;
  late final int _choiceCount;
  int _round = 0;
  late List<String> _elements; // symbol for template index 0,1,2
  late List<String> _choices;
  late String _answer;
  late int _total; // items shown this round, including the hidden one
  final Set<int> _wrongTapped = {};
  final Stopwatch _think = Stopwatch();
  bool _firstTapInRound = true;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _unit = PatternLogic.unitFor(c.level);
    _rounds = PatternLogic.roundsFor(c.level);
    _choiceCount = PatternLogic.choicesFor(c.level);
    c.setUnits(0, _rounds);
    c.react(CharacterState.excited, CharacterLines.start(CharacterId.nova),
        ms: 3000);
    _newRound();
  }

  void _newRound() {
    final pool = List<String>.of(_patternPool)..shuffle(_rand);
    final needed = _unit.reduce(max) + 1;
    _elements = pool.take(needed).toList();
    final level = widget.controller.level;
    _total = PatternLogic.totalLength(level, round: _round);
    final slot = PatternLogic.answerSlot(level, round: _round);
    _answer = _elements[slot];

    // Choices: the answer first, then plausible look-alikes (the pattern's
    // own symbols), then other symbols.
    final choices = <String>[_answer];
    for (final e in _elements) {
      if (!choices.contains(e) && choices.length < _choiceCount) choices.add(e);
    }
    for (final e in pool.skip(needed)) {
      if (choices.length >= _choiceCount) break;
      if (!choices.contains(e)) choices.add(e);
    }
    choices.shuffle(_rand);
    _choices = choices;
    _wrongTapped.clear();
    _firstTapInRound = true;
    _locked = false;
    _think
      ..reset()
      ..start();
  }

  void _pick(int i) {
    if (_locked || _wrongTapped.contains(i)) return;
    final c = widget.controller;
    if (_firstTapInRound) {
      _firstTapInRound = false;
      final ms = _think.elapsedMilliseconds;
      if (ms < 60000) c.recordResponse(ms);
    }

    if (_choices[i] == _answer) {
      _locked = true;
      c.recordSuccess();
      GameAudio.success();
      _round++;
      c.setUnits(_round, _rounds);
      c.react(
        CharacterState.celebrating,
        CharacterLines.novaCorrect[_round % CharacterLines.novaCorrect.length],
        ms: 2000,
      );
      setState(() {});
      if (_round >= _rounds) {
        c.finishLine = CharacterLines.completion(CharacterId.nova);
        c.schedule(1100, () {
          if (mounted) c.complete();
        });
      } else {
        c.schedule(1300, () {
          if (mounted) setState(_newRound);
        });
      }
    } else {
      c.recordMistake();
      GameAudio.tap();
      c.react(CharacterState.encouraging, CharacterLines.novaTryAgain, ms: 2200);
      setState(() => _wrongTapped.add(i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    return LayoutBuilder(builder: (context, box) {
      final perRow = total <= 7 ? total : (total / 2).ceil();
      final cell = max(34.0, min(64.0, (box.maxWidth - 24) / perRow - 6));
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < total; i++)
                      _slot(i, total, cell),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < _choices.length; i++) _choice(i),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _slot(int i, int total, double cell) {
    final hidden = i == total - 1;
    if (hidden) {
      return Container(
        width: cell,
        height: cell,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _locked ? const Color(0xFFE3F6E5) : const Color(0xFFFFF3C4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB300), width: 3),
        ),
        child: Text(_locked ? _answer : '?',
            style: TextStyle(
                fontSize: cell * 0.62,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFF8F00))),
      );
    }
    return SizedBox(
      width: cell,
      height: cell,
      child: Center(
        child: Text(_elements[_unit[i % _unit.length]],
            style: TextStyle(fontSize: cell * 0.7, height: 1.0)),
      ),
    );
  }

  Widget _choice(int i) {
    final wrong = _wrongTapped.contains(i);
    return GestureDetector(
      onTap: () => _pick(i),
      child: AnimatedOpacity(
        opacity: wrong ? 0.3 : 1.0,
        duration: const Duration(milliseconds: 250),
        child: AnimatedScale(
          scale: wrong ? 0.85 : 1.0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF7C9CFF), width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x223D5AFE), blurRadius: 10, offset: Offset(0, 5)),
              ],
            ),
            child: Text(_choices[i], style: const TextStyle(fontSize: 46, height: 1.0)),
          ),
        ),
      ),
    );
  }
}
