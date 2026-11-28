import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../format.dart';
import 'audit_service.dart';
import 'sales_service.dart';

class _Abort implements Exception {
  _Abort(this.message);
  final String message;
}

class EditableSale {
  EditableSale({
    required this.sale,
    required this.drinkQty,
    required this.kitQty,
    required this.drinkPrice,
    required this.kitPrice,
    required this.consumed,
  });
  final Sale sale;
  final Map<int, int> drinkQty;
  final Map<int, int> kitQty;
  final Map<int, int> drinkPrice;
  final Map<int, int> kitPrice;
  /// Boissons déjà prélevées dans le stock par cette vente (kits décomposés)
  final Map<int, int> consumed;
}

class SalesAdminService {
  SalesAdminService(this.db);
  final AppDatabase db;

  static const _locked =
      'Seules les ventes et dépenses de la journée en cours peuvent être modifiées. Une journée clôturée est verrouillée.';

  Future<bool> _isOwner(int userId) async {
    final u = await (db.select(db.users)..where((x) => x.id.equals(userId)))
        .getSingleOrNull();
    return u?.role == 'owner';
  }

  Future<Sale?> _sale(int id) =>
      (db.select(db.sales)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<String?> _checkSale(Sale s) async {
    final day = await SalesService(db).openDay(s.establishmentId);
    if (day == null || s.workDayId != day.id) return _locked;
    return null;
  }

  Future<String?> _checkExpense(Expense e) async {
    final day = await SalesService(db).openDay(e.establishmentId);
    if (day == null || e.createdAt.isBefore(day.openedAt)) return _locked;
    return null;
  }

  Future<String> _describe(Sale s) async {
    final drinks = {
      for (final d in await (db.select(db.drinks)
            ..where((d) => d.establishmentId.equals(s.establishmentId)))
          .get())
        d.id: d.name
    };
    final kits = {
      for (final k in await (db.select(db.kits)
            ..where((k) => k.establishmentId.equals(s.establishmentId)))
          .get())
        k.id: k.name
    };
    final items = await (db.select(db.saleItems)
          ..where((i) => i.saleId.equals(s.id)))
        .get();
    final text = items.map((i) {
      final n = (i.drinkId != null ? drinks[i.drinkId] : kits[i.kitId]) ?? '?';
      return '$n ×${i.quantity}';
    }).join(', ');
    return '${fcfa(s.total)} (${s.paymentMode == 'credit' ? 'crédit' : 'espèces'}) — $text';
  }

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

  /// Vérifie qu'un client ne se retrouve pas avec une dette négative
  Future<String?> _creditCheck(Sale old,
      {int? newCustomer, int newTotal = 0}) async {
    final delta = <int, int>{};
    if (old.paymentMode == 'credit' && old.customerId != null) {
      delta[old.customerId!] = (delta[old.customerId!] ?? 0) - old.total;
    }
    if (newCustomer != null) {
      delta[newCustomer] = (delta[newCustomer] ?? 0) + newTotal;
    }
    final balances = await SalesService(db).customers(old.establishmentId);
    for (final e in delta.entries) {
      final b = balances.where((x) => x.customer.id == e.key);
      if (b.isNotEmpty && b.first.owed + e.value < 0) {
        return 'Impossible : ce client a déjà payé plus que sa nouvelle dette (${b.first.customer.name}).';
      }
    }
    return null;
  }

  // ---------- Ventes ----------

  Future<EditableSale?> load(int saleId) async {
    final sale = await _sale(saleId);
    if (sale == null) return null;
    final items = await (db.select(db.saleItems)
          ..where((i) => i.saleId.equals(saleId)))
        .get();
    final dq = <int, int>{};
    final kq = <int, int>{};
    final dp = <int, int>{};
    final kp = <int, int>{};
    for (final i in items) {
      if (i.drinkId != null) {
        dq[i.drinkId!] = (dq[i.drinkId!] ?? 0) + i.quantity;
        dp[i.drinkId!] = i.unitPrice;
      } else if (i.kitId != null) {
        kq[i.kitId!] = (kq[i.kitId!] ?? 0) + i.quantity;
        kp[i.kitId!] = i.unitPrice;
      }
    }
    final moves = await (db.select(db.stockMovements)
          ..where((m) =>
              m.establishmentId.equals(sale.establishmentId) &
              m.type.equals('sale') &
              m.note.equals('Vente #$saleId')))
        .get();
    final consumed = <int, int>{};
    for (final m in moves) {
      consumed[m.drinkId] = (consumed[m.drinkId] ?? 0) - m.quantity;
    }
    return EditableSale(
      sale: sale,
      drinkQty: dq,
      kitQty: kq,
      drinkPrice: dp,
      kitPrice: kp,
      consumed: consumed,
    );
  }

  Future<String?> deleteSale(int saleId, int userId) async {
    if (!await _isOwner(userId)) return 'Réservé au propriétaire.';
    final sale = await _sale(saleId);
    if (sale == null) return 'Vente introuvable.';
    final lock = await _checkSale(sale);
    if (lock != null) return lock;
    final credit = await _creditCheck(sale);
    if (credit != null) return credit;
    final desc = await _describe(sale);
    await db.transaction(() async {
      await (db.delete(db.stockMovements)
            ..where((m) =>
                m.establishmentId.equals(sale.establishmentId) &
                m.type.equals('sale') &
                m.note.equals('Vente #$saleId')))
          .go();
      await (db.delete(db.saleItems)..where((i) => i.saleId.equals(saleId)))
          .go();
      await (db.delete(db.sales)..where((s) => s.id.equals(saleId))).go();
    });
    await AuditService(db)
        .logCurrent('Suppression', 'Vente', 'Vente n°$saleId supprimée : $desc');
    return null;
  }

  Future<String?> editSale({
    required int saleId,
    required int userId,
    required List<SaleLine> lines,
    required String mode,
    int? customerId,
  }) async {
    if (!await _isOwner(userId)) return 'Réservé au propriétaire.';
    if (lines.isEmpty) {
      return 'Ajoute au moins un article. Pour annuler la vente, utilise « Supprimer ».';
    }
    if (mode == 'credit' && customerId == null) {
      return 'Choisis un client pour la vente à crédit.';
    }
    final sale = await _sale(saleId);
    if (sale == null) return 'Vente introuvable.';
    final lock = await _checkSale(sale);
    if (lock != null) return lock;

    final total = lines.fold<int>(0, (a, l) => a + l.price * l.qty);
    final newCustomer = mode == 'credit' ? customerId : null;
    final credit =
        await _creditCheck(sale, newCustomer: newCustomer, newTotal: total);
    if (credit != null) return credit;

    final before = await _describe(sale);
    final eid = sale.establishmentId;

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
    final oldMoves = await (db.select(db.stockMovements)
          ..where((m) =>
              m.establishmentId.equals(eid) &
              m.type.equals('sale') &
              m.note.equals('Vente #$saleId')))
        .get();
    final oldCost = {for (final m in oldMoves) m.drinkId: m.unitCost};

    try {
      await db.transaction(() async {
        await (db.delete(db.stockMovements)
              ..where((m) =>
                  m.establishmentId.equals(eid) &
                  m.type.equals('sale') &
                  m.note.equals('Vente #$saleId')))
            .go();
        final stock = await _stock(eid);
        for (final e in need.entries) {
          final have = stock[e.key] ?? 0;
          if (e.value > have) {
            throw _Abort(
                'Stock insuffisant : ${byId[e.key]?.name ?? '?'} (reste $have, demandé ${e.value}).');
          }
        }
        await (db.update(db.sales)..where((s) => s.id.equals(saleId))).write(
            SalesCompanion(
          total: Value(total),
          paymentMode: Value(mode),
          customerId: Value(newCustomer),
        ));
        await (db.delete(db.saleItems)..where((i) => i.saleId.equals(saleId)))
            .go();
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
          await db.into(db.stockMovements).insert(
                StockMovementsCompanion.insert(
                  establishmentId: eid,
                  drinkId: e.key,
                  type: 'sale',
                  quantity: -e.value,
                  unitCost: Value(
                      oldCost[e.key] ?? byId[e.key]?.purchasePrice ?? 0),
                  note: Value('Vente #$saleId'),
                  userId: Value(sale.userId),
                  createdAt: Value(sale.createdAt),
                ),
              );
        }
      });
    } on _Abort catch (e) {
      return e.message;
    }

    final updated = await _sale(saleId);
    final after = updated == null ? '' : await _describe(updated);
    await AuditService(db).logCurrent('Modification', 'Vente',
        'Vente n°$saleId modifiée : $before → $after');
    return null;
  }

