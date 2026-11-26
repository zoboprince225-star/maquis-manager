import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'services/auth_service.dart';
import 'services/catalog_service.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(ref.watch(dbProvider)));

final catalogServiceProvider =
    Provider<CatalogService>((ref) => CatalogService(ref.watch(dbProvider)));

/// Utilisateur connecté (null = personne)
final sessionProvider = StateProvider<User?>((ref) => null);

final hasOwnerProvider = FutureProvider<bool>(
    (ref) => ref.watch(authServiceProvider).hasOwner());
