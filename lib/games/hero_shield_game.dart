import 'dart:math';
import 'package:flutter/material.dart';
import '../art/sprites.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'common/game_bits.dart';
import 'models/game_difficulty.dart';

/// HERO SHIELD CHALLENGE (Nova). A hazard falls toward a friendly bunny.
/// Pick the right shield before it lands. The RULE says which shield goes
/// with which hazard, and the rule changes during play ("swap" rule).
///
///   hazard  : 0 fire, 1 water drop, 2 lightning
///   shield  : 0 red,  1 blue,       2 yellow
///   MATCH rule: fire->red, water->blue, lightning->yellow
///   SWAP  rule: fire->blue, water->red, lightning->yellow
///
///   Level  hazards  fall time  rule switches        pretty distractors
///   1      8        6.5 s      none (MATCH only)    no
///   2      10       5.5 s      1                    no
///   3      12       4.8 s      1                    yes
///   4      14       4.2 s      2                    yes
///   5      16       3.6 s      3                    yes
///
/// Logged: success (right shield), mistake (wrong shield), omission (ran out
/// of time), rule_change, response time (hazard appears -> shield chosen).
enum ShieldRule { match, swap }

class ShieldParams {
  final int hazards;
  final double fallSec;
  final List<double> switchAt; // fractions of the hazards
  final bool distractors;
  const ShieldParams(this.hazards, this.fallSec, this.switchAt, this.distractors);

  static ShieldParams forLevel(int level) => ShieldParams(
        pickByLevel(level, 8, 10, 12, 14, 16),
        pickByLevel(level, 6.5, 5.5, 4.8, 4.2, 3.6),
        pickByLevel<List<double>>(level, const [], const [0.6], const [0.5],
            const [0.33, 0.66], const [0.25, 0.5, 0.75]),
        level >= 3,
      );

  /// Hazard numbers (0-based) at which the rule flips.
  List<int> get switchIndexes =>
      [for (final f in switchAt) (hazards * f).round()];
}

class ShieldLogic {
  static int correctShield(int hazard, ShieldRule rule) {
    if (hazard == 2) return 2;
    if (rule == ShieldRule.match) return hazard;
    return hazard == 0 ? 1 : 0;
  }

  static ShieldRule ruleAt(int hazardIndex, List<int> switches) {
    var flips = 0;
    for (final s in switches) {
      if (hazardIndex >= s) flips++;
    }
    return flips.isEven ? ShieldRule.match : ShieldRule.swap;
  }
}

const _kShieldColours = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFFFDD835)];
const _kHazardEmoji = ['\u{1F525}', '\u{1F4A7}', '⚡'];
const _kHazardName = ['fire', 'water', 'lightning'];
const _kShieldName = ['RED', 'BLUE', 'YELLOW'];

class HeroShieldGame extends StatefulWidget {
  final GameSessionController controller;
  const HeroShieldGame({super.key, required this.controller});

  @override
  State<HeroShieldGame> createState() => _HeroShieldGameState();
}

