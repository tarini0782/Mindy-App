import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/screens/game_library_screen.dart';

void main() {
  test('no filter shows every registered game (no hidden cap)', () {
    expect(_all().length, GameType.values.length);
  });
  test('category filter only returns that category', () {
    final r = GameLibraryScreen.filterGames(GameType.values,
        category: GameCategory.calming);
    expect(r.every((g) => g.category == GameCategory.calming), isTrue);
  });
  test('search matches title and is case-insensitive', () {
    final r = GameLibraryScreen.filterGames(GameType.values, query: 'FOX');
    expect(r.contains(GameType.sleepyFox), isTrue);
  });
  test('favourites filter', () {
    final r = GameLibraryScreen.filterGames(GameType.values,
        onlyFavourites: true, favourites: {GameType.turboCar.id});
    expect(r, [GameType.turboCar]);
  });
}

List<GameType> _all() =>
    GameLibraryScreen.filterGames(GameType.values);
