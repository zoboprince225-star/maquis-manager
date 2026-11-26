import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../format.dart';
import '../providers.dart';
import '../services/export_service.dart';
import '../services/export_writer.dart';
import '../services/report_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});
  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  static const _labels = {
    ExportKind.sales: 'Ventes',
    ExportKind.expenses: 'Dépenses',
    ExportKind.stock: 'État du stock',
    ExportKind.losses: 'Pertes',
    ExportKind.credits: 'Crédits clients',
    ExportKind.profits: 'Bénéfices par boisson',
  };
  static const _periods = [
    'Aujourd’hui',
    'Hier',
    '7 jours',
    'Ce mois',
    'Mois dernier',
    'Personnalisé',
  ];

  ExportKind _kind = ExportKind.sales;
  String _period = 'Ce mois';
  DateTimeRange? _custom;
  String _fmt = 'xlsx';
  bool _busy = false;

  bool get _needsPeriod =>
      _kind != ExportKind.stock && _kind != ExportKind.credits;

  (DateTime, DateTime) _range() {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final tomorrow = DateTime(n.year, n.month, n.day + 1);
    switch (_period) {
      case 'Hier':
        return (DateTime(n.year, n.month, n.day - 1), today);
      case '7 jours':
        return (DateTime(n.year, n.month, n.day - 6), tomorrow);
      case 'Mois dernier':
        return (DateTime(n.year, n.month - 1, 1), DateTime(n.year, n.month, 1));
      case 'Personnalisé':
        final c = _custom;
        if (c == null) return (today, tomorrow);
        return (
          DateTime(c.start.year, c.start.month, c.start.day),
          DateTime(c.end.year, c.end.month, c.end.day + 1)
        );
      case 'Ce mois':
        return (DateTime(n.year, n.month, 1), tomorrow);
      default:
        return (today, tomorrow);
    }
  }

  String _label() {
    final (from, to) = _range();
    final last = DateTime(to.year, to.month, to.day - 1);
    return from == last
        ? 'du ${dayFr(from)}'
        : 'du ${dayFr(from)} au ${dayFr(last)}';
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
        _period = 'Personnalisé';
      });
    }
  }

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}';
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final db = ref.read(dbProvider);
      final eid = ref.read(sessionProvider)!.establishmentId;
      final (from, to) = _range();
      final t = await ExportService(db)
          .build(_kind, eid, from, to, _needsPeriod ? _label() : '');
      if (t.rows.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Aucune donnée à exporter.')));
        return;
      }
      final est = await ReportService(db).establishmentName(eid);
      final base = 'maquis_${t.slug}_${_stamp()}';
      switch (_fmt) {
        case 'csv':
          await shareBytes(toCsv(t), '$base.csv', 'text/csv', t.title);
        case 'pdf':
          await shareBytes(
              await toPdf(t, est), '$base.pdf', 'application/pdf', t.title);
        default:
          await shareBytes(
              toXlsx(t),
              '$base.xlsx',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              t.title);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur d’export : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider)?.role != 'owner') {
      return Scaffold(
        appBar: AppBar(title: const Text('Exports')),
        body: const Center(child: Text('Réservé au propriétaire.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Exports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Que veux-tu exporter ?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final e in _labels.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _kind == e.key,
                onSelected: (_) => setState(() => _kind = e.key),
              ),
          ]),
          if (_needsPeriod) ...[
            const SizedBox(height: 20),
            Text('Période', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final p in _periods)
                ChoiceChip(
                  label: Text(p),
                  selected: _period == p,
                  onSelected: (_) {
                    if (p == 'Personnalisé') {
                      _pickRange();
                    } else {
                      setState(() => _period = p);
                    }
                  },
                ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_label(),
                  style: const TextStyle(color: Colors.white70)),
            ),
          ],
          const SizedBox(height: 20),
          Text('Format', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'xlsx', label: Text('Excel')),
              ButtonSegment(value: 'csv', label: Text('CSV')),
              ButtonSegment(value: 'pdf', label: Text('PDF')),
            ],
            selected: {_fmt},
            onSelectionChanged: (s) => setState(() => _fmt = s.first),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
            label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Exporter et partager')),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
                'Le fichier s’ouvre dans le menu de partage : choisis WhatsApp, Gmail, Drive…',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
