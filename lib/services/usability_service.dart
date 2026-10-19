import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../insights/sus.dart';

/// One completed SUS questionnaire (grown-up respondent).
class SusEntry {
  final DateTime at;
  final List<int> answers;
  final double score;
  const SusEntry(this.at, this.answers, this.score);

  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'answers': answers, 'score': score};

  static SusEntry? fromJson(dynamic j) {
    if (j is! Map) return null;
    final raw = j['answers'];
    if (raw is! List) return null;
    final answers = [for (final a in raw) (a as num).toInt()];
    final score = susScore(answers);
    final at = DateTime.tryParse('${j['at']}');
    if (score == null || at == null) return null;
    return SusEntry(at, answers, score);
  }
}

/// Per-child SUS history, stored on the device only.
class UsabilityService extends ChangeNotifier {
  UsabilityService._();
  static final UsabilityService instance = UsabilityService._();

  String? _childId;
  final List<SusEntry> _entries = [];
  List<SusEntry> get entries => List.unmodifiable(_entries);

  static String _key(String id) => 'mindy_sus_v1_$id';

  Future<void> load(String? childId) async {
    _childId = childId;
    _entries.clear();
    if (childId != null) {
      try {
        final p = await SharedPreferences.getInstance();
        final raw = p.getString(_key(childId));
        if (raw != null) {
          final l = jsonDecode(raw);
          if (l is List) {
            for (final e in l) {
              final v = SusEntry.fromJson(e);
              if (v != null) _entries.add(v);
            }
          }
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Returns the score, or null if the answers were not valid.
  Future<double?> add(List<int> answers, {DateTime? at}) async {
    final id = _childId;
    final score = susScore(answers);
    if (id == null || score == null) return null;
    _entries.add(SusEntry(at ?? DateTime.now(), List<int>.of(answers), score));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _key(id), jsonEncode([for (final e in _entries) e.toJson()]));
    } catch (_) {}
    notifyListeners();
    return score;
  }

  Future<void> deleteForChild(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key(id));
    } catch (_) {}
    if (_childId == id) {
      _entries.clear();
      notifyListeners();
    }
  }
}
