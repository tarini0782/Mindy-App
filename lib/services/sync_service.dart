import 'dart:async';
import 'package:flutter/foundation.dart';
import '../games/models/game_session.dart';
import 'emotion_signal_client.dart';
import 'session_repository.dart';

/// Offline-first upload queue. Sessions are always saved locally first;
/// this only copies them to the (optional) backend when it is reachable and
/// otherwise leaves them pending for the next attempt. The app never
/// depends on it.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _running = false;
  DateTime? lastAttempt;
  int lastUploaded = 0;

  Future<int> trigger() async {
    if (_running) return 0;
    _running = true;
    var uploaded = 0;
    try {
      final client = EmotionSignalClient.current();
      for (final s in SessionRepository.instance.unsynced) {
        // Demo data is never uploaded.
        if (s.anonymousChildId.startsWith('DEMO-')) continue;
        final ok = await client.uploadSession(s);
        if (ok) {
          s.syncStatus = SyncStatus.synced;
          uploaded++;
        } else {
          s.syncStatus = SyncStatus.failed;
          await SessionRepository.instance.update(s);
          break; // backend unreachable: retry later
        }
        await SessionRepository.instance.update(s);
      }
    } catch (_) {
      // never let sync break the app
    } finally {
      _running = false;
      lastAttempt = DateTime.now();
      lastUploaded = uploaded;
      scheduleMicrotask(notifyListeners);
    }
    return uploaded;
  }
}
