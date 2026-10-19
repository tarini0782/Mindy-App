import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/carrot_catch_game.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/games/pet_care_game.dart';
import 'package:mindy_app/games/sky_flight_game.dart';
import 'package:mindy_app/games/teddy_clinic_game.dart';

void main() {
  group('four new games are registered and distinct', () {
    test('ids, titles and worlds are unique', () {
      final n = [GameType.carrotCatch, GameType.teddyClinic, GameType.skyFlight, GameType.petCare];
      expect(n.map((t) => t.id).toSet().length, 4);
      expect(n.map((t) => t.worldKey).toSet().length, 4);
      expect(GameType.values.map((t) => t.id).toSet().length, GameType.values.length);
    });
  });

  group('Carrot Catch', () {
    test('level 1 has no rocks, level 5 is faster with more items', () {
      expect(CarrotParams.forLevel(1).rockChance, 0);
      expect(CarrotParams.forLevel(5).speed > CarrotParams.forLevel(1).speed, isTrue);
      expect(CarrotParams.forLevel(5).maxItems > CarrotParams.forLevel(1).maxItems, isTrue);
    });
    test('catch test uses basket width', () {
      expect(CarrotLogic.caught(100, 120, 96), isTrue);
      expect(CarrotLogic.caught(300, 120, 96), isFalse);
    });
    test('never spawns a rock when no good item is falling', () {
      final r = Random(1);
      for (var i = 0; i < 100; i++) {
        expect(CarrotLogic.nextIsRock(r, 1.0, needGood: true), isFalse);
      }
    });
  });

  group('Teddy Clinic', () {
    test('tray always contains the needed tool and has the right size', () {
      final r = Random(3);
      for (final c in kCases) {
        for (final steps in [1, 2]) {
          final plan = ClinicLogic.plan(c, steps);
          expect(plan.length, steps);
          for (var s = 0; s < plan.length; s++) {
            for (final size in [2, 3, 4, 5]) {
              final tray = ClinicLogic.tray(plan, s, size, r);
              expect(tray.any((t) => t.id == plan[s]), isTrue);
              expect(tray.length, size);
              expect(tray.map((t) => t.id).toSet().length, tray.length);
            }
          }
        }
      }
    });
    test('every plan only uses known tools', () {
      final ids = kTools.map((t) => t.id).toSet();
      for (final c in kCases) {
        for (final id in [...c.steps1, ...c.steps2]) {
          expect(ids.contains(id), isTrue, reason: id);
        }
      }
    });
    test('two-step levels start at level 4', () {
      expect(ClinicParams.forLevel(3).steps, 1);
      expect(ClinicParams.forLevel(4).steps, 2);
    });
  });

  group('Sky Flight', () {
    test('collision is a circle', () {
      expect(SkyLogic.hit(10, 10, 20), isTrue);
      expect(SkyLogic.hit(30, 30, 20), isFalse);
    });
    test('no cloud is spawned unless a star is already on screen', () {
      final r = Random(2);
      for (var i = 0; i < 100; i++) {
        expect(SkyLogic.nextIsCloud(r, 1.0, starOnScreen: false), isFalse);
      }
    });
    test('harder levels fly faster', () {
      expect(SkyParams.forLevel(5).speed > SkyParams.forLevel(1).speed, isTrue);
    });
  });

  group("Puffy's Day", () {
    test('the next need always differs from the previous one', () {
      final r = Random(5);
      Need? prev;
      for (var i = 0; i < 200; i++) {
        final n = PetLogic.next(r, prev);
        expect(n.id == prev?.id, isFalse);
        prev = n;
      }
    });
    test('tray holds the needed item', () {
      final r = Random(9);
      for (final n in kNeeds) {
        final t = PetLogic.tray(n, 3, r);
        expect(t.any((x) => x.id == n.id), isTrue);
        expect(t.length, 3);
      }
    });
  });
}
