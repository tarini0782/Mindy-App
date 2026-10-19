import 'package:audioplayers/audioplayers.dart';

/// Wraps background music + short sound effects, with independent
/// mute switches for each (Settings screen requirement: separate
/// "Music ON/OFF" and "Sound Effects ON/OFF").
///
/// Important: this app ships with NO music/sound files inside it -- I
/// can't legally include real copyrighted audio for you. Every call
/// here is wrapped in try/catch, so if the asset file is missing the
/// app just plays silently instead of crashing. See
/// assets/audio/README.txt for exactly which free, legal sources to
/// grab real files from and what to name them.
class MusicService {
  MusicService._internal();
  static final MusicService instance = MusicService._internal();

  // Created lazily: unit tests (and devices without audio) never touch the
  // audio plugin unless something is actually played.
  AudioPlayer? _bg;
  AudioPlayer? _fx;
  AudioPlayer get _bgPlayer => _bg ??= AudioPlayer();
  AudioPlayer get _effectPlayer => _fx ??= AudioPlayer();

  bool musicMuted = false;
  bool effectsMuted = false;

  String? _wantedLoop;
  String? _playingLoop;

  Future<void> playBackgroundLoop(String assetPath) async {
    _wantedLoop = assetPath;
    if (musicMuted) return;
    if (_playingLoop == assetPath) return;
    try {
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.play(AssetSource(assetPath), volume: 0.22);
      _playingLoop = assetPath;
    } catch (_) {
      _playingLoop = null;
      // Missing/invalid asset file -- ignore, app keeps working silently.
    }
  }

  Future<void> stopBackgroundLoop() async {
    _wantedLoop = null;
    _playingLoop = null;
    try {
      await _bgPlayer.stop();
    } catch (_) {}
  }

  Future<void> playEffect(String assetPath) async {
    if (effectsMuted) return;
    try {
      await _effectPlayer.play(AssetSource(assetPath), volume: 0.5);
    } catch (_) {
      // Missing/invalid asset file -- ignore.
    }
  }

  void setMusicMuted(bool value) {
    musicMuted = value;
    if (musicMuted) {
      _playingLoop = null;
      _bg?.stop().catchError((_) {});
    } else if (_wantedLoop != null) {
      playBackgroundLoop(_wantedLoop!);
    }
  }

  void setEffectsMuted(bool value) {
    effectsMuted = value;
  }
}
