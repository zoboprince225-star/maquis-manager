import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers.dart';
import '../services/establishment_service.dart';

final establishmentsProvider =
    FutureProvider.autoDispose<List<Establishment>>(
        (ref) => EstablishmentService(ref.watch(dbProvider)).list());

Future<int?> _createDialog(BuildContext context, EstablishmentService svc) {
  final c = TextEditingController();
  String? err;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Nouvel établissement'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(labelText: 'Nom (ex. Maquis Cocody)'),
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(err!, style: const TextStyle(color: Colors.redAccent)),
            ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              final r = await svc.create(c.text);
              if (r.$2 != null) {
                setD(() => err = r.$2);
              } else if (ctx.mounted) {
                Navigator.pop(ctx, r.$1);
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    ),
  );
}

/// Réservé au propriétaire : changer d'établissement ou en ajouter un
Future<void> showEstablishmentSwitcher(
    BuildContext context, WidgetRef ref) async {
  final me = ref.read(sessionProvider);
  if (me == null || me.role != 'owner') return;
  final svc = EstablishmentService(ref.read(dbProvider));
  await showDialog<void>(
    context: context,
    builder: (ctx) => FutureBuilder<List<Establishment>>(
      future: svc.list(),
      builder: (ctx, snap) {
        final list = snap.data ?? const <Establishment>[];
        return AlertDialog(
          title: const Text('Établissements'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in list)
                  ListTile(
                    leading: Icon(e.id == me.establishmentId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off),
                    title: Text(e.name),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (e.id != me.establishmentId) {
                        ref.read(sessionProvider.notifier).state =
                            me.copyWith(establishmentId: e.id);
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.add_business),
              label: const Text('Ajouter'),
              onPressed: () async {
                final id = await _createDialog(ctx, svc);
                if (id == null) return;
                ref.invalidate(establishmentsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                ref.read(sessionProvider.notifier).state =
                    me.copyWith(establishmentId: id);
              },
            ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer')),
          ],
        );
      },
    ),
  );
}
