import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/support_plan.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/services/app_settings.dart';
import 'package:mindy_app/services/insight_summary_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_helpers.dart';

SupportPlan _plan() => SupportPlan.build(
      sessions: [
        for (var i = 0; i < 6; i++)
          makeSession(GameType.breathingGarden,
              before: EmotionState.sad,
              after: EmotionState.calm,
              at: DateTime(2026, 10, 15).subtract(Duration(days: i))),
      ],
      worry: const [],
      calm: const [],
      now: DateTime(2026, 10, 15, 12),
      childName: 'Tee',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
    InsightSummaryService.instance.reset();
  });

  group('signalsFor (what actually gets sent)', () {
    test('never includes a name or a session-level field', () {
      final j = InsightSummaryService.signalsFor(_plan());
      final text = jsonEncode(j);
      expect(text.contains('Tee'), isFalse);
      expect(j.containsKey('sessionId'), isFalse);
      expect(j.containsKey('anonymousChildId'), isFalse);
      expect(j['band'], isA<String>());
      expect(j['checkIns14d'], isA<int>());
    });

    test('the name is stripped from signal and action wording, not just absent '
        'from the top level', () {
      final plan = _plan();
      final j = InsightSummaryService.signalsFor(plan);
      // The plan's own wording DOES use the child's name -- that is correct
      // for a caregiver reading it on the device.
      expect(plan.headline.contains('Tee') || plan.summary.contains('Tee'),
          isTrue,
          reason: 'this test is meaningless if the plan never used the name');
      // What leaves the device must not.
      expect(jsonEncode(j).contains('Tee'), isFalse);
    });

    test('redaction is whole-word and case-insensitive', () {
      expect(InsightSummaryService.redactName('Sam had the same idea', 'Sam'),
          'the child had the same idea',
          reason: '"same" must not be mangled');
      expect(InsightSummaryService.redactName('tee and TEE', 'Tee'),
          'the child and the child');
      expect(InsightSummaryService.redactName('nothing to do', null),
          'nothing to do');
      expect(InsightSummaryService.redactName('nothing to do', '   '),
          'nothing to do');
    });

    test('is stable for the same plan (used as a cache key)', () {
      final p = _plan();
      expect(InsightSummaryService.keyFor(p), InsightSummaryService.keyFor(p));
    });
  });

  group('refresh: off by default', () {
    test('does nothing and makes no HTTP call when the toggle is off', () async {
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      });
      await InsightSummaryService.instance.refresh(_plan(), client: client);
      expect(called, isFalse);
      expect(InsightSummaryService.instance.text, isNull);
    });
  });

  group('refresh: enabled', () {
    setUp(() async {
      await AppSettings.instance.setAiInsightsEnabled(true);
      await AppSettings.instance.setBaseUrl('http://example.invalid');
    });

    test('no base url set: fails quietly, no call attempted', () async {
      await AppSettings.instance.setBaseUrl('');
      var called = false;
      final client = MockClient((req) async {
        called = true;
        return http.Response('{}', 200);
      });
      await InsightSummaryService.instance.refresh(_plan(), client: client);
      expect(called, isFalse);
      expect(InsightSummaryService.instance.text, isNull);
      expect(InsightSummaryService.instance.unavailableReason, contains('backend address'));
    });

    test('backend returns a good llm result: shown', () async {
      final client = MockClient((req) async {
        expect(req.url.path, '/insights/summary');
        final body = jsonDecode(req.body) as Map;
        expect(body['signals'], isA<Map>());
        return http.Response(
            jsonEncode({'source': 'llm', 'text': 'A calm, factual note for Tee this week.'}),
            200);
      });
      await InsightSummaryService.instance.refresh(_plan(), client: client);
      expect(InsightSummaryService.instance.text, 'A calm, factual note for Tee this week.');
      expect(InsightSummaryService.instance.unavailableReason, isNull);
    });

    test('backend fallback (not configured): shows nothing, no crash', () async {
      final client = MockClient((req) async =>
          http.Response(jsonEncode({'source': 'fallback', 'reason': 'not configured'}), 200));
      await InsightSummaryService.instance.refresh(_plan(), client: client);
      expect(InsightSummaryService.instance.text, isNull);
      expect(InsightSummaryService.instance.unavailableReason, 'not configured');
    });

    test('a banned term in the model text is rejected client-side too', () async {
      final client = MockClient((req) async => http.Response(
          jsonEncode({'source': 'llm', 'text': 'This could be a sign of a disorder.'}), 200));
      await InsightSummaryService.instance.refresh(_plan(), client: client);
      expect(InsightSummaryService.instance.text, isNull);
      expect(InsightSummaryService.instance.unavailableReason, contains('safety check'));
    });

    test('non-200 status: fails quietly', () async {
      final client = MockClient((req) async => http.Response('oops', 500));
      await InsightSummaryService.instance.refresh(_plan(), client: client);
      expect(InsightSummaryService.instance.text, isNull);
    });

    test('network exception: fails quietly, never throws', () async {
      final client = MockClient((req) async => throw Exception('no network'));
      await expectLater(
          InsightSummaryService.instance.refresh(_plan(), client: client), completes);
      expect(InsightSummaryService.instance.text, isNull);
      expect(InsightSummaryService.instance.unavailableReason, contains('Could not reach'));
    });

    test('a second refresh with an unchanged plan does not call the network again',
        () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response(jsonEncode({'source': 'llm', 'text': 'Stable text.'}), 200);
      });
      final plan = _plan();
      await InsightSummaryService.instance.refresh(plan, client: client);
      await InsightSummaryService.instance.refresh(plan, client: client);
      expect(calls, 1);
    });

    test('turning the toggle off clears any cached text', () async {
      final client = MockClient(
          (req) async => http.Response(jsonEncode({'source': 'llm', 'text': 'Some text.'}), 200));
      await InsightSummaryService.instance.refresh(_plan(), client: client);
      expect(InsightSummaryService.instance.text, isNotNull);
      await AppSettings.instance.setAiInsightsEnabled(false);
      await InsightSummaryService.instance.refresh(_plan(), client: client);
      expect(InsightSummaryService.instance.text, isNull);
    });
  });
}
