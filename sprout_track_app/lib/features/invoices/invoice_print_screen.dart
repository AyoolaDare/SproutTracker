import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../app/app_theme.dart';
import '../../core/api/features/invoices_provider.dart';
import '../../core/api/features/settings_provider.dart';
import '../../shared/formatters.dart';
import 'invoice_pdf_service.dart';

class InvoicePrintScreen extends ConsumerStatefulWidget {
  const InvoicePrintScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  ConsumerState<InvoicePrintScreen> createState() => _InvoicePrintScreenState();
}

class _InvoicePrintScreenState extends ConsumerState<InvoicePrintScreen> {
  late final Future<ApiInvoice?> _invoiceFuture;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    // Stored once — ref.watch in build keeps the AutoDispose provider alive.
    _invoiceFuture =
        ref.read(invoicesProvider.notifier).getById(widget.invoiceId);
  }

  Future<void> _download(ApiInvoice invoice, ApiBusinessProfile profile) async {
    setState(() => _downloading = true);
    try {
      final Uint8List bytes = await buildInvoicePdf(invoice, profile);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${invoice.invoiceNumber}.pdf',
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch keeps the AutoDispose provider alive while this screen is mounted.
    ref.watch(invoicesProvider);
    final profile = ref.watch(settingsProvider).valueOrNull ??
        const ApiBusinessProfile(businessName: 'Sprout Track');

    return FutureBuilder<ApiInvoice?>(
      future: _invoiceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final invoice = snapshot.data;
        if (invoice == null || snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Invoice')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 52,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.hasError
                        ? 'Could not load invoice'
                        : 'Invoice not found',
                  ),
                ],
              ),
            ),
          );
        }

        final isReceipt = invoice.isPaid;

        return Scaffold(
          backgroundColor: const Color(0xFFF0EBE1),
          appBar: AppBar(
            backgroundColor: AppTheme.ink,
            foregroundColor: AppTheme.sand,
            elevation: 0,
            title: Text(
              isReceipt
                  ? 'Receipt • ${invoice.invoiceNumber}'
                  : 'Invoice • ${invoice.invoiceNumber}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            actions: [
              if (_downloading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.sand,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: () => _download(invoice, profile),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.moss,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text(
                      'Download PDF',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Container(
                width: 820,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE0D8CC)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .07),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header band ─────────────────────────────────────
                    Container(
                      color: AppTheme.ink,
                      padding: const EdgeInsets.fromLTRB(42, 26, 42, 26),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.moss,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: AppTheme.sand,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.businessName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: AppTheme.sand,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                if ((profile.address ?? '').isNotEmpty)
                                  Text(
                                    profile.address!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.sand
                                              .withValues(alpha: .65),
                                        ),
                                  ),
                                if ((profile.phone ?? '').isNotEmpty ||
                                    (profile.email ?? '').isNotEmpty)
                                  Text(
                                    [
                                      if ((profile.phone ?? '').isNotEmpty)
                                        profile.phone!,
                                      if ((profile.email ?? '').isNotEmpty)
                                        profile.email!,
                                    ].join('  •  '),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppTheme.sand
                                              .withValues(alpha: .55),
                                        ),
                                  ),
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
                                      color: AppTheme.sand,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                invoice.invoiceNumber,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.clay,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Status ribbon ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      color: isReceipt
                          ? const Color(0xFF2E7D32)
                          : AppTheme.terracotta,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 42,
                        vertical: 6,
                      ),
                      child: Text(
                        isReceipt ? 'FULLY PAID' : 'PAYMENT PENDING',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.5,
                                ),
                      ),
                    ),

                    // ── Body ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(42, 28, 42, 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bill To / Document meta
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _PrintBlock(
                                  title: 'BILLED TO',
                                  lines: [invoice.customerName],
                                ),
                              ),
                              _PrintBlock(
                                title: 'DOCUMENT',
                                alignEnd: true,
                                lines: [
                                  invoice.invoiceNumber,
                                  'Issued ${shortDate(invoice.invoiceDate)}',
                                  if (!isReceipt)
                                    'Due ${shortDate(invoice.dueDate)}',
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Items table
                          Table(
                            columnWidths: const {
                              0: FlexColumnWidth(4),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(2),
                              3: FlexColumnWidth(2),
                            },
                            border: TableBorder(
                              top: BorderSide(
                                color: AppTheme.moss.withValues(alpha: .35),
                              ),
                              bottom: BorderSide(
                                color: AppTheme.moss.withValues(alpha: .35),
                              ),
                              horizontalInside: BorderSide(
                                color: AppTheme.clay.withValues(alpha: .18),
                              ),
                            ),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: AppTheme.moss.withValues(alpha: .06),
                                ),
                                children: const [
                                  _TableCell(
                                    'ITEM',
                                    bold: true,
                                    small: true,
                                    label: true,
                                  ),
                                  _TableCell(
                                    'QTY',
                                    bold: true,
                                    small: true,
                                    label: true,
                                    alignEnd: true,
                                  ),
                                  _TableCell(
                                    'UNIT PRICE',
                                    bold: true,
                                    small: true,
                                    label: true,
                                    alignEnd: true,
                                  ),
                                  _TableCell(
                                    'TOTAL',
                                    bold: true,
                                    small: true,
                                    label: true,
                                    alignEnd: true,
                                  ),
                                ],
                              ),
                              for (final item in invoice.lineItems)
                                TableRow(
                                  children: [
                                    _TableCell(item.productName),
                                    _TableCell(
                                      '${item.quantity}',
                                      alignEnd: true,
                                    ),
                                    _TableCell(
                                      money(item.unitPrice),
                                      alignEnd: true,
                                    ),
                                    _TableCell(
                                      money(item.lineTotal),
                                      bold: true,
                                      alignEnd: true,
                                    ),
                                  ],
                                ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Totals
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 300,
                              child: Column(
                                children: [
                                  if (invoice.vatAmount > 0) ...[
                                    _TotalLine(
                                      'Subtotal',
                                      invoice.subtotal,
                                    ),
                                    _TotalLine(
                                      'VAT (7.5%)',
                                      invoice.vatAmount,
                                    ),
                                  ],
                                  Divider(
                                    color: AppTheme.clay.withValues(alpha: .3),
                                  ),
                                  _TotalLine(
                                    'Total',
                                    invoice.totalAmount,
                                    bold: true,
                                  ),
                                  _TotalLine(
                                    'Amount Paid',
                                    invoice.amountPaid,
                                    color: isReceipt
                                        ? const Color(0xFF2E7D32)
                                        : null,
                                  ),
                                  if (!isReceipt &&
                                      invoice.amountDue > 0) ...[
                                    Divider(
                                      color:
                                          AppTheme.clay.withValues(alpha: .3),
                                    ),
                                    _TotalLine(
                                      'Balance Due',
                                      invoice.amountDue,
                                      bold: true,
                                      color: AppTheme.terracotta,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Footer
                          Divider(color: AppTheme.clay.withValues(alpha: .25)),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if ((profile.bankName ?? '').isNotEmpty ||
                                  (profile.accountNumber ?? '').isNotEmpty)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PAYMENT DETAILS',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppTheme.moss,
                                              letterSpacing: 1.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      if ((profile.bankName ?? '').isNotEmpty)
                                        Text(
                                          'Bank: ${profile.bankName!}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: AppTheme.ink),
                                        ),
                                      if ((profile.accountNumber ?? '')
                                          .isNotEmpty)
                                        Text(
                                          'Account: ${profile.accountNumber!}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: AppTheme.ink),
                                        ),
                                      if ((profile.accountName ?? '')
                                          .isNotEmpty)
                                        Text(
                                          'Name: ${profile.accountName!}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: AppTheme.ink),
                                        ),
                                    ],
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Thank you for your business.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: AppTheme.moss,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Powered by Sprout Track',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: AppTheme.clay),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

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
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.moss,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
        ),
        const SizedBox(height: 6),
        for (final line in lines.where((l) => l.trim().isNotEmpty))
          Text(
            line,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.ink),
          ),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(
    this.text, {
    this.bold = false,
    this.small = false,
    this.label = false,
    this.alignEnd = false,
  });

  final String text;
  final bool bold;
  final bool small;
  final bool label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      child: Text(
        text,
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        style: (small
                ? Theme.of(context).textTheme.labelSmall
                : Theme.of(context).textTheme.bodyMedium)
            ?.copyWith(
          color: label ? AppTheme.moss : AppTheme.ink,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          letterSpacing: label ? 0.8 : null,
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine(this.label, this.amount, {this.bold = false, this.color});

  final String label;
  final num amount;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? AppTheme.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: effective,
              ),
            ),
          ),
          Text(
            money(amount),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: effective,
            ),
          ),
        ],
      ),
    );
  }
}
