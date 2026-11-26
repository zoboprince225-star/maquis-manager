import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../format.dart';
import '../providers.dart';
import '../services/backup_service.dart';
import '../services/export_writer.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  String? _last;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  Future<void> _loadLast() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString('last_backup');
    if (mounted) {
      setState(() => _last = v == null ? null : dateFr(DateTime.parse(v)));
    }
  }

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  Future<void> _backup() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await BackupService(ref.read(dbProvider)).export();
      await shareBytes(bytes, 'sauvegarde_maquis_${_stamp()}.maquis',
          'application/octet-stream', 'Sauvegarde Maquis Manager');
      final p = await SharedPreferences.getInstance();
      await p.setString('last_backup', DateTime.now().toIso8601String());
      await _loadLast();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplacer toutes les données ?'),
        content: const Text(
            'Toutes les données actuelles de ce téléphone seront effacées et remplacées par celles de la sauvegarde. Cette action est définitive.\n\nAs-tu fait une sauvegarde récente de l’état actuel ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final err = await BackupService(ref.read(dbProvider)).restore(path);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sauvegarde restaurée'),
        content: const Text(
            'Reconnecte-toi avec les identifiants de la sauvegarde.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
    if (!mounted) return;
    final session = ref.read(sessionProvider.notifier);
    ref.invalidate(hasOwnerProvider);
    Navigator.of(context).popUntil((r) => r.isFirst);
    session.state = null;
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider)?.role != 'owner') {
      return Scaffold(
        appBar: AppBar(title: const Text('Sauvegarde')),
        body: const Center(child: Text('Réservé au propriétaire.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde et restauration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Dernière sauvegarde'),
              subtitle: Text(_last ?? 'Aucune sauvegarde faite sur ce téléphone'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
              'Comme l’application fonctionne sans internet, tes données ne sont que sur ce téléphone. Si tu le perds ou le casses, une sauvegarde te permet de tout retrouver sur un autre.',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _backup,
            icon: const Icon(Icons.backup),
            label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Créer et partager une sauvegarde')),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'Envoie le fichier à toi-même sur WhatsApp ou enregistre-le sur Drive.',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Restaurer depuis un fichier')),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'Choisis le fichier .maquis (téléchargé depuis WhatsApp, Drive ou Fichiers). Les données actuelles seront remplacées.',
                style: TextStyle(fontSize: 12, color: Colors.white54)),
          ),
          if (_busy)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 16),
          const Text(
              'Le fichier contient tes comptes utilisateurs (mots de passe chiffrés) : garde-le privé.',
              style: TextStyle(fontSize: 12, color: Colors.amber)),
        ],
      ),
    );
  }
}
