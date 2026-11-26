import 'dart:convert';
import 'dart:io';
import '../database/app_database.dart';

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
    };
    final data = {
      'app': 'maquis-manager',
      'schema': db.schemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'tables': tables,
    };
    return utf8.encode(jsonEncode(data));
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

    try {
      final est = rows('establishments', Establishment.fromJson);
      final users = rows('users', User.fromJson);
      final drinks = rows('drinks', Drink.fromJson);
      final kits = rows('kits', Kit.fromJson);
      final kitItems = rows('kitItems', KitItem.fromJson);
      final moves = rows('stockMovements', StockMovement.fromJson);
      final days = rows('workDays', WorkDay.fromJson);
      final sales = rows('sales', Sale.fromJson);
      final saleItems = rows('saleItems', SaleItem.fromJson);
      final expenses = rows('expenses', Expense.fromJson);
      final customers = rows('customers', Customer.fromJson);
      final payments = rows('creditPayments', CreditPayment.fromJson);
      if (users.isEmpty || est.isEmpty) {
        return 'La sauvegarde ne contient aucun compte utilisateur.';
      }
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
        });
      });
    } catch (e) {
      return 'Échec de la restauration : $e';
    }
    return null;
  }
}
