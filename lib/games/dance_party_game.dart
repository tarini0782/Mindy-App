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

/// DANCE PARTY (Lumi). Glowing music notes slide down colourful lanes. Tap
/// the matching pad when a note reaches the glowing line. Grey "quiet" notes
/// are obstacles: let them pass! A rhythm game with a dancing princess.
///
///   Level  notes to hit  lanes  note speed  quiet-note share  beat (s)
///   1      10            3      150         0%                1.10
///   2      12            3      170         10%               1.00
///   3      16            4      190         18%               0.90
///   4      20            4      215         25%               0.80
///   5      24            4      240         30%               0.70
///
/// Logged: success (note hit), mistake (quiet note tapped), omission (note
/// missed), response time = timing error from the line in milliseconds.
/// Tapping a pad with no note nearby is only a touch, never a mistake.
class DanceParams {
  final int notes;
  final int lanes;
  final double speed;
  final double quietShare;
  final double beat;
  const DanceParams(this.notes, this.lanes, this.speed, this.quietShare, this.beat);

  static DanceParams forLevel(int level) => DanceParams(
        pickByLevel(level, 10, 12, 16, 20, 24),
        pickByLevel(level, 3, 3, 4, 4, 4),
        pickByLevel(level, 150.0, 170.0, 190.0, 215.0, 240.0),
        pickByLevel(level, 0.0, 0.10, 0.18, 0.25, 0.30),
        pickByLevel(level, 1.10, 1.00, 0.90, 0.80, 0.70),
      );
}

class DanceLogic {
  /// A note counts as hit when it is within [window] of the line.
  static bool inWindow(double noteY, double lineY, double window) =>
      (noteY - lineY).abs() <= window;

  /// Timing error in ms for a note at [noteY] moving at [speed] px/s.
  static int timingErrorMs(double noteY, double lineY, double speed) =>
      (((noteY - lineY).abs() / speed) * 1000).round();

  /// The first note and every note while none is playable is a real note.
  static bool nextIsQuiet(Random r, double share, {required bool realOnScreen}) =>
      realOnScreen && r.nextDouble() < share;
}

class _Note {
  final int lane;
  final bool quiet;
  double y = -30;
  bool done = false;
  _Note(this.lane, this.quiet);
}

const _kLaneColours = [
  Color(0xFFFF4081), Color(0xFF40C4FF), Color(0xFFFFD740), Color(0xFF69F0AE)
];

class DancePartyGame extends StatefulWidget {
  final GameSessionController controller;
  const DancePartyGame({super.key, required this.controller});

  @override
  State<DancePartyGame> createState() => _DancePartyGameState();
}

