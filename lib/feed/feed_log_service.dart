import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feed_planner.dart';

/// One look at one feed card: how long the child stayed, and whether they
/// played it. Browsing behaviour only; it says nothing about health.
class FeedView {
  final DateTime at;
  final int index;
  final String gameId;
  final String kind; // calm | challenge | fun
  final int dwellMs;
  final bool played;
  const FeedView({
    required this.at,
    required this.index,
    required this.gameId,
    required this.kind,
    required this.dwellMs,
    required this.played,
  });

  bool get quickSkip => !played && dwellMs < FeedPlanner.quickSkipMs;

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'i': index,
        'g': gameId,
        'k': kind,
        'd': dwellMs,
        'p': played,
      };

  static FeedView? fromJson(Object? o) {
    if (o is! Map) return null;
    final at = DateTime.tryParse('${o['at']}');
    if (at == null) return null;
    return FeedView(
      at: at,
      index: (o['i'] as num?)?.toInt() ?? 0,
      gameId: '${o['g'] ?? ''}',
      kind: '${o['k'] ?? ''}',
      dwellMs: (o['d'] as num?)?.toInt() ?? 0,
      played: o['p'] == true,
    );
  }
}

class FeedStats {
  final int views;
  final int plays;
  final int quickSkips;
  final int medianDwellMs;
  const FeedStats(this.views, this.plays, this.quickSkips, this.medianDwellMs);

  double? get playRate => views == 0 ? null : plays / views;
  double? get quickSkipRate => views == 0 ? null : quickSkips / views;

  static FeedStats of(List<FeedView> v) {
    if (v.isEmpty) return const FeedStats(0, 0, 0, 0);
    final d = v.map((e) => e.dwellMs).toList()..sort();
    final mid = d.length ~/ 2;
    final median = d.length.isOdd ? d[mid] : ((d[mid - 1] + d[mid]) ~/ 2);
    return FeedStats(v.length, v.where((e) => e.played).length,
        v.where((e) => e.quickSkip).length, median);
  }
}

/// Per-child log of feed browsing, saved on the device like everything else.
class FeedLogService extends ChangeNotifier {
  FeedLogService._();
  static final FeedLogService instance = FeedLogService._();

  static const int maxViews = 1000;
  String? _childId;
  final List<FeedView> _views = [];
  List<FeedView> get views => List.unmodifiable(_views);
  FeedStats get stats => FeedStats.of(_views);

  String _key(String id) => 'mindy_feed_v1_$id';

  Future<void> load(String? childId) async {
    _childId = childId;
    _views.clear();
    if (childId != null) {
      try {
        final p = await SharedPreferences.getInstance();
        final raw = p.getString(_key(childId));
        if (raw != null) {
          final l = jsonDecode(raw);
          if (l is List) {
            for (final e in l) {
              final v = FeedView.fromJson(e);
              if (v != null) _views.add(v);
            }
          }
        }
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> add(FeedView v) async {
    final id = _childId;
    if (id == null) return;
    _views.add(v);
    if (_views.length > maxViews) _views.removeAt(0);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key(id), jsonEncode(_views.map((e) => e.toJson()).toList()));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> deleteForChild(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key(id));
    } catch (_) {}
    if (_childId == id) {
      _views.clear();
      notifyListeners();
    }
  }

  /// CSV for the researcher: one row per card view.
  String toCsv(String participantId) {
    final b = StringBuffer('participantId,at,cardIndex,gameId,kind,dwellMs,played,quickSkip\n');
    for (final v in _views) {
      b.writeln('$participantId,${v.at.toIso8601String()},${v.index},${v.gameId},'
          '${v.kind},${v.dwellMs},${v.played},${v.quickSkip}');
    }
    return b.toString();
  }
}
