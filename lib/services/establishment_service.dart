import 'package:drift/drift.dart';
import '../database/app_database.dart';

class EstablishmentService {
  EstablishmentService(this.db);
  final AppDatabase db;

  Future<List<Establishment>> list() => (db.select(db.establishments)
        ..orderBy([(e) => OrderingTerm.asc(e.id)]))
      .get();

  /// Retourne (identifiant, null) si créé, sinon (null, message d'erreur)
  Future<(int?, String?)> create(String name) async {
    final n = name.trim();
    if (n.isEmpty) return (null, 'Saisis un nom.');
    final all = await list();
    if (all.any((e) => e.name.toLowerCase() == n.toLowerCase())) {
      return (null, 'Cet établissement existe déjà.');
    }
    final id = await db
        .into(db.establishments)
        .insert(EstablishmentsCompanion.insert(name: n));
    return (id, null);
  }
}