class _DancePartyGameState extends State<DancePartyGame>
    with
        SingleTickerProviderStateMixin<DancePartyGame>,
        GameLoop<DancePartyGame> {
  late final DanceParams _p;
  final _rand = Random(61);
  final List<_Note> _notes = [];
  double _h = 520;
  double _speed = 150;
  double _beat = 1.1;
  double _quiet = 0;
  double _nextIn = 0.8;
  double _clock = 0;
  double _demoUntil = 0;
  int _hits = 0;
  int _combo = 0;
  int _spawned = 0;
  final Map<int, double> _flash = {};

  static const double _win = 46;

  GameSessionController get _c => widget.controller;
  double get _line => _h - 124;
  int get _lanes => _p.lanes;

  @override
  void initState() {
    super.initState();
    _p = DanceParams.forLevel(_c.level);
    _speed = _p.speed;
    _beat = _p.beat;
    _quiet = _p.quietShare;
    _c.setUnits(0, _p.notes);
    _c.hintText = () => 'Tap the pad when the note touches the glowing line.';
    _c.onDemonstrate = () => _demoUntil = _clock + 3.5;
    _c.onEasier = () {
      _speed = max(110.0, _speed * 0.85);
      _beat *= 1.2;
      _quiet *= 0.5;
    };
    _c.onHarder = () {
      _speed = min(280.0, _speed * 1.1);
      _beat = max(0.55, _beat * 0.92);
      _quiet = min(0.4, _quiet + 0.06);
    };
    _c.supportCue.addListener(_refresh);
    _c.react(CharacterState.excited, "Let's dance! Tap to the music!", ms: 2600);
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
    if (_c.completed) return;
    _clock += dt;
    final sdt = dt * _c.speed.clamp(0.7, 1.0);
    _nextIn -= sdt;
    // keep enough real notes coming to finish the song
    final realLeft = _p.notes - _hits;
    final realOn = _notes.where((n) => !n.quiet && !n.done).length;
    if (_nextIn <= 0 && _notes.length < 8 && (realOn < realLeft || _spawned < 3)) {
      final quiet = DanceLogic.nextIsQuiet(_rand, _quiet, realOnScreen: realOn > 0);
      _notes.add(_Note(_rand.nextInt(_lanes), quiet));
      _spawned++;
      _nextIn = _beat * (0.9 + _rand.nextDouble() * 0.2);
    }
    final gone = <_Note>[];
    for (final n in _notes) {
      n.y += _speed * sdt;
      if (n.y > _line + _win + 24 && !n.done) {
        n.done = true;
        gone.add(n);
        if (!n.quiet) {
          _combo = 0;
          _c.recordTagged('omission');
        }
      }
    }
    _notes.removeWhere(gone.contains);
    _flash.updateAll((k, v) => max(0.0, v - dt * 3));
    if (!_c.completed) setState(() {});
  }

  void _tapLane(int lane) {
    if (_c.completed) return;
    _c.recordTouch();
    _flash[lane] = 1;
    _Note? best;
    for (final n in _notes) {
      if (n.lane != lane || n.done) continue;
      if (!DanceLogic.inWindow(n.y, _line, _win)) continue;
      if (best == null || (n.y - _line).abs() < (best.y - _line).abs()) best = n;
    }
    if (best == null) return; // stray tap: only a touch
    best.done = true;
    _notes.remove(best);
    if (best.quiet) {
      _combo = 0;
      _c.recordMistake();
      GameAudio.tap();
      _c.react(CharacterState.encouraging, 'Shh, that one is quiet!', ms: 1400);
      return;
    }
    _combo++;
    _c.recordResponse(DanceLogic.timingErrorMs(best.y, _line, _speed).clamp(1, 5000).toInt());
    _c.recordSuccess(points: 1 + min(_combo, 6) ~/ 2);
    GameAudio.success();
    _c.burst(Offset(_laneX(lane), _line), _combo >= 4 ? '\u{1F389}' : '\u{1F3B5}');
    _hits++;
    _c.setUnits(_hits, _p.notes);
    if (_combo == 4 || _combo == 8) {
      _c.react(CharacterState.celebrating, 'Combo x$_combo! Dance!', ms: 1500);
    }
    if (_hits >= _p.notes) {
      _c.finishLine = CharacterLines.completion(CharacterId.lumi);
      _c.complete();
      stopLoop();
    }
  }

  double _width = 360;
  double _laneX(int lane) => _width / _lanes * (lane + 0.5);

  @override
  Widget build(BuildContext context) {
    final cue = cueActive(_c.supportCue.value) || _clock < _demoUntil;
    return LayoutBuilder(builder: (context, box) {
      _h = box.maxHeight;
      _width = box.maxWidth;
      final laneW = _width / _lanes;
      // the lane of the next real note gets the cue
      int? cueLane;
      double bestY = -1e9;
      for (final n in _notes) {
        if (!n.quiet && !n.done && n.y > bestY) {
          bestY = n.y;
          cueLane = n.lane;
        }
      }
      final sway = sin(_clock * 6) * 6;
      return Stack(children: [
        Positioned.fill(
          child: CustomPaint(painter: _FloorPainter(_lanes, _line, _clock)),
        ),
        Positioned(
          top: 4,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.translate(
              offset: Offset(sway, 0),
              child: Sprite('host_lumi', width: 56, height: 56, angle: sin(_clock * 6) * 0.12),
            ),
          ),
        ),
        for (final n in _notes)
          Positioned(
            left: n.lane * laneW + laneW / 2 - 24,
            top: n.y - 24,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: n.quiet ? Colors.grey.shade400 : _kLaneColours[n.lane],
                boxShadow: [
                  BoxShadow(
                      color: (n.quiet ? Colors.black26 : _kLaneColours[n.lane])
                          .withValues(alpha: 0.5),
                      blurRadius: 10)
                ],
              ),
              child: Center(
                child: n.quiet
                    ? Sprite('quiet', width: 34, height: 34)
                    : const Icon(Icons.music_note_rounded,
                        color: Colors.white, size: 30),
              ),
            ),
          ),
        for (var i = 0; i < _lanes; i++)
          Positioned(
            left: i * laneW + 6,
            top: _line + 30,
            width: laneW - 12,
            height: 76,
            child: GestureDetector(
              key: Key('pad_$i'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _tapLane(i),
              child: CueRing(
                show: cue && cueLane == i,
                size: 70,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _kLaneColours[i].withValues(alpha: 0.55 + 0.45 * (_flash[i] ?? 0)),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ),
          ),
        if (_combo >= 2)
          Positioned(
            top: 10,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFF7E57C2),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('x$_combo',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ),
          ),
      ]);
    });
  }
}

class _FloorPainter extends CustomPainter {
  final int lanes;
  final double line;
  final double t;
  _FloorPainter(this.lanes, this.line, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF311B92), Color(0xFF6A1B9A), Color(0xFFAD1457)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    final lane = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final w = size.width / lanes;
    for (var i = 0; i < lanes; i += 2) {
      canvas.drawRect(Rect.fromLTWH(i * w, 0, w, size.height), lane);
    }
    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 + 0.25 * sin(t * 8))
      ..strokeWidth = 5;
    canvas.drawLine(Offset(0, line), Offset(size.width, line), glow);
    final dots = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(Offset((i * 83.0) % size.width, (i * 47.0 + t * 20) % line), 2, dots);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPainter old) => true;
}
