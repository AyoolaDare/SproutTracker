import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sproutStoreProvider);

    return SproutPage(
      title: 'Inventory',
      subtitle: 'Stock levels, reorder signals, SKU health, and movement history.',
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _AddProductDialog(),
        ),
        icon: const Icon(Icons.inventory_2_rounded),
        label: const Text('Add product'),
      ),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.inventory.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 330,
            mainAxisExtent: 218,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
          ),
          itemBuilder: (context, index) => _InventoryTile(state.inventory[index]),
        ),
        const SizedBox(height: 18),
        SproutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory history',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final entry in state.inventoryHistory.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${entry.type}: ${entry.itemName}'),
                  subtitle: Text('${shortDate(entry.date)} • ${entry.details}'),
                  trailing: Text(
                    entry.change > 0 ? '+${entry.change}' : '${entry.change}',
                    style: TextStyle(
                      color: entry.change < 0 ? AppTheme.terracotta : AppTheme.moss,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InventoryTile extends ConsumerWidget {
  const _InventoryTile(this.item);

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final low = item.isLowStock;
    final color = low ? AppTheme.terracotta : AppTheme.moss;
    final stockHealth = item.reorderLevel == 0 ? 1.0 : (item.quantity / (item.reorderLevel * 2)).clamp(0.0, 1.0);

    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Icon(low ? Icons.warning_amber_rounded : Icons.eco_rounded, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text('${item.sku} • ${item.category}'),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: stockHealth,
              backgroundColor: AppTheme.clay.withValues(alpha: .18),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StockStat(label: 'On hand', value: '${item.quantity}')),
              Expanded(child: _StockStat(label: 'Value', value: compactMoney(item.stockValue))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => _AdjustStockDialog(item: item),
                  ),
                  child: const Text('Adjust'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Delete item',
                onPressed: () => ref.read(sproutStoreProvider.notifier).deleteInventoryItem(item.id),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockStat extends StatelessWidget {
  const _StockStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _AddProductDialog extends ConsumerStatefulWidget {
  const _AddProductDialog();

  @override
  ConsumerState<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<_AddProductDialog> {
  final name = TextEditingController();
  final sku = TextEditingController();
  final category = TextEditingController();
  final supplier = TextEditingController();
  final unitCost = TextEditingController(text: '0');
  final quantity = TextEditingController(text: '0');
  final reorderLevel = TextEditingController(text: '0');

  @override
  void dispose() {
    name.dispose();
    sku.dispose();
    category.dispose();
    supplier.dispose();
    unitCost.dispose();
    quantity.dispose();
    reorderLevel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add product'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name')),
              const SizedBox(height: 10),
              TextField(controller: sku, decoration: const InputDecoration(labelText: 'SKU')),
              const SizedBox(height: 10),
              TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
              const SizedBox(height: 10),
              TextField(controller: supplier, decoration: const InputDecoration(labelText: 'Supplier')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: unitCost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit cost'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity'))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: reorderLevel, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reorder level')),
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
                  unitCost: num.parse(unitCost.text),
                  quantity: int.parse(quantity.text),
                  reorderLevel: int.parse(reorderLevel.text),
                );
            Navigator.pop(context);
          },
          child: const Text('Add product'),
        ),
      ],
    );
  }
}

class _AdjustStockDialog extends ConsumerStatefulWidget {
  const _AdjustStockDialog({required this.item});
  final InventoryItem item;

  @override
  ConsumerState<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<_AdjustStockDialog> {
  final adjustment = TextEditingController();
  final reason = TextEditingController(text: 'Manual stock adjustment');

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
          TextField(
            controller: adjustment,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Adjustment (+ or -)'),
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
            } catch (error) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          },
          child: const Text('Save adjustment'),
        ),
      ],
    );
  }
}
