import 'package:flutter/material.dart';

/// The Mindy cast: six ORIGINAL characters (none copied from any
/// commercial franchise). Names, colours and personalities are Mindy's own.
///
/// v29: all six are drawn as CHILDREN, in the same visual language as the
/// character a child makes for themselves. They used to be creatures -- a
/// unicorn, a baby dragon, a fairy -- which read as monsters once drawn as
/// flat shapes. Names and personalities are unchanged.
enum CharacterId { kara, nova, lumi, bubbles, pip, twinkle }

/// Simple animation states every character supports (2D, no 3D needed).
enum CharacterState { idle, happy, excited, calm, encouraging, celebrating }

class CharacterInfo {
  final String displayName;
  final String role;
  final String emoji; // used only as a tiny label / fallback text
  final Color main;
  final Color accent;
  const CharacterInfo(this.displayName, this.role, this.emoji, this.main,
      this.accent);
}

const Map<CharacterId, CharacterInfo> _info = {
  CharacterId.kara: CharacterInfo(
      'Kara',
      'The friend who welcomes you and guides the journey',
      '\u{1F984}',
      Color(0xFFFFF1FA),
      Color(0xFFFF8AD0)),
  CharacterId.nova: CharacterInfo(
      'Nova',
      'A brave kid in a cape who cheers you on in Pattern Power',
      '\u{1F9B8}',
      Color(0xFF4F7CFF),
      Color(0xFFFF5A6A)),
  CharacterId.lumi: CharacterInfo(
      'Lumi',
      'A kind, calm kid who keeps the Memory Castle',
      '\u{1F451}',
      Color(0xFFF6C3FF),
      Color(0xFFB57BFF)),
  CharacterId.bubbles: CharacterInfo(
      'Bubbles',
      'A playful kid who collects magical bubbles',
      '\u{1F430}',
      Color(0xFFFFFFFF),
      Color(0xFFFFA8C8)),
  CharacterId.pip: CharacterInfo(
      'Pip',
      'A friendly young explorer who collects stars and gems',
      '\u{1F409}',
      Color(0xFF6FDD9C),
      Color(0xFFFFD166)),
  CharacterId.twinkle: CharacterInfo(
      'Twinkle',
      'A quiet kid with a lantern who guides gentle breathing',
      '\u{1F9DA}',
      Color(0xFFFFE2CF),
      Color(0xFF8EDCF5)),
};

extension CharacterIdX on CharacterId {
  CharacterInfo get info => _info[this]!;
  String get displayName => info.displayName;
  String get role => info.role;
  String get emoji => info.emoji;
  Color get main => info.main;
  Color get accent => info.accent;

  /// Folder name for optional replacement art:
  /// assets/characters/<key>/<state>.png
  String get key => name;
}
