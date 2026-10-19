import 'dart:convert';
import 'package:http/http.dart' as http;
import '../games/models/game_session.dart';
import '../models/emotion_state.dart';
import '../models/study_condition.dart';
import 'app_settings.dart';

class RobotCheckin {
  final EmotionState emotion;
  final DateTime timestamp;
  final bool simulated;
  const RobotCheckin(this.emotion, this.timestamp, {this.simulated = false});

  EmotionSource get source =>
      simulated ? EmotionSource.karaSimulated : EmotionSource.kara;
}

/// Interface to KARA / any external emotion signal and to the optional
/// backend. If nothing is available the app falls back to its own check-in.
///
/// Endpoints (proposal Appendix C):
///   POST /sessions/{childId}/checkin   { child_id, emotion, source, timestamp }
///   GET  /sessions/{childId}/next-game
/// ASSUMED additions (agree with the backend team):
///   GET  /sessions/{childId}/latest-checkin
///   POST /sessions/{childId}/records
abstract class EmotionSignalClient {
  String get name;
  Future<bool> postCheckin(
      String childId, EmotionState? emotion, EmotionSource source);
  Future<RobotCheckin?> latestRobotCheckin(String childId);
  Future<bool> uploadSession(GameSession session);
  Future<bool> ping();

  static final MockEmotionSignalClient mock = MockEmotionSignalClient();

  static EmotionSignalClient current() {
    final s = AppSettings.instance;
    return s.useMockBackend ? mock : RemoteEmotionSignalClient(s.baseUrl);
  }
}

/// Offline stand-in. It NEVER invents a robot signal: it returns one only
/// when the researcher turns on "simulate KARA" in test mode, and that
/// signal is always stored as KARA_SIMULATED. It is labelled as a mock.
class MockEmotionSignalClient implements EmotionSignalClient {
  final List<Map<String, dynamic>> receivedSessions = [];
  final List<Map<String, dynamic>> receivedCheckins = [];

  @override
  String get name => 'Mock (offline)';

  @override
  Future<bool> postCheckin(
      String childId, EmotionState? emotion, EmotionSource source) async {
    receivedCheckins.add({
      'child_id': childId,
      'emotion': emotion?.code,
      'source': source.code,
      'timestamp': DateTime.now().toIso8601String(),
    });
    return true;
  }

  @override
  Future<RobotCheckin?> latestRobotCheckin(String childId) async {
    final e = AppSettings.instance.simulatedKara;
    if (e == null) return null;
    return RobotCheckin(e, DateTime.now(), simulated: true);
  }

  @override
  Future<bool> uploadSession(GameSession session) async {
    if (receivedSessions.any((m) => m['sessionId'] == session.sessionId)) {
      return true;
    }
    receivedSessions.add(session.toJson());
    return true;
  }

  @override
  Future<bool> ping() async => true;
}

/// Real HTTP client. HTTPS only.
class RemoteEmotionSignalClient implements EmotionSignalClient {
  final String baseUrl;
  static const _timeout = Duration(seconds: 4);
  RemoteEmotionSignalClient(this.baseUrl);

  @override
  String get name => 'Remote ($baseUrl)';

  bool get _secure => baseUrl.toLowerCase().startsWith('https://');

  Uri _uri(String path) {
    final b = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$b$path');
  }

  static const _headers = {'Content-Type': 'application/json'};

  @override
  Future<bool> postCheckin(
      String childId, EmotionState? emotion, EmotionSource source) async {
    if (!_secure) return false;
    try {
      final r = await http
          .post(_uri('/sessions/$childId/checkin'),
              headers: _headers,
              body: jsonEncode({
                'child_id': childId,
                'emotion': emotion?.code,
                'source': source.code,
                'timestamp': DateTime.now().toUtc().toIso8601String(),
              }))
          .timeout(_timeout);
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<RobotCheckin?> latestRobotCheckin(String childId) async {
    if (!_secure) return null;
    try {
      final r = await http
          .get(_uri('/sessions/$childId/latest-checkin'))
          .timeout(_timeout);
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final src = (j['source'] as String?)?.toLowerCase();
      if (src != 'robot' && src != 'kara') return null;
      final e = emotionFromName(j['emotion'] as String?);
      final t = DateTime.tryParse((j['timestamp'] as String?) ?? '');
      if (e == null || t == null) return null;
      return RobotCheckin(e, t.toLocal());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> uploadSession(GameSession session) async {
    if (!_secure) return false;
    try {
      final r = await http
          .post(_uri('/sessions/${session.anonymousChildId}/records'),
              headers: _headers, body: jsonEncode(session.toJson()))
          .timeout(_timeout);
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> ping() async {
    if (!_secure) return false;
    try {
      final r = await http.get(_uri('/sessions/ping')).timeout(_timeout);
      return r.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
