import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the caregiver decided about each suggestion in the Support plan.
/// Stored on this device only, per child. Choosing "not now" never hides the
/// suggestion; it only marks it, so a grown-up can always change their mind.
enum PlanChoice { trying, notNow }

class PlanDecision {
  final PlanChoice choice;
  final DateTime at;
  const PlanDecision(this.choice, this.at);
}

class SupportPlanService extends ChangeNotifier {
  SupportPlanService._();
  static final SupportPlanService instance = SupportPlanService._();

  String? _childId;
  final Map<String, PlanDecision> _decisions = {};

  Map<String, PlanDecision> get decisions => Map.unmodifiable(_decisions);

  /// Action id -> the day the caregiver chose to try it.
  Map<String, DateTime> get tryingSince => {
        for (final e in _decisions.entries)
          if (e.value.choice == PlanChoice.trying) e.key: e.value.at,
      };

  PlanChoice? choiceFor(String id) => _decisions[id]?.choice;

  static String _key(String id) => 'mindy_plan_choices_v1_$id';

  Future<void> load(String? childId) async {
    _childId = childId;
    _decisions.clear();
    if (childId != null) {
      try {
        final p = await SharedPreferences.getInstance();
        final raw = p.getString(_key(childId));
        if (raw != null) {
          final m = jsonDecode(raw);
          if (m is Map) {
            m.forEach((k, v) {
              if (v is! Map) return;
              final at = DateTime.tryParse('${v['at']}');
              PlanChoice? c;
              for (final x in PlanChoice.values) {
                if (x.name == v['c']) c = x;
              }
              if (at != null && c != null) _decisions['$k'] = PlanDecision(c, at);
            });
          }
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> set(String actionId, PlanChoice choice, {DateTime? at}) async {
    if (_childId == null) return;
    _decisions[actionId] = PlanDecision(choice, at ?? DateTime.now());
    await _save();
    notifyListeners();
  }

  Future<void> clear(String actionId) async {
    if (_childId == null) return;
    _decisions.remove(actionId);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final id = _childId;
    if (id == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _key(id),
          jsonEncode({
            for (final e in _decisions.entries)
              e.key: {'c': e.value.choice.name, 'at': e.value.at.toIso8601String()},
          }));
    } catch (_) {}
  }

  Future<void> deleteForChild(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key(id));
    } catch (_) {}
    if (_childId == id) {
      _decisions.clear();
      notifyListeners();
    }
  }
}
