import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emotion_state.dart';
import '../models/study_condition.dart';
import 'music_service.dart';

/// Persisted app/research settings. Survives restarts.
///
/// NOTHING here identifies a child: [childId] is a random code generated on
/// first launch, [participantCode] is typed in by the researcher.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  SharedPreferences? _prefs;

  bool musicOn = true;
  bool sfxOn = true;
  StudyCondition condition = StudyCondition.adaptive;
  String childId = 'child-000000';
  String participantCode = '';
  bool useMockBackend = true;
  String baseUrl = '';
  EmotionState? simulatedKara; // test mode only; stored as KARA_SIMULATED
  int? participantAge; // whole years, researcher-entered (optional)

  /// Off by default. When true, the Support plan may send its own
  /// ALREADY-COMPUTED, non-identifying numbers (band, shares, counts -- never
  /// a raw session or a name) to the backend's /insights/summary endpoint,
  /// which may call a third-party LLM to write a friendlier paragraph. The
  /// app works exactly the same either way; this only affects whether that
  /// one extra, clearly-labelled paragraph is attempted.
  bool aiInsightsEnabled = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      musicOn = p.getBool('musicOn') ?? true;
      sfxOn = p.getBool('sfxOn') ?? true;
      condition = StudyConditionX.fromCode(p.getString('condition'));
      participantCode = p.getString('participantCode') ?? '';
      useMockBackend = p.getBool('useMock') ?? true;
      baseUrl = p.getString('baseUrl') ?? '';
      simulatedKara = emotionFromName(p.getString('simKara'));
      participantAge = p.getInt('participantAge');
      aiInsightsEnabled = p.getBool('aiInsightsEnabled') ?? false;
      var id = p.getString('childId');
      if (id == null) {
        final r = Random.secure();
        id = 'child-${List.generate(6, (_) => r.nextInt(16).toRadixString(16)).join()}';
        await p.setString('childId', id);
      }
      childId = id;
    } catch (_) {
      // Storage unavailable: keep defaults, app still works.
    }
    _applyAudio();
    notifyListeners();
  }

  void _applyAudio() {
    MusicService.instance.setMusicMuted(!musicOn);
    MusicService.instance.setEffectsMuted(!sfxOn);
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    _applyAudio();
    await _prefs?.setBool('musicOn', v);
    notifyListeners();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    _applyAudio();
    await _prefs?.setBool('sfxOn', v);
    notifyListeners();
  }

  Future<void> setCondition(StudyCondition c) async {
    condition = c;
    await _prefs?.setString('condition', c.code);
    notifyListeners();
  }

  Future<void> setParticipantCode(String v) async {
    participantCode = v.trim();
    await _prefs?.setString('participantCode', participantCode);
    notifyListeners();
  }

  Future<void> setParticipantAge(int? age) async {
    participantAge = (age == null || age < 2 || age > 18) ? null : age;
    if (participantAge == null) {
      await _prefs?.remove('participantAge');
    } else {
      await _prefs?.setInt('participantAge', participantAge!);
    }
    notifyListeners();
  }

  /// Set from the signed-in child's pseudonymous participant id.
  void setActiveChildId(String id) {
    childId = id;
    notifyListeners();
  }

  Future<void> setUseMock(bool v) async {
    useMockBackend = v;
    await _prefs?.setBool('useMock', v);
    notifyListeners();
  }

  Future<void> setAiInsightsEnabled(bool v) async {
    aiInsightsEnabled = v;
    await _prefs?.setBool('aiInsightsEnabled', v);
    notifyListeners();
  }

  Future<void> setBaseUrl(String v) async {
    baseUrl = v.trim();
    await _prefs?.setString('baseUrl', baseUrl);
    notifyListeners();
  }

  Future<void> setSimulatedKara(EmotionState? e) async {
    simulatedKara = e;
    if (e == null) {
      await _prefs?.remove('simKara');
    } else {
      await _prefs?.setString('simKara', e.name);
    }
    notifyListeners();
  }

  /// The id written into exports: researcher code if set, else the random id.
  String get exportParticipantId =>
      participantCode.isNotEmpty ? participantCode : childId;
}
