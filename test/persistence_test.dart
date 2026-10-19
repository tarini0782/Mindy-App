import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/engine/adaptive_game_engine.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/models/caregiver_observation.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/models/study_condition.dart';
import 'package:mindy_app/services/app_settings.dart';
import 'package:mindy_app/services/journey_controller.dart';
import 'package:mindy_app/services/reward_service.dart';
import 'package:mindy_app/services/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionRepository.instance.clear();
    await ObservationRepository.instance.clear();
    await JourneyController.instance.reset();
    JourneyController.instance.awaitingDecision = false;
    await AppSettings.instance.load();
    await AppSettings.instance.setCondition(StudyCondition.adaptive);
  });

  group('session persistence (survives a restart)', () {
    test('a stored session reloads with every research field', () async {
      final s = makeSession(GameType.bubbleValley,
          level: 2,
          before: EmotionState.sad,
          after: EmotionState.calm,
          successes: 7,
          mistakes: 3,
          pauses: 1,
          playAgain: true,
          avgMs: 1500,
          sdMs: 300);
      await SessionRepository.instance.add(s);
      // "Restart": drop memory and read back from storage.
      await SessionRepository.instance.load();
      final back = SessionRepository.instance.chronological.single;
      expect(back.sessionId, s.sessionId);
      expect(back.game, GameType.bubbleValley);
      expect(back.level, 2);
      expect(back.emotionBefore, EmotionState.sad);
      expect(back.emotionAfter, EmotionState.calm);
      expect(back.moodDelta, 2);
      expect(back.accuracy, closeTo(0.7, 1e-9));
      expect(back.avgResponseMs, 1500);
      expect(back.responseTimeVariabilityMs, 300);
      expect(back.pausedCount, 1);
      expect(back.playAgain, true);
      expect(back.trace.humanReason, s.trace.humanReason);
      expect(back.trace.scores.length, s.trace.scores.length);
    });

    test('post-session mood saved later is persisted', () async {
      final s = makeSession(GameType.breathingGarden,
          level: 1, before: EmotionState.scared, successes: 0, mistakes: 0);
      await SessionRepository.instance.add(s);
      s.emotionAfter = EmotionState.calm;
      await SessionRepository.instance.update(s);
      await SessionRepository.instance.load();
      expect(SessionRepository.instance.chronological.single.emotionAfter,
          EmotionState.calm);
      expect(SessionRepository.instance.chronological.single.moodDelta, 3); // scared(1) -> calm(4)
    });

    test('an incomplete (abandoned) session is stored as incomplete', () async {
      final s = makeSession(GameType.memoryCastle, completed: false, interactions: 2);
      await SessionRepository.instance.add(s);
      await SessionRepository.instance.load();
      final back = SessionRepository.instance.chronological.single;
      expect(back.completed, isFalse);
      expect(back.completionPercent < 1.0, isTrue);
    });

    test('adding the same session twice does not duplicate it', () async {
      final s = makeSession(GameType.bubbleValley);
      await SessionRepository.instance.add(s);
      await SessionRepository.instance.add(s);
      expect(SessionRepository.instance.chronological.length, 1);
    });

    test('caregiver observations persist', () async {
      await ObservationRepository.instance.add(CaregiverObservation(
          id: 'o', timestamp: DateTime(2026, 3, 3), type: ObservationType.sad, note: 'n'));
      await ObservationRepository.instance.load();
      expect(ObservationRepository.instance.chronological.single.type, ObservationType.sad);
    });

    test('corrupt stored data does not crash loading', () async {
      SharedPreferences.setMockInitialValues({'mindy_sessions_v7': '{not json'});
      await SessionRepository.instance.load();
      expect(SessionRepository.instance.chronological, isEmpty);
    });
  });

  group('settings persist', () {
    test('audio, condition and participant code survive a reload', () async {
      await AppSettings.instance.setMusic(false);
      await AppSettings.instance.setSfx(false);
      await AppSettings.instance.setCondition(StudyCondition.fixedBaseline);
      await AppSettings.instance.setParticipantCode('P007');
      final id = AppSettings.instance.childId;
      await AppSettings.instance.load();
      expect(AppSettings.instance.musicOn, isFalse);
      expect(AppSettings.instance.sfxOn, isFalse);
      expect(AppSettings.instance.condition, StudyCondition.fixedBaseline);
      expect(AppSettings.instance.participantCode, 'P007');
      expect(AppSettings.instance.childId, id); // random id is stable
      expect(AppSettings.instance.exportParticipantId, 'P007');
      await AppSettings.instance.setMusic(true);
      await AppSettings.instance.setSfx(true);
    });
  });

  group('journey: sequential, persisted, no bypass', () {
    test('check-in creates ONE pending decision that survives a restart', () async {
      final rec = await JourneyController.instance.beginFromCheckIn(
          emotion: EmotionState.sad, source: EmotionSource.app, checkInMs: 1200);
      expect(JourneyController.instance.needsCheckIn(), isFalse);
      expect(JourneyController.instance.pending!.gameType, rec.gameType);

      JourneyController.instance.state = null; // app closed
      await JourneyController.instance.load(); // app reopened
      final s = JourneyController.instance.state!;
      expect(s.pending!.gameType, rec.gameType);
      expect(s.pending!.level, rec.level);
      expect(s.pendingCheckInMs, 1200);
      expect(s.pendingEmotion, EmotionState.sad);
      expect(s.pendingSource, EmotionSource.app);
      expect(s.pending!.trace.humanReason, rec.trace.humanReason);
    });

    test('a stale decision asks how the child feels again', () async {
      await JourneyController.instance.beginFromCheckIn(
          emotion: EmotionState.calm, source: EmotionSource.app, checkInMs: 800);
      final later = DateTime.now().add(const Duration(hours: 4));
      expect(JourneyController.instance.needsCheckIn(now: later), isTrue);
      expect(JourneyController.instance.needsCheckIn(), isFalse);
    });

    test('no journey yet means a check-in is required', () {
      expect(JourneyController.instance.needsCheckIn(), isTrue);
    });

    test('finishing activities advances the journey and then completes it', () async {
      await JourneyController.instance.beginFromCheckIn(
          emotion: EmotionState.neutral, source: EmotionSource.app, checkInMs: 500);
      for (var i = 0; i < AdaptiveGameEngine.journeyLength; i++) {
        expect(JourneyController.instance.journeyComplete, isFalse);
        final s = makeSession(GameType.bubbleValley,
            before: EmotionState.neutral, after: EmotionState.happy);
        await SessionRepository.instance.add(s);
        await JourneyController.instance.recordCompletion(s);
        expect(JourneyController.instance.completedCount, i + 1);
        if (i + 1 < AdaptiveGameEngine.journeyLength) {
          await JourneyController.instance.decideNext(session: s, after: EmotionState.happy);
          expect(JourneyController.instance.pending, isNotNull);
          // The next decision follows the engine, one step at a time.
          expect(JourneyController.instance.pending!.trace.journeyStep, i + 1);
        }
      }
      expect(JourneyController.instance.journeyComplete, isTrue);
      expect(JourneyController.instance.pending, isNull);
    });

    test('leaving early does NOT count as a step and triggers a fresh decision', () async {
      await JourneyController.instance.beginFromCheckIn(
          emotion: EmotionState.neutral, source: EmotionSource.app, checkInMs: 500);
      final first = JourneyController.instance.pending!;
      final s = makeSession(first.gameType,
          before: EmotionState.neutral, after: null, completed: false, interactions: 1);
      await SessionRepository.instance.add(s);
      await JourneyController.instance.recordAbandon(s);
      expect(JourneyController.instance.completedCount, 0);
      expect(JourneyController.instance.pending, isNull);
      await JourneyController.instance.decideNext(session: s);
      final next = JourneyController.instance.pending!;
      expect(next.trace.previousActivity, first.gameType.id);
      expect(next.trace.recovery, isTrue); // poor response is not repeated blindly
      expect(next.gameType == first.gameType, isFalse);
    });

    test('the next decision uses the post-activity emotion', () async {
      await JourneyController.instance.beginFromCheckIn(
          emotion: EmotionState.sad, source: EmotionSource.app, checkInMs: 700);
      final first = JourneyController.instance.pending!;
      final s = makeSession(first.gameType,
          level: 1, before: EmotionState.sad, after: EmotionState.calm,
          successes: 0, mistakes: 0);
      await SessionRepository.instance.add(s);
      await JourneyController.instance.recordCompletion(s);
      await JourneyController.instance.decideNext(session: s, after: EmotionState.calm);
      final next = JourneyController.instance.pending!;
      expect(next.trace.emotion, 'CALM');
      expect(next.trace.emotionSource, 'APP');
      expect(next.trace.recentMoodChange, 'improved');
    });

    test('the study condition in force is stamped on the decision', () async {
      await AppSettings.instance.setCondition(StudyCondition.fixedBaseline);
      final r = await JourneyController.instance.beginFromCheckIn(
          emotion: EmotionState.scared, source: EmotionSource.app, checkInMs: 300);
      expect(r.trace.condition, 'FIXED_BASELINE');
      expect(r.level, AdaptiveGameEngine.fixedLevel);
    });
  });

  group('rewards are derived from stored sessions', () {
    test('rebuild gives the same totals as awarding one by one', () {
      final list = [
        makeSession(GameType.breathingGarden, successes: 0, mistakes: 0),
        makeSession(GameType.bubbleValley),
        makeSession(GameType.breathingGarden, successes: 0, mistakes: 0),
        makeSession(GameType.memoryCastle, completed: false, interactions: 5),
      ];
      RewardService.instance.clear();
      for (final s in list) {
        RewardService.instance.award(s);
      }
      final stars = RewardService.instance.stars;
      final flowers = RewardService.instance.flowers;
      RewardService.instance.rebuild(list);
      expect(RewardService.instance.stars, stars);
      expect(RewardService.instance.flowers, flowers);
      // 4 (first breathing) + 4 (first bubble) + 3 (repeat) + 1 (tried) = 12
      expect(stars, 12);
    });

    test('rewards ignore accuracy and speed', () {
      final good = makeSession(GameType.bubbleValley, successes: 10, mistakes: 0, avgMs: 400);
      final shaky = makeSession(GameType.bubbleValley, successes: 2, mistakes: 8, avgMs: 5000);
      RewardService.instance.clear();
      final a = RewardService.instance.award(good).stars;
      RewardService.instance.clear();
      final b = RewardService.instance.award(shaky).stars;
      expect(a, b);
    });
  });
}
