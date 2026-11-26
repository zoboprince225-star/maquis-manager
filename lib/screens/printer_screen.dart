import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/printer_service.dart';
import '../services/receipt_builder.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});
  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  String? _mac;
  String? _name;
  int _chars = 32;
  bool _ask = true;
  List<BluetoothInfo> _devices = [];
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mac = await PrinterService.savedMac();
    final name = await PrinterService.savedName();
    final chars = await PrinterService.paperChars();
    final ask = await PrinterService.askAfterSale();
    if (!mounted) return;
    setState(() {
      _mac = mac;
      _name = name;
      _chars = chars;
      _ask = ask;
    });
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      if (!await PrinterService.ensurePermissions()) {
        _msg = 'Autorise le Bluetooth dans les réglages de l’application.';
      } else if (!await PrintBluetoothThermal.bluetoothEnabled) {
        _msg = 'Active le Bluetooth du téléphone.';
      } else {
        _devices = await PrinterService.paired();
        if (_devices.isEmpty) {
          _msg =
              'Aucun appareil jumelé. Jumelle d’abord l’imprimante dans Réglages › Bluetooth du téléphone (code 0000 ou 1234).';
        }
      }
    } catch (e) {
      _msg = 'Erreur : $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _select(BluetoothInfo d) async {
    setState(() {
      _busy = true;
      _msg = 'Connexion à ${d.name}…';
    });
    final ok = await PrinterService.connect(d.macAdress);
    if (ok) {
      await PrinterService.save(d.macAdress, d.name);
      _mac = d.macAdress;
      _name = d.name;
      _msg = 'Imprimante enregistrée. Fais un test d’impression.';
    } else {
      _msg =
          'Connexion impossible. Allume l’imprimante, rapproche-la, puis réessaie.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = await PrinterService.printBytes(buildTestReceipt(_chars));
    if (mounted) {
      setState(() {
        _busy = false;
        _msg = err ?? 'Test envoyé à l’imprimante.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Imprimante')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.print),
              title: Text(_name ?? 'Aucune imprimante choisie'),
              subtitle: Text(_mac ?? 'Choisis-en une ci-dessous'),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Largeur du papier'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 32, label: Text('58 mm')),
              ButtonSegment(value: 48, label: Text('80 mm')),
            ],
            selected: {_chars},
            onSelectionChanged: (s) async {
              await PrinterService.setPaperChars(s.first);
              setState(() => _chars = s.first);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Proposer l’impression après chaque vente'),
            value: _ask,
            onChanged: (v) async {
              await PrinterService.setAskAfterSale(v);
              setState(() => _ask = v);
            },
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _search,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Rechercher les imprimantes jumelées')),
          ),
          for (final d in _devices)
            ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(d.name),
              subtitle: Text(d.macAdress),
              trailing: d.macAdress == _mac
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: _busy ? null : () => _select(d),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: (_busy || _mac == null) ? null : _test,
            icon: const Icon(Icons.receipt_long),
            label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Imprimer un test')),
          ),
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator())),
          if (_msg != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_msg!, style: const TextStyle(color: Colors.amber))),
        ],
      ),
    );
  }
}
