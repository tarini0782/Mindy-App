import 'package:shared_preferences/shared_preferences.dart';

/// Counts and keeps the last few uncaught errors so a researcher can see
/// app stability. Nothing here is sent anywhere.
class DiagnosticsService {
  DiagnosticsService._();
  static final DiagnosticsService instance = DiagnosticsService._();

  static const _kCount = 'mindy_error_count';
  static const _kLast = 'mindy_error_last';
  static const _kLaunches = 'mindy_launch_count';

  int errorCount = 0;
  int launchCount = 0;
  List<String> lastErrors = [];

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      errorCount = p.getInt(_kCount) ?? 0;
      lastErrors = p.getStringList(_kLast) ?? [];
      launchCount = (p.getInt(_kLaunches) ?? 0) + 1;
      await p.setInt(_kLaunches, launchCount);
    } catch (_) {}
  }

  Future<void> record(Object error, [StackTrace? stack]) async {
    errorCount++;
    final line = '${DateTime.now().toIso8601String()}  $error';
    lastErrors = [line, ...lastErrors].take(20).toList();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kCount, errorCount);
      await p.setStringList(_kLast, lastErrors);
    } catch (_) {}
  }
}
