import 'package:flutter/material.dart';

/// Optional, free customization for Kara (no purchases, no currency).
/// In-memory like the rest of the local state.
class CompanionLook {
  final int colorIndex;
  final int accessoryIndex;
  const CompanionLook({this.colorIndex = 0, this.accessoryIndex = 0});

  static const List<Color> colors = [
    Color(0xFFFFF1FA), // blossom
    Color(0xFFDDF3FF), // sky
    Color(0xFFDDF8E8), // mint
    Color(0xFFFFF5CC), // lemon
  ];
  static const List<String> colorNames = ['Blossom', 'Sky', 'Mint', 'Lemon'];

  static const List<String> accessoryNames = [
    'None',
    'Crown',
    'Party hat',
    'Bow',
    'Cape',
  ];
  static const List<String> accessoryEmoji = [
    '\u2728',
    '\u{1F451}',
    '\u{1F389}',
    '\u{1F380}',
    '\u{1F9B8}',
  ];

  Color get bodyColor => colors[colorIndex.clamp(0, colors.length - 1).toInt()];
  int get accessory =>
      accessoryIndex.clamp(0, accessoryNames.length - 1).toInt();

  CompanionLook copyWith({int? colorIndex, int? accessoryIndex}) =>
      CompanionLook(
        colorIndex: colorIndex ?? this.colorIndex,
        accessoryIndex: accessoryIndex ?? this.accessoryIndex,
      );
}

class CompanionService extends ChangeNotifier {
  CompanionService._();
  static final CompanionService instance = CompanionService._();

  CompanionLook _look = const CompanionLook();
  CompanionLook get look => _look;

  void setLook(CompanionLook look) {
    _look = look;
    notifyListeners();
  }

  void reset() {
    _look = const CompanionLook();
    notifyListeners();
  }
}
