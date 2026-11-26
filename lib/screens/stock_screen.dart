import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/stock_service.dart';
import 'inventory_screen.dart';
import 'supply_screen.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});
  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  late Future<List<StockRow>> _future;
  String _filter = 'Tous';

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<List<StockRow>> _load() =>
      ref.read(stockServiceProvider).rows(_eid);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  Color _color(StockRow r) =>
      r.empty ? Colors.redAccent : (r.low ? Colors.orange : Colors.green);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('État des stocks'),
        actions: [
          IconButton(
              tooltip: 'Approvisionnement',
              icon: const Icon(Icons.local_shipping),
              onPressed: () => _go(const SupplyScreen())),
          IconButton(
              tooltip: 'Inventaire',
              icon: const Icon(Icons.fact_check),
              onPressed: () => _go(const InventoryScreen())),
        ],
      ),
      body: FutureBuilder<List<StockRow>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          int count(String l) => all.where((r) => r.label == l).length;
          final list = _filter == 'Tous'
              ? all
              : all.where((r) => r.label == _filter).toList();
          final chips = <String, int>{
            'Tous': all.length,
            'Épuisé': count('Épuisé'),
            'Presque épuisé': count('Presque épuisé'),
            'Normal': count('Normal'),
          };
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  for (final e in chips.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${e.key} (${e.value})'),
                        selected: _filter == e.key,
                        onSelected: (_) => setState(() => _filter = e.key),
                      ),
                    ),
                ]),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Aucune boisson ici.'))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = list[i];
                          return ListTile(
                            title: Text(r.drink.name),
                            subtitle:
                                Text('Seuil d’alerte : ${r.drink.alertThreshold}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${r.stock}',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                Text(r.label,
                                    style: TextStyle(
                                        color: _color(r), fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
