import '../format.dart';
import 'receipt_builder.dart';
import 'report_service.dart';

List<int> buildDayReport(String establishment, ClosedDay c, int width) {
  final s = c.summary;
  final r = ReceiptBuilder(width)..init();
  r.align(1);
  r.bold(true);
  r.line(r.fit(establishment));
  r.bold(false);
  r.line('RAPPORT DE CLOTURE');
  r.sep();
  r.align(0);
  r.line('Ouverture : ${dateFr(c.day.openedAt)}');
  if (c.day.closedAt != null) {
    r.line('Cloture : ${dateFr(c.day.closedAt!)}');
  }
  r.sep();
  r.lr('Fond de caisse', fcfa(s.opening));
  r.lr('Ventes especes', fcfa(s.cashSales));
  r.lr('Credits encaisses', fcfa(s.payments));
  r.lr('Depenses caisse', fcfa(-s.cashExpenses));
  r.sep();
  r.bold(true);
  r.lr('Attendu en caisse', fcfa(s.expected));
  r.bold(false);
  r.lr('Compte', fcfa(s.counted ?? 0));
  final d = s.diff ?? 0;
  r.bold(true);
  r.lr('Ecart', d == 0 ? 'Caisse juste' : fcfa(d));
  r.bold(false);
  r.sep();
  r.lr('Ventes a credit', fcfa(s.creditSales));
  r.lr('Depenses hors caisse', fcfa(s.offExpenses));
  r.lr('Total des ventes', fcfa(s.totalSales));
  r.feed(4);
  r.cut();
  return r.bytes;
}
