import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_settings.dart';

/// What kind of picture is being asked about.
enum VqaModality { skin, xray, lab }

extension VqaModalityX on VqaModality {
  String get code => name; // skin | xray | lab
  String get label {
    switch (this) {
      case VqaModality.skin:
        return 'Skin photo';
      case VqaModality.xray:
        return 'X-ray';
      case VqaModality.lab:
        return 'Lab report';
    }
  }
}

class VqaFinding {
  final String label;
  final double probability; // 0..1
  const VqaFinding(this.label, this.probability);
}

/// The answer from the project's AI backend (the VQA engine, built by the
/// backend team member). The app only DISPLAYS it: it never edits,
/// completes or invents an answer.
class VqaAnswer {
  final String answer;
  final double confidence; // 0..1
  final List<VqaFinding> findings;
  final String? heatmapUrl; // explainability image (https only)
  final String disclaimer;
  final bool requiresClinicianReview;
  final String? modelVersion;
  const VqaAnswer({
    required this.answer,
    required this.confidence,
    required this.findings,
    required this.heatmapUrl,
    required this.disclaimer,
    required this.requiresClinicianReview,
    required this.modelVersion,
  });

  /// Below this confidence the screen shows a prominent "ask a doctor".
  static const double lowConfidence = 0.6;
  bool get showDoctorWarning => requiresClinicianReview || confidence < lowConfidence;

  /// Returns null unless the required fields are present and valid. A
  /// malformed response is an error, never a guess.
  static VqaAnswer? parse(Object? json) {
    if (json is! Map) return null;
    final a = json['answer'];
    final c = json['confidence'];
    final d = json['disclaimer'];
    if (a is! String || a.trim().isEmpty) return null;
    if (c is! num || c < 0 || c > 1) return null;
    if (d is! String || d.trim().isEmpty) return null;
    final findings = <VqaFinding>[];
    final f = json['findings'];
    if (f is List) {
      for (final e in f) {
        if (e is Map && e['label'] is String && e['probability'] is num) {
          final p = (e['probability'] as num).toDouble();
          if (p >= 0 && p <= 1) findings.add(VqaFinding(e['label'] as String, p));
        }
      }
    }
    String? heat;
    final ex = json['explanation'];
    if (ex is Map && ex['heatmapUrl'] is String) {
      final u = ex['heatmapUrl'] as String;
      if (u.toLowerCase().startsWith('https://')) heat = u;
    }
    return VqaAnswer(
      answer: a,
      confidence: c.toDouble(),
      findings: findings,
      heatmapUrl: heat,
      disclaimer: d,
      requiresClinicianReview: json['requiresClinicianReview'] == true,
      modelVersion: json['modelVersion'] is String ? json['modelVersion'] as String : null,
    );
  }
}

class VqaOutcome {
  final VqaAnswer? answer;
  final String? error;
  const VqaOutcome.ok(VqaAnswer a)
      : answer = a,
        error = null;
  const VqaOutcome.failed(String e)
      : answer = null,
        error = e;
  bool get ok => answer != null;
}

/// Calls POST {baseUrl}/vqa/ask (see docs/INTEGRATION_CONTRACT.md).
/// Sends the picture and the question ONLY: no child ID, name or age.
class RemoteVqaClient {
  final String baseUrl;
  final http.Client _http;
  static const Duration timeout = Duration(seconds: 30);
  static const int maxBytes = 8 * 1024 * 1024;

  RemoteVqaClient(this.baseUrl, {http.Client? client}) : _http = client ?? http.Client();

  /// Built from the researcher settings. Null when no real backend is set.
  static RemoteVqaClient? fromSettings({http.Client? client}) {
    final s = AppSettings.instance;
    if (s.useMockBackend || s.baseUrl.trim().isEmpty) return null;
    return RemoteVqaClient(s.baseUrl.trim(), client: client);
  }

  bool get _secure => baseUrl.toLowerCase().startsWith('https://');

  Future<VqaOutcome> ask({
    required VqaModality modality,
    required String question,
    required List<int> imageBytes,
    required String filename,
  }) async {
    if (!_secure) {
      return const VqaOutcome.failed('The backend address must start with https://');
    }
    if (imageBytes.isEmpty) return const VqaOutcome.failed('No picture was chosen.');
    if (imageBytes.length > maxBytes) {
      return const VqaOutcome.failed('That picture is too large (limit 8 MB).');
    }
    final q = question.trim();
    if (q.isEmpty) return const VqaOutcome.failed('Please type a question.');
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    try {
      final req = http.MultipartRequest('POST', Uri.parse('$base/vqa/ask'))
        ..fields['modality'] = modality.code
        ..fields['question'] = q
        ..files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: filename));
      final streamed = await _http.send(req).timeout(timeout);
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 501 || res.statusCode == 503) {
        return const VqaOutcome.failed(
            'The analysis service is not ready yet. Please ask the clinician.');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return VqaOutcome.failed('The service answered with an error (${res.statusCode}).');
      }
      final a = VqaAnswer.parse(jsonDecode(res.body));
      if (a == null) {
        return const VqaOutcome.failed(
            'The answer was incomplete, so it is not shown. Please ask the clinician.');
      }
      return VqaOutcome.ok(a);
    } catch (_) {
      return const VqaOutcome.failed('Could not reach the analysis service.');
    }
  }
}
