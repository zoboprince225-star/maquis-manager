import 'package:flutter/material.dart';
import '../services/printer_service.dart';
import '../services/receipt_builder.dart';

Future<void> showReceiptPreview(
  BuildContext context, {
  required String title,
  required ReceiptBuilder builder,
  String successMessage = 'Reçu imprimé',
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PreviewDialog(
        title: title, builder: builder, successMessage: successMessage),
  );
}

class _PreviewDialog extends StatefulWidget {
  const _PreviewDialog({
    required this.title,
    required this.builder,
    required this.successMessage,
  });
  final String title;
  final ReceiptBuilder builder;
  final String successMessage;

  @override
  State<_PreviewDialog> createState() => _PreviewDialogState();
}

class _PreviewDialogState extends State<_PreviewDialog> {
  bool _busy = false;
  bool _ok = false;
  String? _msg;

  Future<void> _print() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = await PrinterService.printBytes(widget.builder.bytes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = err == null;
      _msg = err ?? widget.successMessage;
    });
  }

  Widget _line(PreviewLine l, double fs) {
    if (l.isCut) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(Icons.content_cut, size: 14, color: Colors.black38),
          SizedBox(width: 6),
          Expanded(child: Divider(color: Colors.black26)),
        ]),
      );
    }
    return Text(
      l.text.isEmpty ? ' ' : l.text,
      textAlign: l.align == 1
          ? TextAlign.center
          : (l.align == 2 ? TextAlign.right : TextAlign.left),
      softWrap: l.big,
      maxLines: l.big ? null : 1,
      overflow: TextOverflow.clip,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: l.big ? fs * 2 : fs,
        fontWeight: l.bold ? FontWeight.bold : FontWeight.normal,
        color: Colors.black87,
        height: 1.25,
      ),
    );
  }

  Widget _paper() {
    final chars = widget.builder.width;
    return LayoutBuilder(builder: (context, c) {
      // La police est ajustée pour que la largeur du papier tienne à l'écran
      final fs = ((c.maxWidth - 24) / (chars * 0.6)).clamp(7.0, 13.0);
      return Center(
        child: Container(
          width: chars * fs * 0.6 + 24,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF8F0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final l in widget.builder.preview) _line(l, fs)],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: SingleChildScrollView(child: _paper())),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_msg!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _ok ? Colors.green : Colors.redAccent)),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                'Aperçu : la mise en page réelle peut varier légèrement selon l’imprimante.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer')),
        FilledButton.icon(
          onPressed: _busy ? null : _print,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.print),
          label: Text(_ok ? 'Réimprimer' : 'Imprimer'),
        ),
      ],
    );
  }
}
