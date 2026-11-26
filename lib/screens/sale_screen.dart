import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../format.dart';
import '../providers.dart';
import '../services/catalog_service.dart';
import '../services/sales_service.dart';
import '../services/stock_service.dart';
import 'customers_screen.dart';
import 'receipt_actions.dart';

class SaleScreen extends ConsumerStatefulWidget {
  const SaleScreen({super.key});
  @override
  ConsumerState<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends ConsumerState<SaleScreen> {
  List<StockRow> _stock = [];
  List<KitView> _kits = [];
  List<CustomerBalance> _customers = [];
  bool _loaded = false;
  final Map<int, int> _dq = {};
  final Map<int, int> _kq = {};
  String _mode = 'cash';
  int? _customerId;
  String? _error;

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<void> _loadAll() async {
    final st = await ref.read(stockServiceProvider).rows(_eid);
    final kits = await ref.read(catalogServiceProvider).kits(_eid);
    final cus = await ref.read(salesServiceProvider).customers(_eid);
    if (!mounted) return;
    setState(() {
      _stock = st;
      _kits = kits;
      _customers = cus;
      _loaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  int get _total {
    var t = 0;
    for (final r in _stock) {
      t += (_dq[r.drink.id] ?? 0) * r.drink.salePrice;
    }
    for (final k in _kits) {
      t += (_kq[k.kit.id] ?? 0) * k.kit.salePrice;
    }
    return t;
  }

  Future<void> _validate() async {
    final lines = <SaleLine>[
      for (final r in _stock)
        if ((_dq[r.drink.id] ?? 0) > 0)
          SaleLine(
              drinkId: r.drink.id,
              qty: _dq[r.drink.id]!,
              price: r.drink.salePrice),
      for (final k in _kits)
        if ((_kq[k.kit.id] ?? 0) > 0)
          SaleLine(
              kitId: k.kit.id, qty: _kq[k.kit.id]!, price: k.kit.salePrice),
    ];
    final total = _total;
    final err = await ref.read(salesServiceProvider).recordSale(
          eid: _eid,
          userId: ref.read(sessionProvider)!.id,
          lines: lines,
          mode: _mode,
          customerId: _mode == 'credit' ? _customerId : null,
        );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    ref.read(dataTickProvider.notifier).state++;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vente enregistrée : ${fcfa(total)}')));
      Navigator.pop(context, true);
    }
  }

  Widget _stepper(int qty, VoidCallback minus, VoidCallback? plus) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: qty > 0 ? minus : null),
      SizedBox(
          width: 28,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: plus),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : (_stock.isEmpty && _kits.isEmpty)
              ? const Center(
                  child: Text('Crée d’abord des boissons dans le catalogue.'))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (_kits.isNotEmpty)
                      const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text('Kits',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    for (final k in _kits)
                      ListTile(
                        title: Text(k.kit.name),
                        subtitle: Text(fcfa(k.kit.salePrice)),
                        trailing: _stepper(
                          _kq[k.kit.id] ?? 0,
                          () => setState(
                              () => _kq[k.kit.id] = (_kq[k.kit.id] ?? 0) - 1),
                          () => setState(
                              () => _kq[k.kit.id] = (_kq[k.kit.id] ?? 0) + 1),
                        ),
                      ),
                    const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Boissons',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    for (final r in _stock)
                      ListTile(
                        title: Text(r.drink.name),
                        subtitle: Text(
                            '${fcfa(r.drink.salePrice)} · stock ${r.stock}',
                            style: TextStyle(
                                color: r.empty ? Colors.redAccent : null)),
                        trailing: _stepper(
                          _dq[r.drink.id] ?? 0,
                          () => setState(
                              () => _dq[r.drink.id] = (_dq[r.drink.id] ?? 0) - 1),
                          (_dq[r.drink.id] ?? 0) < r.stock
                              ? () => setState(() =>
                                  _dq[r.drink.id] = (_dq[r.drink.id] ?? 0) + 1)
                              : null,
                        ),
                      ),
                  ],
                ),
      bottomNavigationBar: !_loaded
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'cash',
                            label: Text('Espèces'),
                            icon: Icon(Icons.payments)),
                        ButtonSegment(
                            value: 'credit',
                            label: Text('Crédit'),
                            icon: Icon(Icons.credit_score)),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                    if (_mode == 'credit')
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _customerId,
                            isExpanded: true,
                            hint: const Text('Choisir le client'),
                            items: [
                              for (final c in _customers)
                                DropdownMenuItem(
                                    value: c.customer.id,
                                    child: Text(c.customer.name))
                            ],
                            onChanged: (v) => setState(() => _customerId = v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          onPressed: () async {
                            final id = await showCustomerForm(context, ref);
                            if (id != null) {
                              await _loadAll();
                              setState(() => _customerId = id);
                            }
                          },
                        ),
                      ]),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.redAccent))),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _total > 0 ? _validate : null,
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('Valider · ${fcfa(_total)}')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
