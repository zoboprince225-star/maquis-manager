import 'dart:convert';
import 'dart:io';
import '../database/app_database.dart';
import 'audit_service.dart';
import 'photo_service.dart';

class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  Future<List<int>> export() async {
    final tables = <String, List<Map<String, dynamic>>>{
      'establishments': [
        for (final r in await db.select(db.establishments).get()) r.toJson()
      ],
      'users': [for (final r in await db.select(db.users).get()) r.toJson()],
      'drinks': [for (final r in await db.select(db.drinks).get()) r.toJson()],
      'kits': [for (final r in await db.select(db.kits).get()) r.toJson()],
      'kitItems': [
        for (final r in await db.select(db.kitItems).get()) r.toJson()
      ],
      'stockMovements': [
        for (final r in await db.select(db.stockMovements).get()) r.toJson()
      ],
      'workDays': [
        for (final r in await db.select(db.workDays).get()) r.toJson()
      ],
      'sales': [for (final r in await db.select(db.sales).get()) r.toJson()],
      'saleItems': [
        for (final r in await db.select(db.saleItems).get()) r.toJson()
      ],
      'expenses': [
        for (final r in await db.select(db.expenses).get()) r.toJson()
      ],
      'customers': [
        for (final r in await db.select(db.customers).get()) r.toJson()
      ],
      'creditPayments': [
        for (final r in await db.select(db.creditPayments).get()) r.toJson()
      ],
      'auditEntries': [
        for (final r in await db.select(db.auditEntries).get()) r.toJson()
      ],
    };
    final data = {
      'app': 'maquis-manager',
      'schema': db.schemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'tables': tables,
    };
    final bytes = utf8.encode(jsonEncode(data));
    await AuditService(db)
        .logCurrent('Sauvegarde', 'Sauvegarde', 'Sauvegarde créée et partagée');
    return bytes;
  }

  /// Retourne null si tout va bien, sinon un message d'erreur.
  /// Remplace TOUTES les données actuelles.
  Future<String?> restore(String path) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return 'Fichier illisible : ce n’est pas une sauvegarde valide.';
    }
    if (data['app'] != 'maquis-manager') {
      return 'Ce fichier n’est pas une sauvegarde de Maquis Manager.';
    }
    final schema = data['schema'];
    if (schema is! int || schema > db.schemaVersion) {
      return 'Cette sauvegarde vient d’une version plus récente de l’application. Mets l’application à jour.';
    }
    final t = data['tables'];
    if (t is! Map<String, dynamic>) return 'Sauvegarde vide ou abîmée.';

    List<T> rows<T>(String key, T Function(Map<String, dynamic>) f) {
      final l = t[key];
      if (l is! List) return <T>[];
      return [for (final e in l) f(e as Map<String, dynamic>)];
    }

    final List<Establishment> est;
    final List<User> users;
    final List<Drink> drinks;
    final List<Kit> kits;
    final List<KitItem> kitItems;
    final List<StockMovement> moves;
    final List<WorkDay> days;
    final List<Sale> sales;
    final List<SaleItem> saleItems;
    final List<Expense> expenses;
    final List<Customer> customers;
    final List<CreditPayment> payments;
    final List<AuditEntry> audit;
    try {
      est = rows('establishments', Establishment.fromJson);
      users = rows('users', User.fromJson);
      drinks = rows('drinks', Drink.fromJson);
      kits = rows('kits', Kit.fromJson);
      kitItems = rows('kitItems', KitItem.fromJson);
      moves = rows('stockMovements', StockMovement.fromJson);
      days = rows('workDays', WorkDay.fromJson);
      sales = rows('sales', Sale.fromJson);
      saleItems = rows('saleItems', SaleItem.fromJson);
      expenses = rows('expenses', Expense.fromJson);
      customers = rows('customers', Customer.fromJson);
      payments = rows('creditPayments', CreditPayment.fromJson);
      audit = rows('auditEntries', AuditEntry.fromJson);
    } catch (e) {
      return 'Sauvegarde illisible : $e';
    }
    if (users.isEmpty || est.isEmpty) {
      return 'La sauvegarde ne contient aucun compte utilisateur.';
    }

    // Qui lance la restauration (pour le journal)
    String? who;
    try {
      final s = await db.select(db.appSession).getSingleOrNull();
      final uid = s?.userId;
      if (uid != null) {
        final u = await (db.select(db.users)..where((x) => x.id.equals(uid)))
            .getSingleOrNull();
        who = u?.name;
      }
    } catch (_) {}

    // On coupe le journal automatique pendant le remplacement des données
    await db.customStatement('UPDATE app_session SET enabled = 0 WHERE id = 1');
    String? failure;
    try {
      await db.transaction(() async {
        await db.delete(db.establishments).go();
        await db.delete(db.users).go();
        await db.delete(db.drinks).go();
        await db.delete(db.kits).go();
        await db.delete(db.kitItems).go();
        await db.delete(db.stockMovements).go();
        await db.delete(db.workDays).go();
        await db.delete(db.sales).go();
        await db.delete(db.saleItems).go();
        await db.delete(db.expenses).go();
        await db.delete(db.customers).go();
        await db.delete(db.creditPayments).go();
        await db.delete(db.auditEntries).go();
        await db.batch((b) {
          b.insertAll(db.establishments, est);
          b.insertAll(db.users, users);
          b.insertAll(db.drinks, drinks);
          b.insertAll(db.kits, kits);
          b.insertAll(db.kitItems, kitItems);
          b.insertAll(db.stockMovements, moves);
          b.insertAll(db.workDays, days);
          b.insertAll(db.sales, sales);
          b.insertAll(db.saleItems, saleItems);
          b.insertAll(db.expenses, expenses);
          b.insertAll(db.customers, customers);
          b.insertAll(db.creditPayments, payments);
          b.insertAll(db.auditEntries, audit);
        });
      });
    } catch (e) {
      failure = 'Échec de la restauration : $e';
    }
    await db.customStatement('UPDATE app_session SET enabled = 1 WHERE id = 1');
    if (failure != null) return failure;

    await db.customStatement(
        'INSERT INTO audit_entries (establishment_id, user_id, user_name, action, entity, detail) VALUES (?, NULL, ?, ?, ?, ?)',
        [
          est.first.id,
          who,
          'Restauration',
          'Sauvegarde',
          'Toutes les données ont été remplacées par une sauvegarde'
        ]);
    return null;
  }
}
