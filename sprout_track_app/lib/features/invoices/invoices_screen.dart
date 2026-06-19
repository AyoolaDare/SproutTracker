import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';
import '../../shared/widgets/status_pill.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(sproutStoreProvider);
    final scheme   = Theme.of(context).colorScheme;
    final invoices = state.invoices.where((inv) {
      return switch (_filter) {
        _Filter.all     => true,
        _Filter.pending => inv.derivedStatus == InvoiceStatus.pending,
        _Filter.paid    => inv.derivedStatus == InvoiceStatus.paid,
        _Filter.overdue => inv.derivedStatus == InvoiceStatus.overdue,
      };
    }).toList();

    return SproutPage(
      title: 'Invoices',
      subtitle: 'Create invoices, sync stock, record payments, and print receipts.',
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _CreateInvoiceDialog(),
        ),
        icon: const Icon(Icons.receipt_long_rounded, size: 18),
        label: const Text('New invoice'),
      ),
      children: [
        // ── Filter tabs ───────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.label),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AppTheme.moss.withValues(alpha: .15),
                    checkmarkColor: AppTheme.moss,
                    labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _filter == f ? AppTheme.moss : scheme.onSurfaceVariant,
                          fontWeight: _filter == f ? FontWeight.w800 : FontWeight.w600,
                        ),
                    side: BorderSide(
                      color: _filter == f
                          ? AppTheme.moss.withValues(alpha: .5)
                          : scheme.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Invoice list ──────────────────────────────────────────────────────
        SproutCard(
          padding: EdgeInsets.zero,
          child: invoices.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 40,
                          color: scheme.onSurfaceVariant.withValues(alpha: .4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filter == _Filter.all
                              ? 'No invoices yet. Create one to start tracking revenue.'
                              : 'No ${_filter.label.toLowerCase()} invoices.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Column headers
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: .4),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 52 + 14),
                          Expanded(
                            child: Text(
                              'Customer / Invoice',
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
                    for (var i = 0; i < invoices.length; i++)
                      _InvoiceRow(
                        invoice: invoices[i],
                        isLast: i == invoices.length - 1,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Invoice row ────────────────────────────────────────────────────────────────

class _InvoiceRow extends ConsumerWidget {
  const _InvoiceRow({required this.invoice, required this.isLast});
  final Invoice invoice;
  final bool    isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _InvoiceDetailsDialog(invoice: invoice),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 22,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.customerName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${invoice.invoiceNumber} · Due ${shortDate(invoice.dueDate)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(invoice.amount),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    StatusPill(invoice.derivedStatus.label),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 18,
            endIndent: 18,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .45),
          ),
      ],
    );
  }
}

// ── Create invoice dialog ──────────────────────────────────────────────────────

class _CreateInvoiceDialog extends ConsumerStatefulWidget {
  const _CreateInvoiceDialog();

  @override
  ConsumerState<_CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends ConsumerState<_CreateInvoiceDialog> {
  final customerName = TextEditingController();
  final phone        = TextEditingController();
  final address      = TextEditingController();
  final quantity     = TextEditingController(text: '1');
  final unitPrice    = TextEditingController();
  PaymentMethod paymentMethod = PaymentMethod.credit;
  bool   calculateVat    = false;
  String? selectedProductId;

  @override
  void dispose() {
    customerName.dispose();
    phone.dispose();
    address.dispose();
    quantity.dispose();
    unitPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(sproutStoreProvider);
    final product = state.inventory.where((e) => e.id == selectedProductId).firstOrNull;
    final qty     = int.tryParse(quantity.text) ?? 0;
    final price   = num.tryParse(unitPrice.text) ?? 0;
    final subtotal = qty * price;
    final vat      = calculateVat ? subtotal * .075 : 0;
    final total    = subtotal + vat;
    final scheme   = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Create invoice'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer section
              Text('Customer', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(controller: customerName, decoration: const InputDecoration(labelText: 'Customer name')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: phone,   decoration: const InputDecoration(labelText: 'Phone'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: address, decoration: const InputDecoration(labelText: 'Address'))),
                ],
              ),
              const SizedBox(height: 20),

              // Product section
              Text('Product', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedProductId,
                items: [
                  for (final item in state.inventory)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.name}  (${item.quantity} in stock)'),
                    ),
                ],
                onChanged: (value) {
                  final selected = state.inventory.firstWhere((e) => e.id == value);
                  setState(() {
                    selectedProductId = value;
                    unitPrice.text = selected.unitCost.toString();
                  });
                },
                decoration: const InputDecoration(labelText: 'Select product'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: unitPrice,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Unit price (₦)'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: paymentMethod,
                items: [
                  for (final method in PaymentMethod.values)
                    DropdownMenuItem(value: method, child: Text(method.label)),
                ],
                onChanged: (v) => setState(() => paymentMethod = v ?? PaymentMethod.credit),
                decoration: const InputDecoration(labelText: 'Payment method'),
              ),
              SwitchListTile(
                value: calculateVat,
                onChanged: (v) => setState(() => calculateVat = v),
                title: const Text('Include VAT (7.5%)'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              // Total summary
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      money(total),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.moss,
                          ),
                    ),
                  ],
                ),
              ),

              if (product != null && qty > product.quantity) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.terracotta.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.terracotta, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Insufficient stock. Only ${product.quantity} units available.',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.terracotta),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            try {
              final selected = state.inventory.firstWhere((e) => e.id == selectedProductId);
              final invoice = ref.read(sproutStoreProvider.notifier).createInvoice(
                    customerName: customerName.text,
                    phone: phone.text,
                    address: address.text,
                    paymentMethod: paymentMethod,
                    calculateVat: calculateVat,
                    lineItems: [
                      InvoiceLineItem(
                        productId: selected.id,
                        name: selected.name,
                        quantity: int.parse(quantity.text),
                        unitPrice: num.parse(unitPrice.text),
                      ),
                    ],
                  );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Invoice ${invoice.invoiceNumber} created.')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          },
          child: const Text('Create invoice'),
        ),
      ],
    );
  }
}

