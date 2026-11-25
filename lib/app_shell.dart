import 'package:flutter/material.dart';

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
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          _Soon('Caisse'),
          _Soon('Ventes'),
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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _actions = [
    ('Créer boisson', Icons.local_bar, Color(0xFF6A1B9A)),
    ('Nouvelle vente', Icons.add, Color(0xFF4CAF50)),
    ('État des stocks', Icons.inventory_2, Color(0xFF26A69A)),
    ('Approvision-nement', Icons.local_shipping, Color(0xFF8D6E63)),
    ('Inventaire', Icons.archive, Color(0xFF78909C)),
    ('Dépense', Icons.payments, Color(0xFF00ACC1)),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
            for (final a in _actions) _Tile(a.$1, a.$2, a.$3),
          ],
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Tile(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bientôt disponible'))),
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
