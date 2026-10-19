import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/buddy.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'models/game_difficulty.dart';

/// PEEKABOO PALS (Kara). Shy pals peek out of their burrows; tap to say hi.
///
/// A gentle take on the "pop-up friends" mini-game: pals stay visible for a
/// long time, a pal you miss just shyly tucks away again (no message, no
/// penalty), and nothing is timed. From level 4 a few sleepy pals appear
/// (a soft "zzz"): they are simply left to nap.
///
///   Level  burrows  at once  stays out   sleepy pals
///   1      2 x 2    1        longest     none
///   2      3 x 2    1                    none
///   3      3 x 3    2                    none
///   4      3 x 3    2                    some
///   5      3 x 4    3        shortest    more
class PeekParams {
  final int rows;
  final int cols;
  final int hellos; // pals to greet to finish
  final double lifetime; // seconds a pal stays out
  final int maxActive;
  final double spawnGap; // seconds between new pals
  final double sleepyChance;

  const PeekParams(this.rows, this.cols, this.hellos, this.lifetime,
      this.maxActive, this.spawnGap, this.sleepyChance);

  static PeekParams forLevel(int level) => PeekParams(
        pickByLevel(level, 2, 2, 3, 3, 4),
        pickByLevel(level, 2, 3, 3, 3, 3),
        pickByLevel(level, 6, 8, 10, 12, 14),
        pickByLevel(level, 4.5, 4.0, 3.4, 2.8, 2.4),
        pickByLevel(level, 1, 1, 2, 2, 3),
        pickByLevel(level, 1.6, 1.4, 1.2, 1.0, 0.9),
        pickByLevel(level, 0.0, 0.0, 0.0, 0.12, 0.18),
      );
}

class PeekabooPalsGame extends StatefulWidget {
  final GameSessionController controller;
  const PeekabooPalsGame({super.key, required this.controller});

  @override
  State<PeekabooPalsGame> createState() => _PeekabooPalsGameState();
}

class _Pal {
  final BuddyKind kind;
  final bool sleepy;
  double age = 0;
  double? greetedAt; // game clock when greeted
  double shake = 0;
  _Pal(this.kind, this.sleepy);
}

const List<BuddyKind> _palKinds = [
  BuddyKind.happy,
  BuddyKind.calm,
  BuddyKind.excited,
  BuddyKind.neutral,
  BuddyKind.mindy,
];

const List<String> _hellos = ['Hello!', 'Peekaboo!', 'A new friend!', 'Hi there!'];

