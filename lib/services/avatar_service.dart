import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../characters/avatar.dart';

/// Stores the child's own characters.
///
/// Scoped per child id, so switching child switches character, and one
/// child's character never appears in another child's app. Saved locally
/// only: a character is a handful of integers and a nickname the caregiver
/// typed, and it is never synced to the backend or sent anywhere.
///
/// Up to [maxSaved] characters can be kept, so a child can make a few and
/// switch between them without losing the earlier ones.
class AvatarService extends ChangeNotifier {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  static const int maxSaved = 6;
  static String _key(String childId) => 'mindy_avatars_v1_$childId';
  static String _activeKey(String childId) => 'mindy_avatar_active_v1_$childId';
  static String _seenKey(String childId) => 'mindy_avatar_seen_v1_$childId';

  String _childId = 'default';
  List<MindyAvatar> _saved = const [];
  int _activeIndex = 0;
  bool _onboardingSeen = false;

  List<MindyAvatar> get saved => List.unmodifiable(_saved);
  int get activeIndex => _activeIndex;

  /// True once the child has either made a friend or chosen to skip.
  ///
  /// Kept separate from [hasChosen] so that skipping is respected: a child
  /// who skips is not asked again on every launch, but can still make a
  /// friend later from Home. Scoped per child like everything else here.
  bool get onboardingSeen => _onboardingSeen || hasChosen;

  /// The first-run "let's make your friend" flow is due.
  bool get needsOnboarding => !onboardingSeen;

  Future<void> markOnboardingSeen() async {
    if (_onboardingSeen) return;
    _onboardingSeen = true;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_seenKey(_childId), true);
    } catch (_) {
      // Worst case the child is offered the flow once more. Harmless.
    }
  }

  /// Never null: a child who has not made a character yet still has one to
  /// show, so no screen has to handle an empty case.
  MindyAvatar get active => _saved.isEmpty
      ? const MindyAvatar()
      : _saved[_activeIndex.clamp(0, _saved.length - 1).toInt()];

  bool get hasChosen => _saved.isNotEmpty;

  /// Call on sign-in and whenever the active child changes.
  Future<void> load(String childId) async {
    _childId = childId.isEmpty ? 'default' : childId;
    _saved = const [];
    _activeIndex = 0;
    _onboardingSeen = false;
    try {
      final p = await SharedPreferences.getInstance();
      _onboardingSeen = p.getBool(_seenKey(_childId)) ?? false;
      final raw = p.getString(_key(_childId));
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _saved = [
          for (final item in list)
            MindyAvatar.fromJson(Map<String, dynamic>.from(item as Map)),
        ];
      }
      _activeIndex = p.getInt(_activeKey(_childId)) ?? 0;
      if (_saved.isNotEmpty) {
        _activeIndex = _activeIndex.clamp(0, _saved.length - 1).toInt();
      }
    } catch (_) {
      // A corrupt entry must not stop the app opening: fall back to the
      // default character.
      _saved = const [];
      _activeIndex = 0;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key(_childId),
          jsonEncode([for (final a in _saved) a.toJson()]));
      await p.setInt(_activeKey(_childId), _activeIndex);
    } catch (_) {
      // Storage failures are not worth interrupting a child's play for.
    }
  }

  /// Adds a new character, or replaces the one at [replaceIndex].
  Future<void> save(MindyAvatar avatar, {int? replaceIndex}) async {
    final list = [..._saved];
    if (replaceIndex != null &&
        replaceIndex >= 0 &&
        replaceIndex < list.length) {
      list[replaceIndex] = avatar;
      _activeIndex = replaceIndex;
    } else {
      if (list.length >= maxSaved) {
        list.removeAt(0); // oldest goes, newest is always kept
      }
      list.add(avatar);
      _activeIndex = list.length - 1;
    }
    _saved = list;
    notifyListeners();
    await _persist();
  }

  Future<void> setActive(int index) async {
    if (index < 0 || index >= _saved.length) return;
    _activeIndex = index;
    notifyListeners();
    await _persist();
  }

  Future<void> delete(int index) async {
    if (index < 0 || index >= _saved.length) return;
    final list = [..._saved]..removeAt(index);
    _saved = list;
    _activeIndex = list.isEmpty ? 0 : _activeIndex.clamp(0, list.length - 1).toInt();
    notifyListeners();
    await _persist();
  }

  /// Used when a child's data is deleted.
  Future<void> clearForChild(String childId) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key(childId));
      await p.remove(_activeKey(childId));
      await p.remove(_seenKey(childId));
    } catch (_) {}
    if (childId == _childId) {
      _saved = const [];
      _activeIndex = 0;
      _onboardingSeen = false;
      notifyListeners();
    }
  }
}
