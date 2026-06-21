import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                      money(invoice.totalAmount),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    StatusPill(invoice.displayStatus),
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

// ── Discount mode (mutually exclusive) ────────────────────────────────────────

enum _DiscountMode { none, lineItem, invoiceLevel }

// ── Per-line-item mutable state ────────────────────────────────────────────────

class _LineItemData {
  String? productId;
  final TextEditingController desc  = TextEditingController();
  final TextEditingController qty   = TextEditingController(text: '1');
  final TextEditingController price = TextEditingController();
  final TextEditingController disc  = TextEditingController(text: '0');
  bool discPct = true;

  double get grossAmt {
    final q = double.tryParse(qty.text) ?? 0;
    final p = double.tryParse(price.text) ?? 0;
    return q * p;
  }

  double get discountAmt {
    final d = double.tryParse(disc.text) ?? 0;
    return discPct ? grossAmt * d / 100 : d.clamp(0, grossAmt);
  }

  double get netAmt => grossAmt - discountAmt;

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

  // Discount
  _DiscountMode _discMode   = _DiscountMode.none;
  bool          _invDiscPct = true;
  final         _invDisc    = TextEditingController(text: '0');

  // VAT
  bool _applyVat   = false;
  bool _vatPerLine = false;

  bool _saving = false;

  @override
  void dispose() {
    for (final item in _lineItems) {
      item.dispose();
    }
    _custName.dispose();
    _custPhone.dispose();
    _custEmail.dispose();
    _invDisc.dispose();
    super.dispose();
  }

  // ── Computed totals ───────────────────────────────────────────────────────────

  double get _grossSubtotal => _lineItems.fold(0.0, (s, i) => s + i.grossAmt);

  double get _totalLineDiscount =>
      _discMode == _DiscountMode.lineItem
          ? _lineItems.fold(0.0, (s, i) => s + i.discountAmt)
          : 0;

  double get _invoiceDiscountAmt {
    if (_discMode != _DiscountMode.invoiceLevel) return 0;
    final d = double.tryParse(_invDisc.text) ?? 0;
    return _invDiscPct
        ? _grossSubtotal * d / 100
        : d.clamp(0, _grossSubtotal);
  }

  double get _taxableAmt =>
      _grossSubtotal - _totalLineDiscount - _invoiceDiscountAmt;

  double get _vatAmt => _applyVat ? _taxableAmt * 0.075 : 0;

