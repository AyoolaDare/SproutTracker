import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_provider.dart';
import '../../state/sprout_state.dart';
import '../api_client.dart';

class ApiInvoice {
  const ApiInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerId,
    required this.totalAmount,
    required this.amountPaid,
    required this.status,
    required this.paymentStatus,
    required this.invoiceDate,
    required this.dueDate,
    this.vatAmount = 0,
    this.whtAmount = 0,
    this.subtotal = 0,
    this.lineItems = const [],
  });

  final String          id;
  final String          invoiceNumber;
  final String          customerName;
  final String          customerId;
  final double          totalAmount;
  final double          amountPaid;
  final String          status;
  final String          paymentStatus;
  final DateTime        invoiceDate;
  final DateTime        dueDate;
  final double          vatAmount;
  final double          whtAmount;
  final double          subtotal;
  final List<ApiInvoiceItem> lineItems;

  double get amountDue => totalAmount - amountPaid;
  bool   get isPaid    => paymentStatus == 'PAID';
  bool   get isOverdue =>
      !isPaid && dueDate.isBefore(DateTime.now()) && status != 'VOID';

  String get displayStatus {
    if (status == 'VOID') return 'void';
    if (isPaid) return 'paid';
    if (isOverdue) return 'overdue';
    if (status == 'DRAFT') return 'draft';
    return 'pending';
  }

  factory ApiInvoice.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List? ?? [])
        .map((e) => ApiInvoiceItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return ApiInvoice(
      id:            j['id'] as String? ?? '',
      invoiceNumber: j['invoice_number'] as String? ?? '',
      customerName:  j['customer_name'] as String? ?? (j['customer'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      customerId:    j['customer_id'] as String? ?? '',
      totalAmount:   (j['total_amount'] as num? ?? 0).toDouble(),
      amountPaid:    ((j['amount_paid'] ?? j['paid_amount']) as num? ?? 0).toDouble(),
      status:        j['status'] as String? ?? 'DRAFT',
      paymentStatus: j['payment_status'] as String? ?? 'UNPAID',
      invoiceDate:   DateTime.tryParse(j['invoice_date'] as String? ?? '') ?? DateTime.now(),
      dueDate:       DateTime.tryParse(j['due_date'] as String? ?? '') ?? DateTime.now(),
      vatAmount:     (j['vat_amount'] as num? ?? 0).toDouble(),
      whtAmount:     (j['wht_amount'] as num? ?? 0).toDouble(),
      subtotal:      (j['subtotal'] as num? ?? 0).toDouble(),
      lineItems:     items,
    );
  }

  factory ApiInvoice.fromLocal(Invoice i) => ApiInvoice(
        id:            i.id,
        invoiceNumber: i.invoiceNumber,
        customerName:  i.customerName,
        customerId:    i.customerId,
        totalAmount:   i.amount.toDouble(),
        amountPaid:    i.amountPaid.toDouble(),
        status:        i.derivedStatus == InvoiceStatus.paid
            ? 'SENT'
            : i.derivedStatus == InvoiceStatus.overdue
                ? 'OVERDUE'
                : 'SENT',
        paymentStatus: i.derivedStatus == InvoiceStatus.paid ? 'PAID' : 'UNPAID',
        invoiceDate:   i.issueDate,
        dueDate:       i.dueDate,
        vatAmount:     i.vatAmount.toDouble(),
        subtotal:      i.subtotal.toDouble(),
        lineItems:     i.lineItems.map(ApiInvoiceItem.fromLocal).toList(),
      );
}

class ApiInvoiceItem {
  const ApiInvoiceItem({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.productId,
  });

  final String  id;
  final String  productName;
  final int     quantity;
  final double  unitPrice;
  final double  lineTotal;
  final String? productId;

  factory ApiInvoiceItem.fromJson(Map<String, dynamic> j) => ApiInvoiceItem(
        id:          j['id'] as String? ?? '',
        productName: j['description'] as String? ?? j['product_name'] as String? ?? '',
        quantity:    (j['quantity'] as num? ?? 1).toInt(),
        unitPrice:   (j['unit_price'] as num? ?? 0).toDouble(),
        lineTotal:   (j['line_total'] as num? ?? 0).toDouble(),
        productId:   j['product_id'] as String?,
      );

  factory ApiInvoiceItem.fromLocal(InvoiceLineItem item) => ApiInvoiceItem(
        id:          item.productId ?? '',
        productName: item.name,
        quantity:    item.quantity,
        unitPrice:   item.unitPrice.toDouble(),
        lineTotal:   item.lineTotal.toDouble(),
        productId:   item.productId,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class InvoicesNotifier extends AutoDisposeAsyncNotifier<List<ApiInvoice>> {
  @override
  Future<List<ApiInvoice>> build() => _load();

  Future<List<ApiInvoice>> _load() async {
    final isDemo = ref.watch(authProvider).isDemo;
    if (isDemo) {
      return ref
          .watch(sproutStoreProvider)
          .invoices
          .map(ApiInvoice.fromLocal)
          .toList();
    }
    final res = await ref.watch(apiClientProvider).get(
      '/api/invoices',
      query: {'limit': 100},
    );
    final body = res.data as Map<String, dynamic>;
    final items = (body['data'] ?? body['items'] ?? body['invoices'] ?? []) as List;
    return items
        .map((e) => ApiInvoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<ApiInvoice> create({
    required String customerId,
    required DateTime invoiceDate,
    required DateTime dueDate,
    required List<Map<String, dynamic>> items,
    bool finalize = true,
    bool applyVat = true,
    bool applyWht = false,
    String? notes,
    String? terms,
  }) async {
    final res = await ref.read(apiClientProvider).post(
      '/api/invoices',
      data: {
        'customer_id': customerId,
        'invoice_date': invoiceDate.toIso8601String().split('T').first,
        'due_date': dueDate.toIso8601String().split('T').first,
        'status': 'DRAFT',
        'items': items,
        'apply_vat': applyVat,
        'apply_wht': applyWht,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (terms != null && terms.isNotEmpty) 'terms': terms,
      },
    );
    final body = res.data as Map<String, dynamic>;
    var invoice = ApiInvoice.fromJson((body['data'] ?? body) as Map<String, dynamic>);
    if (finalize) {
      final finalized = await ref.read(apiClientProvider).post(
        '/api/invoices/${invoice.id}/finalize',
      );
      final finalizedBody = finalized.data as Map<String, dynamic>;
      invoice = ApiInvoice.fromJson(
        (finalizedBody['data'] ?? finalizedBody) as Map<String, dynamic>,
      );
    }
    await refresh();
    return invoice;
  }

  Future<ApiInvoice?> getById(String id) async {
    final isDemo = ref.read(authProvider).isDemo;
    if (isDemo) {
      // Use cached state if loaded, otherwise await first build
      final all = state.valueOrNull ?? await future;
      return all.where((inv) => inv.id == id).firstOrNull;
    }
    final res = await ref.read(apiClientProvider).get('/api/invoices/$id');
    final body = res.data as Map<String, dynamic>;
    return ApiInvoice.fromJson((body['data'] ?? body) as Map<String, dynamic>);
  }

  Future<void> recordPayment({
    required String invoiceId,
    required double amount,
    required String method,
    String? reference,
  }) async {
    await ref.read(apiClientProvider).post(
      '/api/invoices/$invoiceId/payments',
      data: {
        'amount':     amount,
        'payment_method': method,
        if (reference != null) 'reference': reference,
        'payment_date': DateTime.now().toIso8601String().split('T').first,
      },
    );
    await refresh();
  }

  Future<void> voidInvoice(String id) async {
    await ref.read(apiClientProvider).post('/api/invoices/$id/void');
    await refresh();
  }

  Future<void> emailInvoice({
    required String invoiceId,
    String? toEmail,
    String? message,
  }) async {
    await ref.read(apiClientProvider).post(
      '/api/invoices/$invoiceId/send-email',
      data: {
        if (toEmail != null && toEmail.isNotEmpty) 'to_email': toEmail,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
  }
}

final invoicesProvider =
    AsyncNotifierProvider.autoDispose<InvoicesNotifier, List<ApiInvoice>>(
  InvoicesNotifier.new,
);
