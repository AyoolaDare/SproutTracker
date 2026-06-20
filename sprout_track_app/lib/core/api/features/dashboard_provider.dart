import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_provider.dart';
import '../../state/sprout_state.dart';
import '../api_client.dart';

class DashboardMetrics {
  const DashboardMetrics({
    required this.revenueThisMonth,
    required this.expensesThisMonth,
    required this.netProfit,
    required this.outstandingBalance,
    required this.stockValue,
    required this.lowStockCount,
    required this.revenueLastMonth,
    required this.expensesLastMonth,
    required this.monthlyCashFlow,
    required this.recentInvoices,
    required this.recentExpenses,
  });

  final double revenueThisMonth;
  final double expensesThisMonth;
  final double netProfit;
  final double outstandingBalance;
  final double stockValue;
  final int    lowStockCount;
  final double revenueLastMonth;
  final double expensesLastMonth;
  final List<MonthlyCashFlowPoint> monthlyCashFlow;
  final List<RecentInvoice>        recentInvoices;
  final List<RecentExpense>        recentExpenses;

  double get profitMargin =>
      revenueThisMonth == 0 ? 0 : (netProfit / revenueThisMonth) * 100;

  double get revenueChangePct => revenueLastMonth == 0
      ? 0
      : ((revenueThisMonth - revenueLastMonth) / revenueLastMonth) * 100;

  double get expensesChangePct => expensesLastMonth == 0
      ? 0
      : ((expensesThisMonth - expensesLastMonth) / expensesLastMonth) * 100;

  factory DashboardMetrics.fromApi(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;
    final cashFlow = ((data['monthly_cash_flow'] ?? data['cash_flow']) as List? ?? [])
        .map((e) => MonthlyCashFlowPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    final invoices = (data['recent_invoices'] as List? ?? [])
        .map((e) => RecentInvoice.fromJson(e as Map<String, dynamic>))
        .toList();
    final expenses = (data['recent_expenses'] as List? ?? [])
        .map((e) => RecentExpense.fromJson(e as Map<String, dynamic>))
        .toList();
    final lowStockAlerts = (data['low_stock_alerts'] as List? ?? []);
    return DashboardMetrics(
      revenueThisMonth:  _d(data['revenue_this_month']),
      expensesThisMonth: _d(data['expenses_this_month']),
      netProfit:         _d(data['net_profit']),
      outstandingBalance: _d(data['outstanding_balance'] ?? data['outstanding_invoices']),
      stockValue:        _d(data['stock_value'] ?? data['inventory_value']),
      lowStockCount:     (data['low_stock_count'] as num? ?? lowStockAlerts.length).toInt(),
      revenueLastMonth:  _d(data['revenue_last_month']),
      expensesLastMonth: _d(data['expenses_last_month']),
      monthlyCashFlow:   cashFlow,
      recentInvoices:    invoices,
      recentExpenses:    expenses,
    );
  }

  factory DashboardMetrics.fromLocal(SproutState state) {
    final now   = DateTime.now();
    bool sameMonth(DateTime d, int monthOffset) {
      final m = DateTime(now.year, now.month + monthOffset);
      return d.year == m.year && d.month == m.month;
    }

    final paidInvoices = state.invoices
        .where((i) => i.derivedStatus == InvoiceStatus.paid);

    final revThisMonth = paidInvoices
        .where((i) => sameMonth(i.issueDate, 0))
        .fold<double>(0, (s, i) => s + (i.amountPaid == 0 ? i.amount : i.amountPaid).toDouble());

    final expThisMonth = state.expenses
        .where((e) => sameMonth(e.date, 0))
        .fold<double>(0, (s, e) => s + e.amount.toDouble());

    final revLastMonth = paidInvoices
        .where((i) => sameMonth(i.issueDate, -1))
        .fold<double>(0, (s, i) => s + (i.amountPaid == 0 ? i.amount : i.amountPaid).toDouble());

    final expLastMonth = state.expenses
        .where((e) => sameMonth(e.date, -1))
        .fold<double>(0, (s, e) => s + e.amount.toDouble());

    final cashFlow = <MonthlyCashFlowPoint>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      bool sm(DateTime d) => d.year == m.year && d.month == m.month;
      final inc = paidInvoices
          .where((inv) => sm(inv.issueDate))
          .fold<double>(0, (s, inv) => s + (inv.amountPaid == 0 ? inv.amount : inv.amountPaid).toDouble());
      final exp = state.expenses
          .where((e) => sm(e.date))
          .fold<double>(0, (s, e) => s + e.amount.toDouble());
      cashFlow.add(MonthlyCashFlowPoint(
        month: _monthAbbr(m.month),
        income: inc,
        expenses: exp,
      ),);
    }

    return DashboardMetrics(
      revenueThisMonth:   revThisMonth,
      expensesThisMonth:  expThisMonth,
      netProfit:          revThisMonth - expThisMonth,
      outstandingBalance: state.invoices.fold(0, (s, i) => s + i.amountDue.toDouble()),
      stockValue:         state.inventory.fold(0, (s, i) => s + i.stockValue.toDouble()),
      lowStockCount:      state.inventory.where((i) => i.quantity <= i.reorderLevel).length,
      revenueLastMonth:   revLastMonth,
      expensesLastMonth:  expLastMonth,
      monthlyCashFlow:    cashFlow,
      recentInvoices: state.invoices.take(5).map(
        (i) => RecentInvoice(
          id:            i.id,
          invoiceNumber: i.invoiceNumber,
          customerName:  i.customerName,
          totalAmount:   i.amount.toDouble(),
          status:        i.derivedStatus.label,
          paymentStatus: i.derivedStatus == InvoiceStatus.paid ? 'PAID' : 'UNPAID',
        ),
      ).toList(),
      recentExpenses: state.expenses.take(5).map(
        (e) => RecentExpense(
          id:          e.id,
          description: e.description,
          amount:      e.amount.toDouble(),
          category:    e.category,
        ),
      ).toList(),
    );
  }

