import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../app/app_theme.dart';
import '../../core/api/features/customers_provider.dart';
import '../../core/api/features/invoices_provider.dart';
import '../../core/api/features/products_provider.dart';
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
    final invoicesAsync = ref.watch(invoicesProvider);
    final scheme   = Theme.of(context).colorScheme;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final invoices = (invoicesAsync.valueOrNull ?? []).where((inv) {
      return switch (_filter) {
        _Filter.all     => true,
        _Filter.pending => inv.displayStatus == 'pending' || inv.displayStatus == 'draft',
        _Filter.paid    => inv.displayStatus == 'paid',
        _Filter.overdue => inv.displayStatus == 'overdue',
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
        if (invoicesAsync.isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (invoicesAsync.hasError)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Could not load invoices: ${invoicesAsync.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ),
          )
        else
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
                    if (!isMobile)
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
  final ApiInvoice invoice;
  final bool    isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Column(
      children: [
        InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _InvoiceDetailsDialog(invoice: invoice),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 18,
              vertical: isMobile ? 13 : 14,
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: isMobile ? 44 : 52,
                  height: isMobile ? 44 : 52,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                SizedBox(width: isMobile ? 8 : 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isMobile ? 92 : 132),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          money(invoice.totalAmount),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: StatusPill(invoice.displayStatus),
                    ),
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

// ── Line-item mutable state ────────────────────────────────────────────────────

class _LineItemData {
  String? productId;
  final TextEditingController desc  = TextEditingController();
  final TextEditingController qty   = TextEditingController(text: '1');
  final TextEditingController price = TextEditingController();
  final TextEditingController disc  = TextEditingController(text: '0');
  bool discPct     = true;
  bool discEnabled = false;
  bool vatEnabled  = false;

  double get grossAmt {
    final q = double.tryParse(qty.text) ?? 0;
    final p = double.tryParse(price.text) ?? 0;
    return q * p;
  }

  double get discountAmt {
    if (!discEnabled) return 0;
    final d = double.tryParse(disc.text) ?? 0;
    return discPct ? grossAmt * d / 100 : d.clamp(0, grossAmt);
  }

  double get netAmt    => grossAmt - discountAmt;
  double get vatAmt    => vatEnabled ? netAmt * 0.075 : 0;
  double get lineTotal => netAmt + vatAmt;

  void dispose() {
    desc.dispose();
    qty.dispose();
    price.dispose();
    disc.dispose();
  }
}

// ── Create invoice dialog ──────────────────────────────────────────────────────

class _CreateInvoiceDialog extends ConsumerStatefulWidget {
  const _CreateInvoiceDialog();

  @override
  ConsumerState<_CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends ConsumerState<_CreateInvoiceDialog> {
  // Customer
  ApiCustomer? _customer;
  bool _newCust       = false;
  final _custName     = TextEditingController();
  final _custPhone    = TextEditingController();
  final _custEmail    = TextEditingController();

  // Line items
  final List<_LineItemData> _lineItems = [_LineItemData()];

  // Invoice-level adjustments (mutually exclusive with per-line)
  bool _invoiceDiscEnabled = false;
  bool _invoiceDiscPct     = true;
  final _invoiceDisc       = TextEditingController(text: '0');
  bool _invoiceVatEnabled  = false;

  bool _saving = false;

  bool get _anyLineDiscount => _lineItems.any((i) => i.discEnabled);
  bool get _anyLineVat      => _lineItems.any((i) => i.vatEnabled);

  @override
  void dispose() {
    for (final item in _lineItems) {
      item.dispose();
    }
    _custName.dispose();
    _custPhone.dispose();
    _custEmail.dispose();
    _invoiceDisc.dispose();
    super.dispose();
  }

  // ── Totals ────────────────────────────────────────────────────────────────────

  double get _grossSubtotal => _lineItems.fold(0.0, (s, i) => s + i.grossAmt);
  double get _lineDiscTotal => _lineItems.fold(0.0, (s, i) => s + i.discountAmt);
  double get _lineVatTotal  => _lineItems.fold(0.0, (s, i) => s + i.vatAmt);
  double get _subtotalNet   => _lineItems.fold(0.0, (s, i) => s + i.netAmt);

  double get _invoiceDiscountAmt {
    if (!_invoiceDiscEnabled) return 0;
    final d = double.tryParse(_invoiceDisc.text) ?? 0;
    return _invoiceDiscPct ? _subtotalNet * d / 100 : d.clamp(0, _subtotalNet);
  }

  double get _taxableAmt    => _subtotalNet - _invoiceDiscountAmt;
  double get _invoiceVatAmt => _invoiceVatEnabled ? _taxableAmt * 0.075 : 0;
  double get _grandTotal    => _taxableAmt + _lineVatTotal + _invoiceVatAmt;

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider).valueOrNull ?? const <ApiCustomer>[];
    final products  = ref.watch(productsProvider).valueOrNull  ?? const <ApiProduct>[];
    final scheme    = Theme.of(context).colorScheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.moss.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 18,
              color: AppTheme.moss,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('New Invoice')),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),

              // ── CUSTOMER ─────────────────────────────────────────────────
              _SectionLabel('CUSTOMER'),
              const SizedBox(height: 10),
              if (!_newCust) ...[
                DropdownButtonFormField<ApiCustomer>(
                  initialValue: _customer,
                  decoration: const InputDecoration(
                    labelText: 'Select customer',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                  ),
                  items: [
                    for (final c in customers)
                      DropdownMenuItem(
                        value: c,
                        child: Text(c.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _customer = v),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _newCust  = true;
                    _customer = null;
                  }),
                  child: const Text(
                    '+ Create new customer',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.moss,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.moss.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.moss.withValues(alpha: .2),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _custName,
                        decoration: const InputDecoration(
                          labelText: 'Full name *',
                          prefixIcon: Icon(Icons.person_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _custPhone,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: Icon(Icons.phone_outlined, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _custEmail,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _newCust = false),
                  child: const Text(
                    '← Back to customer list',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.moss,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── LINE ITEMS ────────────────────────────────────────────────
              Row(
                children: [
                  const Expanded(child: _SectionLabel('LINE ITEMS')),
                  _ActionPill(
                    label: '+ Add item',
                    onTap: () => setState(() => _lineItems.add(_LineItemData())),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var idx = 0; idx < _lineItems.length; idx++)
                _buildItemCard(
                  context: context,
                  idx: idx,
                  item: _lineItems[idx],
                  products: products,
                  scheme: scheme,
                ),

              const SizedBox(height: 4),

              // ── TOTALS CARD ───────────────────────────────────────────────
              _buildTotalsCard(context: context, scheme: scheme),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 16),
          label: const Text('Create invoice'),
        ),
      ],
    );
  }

  // ── Line item card ─────────────────────────────────────────────────────────

  Widget _buildItemCard({
    required BuildContext context,
    required int idx,
    required _LineItemData item,
    required List<ApiProduct> products,
    required ColorScheme scheme,
  }) {
    final isActive  = item.discEnabled || item.vatEnabled;
    final canDisc   = !_invoiceDiscEnabled;
    final canVat    = !_invoiceVatEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppTheme.moss.withValues(alpha: .3)
              : scheme.outlineVariant.withValues(alpha: .45),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Product selector row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: item.productId,
                    decoration: InputDecoration(
                      hintText: 'Select product (optional)',
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: .5),
                        fontSize: 13,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppTheme.moss.withValues(alpha: .5),
                        ),
                      ),
                    ),
                    items: [
                      for (final p in products)
                        DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.name}  ·  ${p.currentStock} in stock',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      final p = products.firstWhere((e) => e.id == val);
                      setState(() {
                        item.productId  = val;
                        item.desc.text  = p.name;
                        item.price.text = p.sellingPrice.toStringAsFixed(0);
                      });
                    },
                  ),
                ),
                if (_lineItems.length > 1)
                  IconButton(
                    onPressed: () {
                      _lineItems[idx].dispose();
                      setState(() => _lineItems.removeAt(idx));
                    },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: scheme.onSurfaceVariant.withValues(alpha: .5),
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // ── Description ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: TextField(
              controller: item.desc,
              decoration: InputDecoration(
                hintText: 'Item description',
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: .45),
                  fontSize: 13,
                ),
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.moss.withValues(alpha: .5),
                  ),
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // ── Qty × Price ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Qty field
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: item.qty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: .5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.moss.withValues(alpha: .5),
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '×',
                    style: TextStyle(
                      fontSize: 18,
                      color: scheme.onSurfaceVariant.withValues(alpha: .5),
                    ),
                  ),
                ),
                // Price field
                Expanded(
                  child: TextField(
                    controller: item.price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Unit price',
                      prefixText: '₦ ',
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest.withValues(alpha: .5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.moss.withValues(alpha: .5),
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                // Line total
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      money(item.lineTotal),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.moss,
                          ),
                    ),
                    if (item.discountAmt > 0)
                      Text(
                        '−${money(item.discountAmt)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.terracotta,
                            ),
                      ),
                    if (item.vatAmt > 0)
                      Text(
                        '+VAT ${money(item.vatAmt)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.moss,
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Discount input (visible when enabled) ───────────────────────
          if (item.discEnabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  _PillToggle(
                    options: const ['%', '₦'],
                    selectedIndex: item.discPct ? 0 : 1,
                    onChanged: (i) => setState(() => item.discPct = i == 0),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: item.disc,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: item.discPct ? 'Discount %' : 'Discount ₦',
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.terracotta.withValues(alpha: .06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: AppTheme.terracotta.withValues(alpha: .3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: AppTheme.terracotta.withValues(alpha: .3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.terracotta),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (item.discountAmt > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      'saves ${money(item.discountAmt)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.terracotta,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Action buttons: Discount + VAT ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                if (canDisc)
                  _ToggleBtn(
                    label: item.discEnabled ? 'Discount on' : '+ Discount',
                    active: item.discEnabled,
                    color: AppTheme.terracotta,
                    icon: item.discEnabled
                        ? Icons.discount_rounded
                        : Icons.discount_outlined,
                    onTap: () => setState(() {
                      item.discEnabled = !item.discEnabled;
                      if (!item.discEnabled) item.disc.text = '0';
                    }),
                  ),
                if (canDisc) const SizedBox(width: 8),
                if (canVat)
                  _ToggleBtn(
                    label: item.vatEnabled ? 'VAT 7.5% on' : '+ VAT 7.5%',
                    active: item.vatEnabled,
                    color: AppTheme.moss,
                    icon: item.vatEnabled
                        ? Icons.receipt_rounded
                        : Icons.receipt_outlined,
                    onTap: () => setState(() => item.vatEnabled = !item.vatEnabled),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Totals card ────────────────────────────────────────────────────────────

  Widget _buildTotalsCard({
    required BuildContext context,
    required ColorScheme scheme,
  }) {
    final hasAnyDisc = _anyLineDiscount || _invoiceDiscEnabled;
    final hasAnyVat  = _anyLineVat || _invoiceVatEnabled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.moss.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.moss.withValues(alpha: .2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtotal
          _SummaryRow(
            label: 'Subtotal',
            value: money(_grossSubtotal),
          ),

          // Line discount summary
          if (_lineDiscTotal > 0) ...[
            const SizedBox(height: 2),
            _SummaryRow(
              label: 'Line discounts',
              value: '−${money(_lineDiscTotal)}',
              valueColor: AppTheme.terracotta,
            ),
            _SummaryRow(
              label: 'After discounts',
              value: money(_subtotalNet),
            ),
          ],

          // Invoice-level discount input
          if (_invoiceDiscEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Invoice discount',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.terracotta,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                _PillToggle(
                  options: const ['%', '₦'],
                  selectedIndex: _invoiceDiscPct ? 0 : 1,
                  onChanged: (i) => setState(() => _invoiceDiscPct = i == 0),
                  compact: true,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: _invoiceDisc,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppTheme.terracotta.withValues(alpha: .06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.terracotta.withValues(alpha: .3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.terracotta.withValues(alpha: .3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.terracotta),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_invoiceDiscountAmt > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '−${money(_invoiceDiscountAmt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.terracotta,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
            if (_invoiceDiscountAmt > 0) ...[
              const SizedBox(height: 4),
              _SummaryRow(
                label: 'Taxable amount',
                value: money(_taxableAmt),
              ),
            ],
          ],

          // Line-level VAT total
          if (_lineVatTotal > 0) ...[
            const SizedBox(height: 2),
            _SummaryRow(
              label: 'VAT (7.5% per line)',
              value: '+${money(_lineVatTotal)}',
              valueColor: AppTheme.moss,
            ),
          ],

          // Invoice-level VAT
          if (_invoiceVatEnabled) ...[
            const SizedBox(height: 2),
            _SummaryRow(
              label: 'VAT (7.5% on subtotal)',
              value: '+${money(_invoiceVatAmt)}',
              valueColor: AppTheme.moss,
            ),
          ],

          // ── Action buttons ─────────────────────────────────────────────
          if (!hasAnyDisc || !hasAnyVat) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (!hasAnyDisc)
                  _ToggleBtn(
                    label: '+ Invoice discount',
                    active: false,
                    color: AppTheme.terracotta,
                    icon: Icons.discount_outlined,
                    onTap: () => setState(() => _invoiceDiscEnabled = true),
                  ),
                if (!hasAnyDisc && !hasAnyVat) const SizedBox(width: 8),
                if (!hasAnyVat)
                  _ToggleBtn(
                    label: '+ VAT 7.5%',
                    active: false,
                    color: AppTheme.moss,
                    icon: Icons.receipt_outlined,
                    onTap: () => setState(() => _invoiceVatEnabled = true),
                  ),
              ],
            ),
          ],

          // Remove links for active invoice-level options
          if (_invoiceDiscEnabled || _invoiceVatEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_invoiceDiscEnabled)
                  GestureDetector(
                    onTap: () => setState(() {
                      _invoiceDiscEnabled = false;
                      _invoiceDisc.text   = '0';
                    }),
                    child: const Text(
                      '× Remove discount',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.terracotta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_invoiceDiscEnabled && _invoiceVatEnabled)
                  const SizedBox(width: 16),
                if (_invoiceVatEnabled)
                  GestureDetector(
                    onTap: () => setState(() => _invoiceVatEnabled = false),
                    child: const Text(
                      '× Remove VAT',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.terracotta,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // ── Grand Total ────────────────────────────────────────────────
          const SizedBox(height: 14),
          Divider(
            color: AppTheme.moss.withValues(alpha: .2),
            height: 1,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'TOTAL',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.moss,
                      letterSpacing: 0.8,
                    ),
              ),
              const Spacer(),
              Text(
                money(_grandTotal),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.moss,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      ApiCustomer? customer = _customer;
      if (_newCust) {
        final name = _custName.text.trim();
        if (name.isEmpty) throw Exception('Customer name is required.');
        customer = await ref.read(customersProvider.notifier).create(
              name: name,
              phone: _custPhone.text.trim().isEmpty ? null : _custPhone.text.trim(),
              email: _custEmail.text.trim().isEmpty ? null : _custEmail.text.trim(),
            );
      } else if (customer == null) {
        throw Exception('Please select or create a customer.');
      }

      if (_lineItems.isEmpty) throw Exception('Add at least one line item.');
      for (var i = 0; i < _lineItems.length; i++) {
        final item = _lineItems[i];
        if (item.desc.text.trim().isEmpty && item.productId == null) {
          throw Exception('Item ${i + 1}: add a description or select a product.');
        }
        if ((double.tryParse(item.price.text) ?? 0) <= 0) {
          throw Exception('Item ${i + 1}: unit price must be greater than 0.');
        }
      }

      final apiItems = <Map<String, dynamic>>[
        for (final item in _lineItems)
          <String, dynamic>{
            'description': item.desc.text.trim().isEmpty ? 'Item' : item.desc.text.trim(),
            'quantity':    double.tryParse(item.qty.text) ?? 1,
            'unit_price':  double.tryParse(item.price.text) ?? 0,
            if (item.productId != null) 'product_id': item.productId,
            if (item.discEnabled) ...{
              'discount_amount': item.discountAmt,
              'discount_type':   item.discPct ? 'percent' : 'fixed',
            },
          },
      ];

      final invDiscount = _invoiceDiscountAmt;

      final invoice = await ref.read(invoicesProvider.notifier).create(
            customerId:  customer.id,
            invoiceDate: DateTime.now(),
            dueDate:     DateTime.now().add(const Duration(days: 14)),
            applyVat:    _invoiceVatEnabled || _anyLineVat,
            items:       apiItems,
            notes: invDiscount > 0
                ? 'Invoice discount: ${money(invDiscount)}'
                : null,
          );

      ref.invalidate(productsProvider);
      ref.invalidate(customersProvider);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice ${invoice.invoiceNumber} created.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: AppTheme.moss,
          letterSpacing: 1.4,
        ),
      );
}

// ── Pill link button (e.g. "+ Add item") ──────────────────────────────────────

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});
  final String        label;
  final VoidCallback  onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.moss.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.moss.withValues(alpha: .3)),
          ),
          child: const Text(
            '+ Add item',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.moss,
            ),
          ),
        ),
      );
}

