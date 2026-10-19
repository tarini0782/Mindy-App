import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_session_controller.dart';
import 'common/game_bits.dart';
import 'models/game_difficulty.dart';

/// HONEY BEE COLLECTOR (Twinkle). A garden of coloured flowers. A rule card
/// says which colour(s) to collect, in order. Tap the right flower; the bee
/// flies there. The collection rule changes part-way through.
///
///   Level  flowers to collect  grid  rule pattern
///   1      6                   3x3   one colour (RED), then BLUE
///   2      8                   3x3   one colour, then another
///   3      10                  3x4   two-colour order (RED then BLUE)
///   4      12                  4x4   two-colour order, then reversed
///   5      14                  4x4   three-colour order, then a new one
///
/// Logged: success (right flower), mistake (wrong colour / wrong order),
/// rule_change, response time (previous collect -> this tap).
class BeeParams {
  final int toCollect;
  final int cols;
  final int rows;
  final List<List<int>> rules; // colour sequences, used one after another
  const BeeParams(this.toCollect, this.cols, this.rows, this.rules);

  // colours: 0 red, 1 blue, 2 yellow, 3 purple
  static BeeParams forLevel(int level) => BeeParams(
        pickByLevel(level, 6, 8, 10, 12, 14),
        pickByLevel(level, 3, 3, 3, 4, 4),
        pickByLevel(level, 3, 3, 4, 4, 4),
        pickByLevel<List<List<int>>>(
          level,
          const [[0], [1]],
          const [[0], [2]],
          const [[0, 1], [2, 3]],
          const [[0, 1], [1, 0]],
          const [[0, 1, 2], [3, 2, 1]],
        ),
      );

  /// The collection number (0-based) where the rule flips to the next one.
  int get switchAt => (toCollect / 2).round();
}

class BeeLogic {
  /// The colour required for collection number [n] (0-based).
  static int needed(BeeParams p, int n) {
    final rule = n < p.switchAt ? p.rules[0] : p.rules[1];
    final k = n < p.switchAt ? n : n - p.switchAt;
    return rule[k % rule.length];
  }

  /// Guarantees at least one flower of [colour] is on the grid.
  static void ensureAvailable(List<int> grid, int colour, Random r) {
    if (grid.contains(colour)) return;
    grid[r.nextInt(grid.length)] = colour;
  }
}

const _kFlowerColours = [
  Color(0xFFE53935),
  Color(0xFF1E88E5),
  Color(0xFFFDD835),
  Color(0xFF8E24AA),
];
const _kColourName = ['RED', 'BLUE', 'YELLOW', 'PURPLE'];

class BeeCollectorGame extends StatefulWidget {
  final GameSessionController controller;
  const BeeCollectorGame({super.key, required this.controller});

  @override
  State<BeeCollectorGame> createState() => _BeeCollectorGameState();
}

class _BeeCollectorGameState extends State<BeeCollectorGame> {
  late final BeeParams _p;
  late List<int> _grid;
  final _rand = Random(83);
  int _n = 0; // collections done
  int? _beeCell;
  DateTime _since = DateTime.now();
  bool _switched = false;

  GameSessionController get _c => widget.controller;
  int get _need => BeeLogic.needed(_p, min(_n, _p.toCollect - 1));

  @override
  void initState() {
    super.initState();
    _p = BeeParams.forLevel(_c.level);
    _grid = [for (var i = 0; i < _p.cols * _p.rows; i++) _rand.nextInt(4)];
    BeeLogic.ensureAvailable(_grid, _need, _rand);
    _c.setUnits(0, _p.toCollect);
    _c.hintText = () => 'Find a ${_kColourName[_need]} flower.';
    _c.onDemonstrate = () {};
    _c.onEasier = () {};
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, CharacterLines.start(CharacterId.twinkle),
        ms: 3000);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.supportCue.removeListener(_refresh);
    super.dispose();
  }

  void _tap(int cell) {
    if (_c.completed) return;
    _c.recordTouch();
    final ms = DateTime.now().difference(_since).inMilliseconds;
    _c.recordResponse(ms);
    _since = DateTime.now();
    if (_grid[cell] == _need) {
      _c.recordSuccess();
      GameAudio.success();
      setState(() {
        _beeCell = cell;
        _n++;
        _c.setUnits(_n, _p.toCollect);
        if (_n >= _p.toCollect) return;
        _grid[cell] = _rand.nextInt(4);
        BeeLogic.ensureAvailable(_grid, _need, _rand);
      });
      if (_n >= _p.toCollect) {
        _c.finishLine = CharacterLines.completion(CharacterId.twinkle);
        _c.complete();
        return;
      }
      if (!_switched && _n == _p.switchAt) {
        _switched = true;
        _c.recordTagged('rule_change');
        _c.react(CharacterState.excited, 'New rule! Look at the card!', ms: 3000);
      } else {
        _c.react(CharacterState.happy, 'Bzzz! Yummy!', ms: 900);
      }
    } else {
      _c.recordMistake();
      GameAudio.tap();
      _c.react(CharacterState.encouraging,
          'Look for ${_kColourName[_need]} flowers.', ms: 1600);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value);
    final ruleSeq = _n < _p.switchAt ? _p.rules[0] : _p.rules[1];
    final k = _n < _p.switchAt ? _n : _n - _p.switchAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Collect: ', style: TextStyle(fontWeight: FontWeight.w800)),
            for (var i = 0; i < ruleSeq.length; i++) ...[
              if (i > 0) const Icon(Icons.arrow_forward_rounded, size: 18),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kFlowerColours[ruleSeq[i]],
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: i == k % ruleSeq.length
                          ? Colors.black87
                          : Colors.white,
                      width: 3),
                ),
              ),
            ],
          ]),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _p.cols / _p.rows,
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: _p.cols,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (var i = 0; i < _grid.length; i++)
                    GestureDetector(
                      onTap: () => _tap(i),
                      child: CueRing(
                        show: cue && _grid[i] == _need,
                        size: 90,
                        child: Stack(alignment: Alignment.center, children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                                color: _kFlowerColours[_grid[i]],
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 4)),
                          ),
                          const Icon(Icons.local_florist_rounded,
                              color: Colors.white, size: 34),
                          if (_beeCell == i)
                            const Text('\u{1F41D}',
                                style: TextStyle(fontSize: 34)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
