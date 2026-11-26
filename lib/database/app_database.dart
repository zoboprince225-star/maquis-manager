import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Establishments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get establishmentId => integer()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get role => text().withDefault(const Constant('employee'))();
  TextColumn get passwordHash => text()();
  TextColumn get pinHash => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Drinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get establishmentId => integer()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  IntColumn get purchasePrice => integer().withDefault(const Constant(0))();
  IntColumn get salePrice => integer().withDefault(const Constant(0))();
  IntColumn get alertThreshold => integer().withDefault(const Constant(5))();
  TextColumn get photoPath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Kits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get establishmentId => integer()();
  TextColumn get name => text()();
  IntColumn get salePrice => integer().withDefault(const Constant(0))();
}

class KitItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get kitId => integer()();
  IntColumn get drinkId => integer()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get establishmentId => integer()();
  IntColumn get drinkId => integer()();
  // supply, sale, loss, inventory
  TextColumn get type => text()();
  IntColumn get quantity => integer()(); // signé : + entrée, - sortie
  IntColumn get unitCost => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  IntColumn get userId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class WorkDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get establishmentId => integer()();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get openingCash => integer().withDefault(const Constant(0))();
  IntColumn get countedCash => integer().nullable()();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get establishmentId => integer()();
  IntColumn get userId => integer()();
  IntColumn get workDayId => integer().nullable()();
  IntColumn get total => integer()();
  // cash ou credit
  TextColumn get paymentMode => text().withDefault(const Constant('cash'))();
  IntColumn get customerId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer()();
  IntColumn get drinkId => integer().nullable()();
  IntColumn get kitId => integer().nullable()();
  IntColumn get quantity => integer()();
  IntColumn get unitPrice => integer()();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get establishmentId => integer()();
  TextColumn get label => text()();
  IntColumn get amount => integer()();
  BoolColumn get fromCash => boolean().withDefault(const Constant(true))();
  IntColumn get userId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get establishmentId => integer()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
}

class CreditPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get establishmentId => integer()();
  IntColumn get customerId => integer()();
  IntColumn get workDayId => integer().nullable()();
  IntColumn get amount => integer()();
  IntColumn get userId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  Establishments,
  Users,
  Drinks,
  Kits,
  KitItems,
  StockMovements,
  WorkDays,
  Sales,
  SaleItems,
  Expenses,
  Customers,
  CreditPayments,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'maquis_manager'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(customers);
            await m.createTable(creditPayments);
            await m.addColumn(sales, sales.customerId);
          }
        },
      );
}
