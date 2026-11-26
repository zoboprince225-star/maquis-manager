import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../format.dart';
import 'analytics_service.dart';
import 'sales_service.dart';
import 'stock_service.dart';

enum ExportKind { sales, expenses, stock, losses, credits, profits }

class ExportTable {
  ExportTable({
    required this.title,
    required this.slug,
    required this.headers,
    required this.rows,
    this.moneyCols = const {},
    this.totalRow,
  });
  final String title;
  final String slug;
  final List<String> headers;
  final List<List<Object>> rows;
  final Set<int> moneyCols;
  final List<Object>? totalRow;
}

class ExportService {
  ExportService(this.db);
  final AppDatabase db;

  Future<ExportTable> build(
      ExportKind kind, int eid, DateTime from, DateTime to, String label) {
    switch (kind) {
      case ExportKind.sales:
        return _sales(eid, from, to, label);
      case ExportKind.expenses:
        return _expenses(eid, from, to, label);
      case ExportKind.stock:
        return _stock(eid);
      case ExportKind.losses:
        return _losses(eid, from, to, label);
      case ExportKind.credits:
        return _credits(eid);
      case ExportKind.profits:
        return _profits(eid, from, to, label);
    }
  }

  Future<Map<int, String>> _userNames(int eid) async {
    final users = await (db.select(db.users)
          ..where((u) => u.establishmentId.equals(eid)))
        .get();
    return {for (final u in users) u.id: u.name};
  }

