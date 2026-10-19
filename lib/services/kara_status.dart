import 'package:flutter/foundation.dart';
import 'app_settings.dart';
import 'emotion_signal_client.dart';

enum KaraLink { notConnected, simulated, connected }

/// Honest KARA status: "connected" only when a real backend answered.
class KaraStatusService extends ChangeNotifier {
  KaraStatusService._();
  static final KaraStatusService instance = KaraStatusService._();

  KaraLink link = KaraLink.notConnected;
  static const Duration freshFor = Duration(minutes: 15);

  /// Returns a FRESH robot check-in if one exists, else null (the caller
  /// then shows the normal in-app check-in).
  Future<RobotCheckin?> fetchRecent({DateTime? now}) async {
    final s = AppSettings.instance;
    final client = EmotionSignalClient.current();
    RobotCheckin? c;
    try {
      c = await client.latestRobotCheckin(s.childId);
    } catch (_) {
      c = null;
    }
    if (s.useMockBackend) {
      link = s.simulatedKara == null ? KaraLink.notConnected : KaraLink.simulated;
    } else {
      link = (await client.ping()) ? KaraLink.connected : KaraLink.notConnected;
    }
    notifyListeners();
    if (c == null) return null;
    final age = (now ?? DateTime.now()).difference(c.timestamp);
    if (age > freshFor) return null;
    return c;
  }
}
