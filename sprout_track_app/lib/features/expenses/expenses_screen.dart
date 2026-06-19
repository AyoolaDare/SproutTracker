import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(sproutStoreProvider).expenses;

    return SproutPage(
      title: 'Expenses',
      subtitle: 'Track spend, categorize deductions, and keep receipt status visible.',
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _AddExpenseDialog(),
        ),
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Add expense'),
      ),
      children: [
        SproutCard(
          child: Column(
            children: [
              if (expenses.isEmpty) const Text('No expenses recorded yet.'),
              for (final expense in expenses)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.clay.withValues(alpha: .22),
                    child: const Icon(Icons.receipt_long_rounded),
                  ),
                  title: Text(expense.description),
                  subtitle: Text('${expense.category} • ${shortDate(expense.date)}'),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(money(expense.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                      IconButton(
                        tooltip: 'Delete expense',
                        onPressed: () => ref.read(sproutStoreProvider.notifier).deleteExpense(expense.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddExpenseDialog extends ConsumerStatefulWidget {
  const _AddExpenseDialog();

  @override
  ConsumerState<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<_AddExpenseDialog> {
  final description = TextEditingController();
  final category = TextEditingController();
  final amount = TextEditingController(text: '0');

  @override
  void dispose() {
    description.dispose();
    category.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record expense'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 10),
            TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
            const SizedBox(height: 10),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            ref.read(sproutStoreProvider.notifier).addExpense(
                  description: description.text,
                  category: category.text,
                  amount: num.parse(amount.text),
                );
            Navigator.pop(context);
          },
          child: const Text('Record expense'),
        ),
      ],
    );
  }
}
