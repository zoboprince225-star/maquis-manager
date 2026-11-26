import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

Future<bool?> showExpenseForm(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ExpenseForm(),
  );
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm();
  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  bool _fromCash = true;
  String? _error;

  Future<void> _save() async {
    final u = ref.read(sessionProvider)!;
    final err = await ref.read(salesServiceProvider).addExpense(
          eid: u.establishmentId,
          userId: u.id,
          label: _label.text,
          amount: int.tryParse(_amount.text) ?? 0,
          fromCash: _fromCash,
        );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    ref.read(dataTickProvider.notifier).state++;
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Dépense enregistrée')));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enregistrer une dépense',
                style: Theme.of(context).textTheme.titleLarge),
            TextField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Libellé (glace, électricité, salaire…)')),
            TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    const InputDecoration(labelText: 'Montant (FCFA)')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Payée avec l’argent de la caisse'),
              value: _fromCash,
              onChanged: (v) => setState(() => _fromCash = v),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _save,
                child: const Padding(
                    padding: EdgeInsets.all(12), child: Text('Enregistrer'))),
          ],
        ),
      ),
    );
  }
}
