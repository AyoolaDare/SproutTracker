import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state  = ref.watch(sproutStoreProvider);
    final scheme = Theme.of(context).colorScheme;

    return SproutPage(
      title: 'Inventory',
      subtitle: 'Stock levels, reorder signals, SKU health, and movement history.',
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _AddProductDialog(),
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add product'),
      ),
      children: [
        if (state.inventory.isEmpty)
          SproutCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      size: 40,
                      color: scheme.onSurfaceVariant.withValues(alpha: .35),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No products yet. Add your first product to begin tracking stock.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.inventory.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisExtent: 234,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, i) => _InventoryTile(state.inventory[i]),
          ),

        const SizedBox(height: 20),

        // ── Inventory history ──────────────────────────────────────────────
        SproutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Movement history'),
              const SizedBox(height: 14),
              if (state.inventoryHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No stock movements recorded yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              else
                for (var i = 0; i < state.inventoryHistory.take(10).length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .4)),
                  _HistoryRow(state.inventoryHistory.elementAt(i)),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── History row ────────────────────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  const _HistoryRow(this.entry);
  final InventoryHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdd  = entry.change > 0;
    final color  = isAdd ? AppTheme.moss : AppTheme.terracotta;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAdd ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.itemName,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${entry.type} · ${shortDate(entry.date)} · ${entry.details}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            entry.change > 0 ? '+${entry.change}' : '${entry.change}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Inventory tile (grid card) ────────────────────────────────────────────────

class _InventoryTile extends ConsumerWidget {
  const _InventoryTile(this.item);
  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final low         = item.isLowStock;
    final tileColor   = low ? AppTheme.terracotta : AppTheme.moss;
    final stockHealth = item.reorderLevel == 0
        ? 1.0
        : (item.quantity / (item.reorderLevel * 2)).clamp(0.0, 1.0);
    final scheme      = Theme.of(context).colorScheme;

    return SproutCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tileColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  low ? Icons.warning_amber_rounded : Icons.eco_rounded,
                  color: tileColor,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.sku} · ${item.category}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),

          // Stock health bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Stock level', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                  Text('${(stockHealth * 100).round()}%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tileColor, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: stockHealth,
                  backgroundColor: AppTheme.clay.withValues(alpha: .2),
                  valueColor: AlwaysStoppedAnimation(tileColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              Expanded(child: _Stat(label: 'On hand', value: '${item.quantity} units')),
              Expanded(child: _Stat(label: 'Value', value: compactMoney(item.stockValue))),
            ],
          ),
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _AdjustStockDialog(item: item),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Adjust stock'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove product',
                onPressed: () => ref.read(sproutStoreProvider.notifier).deleteInventoryItem(item.id),
                icon: const Icon(Icons.delete_outline_rounded),
                iconSize: 20,
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.terracotta,
                  backgroundColor: AppTheme.terracotta.withValues(alpha: .08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

// ── Add product dialog ─────────────────────────────────────────────────────────

class _AddProductDialog extends ConsumerStatefulWidget {
  const _AddProductDialog();

  @override
  ConsumerState<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<_AddProductDialog> {
  final name         = TextEditingController();
  final sku          = TextEditingController();
  final category     = TextEditingController();
  final supplier     = TextEditingController();
  final unitCost     = TextEditingController(text: '0');
  final quantity     = TextEditingController(text: '0');
  final reorderLevel = TextEditingController(text: '0');

  @override
  void dispose() {
    name.dispose(); sku.dispose(); category.dispose(); supplier.dispose();
    unitCost.dispose(); quantity.dispose(); reorderLevel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add product'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name,     decoration: const InputDecoration(labelText: 'Product name')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: sku,      decoration: const InputDecoration(labelText: 'SKU'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: category, decoration: const InputDecoration(labelText: 'Category'))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: supplier, decoration: const InputDecoration(labelText: 'Supplier')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: unitCost,     keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit cost (₦)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: quantity,     keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening qty'))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: reorderLevel, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reorder level')),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Alerts trigger when quantity falls to or below this level.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            ref.read(sproutStoreProvider.notifier).addProduct(
                  name: name.text,
                  sku: sku.text,
                  category: category.text,
                  supplier: supplier.text,
                  unitCost: num.tryParse(unitCost.text) ?? 0,
                  quantity: int.tryParse(quantity.text) ?? 0,
                  reorderLevel: int.tryParse(reorderLevel.text) ?? 0,
                );
            Navigator.pop(context);
          },
          child: const Text('Add product'),
        ),
      ],
    );
  }
}

// ── Adjust stock dialog ────────────────────────────────────────────────────────

class _AdjustStockDialog extends ConsumerStatefulWidget {
  const _AdjustStockDialog({required this.item});
  final InventoryItem item;

  @override
  ConsumerState<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<_AdjustStockDialog> {
  final adjustment = TextEditingController();
  final reason     = TextEditingController(text: 'Manual stock adjustment');

  @override
  void dispose() {
    adjustment.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust ${widget.item.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Current stock', style: Theme.of(context).textTheme.bodyMedium)),
                Text('${widget.item.quantity} units', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: adjustment,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Adjustment (+10 to add · -5 to deduct)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            try {
              ref.read(sproutStoreProvider.notifier).adjustInventory(
                    itemId: widget.item.id,
                    adjustment: int.parse(adjustment.text),
                    reason: reason.text,
                  );
              Navigator.pop(context);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          },
          child: const Text('Save adjustment'),
        ),
      ],
    );
  }
}
