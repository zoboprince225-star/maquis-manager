import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/activation_service.dart';

final activatedProvider =
    FutureProvider<bool>((ref) => ActivationService.isActivated());

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});
  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _c = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ActivationService.activate(_c.text);
    if (!mounted) return;
    if (err == null) {
      ref.invalidate(activatedProvider);
    } else {
      setState(() {
        _error = err;
        _busy = false;
      });
      _c.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 64, color: color),
                const SizedBox(height: 16),
                Text('Maquis Manager',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                  'Saisis le code d’activation à 8 chiffres pour utiliser l’application.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _c,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 28, letterSpacing: 6),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: 'Code d’activation', counterText: ''),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: const Padding(
                        padding: EdgeInsets.all(12), child: Text('Activer')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
