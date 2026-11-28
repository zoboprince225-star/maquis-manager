import 'receipt_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../format.dart';
import '../providers.dart';
import '../services/printer_service.dart';
import '../services/report_printer.dart';
import '../services/report_service.dart';
import '../widgets/bars.dart';

class JournalPage extends ConsumerStatefulWidget {
  const JournalPage({super.key});
  @override
  ConsumerState<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends ConsumerState<JournalPage> {
  static const _keys = [
    'Aujourd’hui',
    'Hier',
    '7 jours',
    'Ce mois',
    'Personnalisé'
  ];
  String _key = _keys[0];
  DateTimeRange? _custom;
  int _userSel = 0; // 0 = tous
  List<User> _users = [];
  Report? _r;
  List<ClosedDay> _closed = [];

  User get _me => ref.read(sessionProvider)!;
  bool get _owner => _me.role == 'owner';
  int get _eid => _me.establishmentId;

  (DateTime, DateTime) _range() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final tomorrow = DateTime(n.year, n.month, n.day + 1);
    switch (_key) {
      case 'Hier':
        return (DateTime(n.year, n.month, n.day - 1), today);
      case '7 jours':
        return (DateTime(n.year, n.month, n.day - 6), tomorrow);
      case 'Ce mois':
        return (DateTime(n.year, n.month, 1), tomorrow);
      case 'Personnalisé':
        final c = _custom;
        if (c == null) return (today, tomorrow);
        return (
          DateTime(c.start.year, c.start.month, c.start.day),
          DateTime(c.end.year, c.end.month, c.end.day + 1)
        );
      default:
        return (today, tomorrow);
    }
  }

  Future<void> _reload() async {
    final svc = ReportService(ref.read(dbProvider));
    final (from, to) = _range();
    final uid = _owner ? (_userSel == 0 ? null : _userSel) : _me.id;
    final r = await svc.build(_eid, from, to, userId: uid);
    final closed = _owner ? await svc.closedDays(_eid, from, to) : <ClosedDay>[];
    final users =
        _owner ? await ref.read(authServiceProvider).users(_eid) : <User>[];
    if (!mounted) return;
    setState(() {
      _r = r;
      _closed = closed;
      _users = users;
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _pickRange() async {
    final n = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(n.year + 1, 12, 31),
      initialDateRange: _custom,
    );
    if (r != null) {
      setState(() {
        _custom = r;
        _key = 'Personnalisé';
      });
      _reload();
    }
  }

  

  Widget _row(String label, String value,
      {Color? color, bool bold = false, double indent = 0}) {
    final style = TextStyle(
        color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: EdgeInsets.fromLTRB(indent, 5, 0, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _summary(Report r) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('Ventes', fcfa(r.sales), color: Colors.green, bold: true),
              _row('Espèces', fcfa(r.salesCash), indent: 16),
              _row('À crédit', fcfa(r.salesCredit),
                  color: Colors.orange, indent: 16),
              _row('Nombre de ventes', '${r.saleCount}'),
              _row('Boissons sorties', '${r.qtyOut}'),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('Crédits encaissés', fcfa(r.payments),
                  color: Colors.green),
              _row('Dépenses de caisse', fcfa(-r.expCash),
                  color: Colors.redAccent),
              _row('Dépenses hors caisse', fcfa(-r.expOff),
                  color: Colors.white70),
              const Divider(),
              _row('Solde caisse', fcfa(r.cashBalance), bold: true),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('Marge brute (ventes − achats)', fcfa(r.gross),
                  color: r.gross >= 0 ? Colors.green : Colors.redAccent),
              _row('Bénéfice net (après dépenses)', fcfa(r.net),
                  bold: true,
                  color: r.net >= 0 ? Colors.green : Colors.redAccent),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _charts(Report r) {
    if (r.sales == 0) {
      return const Center(child: Text('Aucune vente sur cette période.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ventes par jour',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SimpleBars(
                  labels: [for (final d in r.byDay) dayShort(d.$1)],
                  values: [for (final d in r.byDay) d.$2],
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ventes par heure',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SimpleBars(
                  labels: [for (var h = 0; h < 24; h++) '${h}h'],
                  values: r.byHour,
                  color: const Color(0xFF26A69A),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ventes par serveur',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                HBars(items: r.byServer),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _closedList() {
    if (_closed.isEmpty) {
      return const Center(
          child: Text('Aucune journée clôturée sur cette période.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final c in _closed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Text(
                        'Journée du ${dayFr(c.day.openedAt)}',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Imprimer le rapport',
                    icon: const Icon(Icons.print),
                    onPressed: () => _print(c),
                  ),
                ]),
                _row('Ouverte à', hourFr(c.day.openedAt)),
                _row('Clôturée à',
                    c.day.closedAt == null ? '' : hourFr(c.day.closedAt!)),
                const Divider(),
                _row('Ventes', fcfa(c.summary.totalSales),
                    color: Colors.green),
                _row('Attendu en caisse', fcfa(c.summary.expected)),
                _row('Compté', fcfa(c.summary.counted ?? 0)),
                _row(
                  'Écart',
                  (c.summary.diff ?? 0) == 0
                      ? 'Caisse juste'
                      : fcfa(c.summary.diff!),
                  bold: true,
                  color: (c.summary.diff ?? 0) == 0
                      ? Colors.green
                      : ((c.summary.diff ?? 0) < 0
                          ? Colors.redAccent
                          : Colors.orange),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dataTickProvider, (_, __) => _reload());
    final (from, to) = _range();
    final last = DateTime(to.year, to.month, to.day - 1);
    final label = from == last
        ? dayFr(from)
        : 'du ${dayFr(from)} au ${dayFr(last)}';
    final r = _r;
    return DefaultTabController(
      length: _owner ? 3 : 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(children: [
              Expanded(
                child: _owner
                    ? DropdownButtonFormField<int>(
                        value: _userSel,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Filtrer'),
                        items: [
                          const DropdownMenuItem(
                              value: 0, child: Text('Tous les utilisateurs')),
                          for (final u in _users)
                            DropdownMenuItem(value: u.id, child: Text(u.name)),
                        ],
                        onChanged: (v) {
                          setState(() => _userSel = v ?? 0);
                          _reload();
                        },
                      )
                    : Text('Mes ventes : ${_me.name}',
                        style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                  tooltip: 'Choisir des dates',
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _pickRange),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              for (final k in _keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(k),
                    selected: _key == k,
                    onSelected: (_) {
                      if (k == 'Personnalisé') {
                        _pickRange();
                      } else {
                        setState(() => _key = k);
                        _reload();
                      }
                    },
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          TabBar(tabs: [
            const Tab(text: 'Résumé'),
            const Tab(text: 'Graphiques'),
            if (_owner) const Tab(text: 'Clôtures'),
          ]),
          Expanded(
            child: r == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _summary(r),
                    _charts(r),
                    if (_owner) _closedList(),
                  ]),
          ),
        ],
      ),
    );
  }
}
