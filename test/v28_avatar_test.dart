import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/characters/avatar.dart';
import 'package:mindy_app/characters/avatar_painter.dart';
import 'package:mindy_app/screens/character_creator_screen.dart';
import 'package:mindy_app/services/avatar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AvatarService.instance.load('child-test');
  });

  group('the model cannot be put in a broken state', () {
    test('a fresh avatar is valid and has a name', () {
      const a = MindyAvatar();
      expect(a.name.isNotEmpty, isTrue);
      expect(a.skin, inInclusiveRange(0, AvatarOptions.skins.length - 1));
    });

    test('out-of-range or missing saved values are clamped, not crashed', () {
      final a = MindyAvatar.fromJson(const {
        'name': '',
        'skin': 99,
        'hairStyle': -4,
        // every other key deliberately absent
      });
      expect(a.skin, AvatarOptions.skins.length - 1);
      expect(a.hairStyle, 0);
      expect(a.name, 'My character');
    });

    test('a round trip through json preserves every choice', () {
      const a = MindyAvatar(
        name: 'Sky Dragon',
        skin: 3, hairStyle: 4, hairColor: 6, outfit: 1,
        outfitColor: 1, headwear: 5, wings: 3, face: 2, extra: 1,
      );
      expect(MindyAvatar.fromJson(a.toJson()), a);
    });

    test('every preset is in range for every option list', () {
      for (final p in AvatarOptions.presets) {
        expect(p.skin, lessThan(AvatarOptions.skins.length));
        expect(p.hairStyle, lessThan(AvatarOptions.hairStyles.length));
        expect(p.hairColor, lessThan(AvatarOptions.hairColors.length));
        expect(p.outfit, lessThan(AvatarOptions.outfits.length));
        expect(p.outfitColor, lessThan(AvatarOptions.outfitColors.length));
        expect(p.headwear, lessThan(AvatarOptions.headwear.length));
        expect(p.wings, lessThan(AvatarOptions.wings.length));
        expect(p.face, lessThan(AvatarOptions.faces.length));
        expect(p.extra, lessThan(AvatarOptions.extras.length));
      }
    });

    test('option names and colour lists line up', () {
      expect(AvatarOptions.skinNames.length, AvatarOptions.skins.length);
      expect(AvatarOptions.hairColorNames.length,
          AvatarOptions.hairColors.length);
      expect(AvatarOptions.outfitColorNames.length,
          AvatarOptions.outfitColors.length);
    });
  });

  group('saving and switching characters', () {
    test('saves, persists across a reload, and stays active', () async {
      const a = MindyAvatar(name: 'Star Explorer', skin: 1, wings: 2);
      await AvatarService.instance.save(a);
      expect(AvatarService.instance.active.name, 'Star Explorer');

      await AvatarService.instance.load('child-test'); // simulate restart
      expect(AvatarService.instance.saved.length, 1);
      expect(AvatarService.instance.active.wings, 2);
    });

    test('characters are scoped per child', () async {
      await AvatarService.instance.save(const MindyAvatar(name: 'Child A'));
      await AvatarService.instance.load('child-other');
      expect(AvatarService.instance.saved, isEmpty,
          reason: 'another child must not see the first child\'s character');
      await AvatarService.instance.load('child-test');
      expect(AvatarService.instance.active.name, 'Child A');
    });

    test('editing replaces in place rather than adding a duplicate', () async {
      await AvatarService.instance.save(const MindyAvatar(name: 'First'));
      await AvatarService.instance
          .save(const MindyAvatar(name: 'First, changed'), replaceIndex: 0);
      expect(AvatarService.instance.saved.length, 1);
      expect(AvatarService.instance.active.name, 'First, changed');
    });

    test('never keeps more than maxSaved, dropping the oldest', () async {
      for (var i = 0; i < AvatarService.maxSaved + 2; i++) {
        await AvatarService.instance.save(MindyAvatar(name: 'C$i'));
      }
      expect(AvatarService.instance.saved.length, AvatarService.maxSaved);
      expect(AvatarService.instance.saved.first.name, 'C2',
          reason: 'the two oldest should have been dropped');
      expect(AvatarService.instance.active.name,
          'C${AvatarService.maxSaved + 1}');
    });

    test('deleting a character keeps the active index in range', () async {
      await AvatarService.instance.save(const MindyAvatar(name: 'A'));
      await AvatarService.instance.save(const MindyAvatar(name: 'B'));
      await AvatarService.instance.delete(1);
      expect(AvatarService.instance.saved.length, 1);
      expect(AvatarService.instance.active.name, 'A');
    });

    test('clearing a child removes their characters', () async {
      await AvatarService.instance.save(const MindyAvatar(name: 'Gone'));
      await AvatarService.instance.clearForChild('child-test');
      expect(AvatarService.instance.saved, isEmpty);
      await AvatarService.instance.load('child-test');
      expect(AvatarService.instance.saved, isEmpty);
    });

    test('there is always a character to draw, even with none saved', () {
      expect(AvatarService.instance.hasChosen, isFalse);
      expect(AvatarService.instance.active, isA<MindyAvatar>());
    });
  });

  group('it draws and it saves', () {
    testWidgets('every preset renders without throwing', (tester) async {
      for (final p in AvatarOptions.presets) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Center(child: AvatarView(p, size: 120))),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('the creator opens and saving stores a character',
        (tester) async {
      await tester.pumpWidget(
          const MaterialApp(home: CharacterCreatorScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('This is me!'), findsOneWidget);
      await tester.tap(find.text('This is me!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(AvatarService.instance.saved.length, 1);
    });
  });
}
