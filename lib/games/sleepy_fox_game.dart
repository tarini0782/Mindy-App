import 'dart:math';
import 'package:flutter/material.dart';
import '../characters/character_id.dart';
import '../characters/character_lines.dart';
import 'base/game_audio.dart';
import 'base/game_loop.dart';
import 'base/game_session_controller.dart';
import 'models/game_difficulty.dart';

/// SLEEPY FOX (Lumi). A go / no-go game, the standard way child development
/// research looks at stopping a tap.
///
/// Friends (bunny, bear, chick) pop up one at a time: TAP the big button.
/// Sometimes the sleepy fox appears: do NOT tap, let it sleep.
///
/// Logged: success (tap on a friend, or correctly waiting for the fox), the
/// response time of friend taps, mistake + `commission` (tapped the fox) and
/// `omission` (a friend left without a tap; not counted as a mistake).
///
///   Level  items  fox share  time to answer
///   1      12     25%         2.6 s
///   2      14     25%         2.3 s
///   3      16     30%         2.0 s
///   4      18     33%         1.7 s
///   5      20     33%         1.5 s
///
/// ---------------------------------------------------------------------------
/// v37 VISUAL PASS -- READ THIS BEFORE CHANGING ANYTHING HERE.
///
/// This game produces two of the seven caregiver indicators:
///   * "Tapping when asked to wait"   <- `commission` events / fox items
///   * "Friends that were not tapped" <- `omission` events / friend items
/// (see `lib/insights/rule_indicators.dart`, `stopping` and `lapses`).
///
/// The v37 pass changed ONLY what sits BEHIND the stimulus. Three rules were
/// followed, and must keep being followed:
///
///   1. The scene is IDENTICAL on go and no-go trials. If the background
///      dimmed, shook or changed colour for the fox, that would be a second
///      cue that the fox is a no-go. Commission errors would drop for a
///      reason that has nothing to do with the child, and indicator 2 would
///      stop measuring what it claims to measure.
///   2. The stimulus itself is unchanged -- same glyphs, same 120px size,
///      same 180ms scale/fade. Discriminability between go and no-go is
///      exactly what it was, so sessions stay comparable with old ones.
///   3. The backdrop does not animate. Motion next to a timed stimulus
///      competes for attention and would add noise to `recordResponse`.
///
/// The response button is also unchanged in size (110), width (full) and
/// position (bottom). Moving the tap target would change every measured
/// reaction time and make this session incomparable with earlier ones.
/// Only its colour and shape changed.
class FoxParams {
  final int items;
  final double foxShare;
  final double stimSec;
  const FoxParams(this.items, this.foxShare, this.stimSec);

  /// How many fox (do-not-tap) items a session contains.
  int get foxCount => (items * foxShare).round().clamp(1, items - 2).toInt();
  static FoxParams forLevel(int level) => FoxParams(
        pickByLevel(level, 12, 14, 16, 18, 20),
        pickByLevel(level, 0.25, 0.25, 0.30, 0.33, 0.33),
        pickByLevel(level, 2.6, 2.3, 2.0, 1.7, 1.5),
      );
}

class FoxLogic {
  /// true = fox (no-go). First two items are always friends and the fox never
  /// appears more than twice in a row, so the rhythm stays fair.
  static List<bool> sequence(int items, double foxShare, Random rand) {
    final foxes = FoxParams(items, foxShare, 0).foxCount;
    for (var attempt = 0; attempt < 200; attempt++) {
      final seq = List<bool>.filled(items, false);
      final slots = [for (var i = 2; i < items; i++) i]..shuffle(rand);
      for (var k = 0; k < foxes; k++) {
        seq[slots[k]] = true;
      }
      if (_ok(seq)) return seq;
    }
    // deterministic fallback: spread evenly
    final seq = List<bool>.filled(items, false);
    final step = ((items - 2) / foxes).floor().clamp(2, items).toInt();
    for (var k = 0, i = 3; k < foxes && i < items; k++, i += step) {
      seq[i] = true;
    }
    return seq;
  }

