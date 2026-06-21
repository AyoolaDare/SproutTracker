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
    required this.cashPosition,
    required this.moneyOwed,
    required this.businessHealthScore,
    required this.businessHealthSummary,
    required this.todaysPriorities,
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
  final CashPositionSummary cashPosition;
  final MoneyOwedSummary moneyOwed;
  final int businessHealthScore;
  final String businessHealthSummary;
  final List<DashboardPriority> todaysPriorities;
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
    final priorities = (data['todays_priorities'] as List? ?? [])
        .map((e) => DashboardPriority.fromJson(e as Map<String, dynamic>))
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
      cashPosition: CashPositionSummary.fromJson(
        (data['cash_position'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      moneyOwed: MoneyOwedSummary.fromJson(
        (data['money_owed'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      businessHealthScore: (data['business_health_score'] as num? ?? 0).toInt(),
      businessHealthSummary: data['business_health_summary'] as String? ?? 'Set up',
      todaysPriorities: priorities,
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
      cashPosition: const CashPositionSummary(
        cashOnHand: 85000,
        bankBalance: 420000,
        total: 505000,
      ),
      moneyOwed: MoneyOwedSummary(
        total: state.invoices.fold(0, (s, i) => s + i.amountDue.toDouble()),
        count: state.invoices.where((i) => i.amountDue > 0).length,
        aging: const {},
        topDebtors: const [],
      ),
      businessHealthScore: 74,
      businessHealthSummary: 'Watch closely',
      todaysPriorities: [
        const DashboardPriority(
          type: 'receivables',
          title: 'Follow up unpaid invoices',
          detail: 'Collect money owed before creating new credit sales',
          severity: 'medium',
        ),
        if (state.inventory.any((i) => i.quantity <= i.reorderLevel))
          const DashboardPriority(
            type: 'inventory',
            title: 'Restock low inventory',
            detail: 'Some products are at or below reorder level',
            severity: 'medium',
          ),
        const DashboardPriority(
          type: 'cash',
          title: 'Update cash position',
          detail: 'Confirm today cash and bank balance',
          severity: 'low',
        ),
      ].take(3).toList(),
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

class CashPositionSummary {
  const CashPositionSummary({
    required this.cashOnHand,
    required this.bankBalance,
    required this.total,
    this.recordedAt,
  });

  final double cashOnHand;
  final double bankBalance;
  final double total;
  final DateTime? recordedAt;

  factory CashPositionSummary.fromJson(Map<String, dynamic> j) {
    final recorded = j['recorded_at'] as String?;
    return CashPositionSummary(
      cashOnHand: DashboardMetrics._d(j['cash_on_hand']),
      bankBalance: DashboardMetrics._d(j['bank_balance']),
      total: DashboardMetrics._d(j['total']),
      recordedAt: recorded == null ? null : DateTime.tryParse(recorded),
    );
  }
}

class MoneyOwedSummary {
  const MoneyOwedSummary({
    required this.total,
    required this.count,
    required this.aging,
    required this.topDebtors,
  });

  final double total;
  final int count;
  final Map<String, double> aging;
  final List<TopDebtor> topDebtors;

  factory MoneyOwedSummary.fromJson(Map<String, dynamic> j) {
    final agingRaw = (j['aging'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MoneyOwedSummary(
      total: DashboardMetrics._d(j['total']),
      count: (j['count'] as num? ?? 0).toInt(),
      aging: agingRaw.map((key, value) => MapEntry(key, DashboardMetrics._d(value))),
      topDebtors: (j['top_debtors'] as List? ?? [])
          .map((e) => TopDebtor.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TopDebtor {
  const TopDebtor({
    required this.customerName,
    required this.amount,
    required this.oldestDaysOverdue,
  });

  final String customerName;
  final double amount;
  final int oldestDaysOverdue;

  factory TopDebtor.fromJson(Map<String, dynamic> j) => TopDebtor(
        customerName: j['customer_name'] as String? ?? 'Customer',
        amount: DashboardMetrics._d(j['amount']),
        oldestDaysOverdue: (j['oldest_days_overdue'] as num? ?? 0).toInt(),
      );
}

class DashboardPriority {
  const DashboardPriority({
    required this.type,
    required this.title,
    required this.detail,
    required this.severity,
  });

  final String type;
  final String title;
  final String detail;
  final String severity;

  factory DashboardPriority.fromJson(Map<String, dynamic> j) => DashboardPriority(
        type: j['type'] as String? ?? 'task',
        title: j['title'] as String? ?? 'Review business activity',
        detail: j['detail'] as String? ?? '',
        severity: j['severity'] as String? ?? 'low',
      );
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
