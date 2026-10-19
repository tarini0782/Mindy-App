import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_app/games/models/game_type.dart';
import 'package:mindy_app/services/account_service.dart';
import 'package:mindy_app/services/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

String _hex(List<int> b) =>
    b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AccountService svc() => AccountService(iterations: 10);

  group('PBKDF2-HMAC-SHA256 (reference vectors computed with Python hashlib)', () {
    test('known answers', () {
      final salt = utf8.encode('salt');
      expect(_hex(PasswordHasher.pbkdf2('password', salt, 1)),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      expect(_hex(PasswordHasher.pbkdf2('password', salt, 2)),
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
      expect(_hex(PasswordHasher.pbkdf2('password', salt, 4096)),
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });

    test('constant-time equal behaves', () {
      expect(PasswordHasher.equal('abc', 'abc'), isTrue);
      expect(PasswordHasher.equal('abc', 'abd'), isFalse);
      expect(PasswordHasher.equal('abc', 'abcd'), isFalse);
    });
  });

  group('validation', () {
    test('username, password, nickname, birth year', () {
      expect(Validation.username('ab'), isNotNull);
      expect(Validation.username('good_name.1'), isNull);
      expect(Validation.password('short1'), isNotNull);
      expect(Validation.password('longlongpass'), isNotNull); // no digit
      expect(Validation.password('12345678'), isNotNull); // no letter
      expect(Validation.password('abcd1234'), isNull);
      expect(Validation.nickname('  '), isNotNull);
      expect(Validation.nickname('Mia'), isNull);
      expect(Validation.birthYear(2000, nowYear: 2026), isNotNull);
      expect(Validation.birthYear(2020, nowYear: 2026), isNull);
      expect(Validation.birthYear(2026, nowYear: 2026), isNotNull);
      expect(Validation.birthYear(null), isNotNull);
    });
  });

  group('registration and login', () {
    test('register, logout, wrong password, right password', () async {
      final a = svc();
      expect(await a.register(username: 'Parent1', password: 'abcd1234'), isNull);
      expect(a.loggedIn, isTrue);
      await a.logout();
      expect(a.loggedIn, isFalse);
      expect(await a.login('parent1', 'wrongpass1'), isNotNull);
      expect(a.loggedIn, isFalse);
      expect(await a.login('PARENT1', 'abcd1234'), isNull);
      expect(a.loggedIn, isTrue);
      expect(a.isResearcher, isFalse);
    });

    test('unknown user and wrong password give the same message', () async {
      final a = svc();
      await a.register(username: 'parent1', password: 'abcd1234');
      await a.logout();
      final m1 = await a.login('nobody', 'abcd1234');
      final m2 = await a.login('parent1', 'zzzz9999');
      expect(m1, m2);
    });

    test('duplicate username and weak password are refused', () async {
      final a = svc();
      expect(await a.register(username: 'parent1', password: 'abcd1234'), isNull);
      expect(await a.register(username: 'parent1', password: 'abcd1234'), isNotNull);
      expect(await a.register(username: 'other', password: 'weak'), isNotNull);
    });

    test('no plaintext password in storage; hash and salt are present', () async {
      final a = svc();
      await a.register(username: 'parent1', password: 'SecretPass9');
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('mindy_accounts_v1')!;
      expect(raw.contains('SecretPass9'), isFalse);
      final j = (jsonDecode(raw) as List).first as Map;
      expect(j['hash'], isNotEmpty);
      expect(j['salt'], isNotEmpty);
      expect(j['iterations'], 10);
    });

    test('researcher registration is disabled when no study code is compiled in', () async {
      final a = svc();
      final err = await a.register(
          username: 'staff1',
          password: 'abcd1234',
          asResearcher: true,
          studyCodeEntered: 'anything');
      if (AccountService.studyCode.isEmpty) {
        expect(err, isNotNull);
        expect(a.isResearcher, isFalse);
      }
    });

    test('login survives an app restart (load)', () async {
      final a = svc();
      await a.register(username: 'parent1', password: 'abcd1234');
      final b = svc();
      await b.load();
      expect(b.loggedIn, isTrue);
      expect(b.user!.username, 'parent1');
    });
  });

  group('children, ownership and consent', () {
    test('child gets a pseudonymous id; nickname is not the id', () async {
      final a = svc();
      await a.register(username: 'parent1', password: 'abcd1234');
      expect(await a.addChild(nickname: 'Mia', birthYear: DateTime.now().year - 5),
          isNull);
      final c = a.activeChild!;
      expect(RegExp(r'^P-[A-Z2-9]{6}$').hasMatch(c.participantId), isTrue);
      expect(c.participantId.contains('Mia'), isFalse);
      expect(c.researchEnabled, isFalse);
      expect(c.consentAnswered, isFalse);
    });

    test('participant ids are unique', () {
      final r = Random(1);
      final ids = {for (var i = 0; i < 200; i++) AccountService.newParticipantId(r)};
      expect(ids.length, greaterThan(190));
    });

    test('research is on only when caregiver AND child agree', () async {
      final a = svc();
      await a.register(username: 'parent1', password: 'abcd1234');
      await a.addChild(nickname: 'Mia', birthYear: DateTime.now().year - 5);
      final id = a.activeChild!.id;
      await a.recordConsent(id, caregiverAgrees: true, childAgrees: false);
      expect(a.activeChild!.researchEnabled, isFalse);
      await a.recordConsent(id, caregiverAgrees: false, childAgrees: true);
      expect(a.activeChild!.researchEnabled, isFalse);
      await a.recordConsent(id, caregiverAgrees: true, childAgrees: true);
      expect(a.activeChild!.researchEnabled, isTrue);
      expect(a.activeChild!.consentVersion, kConsentVersion);
      expect(a.activeChild!.consentAt, isNotNull);
    });

    test('another account cannot see, select, edit or delete my child', () async {
      final a = svc();
      await a.register(username: 'parent1', password: 'abcd1234');
      await a.addChild(nickname: 'Mia', birthYear: DateTime.now().year - 5);
      final childId = a.activeChild!.id;
      await a.logout();
      await a.register(username: 'parent2', password: 'abcd1234');
      expect(a.myChildren, isEmpty);
      await a.selectChild(childId);
      expect(a.activeChild, isNull);
      expect(await a.deleteChild(childId), isNotNull);
      expect(await a.updateChild(childId, nickname: 'X'), isNotNull);
      expect(await a.recordConsent(childId, caregiverAgrees: true, childAgrees: true),
          isNotNull);
    });

    test('deleting a child calls the erase hook and removes the profile', () async {
      final a = svc();
      String? erased;
      a.onChildDeleted = (c) async => erased = c.participantId;
      await a.register(username: 'parent1', password: 'abcd1234');
      await a.addChild(nickname: 'Mia', birthYear: DateTime.now().year - 5);
      final c = a.activeChild!;
      expect(await a.deleteChild(c.id), isNull);
      expect(erased, c.participantId);
      expect(a.myChildren, isEmpty);
    });

    test('deleting the account needs the password and erases all children', () async {
      final a = svc();
      final erased = <String>[];
      a.onChildDeleted = (c) async => erased.add(c.participantId);
      await a.register(username: 'parent1', password: 'abcd1234');
      await a.addChild(nickname: 'Mia', birthYear: DateTime.now().year - 5);
      await a.addChild(nickname: 'Leo', birthYear: DateTime.now().year - 7);
      expect(await a.deleteAccount('wrongpass1'), isNotNull);
      expect(erased, isEmpty);
      expect(await a.deleteAccount('abcd1234'), isNull);
      expect(erased.length, 2);
      expect(a.loggedIn, isFalse);
      expect(await a.login('parent1', 'abcd1234'), isNotNull);
    });
  });

  group('session data is scoped to the active child', () {
    test('only the active child\'s sessions are visible; researcher view sees all',
        () async {
      final repo = SessionRepository.instance;
      await repo.clear();
      final s1 = makeSession(GameType.beeCollector);
      final s2 = makeSession(GameType.dinoDash);
      // makeSession uses a fixed test child id; make the second differ
      final s2b = makeSessionFor('P-OTHER1', GameType.dinoDash);
      await repo.add(s1);
      await repo.add(s2b);
      repo.setActiveChild(s1.anonymousChildId);
      expect(repo.chronological.map((s) => s.sessionId), [s1.sessionId]);
      repo.setActiveChild('P-OTHER1');
      expect(repo.chronological.map((s) => s.sessionId), [s2b.sessionId]);
      repo.setActiveChild(null);
      expect(repo.allChronological.length, 2);
      repo.setActiveChild('nobody');
      expect(repo.chronological, isEmpty);
      expect(s2.sessionId, isNotEmpty);
    });

    test('deleteForChild erases only that child', () async {
      final repo = SessionRepository.instance;
      await repo.clear();
      final a = makeSessionFor('P-AAAAAA', GameType.beeCollector);
      final b = makeSessionFor('P-BBBBBB', GameType.beeCollector);
      await repo.add(a);
      await repo.add(b);
      await repo.deleteForChild('P-AAAAAA');
      expect(repo.allChronological.map((s) => s.sessionId), [b.sessionId]);
      repo.setActiveChild(null);
    });
  });
}
