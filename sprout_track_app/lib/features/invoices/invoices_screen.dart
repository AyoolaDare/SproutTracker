import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';
import '../../shared/widgets/status_pill.dart';

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sproutStoreProvider);

    return SproutPage(
      title: 'Invoices',
      subtitle: 'Create invoices, deduct stock, update customers, collect payments, and verify receipt totals.',
      action: FilledButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _CreateInvoiceDialog(),
        ),
        icon: const Icon(Icons.receipt_long_rounded),
        label: const Text('New invoice'),
      ),
      children: [
        SproutCard(
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              if (state.invoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('No invoices yet. Create one to start tracking revenue.'),
                ),
              for (final invoice in state.invoices)
                _InvoiceRow(
                  invoice: invoice,
                  isLast: invoice == state.invoices.last,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceRow extends ConsumerWidget {
  const _InvoiceRow({required this.invoice, required this.isLast});

  final Invoice invoice;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _InvoiceDetailsDialog(invoice: invoice),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.customerName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text('${invoice.invoiceNumber} • Due ${shortDate(invoice.dueDate)}'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(invoice.amount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    StatusPill(invoice.derivedStatus.label),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}

class _CreateInvoiceDialog extends ConsumerStatefulWidget {
  const _CreateInvoiceDialog();

  @override
  ConsumerState<_CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends ConsumerState<_CreateInvoiceDialog> {
  final customerName = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();
  PaymentMethod paymentMethod = PaymentMethod.credit;
  bool calculateVat = false;
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
    final state = ref.watch(sproutStoreProvider);
    final matches = state.inventory.where((entry) => entry.id == selectedProductId).toList();
    final product = matches.isEmpty ? null : matches.first;
    final qty = int.tryParse(quantity.text) ?? 0;
    final price = num.tryParse(unitPrice.text) ?? 0;
    final subtotal = qty * price;
    final vat = calculateVat ? subtotal * .075 : 0;

    return AlertDialog(
      title: const Text('Create invoice'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: customerName, decoration: const InputDecoration(labelText: 'Customer name')),
              const SizedBox(height: 10),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Customer phone')),
              const SizedBox(height: 10),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Customer address')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedProductId,
                items: [
                  for (final item in state.inventory)
                    DropdownMenuItem(value: item.id, child: Text('${item.name} (${item.quantity} in stock)')),
                ],
                onChanged: (value) {
                  final selected = state.inventory.firstWhere((entry) => entry.id == value);
                  setState(() {
                    selectedProductId = value;
                    unitPrice.text = selected.unitCost.toString();
                  });
                },
                decoration: const InputDecoration(labelText: 'Product'),
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
                      decoration: const InputDecoration(labelText: 'Unit price'),
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
                onChanged: (value) => setState(() => paymentMethod = value ?? PaymentMethod.credit),
                decoration: const InputDecoration(labelText: 'Payment method'),
              ),
              SwitchListTile(
                value: calculateVat,
                onChanged: (value) => setState(() => calculateVat = value),
                title: const Text('Calculate VAT (7.5%)'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${money(subtotal + vat)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (product != null && qty > product.quantity)
                Text(
                  'Not enough stock. Only ${product.quantity} available.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            try {
              final selected = state.inventory.firstWhere((entry) => entry.id == selectedProductId);
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
                SnackBar(content: Text('Invoice ${invoice.invoiceNumber} created and stock synchronized.')),
              );
            } catch (error) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
            }
          },
          child: const Text('Create invoice'),
        ),
      ],
    );
  }
}

class _InvoiceDetailsDialog extends ConsumerWidget {
  const _InvoiceDetailsDialog({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(sproutStoreProvider).invoices.firstWhere((entry) => entry.id == invoice.id);
    final paymentController = TextEditingController(text: latest.amountDue.toStringAsFixed(0));

    return AlertDialog(
      title: Text(latest.derivedStatus == InvoiceStatus.paid ? 'Receipt ${latest.invoiceNumber}' : 'Invoice ${latest.invoiceNumber}'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      latest.customerName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  StatusPill(latest.derivedStatus.label),
                ],
              ),
              Text(latest.customerAddress),
              const Divider(height: 28),
              for (final item in latest.lineItems)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text('${item.quantity} × ${money(item.unitPrice)}'),
                  trailing: Text(money(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              const Divider(height: 28),
              _AmountLine('Subtotal', latest.subtotal),
              _AmountLine('VAT', latest.vatAmount),
              _AmountLine('Total', latest.amount, emphasized: true),
              _AmountLine('Amount paid', latest.amountPaid),
              _AmountLine('Amount due', latest.amountDue, emphasized: latest.amountDue > 0),
              const SizedBox(height: 12),
              Text('QR verification: /receipts/verify/${latest.id}'),
              const SizedBox(height: 12),
              if (latest.amountDue > 0)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: paymentController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Payment amount'),
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
                      child: const Text('Record payment'),
                    ),
                  ],
                ),
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
          icon: const Icon(Icons.print_rounded),
          label: Text(latest.derivedStatus == InvoiceStatus.paid ? 'Print receipt' : 'Print invoice'),
        ),
        TextButton(
          onPressed: () {
            ref.read(sproutStoreProvider.notifier).deleteInvoice(latest.id);
            Navigator.pop(context);
          },
          child: const Text('Delete and restore stock'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine(this.label, this.amount, {this.emphasized = false});

  final String label;
  final num amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            money(amount),
            style: TextStyle(fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
