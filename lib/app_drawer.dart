import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'screens/users_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(sessionProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(u?.name ?? ''),
              subtitle: Text(u?.role == 'owner' ? 'Propriétaire' : 'Serveur'),
            ),
            const Divider(),
            if (u?.role == 'owner')
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Utilisateurs'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const UsersScreen()));
                },
              ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Déconnexion'),
              onTap: () {
                Navigator.pop(context);
                ref.read(sessionProvider.notifier).state = null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