class _PeekabooPalsGameState extends State<PeekabooPalsGame>
    with
        SingleTickerProviderStateMixin<PeekabooPalsGame>,
        GameLoop<PeekabooPalsGame> {
  late final PeekParams _p;
  late final List<_Pal?> _holes;
  final _rand = Random();
  double _clock = 0;
  double _sinceSpawn = 99;
  int _greeted = 0;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _p = PeekParams.forLevel(c.level);
    _holes = List<_Pal?>.filled(_p.rows * _p.cols, null);
    c.setUnits(0, _p.hellos);
    c.react(CharacterState.happy, CharacterLines.start(CharacterId.kara), ms: 3000);
    startLoop();
  }

  double get _life => _p.lifetime * widget.controller.timeScale;

  @override
  void onFrame(double dt) {
    final c = widget.controller;
    if (c.completed) return;
    _clock += dt;
    _sinceSpawn += dt;

    for (var i = 0; i < _holes.length; i++) {
      final p = _holes[i];
      if (p == null) continue;
      p.age += dt;
      if (p.shake > 0) p.shake = max(0, p.shake - dt);
      if (p.greetedAt != null) {
        if (_clock - p.greetedAt! > 0.55) _holes[i] = null;
      } else if (p.age > _life + 0.7) {
        // The pal shyly tucks away. Data only, nothing shown.
        if (!p.sleepy) c.recordMistake();
        _holes[i] = null;
      }
    }

    final active = _holes.where((p) => p != null && p.greetedAt == null).length;
    if (active < _p.maxActive && _sinceSpawn >= _p.spawnGap) {
      final free = [
        for (var i = 0; i < _holes.length; i++)
          if (_holes[i] == null) i,
      ];
      if (free.isNotEmpty) {
        _sinceSpawn = 0;
        final sleepy = _rand.nextDouble() < _p.sleepyChance;
        _holes[free[_rand.nextInt(free.length)]] =
            _Pal(_palKinds[_rand.nextInt(_palKinds.length)], sleepy);
      }
    }

    if (_clock > 240) _finish(); // safety net: ends happily
    setState(() {});
  }

  void _finish() {
    final c = widget.controller;
    if (c.completed) return;
    c.finishLine = CharacterLines.completion(CharacterId.kara);
    c.complete();
    stopLoop();
  }

  void _tap(int i) {
    final p = _holes[i];
    final c = widget.controller;
    if (p == null || p.greetedAt != null || c.completed) return;
    if (p.sleepy) {
      // Let sleeping pals nap: a soft wiggle, nothing else.
      p.shake = 0.5;
      c.recordMistake();
      GameAudio.tap();
      return;
    }
    p.greetedAt = _clock;
    _greeted++;
    c.recordSuccess();
    c.recordResponse((p.age * 1000).round());
    c.setUnits(_greeted, _p.hellos);
    GameAudio.success();
    c.burst(_holeCenter(i), '\u{1F49B}');
    c.react(CharacterState.excited, _hellos[_greeted % _hellos.length], ms: 1500);
    if (_greeted >= _p.hellos) _finish();
  }

  Size _area = const Size(360, 520);
  Offset _holeCenter(int i) {
    final cw = _area.width / _p.cols;
    final ch = _area.height / _p.rows;
    final r = i ~/ _p.cols, col = i % _p.cols;
    return Offset((col + 0.5) * cw, (r + 0.5) * ch);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _area = box.biggest;
      final cw = box.maxWidth / _p.cols;
      final ch = box.maxHeight / _p.rows;
      final holeW = min(cw * 0.82, 150.0);
      final palSize = holeW * 0.8;
      return Stack(
        children: [
          for (var i = 0; i < _holes.length; i++)
            Positioned(
              left: (i % _p.cols) * cw,
              top: (i ~/ _p.cols) * ch,
              width: cw,
              height: ch,
              child: _hole(i, holeW, palSize),
            ),
        ],
      );
    });
  }

  Widget _hole(int i, double holeW, double palSize) {
    final p = _holes[i];
    // 0 = hidden .. 1 = fully up
    var rise = 0.0;
    if (p != null) {
      if (p.greetedAt != null) {
        rise = (1 - (_clock - p.greetedAt!) / 0.55).clamp(0.0, 1.0).toDouble();
        rise = 0.7 + 0.3 * rise; // a happy bounce before tucking away
      } else if (p.age < 0.35) {
        rise = Curves.easeOut.transform((p.age / 0.35).clamp(0.0, 1.0).toDouble());
      } else if (p.age > _life) {
        rise = (1 - (p.age - _life) / 0.7).clamp(0.0, 1.0).toDouble();
      } else {
        rise = 1.0;
      }
    }
    final shake = p == null ? 0.0 : sin(p.shake * 40) * 6 * (p.shake > 0 ? 1 : 0);
    final holeH = holeW * 0.38;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap(i),
      child: Center(
        child: SizedBox(
          width: holeW,
          height: palSize + holeH,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.hardEdge,
            children: [
              // back of the burrow
              Positioned(
                bottom: 0,
                child: Container(
                  width: holeW,
                  height: holeH,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A5A3C),
                    borderRadius: BorderRadius.circular(holeH),
                  ),
                ),
              ),
              // the pal, rising out of the burrow
              if (p != null)
                Positioned(
                  bottom: holeH * 0.35 - (1 - rise) * palSize * 1.1,
                  child: Transform.translate(
                    offset: Offset(shake, 0),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        BuddyWidget(
                          kind: p.greetedAt != null ? BuddyKind.excited : p.kind,
                          size: palSize,
                          animated: false,
                        ),
                        if (p.sleepy)
                          const Positioned(
                              top: 0,
                              right: 4,
                              child: Text('\u{1F4A4}', style: TextStyle(fontSize: 26))),
                      ],
                    ),
                  ),
                ),
              // front lip of the burrow hides the pal's feet
              Positioned(
                bottom: 0,
                child: Container(
                  width: holeW,
                  height: holeH * 0.55,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8FD16B),
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(holeH),
                        top: Radius.circular(holeH * 0.5)),
                    border: Border.all(color: const Color(0xFF6DB84C), width: 3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
