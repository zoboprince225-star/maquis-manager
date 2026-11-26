import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/printer_service.dart';
import '../services/receipt_builder.dart';
import '../services/receipt_service.dart';

Future<void> printSaleReceipt(
    BuildContext context, WidgetRef ref, int saleId) async {
  final messenger = ScaffoldMessenger.of(context);
  final data = await ReceiptService(ref.read(dbProvider)).forSale(saleId);
  if (data == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Vente introuvable.')));
    return;
  }
  final width = await PrinterService.paperChars();
  final err = await PrinterService.printBytes(buildSaleReceipt(data, width));
  messenger.showSnackBar(SnackBar(content: Text(err ?? 'Reçu imprimé')));
}

/// Propose d'imprimer le reçu de la dernière vente enregistrée
Future<void> offerReceipt(BuildContext context, WidgetRef ref) async {
  if (!await PrinterService.askAfterSale()) return;
  final eid = ref.read(sessionProvider)!.establishmentId;
  final id = await ReceiptService(ref.read(dbProvider)).latestSaleId(eid);
  if (id == null || !context.mounted) return;
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Imprimer le reçu ?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Imprimer')),
      ],
    ),
  );
  if (yes == true && context.mounted) {
    await printSaleReceipt(context, ref, id);
  }
}
