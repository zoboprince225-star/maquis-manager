import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'screens/analysis_screen.dart';
import 'screens/audit_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/drinks_screen.dart';
import 'screens/export_screen.dart';
import 'screens/kits_screen.dart';
import 'screens/losses_screen.dart';
import 'screens/printer_screen.dart';
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
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.credit_score),
                    title: const Text('Crédits clients'),
                    onTap: () => _open(context, const CustomersScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.print),
                    title: const Text('Imprimante'),
                    onTap: () => _open(context, const PrinterScreen()),
                  ),
                  if (owner) ...[
                    ListTile(
                      leading: const Icon(Icons.insights),
                      title: const Text('Bénéfices et bilans'),
                      onTap: () => _open(context, const AnalysisScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.policy),
                      title: const Text('Journal d’audit'),
                      onTap: () => _open(context, const AuditScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.file_download),
                      title: const Text('Exports (CSV, Excel, PDF)'),
                      onTap: () => _open(context, const ExportScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.backup),
                      title: const Text('Sauvegarde et restauration'),
                      onTap: () => _open(context, const BackupScreen()),
                    ),
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
                      leading: const Icon(Icons.report_problem_outlined),
                      title: const Text('Pertes'),
                      onTap: () => _open(context, const LossesScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.group),
                      title: const Text('Utilisateurs'),
                      onTap: () => _open(context, const UsersScreen()),
                    ),
                  ],
                ],
              ),
            ),
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
