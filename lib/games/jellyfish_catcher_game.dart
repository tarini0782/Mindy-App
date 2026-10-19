import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'common/game_bits.dart';
import 'models/game_difficulty.dart';

/// JELLYFISH CATCHER (Bubbles). Moving targets, distractors and a rule that
/// changes: first "catch the BLUE jellyfish", later "catch the ones with
/// SPOTS". Tap a jellyfish to catch it.
///
///   Level  to catch  speed  on screen  rule changes
///   1      6         60     2          0
///   2      8         75     3          0
///   3      10        90     3          1
///   4      12        110    4          1
///   5      14        130    5          2
///
/// Logged: success (right catch), mistake (wrong jellyfish), omission (a
/// target swam away), rule_change, response time (appears -> caught).
enum JellyRule { blue, spots }

class JellyParams {
  final int targets;
  final double speed; // design px / second
  final int maxActive;
  final int ruleChanges;
  const JellyParams(this.targets, this.speed, this.maxActive, this.ruleChanges);

  static JellyParams forLevel(int level) => JellyParams(
        pickByLevel(level, 6, 8, 10, 12, 14),
        pickByLevel(level, 60.0, 75.0, 90.0, 110.0, 130.0),
        pickByLevel(level, 2, 3, 3, 4, 5),
        pickByLevel(level, 0, 0, 1, 1, 2),
      );

  /// Caught-counts at which the rule switches (evenly spread).
  List<int> get changePoints => [
        for (var i = 1; i <= ruleChanges; i++)
          (targets * i / (ruleChanges + 1)).round()
      ];
}

class JellyLogic {
  /// colour: 0 pink, 1 blue, 2 green.
  static bool isTarget(JellyRule rule, int colour, bool spots) =>
      rule == JellyRule.blue ? colour == 1 : spots;

  static JellyRule ruleAfterChanges(int changes) =>
      changes.isEven ? JellyRule.blue : JellyRule.spots;

  /// Makes sure at least one target is on screen so the game cannot stall.
  static (int, bool) make(JellyRule rule, Random r, {required bool needTarget}) {
    if (needTarget) {
      return rule == JellyRule.blue ? (1, r.nextBool()) : (r.nextInt(3), true);
    }
    return (r.nextInt(3), r.nextBool());
  }
}

class _Swimmer {
  double x, y, vx;
  final int colour;
  final bool spots;
  double age = 0;
  bool caught = false;
  _Swimmer(this.x, this.y, this.vx, this.colour, this.spots);
}

const _kJellyColours = [Color(0xFFF48FB1), Color(0xFF42A5F5), Color(0xFF66BB6A)];

class JellyfishCatcherGame extends StatefulWidget {
  final GameSessionController controller;
  const JellyfishCatcherGame({super.key, required this.controller});

  @override
  State<JellyfishCatcherGame> createState() => _JellyfishCatcherGameState();
}