  static double _d(dynamic v) => (v as num? ?? 0).toDouble();
  static String _monthAbbr(int m) =>
      const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

class MonthlyCashFlowPoint {
  const MonthlyCashFlowPoint({
    required this.month,
    required this.income,
    required this.expenses,
  });
  final String month;
  final double income;
  final double expenses;

  factory MonthlyCashFlowPoint.fromJson(Map<String, dynamic> j) =>
      MonthlyCashFlowPoint(
        month:    j['month'] as String? ?? '',
        income:   ((j['income'] ?? j['inflow']) as num? ?? 0).toDouble(),
        expenses: ((j['expenses'] ?? j['outflow']) as num? ?? 0).toDouble(),
      );
}

class RecentInvoice {
  const RecentInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
  });
  final String id;
  final String invoiceNumber;
  final String customerName;
  final double totalAmount;
  final String status;
  final String paymentStatus;

  factory RecentInvoice.fromJson(Map<String, dynamic> j) => RecentInvoice(
        id:            j['id'] as String? ?? '',
        invoiceNumber: j['invoice_number'] as String? ?? '',
        customerName:  j['customer_name'] as String? ?? '',
        totalAmount:   (j['total_amount'] as num? ?? 0).toDouble(),
        status:        j['status'] as String? ?? '',
        paymentStatus: j['payment_status'] as String? ?? '',
      );
}

class RecentExpense {
  const RecentExpense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
  });
  final String id;
  final String description;
  final double amount;
  final String category;

  factory RecentExpense.fromJson(Map<String, dynamic> j) => RecentExpense(
        id:          j['id'] as String? ?? '',
        description: j['description'] as String? ?? '',
        amount:      (j['amount'] as num? ?? 0).toDouble(),
        category:    j['category'] as String? ?? '',
      );
}

// ── Provider ───────────────────────────────────────────────────────────────────

final dashboardProvider = FutureProvider.autoDispose<DashboardMetrics>((ref) async {
  final isDemo = ref.watch(authProvider).isDemo;
  if (isDemo) {
    return DashboardMetrics.fromLocal(ref.watch(sproutStoreProvider));
  }
  final res = await ref.watch(apiClientProvider).get('/api/dashboard/metrics');
  return DashboardMetrics.fromApi(res.data as Map<String, dynamic>);
});
