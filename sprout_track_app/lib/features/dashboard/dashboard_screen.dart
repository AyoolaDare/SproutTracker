import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../app/app_theme.dart';
import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';
import '../../shared/widgets/status_pill.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sproutStoreProvider);
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isMobile = breakpoints.isMobile;
    final metricColumns = isMobile ? 1 : (breakpoints.isTablet ? 2 : 4);
    final paidInvoices = data.invoices.where((invoice) => invoice.derivedStatus == InvoiceStatus.paid);
    final totalRevenue = paidInvoices.fold<num>(0, (sum, invoice) => sum + (invoice.amountPaid == 0 ? invoice.amount : invoice.amountPaid));
    final totalExpenses = data.expenses.fold<num>(0, (sum, expense) => sum + expense.amount);
    final netProfit = totalRevenue - totalExpenses;
    final stockValue = data.inventory.fold<num>(0, (sum, item) => sum + item.stockValue);
    final outstanding = data.invoices.fold<num>(0, (sum, invoice) => sum + invoice.amountDue);
    final metrics = [
      MetricViewData('Revenue', totalRevenue, 18.4, MetricKind.money),
      MetricViewData('Expenses', totalExpenses, -6.2, MetricKind.money),
      MetricViewData('Net Profit', netProfit, totalRevenue == 0 ? 0 : (netProfit / totalRevenue) * 100, MetricKind.money),
      MetricViewData('Stock Value', stockValue, outstanding == 0 ? 0 : outstanding / 10000, MetricKind.money),
    ];
    final cashFlow = _monthlyCashFlow(data);

    return SproutPage(
      title: 'Business overview',
      subtitle: 'Cash, stock, debtors, and profit signals in one operating view.',
      action: FilledButton.icon(
        onPressed: () => context.go('/invoices'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create invoice'),
      ),
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metricColumns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: isMobile ? 118 : 132,
          ),
          itemBuilder: (context, index) => _MetricTile(metrics[index]),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth > 900;
            final cashFlowCard = _CashFlowCard(points: cashFlow);
            final health = _HealthCard(items: data.inventory);
            if (!twoColumn) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cashFlowCard,
                  const SizedBox(height: 18),
                  health,
                ],
              );
            }
            return Flex(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: cashFlowCard,
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 5,
                  child: health,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumn = constraints.maxWidth > 900;
            final invoices = _InvoiceActivity(invoices: data.invoices.take(5).toList());
            final expenses = _ExpenseActivity(expenses: data.expenses.take(5).toList());
            if (!twoColumn) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  invoices,
                  const SizedBox(height: 18),
                  expenses,
                ],
              );
            }
            return Flex(
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: invoices,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: expenses,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.metric);

  final MetricViewData metric;

  @override
  Widget build(BuildContext context) {
    final positive = metric.delta >= 0;
    final value = metric.kind == MetricKind.money
        ? compactMoney(metric.value)
        : '${metric.value.toStringAsFixed(0)}%';

    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Icon(
                positive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: positive ? AppTheme.moss : AppTheme.terracotta,
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${positive ? '+' : ''}${metric.delta.toStringAsFixed(1)}% this month',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: positive ? AppTheme.moss : AppTheme.terracotta,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.points});

  final List<CashFlowViewPoint> points;

  @override
  Widget build(BuildContext context) {
    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Cash flow rhythm'),
          const SizedBox(height: 8),
          Text(
            'Income is staying ahead of operating spend across the last six months.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(points[index].month),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 6,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].income,
                          width: 14,
                          color: AppTheme.moss,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        BarChartRodData(
                          toY: points[i].expenses,
                          width: 14,
                          color: AppTheme.terracotta,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final average = items.isEmpty
        ? 0
        : items.map((e) => e.quantity <= e.reorderLevel ? 35 : 90).reduce((a, b) => a + b) / items.length;
    final lowStock = items.where((e) => e.quantity <= e.reorderLevel).length;

    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Inventory health'),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: CustomPaint(
                painter: GrowthRingPainter(progress: average / 100),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${average.round()}%',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        'stock healthy',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HealthChip(
                icon: Icons.inventory_2_rounded,
                label: '${items.length} SKUs tracked',
              ),
              const SizedBox(width: 10),
              _HealthChip(
                icon: Icons.warning_amber_rounded,
                label: '$lowStock low stock',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.sage.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GrowthRingPainter extends CustomPainter {
  GrowthRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 16;

    for (var i = 0; i < 4; i++) {
      final ringRadius = radius - 12 - i * 22;
      canvas.drawCircle(
        center,
        ringRadius,
        basePaint..color = AppTheme.clay.withValues(alpha: .16 + i * .03),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        -math.pi / 2,
        math.pi * 2 * progress * (1 - i * .08),
        false,
        basePaint
          ..color = [
            AppTheme.moss,
            AppTheme.sage,
            AppTheme.ochre,
            AppTheme.terracotta,
          ][i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant GrowthRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _InvoiceActivity extends StatelessWidget {
  const _InvoiceActivity({required this.invoices});

  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Recent invoices'),
          const SizedBox(height: 14),
          for (final invoice in invoices) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(invoice.customerName),
              subtitle: Text(invoice.invoiceNumber),
              trailing: SizedBox(
                width: 112,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        compactMoney(invoice.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusPill(invoice.derivedStatus.label),
                  ],
                ),
              ),
            ),
            if (invoice != invoices.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ExpenseActivity extends StatelessWidget {
  const _ExpenseActivity({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Expense watchlist'),
          const SizedBox(height: 14),
          for (final expense in expenses) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppTheme.terracotta.withValues(alpha: .14),
                child: const Icon(Icons.account_balance_wallet_rounded),
              ),
              title: Text(expense.description),
              subtitle: Text(expense.category),
              trailing: SizedBox(
                width: 92,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    compactMoney(expense.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            if (expense != expenses.last) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

enum MetricKind { money, percent }

class MetricViewData {
  const MetricViewData(this.label, this.value, this.delta, this.kind);
  final String label;
  final num value;
  final double delta;
  final MetricKind kind;
}

class CashFlowViewPoint {
  const CashFlowViewPoint(this.month, this.income, this.expenses);
  final String month;
  final double income;
  final double expenses;
}

List<CashFlowViewPoint> _monthlyCashFlow(SproutState state) {
  final now = DateTime.now();
  final result = <CashFlowViewPoint>[];
  for (var i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i);
    final monthName = DateFormat('MMM').format(month);
    bool sameMonth(DateTime value) => value.year == month.year && value.month == month.month;
    final income = state.invoices
        .where((invoice) => invoice.derivedStatus == InvoiceStatus.paid && sameMonth(invoice.issueDate))
        .fold<num>(0, (sum, invoice) => sum + (invoice.amountPaid == 0 ? invoice.amount : invoice.amountPaid));
    final expenses = state.expenses
        .where((expense) => sameMonth(expense.date))
        .fold<num>(0, (sum, expense) => sum + expense.amount);
    result.add(CashFlowViewPoint(monthName, income / 1000000, expenses / 1000000));
  }
  return result;
}
