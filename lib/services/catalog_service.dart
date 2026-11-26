import 'package:drift/drift.dart';
import '../database/app_database.dart';

class KitLine {
  KitLine(this.drink, this.quantity);
  final Drink? drink;
  final int quantity;
}

class KitView {
  KitView(this.kit, this.lines);
  final Kit kit;
  final List<KitLine> lines;
}

class CatalogService {
  CatalogService(this.db);
  final AppDatabase db;

  Future<List<Drink>> drinks(int eid) => (db.select(db.drinks)
        ..where((d) => d.establishmentId.equals(eid) & d.isActive.equals(true))
        ..orderBy([(d) => OrderingTerm.asc(d.name)]))
      .get();

  /// Stock actuel par boisson (somme des mouvements)
  Future<Map<int, int>> stock(int eid) async {
    final rows = await (db.select(db.stockMovements)
          ..where((m) => m.establishmentId.equals(eid)))
        .get();
    final map = <int, int>{};
    for (final m in rows) {
      map[m.drinkId] = (map[m.drinkId] ?? 0) + m.quantity;
    }
    return map;
  }

  Future<String?> saveDrink({
    int? id,
    required int eid,
    required String name,
    String? category,
    required int purchase,
    required int sale,
    required int threshold,
    int initialStock = 0,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return 'Saisis un nom.';
    if (sale <= 0) return 'Le prix de vente doit être supérieur à 0.';
    final same = await (db.select(db.drinks)
          ..where((d) =>
              d.establishmentId.equals(eid) &
              d.name.equals(n) &
              d.isActive.equals(true)))
        .get();
    if (same.any((d) => d.id != id)) return 'Cette boisson existe déjà.';

    if (id == null) {
      final newId = await db.into(db.drinks).insert(DrinksCompanion.insert(
            establishmentId: eid,
            name: n,
            category: Value(category),
            purchasePrice: Value(purchase),
            salePrice: Value(sale),
            alertThreshold: Value(threshold),
          ));
      if (initialStock > 0) {
        await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
              establishmentId: eid,
              drinkId: newId,
              type: 'inventory',
              quantity: initialStock,
              unitCost: Value(purchase),
              note: const Value('Stock initial'),
            ));
      }
    } else {
      await (db.update(db.drinks)..where((d) => d.id.equals(id))).write(
          DrinksCompanion(
        name: Value(n),
        category: Value(category),
        purchasePrice: Value(purchase),
        salePrice: Value(sale),
        alertThreshold: Value(threshold),
      ));
    }
    return null;
  }

  Future<String?> deleteDrink(int id) async {
    final used = await (db.select(db.kitItems)
          ..where((i) => i.drinkId.equals(id)))
        .get();
    if (used.isNotEmpty) {
      return 'Cette boisson est utilisée dans un kit. Supprime d’abord le kit.';
    }
    await (db.update(db.drinks)..where((d) => d.id.equals(id)))
        .write(const DrinksCompanion(isActive: Value(false)));
    return null;
  }

  Future<List<KitView>> kits(int eid) async {
    final ks = await (db.select(db.kits)
          ..where((k) => k.establishmentId.equals(eid))
          ..orderBy([(k) => OrderingTerm.asc(k.name)]))
        .get();
    final out = <KitView>[];
    for (final k in ks) {
      final items = await (db.select(db.kitItems)
            ..where((i) => i.kitId.equals(k.id)))
          .get();
      final lines = <KitLine>[];
      for (final i in items) {
        final d = await (db.select(db.drinks)
              ..where((x) => x.id.equals(i.drinkId)))
            .getSingleOrNull();
        lines.add(KitLine(d, i.quantity));
      }
      out.add(KitView(k, lines));
    }
    return out;
  }

  /// lines : identifiant de boisson -> quantité (un kit peut n'avoir qu'une boisson)
  Future<String?> saveKit({
    required int eid,
    required String name,
    required int price,
    required Map<int, int> lines,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return 'Saisis un nom de kit.';
    if (price <= 0) return 'Le prix du kit doit être supérieur à 0.';
    if (lines.isEmpty) return 'Ajoute au moins une boisson.';
    await db.transaction(() async {
      final kitId = await db.into(db.kits).insert(KitsCompanion.insert(
            establishmentId: eid,
            name: n,
            salePrice: Value(price),
          ));
      for (final e in lines.entries) {
        await db.into(db.kitItems).insert(KitItemsCompanion.insert(
              kitId: kitId,
              drinkId: e.key,
              quantity: Value(e.value),
            ));
      }
    });
    return null;
  }

  Future<void> deleteKit(int id) async {
    await db.transaction(() async {
      await (db.delete(db.kitItems)..where((i) => i.kitId.equals(id))).go();
      await (db.delete(db.kits)..where((k) => k.id.equals(id))).go();
    });
  }
}
