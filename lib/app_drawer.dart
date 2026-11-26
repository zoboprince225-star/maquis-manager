import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'screens/drinks_screen.dart';
import 'screens/kits_screen.dart';
import 'screens/users_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(sessionProvider);
    final owner = u?.role == 'owner';
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(u?.name ?? ''),
              subtitle: Text(owner ? 'Propriétaire' : 'Serveur'),
            ),
            const Divider(),
            if (owner) ...[
              ListTile(
                leading: const Icon(Icons.local_bar),
                title: const Text('Catalogue boissons'),
                onTap: () => _open(context, const DrinksScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Catalogue kits'),
                onTap: () => _open(context, const KitsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Utilisateurs'),
                onTap: () => _open(context, const UsersScreen()),
              ),
            ],
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
