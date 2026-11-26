import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../format.dart';
import '../providers.dart';
import '../services/sales_service.dart';
import '../widgets/day_card.dart';
import 'expense_form.dart';

class CaissePage extends ConsumerStatefulWidget {
  const CaissePage({super.key});
  @override
  ConsumerState<CaissePage> createState() => _CaissePageState();
}

class _CaissePageState extends ConsumerState<CaissePage> {
  WorkDay? _day;
  DaySummary? _sum;
  List<Expense> _exps = [];

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<void> _reload() async {
    final s = ref.read(salesServiceProvider);
    final day = await s.openDay(_eid);
    DaySummary? sum;
    var exps = <Expense>[];
    if (day != null) {
      sum = await s.summary(_eid, day);
      exps = await s.dayExpenses(_eid, day);
    }
    if (!mounted) return;
    setState(() {
      _day = day;
      _sum = sum;
      _exps = exps;
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Widget _row(String label, int value, {Color? color, bool bold = false}) {
    final style = TextStyle(
        color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(fcfa(value), style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dataTickProvider, (_, __) => _reload());
    final s = _sum;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DayCard(),
        const SizedBox(height: 12),
        if (_day == null || s == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Text('Démarre la journée pour suivre la caisse.')),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _row('Fond de caisse', s.opening),
                _row('Ventes en espèces', s.cashSales, color: Colors.green),
                _row('Crédits encaissés', s.payments, color: Colors.green),
                _row('Dépenses de caisse', -s.cashExpenses,
                    color: Colors.redAccent),
                const Divider(),
                _row('Solde attendu en caisse', s.expected, bold: true),
                const Divider(),
                _row('Ventes à crédit (non encaissées)', s.creditSales,
                    color: Colors.orange),
                _row('Dépenses hors caisse', s.offExpenses,
                    color: Colors.white70),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => showExpenseForm(context),
            icon: const Icon(Icons.payments),
            label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Enregistrer une dépense')),
          ),
          const SizedBox(height: 16),
          Text('Dépenses de la journée',
              style: Theme.of(context).textTheme.titleMedium),
          if (_exps.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aucune dépense.')),
          for (final e in _exps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.label),
              subtitle: Text(
                  '${hourFr(e.createdAt)} · ${e.fromCash ? 'Caisse' : 'Hors caisse'}'),
              trailing: Text(fcfa(e.amount),
                  style: const TextStyle(color: Colors.redAccent)),
            ),
        ],
      ],
    );
  }
}