  Future<ExportTable> _sales(
      int eid, DateTime from, DateTime to, String label) async {
    final sales = await (db.select(db.sales)
          ..where((s) =>
              s.establishmentId.equals(eid) &
              s.createdAt.isBiggerOrEqualValue(from) &
              s.createdAt.isSmallerThanValue(to))
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
        .get();
    final users = await _userNames(eid);
    final customers = {
      for (final c in await (db.select(db.customers)
            ..where((c) => c.establishmentId.equals(eid)))
          .get())
        c.id: c.name
    };
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
    final ids = [for (final s in sales) s.id];
    final items = ids.isEmpty
        ? <SaleItem>[]
        : await (db.select(db.saleItems)..where((i) => i.saleId.isIn(ids)))
            .get();
    final byId = <int, List<SaleItem>>{};
    for (final i in items) {
      (byId[i.saleId] ??= []).add(i);
    }
    var total = 0;
    final rows = <List<Object>>[];
    for (final s in sales) {
      total += s.total;
      final text = (byId[s.id] ?? []).map((i) {
        final name =
            (i.drinkId != null ? drinks[i.drinkId] : kits[i.kitId]) ?? '?';
        return '$name x${i.quantity}';
      }).join(', ');
      rows.add([
        dayFr(s.createdAt),
        hourFr(s.createdAt),
        s.id,
        users[s.userId] ?? '',
        s.paymentMode == 'credit' ? 'Crédit' : 'Espèces',
        customers[s.customerId] ?? '',
        text,
        s.total,
      ]);
    }
    return ExportTable(
      title: 'Ventes $label',
      slug: 'ventes',
      headers: [
        'Date', 'Heure', 'N°', 'Serveur', 'Paiement', 'Client', 'Articles',
        'Total (FCFA)'
      ],
      rows: rows,
      moneyCols: {7},
      totalRow: ['TOTAL', '', '', '', '', '', '', total],
    );
  }

  Future<ExportTable> _expenses(
      int eid, DateTime from, DateTime to, String label) async {
    final list = await (db.select(db.expenses)
          ..where((e) =>
              e.establishmentId.equals(eid) &
              e.createdAt.isBiggerOrEqualValue(from) &
              e.createdAt.isSmallerThanValue(to))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAt)]))
        .get();
    final users = await _userNames(eid);
    var total = 0;
    final rows = <List<Object>>[];
    for (final e in list) {
      total += e.amount;
      rows.add([
        dayFr(e.createdAt),
        hourFr(e.createdAt),
        e.label,
        e.fromCash ? 'Caisse' : 'Hors caisse',
        users[e.userId] ?? '',
        e.amount,
      ]);
    }
    return ExportTable(
      title: 'Dépenses $label',
      slug: 'depenses',
      headers: ['Date', 'Heure', 'Libellé', 'Type', 'Saisi par', 'Montant (FCFA)'],
      rows: rows,
      moneyCols: {5},
      totalRow: ['TOTAL', '', '', '', '', total],
    );
  }

  Future<ExportTable> _stock(int eid) async {
    final list = await StockService(db).rows(eid);
    var total = 0;
    final rows = <List<Object>>[];
    for (final r in list) {
      final value = r.stock * r.drink.purchasePrice;
      total += value;
      rows.add([
        r.drink.name,
        r.drink.category ?? '',
        r.stock,
        r.drink.alertThreshold,
        r.label,
        r.drink.purchasePrice,
        value,
      ]);
    }
    return ExportTable(
      title: 'État du stock au ${dayFr(DateTime.now())}',
      slug: 'stock',
      headers: [
        'Boisson', 'Catégorie', 'Stock', 'Seuil d’alerte', 'État',
        'Prix d’achat (FCFA)', 'Valeur du stock (FCFA)'
      ],
      rows: rows,
      moneyCols: {5, 6},
      totalRow: ['TOTAL', '', '', '', '', '', total],
    );
  }

  Future<ExportTable> _losses(
      int eid, DateTime from, DateTime to, String label) async {
    final all = await StockService(db).losses(eid, from);
    final list = all.where((l) => l.date.isBefore(to)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    var total = 0;
    final rows = <List<Object>>[];
    for (final l in list) {
      total += l.value;
      rows.add([
        dayFr(l.date),
        l.drinkName,
        l.quantity,
        l.value,
        l.note ?? '',
      ]);
    }
    return ExportTable(
      title: 'Pertes $label',
      slug: 'pertes',
      headers: ['Date', 'Boisson', 'Quantité', 'Valeur (FCFA)', 'Note'],
      rows: rows,
      moneyCols: {3},
      totalRow: ['TOTAL', '', '', total, ''],
    );
  }

  Future<ExportTable> _credits(int eid) async {
    final list = await SalesService(db).customers(eid);
    var total = 0;
    final rows = <List<Object>>[];
    for (final c in list) {
      total += c.owed;
      rows.add([c.customer.name, c.customer.phone ?? '', c.owed]);
    }
    return ExportTable(
      title: 'Crédits clients au ${dayFr(DateTime.now())}',
      slug: 'credits',
      headers: ['Client', 'Téléphone', 'Dette (FCFA)'],
      rows: rows,
      moneyCols: {2},
      totalRow: ['TOTAL', '', total],
    );
  }

  Future<ExportTable> _profits(
      int eid, DateTime from, DateTime to, String label) async {
    final stats = await AnalyticsService(db).drinkStats(eid, from, to);
    stats.sort((a, b) => b.margin.compareTo(a.margin));
    var rev = 0;
    var cost = 0;
    var qty = 0;
    final rows = <List<Object>>[];
    for (final s in stats) {
      rev += s.revenue;
      cost += s.cost;
      qty += s.qty;
      rows.add([s.name, s.qty, s.revenue, s.cost, s.margin, '${s.pct} %']);
    }
    final margin = rev - cost;
    return ExportTable(
      title: 'Bénéfices par boisson $label',
      slug: 'benefices',
      headers: [
        'Boisson', 'Quantité', 'CA (FCFA)', 'Coût (FCFA)', 'Marge (FCFA)',
        'Marge %'
      ],
      rows: rows,
      moneyCols: {2, 3, 4},
      totalRow: [
        'TOTAL',
        qty,
        rev,
        cost,
        margin,
        rev <= 0 ? '0 %' : '${(margin * 100 / rev).round()} %'
      ],
    );
  }
}
