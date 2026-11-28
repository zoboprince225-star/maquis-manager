import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../services/printer_service.dart';
import '../services/receipt_builder.dart';
import '../services/receipt_service.dart';
import 'receipt_preview.dart';

/// Ouvre l'aperçu du reçu d'une vente, puis imprime si on le confirme
Future<void> printSaleReceipt(
    BuildContext context, WidgetRef ref, int saleId) async {
  final messenger = ScaffoldMessenger.of(context);
  final data = await ReceiptService(ref.read(dbProvider)).forSale(saleId);
  if (data == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Vente introuvable.')));
    return;
  }
  final width = await PrinterService.paperChars();
  if (!context.mounted) return;
  await showReceiptPreview(
    context,
    title: 'Reçu n°${data.saleId}',
    builder: saleReceipt(data, width),
  );
}

/// Après une vente : affiche l'aperçu du reçu de la dernière vente enregistrée
Future<void> offerReceipt(BuildContext context, WidgetRef ref) async {
  if (!await PrinterService.askAfterSale()) return;
  final eid = ref.read(sessionProvider)!.establishmentId;
  final id = await ReceiptService(ref.read(dbProvider)).latestSaleId(eid);
  if (id == null || !context.mounted) return;
  await printSaleReceipt(context, ref, id);
}
