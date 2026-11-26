import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

class AuthResult {
  const AuthResult.ok(this.user) : error = null;
  const AuthResult.fail(this.error) : user = null;
  final User? user;
  final String? error;
}

class AuthService {
  AuthService(this.db);
  final AppDatabase db;

  int _fails = 0;
  DateTime? _lockUntil;

  String _rand([int n = 12]) {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  String _hash(String secret, String salt) =>
      sha256.convert(utf8.encode('$salt:$secret')).toString();

  String _make(String secret) {
    final salt = _rand();
    return '$salt\$${_hash(secret, salt)}';
  }

  bool _check(String secret, String? stored) {
    if (stored == null) return false;
    final p = stored.split('\$');
    return p.length == 2 && _hash(secret, p[0]) == p[1];
  }

  String? _locked() {
    final l = _lockUntil;
    if (l != null && DateTime.now().isBefore(l)) {
      return 'Trop d’essais. Réessaie dans ${l.difference(DateTime.now()).inSeconds + 1} s.';
    }
    return null;
  }

  AuthResult _fail(String msg) {
    _fails++;
    if (_fails >= 5) {
      _fails = 0;
      _lockUntil = DateTime.now().add(const Duration(seconds: 30));
      return const AuthResult.fail('Trop d’essais. Réessaie dans 30 s.');
    }
    return AuthResult.fail(msg);
  }

  Future<bool> hasOwner() async {
    final rows = await (db.select(db.users)
          ..where((u) => u.role.equals('owner'))
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  Future<User> createOwner({
    required String establishment,
    required String name,
    required String phone,
    required String password,
    String? pin,
  }) async {
    final eid = await db
        .into(db.establishments)
        .insert(EstablishmentsCompanion.insert(name: establishment));
    final id = await db.into(db.users).insert(UsersCompanion.insert(
          establishmentId: eid,
          name: name,
          passwordHash: _make(password),
          phone: Value(phone),
          role: const Value('owner'),
          pinHash: Value((pin == null || pin.isEmpty) ? null : _make(pin)),
        ));
    return (db.select(db.users)..where((u) => u.id.equals(id))).getSingle();
  }

  Future<AuthResult> loginPassword(String phone, String password) async {
    final l = _locked();
    if (l != null) return AuthResult.fail(l);
    final rows = await (db.select(db.users)
          ..where((u) => u.phone.equals(phone.trim())))
        .get();
    for (final u in rows) {
      if (_check(password, u.passwordHash)) {
        _fails = 0;
        return AuthResult.ok(u);
      }
    }
    return _fail('Téléphone ou mot de passe incorrect.');
  }

  Future<AuthResult> loginPin(String pin) async {
    final l = _locked();
    if (l != null) return AuthResult.fail(l);
    final rows =
        await (db.select(db.users)..where((u) => u.pinHash.isNotNull())).get();
    for (final u in rows) {
      if (_check(pin, u.pinHash)) {
        _fails = 0;
        return AuthResult.ok(u);
      }
    }
    return _fail('Code PIN incorrect.');
  }

  Future<List<User>> users(int establishmentId) => (db.select(db.users)
        ..where((u) => u.establishmentId.equals(establishmentId)))
      .get();

  Future<String?> addEmployee({
    required int establishmentId,
    required String name,
    required String pin,
  }) async {
    if (name.trim().isEmpty) return 'Saisis un nom.';
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      return 'Le PIN doit avoir 4 à 6 chiffres.';
    }
    final all = await users(establishmentId);
    if (all.any((u) => _check(pin, u.pinHash))) {
      return 'Ce PIN est déjà utilisé.';
    }
    await db.into(db.users).insert(UsersCompanion.insert(
          establishmentId: establishmentId,
          name: name.trim(),
          passwordHash: _make(_rand()),
          pinHash: Value(_make(pin)),
        ));
    return null;
  }

  Future<void> deleteUser(int id) =>
      (db.delete(db.users)..where((u) => u.id.equals(id))).go();
}
