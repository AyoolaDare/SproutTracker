import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/api/features/invoices_provider.dart';
import '../../core/api/features/settings_provider.dart';

// Brand palette — fractional RGB from hex
const _moss    = PdfColor(0.376, 0.424, 0.220); // #606C38
const _ink     = PdfColor(0.137, 0.153, 0.102); // #23271A
const _sand    = PdfColor(0.949, 0.929, 0.882); // #F2EDE1
const _clay    = PdfColor(0.690, 0.545, 0.431); // #B08B6E
const _altRow  = PdfColor(0.973, 0.961, 0.941); // #F8F5F0
const _green   = PdfColor(0.176, 0.529, 0.200); // paid status
const _terra   = PdfColor(0.776, 0.420, 0.239); // #C66B3D pending
const _divider = PdfColor(0.875, 0.847, 0.800);

/// Builds a lightweight branded PDF invoice or receipt (~20–40 KB).
/// Uses standard PDF fonts so no font data is embedded.
Future<Uint8List> buildInvoicePdf(
  ApiInvoice invoice,
  ApiBusinessProfile profile,
) async {
  final doc  = pw.Document(compress: true);
  final bold = pw.Font.helveticaBold();
  final reg  = pw.Font.helvetica();

  final isReceipt = invoice.isPaid;
  final docLabel  = isReceipt ? 'RECEIPT' : 'INVOICE';

  // NGN prefix — Naira sign (₦ U+20A6) is outside Helvetica Latin-1, use "NGN"
  String ngn(num n) =>
      NumberFormat.currency(locale: 'en_NG', symbol: 'NGN ', decimalDigits: 0)
          .format(n);
  String fmtDate(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _banner(invoice, profile, bold, reg, docLabel),
          _statusRibbon(isReceipt, bold),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(42, 26, 42, 22),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _billingHeader(invoice, bold, reg, isReceipt, fmtDate),
                  pw.SizedBox(height: 22),
                  _itemsTable(invoice, bold, reg, ngn),
                  pw.SizedBox(height: 14),
                  _totalsBox(invoice, bold, reg, isReceipt, ngn),
                  pw.Spacer(),
                  _footer(profile, bold, reg),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

// ── Section builders ────────────────────────────────────────────────────────

pw.Widget _banner(
  ApiInvoice invoice,
  ApiBusinessProfile profile,
  pw.Font bold,
  pw.Font reg,
  String docLabel,
) =>
    pw.Container(
      width: double.infinity,
      color: _moss,
      padding: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 26),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Flexible(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  profile.businessName,
                  style: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 21),
                ),
                if ((profile.address ?? '').isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(
                    profile.address!,
                    style: pw.TextStyle(font: reg, color: _sand, fontSize: 9),
                  ),
                ],
                if ((profile.phone ?? '').isNotEmpty ||
                    (profile.email ?? '').isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    [
                      if ((profile.phone ?? '').isNotEmpty) profile.phone!,
                      if ((profile.email ?? '').isNotEmpty) profile.email!,
                    ].join('   |   '),
                    style: pw.TextStyle(font: reg, color: _sand, fontSize: 9),
                  ),
                ],
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                docLabel,
                style: pw.TextStyle(
                  font: bold,
                  color: PdfColors.white,
                  fontSize: 28,
                  letterSpacing: 4,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                invoice.invoiceNumber,
                style: pw.TextStyle(font: bold, color: _clay, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );

pw.Widget _statusRibbon(bool isReceipt, pw.Font bold) => pw.Container(
      width: double.infinity,
      color: isReceipt ? _green : _terra,
      padding: const pw.EdgeInsets.symmetric(horizontal: 42, vertical: 5),
      child: pw.Text(
        isReceipt ? 'FULLY PAID' : 'PAYMENT PENDING',
        style: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 8.5, letterSpacing: 2),
      ),
    );

pw.Widget _billingHeader(
  ApiInvoice invoice,
  pw.Font bold,
  pw.Font reg,
  bool isReceipt,
  String Function(DateTime) fmtDate,
) =>
    pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BILLED TO',
                style: pw.TextStyle(font: bold, color: _moss, fontSize: 7.5, letterSpacing: 2),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                invoice.customerName,
                style: pw.TextStyle(font: bold, color: _ink, fontSize: 14),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _metaRow('Invoice No', invoice.invoiceNumber, bold, reg),
            _metaRow('Date Issued', fmtDate(invoice.invoiceDate), bold, reg),
            if (!isReceipt) _metaRow('Due Date', fmtDate(invoice.dueDate), bold, reg),
          ],
        ),
      ],
    );

