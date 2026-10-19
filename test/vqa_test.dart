import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindy_app/services/vqa_client.dart';

Map<String, dynamic> good() => {
      'answer': 'The report shows normal haemoglobin.',
      'confidence': 0.82,
      'findings': [
        {'label': 'normal', 'probability': 0.82}
      ],
      'explanation': {'heatmapUrl': 'https://example.org/h.png'},
      'disclaimer': 'Supports, does not replace, a clinician.',
      'requiresClinicianReview': false,
      'modelVersion': 'dev-0',
    };

void main() {
  group('parse', () {
    test('accepts a complete answer', () {
      final a = VqaAnswer.parse(good())!;
      expect(a.confidence, 0.82);
      expect(a.findings.single.label, 'normal');
      expect(a.heatmapUrl, 'https://example.org/h.png');
      expect(a.showDoctorWarning, isFalse);
    });

    test('rejects missing answer, bad confidence or missing disclaimer', () {
      expect(VqaAnswer.parse({...good(), 'answer': ''}), isNull);
      expect(VqaAnswer.parse({...good(), 'confidence': 1.5}), isNull);
      expect(VqaAnswer.parse({...good(), 'confidence': 'high'}), isNull);
      final m = good()..remove('disclaimer');
      expect(VqaAnswer.parse(m), isNull);
      expect(VqaAnswer.parse('nope'), isNull);
    });

    test('low confidence or review flag shows the doctor warning', () {
      expect(VqaAnswer.parse({...good(), 'confidence': 0.4})!.showDoctorWarning, isTrue);
      expect(VqaAnswer.parse({...good(), 'requiresClinicianReview': true})!.showDoctorWarning, isTrue);
    });

    test('non-https heatmap is dropped', () {
      final a = VqaAnswer.parse({...good(), 'explanation': {'heatmapUrl': 'http://x/h.png'}})!;
      expect(a.heatmapUrl, isNull);
    });
  });

  group('client', () {
    test('sends picture and question only, no child identifiers', () async {
      late http.Request seen;
      final c = RemoteVqaClient('https://api.example.org', client: MockClient((r) async {
        seen = r;
        return http.Response(jsonEncode(good()), 200);
      }));
      final out = await c.ask(
          modality: VqaModality.lab, question: 'What is this?', imageBytes: [1, 2, 3], filename: 'a.jpg');
      expect(out.ok, isTrue);
      expect(seen.url.toString(), 'https://api.example.org/vqa/ask');
      final body = utf8.decode(seen.bodyBytes, allowMalformed: true);
      expect(body, contains('name="modality"'));
      expect(body, contains('name="question"'));
      expect(body.contains('child'), isFalse);
      expect(body.contains('participant'), isFalse);
    });

    test('refuses http, empty picture, empty question and huge pictures', () async {
      final http1 = RemoteVqaClient('http://api.example.org', client: MockClient((r) async => http.Response('{}', 200)));
      expect((await http1.ask(modality: VqaModality.skin, question: 'q', imageBytes: [1], filename: 'a')).ok, isFalse);
      final c = RemoteVqaClient('https://api.example.org', client: MockClient((r) async => http.Response('{}', 200)));
      expect((await c.ask(modality: VqaModality.skin, question: 'q', imageBytes: [], filename: 'a')).error, contains('picture'));
      expect((await c.ask(modality: VqaModality.skin, question: ' ', imageBytes: [1], filename: 'a')).error, contains('question'));
      final big = List<int>.filled(RemoteVqaClient.maxBytes + 1, 0);
      expect((await c.ask(modality: VqaModality.skin, question: 'q', imageBytes: big, filename: 'a')).error, contains('large'));
    });

    test('501 means not ready; an incomplete answer is never shown', () async {
      final nr = RemoteVqaClient('https://api.example.org', client: MockClient((r) async => http.Response('', 501)));
      final o1 = await nr.ask(modality: VqaModality.xray, question: 'q', imageBytes: [1], filename: 'a');
      expect(o1.ok, isFalse);
      expect(o1.error, contains('not ready'));
      final bad = RemoteVqaClient('https://api.example.org', client: MockClient((r) async => http.Response('{"answer":"x"}', 200)));
      final o2 = await bad.ask(modality: VqaModality.xray, question: 'q', imageBytes: [1], filename: 'a');
      expect(o2.ok, isFalse);
      expect(o2.error, contains('incomplete'));
    });

    test('network failure is an error, not an answer', () async {
      final c = RemoteVqaClient('https://api.example.org', client: MockClient((r) async => throw Exception('down')));
      final o = await c.ask(modality: VqaModality.lab, question: 'q', imageBytes: [1], filename: 'a');
      expect(o.ok, isFalse);
    });
  });
}
