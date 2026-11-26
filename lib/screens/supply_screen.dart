import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/stock_service.dart';

class SupplyScreen extends ConsumerStatefulWidget {
  const SupplyScreen({super.key});
  @override
  ConsumerState<SupplyScreen> createState() => _SupplyScreenState();
}

class _SupplyScreenState extends ConsumerState<SupplyScreen> {
  List<StockRow>? _rows;
  final Map<int, TextEditingController> _c = {};
  final _note = TextEditingController();
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
    final q = <int, int>{
      for (final e in _c.entries) e.key: int.tryParse(e.value.text) ?? 0
    };
    final note = _note.text.trim();
    final err = await ref.read(stockServiceProvider).supply(
          eid: _eid,
          userId: ref.read(sessionProvider)!.id,
          quantities: q,
          note: note.isEmpty ? null : note,
        );
    if (err != null) {
      setState(() => _error = err);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Approvisionnement enregistré')));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Approvisionnement')),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? const Center(
                  child: Text('Crée d’abord des boissons dans le catalogue.'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text('Saisis la quantité reçue pour chaque boisson.',
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    for (final r in rows)
                      ListTile(
                        title: Text(r.drink.name),
                        subtitle: Text('Stock actuel : ${r.stock}'),
                        trailing: SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _c[r.drink.id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: const InputDecoration(hintText: 'Qté'),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: _note,
                        decoration: const InputDecoration(
                            labelText: 'Note (fournisseur, facture…)')),
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
                        child: Text('Enregistrer l’approvisionnement'))),
              ),
            ),
    );
  }
}
