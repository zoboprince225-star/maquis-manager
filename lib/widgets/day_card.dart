import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../format.dart';
import '../providers.dart';

class DayCard extends ConsumerStatefulWidget {
  const DayCard({super.key});
  @override
  ConsumerState<DayCard> createState() => _DayCardState();
}

class _DayCardState extends ConsumerState<DayCard> {
  WorkDay? _day;
  bool _ready = false;

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<void> _reload() async {
    final d = await ref.read(salesServiceProvider).openDay(_eid);
    if (mounted) {
      setState(() {
        _day = d;
        _ready = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _tick() => ref.read(dataTickProvider.notifier).state++;

  Future<int?> _askAmount(String title, String label, {String? info}) {
    final c = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (info != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12), child: Text(info)),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: label),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(c.text) ?? 0),
              child: const Text('Valider')),
        ],
      ),
    );
  }

  Future<void> _start() async {
    final amount =
        await _askAmount('Démarrer la journée', 'Fond de caisse (FCFA)');
    if (amount == null) return;
    final err = await ref.read(salesServiceProvider).startDay(_eid, amount);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
    _tick();
  }

  Future<void> _close(WorkDay day) async {
    final s = await ref.read(salesServiceProvider).summary(_eid, day);
    if (!mounted) return;
    final counted = await _askAmount(
        'Clôturer la journée', 'Argent compté en caisse (FCFA)',
        info: 'Montant attendu : ${fcfa(s.expected)}');
    if (counted == null) return;
    final res = await ref.read(salesServiceProvider).closeDay(_eid, counted);
    if (!mounted || res == null) return;
    final d = res.diff ?? 0;
    final ecart = d == 0
        ? 'Caisse juste.'
        : d < 0
            ? 'Manque : ${fcfa(-d)}'
            : 'Excédent : ${fcfa(d)}';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Journée clôturée'),
        content: Text('Ventes : ${fcfa(res.totalSales)}\n'
            'Attendu en caisse : ${fcfa(res.expected)}\n'
            'Compté : ${fcfa(counted)}\n\n$ecart'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
    _tick();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dataTickProvider, (_, __) => _reload());
    final day = _day;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(day == null ? Icons.cancel_outlined : Icons.check_circle,
              size: 32, color: day == null ? Colors.white54 : Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Journée de travail',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                    !_ready
                        ? '…'
                        : day == null
                            ? 'Aucune journée démarrée'
                            : 'Ouverte depuis ${hourFr(day.openedAt)}',
                    style: TextStyle(
                        color: day == null ? Colors.white70 : Colors.greenAccent)),
              ],
            ),
          ),
          if (_ready)
            FilledButton(
              onPressed: day == null ? _start : () => _close(day),
              child: Text(day == null ? 'Démarrer' : 'Clôturer'),
            ),
        ]),
      ),
    );
  }
}