  // ---------- Dépenses ----------

  Future<String?> deleteExpense(int id, int userId) async {
    if (!await _isOwner(userId)) return 'Réservé au propriétaire.';
    final e = await (db.select(db.expenses)..where((x) => x.id.equals(id)))
        .getSingleOrNull();
    if (e == null) return 'Dépense introuvable.';
    final lock = await _checkExpense(e);
    if (lock != null) return lock;
    await (db.delete(db.expenses)..where((x) => x.id.equals(id))).go();
    await AuditService(db).logCurrent('Suppression', 'Dépense',
        'Dépense supprimée : ${e.label} — ${fcfa(e.amount)} (${e.fromCash ? 'caisse' : 'hors caisse'})');
    return null;
  }

  Future<String?> editExpense({
    required int id,
    required int userId,
    required String label,
    required int amount,
    required bool fromCash,
  }) async {
    if (!await _isOwner(userId)) return 'Réservé au propriétaire.';
    if (label.trim().isEmpty) return 'Saisis un libellé.';
    if (amount <= 0) return 'Saisis un montant.';
    final e = await (db.select(db.expenses)..where((x) => x.id.equals(id)))
        .getSingleOrNull();
    if (e == null) return 'Dépense introuvable.';
    final lock = await _checkExpense(e);
    if (lock != null) return lock;
    await (db.update(db.expenses)..where((x) => x.id.equals(id))).write(
        ExpensesCompanion(
      label: Value(label.trim()),
      amount: Value(amount),
      fromCash: Value(fromCash),
    ));
    await AuditService(db).logCurrent('Modification', 'Dépense',
        'Dépense modifiée : ${e.label} — ${fcfa(e.amount)} (${e.fromCash ? 'caisse' : 'hors caisse'}) → ${label.trim()} — ${fcfa(amount)} (${fromCash ? 'caisse' : 'hors caisse'})');
    return null;
  }
}
