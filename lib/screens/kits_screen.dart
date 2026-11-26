import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../format.dart';
import '../providers.dart';
import '../services/catalog_service.dart';

class KitsScreen extends ConsumerStatefulWidget {
  const KitsScreen({super.key});
  @override
  ConsumerState<KitsScreen> createState() => _KitsScreenState();
}

class _KitsScreenState extends ConsumerState<KitsScreen> {
  late Future<List<KitView>> _future;

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  @override
  void initState() {
    super.initState();
    _future = ref.read(catalogServiceProvider).kits(_eid);
  }

  void _reload() => setState(
      () => _future = ref.read(catalogServiceProvider).kits(_eid));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalogue kits')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Kit'),
        onPressed: () async {
          final ok = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => const KitFormScreen()));
          if (ok == true) _reload();
        },
      ),
      body: FutureBuilder<List<KitView>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data!.isEmpty) {
            return const Center(
                child: Text('Aucun kit. Appuie sur « Kit ».'));
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              for (final k in snap.data!)
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(k.kit.name),
                    subtitle: Text(k.lines
                        .map((l) => '${l.drink?.name ?? '?'} × ${l.quantity}')
                        .join('\n')),
                    isThreeLine: k.lines.length > 1,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(fcfa(k.kit.salePrice),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        InkWell(
                          onTap: () async {
                            await ref
                                .read(catalogServiceProvider)
                                .deleteKit(k.kit.id);
                            _reload();
                          },
                          child: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Line {
  int? drinkId;
  int qty = 1;
}

class KitFormScreen extends ConsumerStatefulWidget {
  const KitFormScreen({super.key});
  @override
  ConsumerState<KitFormScreen> createState() => _KitFormScreenState();
}

class _KitFormScreenState extends ConsumerState<KitFormScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final List<_Line> _lines = [_Line()];
  List<Drink> _drinks = [];
  String? _error;

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  @override
  void initState() {
    super.initState();
    ref.read(catalogServiceProvider).drinks(_eid).then((d) {
      if (mounted) setState(() => _drinks = d);
    });
  }

  int get _separate {
    var t = 0;
    for (final l in _lines) {
      if (l.drinkId == null) continue;
      final d = _drinks.where((x) => x.id == l.drinkId);
      if (d.isNotEmpty) t += d.first.salePrice * l.qty;
    }
    return t;
  }

  Future<void> _save() async {
    final map = <int, int>{};
    for (final l in _lines) {
      if (l.drinkId != null) {
        map[l.drinkId!] = (map[l.drinkId!] ?? 0) + l.qty;
      }
    }
    final err = await ref.read(catalogServiceProvider).saveKit(
          eid: _eid,
          name: _name.text,
          price: int.tryParse(_price.text) ?? 0,
          lines: map,
        );
    if (err != null) {
      setState(() => _error = err);
    } else if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Nom du kit (ex. Casier Flag, Cocktail maison)')),
          TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration:
                  const InputDecoration(labelText: 'Prix du kit (FCFA)')),
          const SizedBox(height: 16),
          Text('Boissons du kit',
              style: Theme.of(context).textTheme.titleMedium),
          if (_drinks.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Crée d’abord au moins une boisson.')),
          for (var i = 0; i < _lines.length; i++)
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _lines[i].drinkId,
                  isExpanded: true,
                  hint: const Text('Choisir une boisson'),
                  items: [
                    for (final d in _drinks)
                      DropdownMenuItem(value: d.id, child: Text(d.name))
                  ],
                  onChanged: (v) => setState(() => _lines[i].drinkId = v),
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() {
                        if (_lines[i].qty > 1) _lines[i].qty--;
                      })),
              Text('${_lines[i].qty}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _lines[i].qty++)),
              if (_lines.length > 1)
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _lines.removeAt(i))),
            ]),
          TextButton.icon(
              onPressed: () => setState(() => _lines.add(_Line())),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une boisson')),
          Text('Prix si vendues séparément : ${fcfa(_separate)}',
              style: const TextStyle(color: Colors.white70)),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: _save,
              child: const Padding(
                  padding: EdgeInsets.all(12), child: Text('Enregistrer le kit'))),
        ],
      ),
    );
  }
}
