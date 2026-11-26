import '../format.dart';
import 'receipt_service.dart';

const _map = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', 'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i', 'î': 'i',
  'ï': 'i', 'ñ': 'n', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'œ': 'oe',
  'À': 'A', 'Â': 'A', 'Ä': 'A', 'Á': 'A', 'Ã': 'A', 'Å': 'A', 'Ç': 'C',
  'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E', 'Í': 'I', 'Ì': 'I', 'Î': 'I',
  'Ï': 'I', 'Ñ': 'N', 'Ó': 'O', 'Ò': 'O', 'Ô': 'O', 'Ö': 'O', 'Õ': 'O',
  'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U', 'Ý': 'Y', 'Œ': 'OE',
  '’': "'", '‘': "'", '“': '"', '”': '"', '«': '"', '»': '"',
  '–': '-', '—': '-', '…': '...', '×': 'x', '·': '-',
};

String _ascii(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (r >= 32 && r < 127) {
      b.write(c);
    } else {
      b.write(_map[c] ?? '?');
    }
  }
  return b.toString();
}

String _n(int v) => fcfa(v).replaceAll(' FCFA', '');

class ReceiptBuilder {
  ReceiptBuilder(this.width);
  final int width; // 32 (58 mm) ou 48 (80 mm)
  final List<int> _b = [];

  List<int> get bytes => _b;

  void init() => _b.addAll([0x1B, 0x40]);
  void align(int n) => _b.addAll([0x1B, 0x61, n]); // 0 gauche, 1 centre, 2 droite
  void bold(bool on) => _b.addAll([0x1B, 0x45, on ? 1 : 0]);
  void big(bool on) => _b.addAll([0x1D, 0x21, on ? 0x11 : 0x00]);
  void feed(int n) => _b.addAll([0x1B, 0x64, n]);
  void cut() => _b.addAll([0x1D, 0x56, 0x42, 0x00]);

  void line(String s) {
    _b.addAll(_ascii(s).codeUnits);
    _b.add(0x0A);
  }

  void sep() => line('-' * width);

  /// Texte à gauche, valeur à droite
  void lr(String l, String r) {
    final rr = _ascii(r);
    var ll = _ascii(l);
    final room = width - rr.length - 1;
    if (ll.length > room) ll = ll.substring(0, room < 0 ? 0 : room);
    line(ll.padRight(width - rr.length) + rr);
  }

  String fit(String s) {
    final a = _ascii(s);
    return a.length > width ? a.substring(0, width) : a;
  }
}

List<int> buildTestReceipt(int width) {
  final r = ReceiptBuilder(width)..init();
  r.align(1);
  r.bold(true);
  r.line('TEST IMPRIMANTE');
  r.bold(false);
  r.line('Maquis Manager');
  r.sep();
  r.align(0);
  r.line('Accents : e a u c -> OK');
  r.lr('Total exemple', '1 400 FCFA');
  r.sep();
  r.align(1);
  r.line('Impression reussie !');
  r.feed(4);
  r.cut();
  return r.bytes;
}

List<int> buildSaleReceipt(ReceiptData d, int width) {
  final r = ReceiptBuilder(width)..init();
  r.align(1);
  r.bold(true);
  r.big(true);
  r.line(r.fit(d.establishment));
  r.big(false);
  r.bold(false);
  r.line('RECU DE VENTE');
  r.sep();
  r.align(0);
  r.line('Date : ${dateFr(d.date)}');
  r.line('Recu No : ${d.saleId}');
  if (d.server.isNotEmpty) r.line('Serveur : ${d.server}');
  if (d.credit && d.customer != null) r.line('Client : ${d.customer}');
  r.sep();
  for (final l in d.lines) {
    r.line(r.fit(l.name));
    r.lr('  ${l.qty} x ${_n(l.price)}', _n(l.qty * l.price));
  }
  r.sep();
  r.bold(true);
  r.lr('TOTAL', '${_n(d.total)} FCFA');
  r.bold(false);
  r.line(d.credit ? 'Paiement : CREDIT (a payer)' : 'Paiement : Especes');
  r.sep();
  r.align(1);
  r.line('Merci de votre visite !');
  r.feed(4);
  r.cut();
  return r.bytes;
}
