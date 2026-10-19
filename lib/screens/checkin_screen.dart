import 'package:flutter/material.dart';
import '../characters/avatar.dart';
import '../characters/avatar_painter.dart';
import '../characters/buddy.dart';
import '../characters/friend_view.dart';
import '../characters/mindy_character.dart';
import '../services/avatar_service.dart';
import '../models/emotion_state.dart';
import '../models/study_condition.dart';
import '../services/emotion_signal_client.dart';
import '../services/app_settings.dart';
import '../services/journey_controller.dart';
import '../services/kara_status.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';
import '../widgets/emotion_picker.dart';
import '../widgets/sky_background.dart';

/// SENSE. Mindy asks "How are you feeling today?" and the five emotion
/// creatures answer. Picking one makes the whole screen take on that
/// emotion's atmosphere; the child confirms with one big button.
///
/// Stored: emotion, source, check-in duration, previous emotion (via the
/// journey). If KARA (or a clearly-labelled simulated signal) has a fresh
/// report it is offered first; otherwise the source is simply APP. The app
/// never pretends a robot signal exists.
class CheckinScreen extends StatefulWidget {
  /// Called after the decision has been made and saved.
  final VoidCallback onDecided;
  const CheckinScreen({super.key, required this.onDecided});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen>
    with SingleTickerProviderStateMixin {
  final Stopwatch _watch = Stopwatch()..start();
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  EmotionState? _picked;
  RobotCheckin? _robot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRobot();
  }

  Future<void> _loadRobot() async {
    final c = await KaraStatusService.instance.fetchRecent();
    if (mounted) setState(() => _robot = c);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Future<void> _confirm(EmotionState? emotion, EmotionSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ms = _watch.elapsedMilliseconds;
    // Report to the optional backend; never blocks and never fails loudly.
    EmotionSignalClient.current()
        .postCheckin(AppSettings.instance.childId, emotion, source)
        .catchError((_) => false);
    await JourneyController.instance
        .beginFromCheckIn(emotion: emotion, source: source, checkInMs: ms);
    if (mounted) widget.onDecided();
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: picked == null ? _grid() : _selected(picked),
      ),
    );
  }

  // ---------------------------------------------------------- stage 1

  Widget _grid() {
    return SkyBackground(
      key: const ValueKey('grid'),
      colors: AppColors.rainbowSky,
      showStars: false,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              // The feeling check-in is between the child and their own
              // friend, so the friend asks.
              const FriendView(size: 110),
              const SizedBox(height: 6),
              MindySpeechBubble(
                  text: LanguageService.instance.tr('greeting'), fontSize: 19),
              const SizedBox(height: 18),
              if (_robot != null) _robotCard(_robot!),
              if (_robot != null) const SizedBox(height: 14),
              EmotionPicker(onSelected: (e) => setState(() => _picked = e)),
              const SizedBox(height: 14),
              TextButton(
                onPressed:
                    _busy ? null : () => _confirm(null, EmotionSource.app),
                child: Text(
                  LanguageService.instance.tr('checkin.rather'),
                  style: AppText.body.copyWith(
                    color: AppColors.inkNavy.withValues(alpha: 0.65),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _robotCard(RobotCheckin r) {
    final label = r.simulated ? 'KARA (test signal)' : 'KARA';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadii.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Text('$label noticed you might feel ${r.emotion.label.toLowerCase()}.',
              textAlign: TextAlign.center,
              style: AppText.subheading),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _busy ? null : () => _confirm(r.emotion, r.source),
                child: const Text("Yes, that's right"),
              ),
              TextButton(
                onPressed: () => setState(() => _robot = null),
                child: const Text("No, I'll choose"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- stage 2

  Widget _selected(EmotionState e) {
    final pal = e.palette;
    return Stack(
      key: ValueKey('selected-${e.name}'),
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _clock,
          builder: (_, __) => CustomPaint(
            painter: EmotionBackdropPainter(e, _clock.value),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) =>
                        Transform.scale(scale: t, child: child),
                    // v49: the confirm step showed a creature while the
                    // cards behind it showed the child's own friend. Same
                    // friend, same face as the card they just tapped.
                    child: AnimatedBuilder(
                      animation: AvatarService.instance,
                      builder: (_, __) => AvatarView(
                        AvatarService.instance.active.copyWith(
                          face: AvatarOptions.faceForEmotionIndex[
                              e.index.clamp(
                                  0,
                                  AvatarOptions.faceForEmotionIndex.length -
                                      1)],
                        ),
                        size: 190,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Text(e.displaySentence,
                        textAlign: TextAlign.center,
                        style: AppText.heading.copyWith(color: pal.ink)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 280,
                    height: 66,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pal.accent,
                        foregroundColor: pal.ink,
                      ),
                      onPressed:
                          _busy ? null : () => _confirm(e, EmotionSource.app),
                      child: Text(LanguageService.instance.tr('checkin.thatsMe')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _picked = null),
                    child: Text(LanguageService.instance.tr('checkin.pickAgain'),
                        style: AppText.body.copyWith(
                            color: pal.ink,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
