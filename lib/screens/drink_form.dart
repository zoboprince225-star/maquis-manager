import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../database/app_database.dart';
import '../providers.dart';
import '../services/photo_service.dart';
import '../widgets/drink_photo.dart';

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
  String? _photo;
  String? _newPhoto; // photo choisie dans ce formulaire, pas encore enregistrée
  bool _saved = false;

  int get _eid => ref.read(sessionProvider)!.establishmentId;
  bool get _editing => widget.drink != null;

  @override
  void initState() {
    super.initState();
    _photo = widget.drink?.photoPath;
  }

  @override
  void dispose() {
    // Formulaire fermé sans enregistrer : on supprime la photo orpheline
    if (!_saved && _newPhoto != null) PhotoService.delete(_newPhoto);
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final n = await PhotoService.pick(source);
      if (n == null) return;
      if (_newPhoto != null) await PhotoService.delete(_newPhoto);
      if (mounted) {
        setState(() {
          _photo = n;
          _newPhoto = n;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible d’ajouter la photo : $e');
    }
  }

  Future<void> _removePhoto() async {
    if (_photo != null && _photo == _newPhoto) {
      await PhotoService.delete(_photo);
      _newPhoto = null;
    }
    if (mounted) setState(() => _photo = null);
  }

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
          photo: _photo,
        );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    _saved = true;
    final old = widget.drink?.photoPath;
    if (old != null && old != _photo) await PhotoService.delete(old);
    if (mounted) Navigator.pop(context, true);
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
      _saved = true;
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
            const SizedBox(height: 12),
            Row(children: [
              DrinkPhoto(name: _photo, size: 80),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(spacing: 4, children: [
                  TextButton.icon(
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galerie')),
                  TextButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Appareil photo')),
                  if (_photo != null)
                    TextButton.icon(
                        onPressed: _removePhoto,
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        label: const Text('Retirer')),
                ]),
              ),
            ]),
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
