import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/api/features/invoices_provider.dart';
import '../../core/api/features/settings_provider.dart';
import '../../core/printing/print_service.dart';
import '../../shared/formatters.dart';

class InvoicePrintScreen extends ConsumerWidget {
  const InvoicePrintScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(settingsProvider).valueOrNull ??
        const ApiBusinessProfile(businessName: 'Sprout Track');
    final invoiceFuture = ref.watch(invoicesProvider.notifier).getById(invoiceId);

    return FutureBuilder<ApiInvoice?>(
      future: invoiceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final invoice = snapshot.data;
        if (invoice == null || snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                snapshot.error == null
                    ? 'Invoice not found'
                    : 'Invoice not found: ${snapshot.error}',
              ),
            ),
          );
        }

        final isReceipt = invoice.isPaid;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(isReceipt ? 'Receipt preview' : 'Invoice preview'),
            actions: [
              FilledButton.icon(
                onPressed: printCurrentPage,
                icon: const Icon(Icons.print_rounded),
                label: const Text('Print'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                width: 820,
                padding: const EdgeInsets.all(42),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE7E0D2)),
                ),
                child: DefaultTextStyle(
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: AppTheme.ink),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppTheme.moss,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: AppTheme.sand,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.businessName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AppTheme.ink,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                if ((profile.address ?? '').isNotEmpty)
                                  Text(profile.address!),
                                Text([
                                  if ((profile.email ?? '').isNotEmpty) profile.email!,
                                  if ((profile.phone ?? '').isNotEmpty) profile.phone!,
                                ].join(' • '),),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isReceipt ? 'RECEIPT' : 'INVOICE',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppTheme.ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              Text(invoice.displayStatus.toUpperCase()),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _PrintBlock(
                              title: 'Billed To',
                              lines: [invoice.customerName],
                            ),
                          ),
                          Expanded(
                            child: _PrintBlock(
                              title: 'Document',
                              alignEnd: true,
                              lines: [
                                invoice.invoiceNumber,
                                'Issued ${shortDate(invoice.invoiceDate)}',
                                if (!isReceipt) 'Due ${shortDate(invoice.dueDate)}',
                                'Payment ${invoice.paymentStatus}',
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(4),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(2),
                        },
                        border: TableBorder(
                          horizontalInside: BorderSide(
                            color: AppTheme.clay.withValues(alpha: .25),
                          ),
                          top: BorderSide(color: AppTheme.clay.withValues(alpha: .35)),
                          bottom:
                              BorderSide(color: AppTheme.clay.withValues(alpha: .35)),
                        ),
                        children: [
                          const TableRow(
                            children: [
                              _TableCell('Item', bold: true),
                              _TableCell('Qty', bold: true, alignEnd: true),
                              _TableCell('Price', bold: true, alignEnd: true),
                              _TableCell('Total', bold: true, alignEnd: true),
                            ],
                          ),
                          for (final item in invoice.lineItems)
                            TableRow(
                              children: [
                                _TableCell(item.productName),
                                _TableCell('${item.quantity}', alignEnd: true),
                                _TableCell(money(item.unitPrice), alignEnd: true),
                                _TableCell(money(item.lineTotal), alignEnd: true),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 280,
                          child: Column(
                            children: [
                              _TotalLine('Subtotal', invoice.subtotal),
                              _TotalLine('VAT', invoice.vatAmount),
                              _TotalLine('Total', invoice.totalAmount, bold: true),
                              _TotalLine('Amount paid', invoice.amountPaid),
                              if (!isReceipt)
                                _TotalLine(
                                  'Amount due',
                                  invoice.amountDue,
                                  bold: true,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.moss),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'QR\nVERIFY',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: AppTheme.moss),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Text('Verify at /verify-invoice/${invoice.id}')),
                          Text(
                            'Thank you for your business.',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrintBlock extends StatelessWidget {
  const _PrintBlock({
    required this.title,
    required this.lines,
    this.alignEnd = false,
  });

  final String title;
  final List<String> lines;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.moss),
        ),
        const SizedBox(height: 6),
        for (final line in lines.where((line) => line.trim().isNotEmpty))
          Text(
            line,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          ),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text, {this.bold = false, this.alignEnd = false});

  final String text;
  final bool bold;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w500),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.amount, {this.bold = false});

  final String label;
  final num amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            money(amount),
            style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
