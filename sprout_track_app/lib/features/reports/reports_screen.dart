import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../core/state/sprout_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(sproutStoreProvider);
    final months   = _monthlyReport(state);

    final revenue    = state.invoices
        .where((i) => i.derivedStatus == InvoiceStatus.paid)
        .fold<num>(0, (s, i) => s + i.amountPaid);
    final expenses   = state.expenses.fold<num>(0, (s, e) => s + e.amount);
    final profit     = revenue - expenses;
    final margin     = revenue == 0 ? 0.0 : (profit / revenue) * 100;
    final stockValue = state.inventory.fold<num>(0, (s, i) => s + i.stockValue);
    final lowStock   = state.inventory.where((i) => i.isLowStock).length;
    final outstanding = state.invoices.fold<num>(0, (s, i) => s + i.amountDue);

    final scheme = Theme.of(context).colorScheme;

    return SproutPage(
      title: 'Reports',
      subtitle: 'Revenue, expenses, profit margin, cash flow, and inventory health.',
      action: FilledButton.icon(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF export connects to the backend report generator.')),
        ),
        icon: const Icon(Icons.ios_share_rounded, size: 18),
        label: const Text('Export PDF'),
      ),
      children: [
        // ── KPI cards ─────────────────────────────────────────────────────────
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            mainAxisExtent: 100,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          children: [
            _MetricCard('Revenue',     compactMoney(revenue),    AppTheme.moss,       Icons.trending_up_rounded),
            _MetricCard('Expenses',    compactMoney(expenses),   AppTheme.terracotta, Icons.trending_down_rounded),
            _MetricCard('Net profit',  compactMoney(profit),     profit >= 0 ? AppTheme.moss : AppTheme.terracotta, Icons.account_balance_rounded),
            _MetricCard('Margin',      '${margin.toStringAsFixed(1)}%', AppTheme.ochre, Icons.percent_rounded),
            _MetricCard('Stock value', compactMoney(stockValue), AppTheme.sage,       Icons.inventory_2_rounded),
            _MetricCard('Outstanding', compactMoney(outstanding),outstanding > 0 ? AppTheme.ochre : AppTheme.moss, Icons.pending_actions_rounded),
            _MetricCard('Low stock',   '$lowStock items',         lowStock > 0 ? AppTheme.terracotta : AppTheme.moss, Icons.warning_amber_rounded),
          ],
        ),
        const SizedBox(height: 20),

        // ── P&L bar chart ─────────────────────────────────────────────────────
        SproutCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Profit & loss',
                trailing: Row(
                  children: [
                    _LegendDot(color: AppTheme.moss,       label: 'Revenue'),
                    const SizedBox(width: 14),
                    _LegendDot(color: AppTheme.terracotta, label: 'Expenses'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Monthly breakdown — last 6 months (₦ millions)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 280,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: 0.5,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: scheme.outlineVariant.withValues(alpha: .4),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles:   const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          interval: 0.5,
                          getTitlesWidget: (v, _) {
                            final axisStyle = GoogleFonts.epilogue(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            );
                            return Text(
                              v == 0 ? '0' : '${v.toStringAsFixed(1)}M',
                              style: axisStyle,
                              textAlign: TextAlign.right,
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= months.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                months[i].label,
                                style: GoogleFonts.epilogue(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        tooltipRoundedRadius: 10,
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        getTooltipItem: (group, _, rod, rodIndex) {
                          final lbl = rodIndex == 0 ? 'Revenue' : 'Expenses';
                          return BarTooltipItem(
                            '$lbl\n₦${(rod.toY * 1000000).toStringAsFixed(0)}',
                            GoogleFonts.epilogue(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          );
                        },
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
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                            BarChartRodData(
                              toY: months[i].expenses / 1000000,
                              width: 13,
                              color: AppTheme.terracotta,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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

// ── Metric card ────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.accentColor, this.icon);
  final String   label;
  final String   value;
  final Color    accentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SproutCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
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

// ── Chart legend dot ───────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color  color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

// ── Monthly data helper ────────────────────────────────────────────────────────

class MonthReport {
  const MonthReport(this.label, this.income, this.expenses);
  final String label;
  final num    income;
  final num    expenses;
}

List<MonthReport> _monthlyReport(SproutState state) {
  final now = DateTime.now();
  return [
    for (var i = 5; i >= 0; i--)
      () {
        final m = DateTime(now.year, now.month - i);
        bool same(DateTime d) => d.year == m.year && d.month == m.month;
        final inc = state.invoices
            .where((inv) => inv.derivedStatus == InvoiceStatus.paid && same(inv.issueDate))
            .fold<num>(0, (s, inv) => s + inv.amountPaid);
        final exp = state.expenses
            .where((e) => same(e.date))
            .fold<num>(0, (s, e) => s + e.amount);
        return MonthReport(DateFormat('MMM').format(m), inc, exp);
      }(),
  ];
}
