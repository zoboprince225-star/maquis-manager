import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ReceiptLine {
  ReceiptLine(this.name, this.qty, this.price);
  final String name;
  final int qty;
  final int price;
}

class ReceiptData {
  ReceiptData({
    required this.establishment,
    required this.saleId,
    required this.date,
    required this.server,
    required this.credit,
    required this.lines,
    required this.total,
    this.customer,
  });
  final String establishment;
  final int saleId;
  final DateTime date;
  final String server;
  final bool credit;
  final String? customer;
  final List<ReceiptLine> lines;
  final int total;
}

class ReceiptService {
  ReceiptService(this.db);
  final AppDatabase db;

  Future<int?> latestSaleId(int eid) async {
    final s = await (db.select(db.sales)
          ..where((x) => x.establishmentId.equals(eid))
          ..orderBy([(x) => OrderingTerm.desc(x.id)])
          ..limit(1))
        .getSingleOrNull();
    return s?.id;
  }

  Future<ReceiptData?> forSale(int saleId) async {
    final sale = await (db.select(db.sales)
          ..where((s) => s.id.equals(saleId)))
        .getSingleOrNull();
    if (sale == null) return null;
    final est = await (db.select(db.establishments)
          ..where((e) => e.id.equals(sale.establishmentId)))
        .getSingleOrNull();
    final user = await (db.select(db.users)
          ..where((u) => u.id.equals(sale.userId)))
        .getSingleOrNull();
    String? customer;
    if (sale.customerId != null) {
      final c = await (db.select(db.customers)
            ..where((x) => x.id.equals(sale.customerId!)))
          .getSingleOrNull();
      customer = c?.name;
    }
    final items = await (db.select(db.saleItems)
          ..where((i) => i.saleId.equals(saleId)))
        .get();
    final lines = <ReceiptLine>[];
    for (final i in items) {
      var name = '?';
      if (i.drinkId != null) {
        final d = await (db.select(db.drinks)
              ..where((x) => x.id.equals(i.drinkId!)))
            .getSingleOrNull();
        name = d?.name ?? '?';
      } else if (i.kitId != null) {
        final k = await (db.select(db.kits)
              ..where((x) => x.id.equals(i.kitId!)))
            .getSingleOrNull();
        name = k?.name ?? '?';
      }
      lines.add(ReceiptLine(name, i.quantity, i.unitPrice));
    }
    return ReceiptData(
      establishment: est?.name ?? 'Maquis',
      saleId: sale.id,
      date: sale.createdAt,
      server: user?.name ?? '',
      credit: sale.paymentMode == 'credit',
      customer: customer,
      lines: lines,
      total: sale.total,
    );
  }
}