class _HeroShieldGameState extends State<HeroShieldGame>
    with SingleTickerProviderStateMixin<HeroShieldGame>, GameLoop<HeroShieldGame> {
  late final ShieldParams _p;
  late final List<int> _switches;
  late final List<int> _seq;
  final _rand = Random(53);
  int _i = 0; // current hazard index
  double _t = 0; // time since this hazard appeared
  double _fall = 5;
  bool _locked = false; // feedback pause
  int? _picked;
  bool? _ok;
  ShieldRule _rule = ShieldRule.match;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = ShieldParams.forLevel(_c.level);
    _fall = _p.fallSec / _c.speed.clamp(0.75, 1.3);
    _switches = _p.switchIndexes;
    _seq = [for (var i = 0; i < _p.hazards; i++) _rand.nextInt(3)];
    _c.setUnits(0, _p.hazards);
    _c.hintText = () {
      final h = _seq[min(_i, _seq.length - 1)];
      final s = ShieldLogic.correctShield(h, _rule);
      return 'For ${_kHazardName[h]} use the ${_kShieldName[s]} shield.';
    };
    _c.onDemonstrate = () {};
    _c.onEasier = () => _fall *= 1.3;
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, CharacterLines.start(CharacterId.nova),
        ms: 3000);
    startLoop();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c.supportCue.removeListener(_refresh);
    super.dispose();
  }

  @override
  void onFrame(double dt) {
    if (_c.completed || _locked) return;
    _t += dt;
    if (_t >= _fall) _timeout();
    setState(() {});
  }

  void _timeout() {
    _locked = true;
    _c.recordTagged('omission');
    _c.recordMistake();
    _c.react(CharacterState.encouraging, 'Whoosh! Bunny is safe in a bubble.',
        ms: 1800);
    _ok = false;
    _picked = null;
    _c.schedule(1200, _next);
  }

  void _pick(int shield) {
    if (_locked || _c.completed) return;
    _locked = true;
    final right = ShieldLogic.correctShield(_seq[_i], _rule);
    final ok = shield == right;
    _c.recordTouch();
    _c.recordResponse((_t * 1000).round());
    if (ok) {
      _c.recordSuccess();
      GameAudio.success();
      _c.react(CharacterState.celebrating, 'Shield up! Well done!', ms: 1200);
    } else {
      _c.recordMistake();
      GameAudio.tap();
      _c.react(CharacterState.encouraging, 'Oops! Check the rule.', ms: 1500);
    }
    setState(() {
      _picked = shield;
      _ok = ok;
    });
    _c.schedule(ok ? 700 : 1200, _next);
  }

  void _next() {
    if (!mounted) return;
    _i++;
    _c.setUnits(_i, _p.hazards);
    if (_i >= _p.hazards) {
      _c.finishLine = CharacterLines.completion(CharacterId.nova);
      _c.complete();
      stopLoop();
      return;
    }
    final newRule = ShieldLogic.ruleAt(_i, _switches);
    if (newRule != _rule) {
      _c.recordTagged('rule_change');
      _c.react(CharacterState.excited,
          newRule == ShieldRule.swap
              ? 'New rule! RED and BLUE swap!'
              : 'Back to normal: colours match!',
          ms: 3000);
    }
    setState(() {
      _rule = newRule;
      _t = 0;
      _locked = false;
      _picked = null;
      _ok = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hazard = _seq[min(_i, _seq.length - 1)];
    final right = ShieldLogic.correctShield(hazard, _rule);
    final cue = cueActive(_c.supportCue.value);
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      final frac = (_t / _fall).clamp(0.0, 1.0).toDouble();
      final hazardY = 70 + (h * 0.42) * frac;
      return Stack(children: [
        Positioned(
          top: 6,
          left: 0,
          right: 0,
          child: Center(
            child: RuleChip(
              color: _rule == ShieldRule.match
                  ? const Color(0xFF3D5AFE)
                  : const Color(0xFF8E24AA),
              text: _rule == ShieldRule.match
                  ? 'Match the colours'
                  : 'RED and BLUE swapped!',
              icons: const [Icon(Icons.shield_rounded, color: Colors.white)],
            ),
          ),
        ),
        if (_p.distractors) ...[
          Positioned(
              left: 30 + 40 * sin(_t * 1.3),
              top: 120 + 20 * cos(_t),
              child: const Sprite('star', width: 34, height: 34, opacity: 0.8)),
          Positioned(
              right: 40 + 30 * cos(_t * 0.9),
              top: 190,
              child: const Sprite('cloud', width: 56, height: 38, opacity: 0.85)),
        ],
        Positioned(
          left: 0,
          right: 0,
          top: hazardY,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _locked && _ok == true ? 0.2 : 1,
              child: Text(_kHazardEmoji[hazard],
                  style: const TextStyle(fontSize: 64)),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 130,
          child: Center(
            child: Sprite('puffy',
                width: 72,
                height: 72,
                angle: _ok == false && _picked == null ? -0.12 : 0),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 14,
          child: Row(children: [
            for (var s = 0; s < 3; s++) ...[
              if (s > 0) const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pick(s),
                  child: Center(
                    child: CueRing(
                      show: cue && s == right,
                      size: 104,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: _kShieldColours[s],
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _picked == s
                                  ? (_ok == true ? Colors.green : Colors.orange)
                                  : Colors.white,
                              width: 5),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: Colors.white, size: 44),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]);
    });
  }
}