  static bool _ok(List<bool> s) {
    var run = 0;
    for (final f in s) {
      run = f ? run + 1 : 0;
      if (run > 2) return false;
    }
    return true;
  }
}

enum _Phase { showing, gap }

class SleepyFoxGame extends StatefulWidget {
  final GameSessionController controller;
  const SleepyFoxGame({super.key, required this.controller});

  @override
  State<SleepyFoxGame> createState() => _SleepyFoxGameState();
}

class _SleepyFoxGameState extends State<SleepyFoxGame>
    with SingleTickerProviderStateMixin<SleepyFoxGame>, GameLoop<SleepyFoxGame> {
  static const _friends = ['\u{1F430}', '\u{1F43B}', '\u{1F425}'];
  static const double _gapSec = 0.6;

  late final FoxParams _p;
  late final List<bool> _seq;
  final _rand = Random(31);
  int _i = -1;
  _Phase _phase = _Phase.gap;
  double _t = 0;
  bool _responded = false;
  String _face = '';
  bool _isFox = false;
  int _done = 0;

  GameSessionController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _p = FoxParams.forLevel(_c.level);
    _seq = FoxLogic.sequence(_p.items, _p.foxShare, _rand);
    _c.setUnits(0, _p.items);
    _c.react(CharacterState.excited, CharacterLines.start(CharacterId.lumi),
        ms: 3000);
    startLoop();
  }

  @override
  void onFrame(double dt) {
    if (_c.completed) return;
    _t += dt;
    if (_phase == _Phase.gap) {
      if (_t >= _gapSec) _showNext();
    } else if (_t >= _p.stimSec) {
      _resolve(tapped: false);
    }
  }

  void _showNext() {
    _i++;
    if (_i >= _p.items) {
      _c.finishLine = CharacterLines.completion(CharacterId.lumi);
      _c.complete();
      stopLoop();
      return;
    }
    setState(() {
      _phase = _Phase.showing;
      _t = 0;
      _responded = false;
      _isFox = _seq[_i];
      _face = _isFox ? '\u{1F98A}' : _friends[_rand.nextInt(_friends.length)];
    });
  }

  void _resolve({required bool tapped}) {
    if (_responded) return;
    _responded = true;
    if (tapped) {
      _c.recordTouch();
      if (_isFox) {
        _c.recordMistake();
        _c.recordTagged('commission');
        GameAudio.tap();
        _c.react(CharacterState.encouraging, 'Shh, the fox is sleeping!',
            ms: 1500);
      } else {
        _c.recordResponse((_t * 1000).round());
        _c.recordSuccess();
        GameAudio.success();
        _c.react(CharacterState.happy, 'Hello, friend!', ms: 900);
      }
    } else {
      if (_isFox) {
        _c.recordSuccess(); // waited quietly
        _c.react(CharacterState.calm, 'Nice and quiet. Zzz...', ms: 1200);
      } else {
        _c.recordTagged('omission');
      }
    }
    _done++;
    _c.setUnits(_done, _p.items);
    setState(() {
      _phase = _Phase.gap;
      _t = 0;
    });
  }

  void _tapButton() {
    if (_c.completed) return;
    if (_phase == _Phase.showing) {
      _resolve(tapped: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showing = _phase == _Phase.showing;
    return Stack(
      children: [
        // Static night meadow. Identical on every trial, go and no-go alike,
        // and deliberately not animated -- see the note at the top of the file.
        const Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _MeadowPainter()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2E4A),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                      color: const Color(0x33FFFFFF), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 14)
                  ],
                ),
                child: const Text(
                  '\u{1F430} Tap friends    \u{1F98A}\u{1F4A4} Let the fox sleep',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The pool of lantern light the creature stands in.
                        // Drawn for BOTH trial types, unchanged between them.
                        const RepaintBoundary(
                          child: CustomPaint(
                            size: Size(260, 260),
                            painter: _ClearingPainter(),
                          ),
                        ),
                        // The stimulus itself: untouched from v36.
                        AnimatedScale(
                          duration: const Duration(milliseconds: 180),
                          scale: showing ? 1 : 0.2,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: showing ? 1 : 0,
                            child: Text(
                              _isFox ? '\u{1F98A}\u{1F4A4}' : _face,
                              style: const TextStyle(fontSize: 120),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _tapButton,
                child: Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFC978), Color(0xFFF2993C)],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                        color: const Color(0x66FFFFFF), width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 16,
                          offset: Offset(0, 6))
                    ],
                  ),
                  child: const Center(
                    child: Text('TAP!',
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3A2206),
                            letterSpacing: 2)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A still night meadow: deep sky, moon, fixed stars, layered hills and a
