import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sproutStoreProvider);
    final months = _monthlyReport(state);
    final revenue = state.invoices
        .where((invoice) => invoice.derivedStatus == InvoiceStatus.paid)
        .fold<num>(0, (sum, invoice) => sum + invoice.amountPaid);
    final expenses = state.expenses.fold<num>(0, (sum, expense) => sum + expense.amount);
    final profit = revenue - expenses;
    final margin = revenue == 0 ? 0 : (profit / revenue) * 100;
    final stockValue = state.inventory.fold<num>(0, (sum, item) => sum + item.stockValue);
    final lowStock = state.inventory.where((item) => item.isLowStock).length;

    return SproutPage(
      title: 'Reports',
      subtitle: 'Revenue, expenses, profit margin, cash flow, and inventory health.',
      action: FilledButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF export will connect to the backend report generator.')),
          );
        },
        icon: const Icon(Icons.ios_share_rounded),
        label: const Text('Export PDF'),
      ),
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            mainAxisExtent: 106,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          children: [
            _ReportMetric('Revenue', compactMoney(revenue)),
            _ReportMetric('Expenses', compactMoney(expenses)),
            _ReportMetric('Profit', compactMoney(profit)),
            _ReportMetric('Margin', '${margin.toStringAsFixed(1)}%'),
            _ReportMetric('Stock value', compactMoney(stockValue)),
            _ReportMetric('Low stock', '$lowStock items'),
          ],
        ),
        const SizedBox(height: 18),
        SproutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profit and loss',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 290,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: AppTheme.clay.withValues(alpha: .2),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= months.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(months[index].label),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < months.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 5,
                          barRods: [
                            BarChartRodData(
                              toY: months[i].income / 1000000,
                              width: 13,
                              color: AppTheme.moss,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            BarChartRodData(
                              toY: months[i].expenses / 1000000,
                              width: 13,
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
        ),
      ],
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class MonthReport {
  const MonthReport(this.label, this.income, this.expenses);
  final String label;
  final num income;
  final num expenses;
}

List<MonthReport> _monthlyReport(SproutState state) {
  final now = DateTime.now();
  return [
    for (var i = 5; i >= 0; i--)
      (() {
        final month = DateTime(now.year, now.month - i);
        bool sameMonth(DateTime value) => value.year == month.year && value.month == month.month;
        final income = state.invoices
            .where((invoice) => invoice.derivedStatus == InvoiceStatus.paid && sameMonth(invoice.issueDate))
            .fold<num>(0, (sum, invoice) => sum + invoice.amountPaid);
        final expenses = state.expenses
            .where((expense) => sameMonth(expense.date))
            .fold<num>(0, (sum, expense) => sum + expense.amount);
        return MonthReport(DateFormat('MMM').format(month), income, expenses);
      })(),
  ];
}
