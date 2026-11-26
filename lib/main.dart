import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_shell.dart';
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
    if (ref.watch(sessionProvider) != null) return const AppShell();
    return ref.watch(hasOwnerProvider).when(
          data: (has) => has ? const LoginScreen() : const SetupScreen(),
          loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
        );
  }
}
