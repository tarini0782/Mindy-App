import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One finished visit to the Calm Corner.
class CalmVisit {
  final DateTime at;
  final String activity; // 'breathing' | 'grounding'
  final int seconds;
  final int feelingBefore; // 1..3 (1 = not good, 3 = good), 0 = not asked
  final int feelingAfter; // 1..3, 0 = not asked
  const CalmVisit({
    required this.at,
    required this.activity,
    required this.seconds,
    required this.feelingBefore,
    required this.feelingAfter,
  });

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'a': activity,
        's': seconds,
        'b': feelingBefore,
        'f': feelingAfter,
      };

  static CalmVisit? fromJson(Object? o) {
    if (o is! Map) return null;
    final at = DateTime.tryParse('${o['at']}');
    if (at == null) return null;
    return CalmVisit(
      at: at,
      activity: '${o['a'] ?? ''}',
      seconds: (o['s'] as num?)?.toInt() ?? 0,
      feelingBefore: (o['b'] as num?)?.toInt() ?? 0,
      feelingAfter: (o['f'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Remembers how often the child chose the Calm Corner, per child.
/// This is self-chosen coping practice, NOT a research session: it never
/// feeds the adaptive engine or the research export, it is only shown to
/// the caregiver as "what your child chose to do".
class CalmService extends ChangeNotifier {
  CalmService._();
  static final CalmService instance = CalmService._();

  String? _childId;
  final List<CalmVisit> _visits = [];
  List<CalmVisit> get visits => List.unmodifiable(_visits);

  String _key(String id) => 'mindy_calm_v1_$id';

  Future<void> load(String? childId) async {
    _childId = childId;
    _visits.clear();
    if (childId != null) {
      try {
        final p = await SharedPreferences.getInstance();
        final raw = p.getString(_key(childId));
        if (raw != null) {
          final list = jsonDecode(raw);
          if (list is List) {
            for (final e in list) {
              final v = CalmVisit.fromJson(e);
              if (v != null) _visits.add(v);
            }
          }
        }
      } catch (_) {
        // A damaged value is ignored; the child just starts again.
      }
    }
    notifyListeners();
  }

  Future<void> add(CalmVisit v) async {
    final id = _childId;
    if (id == null) return;
    _visits.add(v);
    if (_visits.length > 200) _visits.removeAt(0);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key(id), jsonEncode(_visits.map((e) => e.toJson()).toList()));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteForChild(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key(id));
    } catch (_) {}
    if (_childId == id) {
      _visits.clear();
      notifyListeners();
    }
  }

  int visitsInLastDays(int days, DateTime now) =>
      _visits.where((v) => now.difference(v.at).inDays < days).length;

  /// Share of visits where the child said they felt better afterwards,
  /// among visits that asked both questions. Null when none did.
  double? get feltBetterShare {
    final rated = _visits.where((v) => v.feelingBefore > 0 && v.feelingAfter > 0);
    if (rated.isEmpty) return null;
    final better = rated.where((v) => v.feelingAfter > v.feelingBefore).length;
    return better / rated.length;
  }

  /// Plain sentence for the grown-up summary. Never a clinical claim.
  String caregiverLine(DateTime now) {
    final n = visitsInLastDays(7, now);
    if (_visits.isEmpty) {
      return 'Your child has not used the Calm Corner yet. It is always there '
          'if they want a quiet moment.';
    }
    final share = feltBetterShare;
    final base = 'Your child chose the Calm Corner $n time${n == 1 ? '' : 's'} '
        'in the last 7 days.';
    if (share == null) return base;
    final pct = (share * 100).round();
    return '$base After $pct% of the visits where they answered, they said they '
        'felt better (their own answer, not a measurement).';
  }
}
