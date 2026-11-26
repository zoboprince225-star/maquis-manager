import 'package:drift/drift.dart';
import '../database/app_database.dart';

class StockRow {
  StockRow(this.drink, this.stock);
  final Drink drink;
  final int stock;
  bool get empty => stock <= 0;
  bool get low => stock > 0 && stock <= drink.alertThreshold;
  String get label => empty ? 'Épuisé' : (low ? 'Presque épuisé' : 'Normal');
}

class InventoryResult {
  InventoryResult(this.lossQty, this.lossValue, this.gainQty);
  final int lossQty;
  final int lossValue;
  final int gainQty;
}

class LossRow {
  LossRow(this.date, this.drinkName, this.quantity, this.value, this.note);
  final DateTime date;
  final String drinkName;
  final int quantity;
  final int value;
  final String? note;
}

class StockService {
  StockService(this.db);
  final AppDatabase db;

  /// Stock théorique actuel de chaque boisson active
  Future<List<StockRow>> rows(int eid) async {
    final drinks = await (db.select(db.drinks)
          ..where(
              (d) => d.establishmentId.equals(eid) & d.isActive.equals(true))
          ..orderBy([(d) => OrderingTerm.asc(d.name)]))
        .get();
    final moves = await (db.select(db.stockMovements)
          ..where((m) => m.establishmentId.equals(eid)))
        .get();
    final sums = <int, int>{};
    for (final m in moves) {
      sums[m.drinkId] = (sums[m.drinkId] ?? 0) + m.quantity;
    }
    return [for (final d in drinks) StockRow(d, sums[d.id] ?? 0)];
  }

  Future<String?> supply({
    required int eid,
    required int? userId,
    required Map<int, int> quantities,
    String? note,
  }) async {
    final items = quantities.entries.where((e) => e.value > 0).toList();
    if (items.isEmpty) return 'Saisis au moins une quantité.';
    final drinks = await (db.select(db.drinks)
          ..where((d) => d.establishmentId.equals(eid)))
        .get();
    await db.transaction(() async {
      for (final e in items) {
        final cost = drinks.where((d) => d.id == e.key).first.purchasePrice;
        await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
              establishmentId: eid,
              drinkId: e.key,
              type: 'supply',
              quantity: e.value,
              unitCost: Value(cost),
              note: Value(note),
              userId: Value(userId),
            ));
      }
    });
    return null;
  }

  /// counted : boisson -> quantité réellement comptée
  Future<InventoryResult> inventory({
    required int eid,
    required int? userId,
    required Map<int, int> counted,
  }) async {
    var lossQty = 0;
    var lossValue = 0;
    var gainQty = 0;
    await db.transaction(() async {
      final current = await rows(eid);
      for (final r in current) {
        final c = counted[r.drink.id];
        if (c == null) continue;
        final diff = c - r.stock;
        if (diff == 0) continue;
        if (diff < 0) {
          lossQty += -diff;
          lossValue += -diff * r.drink.purchasePrice;
        } else {
          gainQty += diff;
        }
        await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
              establishmentId: eid,
              drinkId: r.drink.id,
              type: diff < 0 ? 'loss' : 'inventory',
              quantity: diff,
              unitCost: Value(r.drink.purchasePrice),
              note: Value(
                  '${diff < 0 ? 'Manque' : 'Surplus'} à l’inventaire (théorique ${r.stock}, compté $c)'),
              userId: Value(userId),
            ));
      }
    });
    return InventoryResult(lossQty, lossValue, gainQty);
  }

  Future<List<LossRow>> losses(int eid, DateTime? from) async {
    final moves = await (db.select(db.stockMovements)
          ..where((m) {
            Expression<bool> p =
                m.establishmentId.equals(eid) & m.type.equals('loss');
            if (from != null) p = p & m.createdAt.isBiggerOrEqualValue(from);
            return p;
          })
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
    final drinks = await (db.select(db.drinks)
          ..where((d) => d.establishmentId.equals(eid)))
        .get();
    final names = {for (final d in drinks) d.id: d.name};
    return [
      for (final m in moves)
        LossRow(m.createdAt, names[m.drinkId] ?? '?', -m.quantity,
            -m.quantity * m.unitCost, m.note)
    ];
  }
}
