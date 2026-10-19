import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../games/engine/adaptive_game_engine.dart';
import '../games/models/game_type.dart';
import '../games/models/game_recommendation.dart';
import '../games/models/game_session.dart';
import '../models/emotion_state.dart';
import '../models/study_condition.dart';
import 'app_settings.dart';
import 'session_repository.dart';

/// The persisted state of "Today's Mindy Adventure": a sequence of
/// [AdaptiveGameEngine.journeyLength] activities chosen one at a time.
///
/// The child never picks the activity: the engine's pending decision is the
/// only playable node. The pending decision is SAVED, so closing and
/// reopening the app cannot "re-roll" it.
class JourneyState {
  final String journeyId;
  final int number; // 1, 2, 3...
  final DateTime startedAt;
  final List<String> completedSessionIds;
  GameRecommendation? pending;
  DateTime? pendingAt;
  EmotionState? pendingEmotion;
  EmotionSource pendingSource;
  int pendingCheckInMs;
  EmotionState? pendingPreviousEmotion;
  bool complete;

  JourneyState({
    required this.journeyId,
    required this.number,
    required this.startedAt,
    List<String>? completedSessionIds,
    this.pending,
    this.pendingAt,
    this.pendingEmotion,
    this.pendingSource = EmotionSource.app,
    this.pendingCheckInMs = 0,
    this.pendingPreviousEmotion,
    this.complete = false,
  }) : completedSessionIds = completedSessionIds ?? [];

  Map<String, dynamic> toJson() => {
        'journeyId': journeyId,
        'number': number,
        'startedAt': startedAt.toIso8601String(),
        'completed': completedSessionIds,
        'pending': pending?.toJson(),
        'pendingAt': pendingAt?.toIso8601String(),
        'pendingEmotion': pendingEmotion?.name,
        'pendingSource': pendingSource.code,
        'pendingCheckInMs': pendingCheckInMs,
        'pendingPreviousEmotion': pendingPreviousEmotion?.name,
        'complete': complete,
      };

  factory JourneyState.fromJson(Map<String, dynamic> j) => JourneyState(
        journeyId: (j['journeyId'] as String?) ?? 'j0',
        number: (j['number'] as num?)?.toInt() ?? 1,
        startedAt: DateTime.tryParse((j['startedAt'] as String?) ?? '') ??
            DateTime.now(),
        completedSessionIds:
            ((j['completed'] as List?) ?? []).map((e) => e.toString()).toList(),
        pending: j['pending'] == null
            ? null
            : GameRecommendation.fromJson(
                Map<String, dynamic>.from(j['pending'] as Map)),
        pendingAt: DateTime.tryParse((j['pendingAt'] as String?) ?? ''),
        pendingEmotion: emotionFromName(j['pendingEmotion'] as String?),
        pendingSource: EmotionSourceX.fromCode(j['pendingSource'] as String?),
        pendingCheckInMs: (j['pendingCheckInMs'] as num?)?.toInt() ?? 0,
        pendingPreviousEmotion:
            emotionFromName(j['pendingPreviousEmotion'] as String?),
        complete: (j['complete'] as bool?) ?? false,
      );
}

class JourneyController extends ChangeNotifier {
  JourneyController._();
  static final JourneyController instance = JourneyController._();

  static const _baseKey = 'mindy_journey_v7';
  String _key = _baseKey;

  /// Each child has their own adventure. Called when the active child changes.
  Future<void> switchChild(String? participantId) async {
    _key = participantId == null ? _baseKey : '${_baseKey}_$participantId';
    state = null;
    await load();
  }