class _JellyfishCatcherGameState extends State<JellyfishCatcherGame>
    with
        SingleTickerProviderStateMixin<JellyfishCatcherGame>,
        GameLoop<JellyfishCatcherGame> {
  late final JellyParams _p;
  final _rand = Random(41);
  final List<_Swimmer> _fish = [];
  Size _size = const Size(360, 520);
  JellyRule _rule = JellyRule.blue;
  int _caught = 0;
  int _changes = 0;
  double _spawnIn = 0.6;
  double _cooldown = 0;
  double _speedScale = 1;
  int _maxActive = 2;
  double _demoUntil = 0;
  double _clock = 0;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = JellyParams.forLevel(_c.level);
    _maxActive = _p.maxActive;
    _c.setUnits(0, _p.targets);
    _c.hintText = () => _rule == JellyRule.blue
        ? 'Try looking for the BLUE jellyfish.'
        : 'Try looking for the jellyfish with SPOTS.';
    _c.onDemonstrate = () => _demoUntil = _clock + 3.5;
    _c.onEasier = () {
      _speedScale = max(0.6, _speedScale * 0.8);
      _maxActive = max(1, _maxActive - 1);
    };
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, CharacterLines.start(CharacterId.bubbles),
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

  bool _isTarget(_Swimmer s) => JellyLogic.isTarget(_rule, s.colour, s.spots);

  void _spawn() {
    final needTarget = !_fish.any((f) => !f.caught && _isTarget(f));
    final (colour, spots) = JellyLogic.make(_rule, _rand, needTarget: needTarget);
    final fromLeft = _rand.nextBool();
    final speed = _p.speed * _c.speed * _speedScale * (0.85 + _rand.nextDouble() * 0.3);
    final k = _size.width / 360.0;
    final y = 40 + _rand.nextDouble() * (_size.height - 140);
    _fish.add(_Swimmer(fromLeft ? -50 * k : _size.width + 50 * k, y,
        (fromLeft ? 1 : -1) * speed * k, colour, spots));
  }

  @override
  void onFrame(double dt) {
    if (_c.completed) return;
    _clock += dt;
    if (_cooldown > 0) {
      _cooldown -= dt;
    } else {
      _spawnIn -= dt;
      if (_spawnIn <= 0 && _fish.length < _maxActive) {
        _spawn();
        _spawnIn = 0.8 + _rand.nextDouble() * 0.9;
      }
    }
    for (final f in _fish) {
      f.x += f.vx * dt;
      f.age += dt;
    }
    final gone = _fish
        .where((f) => f.x < -80 || f.x > _size.width + 80)
        .toList();
    for (final f in gone) {
      if (_isTarget(f) && !f.caught) _c.recordTagged('omission');
      _fish.remove(f);
    }
    setState(() {});
  }

  void _tapAt(Offset p) {
    if (_c.completed) return;
    final k = _size.width / 360.0;
    _Swimmer? best;
    var bestD = 52.0 * k;
    for (final f in _fish) {
      final d = (Offset(f.x, f.y) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = f;
      }
    }
    if (best == null) return;
    _c.recordTouch();
    if (_isTarget(best)) {
      _c.recordResponse((best.age * 1000).round());
      _c.recordSuccess();
      _fish.remove(best);
      _caught++;
      _c.setUnits(_caught, _p.targets);
      GameAudio.success();
      _c.burst(Offset(best.x, best.y), '⭐');
      if (_caught >= _p.targets) {
        _c.finishLine = CharacterLines.completion(CharacterId.bubbles);
        _c.complete();
        stopLoop();
        return;
      }
      final pts = _p.changePoints;
      if (_changes < pts.length && _caught >= pts[_changes]) {
        _changes++;
        _rule = JellyLogic.ruleAfterChanges(_changes);
        _fish.clear();
        _cooldown = 1.6;
        _c.recordTagged('rule_change');
        _c.react(CharacterState.excited,
            _rule == JellyRule.blue
                ? 'New rule! Catch the BLUE jellyfish!'
                : 'New rule! Catch the ones with SPOTS!',
            ms: 3000);
      }
    } else {
      _c.recordMistake();
      GameAudio.tap();
      _c.react(
          CharacterState.encouraging,
          _rule == JellyRule.blue ? 'Look for BLUE ones!' : 'Look for SPOTS!',
          ms: 1500);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value) || _clock < _demoUntil;
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      final k = _size.width / 360.0;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _tapAt(d.localPosition),
        child: Stack(children: [
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: RuleChip(
                color: const Color(0xFF0288D1),
                text: _rule == JellyRule.blue
                    ? 'Catch the BLUE jellyfish'
                    : 'Catch the SPOTTED jellyfish',
                icons: [
                  _rule == JellyRule.blue
                      ? const Icon(Icons.circle, color: Color(0xFF42A5F5), size: 26)
                      : const Icon(Icons.blur_on_rounded,
                          color: Colors.white, size: 28),
                ],
              ),
            ),
          ),
          for (final f in _fish)
            Positioned(
              left: f.x - 40 * k,
              top: f.y - 40 * k,
              child: CueRing(
                show: cue && _isTarget(f),
                size: 80 * k,
                child: CustomPaint(
                  size: Size(56 * k, 64 * k),
                  painter: _JellyPainter(_kJellyColours[f.colour], f.spots, f.age),
                ),
              ),
            ),
        ]),
      );
    });
  }
}

class _JellyPainter extends CustomPainter {
  final Color colour;
  final bool spots;
  final double t;
  _JellyPainter(this.colour, this.spots, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = colour;
    final w = size.width, h = size.height;
    canvas.drawArc(Rect.fromLTWH(0, 0, w, h * 0.75), pi, pi, true, body);
    final tent = Paint()
      ..color = colour.withValues(alpha: 0.8)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final x = w * (0.18 + i * 0.213);
      final sway = sin(t * 4 + i) * 4;
      final path = Path()
        ..moveTo(x, h * 0.375)
        ..quadraticBezierTo(x + sway, h * 0.7, x - sway, h);
      canvas.drawPath(path, tent);
    }
    final eye = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.35, h * 0.28), 4, eye);
    canvas.drawCircle(Offset(w * 0.65, h * 0.28), 4, eye);
    if (spots) {
      final sp = Paint()..color = Colors.white.withValues(alpha: 0.9);
      canvas.drawCircle(Offset(w * 0.25, h * 0.12), 4.5, sp);
      canvas.drawCircle(Offset(w * 0.5, h * 0.06), 4.5, sp);
      canvas.drawCircle(Offset(w * 0.75, h * 0.14), 4.5, sp);
    }
  }

  @override
  bool shouldRepaint(covariant _JellyPainter old) => true;
}
