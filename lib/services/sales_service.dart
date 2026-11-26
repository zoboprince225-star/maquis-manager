import 'package:drift/drift.dart';
import '../database/app_database.dart';

class SaleLine {
  SaleLine({this.drinkId, this.kitId, required this.qty, required this.price});
  final int? drinkId;
  final int? kitId;
  final int qty;
  final int price;
}

class DaySummary {
  DaySummary({
    required this.opening,
    required this.cashSales,
    required this.creditSales,
    required this.payments,
    required this.cashExpenses,
    required this.offExpenses,
    this.counted,
  });
  final int opening;
  final int cashSales;
  final int creditSales;
  final int payments;
  final int cashExpenses;
  final int offExpenses;
  final int? counted;

  int get totalSales => cashSales + creditSales;
  int get expected => opening + cashSales + payments - cashExpenses;
  int? get diff => counted == null ? null : counted! - expected;
}

class SaleRow {
  SaleRow(this.sale, this.items);
  final Sale sale;
  final String items;
}

class CustomerBalance {
  CustomerBalance(this.customer, this.owed);
  final Customer customer;
  final int owed;
}

class SalesService {
  SalesService(this.db);
  final AppDatabase db;

  // ---------- Journée de travail ----------

  Future<WorkDay?> openDay(int eid) => (db.select(db.workDays)
        ..where((d) => d.establishmentId.equals(eid) & d.closedAt.isNull())
        ..limit(1))
      .getSingleOrNull();

  Future<String?> startDay(int eid, int openingCash) async {
    if (await openDay(eid) != null) return 'Une journée est déjà en cours.';
    await db.into(db.workDays).insert(WorkDaysCompanion.insert(
          establishmentId: eid,
          openedAt: DateTime.now(),
          openingCash: Value(openingCash),
        ));
    return null;
  }

  Future<List<Expense>> dayExpenses(int eid, WorkDay day) async {
    final end = day.closedAt;
    final all = await (db.select(db.expenses)
          ..where((e) => e.establishmentId.equals(eid)))
        .get();
    return all
        .where((e) =>
            !e.createdAt.isBefore(day.openedAt) &&
            (end == null || !e.createdAt.isAfter(end)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<DaySummary> summary(int eid, WorkDay day, {int? counted}) async {
    final end = day.closedAt;
    final sales = await (db.select(db.sales)
          ..where((s) => s.workDayId.equals(day.id)))
        .get();
    var cash = 0;
    var credit = 0;
    for (final s in sales) {
      if (s.paymentMode == 'credit') {
        credit += s.total;
      } else {
        cash += s.total;
      }
    }
    final pays = await (db.select(db.creditPayments)
          ..where((p) => p.establishmentId.equals(eid)))
        .get();
    final paid = pays
        .where((p) =>
            !p.createdAt.isBefore(day.openedAt) &&
            (end == null || !p.createdAt.isAfter(end)))
        .fold<int>(0, (a, p) => a + p.amount);
    final exps = await dayExpenses(eid, day);
    return DaySummary(
      opening: day.openingCash,
      cashSales: cash,
      creditSales: credit,
      payments: paid,
      cashExpenses:
          exps.where((e) => e.fromCash).fold<int>(0, (a, e) => a + e.amount),
      offExpenses:
          exps.where((e) => !e.fromCash).fold<int>(0, (a, e) => a + e.amount),
      counted: counted,
    );
  }

  Future<DaySummary?> closeDay(int eid, int counted) async {
    final day = await openDay(eid);
    if (day == null) return null;
    final s = await summary(eid, day, counted: counted);
    await (db.update(db.workDays)..where((d) => d.id.equals(day.id))).write(
        WorkDaysCompanion(
            closedAt: Value(DateTime.now()), countedCash: Value(counted)));
    return s;
  }

  // ---------- Ventes ----------

  Future<Map<int, int>> _stock(int eid) async {
    final rows = await (db.select(db.stockMovements)
          ..where((m) => m.establishmentId.equals(eid)))
        .get();
    final map = <int, int>{};
    for (final m in rows) {
      map[m.drinkId] = (map[m.drinkId] ?? 0) + m.quantity;
    }
    return map;
  }

  Future<String?> recordSale({
    required int eid,
    required int userId,
    required List<SaleLine> lines,
    required String mode,
    int? customerId,
  }) async {
    if (lines.isEmpty) return 'Ajoute au moins un article.';
    if (mode == 'credit' && customerId == null) {
      return 'Choisis un client pour la vente à crédit.';
    }
    final day = await openDay(eid);
    if (day == null) {
      return 'Démarre d’abord la journée de travail (écran Accueil).';
    }

    // Besoin en boissons : les kits sont décomposés en boissons
    final need = <int, int>{};
    for (final l in lines) {
      if (l.drinkId != null) {
        need[l.drinkId!] = (need[l.drinkId!] ?? 0) + l.qty;
      } else if (l.kitId != null) {
        final items = await (db.select(db.kitItems)
              ..where((i) => i.kitId.equals(l.kitId!)))
            .get();
        for (final i in items) {
          need[i.drinkId] = (need[i.drinkId] ?? 0) + i.quantity * l.qty;
        }
      }
    }
    final drinks = await (db.select(db.drinks)
          ..where((d) => d.establishmentId.equals(eid)))
        .get();
    final byId = {for (final d in drinks) d.id: d};
    final stock = await _stock(eid);
    for (final e in need.entries) {
      final have = stock[e.key] ?? 0;
      if (e.value > have) {
        return 'Stock insuffisant : ${byId[e.key]?.name ?? '?'} (reste $have, demandé ${e.value}).';
      }
    }

    final total = lines.fold<int>(0, (a, l) => a + l.price * l.qty);
    await db.transaction(() async {
      final saleId = await db.into(db.sales).insert(SalesCompanion.insert(
            establishmentId: eid,
            userId: userId,
            total: total,
            workDayId: Value(day.id),
            paymentMode: Value(mode),
            customerId: Value(customerId),
          ));
      for (final l in lines) {
        await db.into(db.saleItems).insert(SaleItemsCompanion.insert(
              saleId: saleId,
              drinkId: Value(l.drinkId),
              kitId: Value(l.kitId),
              quantity: l.qty,
              unitPrice: l.price,
            ));
      }
      for (final e in need.entries) {
        await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
              establishmentId: eid,
              drinkId: e.key,
              type: 'sale',
              quantity: -e.value,
              unitCost: Value(byId[e.key]?.purchasePrice ?? 0),
              note: Value('Vente #$saleId'),
              userId: Value(userId),
            ));
      }
    });
    return null;
  }

  Future<List<SaleRow>> salesSince(int eid, DateTime from) async {
    final sales = await (db.select(db.sales)
          ..where((s) =>
              s.establishmentId.equals(eid) &
              s.createdAt.isBiggerOrEqualValue(from))
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .get();
    final drinks = {
      for (final d in await (db.select(db.drinks)
            ..where((d) => d.establishmentId.equals(eid)))
          .get())
        d.id: d.name
    };
    final kits = {
      for (final k in await (db.select(db.kits)
            ..where((k) => k.establishmentId.equals(eid)))
          .get())
        k.id: k.name
    };
    final out = <SaleRow>[];
    for (final s in sales) {
      final items = await (db.select(db.saleItems)
            ..where((i) => i.saleId.equals(s.id)))
          .get();
      final text = items.map((i) {
        final name = (i.drinkId != null ? drinks[i.drinkId] : kits[i.kitId]) ?? '?';
        return '$name × ${i.quantity}';
      }).join(', ');
      out.add(SaleRow(s, text));
    }
    return out;
  }

  // ---------- Dépenses ----------

  Future<String?> addExpense({
    required int eid,
    required int userId,
    required String label,
    required int amount,
    required bool fromCash,
  }) async {
    if (label.trim().isEmpty) return 'Saisis un libellé.';
    if (amount <= 0) return 'Saisis un montant.';
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          establishmentId: eid,
          label: label.trim(),
          amount: amount,
          fromCash: Value(fromCash),
          userId: Value(userId),
        ));
    return null;
  }

