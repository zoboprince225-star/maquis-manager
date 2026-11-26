import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'sales_service.dart';

class Report {
  Report({
    required this.salesCash,
    required this.salesCredit,
    required this.saleCount,
    required this.payments,
    required this.expCash,
    required this.expOff,
    required this.qtyOut,
    required this.cogs,
    required this.byDay,
    required this.byHour,
    required this.byServer,
  });
  final int salesCash;
  final int salesCredit;
  final int saleCount;
  final int payments;
  final int expCash;
  final int expOff;
  final int qtyOut;
  final int cogs; // coût d'achat des boissons sorties
  final List<(DateTime, int)> byDay;
  final List<int> byHour;
  final List<(String, int)> byServer;

  int get sales => salesCash + salesCredit;
  int get cashBalance => salesCash + payments - expCash;
  int get gross => sales - cogs;
  int get net => gross - expCash - expOff;
}

class ClosedDay {
  ClosedDay(this.day, this.summary);
  final WorkDay day;
  final DaySummary summary;
}

class ReportService {
  ReportService(this.db);
  final AppDatabase db;

  Future<String> establishmentName(int eid) async {
    final e = await (db.select(db.establishments)
          ..where((x) => x.id.equals(eid)))
        .getSingleOrNull();
    return e?.name ?? 'Maquis';
  }

  /// Période : de `from` (inclus) à `to` (exclu)
  Future<Report> build(int eid, DateTime from, DateTime to,
      {int? userId}) async {
    final sales = await (db.select(db.sales)
          ..where((s) {
            Expression<bool> p = s.establishmentId.equals(eid) &
                s.createdAt.isBiggerOrEqualValue(from) &
                s.createdAt.isSmallerThanValue(to);
            if (userId != null) p = p & s.userId.equals(userId);
            return p;
          }))
        .get();
    final pays = await (db.select(db.creditPayments)
          ..where((s) {
            Expression<bool> p = s.establishmentId.equals(eid) &
                s.createdAt.isBiggerOrEqualValue(from) &
                s.createdAt.isSmallerThanValue(to);
            if (userId != null) p = p & s.userId.equals(userId);
            return p;
          }))
        .get();
    final exps = await (db.select(db.expenses)
          ..where((s) {
            Expression<bool> p = s.establishmentId.equals(eid) &
                s.createdAt.isBiggerOrEqualValue(from) &
                s.createdAt.isSmallerThanValue(to);
            if (userId != null) p = p & s.userId.equals(userId);
            return p;
          }))
        .get();
    final moves = await (db.select(db.stockMovements)
          ..where((s) {
            Expression<bool> p = s.establishmentId.equals(eid) &
                s.type.equals('sale') &
                s.createdAt.isBiggerOrEqualValue(from) &
                s.createdAt.isSmallerThanValue(to);
            if (userId != null) p = p & s.userId.equals(userId);
            return p;
          }))
        .get();
    final users = await (db.select(db.users)
          ..where((u) => u.establishmentId.equals(eid)))
        .get();
    final names = {for (final u in users) u.id: u.name};

    var cash = 0;
    var credit = 0;
    final hours = List<int>.filled(24, 0);
    final perDay = <DateTime, int>{};
    final perServer = <int, int>{};
    for (final s in sales) {
      if (s.paymentMode == 'credit') {
        credit += s.total;
      } else {
        cash += s.total;
      }
      hours[s.createdAt.hour] += s.total;
      final d = DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day);
      perDay[d] = (perDay[d] ?? 0) + s.total;
      perServer[s.userId] = (perServer[s.userId] ?? 0) + s.total;
    }

    final days = to.difference(from).inDays;
    final byDay = <(DateTime, int)>[];
    if (days <= 93) {
      for (var i = 0; i < days; i++) {
        final d = DateTime(from.year, from.month, from.day + i);
        byDay.add((d, perDay[d] ?? 0));
      }
    } else {
      final keys = perDay.keys.toList()..sort();
      for (final k in keys) {
        byDay.add((k, perDay[k]!));
      }
    }

    final byServer = [
      for (final e in perServer.entries) (names[e.key] ?? '?', e.value)
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    return Report(
      salesCash: cash,
      salesCredit: credit,
      saleCount: sales.length,
      payments: pays.fold<int>(0, (a, p) => a + p.amount),
      expCash:
          exps.where((e) => e.fromCash).fold<int>(0, (a, e) => a + e.amount),
      expOff:
          exps.where((e) => !e.fromCash).fold<int>(0, (a, e) => a + e.amount),
      qtyOut: moves.fold<int>(0, (a, m) => a - m.quantity),
      cogs: moves.fold<int>(0, (a, m) => a - m.quantity * m.unitCost),
      byDay: byDay,
      byHour: hours,
      byServer: byServer,
    );
  }

  Future<List<ClosedDay>> closedDays(
      int eid, DateTime from, DateTime to) async {
    final days = await (db.select(db.workDays)
          ..where((d) =>
              d.establishmentId.equals(eid) &
              d.closedAt.isNotNull() &
              d.closedAt.isBiggerOrEqualValue(from) &
              d.closedAt.isSmallerThanValue(to))
          ..orderBy([(d) => OrderingTerm.desc(d.closedAt)]))
        .get();
    final svc = SalesService(db);
    final out = <ClosedDay>[];
    for (final d in days) {
      out.add(ClosedDay(d, await svc.summary(eid, d, counted: d.countedCash)));
    }
    return out;
  }
}
