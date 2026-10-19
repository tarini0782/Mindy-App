import 'dart:async';
import 'package:flutter/material.dart';
import '../art/sprites.dart';
import '../characters/friend_view.dart';
import '../characters/mindy_character.dart';
import '../services/calm_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sky_background.dart';

/// A quiet place the child can choose at any time. Two short activities led
/// by Twinkle: a breathing balloon and a "look around" grounding game.
/// No scores, no timers that can be failed, no right answers.
class CalmCornerScreen extends StatefulWidget {
  const CalmCornerScreen({super.key});

  @override
  State<CalmCornerScreen> createState() => _CalmCornerScreenState();
}

enum _Stage { pickFeeling, pickActivity, breathing, grounding, afterFeeling, done }

class _CalmCornerScreenState extends State<CalmCornerScreen> {
  _Stage _stage = _Stage.pickFeeling;
  int _before = 0;
  int _after = 0;
  String _activity = 'breathing';
  final Stopwatch _watch = Stopwatch();

  void _start(String activity) {
    _activity = activity;
    _watch.reset();
    _watch.start();
    setState(() => _stage = activity == 'breathing' ? _Stage.breathing : _Stage.grounding);
  }

  void _finishActivity() {
    _watch.stop();
    setState(() => _stage = _Stage.afterFeeling);
  }

  Future<void> _save() async {
    await CalmService.instance.add(CalmVisit(
      at: DateTime.now(),
      activity: _activity,
      seconds: _watch.elapsed.inSeconds,
      feelingBefore: _before,
      feelingAfter: _after,
    ));
    if (mounted) setState(() => _stage = _Stage.done);
  }

  Widget _feelingRow(void Function(int) onPick) {
    Widget face(int v, String label, Color c) => GestureDetector(
          key: Key('calm_feel_$v'),
          onTap: () => onPick(v),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                  color: c, shape: BoxShape.circle, boxShadow: AppShadows.soft),
              child: Center(
                child: Text(v == 1 ? '\u{1F61F}' : (v == 2 ? '\u{1F610}' : '\u{1F642}'),
                    style: const TextStyle(fontSize: 44)),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
        );
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      face(1, 'Not good', const Color(0xFFFFC6B8)),
      face(2, 'Okay', const Color(0xFFFFE9A8)),
      face(3, 'Good', const Color(0xFFBDF0C8)),
    ]);
  }

  Widget _bigButton(String text, VoidCallback onTap, {Key? key}) => SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(key: key, onPressed: onTap, child: Text(text, style: const TextStyle(fontSize: 20))),
      );

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_stage) {
      case _Stage.pickFeeling:
        body = _Page(
          say: 'Hi, I am Twinkle. How are you right now?',
          child: _feelingRow((v) => setState(() {
                _before = v;
                _stage = _Stage.pickActivity;
              })),
        );
        break;
      case _Stage.pickActivity:
        body = _Page(
          say: 'Let\'s have a quiet moment together. Pick one.',
          child: Column(children: [
            _bigButton('Breathe with the balloon', () => _start('breathing'),
                key: const Key('calm_pick_breathing')),
            const SizedBox(height: 14),
            _bigButton('Look around game', () => _start('grounding'),
                key: const Key('calm_pick_grounding')),
          ]),
        );
        break;
      case _Stage.breathing:
        body = _BreathingBalloon(onDone: _finishActivity);
        break;
      case _Stage.grounding:
        body = _Grounding(onDone: _finishActivity);
        break;
      case _Stage.afterFeeling:
        body = _Page(
          say: 'Well done for taking a moment. How are you now?',
          child: _feelingRow((v) {
            _after = v;
            _save();
          }),
        );
        break;
      case _Stage.done:
        body = _Page(
          say: 'Thank you. You can come back any time you like.',
          child: _bigButton('Back to play', () => Navigator.of(context).maybePop(),
              key: const Key('calm_done')),
        );
        break;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calm Corner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: SkyBackground(
        colors: AppColors.skyMorning,
        showStars: true,
        child: SafeArea(child: body),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final String say;
  final Widget child;
  const _Page({required this.say, required this.child});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
        children: [
          Row(children: [
            // v49: was a hardcoded Twinkle. The Calm Corner is a quiet
            // moment between the child and their own friend, so the
            // friend sits with them here like everywhere else.
            const FriendView(size: 86),
            const SizedBox(width: 8),
            Expanded(child: MindySpeechBubble(text: say, fontSize: 19, maxWidth: 260)),
          ]),
          const SizedBox(height: 28),
          child,
        ],
      );
}

