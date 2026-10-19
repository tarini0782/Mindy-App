import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../insights/support_plan.dart';
import 'app_settings.dart';

/// Writes ONE short, friendlier paragraph over the Support plan's own
/// numbers, using the backend's /insights/summary endpoint (which may call
/// a pretrained LLM -- see backend/insight_summary.py). This is a writing
/// layer ONLY: it never changes what the rule engine in support_plan.dart
/// decided, and the plain rule-based summary is always shown underneath it
/// (see support_plan_screen.dart), never replaced.
///
/// Off by default (AppSettings.aiInsightsEnabled). Only already-computed,
/// aggregated numbers are sent -- never a name, a raw session, or anything
/// that could identify the child. Any failure (no network, backend down,
/// timeout, the model's own text failing a safety check) falls back to
/// silence: the screen just shows its existing rule-based text, as if this
/// service were never called.
class InsightSummaryService extends ChangeNotifier {
  InsightSummaryService._();
  static final InsightSummaryService instance = InsightSummaryService._();

  static const Duration timeout = Duration(seconds: 8);

  /// Terms that must never reach the screen, re-checked here even though
  /// the backend already checks them -- defence in depth, and this is the
  /// same promise tested in test/v26_support_plan_test.dart.
  static const List<String> bannedTerms = [
    'diagnos', 'disorder', 'you have', 'is anxious', 'is depressed',
    'adhd', 'autis', 'ptsd', 'ocd', 'bipolar', 'syndrome', 'psychiatric',
    'mental illness', 'trauma', 'clinical', 'disease', 'pathology',
  ];

  String? _text; // the last accepted AI paragraph, or null
  String? _forPlanKey; // which plan snapshot [_text] belongs to
  bool _loading = false;
  String? _unavailableReason; // non-null only to explain a failed attempt

  String? get text => _text;
  bool get loading => _loading;
  String? get unavailableReason => _unavailableReason;

  /// A short fingerprint of the numbers that would be sent, so a rebuild
  /// with an unchanged plan doesn't repeat the network call.
  static String keyFor(SupportPlan plan) => jsonEncode(signalsFor(plan));

  /// Replaces the child's nickname with "the child" wherever it appears.
  ///
  /// This exists because the plan's signal and action wording is written FOR
  /// a caregiver and therefore uses the child's name ("Tee settled after
  /// quiet activities"). Sending that verbatim would put a real child's name
  /// into a third-party service. A test asserts the name cannot survive this.
  ///
  /// Case-insensitive and whole-word only, so a name like "Sam" does not
  /// mangle "same".
  static String redactName(String text, String? name) {
    if (name == null || name.trim().isEmpty) return text;
    final n = RegExp.escape(name.trim());
    return text.replaceAll(
        RegExp('(?<![A-Za-z])$n(?![A-Za-z])', caseSensitive: false),
        'the child');
  }

  /// Only already-computed, non-identifying numbers and wording with the
  /// child's name stripped out. Nothing here is an id or a raw session.
  static Map<String, dynamic> signalsFor(SupportPlan plan) {
    String clean(String s) => redactName(s, plan.childName);
    return {
      'band': plan.band.name,
      'checkIns14d': plan.checkIns,
      'lowCount14d': plan.lowCount,
      'confidence': clean(plan.confidence),
      'signals': [
        for (final s in plan.signals)
          {
            'id': s.ruleId,
            'title': clean(s.title),
            'detail': clean(s.detail),
            'tone': s.tone.name,
          },
      ],
      'topActionTitles': [
        for (final a in plan.actions.take(3)) clean(a.title),
      ],
    };
  }

  static bool _isBanned(String text) {
    final low = text.toLowerCase();
    return bannedTerms.any(low.contains);
  }

  /// Fetches (or returns the cached) AI paragraph for this plan. Silent on
  /// any failure: callers should keep showing the rule-based summary
  /// regardless of what this returns, and [unavailableReason] is for your
  /// own debugging, not something to show a caregiver as an error.
  Future<void> refresh(SupportPlan plan, {http.Client? client}) async {
    if (!AppSettings.instance.aiInsightsEnabled) {
      _text = null;
      _forPlanKey = null;
      _unavailableReason = null;
      notifyListeners();
      return;
    }
    final key = keyFor(plan);
    if (key == _forPlanKey && _text != null) return; // already have it
    final base = AppSettings.instance.baseUrl.trim();
    if (base.isEmpty) {
      _text = null;
      _unavailableReason = 'No backend address is set in Settings.';
      notifyListeners();
      return;
    }
    _loading = true;
    _unavailableReason = null;
    notifyListeners();
    final c = client ?? http.Client();
    try {
      final uri = Uri.parse('$base/insights/summary');
      final resp = await c
          .post(uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'signals': signalsFor(plan)}))
          .timeout(timeout);
      if (resp.statusCode != 200) {
        _text = null;
        _unavailableReason = 'Backend returned ${resp.statusCode}';
        return;
      }
      final body = jsonDecode(resp.body);
      if (body is! Map || body['source'] != 'llm') {
        _text = null;
        _unavailableReason = (body is Map ? body['reason'] : null)?.toString() ??
            'No AI text was returned';
        return;
      }
      final text = (body['text'] as Object?)?.toString().trim() ?? '';
      if (text.isEmpty || _isBanned(text)) {
        _text = null;
        _unavailableReason = 'The AI text did not pass the safety check';
        return;
      }
      _text = text;
      _forPlanKey = key;
    } catch (e) {
      _text = null;
      _unavailableReason = 'Could not reach the backend: $e';
    } finally {
      if (client == null) c.close();
      _loading = false;
      notifyListeners();
    }
  }

  /// Clears any cached text (e.g. when the toggle is switched off or the
  /// active child changes).
  void reset() {
    _text = null;
    _forPlanKey = null;
    _unavailableReason = null;
    _loading = false;
    notifyListeners();
  }
}
