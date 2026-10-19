import 'package:flutter/services.dart';
import 'character_id.dart';

/// Optional replacement art. Drop PNG files into these folders and the app
/// uses them automatically; if a file is missing the built-in vector
/// character is drawn instead, so nothing ever breaks.
///
///   assets/characters/<kara|nova|lumi|bubbles|pip|twinkle>/<state>.png
///       states: idle, happy, excited, calm, encouraging, celebrating
///       (only idle.png is required; other states fall back to idle.png)
///   assets/worlds/<magic_garden|bubble_valley|memory_castle|
///                  superhero_academy|rainbow_kingdom|dragon_valley>/background.png
///
/// Every folder must also be listed under `flutter: assets:` in pubspec.yaml
/// (see PUBSPEC_ASSETS.txt).
class CharacterAssets {
  CharacterAssets._();

  static Set<String> _available = <String>{};

  /// Call once at startup. Never throws.
  static Future<void> init() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _available = manifest.listAssets().toSet();
    } catch (_) {
      _available = <String>{};
    }
  }

  static bool has(String path) => _available.contains(path);

  static String characterPath(CharacterId id, CharacterState state) =>
      'assets/characters/${id.key}/${state.name}.png';

  /// Best available image path for this character + state, or null.
  static String? characterImage(CharacterId id, CharacterState state) {
    final exact = characterPath(id, state);
    if (has(exact)) return exact;
    final idle = characterPath(id, CharacterState.idle);
    if (has(idle)) return idle;
    return null;
  }

  static String worldBackgroundPath(String worldKey) =>
      'assets/worlds/$worldKey/background.png';

  static String? worldBackground(String worldKey) {
    final p = worldBackgroundPath(worldKey);
    return has(p) ? p : null;
  }
}
