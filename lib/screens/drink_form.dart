import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers.dart';

Future<bool?> showDrinkForm(BuildContext context, {Drink? drink}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DrinkForm(drink: drink),
  );
}

class _DrinkForm extends ConsumerStatefulWidget {
  const _DrinkForm({this.drink});
  final Drink? drink;
  @override
  ConsumerState<_DrinkForm> createState() => _DrinkFormState();
}

class _DrinkFormState extends ConsumerState<_DrinkForm> {
  late final _name = TextEditingController(text: widget.drink?.name ?? '');
  late final _cat = TextEditingController(text: widget.drink?.category ?? '');
  late final _buy = TextEditingController(
      text: widget.drink == null ? '' : '${widget.drink!.purchasePrice}');
  late final _sell = TextEditingController(
      text: widget.drink == null ? '' : '${widget.drink!.salePrice}');
  late final _th = TextEditingController(
      text: '${widget.drink?.alertThreshold ?? 5}');
  final _stock = TextEditingController();
  String? _error;

  int get _eid => ref.read(sessionProvider)!.establishmentId;
  bool get _editing => widget.drink != null;

  Future<void> _save() async {
    final cat = _cat.text.trim();
    final err = await ref.read(catalogServiceProvider).saveDrink(
          id: widget.drink?.id,
          eid: _eid,
          name: _name.text,
          category: cat.isEmpty ? null : cat,
          purchase: int.tryParse(_buy.text) ?? 0,
          sale: int.tryParse(_sell.text) ?? 0,
          threshold: int.tryParse(_th.text) ?? 5,
          initialStock: int.tryParse(_stock.text) ?? 0,
        );
    if (err != null) {
      setState(() => _error = err);
    } else if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette boisson ?'),
        content: Text(widget.drink!.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    final err =
        await ref.read(catalogServiceProvider).deleteDrink(widget.drink!.id);
    if (err != null) {
      setState(() => _error = err);
    } else if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_editing ? 'Modifier la boisson' : 'Créer une boisson',
                style: Theme.of(context).textTheme.titleLarge),
            TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nom')),
            TextField(
                controller: _cat,
                decoration: const InputDecoration(
                    labelText: 'Catégorie (bière, soda, alcool fort…)')),
            _num(_buy, 'Prix d’achat (FCFA)'),
            _num(_sell, 'Prix de vente (FCFA)'),
            _num(_th, 'Seuil d’alerte de stock'),
            if (!_editing) _num(_stock, 'Stock initial (facultatif)'),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 16),
            Row(children: [
              if (_editing)
                IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent)),
              Expanded(
                  child: FilledButton(
                      onPressed: _save,
                      child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Enregistrer')))),
            ]),
          ],
        ),
      ),
    );
  }
}