pw.Widget _itemsTable(
  ApiInvoice invoice,
  pw.Font bold,
  pw.Font reg,
  String Function(num) ngn,
) =>
    pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FixedColumnWidth(50),
        2: const pw.FixedColumnWidth(100),
        3: const pw.FixedColumnWidth(100),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _moss),
          children: [
            _th('ITEM', bold, pw.TextAlign.left),
            _th('QTY', bold, pw.TextAlign.center),
            _th('UNIT PRICE', bold, pw.TextAlign.right),
            _th('TOTAL', bold, pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < invoice.lineItems.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _altRow),
            children: [
              _td(invoice.lineItems[i].productName, reg, _ink),
              _td('${invoice.lineItems[i].quantity}', reg, _ink, align: pw.TextAlign.center),
              _td(ngn(invoice.lineItems[i].unitPrice), reg, _ink, align: pw.TextAlign.right),
              _td(ngn(invoice.lineItems[i].lineTotal), bold, _ink, align: pw.TextAlign.right),
            ],
          ),
      ],
    );

pw.Widget _totalsBox(
  ApiInvoice invoice,
  pw.Font bold,
  pw.Font reg,
  bool isReceipt,
  String Function(num) ngn,
) =>
    pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 265,
        child: pw.Column(
          children: [
            if (invoice.vatAmount > 0) ...[
              _totRow('Subtotal', ngn(invoice.subtotal), reg, _ink),
              _totRow('VAT (7.5%)', ngn(invoice.vatAmount), reg, _ink),
            ],
            pw.Divider(color: _clay, thickness: 0.7),
            _totRow('TOTAL', ngn(invoice.totalAmount), bold, _ink, bigger: true),
            if (isReceipt && invoice.amountPaid > 0)
              _totRow('Amount Paid', ngn(invoice.amountPaid), bold, _green),
            if (!isReceipt) ...[
              if (invoice.amountPaid > 0)
                _totRow('Amount Paid', ngn(invoice.amountPaid), reg, _ink),
              if (invoice.amountDue > 0) ...[
                pw.Divider(color: _clay, thickness: 0.7),
                _totRow('BALANCE DUE', ngn(invoice.amountDue), bold, _terra, bigger: true),
              ],
            ],
          ],
        ),
      ),
    );

pw.Widget _footer(ApiBusinessProfile profile, pw.Font bold, pw.Font reg) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: _divider, thickness: 0.5),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if ((profile.bankName ?? '').isNotEmpty || (profile.accountNumber ?? '').isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAYMENT DETAILS',
                    style: pw.TextStyle(font: bold, color: _moss, fontSize: 7, letterSpacing: 1.5),
                  ),
                  pw.SizedBox(height: 3),
                  if ((profile.bankName ?? '').isNotEmpty)
                    pw.Text(
                      'Bank: ${profile.bankName!}',
                      style: pw.TextStyle(font: reg, color: _ink, fontSize: 8.5),
                    ),
                  if ((profile.accountNumber ?? '').isNotEmpty)
                    pw.Text(
                      'Account: ${profile.accountNumber!}',
                      style: pw.TextStyle(font: reg, color: _ink, fontSize: 8.5),
                    ),
                  if ((profile.accountName ?? '').isNotEmpty)
                    pw.Text(
                      'Name: ${profile.accountName!}',
                      style: pw.TextStyle(font: reg, color: _ink, fontSize: 8.5),
                    ),
                ],
              )
            else
              pw.SizedBox(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Thank you for your business.',
                  style: pw.TextStyle(font: bold, color: _moss, fontSize: 11),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Powered by Sprout Track',
                  style: pw.TextStyle(font: reg, color: _clay, fontSize: 7.5),
                ),
              ],
            ),
          ],
        ),
      ],
    );

// ── Micro helpers ───────────────────────────────────────────────────────────

pw.Widget _metaRow(String label, String value, pw.Font bold, pw.Font reg) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label  ',
            style: pw.TextStyle(font: bold, color: _moss, fontSize: 8, letterSpacing: 0.3),
          ),
          pw.Text(value, style: pw.TextStyle(font: reg, color: _ink, fontSize: 8.5)),
        ],
      ),
    );

pw.Widget _th(String text, pw.Font bold, pw.TextAlign align) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: bold, color: PdfColors.white, fontSize: 8, letterSpacing: 1),
      ),
    );

pw.Widget _td(String text, pw.Font font, PdfColor color, {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, color: color, fontSize: 9.5),
      ),
    );

pw.Widget _totRow(
  String label,
  String value,
  pw.Font font,
  PdfColor color, {
  bool bigger = false,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, color: color, fontSize: bigger ? 11 : 9.5)),
          pw.Text(value, style: pw.TextStyle(font: font, color: color, fontSize: bigger ? 11 : 9.5)),
        ],
      ),
    );
