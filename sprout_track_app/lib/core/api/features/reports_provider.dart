import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_provider.dart';
import '../../state/sprout_state.dart';
import '../api_client.dart';

// ── P&L ───────────────────────────────────────────────────────────────────────

class ProfitLossReport {
  const ProfitLossReport({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.grossMarginPct,
    required this.netMarginPct,
    required this.expensesByCategory,
    required this.vatProvision,
    required this.citProvision,
  });

  final double revenue;
  final double cogs;
  final double grossProfit;
  final double totalExpenses;
  final double netProfit;
  final double grossMarginPct;
  final double netMarginPct;
  final Map<String, double> expensesByCategory;
  final double vatProvision;
  final double citProvision;

  factory ProfitLossReport.fromApi(Map<String, dynamic> j) {
    final cats = <String, double>{};
    (j['expenses_by_category'] as Map<String, dynamic>? ?? {})
        .forEach((k, v) => cats[k] = (v as num).toDouble());
    return ProfitLossReport(
      revenue:             _d(j['revenue']),
      cogs:                _d(j['cogs']),
      grossProfit:         _d(j['gross_profit']),
      totalExpenses:       _d(j['total_expenses']),
      netProfit:           _d(j['net_profit']),
      grossMarginPct:      _d(j['gross_margin_pct']),
      netMarginPct:        _d(j['net_margin_pct']),
      expensesByCategory:  cats,
      vatProvision:        _d(j['vat_provision']),
      citProvision:        _d(j['cit_provision']),
    );
  }

  factory ProfitLossReport.fromLocal(SproutState s) {
    final revenue = s.invoices
        .where((i) => i.derivedStatus == InvoiceStatus.paid)
        .fold<double>(0, (sum, i) => sum + (i.amountPaid == 0 ? i.amount : i.amountPaid).toDouble());
    final totalExpenses = s.expenses.fold<double>(0, (sum, e) => sum + e.amount.toDouble());
    final netProfit = revenue - totalExpenses;
    final cats = <String, double>{};
    for (final e in s.expenses) {
      cats[e.category] = (cats[e.category] ?? 0) + e.amount.toDouble();
    }
    return ProfitLossReport(
      revenue:            revenue,
      cogs:               0,
      grossProfit:        revenue,
      totalExpenses:      totalExpenses,
      netProfit:          netProfit,
      grossMarginPct:     revenue == 0 ? 0 : 100,
      netMarginPct:       revenue == 0 ? 0 : (netProfit / revenue) * 100,
      expensesByCategory: cats,
      vatProvision:       revenue * 0.075,
      citProvision:       netProfit > 0 ? netProfit * 0.2 : 0,
    );
  }

  static double _d(dynamic v) => (v as num? ?? 0).toDouble();
}

// ── VAT return ────────────────────────────────────────────────────────────────

class VatReport {
  const VatReport({
    required this.outputVat,
    required this.inputVat,
    required this.netVatPayable,
    required this.filingDueDate,
    required this.month,
    required this.year,
  });

  final double outputVat;
  final double inputVat;
  final double netVatPayable;
  final String filingDueDate;
  final int    month;
  final int    year;

  factory VatReport.fromApi(Map<String, dynamic> j) => VatReport(
        outputVat:    (j['output_vat'] as num? ?? 0).toDouble(),
        inputVat:     (j['input_vat'] as num? ?? 0).toDouble(),
        netVatPayable:(j['net_vat_payable'] as num? ?? 0).toDouble(),
        filingDueDate: j['filing_due_date'] as String? ?? '',
        month:         (j['month'] as num? ?? 1).toInt(),
        year:          (j['year'] as num? ?? DateTime.now().year).toInt(),
      );

  factory VatReport.fromLocal(SproutState s) {
    final now = DateTime.now();
    final outputVat = s.invoices
        .where((i) => i.derivedStatus == InvoiceStatus.paid)
        .fold<double>(0, (sum, i) => sum + i.vatAmount.toDouble());
    return VatReport(
      outputVat:     outputVat,
      inputVat:      0,
      netVatPayable: outputVat,
      filingDueDate: '21st of next month',
      month:         now.month,
      year:          now.year,
    );
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

final profitLossProvider = FutureProvider.autoDispose.family<ProfitLossReport, DateRange>(
  (ref, range) async {
    final isDemo = ref.watch(authProvider).isDemo;
    if (isDemo) {
      return ProfitLossReport.fromLocal(ref.watch(sproutStoreProvider));
    }
    final res = await ref.watch(apiClientProvider).get(
      '/api/reports/profit-loss',
      query: {'start_date': range.start, 'end_date': range.end},
    );
    return ProfitLossReport.fromApi(res.data as Map<String, dynamic>);
  },
);

final vatReportProvider = FutureProvider.autoDispose.family<VatReport, MonthYear>(
  (ref, my) async {
    final isDemo = ref.watch(authProvider).isDemo;
    if (isDemo) {
      return VatReport.fromLocal(ref.watch(sproutStoreProvider));
    }
    final res = await ref.watch(apiClientProvider).get(
      '/api/reports/vat',
      query: {'month': my.month, 'year': my.year},
    );
    return VatReport.fromApi(res.data as Map<String, dynamic>);
  },
);

// ── Parameter types ────────────────────────────────────────────────────────────

class DateRange {
  const DateRange({required this.start, required this.end});
  final String start;
  final String end;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class MonthYear {
  const MonthYear({required this.month, required this.year});
  final int month;
  final int year;

  @override
  bool operator ==(Object other) =>
      other is MonthYear && other.month == month && other.year == year;

  @override
  int get hashCode => Object.hash(month, year);
}