// ── Invoice details dialog ─────────────────────────────────────────────────────

class _InvoiceDetailsDialog extends ConsumerWidget {
  const _InvoiceDetailsDialog({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest            = ref.watch(sproutStoreProvider).invoices.firstWhere((e) => e.id == invoice.id);
    final paymentController = TextEditingController(text: latest.amountDue.toStringAsFixed(0));
    final scheme            = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              latest.derivedStatus == InvoiceStatus.paid
                  ? 'Receipt ${latest.invoiceNumber}'
                  : 'Invoice ${latest.invoiceNumber}',
            ),
          ),
          StatusPill(latest.derivedStatus.label),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                latest.customerName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                latest.customerAddress,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // Line items
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: .4),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text('Item', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant))),
                          Text('Qty', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(width: 40),
                          SizedBox(width: 90, child: Text('Amount', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                    for (var i = 0; i < latest.lineItems.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .4)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text(latest.lineItems[i].name, style: Theme.of(context).textTheme.bodyMedium)),
                            Text('${latest.lineItems[i].quantity}'),
                            const SizedBox(width: 20),
                            SizedBox(width: 90, child: Text(money(latest.lineItems[i].lineTotal), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Totals
              _AmountLine('Subtotal', latest.subtotal),
              _AmountLine('VAT (7.5%)', latest.vatAmount),
              Divider(height: 16, color: scheme.outlineVariant.withValues(alpha: .5)),
              _AmountLine('Total', latest.amount, emphasized: true),
              _AmountLine('Amount paid', latest.amountPaid),
              _AmountLine('Balance due', latest.amountDue, emphasized: latest.amountDue > 0),
              const SizedBox(height: 16),

              // QR verification
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_rounded, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '/receipts/verify/${latest.id}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),

              // Record payment
              if (latest.amountDue > 0) ...[
                const SizedBox(height: 16),
                Text('Record payment', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: paymentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Amount (₦)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () {
                        ref.read(sproutStoreProvider.notifier).recordInvoicePayment(
                              latest.id,
                              num.parse(paymentController.text),
                            );
                        Navigator.pop(context);
                      },
                      child: const Text('Record'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            context.go('/invoices/${latest.id}/print');
          },
          icon: const Icon(Icons.print_rounded, size: 16),
          label: Text(latest.derivedStatus == InvoiceStatus.paid ? 'Print receipt' : 'Print invoice'),
        ),
        TextButton(
          onPressed: () {
            ref.read(sproutStoreProvider.notifier).deleteInvoice(latest.id);
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(foregroundColor: AppTheme.terracotta),
          child: const Text('Delete'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

// ── Amount summary row ─────────────────────────────────────────────────────────

class _AmountLine extends StatelessWidget {
  const _AmountLine(this.label, this.amount, {this.emphasized = false});
  final String label;
  final num    amount;
  final bool   emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: emphasized ? null : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Text(
            money(amount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Filter enum ────────────────────────────────────────────────────────────────

enum _Filter {
  all('All'),
  pending('Pending'),
  paid('Paid'),
  overdue('Overdue');

  const _Filter(this.label);
  final String label;
}