/// grass fringe. Nothing here moves and nothing here depends on the trial.
class _MeadowPainter extends CustomPainter {
  const _MeadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1C2E52),
            Color(0xFF32507D),
            Color(0xFF5E7FA8),
          ],
          stops: [0.0, 0.52, 1.0],
        ).createShader(rect),
    );

    // Moon, with a soft halo.
    final moon = Offset(w * 0.80, h * 0.14);
    canvas.drawCircle(
        moon, h * 0.10, Paint()..color = const Color(0x22FFF4CF));
    canvas.drawCircle(
        moon, h * 0.065, Paint()..color = const Color(0x3DFFF4CF));
    canvas.drawCircle(moon, h * 0.042, Paint()..color = const Color(0xFFFFF6DC));

    // Fixed stars. Seeded, so the sky is the same every session.
    final r = Random(7);
    final star = Paint()..color = const Color(0xCCFFFFFF);
    for (var i = 0; i < 46; i++) {
      final x = r.nextDouble() * w;
      final y = r.nextDouble() * h * 0.55;
      canvas.drawCircle(Offset(x, y), 0.7 + r.nextDouble() * 1.5,
          star..color = Color.fromRGBO(255, 255, 255, 0.35 + r.nextDouble() * 0.5));
    }

    // Two hill bands, back to front. A simple run of alternating humps.
    void hill(double top, double amp, Color c) {
      const steps = 8;
      final span = w / steps;
      final p = Path()
        ..moveTo(0, h)
        ..lineTo(0, top);
      for (var i = 0; i < steps; i++) {
        final x = i * span;
        final rise = i.isEven ? amp : amp * 0.55;
        p.quadraticBezierTo(x + span / 2, top - rise, x + span, top);
      }
      p
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(p, Paint()..color = c);
    }

    hill(h * 0.62, h * 0.055, const Color(0xFF2F5D56));
    hill(h * 0.74, h * 0.040, const Color(0xFF27514C));

    // Grass fringe along the very bottom.
    final blade = Paint()..color = const Color(0xFF1E423E);
    for (var x = -10.0; x < w + 10; x += 13) {
      final p = Path()
        ..moveTo(x, h)
        ..quadraticBezierTo(x + 5, h - 26, x + 11, h)
        ..close();
      canvas.drawPath(p, blade);
    }
  }

  @override
  bool shouldRepaint(covariant _MeadowPainter oldDelegate) => false;
}

/// The lit clearing the creature appears in. Identical for friends and fox.
class _ClearingPainter extends CustomPainter {
  const _ClearingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    canvas.drawCircle(
      c,
      size.width * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x40FFE9B8), Color(0x00FFE9B8)],
        ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.46)),
    );

    // A low grassy mound so the creature is standing on something.
    final mound = Rect.fromCenter(
        center: Offset(c.dx, size.height * 0.80),
        width: size.width * 0.72,
        height: size.height * 0.26);
    canvas.drawOval(mound, Paint()..color = const Color(0xFF2B5A52));
    canvas.drawOval(mound.deflate(size.width * 0.045),
        Paint()..color = const Color(0xFF336B61));
  }

  @override
  bool shouldRepaint(covariant _ClearingPainter oldDelegate) => false;
}
