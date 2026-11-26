import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_shell.dart';
import 'database/app_database.dart';
import 'providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/setup_screen.dart';
import 'theme.dart';

void main() => runApp(const ProviderScope(child: MaquisApp()));

class MaquisApp extends StatelessWidget {
  const MaquisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maquis Manager',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const Gate(),
    );
  }
}

class Gate extends ConsumerWidget {
  const Gate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Indique à la base qui est connecté, pour attribuer chaque action
    ref.listen<User?>(sessionProvider, (prev, next) async {
      final audit = ref.read(auditServiceProvider);
      if (prev != null && next == null) {
        await audit.logAs(
            prev, 'Déconnexion', 'Session', 'Déconnexion de ${prev.name}');
      }
      await audit.setUser(next?.id);
      if (next != null) {
        await audit.logAs(
            next, 'Connexion', 'Session', 'Connexion de ${next.name}');
      }
    });
    if (ref.watch(sessionProvider) != null) return const AppShell();
    return ref.watch(hasOwnerProvider).when(
          data: (has) => has ? const LoginScreen() : const SetupScreen(),
          loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
        );
  }
}