/// A balloon that grows while the child breathes in and shrinks while they
/// breathe out. 4 seconds each way, 5 rounds. Slower is never "wrong".
class _BreathingBalloon extends StatefulWidget {
  final VoidCallback onDone;
  const _BreathingBalloon({required this.onDone});

  @override
  State<_BreathingBalloon> createState() => _BreathingBalloonState();
}

class _BreathingBalloonState extends State<_BreathingBalloon>
    with SingleTickerProviderStateMixin {
  static const int rounds = 5;
  late final AnimationController _ctl;
  int _round = 0;
  bool _breathingIn = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _ctl.addStatusListener((s) {
      if (!mounted || _finished) return;
      if (s == AnimationStatus.completed) {
        setState(() => _breathingIn = false);
        _ctl.reverse();
      } else if (s == AnimationStatus.dismissed) {
        if (_round + 1 >= rounds) {
          _finished = true;
          widget.onDone();
        } else {
          setState(() {
            _round++;
            _breathingIn = true;
          });
          _ctl.forward();
        }
      }
    });
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final maxD = (h * 0.34).clamp(160.0, 300.0);
    return Column(children: [
      const SizedBox(height: 70),
      Text(_breathingIn ? 'Breathe in…' : 'Breathe out…',
          key: const Key('calm_breath_label'),
          style: AppText.heading.copyWith(fontSize: 30)),
      Text('${_round + 1} of $rounds', style: AppText.body),
      Expanded(
        child: Center(
          child: AnimatedBuilder(
            animation: _ctl,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_ctl.value);
              final d = maxD * (0.45 + 0.55 * t);
              return Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Colors.white.withValues(alpha: 0.95),
                    const Color(0xFFFF9EC7),
                  ]),
                  boxShadow: AppShadows.soft,
                ),
                child: Center(child: Sprite('heart', width: d * 0.3, height: d * 0.3)),
              );
            },
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: TextButton(
          key: const Key('calm_breath_skip'),
          onPressed: () {
            if (_finished) return;
            _finished = true;
            widget.onDone();
          },
          child: const Text('I\'m done'),
        ),
      ),
    ]);
  }
}

/// "5 things I can see" style game. Tap each bubble as you find that kind of
/// thing in the real room. The app cannot check the answer, by design.
class _Grounding extends StatefulWidget {
  final VoidCallback onDone;
  const _Grounding({required this.onDone});

  @override
  State<_Grounding> createState() => _GroundingState();
}

class _GroundingState extends State<_Grounding> {
  static const List<_GStep> steps = [
    _GStep('Find 3 things you can SEE', 'star', 3),
    _GStep('Find 2 things you can HEAR', 'note', 2),
    _GStep('Find 1 thing you can TOUCH', 'heart', 1),
  ];
  int _step = 0;
  int _found = 0;

  void _tap() {
    setState(() {
      _found++;
      if (_found >= steps[_step].count) {
        if (_step + 1 >= steps.length) {
          Timer(const Duration(milliseconds: 500), () {
            if (mounted) widget.onDone();
          });
        } else {
          _step++;
          _found = 0;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = steps[_step];
    return _Page(
      say: s.say,
      child: Column(children: [
        Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < s.count; i++)
            GestureDetector(
              key: Key('calm_ground_$i'),
              onTap: i == _found ? _tap : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: i < _found ? 0.25 : 1,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.soft),
                  padding: const EdgeInsets.all(18),
                  child: Sprite(s.sprite, width: 56, height: 56),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 18),
        Text('Tap a bubble each time you find one.', style: AppText.body),
      ]),
    );
  }
}

class _GStep {
  final String say;
  final String sprite;
  final int count;
  const _GStep(this.say, this.sprite, this.count);
}
