import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../format.dart';
import '../providers.dart';
import '../services/sales_service.dart';
import 'receipt_actions.dart';
import 'sale_screen.dart';

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});
  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  List<SaleRow> _rows = [];

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<void> _reload() async {
    final n = DateTime.now();
    final r = await ref
        .read(salesServiceProvider)
        .salesSince(_eid, DateTime(n.year, n.month, n.day));
    if (mounted) setState(() => _rows = r);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dataTickProvider, (_, __) => _reload());
    final total = _rows.fold<int>(0, (a, r) => a + r.sale.total);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SaleScreen())),
          icon: const Icon(Icons.add),
          label: const Padding(
              padding: EdgeInsets.all(12), child: Text('Nouvelle vente')),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            title: const Text('Ventes d’aujourd’hui'),
            subtitle: Text('${_rows.length} vente(s)'),
            trailing: Text(fcfa(total),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
          ),
        ),
        if (_rows.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Aucune vente aujourd’hui.'))),
        for (final r in _rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
                r.sale.paymentMode == 'credit'
                    ? Icons.credit_score
                    : Icons.payments,
                color: r.sale.paymentMode == 'credit'
                    ? Colors.orange
                    : Colors.green),
            title: Text(fcfa(r.sale.total)),
            subtitle: Text(
                '${hourFr(r.sale.createdAt)} · ${r.sale.paymentMode == 'credit' ? 'Crédit' : 'Espèces'}\n${r.items}'),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'Réimprimer le reçu',
              icon: const Icon(Icons.print),
              onPressed: () => printSaleReceipt(context, ref, r.sale.id),
            ),
          ),
      ],
    );
  }
}
