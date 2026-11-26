import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../format.dart';
import '../providers.dart';
import '../services/analytics_service.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});
  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  static const _keys = [
    'Cette semaine',
    'Ce mois',
    'Mois dernier',
    'Cette année',
    '30 jours',
    'Personnalisé',
  ];
  String _key = 'Ce mois';
  DateTimeRange? _custom;
  bool _byMargin = true;
  List<DrinkStat>? _stats;
  List<DormantRow> _dormant = [];
  StockBalance? _bal;

  bool get _owner => ref.read(sessionProvider)?.role == 'owner';
  int get _eid => ref.read(sessionProvider)!.establishmentId;

  (DateTime, DateTime) _range() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final tomorrow = DateTime(n.year, n.month, n.day + 1);
    switch (_key) {
      case 'Cette semaine':
        return (DateTime(n.year, n.month, n.day - (n.weekday - 1)), tomorrow);
      case 'Mois dernier':
        return (DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 1));
      case 'Cette année':
        return (DateTime(n.year, 1, 1), tomorrow);
      case '30 jours':
        return (DateTime(n.year, n.month, n.day - 29), tomorrow);
      case 'Personnalisé':
        final c = _custom;
        if (c == null) return (today, tomorrow);
        return (
          DateTime(c.start.year, c.start.month, c.start.day),
          DateTime(c.end.year, c.end.month, c.end.day + 1)
        );
      default:
        return (DateTime(n.year, n.month, 1), tomorrow);
    }
  }

  Future<void> _reload() async {
    if (!_owner) return;
    final svc = AnalyticsService(ref.read(dbProvider));
    final (from, to) = _range();
    final s = await svc.drinkStats(_eid, from, to);
    final d = await svc.dormant(_eid, from, to);
    final b = await svc.balance(_eid, from, to);
    if (!mounted) return;
    setState(() {
      _stats = s;
      _dormant = d;
      _bal = b;
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

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    final style = TextStyle(
        color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _profitTab() {
    final s = _stats;
    if (s == null) return const Center(child: CircularProgressIndicator());
    if (s.isEmpty) {
      return const Center(child: Text('Aucune vente sur cette période.'));
    }
    final list = [...s]..sort((a, b) =>
        _byMargin ? b.margin.compareTo(a.margin) : b.qty.compareTo(a.qty));
    final rev = s.fold<int>(0, (a, x) => a + x.revenue);
    final cost = s.fold<int>(0, (a, x) => a + x.cost);
    final margin = rev - cost;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('Chiffre d’affaires', fcfa(rev)),
              _row('Coût d’achat', fcfa(-cost), color: Colors.white70),
              const Divider(),
              _row('Marge brute', fcfa(margin),
                  bold: true,
                  color: margin >= 0 ? Colors.green : Colors.redAccent),
            ]),
          ),
        ),
        Row(children: [
          ChoiceChip(
              label: const Text('Par marge'),
              selected: _byMargin,
              onSelected: (_) => setState(() => _byMargin = true)),
          const SizedBox(width: 8),
          ChoiceChip(
              label: const Text('Par quantité'),
              selected: !_byMargin,
              onSelected: (_) => setState(() => _byMargin = false)),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < list.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor:
                  i < 3 ? const Color(0xFFE8801E) : Colors.white24,
              child: Text('${i + 1}',
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
            ),
            title: Text(list[i].name),
            subtitle: Text(
                '${list[i].qty} sortie(s) · CA ${fcfa(list[i].revenue)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fcfa(list[i].margin),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: list[i].margin >= 0
                            ? Colors.green
                            : Colors.redAccent)),
                Text('${list[i].pct} %',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
              'Les ventes de kits sont réparties entre leurs boissons selon leurs prix de vente.',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
        ),
      ],
    );
  }

  Widget _dormantTab() {
    if (_stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_dormant.isEmpty) {
      return const Center(
          child: Text('Aucun produit dormant : tout ce qui est en stock se vend.'));
    }
    final value = _dormant.fold<int>(0, (a, d) => a + d.value);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.hourglass_empty, color: Colors.orange),
            title: Text('${_dormant.length} produit(s) sans vente'),
            subtitle: const Text('Argent immobilisé (prix d’achat)'),
            trailing: Text(fcfa(value),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange)),
          ),
        ),
        for (final d in _dormant)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(d.drink.name),
            subtitle: Text(d.lastSale == null
                ? 'Jamais vendu'
                : 'Dernière vente : ${dayFr(d.lastSale!)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${d.stock} en stock',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(fcfa(d.value),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _balanceTab() {
    final b = _bal;
    if (b == null) return const Center(child: CircularProgressIndicator());
    if (b.rows.isEmpty) {
      return const Center(child: Text('Aucune boisson dans le catalogue.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _row('Valeur du stock au début', fcfa(b.openingValue)),
              _row('Valeur du stock à la fin', fcfa(b.closingValue),
                  bold: true),
              const Divider(),
              _row('Valeur des pertes', fcfa(b.lossValue),
                  color: b.lossValue > 0 ? Colors.redAccent : null),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text('Boisson')),
              DataColumn(label: Text('Début'), numeric: true),
              DataColumn(label: Text('Entrées'), numeric: true),
              DataColumn(label: Text('Ventes'), numeric: true),
              DataColumn(label: Text('Pertes'), numeric: true),
              DataColumn(label: Text('Ajust.'), numeric: true),
              DataColumn(label: Text('Fin'), numeric: true),
            ],
            rows: [
              for (final r in b.rows)
                DataRow(cells: [
                  DataCell(Text(r.drink.name)),
                  DataCell(Text('${r.opening}')),
                  DataCell(Text('${r.supplies}')),
                  DataCell(Text('${r.sold}')),
                  DataCell(Text('${r.lost}',
                      style: TextStyle(
                          color: r.lost > 0 ? Colors.redAccent : null))),
                  DataCell(Text('${r.adjust}')),
                  DataCell(Text('${r.closing}',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
              'Valeurs calculées avec le prix d’achat actuel de chaque boisson.',
              style: TextStyle(fontSize: 12, color: Colors.white54)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_owner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bénéfices et bilans')),
        body: const Center(child: Text('Réservé au propriétaire.')),
      );
    }
    final (from, to) = _range();
    final last = DateTime(to.year, to.month, to.day - 1);
    final label =
        from == last ? dayFr(from) : 'du ${dayFr(from)} au ${dayFr(last)}';
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bénéfices et bilans'),
          actions: [
            IconButton(
                tooltip: 'Choisir des dates',
                icon: const Icon(Icons.calendar_month),
                onPressed: _pickRange),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Bénéfices'),
            Tab(text: 'Dormants'),
            Tab(text: 'Bilan stock'),
          ]),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
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
            Expanded(
              child: TabBarView(children: [
                _profitTab(),
                _dormantTab(),
                _balanceTab(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
