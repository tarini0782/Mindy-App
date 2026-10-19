/// How fast things move / how long each step lasts.
enum GamePace { slow, normal, fast }

extension GamePaceX on GamePace {
  String get label {
    switch (this) {
      case GamePace.slow:
        return 'Slow';
      case GamePace.normal:
        return 'Normal';
      case GamePace.fast:
        return 'Fast';
    }
  }

  /// Multiplier for movement speeds (bigger = faster).
  double get speed {
    switch (this) {
      case GamePace.slow:
        return 0.75;
      case GamePace.normal:
        return 1.0;
      case GamePace.fast:
        return 1.3;
    }
  }

  /// Multiplier for durations (bigger = longer / slower).
  double get timeScale => 1.0 / speed;
}
