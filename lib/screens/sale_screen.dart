import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../format.dart';
import '../providers.dart';
import '../services/catalog_service.dart';
import '../services/sales_admin_service.dart';
import '../services/sales_service.dart';
import '../services/stock_service.dart';
import '../widgets/drink_photo.dart'; // PHOTOS
import 'customers_screen.dart';
import 'receipt_actions.dart';

class SaleScreen extends ConsumerStatefulWidget {
  const SaleScreen({super.key, this.editSaleId});

  /// Si renseigné : modification d'une vente existante (propriétaire seul)
  final int? editSaleId;

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
  Map<int, int> _restore = {};
  Map<int, int> _origD = {};
  Map<int, int> _origK = {};
  bool _blocked = false;
  String _mode = 'cash';
  int? _customerId;
  String? _error;

  bool get _editing => widget.editSaleId != null;
  int get _eid => ref.read(sessionProvider)!.establishmentId;

  int _pd(Drink d) => _origD[d.id] ?? d.salePrice;
  int _pk(Kit k) => _origK[k.id] ?? k.salePrice;

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

  Future<void> _prefill() async {
    final e = await SalesAdminService(ref.read(dbProvider))
        .load(widget.editSaleId!);
    if (!mounted) return;
    if (e == null) {
      setState(() {
        _error = 'Vente introuvable.';
        _blocked = true;
      });
      return;
    }
    final missing =
        e.drinkQty.keys.any((id) => !_stock.any((r) => r.drink.id == id)) ||
            e.kitQty.keys.any((id) => !_kits.any((k) => k.kit.id == id));
    setState(() {
      _dq
        ..clear()
        ..addAll(e.drinkQty);
      _kq
        ..clear()
        ..addAll(e.kitQty);
      _origD = e.drinkPrice;
      _origK = e.kitPrice;
      _restore = e.consumed;
      _mode = e.sale.paymentMode;
      _customerId = e.sale.customerId;
      if (missing) {
        _blocked = true;
        _error =
            'Cette vente contient un article supprimé du catalogue : elle ne peut pas être modifiée. Tu peux la supprimer.';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAll().then((_) {
      if (_editing) _prefill();
    });
  }

  int get _total {
    var t = 0;
    for (final r in _stock) {
      t += (_dq[r.drink.id] ?? 0) * _pd(r.drink);
    }
    for (final k in _kits) {
      t += (_kq[k.kit.id] ?? 0) * _pk(k.kit);
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
              price: _pd(r.drink)),
      for (final k in _kits)
        if ((_kq[k.kit.id] ?? 0) > 0)
          SaleLine(kitId: k.kit.id, qty: _kq[k.kit.id]!, price: _pk(k.kit)),
    ];
    final total = _total;
    final user = ref.read(sessionProvider)!;
    final String? err;
    if (_editing) {
      err = await SalesAdminService(ref.read(dbProvider)).editSale(
        saleId: widget.editSaleId!,
        userId: user.id,
        lines: lines,
        mode: _mode,
        customerId: _mode == 'credit' ? _customerId : null,
      );
    } else {
      err = await ref.read(salesServiceProvider).recordSale(
            eid: _eid,
            userId: user.id,
            lines: lines,
            mode: _mode,
            customerId: _mode == 'credit' ? _customerId : null,
          );
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    ref.read(dataTickProvider.notifier).state++;
    if (!mounted) return;
    if (_editing) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vente modifiée : ${fcfa(total)}')));
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vente enregistrée : ${fcfa(total)}')));
    await offerReceipt(context, ref);
    if (mounted) Navigator.pop(context, true);
  }

  /// Fenêtre de saisie de la quantité avec le clavier numérique
  Future<void> _askQty(
      String name, int current, int max, ValueChanged<int> onSet) async {
    final c = TextEditingController(text: current > 0 ? '$current' : '');
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Quantité',
            helperText: max < 999 ? 'Maximum en stock : $max' : null,
          ),
          onSubmitted: (t) => Navigator.pop(ctx, int.tryParse(t) ?? 0),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(c.text) ?? 0),
              child: const Text('OK')),
        ],
      ),
    );
    if (v == null) return;
    var q = v;
    if (q > max) {
      q = max;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stock insuffisant : maximum $max')));
      }
    }
    setState(() => onSet(q));
  }

  Widget _stepper({
    required int qty,
    required int max,
    required String name,
    required VoidCallback minus,
    required VoidCallback? plus,
    required ValueChanged<int> onSet,
  }) {
    const compact = BoxConstraints(minWidth: 36, minHeight: 36);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          padding: EdgeInsets.zero,
          constraints: compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: qty > 0 ? minus : null),
      InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _askQty(name, qty, max, onSet),
        child: Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: qty > 0 ? null : Colors.white54)),
        ),
      ),
      IconButton(
          padding: EdgeInsets.zero,
          constraints: compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: plus),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing && ref.watch(sessionProvider)?.role != 'owner') {
      return Scaffold(
        appBar: AppBar(title: const Text('Modifier la vente')),
        body: const Center(child: Text('Réservé au propriétaire.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
          title: Text(_editing
              ? 'Modifier la vente n°${widget.editSaleId}'
              : 'Nouvelle vente')),
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
                        subtitle: Text(fcfa(_pk(k.kit))),
                        trailing: _stepper(
                          qty: _kq[k.kit.id] ?? 0,
                          max: 999,
                          name: k.kit.name,
                          minus: () => setState(
                              () => _kq[k.kit.id] = (_kq[k.kit.id] ?? 0) - 1),
                          plus: () => setState(
                              () => _kq[k.kit.id] = (_kq[k.kit.id] ?? 0) + 1),
                          onSet: (q) => _kq[k.kit.id] = q,
                        ),
                      ),
                    const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text('Boissons',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                    for (final r in _stock)
                      Builder(builder: (context) {
                        final avail = r.stock + (_restore[r.drink.id] ?? 0);
                        return ListTile(
                          leading: DrinkPhoto(name: r.drink.photoPath, size: 44), // PHOTOS
                          title: Text(r.drink.name),
                          subtitle: Text(
                              '${fcfa(_pd(r.drink))} · stock $avail',
                              style: TextStyle(
                                  color: avail <= 0 ? Colors.redAccent : null)),
                          trailing: _stepper(
                            qty: _dq[r.drink.id] ?? 0,
                            max: avail,
                            name: r.drink.name,
                            minus: () => setState(() =>
                                _dq[r.drink.id] = (_dq[r.drink.id] ?? 0) - 1),
                            plus: (_dq[r.drink.id] ?? 0) < avail
                                ? () => setState(() => _dq[r.drink.id] =
                                    (_dq[r.drink.id] ?? 0) + 1)
                                : null,
                            onSet: (q) => _dq[r.drink.id] = q,
                          ),
                        );
                      }),
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
                      onPressed: (_total > 0 && !_blocked) ? _validate : null,
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_editing
                              ? 'Enregistrer les modifications · ${fcfa(_total)}'
                              : 'Valider · ${fcfa(_total)}')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
