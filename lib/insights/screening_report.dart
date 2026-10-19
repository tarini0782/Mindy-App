import 'dart:convert';

/// A behavioural screening summary produced OUTSIDE the app by the Python
/// pipeline (`mindy_ml/src/predict.py`). The app only DISPLAYS what that
/// file contains. It never computes, guesses or invents an indicator.
class ScreeningIndicator {
  final String label;
  final String level; // LOW | MODERATE | HIGH
  final double? confidence;
  final String method;
  const ScreeningIndicator(this.label, this.level, this.confidence, this.method);
}

class ScreeningReport {
  static const String syntheticOrigin = 'SYNTHETIC_DEVELOPMENT';
  static const String fixedDisclaimer =
      'This system is a research screening prototype and does not provide a '
      'clinical diagnosis.';
  static const List<String> validLevels = ['LOW', 'MODERATE', 'HIGH'];

  final String childId;
  final String dataOrigin;
  final String? warning;
  final int sessions;
  final int responseEvents;
  final List<ScreeningIndicator> indicators;
  final List<String> patterns;
  final String recommendation;

  const ScreeningReport({
    required this.childId,
    required this.dataOrigin,
    required this.warning,
    required this.sessions,
    required this.responseEvents,
    required this.indicators,
    required this.patterns,
    required this.recommendation,
  });

  bool get isSynthetic => dataOrigin == syntheticOrigin;

  /// Parses the JSON written by predict.py. Throws [FormatException] with a
  /// plain-language message when the file is not a valid report, so a wrong
  /// paste can never turn into a made-up result.
  static ScreeningReport parse(String text) {
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } catch (_) {
      throw const FormatException('That is not valid JSON. Paste the whole report file.');
    }
    if (raw is! Map) {
      throw const FormatException('The report must be a JSON object.');
    }
    final j = Map<String, dynamic>.from(raw);
    final ind = j['indicators'];
    if (ind is! Map || ind.isEmpty) {
      throw const FormatException('No indicators found. Is this a Mindy report?');
    }
    final out = <ScreeningIndicator>[];
    for (final e in ind.entries) {
      final v = e.value;
      if (v is! Map) continue;
      final level = (v['level'] ?? '').toString().toUpperCase();
      if (!validLevels.contains(level)) {
        throw FormatException('Unknown level "$level" for ${e.key}. Expected LOW, MODERATE or HIGH.');
      }
      out.add(ScreeningIndicator(
        (v['label'] ?? e.key).toString(),
        level,
        (v['confidence'] as num?)?.toDouble(),
        (v['method'] ?? '').toString(),
      ));
    }
    if (out.isEmpty) {
      throw const FormatException('No usable indicators in this report.');
    }
    final ev = j['evidence'] is Map ? Map<String, dynamic>.from(j['evidence'] as Map) : <String, dynamic>{};
    return ScreeningReport(
      childId: (j['child_id'] ?? 'unknown').toString(),
      dataOrigin: (j['data_origin'] ?? 'UNKNOWN').toString(),
      warning: j['WARNING']?.toString(),
      sessions: (ev['sessions'] as num?)?.toInt() ?? 0,
      responseEvents: (ev['response_events'] as num?)?.toInt() ?? 0,
      indicators: out,
      patterns: [for (final p in (j['observed_patterns'] as List? ?? const [])) p.toString()],
      recommendation: (j['recommendation'] ?? '').toString(),
    );
  }
}
