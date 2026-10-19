import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/insights/condition_compare.dart';
import 'package:mindy_app/insights/sus.dart';
import 'package:mindy_app/models/emotion_state.dart';
import 'package:mindy_app/services/account_service.dart';
import 'package:mindy_app/services/usability_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SUS', () {
    test('best and worst answers', () {
      expect(susScore([5, 1, 5, 1, 5, 1, 5, 1, 5, 1]), 100);
      expect(susScore([1, 5, 1, 5, 1, 5, 1, 5, 1, 5]), 0);
      expect(susScore([3, 3, 3, 3, 3, 3, 3, 3, 3, 3]), 50);
    });
    test('rejects wrong length or out-of-range answers', () {
      expect(susScore([5, 1]), isNull);
      expect(susScore([6, 1, 5, 1, 5, 1, 5, 1, 5, 1]), isNull);
    });
    test('stores and reloads per child', () async {
      await UsabilityService.instance.load('P-AAA111');
      final s = await UsabilityService.instance
          .add([5, 1, 5, 1, 5, 1, 5, 1, 5, 1]);
      expect(s, 100);
      await UsabilityService.instance.load('P-BBB222');
      expect(UsabilityService.instance.entries, isEmpty);
      await UsabilityService.instance.load('P-AAA111');
      expect(UsabilityService.instance.entries.length, 1);
    });
  });

  group('condition comparison', () {
    test('groups sessions by study condition', () {
      final list = [
        makeSession(GameType.breathingGarden,
            before: EmotionState.scared, after: EmotionState.calm, condition: 'ADAPTIVE'),
        makeSession(GameType.breathingGarden,
            before: EmotionState.sad, after: EmotionState.sad, condition: 'FIXED_BASELINE'),
        makeSession(GameType.breathingGarden,
            before: EmotionState.sad, after: EmotionState.happy, condition: 'FIXED_BASELINE',
            completed: false),
      ];
      final st = compareByCondition(list);
      expect(st.map((s) => s.condition).toList(), ['ADAPTIVE', 'FIXED_BASELINE']);
      expect(st[0].sessions, 1);
      expect(st[1].sessions, 2);
      expect(st[1].completionRate, 0.5);
      expect(st[0].meanMoodChange! > 0, isTrue);
    });
    test('empty input gives empty output', () {
      expect(compareByCondition(const []), isEmpty);
    });
  });

  group('demo mode', () {
    test('creates a DEMO child with consent and replaces older demos', () async {
      final a = AccountService(iterations: 10);
      expect(await a.startDemo(), isNull);
      expect(a.loggedIn, isTrue);
      final c1 = a.activeChild!;
      expect(c1.isDemo, isTrue);
      expect(c1.participantId.startsWith('DEMO-'), isTrue);
      expect(c1.researchEnabled, isTrue);
      expect(await a.startDemo(), isNull);
      expect(a.activeChild!.id == c1.id, isFalse);
      expect(a.myChildren.length, 1);
    });
    test('normal children are not demo', () async {
      final a = AccountService(iterations: 10);
      expect(await a.register(username: 'parent1', password: 'abcdefg1'), isNull);
      expect(await a.addChild(nickname: 'Sam', birthYear: DateTime.now().year - 6), isNull);
      expect(a.activeChild!.isDemo, isFalse);
    });
  });
}
