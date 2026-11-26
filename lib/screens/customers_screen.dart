import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../format.dart';
import '../providers.dart';
import '../services/sales_service.dart';

/// Retourne l'identifiant du client créé (ou null)
Future<int?> showCustomerForm(BuildContext context, WidgetRef ref) {
  final name = TextEditingController();
  final phone = TextEditingController();
  String? err;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Nouveau client'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nom')),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Téléphone (facultatif)')),
          if (err != null)
            Text(err!, style: const TextStyle(color: Colors.redAccent)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final r = await ref.read(salesServiceProvider).addCustomer(
                  ref.read(sessionProvider)!.establishmentId,
                  name.text,
                  phone.text);
              if (r.$2 != null) {
                setD(() => err = r.$2);
              } else if (ctx.mounted) {
                Navigator.pop(ctx, r.$1);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
}

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  List<CustomerBalance>? _list;

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<void> _reload() async {
    final l = await ref.read(salesServiceProvider).customers(_eid);
    if (mounted) setState(() => _list = l);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _pay(CustomerBalance b) async {
    final c = TextEditingController(text: '${b.owed}');
    String? err;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Paiement de ${b.customer.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Dette actuelle : ${fcfa(b.owed)}'),
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Montant payé'),
            ),
            if (err != null)
              Text(err!, style: const TextStyle(color: Colors.redAccent)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final u = ref.read(sessionProvider)!;
                final e = await ref.read(salesServiceProvider).addPayment(
                      eid: u.establishmentId,
                      userId: u.id,
                      customerId: b.customer.id,
                      amount: int.tryParse(c.text) ?? 0,
                    );
                if (e != null) {
                  setD(() => err = e);
                } else {
                  ref.read(dataTickProvider.notifier).state++;
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Encaisser'),
            ),
          ],
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final total = list?.fold<int>(0, (a, b) => a + b.owed) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Crédits clients')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Client'),
        onPressed: () async {
          await showCustomerForm(context, ref);
          _reload();
        },
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Center(
                  child: Text('Aucun client. Appuie sur « Client ».'))
              : Column(children: [
                  Card(
                    margin: const EdgeInsets.all(12),
                    child: ListTile(
                      title: const Text('Total dû par les clients'),
                      trailing: Text(fcfa(total),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final b = list[i];
                        return ListTile(
                          title: Text(b.customer.name),
                          subtitle: b.customer.phone == null
                              ? null
                              : Text(b.customer.phone!),
                          trailing: b.owed > 0
                              ? Text(fcfa(b.owed),
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold))
                              : const Text('Soldé',
                                  style: TextStyle(color: Colors.green)),
                          onTap: b.owed > 0 ? () => _pay(b) : null,
                        );
                      },
                    ),
                  ),
                ]),
    );
  }
}