// ── Toggle action button (outline pill that fills when active) ─────────────────

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.active,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String    label;
  final bool      active;
  final Color     color;
  final IconData  icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outlineColor = active ? color.withValues(alpha: .5) : Theme.of(context).colorScheme.outlineVariant;
    final textColor    = active ? color : Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: .1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: outlineColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── % / ₦ pill toggle ─────────────────────────────────────────────────────────

class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.compact = false,
  });

  final List<String>       options;
  final int                selectedIndex;
  final void Function(int) onChanged;
  final bool               compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 7 : 9,
                  vertical: compact ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: i == selectedIndex ? AppTheme.moss : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: i == selectedIndex ? Colors.white : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Totals summary row ─────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Invoice details dialog ─────────────────────────────────────────────────────

class _InvoiceDetailsDialog extends ConsumerWidget {
  const _InvoiceDetailsDialog({required this.invoice});
  final ApiInvoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest            = invoice;
    final paymentController = TextEditingController(text: latest.amountDue.toStringAsFixed(0));
    final scheme            = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              latest.isPaid
                  ? 'Receipt ${latest.invoiceNumber}'
                  : 'Invoice ${latest.invoiceNumber}',
            ),
          ),
          StatusPill(latest.displayStatus),
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
                latest.customerName,
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
                            Expanded(child: Text(latest.lineItems[i].productName, style: Theme.of(context).textTheme.bodyMedium)),
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
              _AmountLine('Total', latest.totalAmount, emphasized: true),
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
                        '/verify-invoice/${latest.id}',
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
                      onPressed: () async {
                        await ref.read(invoicesProvider.notifier).recordPayment(
                              invoiceId: latest.id,
                              amount: double.parse(paymentController.text),
                              method: 'BANK_TRANSFER',
                            );
                        if (!context.mounted) return;
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
          label: Text(latest.isPaid ? 'Print receipt' : 'Print invoice'),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(invoicesProvider.notifier).voidInvoice(latest.id);
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(foregroundColor: AppTheme.terracotta),
          child: const Text('Void'),
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
