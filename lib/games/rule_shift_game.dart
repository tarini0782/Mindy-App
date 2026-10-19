import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'models/game_difficulty.dart';

/// SORTING STARS (Nova). A rule-switching game built on the well-known
/// "dimensional change card sort" design used in child development research.
///
/// Two boxes sit at the bottom: LEFT shows a RED STAR, RIGHT shows a BLUE
/// HEART. A card appears that matches one box by colour and the other by
/// shape (a red heart, or a blue star). The rule banner says whether to sort
/// by COLOUR or by SHAPE. After a few cards the rule changes.
///
///   Level  cards/rule  rule blocks                      rule always shown
///   1      4           colour, shape                    yes
///   2      5           colour, shape                    yes
///   3      5           colour, shape, colour            yes
///   4      6           colour, shape, colour, shape     only first 2 cards
///   5      6           colour, shape, colour, shape     only first 2 cards
///
/// Logged for the research record: every answer (success / mistake), the
/// response time, a `rule_change` marker at each switch, and a
/// `perseveration` marker when a mistake happens in the first two cards after
/// a switch (with two boxes that answer is the OLD rule's answer).
/// Nothing the child sees is a score or a penalty.
enum SortRule { colour, shape }

class SortCard {
  final int colour; // 0 = red, 1 = blue
  final int shape; // 0 = star, 1 = heart
  const SortCard(this.colour, this.shape);
  @override
  bool operator ==(Object other) =>
      other is SortCard && other.colour == colour && other.shape == shape;
  @override
  int get hashCode => colour * 2 + shape;
}

class SortLogic {
  /// Which box (0 = left, 1 = right) is right under [rule].
  /// Left box = red star (0,0); right box = blue heart (1,1).
  static int correctSide(SortCard c, SortRule rule) =>
      rule == SortRule.colour ? c.colour : c.shape;

  /// Test cards always disagree with themselves (colour != shape), so the two
  /// rules always point at DIFFERENT boxes.
  static bool isConflicting(SortCard c) => c.colour != c.shape;

  /// First [kWindow] cards after a switch count as "post-switch".
  static const int kWindow = 2;
  static bool isPostSwitch(int block, int indexInBlock) =>
      block > 0 && indexInBlock < kWindow;
}

class RuleShiftParams {
  final int cardsPerRule;
  final List<SortRule> blocks;
  final bool ruleAlwaysShown;
  const RuleShiftParams(this.cardsPerRule, this.blocks, this.ruleAlwaysShown);

  static RuleShiftParams forLevel(int level) {
    const c = SortRule.colour, s = SortRule.shape;
    return RuleShiftParams(
      pickByLevel(level, 4, 5, 5, 6, 6),
      pickByLevel<List<SortRule>>(level, const [c, s], const [c, s],
          const [c, s, c], const [c, s, c, s], const [c, s, c, s]),
      level <= 3,
    );
  }

  int get totalCards => cardsPerRule * blocks.length;
}

const _kRed = Color(0xFFE53935);
const _kBlue = Color(0xFF1E88E5);

class RuleShiftGame extends StatefulWidget {
  final GameSessionController controller;
  const RuleShiftGame({super.key, required this.controller});

  @override
  State<RuleShiftGame> createState() => _RuleShiftGameState();
}