  /// Removes a child's stored adventure (profile deletion).
  Future<void> deleteFor(String participantId) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('${_baseKey}_$participantId');
    } catch (_) {}
  }

  /// A pending decision older than this triggers a fresh check-in, because
  /// the child's feeling may have changed. Journey progress is kept.
  static const Duration staleAfter = Duration(hours: 3);

  JourneyState? state;

  void _notify() => scheduleMicrotask(notifyListeners);

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        state = JourneyState.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      }
    } catch (_) {
      state = null;
    }
    _notify();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (state == null) {
        await p.remove(_key);
      } else {
        await p.setString(_key, jsonEncode(state!.toJson()));
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------ queries

  bool get journeyComplete => state?.complete ?? false;
  int get completedCount => state?.completedSessionIds.length ?? 0;
  GameRecommendation? get pending => state?.pending;

  /// True when Mindy has to ask "How are you feeling today?" before anything
  /// can be offered: no journey, no decision yet, or a stale decision.
  bool needsCheckIn({DateTime? now}) {
    final s = state;
    if (s == null) return true;
    if (s.complete) return false;
    if (awaitingDecision) return false; // Mindy is between two activities
    if (s.pending == null || s.pendingAt == null) return true;
    return (now ?? DateTime.now()).difference(s.pendingAt!) > staleAfter;
  }

  /// The feeling before the next check-in: the last answered feeling.
  EmotionState? get previousEmotionForCheckIn {
    final l = SessionRepository.instance.last;
    return l == null ? null : (l.emotionAfter ?? l.emotionBefore);
  }

  // ------------------------------------------------------------ actions

  Future<void> startNewJourney() async {
    final n = (state?.number ?? 0) + 1;
    state = JourneyState(
      journeyId: 'j${DateTime.now().millisecondsSinceEpoch}',
      number: n,
      startedAt: DateTime.now(),
    );
    _notify();
    await _save();
  }

  /// Activities already finished in the current adventure (no repeats).
  Set<String> _gamesInThisJourney() {
    final ids = state?.completedSessionIds.toSet() ?? <String>{};
    return {
      for (final x in SessionRepository.instance.chronological)
        if (ids.contains(x.sessionId)) x.game.id,
    };
  }

  GameRecommendation _decide(EmotionState? emotion, EmotionSource source) {
    return AdaptiveGameEngine.recommend(
      emotion: emotion,
      source: source,
      condition: AppSettings.instance.condition,
      history: SessionRepository.instance.chronological,
      journeyStep: completedCount,
      avoidIds: _gamesInThisJourney(),
    );
  }

  /// SENSE -> DECIDE: the child (or KARA) reported a feeling.
  Future<GameRecommendation> beginFromCheckIn({
    required EmotionState? emotion,
    required EmotionSource source,
    required int checkInMs,
  }) async {
    if (state == null || state!.complete) await startNewJourney();
    final s = state!;
    final rec = _decide(emotion, source);
    s.pending = rec;
    s.pendingAt = DateTime.now();
    s.pendingEmotion = emotion;
    s.pendingSource = source;
    s.pendingCheckInMs = checkInMs;
    s.pendingPreviousEmotion = previousEmotionForCheckIn;
    _notify();
    await _save();
    return rec;
  }

  /// True between the end of a session and the next decision, so the UI can
  /// show "Mindy is thinking" instead of a check-in screen. Not persisted:
  /// after a restart the child is simply asked how they feel.
  bool awaitingDecision = false;

  /// A session just FINISHED. It counts as a journey step immediately (and
  /// is saved), even if the app is closed before the child answers
  /// "How do you feel now?".
  Future<void> recordCompletion(GameSession session) async {
    final s = state;
    if (s == null) return;
    if (!s.completedSessionIds.contains(session.sessionId)) {
      s.completedSessionIds.add(session.sessionId);
    }
    s.pending = null;
    s.pendingAt = null;
    if (s.completedSessionIds.length >= AdaptiveGameEngine.journeyLength) {
      s.complete = true;
    }
    awaitingDecision = !s.complete;
    _notify();
    await _save();
  }

  /// The child LEFT before finishing. The step does not count; the engine
  /// will choose again (usually a different or gentler activity: recovery).
  Future<void> recordAbandon(GameSession session) async {
    final s = state;
    if (s == null || s.complete) return;
    s.pending = null;
    s.pendingAt = null;
    awaitingDecision = true;
    _notify();
    await _save();
  }

  /// LEARN -> ADAPT: choose the NEXT activity from the updated history.
  /// [after] is the child's "how do you feel now?" answer (null if none).
  Future<void> decideNext({
    required GameSession session,
    EmotionState? after,
    int checkInMs = 0,
  }) async {
    final s = state;
    awaitingDecision = false;
    if (s == null || s.complete) {
      _notify();
      await _save();
      return;
    }
    final answered = after ?? session.emotionAfter;
    final emotionNow = answered ?? session.emotionBefore;
    final source = answered != null
        ? EmotionSource.app
        : EmotionSourceX.fromCode(session.emotionSource);
    final rec = _decide(emotionNow, source);
    s.pending = rec;
    s.pendingAt = DateTime.now();
    s.pendingEmotion = emotionNow;
    s.pendingSource = source;
    s.pendingCheckInMs = checkInMs;
    s.pendingPreviousEmotion = session.emotionBefore;
    _notify();
    await _save();
  }

  /// Settings > reset.
  Future<void> reset() async {
    state = null;
    _notify();
    await _save();
  }
}
