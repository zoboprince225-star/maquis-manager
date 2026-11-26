import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../format.dart';
import '../providers.dart';
import '../services/audit_service.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});
  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  static const _periods = ['Aujourd’hui', '7 jours', '30 jours', 'Tout'];
  String _period = '7 jours';
  int _userSel = 0;
  String? _entity;
  List<AuditView>? _list;
  List<User> _users = [];

  bool get _owner => ref.read(sessionProvider)?.role == 'owner';
  int get _eid => ref.read(sessionProvider)!.establishmentId;

  DateTime? _from() {
    final n = DateTime.now();
    switch (_period) {
      case 'Aujourd’hui':
        return DateTime(n.year, n.month, n.day);
      case '7 jours':
        return DateTime(n.year, n.month, n.day - 6);
      case '30 jours':
        return DateTime(n.year, n.month, n.day - 29);
      default:
        return null;
    }
  }

  Future<void> _reload() async {
    if (!_owner) return;
    final users = await ref.read(authServiceProvider).users(_eid);
    final list = await ref.read(auditServiceProvider).query(
          _eid,
          from: _from(),
          userId: _userSel == 0 ? null : _userSel,
          entity: _entity,
        );
    if (!mounted) return;
    setState(() {
      _users = users;
      _list = list;
    });
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  (IconData, Color) _look(String action) {
    switch (action) {
      case 'Création':
        return (Icons.add_circle, Colors.green);
      case 'Modification':
        return (Icons.edit, Colors.orange);
      case 'Suppression':
        return (Icons.delete, Colors.redAccent);
      case 'Perte':
        return (Icons.warning_amber_rounded, Colors.redAccent);
      case 'Approvisionnement':
        return (Icons.local_shipping, Colors.green);
      case 'Inventaire':
        return (Icons.fact_check, Colors.orange);
      case 'Paiement':
        return (Icons.payments, Colors.green);
      case 'Ouverture':
        return (Icons.play_circle, Colors.green);
      case 'Clôture':
        return (Icons.stop_circle, Colors.orange);
      case 'Connexion':
        return (Icons.login, Colors.lightBlue);
      case 'Déconnexion':
        return (Icons.logout, Colors.blueGrey);
      case 'Sauvegarde':
      case 'Restauration':
        return (Icons.backup, Colors.purpleAccent);
      default:
        return (Icons.history, Colors.white70);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_owner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journal d’audit')),
        body: const Center(child: Text('Réservé au propriétaire.')),
      );
    }
    final list = _list;
    return Scaffold(
      appBar: AppBar(title: const Text('Journal d’audit')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              for (final p in _periods)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: _period == p,
                    onSelected: (_) {
                      setState(() => _period = p);
                      _reload();
                    },
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _userSel,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Utilisateur'),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('Tous')),
                    for (final u in _users)
                      DropdownMenuItem(value: u.id, child: Text(u.name)),
                  ],
                  onChanged: (v) {
                    setState(() => _userSel = v ?? 0);
                    _reload();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _entity,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Tous')),
                    for (final e in auditEntities)
                      DropdownMenuItem<String?>(value: e, child: Text(e)),
                  ],
                  onChanged: (v) {
                    setState(() => _entity = v);
                    _reload();
                  },
                ),
              ),
            ]),
          ),
          Expanded(
            child: list == null
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? const Center(
                        child: Text('Aucune action enregistrée sur cette période.'))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final v = list[i];
                          final look = _look(v.entry.action);
                          return ListTile(
                            leading: Icon(look.$1, color: look.$2),
                            title: Text(v.entry.detail),
                            subtitle: Text(
                                '${dateFr(v.entry.createdAt)} · ${v.userName} · ${v.entry.entity}'),
                          );
                        },
                      ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Les 500 actions les plus récentes sont affichées.',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}
