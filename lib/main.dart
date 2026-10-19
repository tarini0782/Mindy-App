import 'dart:async';
import 'package:flutter/material.dart';
import 'characters/character_assets.dart';
import 'screens/auth_screen.dart';
import 'screens/children_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/friend_onboarding_screen.dart';
import 'screens/game_library_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parent_hub_screen.dart';
import 'screens/calm_quest_screen.dart';
import 'services/account_service.dart';
import 'services/app_settings.dart';
import 'services/diagnostics_service.dart';
import 'services/journey_controller.dart';
import 'services/calm_service.dart';
import 'feed/feed_log_service.dart';
import 'screens/feed_screen.dart';
import 'services/reward_service.dart';
import 'services/session_repository.dart';
import 'services/sync_service.dart';
import 'services/usability_service.dart';
import 'services/language_service.dart';
import 'services/worry_service.dart';
import 'services/support_plan_service.dart';
import 'services/insight_summary_service.dart';
import 'services/avatar_service.dart';
import 'theme/app_theme.dart';

/// Runs one startup step. A failing or hanging step is recorded and skipped so
/// the app always reaches runApp (a blank screen is never the outcome).
Future<void> _step(String name, Future<void> Function() f) async {
  try {
    await f().timeout(const Duration(seconds: 8));
  } catch (e, st) {
    debugPrint('MINDY STARTUP STEP FAILED: $name -> $e');
    DiagnosticsService.instance.record('startup:$name: $e', st);
  }
}

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      DiagnosticsService.instance.record(details.exception, details.stack);
    };

    // Offline-first startup: everything below works with no network. Each
    // loader catches its own errors, so a storage problem can never stop
    // the app from opening.
    await _step('diagnostics', () => DiagnosticsService.instance.load());
    await _step('settings', () => AppSettings.instance.load());
    await _step('language', () => LanguageService.instance.load());
    await _step('sessions', () => SessionRepository.instance.load());
    await _step('observations', () => ObservationRepository.instance.load());
    await _step('journey', () => JourneyController.instance.load());
    // Per-child data scoping. The hooks run on login, logout, child switch,
    // consent change and deletion.
    AccountService.instance.onActiveChildChanged = (child) async {
      SessionRepository.instance
          .setActiveChild(child?.participantId ?? '__no_active_child__');
      if (child != null) AppSettings.instance.setActiveChildId(child.participantId);
      await JourneyController.instance.switchChild(child?.participantId);
      await CalmService.instance.load(child?.participantId);
      await FeedLogService.instance.load(child?.participantId);
      await UsabilityService.instance.load(child?.participantId);
      await WorryService.instance.load(child?.participantId);
      await SupportPlanService.instance.load(child?.participantId);
      // v28: each child has their own saved characters, so switching child
      // switches character and never shows one child's to another.
      await AvatarService.instance.load(child?.participantId ?? 'default');
      InsightSummaryService.instance.reset();
      RewardService.instance.rebuild(SessionRepository.instance.chronological);
    };
    AccountService.instance.onChildDeleted = (child) async {
      await SessionRepository.instance.deleteForChild(child.participantId);
      await JourneyController.instance.deleteFor(child.participantId);
      await CalmService.instance.deleteForChild(child.participantId);
      await FeedLogService.instance.deleteForChild(child.participantId);
      await UsabilityService.instance.deleteForChild(child.participantId);
      await WorryService.instance.deleteForChild(child.participantId);
      await SupportPlanService.instance.deleteForChild(child.participantId);
    };
    await _step('account', () => AccountService.instance.load());
    await _step('assets', () => CharacterAssets.init());
    ErrorWidget.builder = (details) => Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text('Mindy hit a problem showing this screen:\n\n${details.exceptionAsString()}',
                  style: const TextStyle(color: Colors.black87, fontSize: 13)),
            ),
          ),
        );
    runApp(const MindyApp());
    SyncService.instance.trigger(); // best effort, never blocks
  }, (error, stack) {
    DiagnosticsService.instance.record(error, stack);
  });
}

class MindyApp extends StatelessWidget {
  const MindyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilt from the top when the language changes (key), so every
    // child-facing label picks up the new language.
    return AnimatedBuilder(
      animation: LanguageService.instance,
      builder: (context, _) => MaterialApp(
        key: ValueKey(LanguageService.instance.lang),
        title: 'Mindy',
        debugShowCheckedModeBanner: false,
        theme: buildMindyTheme(),
        home: const AuthGate(),
      ),
    );
  }
}

/// A deliberately simple "grown-up check". It keeps very young children out
/// of caregiver areas; it is NOT security.
Future<bool> _confirmParentGate(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      title: const Text('Parents & Caregivers'),
      content: const Text(
          'This area is for grown-ups.\n\nWhat is 8 + 5?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('12')),
        ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('13')),
      ],
    ),
  );
  return result ?? false;
}

/// Sign in -> choose child -> consent answered -> app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      // Also listens to AvatarService so that finishing or skipping the
      // first-run friend flow swaps this gate over on its own.
      animation: Listenable.merge(
          [AccountService.instance, AvatarService.instance]),
      builder: (context, _) {
        final a = AccountService.instance;
        if (!a.loggedIn) return const AuthScreen();
        final child = a.activeChild;
        if (child == null) return const ChildrenScreen();
        if (!child.consentAnswered) return ConsentScreen(child: child);
        // First run for this child: make a friend before anything else.
        // Skippable, and never shown again once seen.
        if (AvatarService.instance.needsOnboarding) {
          return FriendOnboardingScreen(onDone: () {});
        }
        return const RootShell();
      },
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // Tabs: 0 Home, 1 Feed, 2 Calm Quest (therapeutic gaming), 3 Games, 4 Grown-ups (behind the grown-up check).
  static const _gated = {4};

  Future<void> _select(int i) async {
    if (_gated.contains(i)) {
      final ok = await _confirmParentGate(context);
      if (!ok || !mounted) return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        onStartAdventure: () => CalmQuestScreen.start(context),
        onAllGames: () => setState(() => _index = 3),
      ),
      FeedScreen(active: _index == 1),
      const CalmQuestScreen(),
      const GameLibraryScreen(),
      const ParentHubScreen(),
    ];
    final demo = AccountService.instance.activeChild?.isDemo ?? false;
    return Scaffold(
      body: Column(children: [
        if (demo)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFE082),
            padding: EdgeInsets.fromLTRB(
                8, MediaQuery.of(context).padding.top + 2, 8, 2),
            child: const Text('DEMO \u2013 NOT REAL PARTICIPANT DATA (stays on this device)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87)),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: demo,
            child: IndexedStack(index: _index, children: screens),
          ),
        ),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_rounded),
              label: LanguageService.instance.tr('nav.home')),
          NavigationDestination(
              icon: const Icon(Icons.swipe_vertical_rounded),
              label: LanguageService.instance.tr('nav.feed')),
          NavigationDestination(
              icon: const Icon(Icons.spa_rounded),
              label: LanguageService.instance.lang == AppLang.en
                  ? 'Calm Quest'
                  : LanguageService.instance.tr('nav.adventure')),
          NavigationDestination(
              icon: const Icon(Icons.sports_esports_rounded),
              label: LanguageService.instance.tr('nav.games')),
          NavigationDestination(
              icon: const Icon(Icons.family_restroom_rounded),
              label: LanguageService.instance.tr('nav.grownups')),
        ],
      ),
    );
  }
}
