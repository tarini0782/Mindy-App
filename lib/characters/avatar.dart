import 'package:flutter/material.dart';

/// MINDY AVATAR -- the child's own character.
///
/// Everything here is drawn in code (see avatar_painter.dart), so the app
/// needs no character artwork to ship and nothing is copied from any
/// commercial character or franchise. Each choice is stored as a small
/// integer index, so a saved character is a handful of numbers.
///
/// Design rules:
///  * every combination is valid -- there is no way to make a broken avatar
///  * nothing is locked, bought, earned or hidden behind progress
///  * no option is gendered in its name; children pick what they like
@immutable
class MindyAvatar {
  final String name;
  final int skin;
  final int hairStyle;
  final int hairColor;
  final int outfit;
  final int outfitColor;
  final int headwear;
  final int wings;
  final int face;
  final int extra;

  /// v42: shoes became a real part rather than being tinted from the
  /// outfit colour. Defaults to 0, so every character saved before this
  /// loads with trainers instead of failing.
  final int shoes;

  const MindyAvatar({
    this.name = 'My character',
    this.skin = 2,
    this.hairStyle = 0,
    this.hairColor = 0,
    this.outfit = 0,
    this.outfitColor = 0,
    this.headwear = 0,
    this.wings = 0,
    this.face = 0,
    this.extra = 0,
    this.shoes = 0,
  });

  MindyAvatar copyWith({
    String? name,
    int? skin,
    int? hairStyle,
    int? hairColor,
    int? outfit,
    int? outfitColor,
    int? headwear,
    int? wings,
    int? face,
    int? extra,
    int? shoes,
  }) =>
      MindyAvatar(
        name: name ?? this.name,
        skin: skin ?? this.skin,
        hairStyle: hairStyle ?? this.hairStyle,
        hairColor: hairColor ?? this.hairColor,
        outfit: outfit ?? this.outfit,
        outfitColor: outfitColor ?? this.outfitColor,
        headwear: headwear ?? this.headwear,
        shoes: shoes ?? this.shoes,
        wings: wings ?? this.wings,
        face: face ?? this.face,
        extra: extra ?? this.extra,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'skin': skin,
        'hairStyle': hairStyle,
        'hairColor': hairColor,
        'outfit': outfit,
        'outfitColor': outfitColor,
        'headwear': headwear,
        'wings': wings,
        'face': face,
        'extra': extra,
        'shoes': shoes,
      };

