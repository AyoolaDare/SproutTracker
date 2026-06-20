import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/api/features/expenses_provider.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final scheme        = Theme.of(context).colorScheme;

    return SproutPage(
      title: 'Expenses',
      subtitle: 'Track spend, categorise deductions, and keep receipt status visible.',
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _AddExpenseDialog(),
        ),
        icon: const Icon(Icons.add_card_rounded, size: 18),
        label: const Text('Add expense'),
      ),
      children: [
        expensesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Could not load expenses.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
          data: (expenses) {
            final total = expenses.fold<double>(0, (s, e) => s + e.amount);
            return Column(
              children: [
                if (expenses.isNotEmpty) ...[
                  SproutCard(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.terracotta.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppTheme.terracotta,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total spend', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                              Text(
                                money(total),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.terracotta,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${expenses.length} record${expenses.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                SproutCard(
                  padding: EdgeInsets.zero,
                  child: expenses.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 40,
                                  color: scheme.onSurfaceVariant.withValues(alpha: .35),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No expenses recorded yet.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withValues(alpha: .4),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 42 + 14),
                                  Expanded(
                                    child: Text(
                                      'Description / Category',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    'Amount',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            for (var i = 0; i < expenses.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  indent: 18,
                                  endIndent: 18,
                                  color: scheme.outlineVariant.withValues(alpha: .45),
                                ),
                              _ExpenseRow(
                                expense: expenses[i],
                                onDelete: () => ref.read(expensesProvider.notifier).delete(expenses[i].id),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Expense row ────────────────────────────────────────────────────────────────

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.onDelete});
  final ApiExpense   expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (iconData, iconColor) = _categoryMeta(expense.category);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),

          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        expense.category,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: iconColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shortDate(expense.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Amount + delete
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                money(expense.amount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                iconSize: 18,
                style: IconButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static (IconData, Color) _categoryMeta(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('rent') || lower.contains('lease')) {
      return (Icons.home_work_rounded, AppTheme.clay);
    }
    if (lower.contains('fuel') || lower.contains('transport') || lower.contains('vehicle')) {
      return (Icons.local_gas_station_rounded, AppTheme.ochre);
    }
    if (lower.contains('utilities') || lower.contains('electric') || lower.contains('power')) {
      return (Icons.bolt_rounded, AppTheme.ochre);
    }
    if (lower.contains('salary') || lower.contains('wage') || lower.contains('staff')) {
      return (Icons.people_rounded, AppTheme.sage);
    }
    if (lower.contains('supply') || lower.contains('material') || lower.contains('stock')) {
      return (Icons.inventory_2_rounded, AppTheme.moss);
    }
    if (lower.contains('market') || lower.contains('advertis')) {
      return (Icons.campaign_rounded, AppTheme.terracotta);
    }
    return (Icons.account_balance_wallet_rounded, AppTheme.terracotta);
  }
}

// ── Add expense dialog ─────────────────────────────────────────────────────────

class _AddExpenseDialog extends ConsumerStatefulWidget {
  const _AddExpenseDialog();

  @override
  ConsumerState<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<_AddExpenseDialog> {
  final description = TextEditingController();
  final category    = TextEditingController();
  final amount      = TextEditingController(text: '0');

  static const _suggestions = [
    'Rent', 'Fuel', 'Utilities', 'Staff salaries',
    'Supplies', 'Marketing', 'Maintenance',
  ];

  @override
  void dispose() {
    description.dispose(); category.dispose(); amount.dispose();
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
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: category,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 8),
            // Quick-pick categories
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => setState(() => category.text = s),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (₦)',
                prefixIcon: Icon(Icons.currency_exchange_rounded),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await ref.read(expensesProvider.notifier).add(
                  description: description.text,
                  category:    category.text,
                  amount:      double.tryParse(amount.text) ?? 0,
                );
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Record expense'),
        ),
      ],
    );
  }
}
