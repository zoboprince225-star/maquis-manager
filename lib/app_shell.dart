import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_drawer.dart';
import 'providers.dart';
import 'screens/caisse_page.dart';
import 'screens/drink_form.dart';
import 'screens/expense_form.dart';
import 'screens/inventory_screen.dart';
import 'screens/sale_screen.dart';
import 'screens/sales_page.dart';
import 'screens/stock_screen.dart';
import 'screens/supply_screen.dart';
import 'services/stock_service.dart';
import 'widgets/day_card.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  static const _titles = ['Accueil', 'Caisse', 'Ventes', 'Journal', 'Guide'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      drawer: const AppDrawer(),
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          CaissePage(),
          SalesPage(),
          _Soon('Journal'),
          _Soon('Guide'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.attach_money), label: 'Caisse'),
          NavigationDestination(
              icon: Icon(Icons.add_circle_outline), label: 'Ventes'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), label: 'Journal'),
          NavigationDestination(
              icon: Icon(Icons.help_outline), label: 'Guide'),
        ],
      ),
    );
  }
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<StockRow> _rows = [];

  int get _eid => ref.read(sessionProvider)!.establishmentId;

  Future<void> _reload() async {
    final r = await ref.read(stockServiceProvider).rows(_eid);
    if (mounted) setState(() => _rows = r);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dataTickProvider, (_, __) => _reload());
    final actions = <(String, IconData, Color, VoidCallback)>[
      ('Créer boisson', Icons.local_bar, const Color(0xFF6A1B9A), () async {
        await showDrinkForm(context);
        if (mounted) _reload();
      }),
      ('Nouvelle vente', Icons.add, const Color(0xFF4CAF50),
          () => _open(const SaleScreen())),
      ('État des stocks', Icons.inventory_2, const Color(0xFF26A69A),
          () => _open(const StockScreen())),
      ('Approvision-nement', Icons.local_shipping, const Color(0xFF8D6E63),
          () => _open(const SupplyScreen())),
      ('Inventaire', Icons.archive, const Color(0xFF78909C),
          () => _open(const InventoryScreen())),
      ('Dépense', Icons.payments, const Color(0xFF00ACC1),
          () => showExpenseForm(context)),
    ];
    final alerts = _rows.where((r) => r.empty || r.low).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DayCard(),
        const SizedBox(height: 16),
        Text('Actions rapides',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final a in actions) _Tile(a.$1, a.$2, a.$3, a.$4),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _open(const StockScreen()),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                        alerts.isEmpty
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: alerts.isEmpty ? Colors.green : Colors.orange),
                    const SizedBox(width: 8),
                    Text('Alertes de stock',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 8),
                  if (alerts.isEmpty)
                    const Text('Aucune alerte, le stock est en ordre.'),
                  for (final r in alerts.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(r.drink.name)),
                          Text('${r.stock} · ${r.label}',
                              style: TextStyle(
                                  color: r.empty
                                      ? Colors.redAccent
                                      : Colors.orange)),
                        ],
                      ),
                    ),
                  if (alerts.length > 6)
                    Text('+ ${alerts.length - 6} autres',
                        style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Tile(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Soon extends StatelessWidget {
  final String name;
  const _Soon(this.name);

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('$name : bientôt disponible'));
}
