import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../games/models/game_session.dart';
import '../models/caregiver_observation.dart';

/// Local, persistent store for every play session. Offline-first: this is
/// the source of truth; the backend (if any) is only a copy.
///
/// Notifications are deferred one microtask: sessions can be saved while a
/// screen is being torn down and listeners must never rebuild mid-teardown.
class SessionRepository extends ChangeNotifier {
  SessionRepository._();
  static final SessionRepository instance = SessionRepository._();

  static const _key = 'mindy_sessions_v7';
  final List<GameSession> _sessions = []; // chronological, oldest first
  String? lastError;

  /// The signed-in child whose data the app shows. null = everything (used
  /// only before login and by tests).
  String? activeChildId;

  void setActiveChild(String? participantId) {
    activeChildId = participantId;
    _notify();
  }

  /// The ACTIVE child's sessions (what children and caregivers see).
  List<GameSession> get chronological => List.unmodifiable(activeChildId == null
      ? _sessions
      : _sessions.where((s) => s.anonymousChildId == activeChildId).toList());

  /// Every stored session on this device (researcher role only).
  List<GameSession> get allChronological => List.unmodifiable(_sessions);

  List<GameSession> get newestFirst => chronological.reversed.toList();
  List<GameSession> get unsynced =>
      _sessions.where((s) => s.syncStatus != SyncStatus.synced).toList();
  GameSession? get last => _sessions.isEmpty ? null : _sessions.last;

  void _notify() => scheduleMicrotask(notifyListeners);

  Future<void> load() async {
    _sessions.clear();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          _sessions.add(
              GameSession.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        _sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      }
    } catch (e) {
      lastError = 'Could not read saved sessions: $e';
      _sessions.clear();
    }
    _notify();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _key, jsonEncode(_sessions.map((s) => s.toJson()).toList()));
    } catch (e) {
      lastError = 'Could not save sessions: $e';
    }
  }

  /// Adds a session (no-op if the id already exists) and saves it.
  Future<void> add(GameSession s) async {
    if (_sessions.any((x) => x.sessionId == s.sessionId)) return;
    _sessions.add(s);
    _notify();
    await _save();
  }

  /// Saves changes made to a stored session (after-emotion, replay answer,
  /// sync status). The object is shared, so only persistence is needed.
  Future<void> update(GameSession s) async {
    if (!_sessions.any((x) => x.sessionId == s.sessionId)) {
      await add(s);
      return;
    }
    _notify();
    await _save();
  }

  Future<void> clear() async {
    _sessions.clear();
    _notify();
    await _save();
  }

  /// Erases one child's sessions (profile deletion / withdrawal).
  Future<void> deleteForChild(String participantId) async {
    _sessions.removeWhere((s) => s.anonymousChildId == participantId);
    _notify();
    await _save();
  }
}

/// Persistent store for caregiver-reported observations.
class ObservationRepository extends ChangeNotifier {
  ObservationRepository._();
  static final ObservationRepository instance = ObservationRepository._();

  static const _key = 'mindy_observations_v7';
  final List<CaregiverObservation> _items = []; // chronological

  List<CaregiverObservation> get chronological => List.unmodifiable(_items);
  List<CaregiverObservation> get newestFirst => _items.reversed.toList();

  void _notify() => scheduleMicrotask(notifyListeners);

  Future<void> load() async {
    _items.clear();
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        for (final item in jsonDecode(raw) as List) {
          _items.add(CaregiverObservation.fromJson(
              Map<String, dynamic>.from(item as Map)));
        }
        _items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }
    } catch (_) {
      _items.clear();
    }
    _notify();
  }

  Future<void> add(CaregiverObservation o) async {
    _items.add(o);
    _notify();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _key, jsonEncode(_items.map((o) => o.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> clear() async {
    _items.clear();
    _notify();
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key);
    } catch (_) {}
  }
}
