import 'package:flutter/material.dart';
import '../characters/character_lines.dart';
import '../characters/friend_view.dart';
import '../characters/mindy_character.dart';
import '../services/account_service.dart';
import '../services/journey_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/sky_background.dart';
import 'checkin_screen.dart';
import 'journey_screen.dart';

/// The child's "Play" tab. It shows exactly ONE of:
///   * the emotion check-in      (no decision yet, or the decision is stale)
///   * the adventure map          (a pending decision exists)
///   * "Mindy is choosing..."      (a moment between activities)
///   * the journey-complete celebration
class PlayFlow extends StatefulWidget {
  const PlayFlow({super.key});

  @override
  State<PlayFlow> createState() => _PlayFlowState();
}

class _PlayFlowState extends State<PlayFlow> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([JourneyController.instance, AccountService.instance]),
      builder: (context, _) {
        final child = AccountService.instance.activeChild;
        if (child != null && !child.researchEnabled) {
          return const _ResearchOff();
        }
        final j = JourneyController.instance;
        if (j.journeyComplete) {
          return _JourneyComplete(
            onNew: () async {
              await JourneyController.instance.startNewJourney();
            },
          );
        }
        if (j.needsCheckIn()) {
          return CheckinScreen(onDecided: () => setState(() {}));
        }
        if (j.awaitingDecision && j.pending == null) {
          return const _Thinking();
        }
        return const JourneyScreen();
      },
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackground(
        colors: AppColors.rainbowSky,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FriendView(size: 140),
              SizedBox(height: 12),
              MindySpeechBubble(text: 'Mindy is choosing your next adventure...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyComplete extends StatelessWidget {
  final VoidCallback onNew;
  const _JourneyComplete({required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SkyBackground(
        colors: AppColors.rainbowSky,
        showStars: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('\u{1F31F}', style: TextStyle(fontSize: 72)),
                  const FriendView(size: 150),
                  const SizedBox(height: 10),
                  const MindySpeechBubble(
                      text: CharacterLines.journeyDone, fontSize: 19),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 300,
                    height: 66,
                    child: ElevatedButton(
                      onPressed: onNew,
                      child: const Text('Start a new adventure'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of the research Adventure when consent / assent is "no".
/// Nothing is saved for research; every game is still playable.
class _ResearchOff extends StatelessWidget {
  const _ResearchOff();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FriendView(size: 96),
                  SizedBox(height: 12),
                  Text('Free play!',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  SizedBox(height: 10),
                  Text(
                      'Research play is switched off for this profile, so nothing is saved. '
                      'Open the Games tab to play any game.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      );
}
