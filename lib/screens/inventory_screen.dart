import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../format.dart';
import '../providers.dart';
import '../services/stock_service.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  List<StockRow>? _rows;
  final Map<int, TextEditingController> _c = {};
  String? _error;

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  @override
  void initState() {
    super.initState();
    ref.read(stockServiceProvider).rows(_eid).then((r) {
      if (!mounted) return;
      setState(() {
        _rows = r;
        for (final x in r) {
          _c[x.drink.id] = TextEditingController();
        }
      });
    });
  }

  Future<void> _save() async {
    final counted = <int, int>{};
    for (final e in _c.entries) {
      final v = int.tryParse(e.value.text);
      if (v != null) counted[e.key] = v;
    }
    if (counted.isEmpty) {
      setState(() => _error = 'Compte au moins une boisson.');
      return;
    }
    final res = await ref.read(stockServiceProvider).inventory(
          eid: _eid,
          userId: ref.read(sessionProvider)!.id,
          counted: counted,
        );
    if (!mounted) return;
    final lines = <String>[
      if (res.lossQty > 0)
        'Manque : ${res.lossQty} unité(s), soit ${fcfa(res.lossValue)} au prix d’achat.',
      if (res.gainQty > 0) 'Surplus : ${res.gainQty} unité(s).',
      if (res.lossQty == 0 && res.gainQty == 0) 'Aucun écart : le stock est exact.',
    ];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inventaire enregistré'),
        content: Text(lines.join('\n\n')),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider)?.role != 'owner') {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventaire')),
        body: const Center(child: Text('Réservé au propriétaire.')),
      );
    }
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Inventaire')),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(
                  child: Text('Crée d’abord des boissons dans le catalogue.'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text(
                        'Compte ce qu’il y a vraiment en rayon et saisis la quantité. Laisse vide les boissons que tu ne comptes pas.',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    for (final r in rows)
                      ListTile(
                        title: Text(r.drink.name),
                        subtitle: Text('Stock théorique : ${r.stock}'),
                        trailing: SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _c[r.drink.id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration:
                                const InputDecoration(hintText: 'Compté'),
                          ),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.redAccent))),
                    const SizedBox(height: 90),
                  ],
                ),
      bottomNavigationBar: rows == null || rows.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                    onPressed: _save,
                    child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Valider l’inventaire'))),
              ),
            ),
    );
  }
}