  /// Tolerant of missing or out-of-range values: a saved character from an
  /// older version still loads, clamped into range, instead of crashing.
  factory MindyAvatar.fromJson(Map<String, dynamic> j) {
    int pick(String key, int max, int fallback) {
      final v = j[key];
      if (v is int) return v.clamp(0, max - 1).toInt();
      return fallback;
    }

    return MindyAvatar(
      name: (j['name'] as String?)?.trim().isNotEmpty == true
          ? j['name'] as String
          : 'My character',
      skin: pick('skin', AvatarOptions.skins.length, 2),
      hairStyle: pick('hairStyle', AvatarOptions.hairStyles.length, 0),
      hairColor: pick('hairColor', AvatarOptions.hairColors.length, 0),
      outfit: pick('outfit', AvatarOptions.outfits.length, 0),
      outfitColor: pick('outfitColor', AvatarOptions.outfitColors.length, 0),
      headwear: pick('headwear', AvatarOptions.headwear.length, 0),
      wings: pick('wings', AvatarOptions.wings.length, 0),
      face: pick('face', AvatarOptions.faces.length, 0),
      extra: pick('extra', AvatarOptions.extras.length, 0),
      shoes: pick('shoes', AvatarOptions.shoes.length, 0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MindyAvatar &&
      other.name == name &&
      other.skin == skin &&
      other.hairStyle == hairStyle &&
      other.hairColor == hairColor &&
      other.outfit == outfit &&
      other.outfitColor == outfitColor &&
      other.headwear == headwear &&
      other.wings == wings &&
      other.face == face &&
      other.extra == extra &&
      other.shoes == shoes;

  @override
  int get hashCode => Object.hash(name, skin, hairStyle, hairColor, outfit,
      outfitColor, headwear, wings, face, extra, shoes);
}

/// Every choice the creator offers. Names are what the child sees, so they
/// are short, plain and friendly.
class AvatarOptions {
  AvatarOptions._();

  static const List<Color> skins = [
    Color(0xFFFFE0C4),
    Color(0xFFF6C99B),
    Color(0xFFE0A579),
    Color(0xFFC07E55),
    Color(0xFF9A5E3C),
    Color(0xFF6B4027),
  ];
  static const List<String> skinNames = [
    'Light', 'Warm', 'Golden', 'Tan', 'Deep', 'Rich',
  ];

  /// Every style is available to every character. Indices 0-5 are the
  /// original six and never move, so a character saved before v42 keeps
  /// exactly the hair it had.
  static const List<String> hairStyles = [
    'Short', 'Bob', 'Long', 'Curly', 'Two buns', 'Ponytail',
    'Braids', 'Crew cut', 'Spiky', 'Side part', 'Afro', 'Buzz cut',
    'Mohawk', 'Wavy',
  ];
  static const List<Color> hairColors = [
    Color(0xFF3B2A20), // dark brown
    Color(0xFF14110F), // black
    Color(0xFF8B5E3C), // chestnut
    Color(0xFFE8B45C), // golden
    Color(0xFFD6604B), // ginger
    Color(0xFF9B6BD6), // violet
    Color(0xFF4FB6D9), // aqua
    Color(0xFFEE86B7), // pink
  ];
  static const List<String> hairColorNames = [
    'Brown', 'Black', 'Chestnut', 'Golden', 'Ginger', 'Violet', 'Aqua', 'Pink',
  ];

  static const List<String> outfits = [
    'T-shirt', 'Hoodie', 'Dress', 'Dungarees', 'Space suit', 'Cape top',
    'Shirt & shorts', 'Prince tunic', 'Armour', 'Hero suit', 'Explorer vest',
  ];
  static const List<Color> outfitColors = [
    Color(0xFF6C74D9), // periwinkle
    Color(0xFF14A3A0), // teal
    Color(0xFFFFB44D), // mango
    Color(0xFFEE86B7), // pink
    Color(0xFF7FC25C), // leaf
    Color(0xFFF4694F), // coral
  ];
  static const List<String> outfitColorNames = [
    'Periwinkle', 'Teal', 'Mango', 'Pink', 'Leaf', 'Coral',
  ];

  // v41: 'Unicorn horn' became 'Wizard hat'. Same index, so every saved
  // character keeps working; it just reads as adventure rather than as a
  // leftover unicorn.
  static const List<String> headwear = [
    'None', 'Crown', 'Party hat', 'Cap', 'Flower band', 'Wizard hat',
    'Tiara', 'Bow', 'Knight helmet', 'Baseball cap', 'Beanie',
    'Pirate hat', 'Explorer hat',
  ];
  static const List<String> wings = [
    'None', 'Butterfly', 'Fairy', 'Dragon',
  ];
  /// v43: 'Sad', 'Scared' and 'Okay' were added so the check-in can show
  /// the child's OWN friend at each feeling instead of five unrelated
  /// creatures. Appended, so indices 0-3 keep their meaning.
  static const List<String> faces = [
    'Smile', 'Big smile', 'Calm', 'Surprised', 'Sad', 'Scared', 'Okay',
  ];

  /// Which face goes with which feeling on the check-in cards.
  /// Index 5 scared, 4 sad, 6 okay, 2 calm, 1 happy — matching the order
  /// of `EmotionState`. Kept here, beside the faces themselves, so the two
  /// cannot drift apart.
  static const List<int> faceForEmotionIndex = [5, 4, 6, 2, 1];
  static const List<String> extras = [
    'None', 'Glasses', 'Freckles', 'Rosy cheeks', 'Scarf',
  ];
  static const List<String> shoes = [
    'Trainers', 'Boots', 'Party shoes', 'Sandals', 'Royal shoes',
  ];

  /// A few ready-made characters, offered as a starting point so a child
  /// who does not want to choose everything still gets something they like.
  static const List<MindyAvatar> presets = [
    MindyAvatar(
        name: 'Garden Fairy',
        skin: 0,
        hairStyle: 2, // long
        hairColor: 7, // pink
        outfit: 2, // dress
        outfitColor: 0,
        headwear: 4, // flower band
        wings: 1, // butterfly
        face: 0,
        extra: 2,
        shoes: 2),
    MindyAvatar(
        name: 'Brave Hero',
        skin: 3,
        hairStyle: 7, // crew cut
        hairColor: 1,
        outfit: 9, // hero suit
        outfitColor: 1,
        headwear: 0,
        wings: 0,
        face: 1,
        extra: 0,
        shoes: 1),
    MindyAvatar(
        name: 'Royal Princess',
        skin: 1,
        hairStyle: 4, // two buns
        hairColor: 3,
        outfit: 2, // dress
        outfitColor: 3,
        headwear: 6, // tiara
        wings: 0,
        face: 0,
        extra: 3,
        shoes: 2),
    MindyAvatar(
        name: 'Young King',
        skin: 2,
        hairStyle: 9, // side part
        hairColor: 2,
        outfit: 7, // prince tunic
        outfitColor: 0,
        headwear: 1, // crown
        wings: 0,
        face: 0,
        extra: 0,
        shoes: 4),
    MindyAvatar(
        name: 'Forest Explorer',
        skin: 4,
        hairStyle: 10, // afro
        hairColor: 1,
        outfit: 10, // explorer vest
        outfitColor: 2,
        headwear: 12, // explorer hat
        wings: 0,
        face: 1,
        extra: 2,
        shoes: 1),
    MindyAvatar(
        name: 'Brave Knight',
        skin: 0,
        hairStyle: 0, // short
        hairColor: 0,
        outfit: 8, // armour
        outfitColor: 4,
        headwear: 8, // knight helmet
        wings: 0,
        face: 0,
        extra: 0,
        shoes: 1),
    MindyAvatar(
        name: 'Sky Dragon',
        skin: 3,
        hairStyle: 8, // spiky
        hairColor: 6,
        outfit: 1, // hoodie
        outfitColor: 1,
        headwear: 0,
        wings: 3, // dragon
        face: 2,
        extra: 1,
        shoes: 0),
    MindyAvatar(
        name: 'Star Wizard',
        skin: 5,
        hairStyle: 13, // wavy
        hairColor: 5,
        outfit: 5, // cape top
        outfitColor: 0,
        headwear: 5, // wizard hat
        wings: 0,
        face: 0,
        extra: 0,
        shoes: 1),
  ];
}
