import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_session_controller.dart';
import 'common/game_bits.dart';
import 'models/game_difficulty.dart';

/// RAINBOW UNICORN MEMORY QUEST (Kara). Watch the gems light up, then tap
/// them in the same order. Sequences get longer round by round.
///
///   Level  gems  first length  last length  rounds
///   1      4     2             3            2
///   2      4     2             4            3
///   3      5     3             5            3
///   4      6     3             6            4
///   5      6     4             7            4
///
/// A wrong tap shows the sequence again (a retry), it never ends the game.
/// Logged: success per correct step, mistake per wrong step (order error),
/// response time per step, support events. Demonstration = replay.
class QuestParams {
  final int gems;
  final int firstLen;
  final int rounds;
  const QuestParams(this.gems, this.firstLen, this.rounds);

  static QuestParams forLevel(int level) => QuestParams(
        pickByLevel(level, 4, 4, 5, 6, 6),
        pickByLevel(level, 2, 2, 3, 3, 4),
        pickByLevel(level, 2, 3, 3, 4, 4),
      );

  int lengthForRound(int round) => firstLen + round;
}

class SequenceLogic {
  /// A reproducible sequence that never repeats the same gem three times.
  static List<int> make(int len, int gems, Random r) {
    final out = <int>[];
    while (out.length < len) {
      final g = r.nextInt(gems);
      final n = out.length;
      if (n >= 2 && out[n - 1] == g && out[n - 2] == g) continue;
      out.add(g);
    }
    return out;
  }

  static bool isCorrect(List<int> seq, int pos, int tapped) =>
      pos >= 0 && pos < seq.length && seq[pos] == tapped;
}

const _kGemColours = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFF43A047),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
  Color(0xFFFB8C00),
];

enum _Phase { showing, input, feedback }

class MemoryQuestGame extends StatefulWidget {
  final GameSessionController controller;
  const MemoryQuestGame({super.key, required this.controller});

  @override
  State<MemoryQuestGame> createState() => _MemoryQuestGameState();
}

class _MemoryQuestGameState extends State<MemoryQuestGame> {
  late final QuestParams _p;
  final _rand = Random(67);
  int _round = 0;
  int _shorten = 0; // "easier" support shortens sequences
  late List<int> _seq;
  int _pos = 0;
  int _lit = -1;
  _Phase _phase = _Phase.showing;
  int _doneSteps = 0;
  DateTime _stepStart = DateTime.now();
  int _replayId = 0;

  GameSessionController get _c => widget.controller;
  int get _totalSteps =>
      [for (var r = 0; r < _p.rounds; r++) _p.lengthForRound(r)]
          .reduce((a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _p = QuestParams.forLevel(_c.level);
    _seq = _newSeq();
    _c.setUnits(0, _totalSteps);
    _c.hintText = () => 'Remember the order of the colours.';
    _c.onDemonstrate = _play;
    _c.onEasier = () => _shorten = min(1, _shorten + 1);
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, CharacterLines.start(CharacterId.kara),
        ms: 2500);
    _c.schedule(1200, _play);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.supportCue.removeListener(_refresh);
    super.dispose();
  }

  List<int> _newSeq() => SequenceLogic.make(
      max(2, _p.lengthForRound(_round) - _shorten), _p.gems, _rand);

  void _play() {
    if (!mounted || _c.completed) return;
    final id = ++_replayId;
    setState(() {
      _phase = _Phase.showing;
      _pos = 0;
      _lit = -1;
    });
    var delay = 400;
    for (final g in _seq) {
      final on = delay;
      _c.schedule(on, () {
        if (!mounted || id != _replayId) return;
        setState(() => _lit = g);
        GameAudio.tap();
      });
      _c.schedule(on + 650, () {
        if (!mounted || id != _replayId) return;
        setState(() => _lit = -1);
      });
      delay += 950;
    }
    _c.schedule(delay, () {
      if (!mounted || id != _replayId) return;
      setState(() {
        _phase = _Phase.input;
        _stepStart = DateTime.now();
      });
    });
  }

  void _tap(int gem) {
    if (_phase != _Phase.input || _c.completed) return;
    _c.recordTouch();
    final ms = DateTime.now().difference(_stepStart).inMilliseconds;
    _c.recordResponse(ms);
    _stepStart = DateTime.now();
    setState(() => _lit = gem);
    _c.schedule(250, () {
      if (mounted) setState(() => _lit = -1);
    });
    if (SequenceLogic.isCorrect(_seq, _pos, gem)) {
      _c.recordSuccess();
      GameAudio.success();
      _pos++;
      _doneSteps++;
      _c.setUnits(_doneSteps, _totalSteps);
      if (_pos >= _seq.length) _roundDone();
    } else {
      _c.recordMistake();
      _c.react(CharacterState.encouraging, 'Not quite. Watch again!', ms: 1800);
      setState(() => _phase = _Phase.feedback);
      _c.schedule(1100, _play);
    }
  }

  void _roundDone() {
    _round++;
    if (_round >= _p.rounds) {
      _c.finishLine = CharacterLines.completion(CharacterId.kara);
      _c.complete();
      return;
    }
    _c.react(CharacterState.celebrating, 'Sparkly! A longer one next!', ms: 1800);
    setState(() => _phase = _Phase.feedback);
    _c.schedule(1300, () {
      if (!mounted) return;
      _seq = _newSeq();
      _play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cueNext = cueActive(_c.supportCue.value) &&
        _phase == _Phase.input &&
        _pos < _seq.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Column(children: [
        RuleChip(
          color: const Color(0xFF8E24AA),
          text: _phase == _Phase.showing
              ? 'Watch the gems...'
              : (_phase == _Phase.input ? 'Your turn!' : 'Get ready...'),
          icons: const [Icon(Icons.auto_awesome_rounded, color: Colors.white)],
        ),
        const SizedBox(height: 8),
        Text('Round ${min(_round + 1, _p.rounds)} of ${_p.rounds}  •  ${_seq.length} gems',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Expanded(
          child: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var g = 0; g < _p.gems; g++)
                  GestureDetector(
                    onTap: () => _tap(g),
                    child: CueRing(
                      show: cueNext && _seq[_pos] == g,
                      size: 104,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: _lit == g ? 94 : 80,
                        height: _lit == g ? 94 : 80,
                        decoration: BoxDecoration(
                          color: _kGemColours[g]
                              .withValues(alpha: _lit == g ? 1.0 : 0.62),
                          shape: BoxShape.circle,
                          boxShadow: _lit == g
                              ? [BoxShadow(color: _kGemColours[g], blurRadius: 22)]
                              : const [],
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: const Icon(Icons.diamond_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
