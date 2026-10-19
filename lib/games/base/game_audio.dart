import '../../services/music_service.dart';

/// Tiny wrapper so games say WHAT happened (tap / success / complete),
/// not which file plays. Plays the soft sound files in assets/audio (pop, star, match); missing files are silently ignored by MusicService, and
/// the Settings "Sound effects" switch mutes everything here.
class GameAudio {
  GameAudio._();

  static void tap() => MusicService.instance.playEffect('audio/pop.wav');
  static void success() => MusicService.instance.playEffect('audio/star.wav');
  static void complete() => MusicService.instance.playEffect('audio/match.wav');
}
