import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../format.dart';
import '../providers.dart';
import '../services/stock_service.dart';

class LossesScreen extends ConsumerStatefulWidget {
  const LossesScreen({super.key});
  @override
  ConsumerState<LossesScreen> createState() => _LossesScreenState();
}

class _LossesScreenState extends ConsumerState<LossesScreen> {
  String _period = '7 jours';
  late Future<List<LossRow>> _future;

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<List<LossRow>> _load() {
    final now = DateTime.now();
    final from = switch (_period) {
      '7 jours' => now.subtract(const Duration(days: 7)),
      '30 jours' => now.subtract(const Duration(days: 30)),
      _ => null,
    };
    return ref.read(stockServiceProvider).losses(_eid, from);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pertes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              for (final p in ['7 jours', '30 jours', 'Tout'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: _period == p,
                    onSelected: (_) => setState(() {
                      _period = p;
                      _future = _load();
                    }),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: FutureBuilder<List<LossRow>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return const Center(
                      child: Text('Aucune perte sur cette période.'));
                }
                final qty = list.fold<int>(0, (a, l) => a + l.quantity);
                final val = list.fold<int>(0, (a, l) => a + l.value);
                return Column(children: [
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListTile(
                      title: Text('$qty unité(s) perdue(s)'),
                      subtitle: const Text('Valeur au prix d’achat'),
                      trailing: Text(fcfa(val),
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final l = list[i];
                        return ListTile(
                          title: Text('${l.drinkName} × ${l.quantity}'),
                          subtitle: Text(
                              '${dateFr(l.date)}${l.note == null ? '' : '\n${l.note}'}'),
                          isThreeLine: l.note != null,
                          trailing: Text(fcfa(l.value),
                              style:
                                  const TextStyle(color: Colors.redAccent)),
                        );
                      },
                    ),
                  ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
