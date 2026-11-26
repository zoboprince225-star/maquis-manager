import 'package:drift/drift.dart';
import '../database/app_database.dart';

class DrinkStat {
  DrinkStat(this.name, this.qty, this.revenue, this.cost);
  final String name;
  final int qty;
  final int revenue;
  final int cost;
  int get margin => revenue - cost;
  int get pct => revenue <= 0 ? 0 : (margin * 100 / revenue).round();
}

class DormantRow {
  DormantRow(this.drink, this.stock, this.lastSale);
  final Drink drink;
  final int stock;
  final DateTime? lastSale;
  int get value => stock * drink.purchasePrice;
}

class BalanceRow {
  BalanceRow(this.drink, this.opening, this.supplies, this.sold, this.lost,
      this.adjust);
  final Drink drink;
  final int opening;
  final int supplies;
  final int sold;
  final int lost;
  final int adjust;
  int get closing => opening + supplies - sold - lost + adjust;
}

class StockBalance {
  StockBalance(this.rows, this.lossValue);
  final List<BalanceRow> rows;
  final int lossValue;
  int get openingValue =>
      rows.fold<int>(0, (a, r) => a + r.opening * r.drink.purchasePrice);
  int get closingValue =>
      rows.fold<int>(0, (a, r) => a + r.closing * r.drink.purchasePrice);
}

class AnalyticsService {
  AnalyticsService(this.db);
  final AppDatabase db;

  /// Période : de `from` (inclus) à `to` (exclu)
  Future<List<DrinkStat>> drinkStats(
      int eid, DateTime from, DateTime to) async {
    final drinks = await (db.select(db.drinks)
          ..where((d) => d.establishmentId.equals(eid)))
        .get();
    final byId = {for (final d in drinks) d.id: d};

    // Quantités sorties et coût (les kits sont déjà décomposés en boissons)
    final moves = await (db.select(db.stockMovements)
          ..where((m) =>
              m.establishmentId.equals(eid) &
              m.type.equals('sale') &
              m.createdAt.isBiggerOrEqualValue(from) &
              m.createdAt.isSmallerThanValue(to)))
        .get();
    final qty = <int, int>{};
    final cost = <int, int>{};
    for (final m in moves) {
      qty[m.drinkId] = (qty[m.drinkId] ?? 0) - m.quantity;
      cost[m.drinkId] = (cost[m.drinkId] ?? 0) - m.quantity * m.unitCost;
    }

    // Chiffre d'affaires : ventes directes + part des kits
    final q = db.select(db.saleItems).join([
      innerJoin(db.sales, db.sales.id.equalsExp(db.saleItems.saleId)),
    ])
      ..where(db.sales.establishmentId.equals(eid) &
          db.sales.createdAt.isBiggerOrEqualValue(from) &
          db.sales.createdAt.isSmallerThanValue(to));
    final rows = await q.get();
    final rev = <int, double>{};
    final kitCache = <int, List<KitItem>>{};
    for (final row in rows) {
      final it = row.readTable(db.saleItems);
      final amount = (it.quantity * it.unitPrice).toDouble();
      if (it.drinkId != null) {
        rev[it.drinkId!] = (rev[it.drinkId!] ?? 0) + amount;
      } else if (it.kitId != null) {
        final items = kitCache[it.kitId!] ??= await (db.select(db.kitItems)
              ..where((k) => k.kitId.equals(it.kitId!)))
            .get();
        if (items.isEmpty) continue;
        double weight(KitItem k) =>
            ((byId[k.drinkId]?.salePrice ?? 0) * k.quantity).toDouble();
        final total = items.fold<double>(0, (a, k) => a + weight(k));
        for (final k in items) {
          final share = total > 0 ? weight(k) / total : 1 / items.length;
          rev[k.drinkId] = (rev[k.drinkId] ?? 0) + amount * share;
        }
      }
    }

    final ids = {...qty.keys, ...rev.keys};
    return [
      for (final id in ids)
        DrinkStat(byId[id]?.name ?? '?', qty[id] ?? 0,
            (rev[id] ?? 0).round(), cost[id] ?? 0)
    ];
  }

  /// Boissons en stock sans aucune vente sur la période
  Future<List<DormantRow>> dormant(
      int eid, DateTime from, DateTime to) async {
    final drinks = await (db.select(db.drinks)
          ..where(
              (d) => d.establishmentId.equals(eid) & d.isActive.equals(true)))
        .get();
    final moves = await (db.select(db.stockMovements)
          ..where((m) => m.establishmentId.equals(eid)))
        .get();
    final stock = <int, int>{};
    final last = <int, DateTime>{};
    final soldInRange = <int>{};
    for (final m in moves) {
      stock[m.drinkId] = (stock[m.drinkId] ?? 0) + m.quantity;
      if (m.type == 'sale') {
        final l = last[m.drinkId];
        if (l == null || m.createdAt.isAfter(l)) last[m.drinkId] = m.createdAt;
        if (!m.createdAt.isBefore(from) && m.createdAt.isBefore(to)) {
          soldInRange.add(m.drinkId);
        }
      }
    }
    final out = [
      for (final d in drinks)
        if (!soldInRange.contains(d.id) && (stock[d.id] ?? 0) > 0)
          DormantRow(d, stock[d.id]!, last[d.id])
    ]..sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  Future<StockBalance> balance(int eid, DateTime from, DateTime to) async {
    final drinks = await (db.select(db.drinks)
          ..where(
              (d) => d.establishmentId.equals(eid) & d.isActive.equals(true))
          ..orderBy([(d) => OrderingTerm.asc(d.name)]))
        .get();
    final moves = await (db.select(db.stockMovements)
          ..where((m) =>
              m.establishmentId.equals(eid) &
              m.createdAt.isSmallerThanValue(to)))
        .get();
    final byDrink = <int, List<StockMovement>>{};
    for (final m in moves) {
      (byDrink[m.drinkId] ??= []).add(m);
    }
    var lossValue = 0;
    final rows = <BalanceRow>[];
    for (final d in drinks) {
      var opening = 0;
      var supplies = 0;
      var sold = 0;
      var lost = 0;
      var adjust = 0;
      for (final m in byDrink[d.id] ?? <StockMovement>[]) {
        if (m.createdAt.isBefore(from)) {
          opening += m.quantity;
          continue;
        }
        switch (m.type) {
          case 'supply':
            supplies += m.quantity;
          case 'sale':
            sold -= m.quantity;
          case 'loss':
            lost -= m.quantity;
            lossValue -= m.quantity * m.unitCost;
          default:
            adjust += m.quantity;
        }
      }
      rows.add(BalanceRow(d, opening, supplies, sold, lost, adjust));
    }
    return StockBalance(rows, lossValue);
  }
}
