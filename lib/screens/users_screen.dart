import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});
  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  late Future<List<User>> _future;

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  @override
  void initState() {
    super.initState();
    _future = ref.read(authServiceProvider).users(_eid);
  }

  void _reload() =>
      setState(() => _future = ref.read(authServiceProvider).users(_eid));

  Future<void> _add() async {
    final name = TextEditingController();
    final pin = TextEditingController();
    String? err;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nouveau serveur'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nom')),
            TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'Code PIN (4 à 6 chiffres)')),
            if (err != null)
              Text(err!, style: const TextStyle(color: Colors.redAccent)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final e = await ref.read(authServiceProvider).addEmployee(
                    establishmentId: _eid, name: name.text, pin: pin.text);
                if (e != null) {
                  setD(() => err = e);
                } else {
                  if (ctx.mounted) Navigator.pop(ctx);
                  _reload();
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.person_add),
          label: const Text('Ajouter')),
      body: FutureBuilder<List<User>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: [
              for (final u in snap.data!)
                ListTile(
                  leading: Icon(u.role == 'owner'
                      ? Icons.verified_user
                      : Icons.person),
                  title: Text(u.name),
                  subtitle:
                      Text(u.role == 'owner' ? 'Propriétaire' : 'Serveur'),
                  trailing: u.role == 'owner'
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ref
                                .read(authServiceProvider)
                                .deleteUser(u.id);
                            _reload();
                          }),
                ),
            ],
          );
        },
      ),
    );
  }
}
