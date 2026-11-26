import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _maquis = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(authServiceProvider).createOwner(
            establishment: _maquis.text.trim(),
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            password: _pass.text,
            pin: _pin.text.trim(),
          );
      ref.read(sessionProvider.notifier).state = user;
    } catch (e) {
      setState(() {
        _error = 'Erreur : $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenue')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Crée ton compte propriétaire',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _maquis,
                  decoration: const InputDecoration(labelText: 'Nom du maquis'),
                  validator: _req),
              TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Ton nom'),
                  validator: _req),
              TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? '8 chiffres minimum'
                      : null),
              TextFormField(
                  controller: _pass,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Mot de passe'),
                  validator: (v) => (v == null || v.length < 6)
                      ? '6 caractères minimum'
                      : null),
              TextFormField(
                  controller: _pass2,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Confirmer le mot de passe'),
                  validator: (v) =>
                      v != _pass.text ? 'Les mots de passe diffèrent' : null),
              TextFormField(
                  controller: _pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Code PIN (facultatif, 4 à 6 chiffres)'),
                  validator: (v) => (v == null ||
                          v.isEmpty ||
                          (v.length >= 4 && v.length <= 6))
                      ? null
                      : '4 à 6 chiffres'),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent))),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Créer mon compte')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
