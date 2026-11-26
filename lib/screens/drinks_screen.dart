import '../widgets/drink_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../format.dart';
import '../providers.dart';
import 'drink_form.dart';

class DrinksScreen extends ConsumerStatefulWidget {
  const DrinksScreen({super.key});
  @override
  ConsumerState<DrinksScreen> createState() => _DrinksScreenState();
}

class _DrinksScreenState extends ConsumerState<DrinksScreen> {
  late Future<(List<Drink>, Map<int, int>)> _future;
  String _q = '';

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<(List<Drink>, Map<int, int>)> _load() async {
    final s = ref.read(catalogServiceProvider);
    return (await s.drinks(_eid), await s.stock(_eid));
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  (String, Color) _status(int stock, int threshold) {
    if (stock <= 0) return ('Épuisé', Colors.redAccent);
    if (stock <= threshold) return ('Presque épuisé', Colors.orange);
    return ('Normal', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue boissons')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Boisson'),
        onPressed: () async {
          if (await showDrinkForm(context) == true) _reload();
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher une boisson',
                  border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _q = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<(List<Drink>, Map<int, int>)>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stock = snap.data!.$2;
                final list = snap.data!.$1
                    .where((d) => d.name.toLowerCase().contains(_q))
                    .toList();
                if (list.isEmpty) {
                  return const Center(
                      child: Text('Aucune boisson. Appuie sur « Boisson ».'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final d = list[i];
                    final s = stock[d.id] ?? 0;
                    final st = _status(s, d.alertThreshold);
                    return ListTile(
                      title: Text(d.name),
                      subtitle: Text(
                          '${d.category == null ? '' : '${d.category} · '}'
                          'Vente ${fcfa(d.salePrice)} · Achat ${fcfa(d.purchasePrice)}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$s',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(st.$1,
                              style: TextStyle(color: st.$2, fontSize: 12)),
                        ],
                      ),
                      onTap: () async {
                        if (await showDrinkForm(context, drink: d) == true) {
                          _reload();
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
