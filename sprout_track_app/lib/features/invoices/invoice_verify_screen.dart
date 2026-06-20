import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../shared/formatters.dart';

class InvoiceVerifyScreen extends ConsumerWidget {
  const InvoiceVerifyScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verify = ref.watch(_invoiceVerifyProvider(invoiceId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: verify.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const _VerifyError(),
                    data: (data) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.verified_rounded, size: 58, color: scheme.primary),
                        const SizedBox(height: 18),
                        Text(
                          'Document verified',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.businessName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 22),
                        _Line('Document', data.invoiceNumber),
                        _Line('Type', data.documentType),
                        _Line('Customer', data.customerName),
                        _Line('Status', data.paymentStatus),
                        _Line('Date', data.invoiceDate),
                        _Line('Total', money(data.totalAmount)),
                        _Line('Outstanding', money(data.outstandingAmount)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _invoiceVerifyProvider = FutureProvider.family<_VerifiedInvoice, String>((ref, id) async {
  final res = await ref.watch(apiClientProvider).get('/api/invoices/verify/$id');
  final body = res.data as Map<String, dynamic>;
  return _VerifiedInvoice.fromJson((body['data'] ?? body) as Map<String, dynamic>);
});

class _VerifiedInvoice {
  const _VerifiedInvoice({
    required this.invoiceNumber,
    required this.documentType,
    required this.customerName,
    required this.businessName,
    required this.invoiceDate,
    required this.paymentStatus,
    required this.totalAmount,
    required this.outstandingAmount,
  });

  final String invoiceNumber;
  final String documentType;
  final String customerName;
  final String businessName;
  final String invoiceDate;
  final String paymentStatus;
  final double totalAmount;
  final double outstandingAmount;

  factory _VerifiedInvoice.fromJson(Map<String, dynamic> j) => _VerifiedInvoice(
        invoiceNumber: j['invoice_number'] as String? ?? '',
        documentType: j['document_type'] as String? ?? '',
        customerName: j['customer_name'] as String? ?? '',
        businessName: j['business_name'] as String? ?? '',
        invoiceDate: j['invoice_date'] as String? ?? '',
        paymentStatus: j['payment_status'] as String? ?? '',
        totalAmount: (j['total_amount'] as num? ?? 0).toDouble(),
        outstandingAmount: (j['outstanding_amount'] as num? ?? 0).toDouble(),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyError extends StatelessWidget {
  const _VerifyError();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, size: 54, color: AppTheme.terracotta),
        const SizedBox(height: 16),
        Text(
          'Unable to verify document',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}