  // ---------- Crédits clients ----------

  Future<List<CustomerBalance>> customers(int eid) async {
    final cs = await (db.select(db.customers)
          ..where((c) => c.establishmentId.equals(eid))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
    final sales = await (db.select(db.sales)
          ..where((s) =>
              s.establishmentId.equals(eid) & s.paymentMode.equals('credit')))
        .get();
    final pays = await (db.select(db.creditPayments)
          ..where((p) => p.establishmentId.equals(eid)))
        .get();
    return [
      for (final c in cs)
        CustomerBalance(
          c,
          sales
                  .where((s) => s.customerId == c.id)
                  .fold<int>(0, (a, s) => a + s.total) -
              pays
                  .where((p) => p.customerId == c.id)
                  .fold<int>(0, (a, p) => a + p.amount),
        )
    ];
  }

  Future<(int?, String?)> addCustomer(
      int eid, String name, String phone) async {
    final n = name.trim();
    if (n.isEmpty) return (null, 'Saisis un nom.');
    final p = phone.trim();
    final id = await db.into(db.customers).insert(CustomersCompanion.insert(
          establishmentId: eid,
          name: n,
          phone: Value(p.isEmpty ? null : p),
        ));
    return (id, null);
  }

  Future<String?> addPayment({
    required int eid,
    required int userId,
    required int customerId,
    required int amount,
  }) async {
    if (amount <= 0) return 'Saisis un montant.';
    final list = await customers(eid);
    final c = list.where((x) => x.customer.id == customerId).toList();
    if (c.isEmpty) return 'Client introuvable.';
    if (amount > c.first.owed) {
      return 'Le montant dépasse la dette (${c.first.owed} FCFA).';
    }
    final day = await openDay(eid);
    await db.into(db.creditPayments).insert(CreditPaymentsCompanion.insert(
          establishmentId: eid,
          customerId: customerId,
          amount: amount,
          workDayId: Value(day?.id),
          userId: Value(userId),
        ));
    return null;
  }
}
