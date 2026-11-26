import 'package:drift/drift.dart';
import '../database/app_database.dart';

const auditEntities = [
  'Boisson',
  'Kit',
  'Vente',
  'Dépense',
  'Stock',
  'Client',
  'Crédit',
  'Utilisateur',
  'Journée',
  'Session',
  'Sauvegarde',
];

class AuditView {
  AuditView(this.entry, this.userName);
  final AuditEntry entry;
  final String userName;
}

class AuditService {
  AuditService(this.db);
  final AppDatabase db;

  /// Mémorise l'utilisateur connecté pour que la base lui attribue ses actions
  Future<void> setUser(int? userId) => db.customStatement(
      'UPDATE app_session SET user_id = ? WHERE id = 1', [userId]);

  Future<void> logAs(User u, String action, String entity, String detail) =>
      db.customStatement(
          'INSERT INTO audit_entries (establishment_id, user_id, user_name, action, entity, detail) VALUES (?, ?, ?, ?, ?, ?)',
          [u.establishmentId, u.id, u.name, action, entity, detail]);

  /// Inscrit une ligne au nom de l'utilisateur actuellement connecté
  Future<void> logCurrent(String action, String entity, String detail) =>
      db.customStatement(
          'INSERT INTO audit_entries (establishment_id, user_id, user_name, action, entity, detail) '
          'SELECT u.establishment_id, s.user_id, u.name, ?, ?, ? '
          'FROM app_session s JOIN users u ON u.id = s.user_id WHERE s.id = 1',
          [action, entity, detail]);

  Future<List<AuditView>> query(
    int eid, {
    DateTime? from,
    int? userId,
    String? entity,
  }) async {
    final rows = await (db.select(db.auditEntries)
          ..where((e) {
            Expression<bool> p =
                e.establishmentId.equals(eid) | e.establishmentId.isNull();
            if (from != null) p = p & e.createdAt.isBiggerOrEqualValue(from);
            if (userId != null) p = p & e.userId.equals(userId);
            if (entity != null) p = p & e.entity.equals(entity);
            return p;
          })
          ..orderBy([
            (e) => OrderingTerm.desc(e.createdAt),
            (e) => OrderingTerm.desc(e.id),
          ])
          ..limit(500))
        .get();
    final users = await (db.select(db.users)
          ..where((u) => u.establishmentId.equals(eid)))
        .get();
    final names = {for (final u in users) u.id: u.name};
    return [
      for (final r in rows)
        AuditView(
          r,
          r.userName ??
              (r.userId == null ? 'Système' : (names[r.userId] ?? '?')),
        )
    ];
  }
}
