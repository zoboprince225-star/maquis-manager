import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pin = TextEditingController();
  String? _error;

  void _done(AuthResult r) {
    if (r.user != null) {
      ref.read(sessionProvider.notifier).state = r.user;
    } else {
      setState(() => _error = r.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connexion'),
          bottom: const TabBar(
              tabs: [Tab(text: 'Mot de passe'), Tab(text: 'Code PIN')]),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              ListView(padding: const EdgeInsets.all(20), children: [
                TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone')),
                TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Mot de passe')),
                _err(),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () async =>
                        _done(await auth.loginPassword(_phone.text, _pass.text)),
                    child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Se connecter'))),
              ]),
              ListView(padding: const EdgeInsets.all(20), children: [
                TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 8),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Code PIN')),
                _err(),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: () async => _done(await auth.loginPin(_pin.text)),
                    child: const Padding(
                        padding: EdgeInsets.all(12), child: Text('Entrer'))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _err() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent)));
}