  double get _grandTotal => _taxableAmt + _vatAmt;

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final customers  = ref.watch(customersProvider).valueOrNull ?? const <ApiCustomer>[];
    final products   = ref.watch(productsProvider).valueOrNull ?? const <ApiProduct>[];
    final scheme     = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        );

    return AlertDialog(
      title: const Text('Create invoice'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Customer ──────────────────────────────────────────────────
              Text('Customer', style: labelStyle),
              const SizedBox(height: 8),
              if (!_newCust) ...[
                DropdownButtonFormField<ApiCustomer>(
                  initialValue: _customer,
                  items: [
                    for (final c in customers)
                      DropdownMenuItem(
                        value: c,
                        child: Text(c.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _customer = v),
                  decoration: const InputDecoration(
                    labelText: 'Select existing customer',
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _newCust  = true;
                      _customer = null;
                    }),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Create new customer'),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _custName,
                        decoration: const InputDecoration(
                          labelText: 'Customer name *',
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _newCust = false),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Select existing instead'),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ── Discount type (mutually exclusive) ────────────────────────
              Text('Discount', style: labelStyle),
              const SizedBox(height: 8),
              SegmentedButton<_DiscountMode>(
                segments: const [
                  ButtonSegment(
                    value: _DiscountMode.none,
                    label: Text('None'),
                  ),
                  ButtonSegment(
                    value: _DiscountMode.lineItem,
                    label: Text('Per line item'),
                  ),
                  ButtonSegment(
                    value: _DiscountMode.invoiceLevel,
                    label: Text('Invoice total'),
                  ),
                ],
                selected: {_discMode},
                onSelectionChanged: (s) => setState(() => _discMode = s.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(height: 20),

              // ── Line items ────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: Text('Line items', style: labelStyle)),
                  TextButton.icon(
                    onPressed: () => setState(() => _lineItems.add(_LineItemData())),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add item'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var idx = 0; idx < _lineItems.length; idx++)
                _buildLineItemCard(
                  context: context,
                  idx: idx,
                  item: _lineItems[idx],
                  products: products,
                  scheme: scheme,
                ),

              // ── Invoice-level discount input ───────────────────────────────
              if (_discMode == _DiscountMode.invoiceLevel) ...[
                const SizedBox(height: 4),
                Text('Invoice discount', style: labelStyle),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _DiscToggle(
                      isPercent: _invDiscPct,
                      onToggle: (v) => setState(() => _invDiscPct = v),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _invDisc,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _invDiscPct ? 'Discount (%)' : 'Discount (₦)',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ── VAT ───────────────────────────────────────────────────────
              SwitchListTile(
                value: _applyVat,
                onChanged: (v) => setState(() => _applyVat = v),
                title: Text(
                  _applyVat
                      ? 'VAT (7.5%) — ${money(_vatAmt)}'
                      : 'Include VAT (7.5%)',
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              if (_applyVat) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Charge VAT on:',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      ChoiceChip(
                        label: const Text('Subtotal'),
                        selected: !_vatPerLine,
                        onSelected: (_) => setState(() => _vatPerLine = false),
                        visualDensity: VisualDensity.compact,
                      ),
                      ChoiceChip(
                        label: const Text('Per line item'),
                        selected: _vatPerLine,
                        onSelected: (_) => setState(() => _vatPerLine = true),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],

              // ── Totals summary ────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: .5),
                  ),
                ),
                child: Column(
                  children: [
                    _TotRow(
                      label: 'Subtotal',
                      value: money(_grossSubtotal),
                    ),
                    if (_discMode == _DiscountMode.lineItem &&
                        _totalLineDiscount > 0)
                      _TotRow(
                        label: 'Line discounts',
                        value: '−${money(_totalLineDiscount)}',
                        dimColor: AppTheme.terracotta,
                      ),
                    if (_discMode == _DiscountMode.invoiceLevel &&
                        _invoiceDiscountAmt > 0)
                      _TotRow(
                        label: 'Invoice discount',
                        value: '−${money(_invoiceDiscountAmt)}',
                        dimColor: AppTheme.terracotta,
                      ),
                    if ((_totalLineDiscount + _invoiceDiscountAmt) > 0)
                      _TotRow(
                        label: 'Taxable amount',
                        value: money(_taxableAmt),
                      ),
                    if (_applyVat)
                      _TotRow(
                        label: 'VAT (7.5%)',
                        value: money(_vatAmt),
                      ),
                    const Divider(height: 12),
                    _TotRow(
                      label: 'TOTAL',
                      value: money(_grandTotal),
                      emphasized: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create invoice'),
        ),
      ],
    );
  }

  Widget _buildLineItemCard({
    required BuildContext context,
    required int idx,
    required _LineItemData item,
    required List<ApiProduct> products,
    required ColorScheme scheme,
  }) {
    final showDisc = _discMode == _DiscountMode.lineItem;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: item.productId,
                  items: [
                    for (final p in products)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name}  (${p.currentStock} in stock)'),
                      ),
                  ],
                  onChanged: (val) {
                    final p = products.firstWhere((e) => e.id == val);
                    setState(() {
                      item.productId  = val;
                      item.desc.text  = p.name;
                      item.price.text = p.sellingPrice.toString();
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Product (optional)',
                    isDense: true,
                  ),
                ),
              ),
              if (_lineItems.length > 1) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () {
                    _lineItems[idx].dispose();
                    setState(() => _lineItems.removeAt(idx));
                  },
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: AppTheme.terracotta,
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: item.desc,
            decoration: const InputDecoration(
              labelText: 'Description',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 68,
                child: TextField(
                  controller: item.qty,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: item.price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Unit price (₦)',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (showDisc) ...[
                const SizedBox(width: 8),
                _DiscToggle(
                  isPercent: item.discPct,
                  onToggle: (v) => setState(() => item.discPct = v),
                  compact: true,
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 76,
                  child: TextField(
                    controller: item.disc,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: item.discPct ? 'Disc %' : 'Disc ₦',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(item.netAmt),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (showDisc && item.discountAmt > 0)
                      Text(
                        '−${money(item.discountAmt)}',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.terracotta,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
            if (_discMode == _DiscountMode.lineItem) ...{
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
            applyVat:    _applyVat,
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

// ── Discount type toggle (% ↔ ₦) ──────────────────────────────────────────────

class _DiscToggle extends StatelessWidget {
  const _DiscToggle({
    required this.isPercent,
    required this.onToggle,
    this.compact = false,
  });

  final bool isPercent;
  final void Function(bool) onToggle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!isPercent),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: AppTheme.moss.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.moss.withValues(alpha: .3)),
        ),
        child: Text(
          isPercent ? '%' : '₦',
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.moss,
          ),
        ),
      ),
    );
  }
}

// ── Invoice totals row ─────────────────────────────────────────────────────────

class _TotRow extends StatelessWidget {
  const _TotRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.dimColor,
  });

  final String label;
  final String value;
  final bool   emphasized;
  final Color? dimColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: emphasized ? FontWeight.w900 : FontWeight.w500,
          fontSize:   emphasized ? 15 : null,
          color:      dimColor,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
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