class _RuleShiftGameState extends State<RuleShiftGame>
    with SingleTickerProviderStateMixin<RuleShiftGame>, GameLoop<RuleShiftGame> {
  late final RuleShiftParams _p;
  final _rand = Random(23);
  int _block = 0;
  int _inBlock = 0;
  int _done = 0;
  SortCard _card = const SortCard(0, 1);
  bool _locked = false;
  int? _tappedSide;
  bool? _wasRight;
  double _rtSec = 0; // counts only while the game is not paused (ticker freezes)

  GameSessionController get _c => widget.controller;
  SortRule get _rule => _p.blocks[_block];

  @override
  void initState() {
    super.initState();
    _p = RuleShiftParams.forLevel(_c.level);
    _c.setUnits(0, _p.totalCards);
    _c.react(CharacterState.excited, CharacterLines.start(CharacterId.nova),
        ms: 3000);
    startLoop();
  }

  @override
  void onFrame(double dt) {
    if (!_locked) _rtSec += dt;
  }

  SortCard _newCard() {
    SortCard next;
    do {
      next = _rand.nextBool() ? const SortCard(0, 1) : const SortCard(1, 0);
    } while (next == _card && _rand.nextInt(3) != 0); // mostly alternate
    return next;
  }

  void _tap(int side) {
    if (_locked || _c.completed) return;
    _locked = true;
    final correct = SortLogic.correctSide(_card, _rule);
    final ok = side == correct;
    _c.recordTouch();
    _c.recordResponse((_rtSec * 1000).round());
    if (ok) {
      _c.recordSuccess();
      GameAudio.success();
      _c.react(CharacterState.celebrating, 'Yes! Great sorting!', ms: 1200);
    } else {
      _c.recordMistake();
      if (SortLogic.isPostSwitch(_block, _inBlock)) {
        _c.recordTagged('perseveration');
      }
      GameAudio.tap();
      _c.react(CharacterState.encouraging,
          _rule == SortRule.colour ? 'Look at the COLOUR!' : 'Look at the SHAPE!',
          ms: 1500);
    }
    setState(() {
      _tappedSide = side;
      _wasRight = ok;
    });
    _done++;
    _c.setUnits(_done, _p.totalCards);
    _c.schedule(ok ? 650 : 1100, _next);
  }

  void _next() {
    if (!mounted) return;
    _inBlock++;
    var switched = false;
    if (_inBlock >= _p.cardsPerRule) {
      _block++;
      _inBlock = 0;
      if (_block >= _p.blocks.length) {
        _c.finishLine = CharacterLines.completion(CharacterId.nova);
        _c.complete();
        stopLoop();
        return;
      }
      switched = true;
    }
    if (switched) {
      _c.recordTagged('rule_change');
      _c.react(CharacterState.excited,
          _rule == SortRule.colour
              ? 'New rule! Sort by COLOUR!'
              : 'New rule! Sort by SHAPE!',
          ms: 2600);
    }
    setState(() {
      _card = _newCard();
      _locked = false;
      _tappedSide = null;
      _wasRight = null;
      _rtSec = 0;
    });
  }

  bool get _showRule => _p.ruleAlwaysShown || _inBlock < 2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showRule ? 1 : 0,
              child: _RuleBanner(rule: _rule),
            ),
          ),
          Expanded(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    width: 5,
                    color: _wasRight == null
                        ? Colors.white
                        : (_wasRight! ? Colors.green : Colors.orange),
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 12)
                  ],
                ),
                child: _ShapeIcon(card: _card, size: 120),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _Box(
                  card: const SortCard(0, 0),
                  mark: _tappedSide == 0,
                  onTap: () => _tap(0),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Box(
                  card: const SortCard(1, 1),
                  mark: _tappedSide == 1,
                  onTap: () => _tap(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShapeIcon extends StatelessWidget {
  final SortCard card;
  final double size;
  const _ShapeIcon({required this.card, required this.size});
  @override
  Widget build(BuildContext context) => Icon(
        card.shape == 0 ? Icons.star_rounded : Icons.favorite_rounded,
        size: size,
        color: card.colour == 0 ? _kRed : _kBlue,
      );
}

class _Box extends StatelessWidget {
  final SortCard card;
  final bool mark;
  final VoidCallback onTap;
  const _Box({required this.card, required this.mark, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 118,
          decoration: BoxDecoration(
            color: mark ? const Color(0xFFFFF3C4) : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF7C4DFF), width: 4),
          ),
          child: Center(child: _ShapeIcon(card: card, size: 64)),
        ),
      );
}

class _RuleBanner extends StatelessWidget {
  final SortRule rule;
  const _RuleBanner({required this.rule});
  @override
  Widget build(BuildContext context) {
    final colour = rule == SortRule.colour;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (colour) ...const [
            Icon(Icons.circle, color: _kRed, size: 30),
            SizedBox(width: 4),
            Icon(Icons.circle, color: _kBlue, size: 30),
          ] else ...const [
            Icon(Icons.star_rounded, color: Colors.white, size: 32),
            SizedBox(width: 4),
            Icon(Icons.favorite_rounded, color: Colors.white, size: 32),
          ],
          const SizedBox(width: 12),
          Text(
            colour ? 'Sort by COLOUR' : 'Sort by SHAPE',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
