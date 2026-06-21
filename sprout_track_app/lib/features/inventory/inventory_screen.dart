import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/api/features/products_provider.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync  = ref.watch(productsProvider);
    final movementsAsync = ref.watch(stockMovementsProvider);
    final scheme         = Theme.of(context).colorScheme;

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
        productsAsync.when(
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
                'Could not load products.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
          data: (products) => products.isEmpty
              ? SproutCard(
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
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 234,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, i) => _InventoryTile(products[i]),
                ),
        ),

        const SizedBox(height: 20),

        SproutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Movement history'),
              const SizedBox(height: 14),
              movementsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Could not load movement history.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
                data: (movements) => movements.isEmpty
                    ? Padding(
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
                    : Column(
                        children: [
                          for (var i = 0; i < movements.take(10).length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                color: scheme.outlineVariant.withValues(alpha: .4),
                              ),
                            _MovementRow(movements[i]),
                          ],
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

// ── Movement row ───────────────────────────────────────────────────────────────

class _MovementRow extends StatelessWidget {
  const _MovementRow(this.movement);
  final ApiStockMovement movement;

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final isIncome  = movement.isIncoming;
    final color     = isIncome ? AppTheme.moss : AppTheme.terracotta;
    final typeLabel = switch (movement.movementType) {
      'RECEIVE' => 'Received',
      'SALE'    => 'Sale',
      'ADJUST'  => 'Adjustment',
      _         => movement.movementType,
    };
    final detail = movement.notes ?? movement.referenceType ?? typeLabel;

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
              isIncome
                  ? Icons.add_circle_outline_rounded
                  : Icons.remove_circle_outline_rounded,
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
                  movement.productName,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$typeLabel · ${shortDate(movement.createdAt)} · $detail',
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
            isIncome ? '+${movement.quantity}' : '${movement.quantity}',
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
  final ApiProduct item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final low         = item.isLowStock;
    final tileColor   = low ? AppTheme.terracotta : AppTheme.moss;
    final stockHealth = item.reorderLevel == 0
        ? 1.0
        : (item.currentStock / (item.reorderLevel * 2)).clamp(0.0, 1.0);
    final scheme      = Theme.of(context).colorScheme;

    return SproutCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            '${item.sku} · ${item.category ?? '—'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stock level',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    '${(stockHealth * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tileColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
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

          Row(
            children: [
              Expanded(child: _Stat(label: 'On hand', value: '${item.currentStock} units')),
              Expanded(child: _Stat(label: 'Value', value: compactMoney(item.stockValue))),
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
                onPressed: () => ref.read(productsProvider.notifier).deleteProduct(item.id),
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
  final sellingPrice = TextEditingController(text: '0');
  final openingQty   = TextEditingController(text: '0');
  final unitCost     = TextEditingController(text: '0');
  final reorderLevel = TextEditingController(text: '0');
  bool _loading = false;

  @override
  void dispose() {
    name.dispose(); sku.dispose(); category.dispose(); supplier.dispose();
    sellingPrice.dispose(); openingQty.dispose(); unitCost.dispose();
    reorderLevel.dispose();
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
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Product name'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sku,
                      decoration: const InputDecoration(labelText: 'SKU (optional)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: supplier,
                decoration: const InputDecoration(labelText: 'Supplier'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sellingPrice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Selling price (₦)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: unitCost,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cost price (₦)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: openingQty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Opening qty'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: reorderLevel,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Reorder level'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Alerts trigger when quantity falls to or below reorder level.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading
              ? null
              : () async {
                  if (name.text.trim().isEmpty) return;
                  setState(() => _loading = true);
                  try {
                    final product = await ref.read(productsProvider.notifier).addProduct(
                          name: name.text.trim(),
                          sku: sku.text.isEmpty ? null : sku.text.trim(),
                          category: category.text.isEmpty ? null : category.text.trim(),
                          supplier: supplier.text.isEmpty ? null : supplier.text.trim(),
                          sellingPrice: double.tryParse(sellingPrice.text) ?? 0,
                          reorderLevel: int.tryParse(reorderLevel.text) ?? 0,
                        );
                    final qty  = int.tryParse(openingQty.text) ?? 0;
                    final cost = double.tryParse(unitCost.text) ?? 0;
                    if (qty > 0) {
                      await ref.read(productsProvider.notifier).receiveStock(
                            productId: product.id,
                            quantity:  qty,
                            unitCost:  cost > 0 ? cost : (double.tryParse(sellingPrice.text) ?? 0),
                          );
                    }
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add product'),
        ),
      ],
    );
  }
}

// ── Adjust stock dialog ────────────────────────────────────────────────────────

class _AdjustStockDialog extends ConsumerStatefulWidget {
  const _AdjustStockDialog({required this.item});
  final ApiProduct item;

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
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: .4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Current stock',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${widget.item.currentStock} units',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
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
          TextField(
            controller: reason,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref.read(productsProvider.notifier).adjustStock(
                    productId: widget.item.id,
                    quantity:  int.parse(adjustment.text),
                    reason:    reason.text,
                  );
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            }
          },
          child: const Text('Save adjustment'),
        ),
      ],
    );
  }
}
