import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../insights/worry_scale.dart';

/// Per-child before/after worry scale answers, stored on the device only.
class WorryService extends ChangeNotifier {
  WorryService._();
  static final WorryService instance = WorryService._();

  String? _childId;
  final List<WorryEntry> _entries = [];
  List<WorryEntry> get entries => List.unmodifiable(_entries);

  static String _key(String id) => 'mindy_worry_v1_$id';

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
              final v = WorryEntry.fromJson(e);
              if (v != null) _entries.add(v);
            }
          }
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<bool> add(WorryPhase phase, int level, {DateTime? at}) async {
    final id = _childId;
    if (id == null || level < 0 || level > 4) return false;
    _entries.add(WorryEntry(at ?? DateTime.now(), phase, level));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _key(id), jsonEncode([for (final e in _entries) e.toJson()]));
    } catch (_) {}
    notifyListeners();
    return true;
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
