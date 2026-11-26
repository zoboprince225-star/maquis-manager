import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'services/audit_service.dart';
import 'services/auth_service.dart';
import 'services/catalog_service.dart';
import 'services/sales_service.dart';
import 'services/stock_service.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(ref.watch(dbProvider)));

final catalogServiceProvider =
    Provider<CatalogService>((ref) => CatalogService(ref.watch(dbProvider)));

final stockServiceProvider =
    Provider<StockService>((ref) => StockService(ref.watch(dbProvider)));

final salesServiceProvider =
    Provider<SalesService>((ref) => SalesService(ref.watch(dbProvider)));

final auditServiceProvider =
    Provider<AuditService>((ref) => AuditService(ref.watch(dbProvider)));

/// Utilisateur connecté (null = personne)
final sessionProvider = StateProvider<User?>((ref) => null);

/// Compteur incrémenté après chaque opération pour rafraîchir les écrans
final dataTickProvider = StateProvider<int>((ref) => 0);

final hasOwnerProvider = FutureProvider<bool>(
    (ref) => ref.watch(authServiceProvider).hasOwner());
