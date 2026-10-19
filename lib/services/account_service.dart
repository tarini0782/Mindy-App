import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// LOCAL, PROTOTYPE-ONLY accounts for the Mindy research app.
///
/// What it does: registration, login, logout, caregiver->child ownership,
/// consent records, a researcher role, and deletion of an account / a child.
/// What it is NOT: a server. Everything lives on this device in
/// shared_preferences (not encrypted at rest). Passwords are never stored in
/// plain text: only a salted PBKDF2-HMAC-SHA256 hash. There is no e-mail, so
/// there is no "forgot password" delivery: the only recovery is deleting the
/// account (which also deletes its children's play data). A real deployment
/// needs a server, TLS, a slow password hash (Argon2id/bcrypt/scrypt) and
/// proper account recovery. See docs/ACCOUNT_AND_PRIVACY_DESIGN.md.
class PasswordHasher {
  PasswordHasher._();

  static List<int> randomSalt([int length = 16]) {
    final r = Random.secure();
    return List<int>.generate(length, (_) => r.nextInt(256));
  }

  /// PBKDF2-HMAC-SHA256, one 32-byte block.
  static List<int> pbkdf2(String password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final t = List<int>.of(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  static String hash(String password, List<int> salt, int iterations) =>
      base64Encode(pbkdf2(password, salt, iterations));

  /// Constant-time comparison of two equal-purpose hashes.
  static bool equal(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

class Validation {
  Validation._();
  static final RegExp _user = RegExp(r'^[a-z0-9_.-]{3,32}$');

  static String? username(String v) => _user.hasMatch(v.trim().toLowerCase())
      ? null
      : 'Use 3-32 letters, numbers, dot, dash or underscore.';

  static String? password(String v) {
    if (v.length < 8) return 'Use at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'[0-9]').hasMatch(v)) {
      return 'Use at least one letter and one number.';
    }
    return null;
  }

  static String? nickname(String v) {
    final t = v.trim();
    if (t.isEmpty || t.length > 20) return 'Use 1-20 characters.';
    return null;
  }

  /// Birth YEAR only (not a full date of birth) to minimise personal data.
  static String? birthYear(int? y, {int? nowYear}) {
    final now = nowYear ?? DateTime.now().year;
    if (y == null) return 'Enter a birth year.';
    if (y < now - 18 || y > now - 2) return 'Child should be 2-18 years old.';
    return null;
  }
}

enum Role { caregiver, researcher }

class Account {
  final String id;
  final String username;
  final String salt; // base64
  final String hash; // base64
  final int iterations;
  final Role role;
  final DateTime createdAt;
  const Account({
    required this.id,
    required this.username,
    required this.salt,
    required this.hash,
    required this.iterations,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'salt': salt,
        'hash': hash,
        'iterations': iterations,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String,
        username: j['username'] as String,
        salt: j['salt'] as String,
        hash: j['hash'] as String,
        iterations: (j['iterations'] as num).toInt(),
        role: j['role'] == 'researcher' ? Role.researcher : Role.caregiver,
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Version of the consent wording shown to the caregiver. Bump when the text
/// changes so old consents are not mistaken for new ones.
const String kConsentVersion = 'consent-v1-2026-10';

/// Participant-code prefix that marks demo data (never uploaded, never real).
const String kDemoPrefix = 'DEMO-';

class ChildProfile {
  final String id;
  final String accountId; // the responsible caregiver
  String nickname; // optional display name; NEVER exported
  int birthYear;
  final String participantId; // pseudonymous research code, e.g. P-7K3F9A
  final DateTime createdAt;
  bool researchConsent; // caregiver agreed to research data on this device
  bool childAssent; // child said "yes" to the simple assent screen
  String? consentVersion;
  DateTime? consentAt;

  ChildProfile({
    required this.id,
    required this.accountId,
    required this.nickname,
    required this.birthYear,
    required this.participantId,
    required this.createdAt,
    this.researchConsent = false,
    this.childAssent = false,
    this.consentVersion,
    this.consentAt,
  });

  /// Research sessions are stored only when BOTH agreed.
  bool get researchEnabled => researchConsent && childAssent;

  /// Demo profiles use a DEMO- participant code. Their data is never uploaded
  /// and is labelled "DEMO - NOT REAL PARTICIPANT DATA".
  bool get isDemo => participantId.startsWith(kDemoPrefix);
  bool get consentAnswered => consentAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountId': accountId,
        'nickname': nickname,
        'birthYear': birthYear,
        'participantId': participantId,
        'createdAt': createdAt.toIso8601String(),
        'researchConsent': researchConsent,
        'childAssent': childAssent,
        'consentVersion': consentVersion,
        'consentAt': consentAt?.toIso8601String(),
      };

  factory ChildProfile.fromJson(Map<String, dynamic> j) => ChildProfile(
        id: j['id'] as String,
        accountId: j['accountId'] as String,
        nickname: (j['nickname'] as String?) ?? '',
        birthYear: (j['birthYear'] as num).toInt(),
        participantId: j['participantId'] as String,
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        researchConsent: (j['researchConsent'] as bool?) ?? false,
        childAssent: (j['childAssent'] as bool?) ?? false,
        consentVersion: j['consentVersion'] as String?,
        consentAt: DateTime.tryParse((j['consentAt'] as String?) ?? ''),
      );
}

class AccountService extends ChangeNotifier {
  AccountService({this.iterations = 10000});
  static final AccountService instance = AccountService();

  /// PBKDF2 rounds for NEW accounts. Kept moderate because the hash runs in
  /// pure Dart on the phone. Stored per account so it can be raised later.
  final int iterations;

  /// Researcher registration needs this study code, supplied at build time:
  ///   flutter run --dart-define=MINDY_STUDY_CODE=your-secret-code
  /// With no code compiled in, researcher registration is DISABLED. There is
  /// no default code and no default PIN.
  static const String studyCode =
      String.fromEnvironment('MINDY_STUDY_CODE', defaultValue: '');

  static const _kAccounts = 'mindy_accounts_v1';
  static const _kChildren = 'mindy_children_v1';
  static const _kSession = 'mindy_login_v1';
  static const _kActive = 'mindy_active_child_v1';

  final List<Account> _accounts = [];
  final List<ChildProfile> _children = [];
  Account? _user;
  String? _activeChildId;

  /// Called whenever the active child (or login state) changes so the
  /// session store / journey can switch. Set in main.dart.
  Future<void> Function(ChildProfile? child)? onActiveChildChanged;

  /// Called when a child's data must be erased (profile or account deletion).
  Future<void> Function(ChildProfile child)? onChildDeleted;

  Account? get user => _user;
  bool get loggedIn => _user != null;
  bool get isResearcher => _user?.role == Role.researcher;

  List<ChildProfile> get myChildren => _user == null
      ? const []
      : List.unmodifiable(
          _children.where((c) => c.accountId == _user!.id).toList());

  ChildProfile? get activeChild {
    final u = _user;
    if (u == null || _activeChildId == null) return null;
    for (final c in _children) {
      if (c.id == _activeChildId && c.accountId == u.id) return c;
    }
    return null;
  }

  // ------------------------------------------------------------ storage

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _accounts
        ..clear()
        ..addAll([
          for (final j in jsonDecode(p.getString(_kAccounts) ?? '[]') as List)
            Account.fromJson(Map<String, dynamic>.from(j as Map))
        ]);
      _children
        ..clear()
        ..addAll([
          for (final j in jsonDecode(p.getString(_kChildren) ?? '[]') as List)
            ChildProfile.fromJson(Map<String, dynamic>.from(j as Map))
        ]);
      final uid = p.getString(_kSession);
      _user = null;
      for (final a in _accounts) {
        if (a.id == uid) _user = a;
      }
      _activeChildId = p.getString(_kActive);
    } catch (_) {
      _accounts.clear();
      _children.clear();
      _user = null;
    }
    notifyListeners();
    await onActiveChildChanged?.call(activeChild);
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _kAccounts, jsonEncode(_accounts.map((a) => a.toJson()).toList()));
      await p.setString(
          _kChildren, jsonEncode(_children.map((c) => c.toJson()).toList()));
      if (_user == null) {
        await p.remove(_kSession);
      } else {
        await p.setString(_kSession, _user!.id);
      }
      if (_activeChildId == null) {
        await p.remove(_kActive);
      } else {
        await p.setString(_kActive, _activeChildId!);
      }
    } catch (_) {}
  }

  static String _newId(String prefix) {
    final r = Random.secure();
    return '$prefix-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${r.nextInt(1 << 30).toRadixString(36)}';
  }

  /// Short pseudonymous code with no personal meaning.
  static String newParticipantId([Random? rng]) {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = rng ?? Random.secure();
    return 'P-${List.generate(6, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  // ------------------------------------------------------- account flow

  /// Returns null on success, otherwise a message safe to show the user.
  Future<String?> register({
    required String username,
    required String password,
    String? studyCodeEntered,
    bool asResearcher = false,
  }) async {
    final u = username.trim().toLowerCase();
    final e = Validation.username(u) ?? Validation.password(password);
    if (e != null) return e;
    if (_accounts.any((a) => a.username == u)) {
      return 'That username is already used on this device.';
    }
    if (asResearcher) {
      if (studyCode.isEmpty) {
        return 'Researcher accounts are disabled in this build.';
      }
      if (studyCodeEntered != studyCode) return 'Study code not recognised.';
    }
    final salt = PasswordHasher.randomSalt();
    final acc = Account(
      id: _newId('acc'),
      username: u,
      salt: base64Encode(salt),
      hash: PasswordHasher.hash(password, salt, iterations),
      iterations: iterations,
      role: asResearcher ? Role.researcher : Role.caregiver,
      createdAt: DateTime.now(),
    );
    _accounts.add(acc);
    _user = acc;
    _activeChildId = null;
    await _save();
    notifyListeners();
    await onActiveChildChanged?.call(null);
    return null;
  }

  Future<String?> login(String username, String password) async {
    final u = username.trim().toLowerCase();
    Account? acc;
    for (final a in _accounts) {
      if (a.username == u) acc = a;
    }
    // Same message for unknown user and wrong password.
    const bad = 'Username or password is not right.';
    if (acc == null) return bad;
    final h = PasswordHasher.hash(
        password, base64Decode(acc.salt), acc.iterations);
    if (!PasswordHasher.equal(h, acc.hash)) return bad;
    _user = acc;
    final mine = myChildren;
    _activeChildId = mine.length == 1 ? mine.first.id : null;
    await _save();
    notifyListeners();
    await onActiveChildChanged?.call(activeChild);
    return null;
  }

  /// Re-checks the password of the signed-in user (before sensitive actions).
  bool confirmPassword(String password) {
    final a = _user;
    if (a == null) return false;
    final h = PasswordHasher.hash(password, base64Decode(a.salt), a.iterations);
    return PasswordHasher.equal(h, a.hash);
  }

  Future<void> logout() async {
    _user = null;
    _activeChildId = null;
    await _save();
    notifyListeners();
    await onActiveChildChanged?.call(null);
  }

  /// Deletes the account and every child profile and their play data.
  Future<String?> deleteAccount(String password) async {
    final a = _user;
    if (a == null) return 'Not signed in.';
    if (!confirmPassword(password)) return 'Password is not right.';
    for (final c in List<ChildProfile>.of(_children)) {
      if (c.accountId == a.id) {
        await onChildDeleted?.call(c);
        _children.remove(c);
      }
    }
    _accounts.removeWhere((x) => x.id == a.id);
    _user = null;
    _activeChildId = null;
    await _save();
    notifyListeners();
    await onActiveChildChanged?.call(null);
    return null;
  }

  // ------------------------------------------------------------- demo

  /// Starts a throw-away demo: a temporary grown-up account (random password
  /// nobody knows) with one sample child whose code starts with DEMO-.
  /// Older demo accounts and their data are removed first. Demo sessions are
  /// stored on this device only and are never uploaded.
  Future<String?> startDemo() async {
    for (final a in List<Account>.of(_accounts)) {
      if (!a.username.startsWith('demo-')) continue;
      for (final c in List<ChildProfile>.of(_children)) {
        if (c.accountId == a.id) {
          await onChildDeleted?.call(c);
          _children.remove(c);
        }
      }
      _accounts.remove(a);
    }
    final r = Random.secure();
    const letters = 'abcdefghjkmnpqrstuvwxyz';
    String pick(int n, String set) =>
        List.generate(n, (_) => set[r.nextInt(set.length)]).join();
    final alnum = '${letters}23456789';
    final name = 'demo-${pick(8, alnum)}';
    final pw = '${pick(10, letters)}${pick(4, '23456789')}';
    final err = await register(username: name, password: pw);
    if (err != null) return err;
    final err2 = await addChild(
        nickname: 'Demo child',
        birthYear: DateTime.now().year - 7,
        demo: true);
    if (err2 != null) return err2;
    final c = activeChild;
    if (c == null) return 'Demo could not start.';
    return recordConsent(c.id, caregiverAgrees: true, childAgrees: true);
  }

  // -------------------------------------------------------- child flow

  Future<String?> addChild({
    required String nickname,
    required int? birthYear,
    Random? rng,
    bool demo = false,
  }) async {
    final u = _user;
    if (u == null) return 'Sign in first.';
    final e = Validation.nickname(nickname) ?? Validation.birthYear(birthYear);
    if (e != null) return e;
    String mk() => demo
        ? '$kDemoPrefix${newParticipantId(rng).substring(2)}'
        : newParticipantId(rng);
    var pid = mk();
    while (_children.any((c) => c.participantId == pid)) {
      pid = mk();
    }
    final child = ChildProfile(
      id: _newId('child'),
      accountId: u.id,
      nickname: nickname.trim(),
      birthYear: birthYear!,
      participantId: pid,
      createdAt: DateTime.now(),
    );
    _children.add(child);
    _activeChildId = child.id;
    await _save();
    notifyListeners();
    await onActiveChildChanged?.call(child);
    return null;
  }

  ChildProfile? _mine(String childId) {
    final u = _user;
    if (u == null) return null;
    for (final c in _children) {
      if (c.id == childId && c.accountId == u.id) return c;
    }
    return null; // not yours: no access
  }

  Future<String?> updateChild(String childId,
      {String? nickname, int? birthYear}) async {
    final c = _mine(childId);
    if (c == null) return 'Profile not found.';
    final e = (nickname == null ? null : Validation.nickname(nickname)) ??
        (birthYear == null ? null : Validation.birthYear(birthYear));
    if (e != null) return e;
    if (nickname != null) c.nickname = nickname.trim();
    if (birthYear != null) c.birthYear = birthYear;
    await _save();
    notifyListeners();
    return null;
  }

  Future<void> selectChild(String childId) async {
    final c = _mine(childId);
    if (c == null) return;
    _activeChildId = c.id;
    await _save();
    notifyListeners();
    await onActiveChildChanged?.call(c);
  }

  /// Caregiver consent + child assent. Either may be false: the child can
  /// still use practice play; research data are simply not stored.
  Future<String?> recordConsent(String childId,
      {required bool caregiverAgrees, required bool childAgrees}) async {
    final c = _mine(childId);
    if (c == null) return 'Profile not found.';
    c.researchConsent = caregiverAgrees;
    c.childAssent = caregiverAgrees && childAgrees;
    c.consentVersion = kConsentVersion;
    c.consentAt = DateTime.now();
    await _save();
    notifyListeners();
    await onActiveChildChanged?.call(c);
    return null;
  }

  Future<String?> deleteChild(String childId) async {
    final c = _mine(childId);
    if (c == null) return 'Profile not found.';
    await onChildDeleted?.call(c);
    _children.remove(c);
    if (_activeChildId == childId) _activeChildId = null;
    await _save();
    notifyListeners();
    await onActiveChildChanged?.call(activeChild);
    return null;
  }
}
