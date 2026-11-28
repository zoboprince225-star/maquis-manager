import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers.dart';
import '../services/sales_admin_service.dart';

/// Sans `expense` : nouvelle dépense. Avec `expense` : modification (propriétaire).
Future<bool?> showExpenseForm(BuildContext context, {Expense? expense}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExpenseForm(expense: expense),
  );
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({this.expense});
  final Expense? expense;
  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  late final _label = TextEditingController(text: widget.expense?.label ?? '');
  late final _amount = TextEditingController(
      text: widget.expense == null ? '' : '${widget.expense!.amount}');
  late bool _fromCash = widget.expense?.fromCash ?? true;
  String? _error;

  bool get _editing => widget.expense != null;

  Future<void> _save() async {
    final u = ref.read(sessionProvider)!;
    final amount = int.tryParse(_amount.text) ?? 0;
    final String? err;
    if (_editing) {
      err = await SalesAdminService(ref.read(dbProvider)).editExpense(
        id: widget.expense!.id,
        userId: u.id,
        label: _label.text,
        amount: amount,
        fromCash: _fromCash,
      );
    } else {
      err = await ref.read(salesServiceProvider).addExpense(
            eid: u.establishmentId,
            userId: u.id,
            label: _label.text,
            amount: amount,
            fromCash: _fromCash,
          );
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    ref.read(dataTickProvider.notifier).state++;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_editing ? 'Dépense modifiée' : 'Dépense enregistrée')));
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
            Text(_editing ? 'Modifier la dépense' : 'Enregistrer une dépense',
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
