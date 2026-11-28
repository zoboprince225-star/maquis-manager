import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../format.dart';
import '../providers.dart';
import '../services/sales_admin_service.dart';
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
  int? _openDayId;

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<void> _reload() async {
    final n = DateTime.now();
    final svc = ref.read(salesServiceProvider);
    final r = await svc.salesSince(_eid, DateTime(n.year, n.month, n.day));
    final day = await svc.openDay(_eid);
    if (mounted) {
      setState(() {
        _rows = r;
        _openDayId = day?.id;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _edit(SaleRow r) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SaleScreen(editSaleId: r.sale.id)));
    if (mounted) _reload();
  }

  Future<void> _delete(SaleRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer la vente n°${r.sale.id} ?'),
        content: Text(
            '${fcfa(r.sale.total)}\n${r.items}\n\nLe stock sera remis à jour et, si la vente était à crédit, la dette du client diminuera.'),
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
    if (ok != true || !mounted) return;
    final err = await SalesAdminService(ref.read(dbProvider))
        .deleteSale(r.sale.id, ref.read(sessionProvider)!.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? 'Vente supprimée')));
    if (err == null) ref.read(dataTickProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dataTickProvider, (_, __) => _reload());
    final owner = ref.watch(sessionProvider)?.role == 'owner';
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
                'N°${r.sale.id} · ${hourFr(r.sale.createdAt)} · ${r.sale.paymentMode == 'credit' ? 'Crédit' : 'Espèces'}\n${r.items}'),
            isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Réimprimer le reçu',
                icon: const Icon(Icons.print),
                onPressed: () => printSaleReceipt(context, ref, r.sale.id),
              ),
              if (owner &&
                  r.sale.workDayId != null &&
                  r.sale.workDayId == _openDayId)
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? _edit(r) : _delete(r),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
            ]),
          ),
      ],
    );
  }
}
