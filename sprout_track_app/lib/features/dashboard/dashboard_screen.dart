import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final data       = ref.watch(sproutStoreProvider);
    final bp         = ResponsiveBreakpoints.of(context);
    final isMobile   = bp.isMobile;
    final metricCols = isMobile ? 2 : (bp.isTablet ? 2 : 4);

    final paidInvoices  = data.invoices.where((i) => i.derivedStatus == InvoiceStatus.paid);
    final totalRevenue  = paidInvoices.fold<num>(0, (s, i) => s + (i.amountPaid == 0 ? i.amount : i.amountPaid));
    final totalExpenses = data.expenses.fold<num>(0, (s, e) => s + e.amount);
    final netProfit     = totalRevenue - totalExpenses;
    final stockValue    = data.inventory.fold<num>(0, (s, i) => s + i.stockValue);
    final outstanding   = data.invoices.fold<num>(0, (s, i) => s + i.amountDue);

    final profitMargin = totalRevenue == 0 ? 0.0 : (netProfit / totalRevenue) * 100;

    final metrics = [
      _MetricData('Revenue',    totalRevenue,  18.4,  _MetricKind.cashIn),
      _MetricData('Expenses',   totalExpenses, -6.2,  _MetricKind.cashOut),
      _MetricData('Net profit', netProfit,     profitMargin, _MetricKind.neutral),
      _MetricData('Stock value', stockValue, outstanding == 0 ? 0.0 : -(outstanding / stockValue * 100).clamp(0.0, 100.0).toDouble(), _MetricKind.neutral),
    ];

    final cashFlow = _monthlyCashFlow(data);

    return SproutPage(
      title: 'Business overview',
      subtitle: 'Cash, stock, debtors, and profit signals in one operating view.',
      action: FilledButton.icon(
        onPressed: () => context.go('/invoices'),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('New invoice'),
      ),
      children: [
        // ── KPI tiles ──────────────────────────────────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metricCols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: isMobile ? 110 : 124,
          ),
          itemBuilder: (context, i) => _MetricTile(metrics[i]),
        ),
        const SizedBox(height: 14),

        // ── Cash flow + inventory health ────────────────────────────────────
        _TwoColumnLayout(
          threshold: 860,
          leftFlex: 7,
          rightFlex: 5,
          left: _CashFlowCard(points: cashFlow),
          right: _HealthCard(items: data.inventory),
        ),
        const SizedBox(height: 14),

        // ── Recent activity ─────────────────────────────────────────────────
        _TwoColumnLayout(
          threshold: 860,
          left: _InvoiceActivity(invoices: data.invoices.take(5).toList()),
          right: _ExpenseActivity(expenses: data.expenses.take(5).toList()),
        ),
      ],
    );
  }
}

// ── Two-column adaptive layout ─────────────────────────────────────────────────

class _TwoColumnLayout extends StatelessWidget {
  const _TwoColumnLayout({
    required this.left,
    required this.right,
    this.threshold = 860,
    this.leftFlex  = 1,
    this.rightFlex = 1,
  });
  final Widget left;
  final Widget right;
  final double threshold;
  final int    leftFlex;
  final int    rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth <= threshold) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 14), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: 14),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}

// ── Metric tile ────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.metric);
  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    final positive     = metric.delta >= 0;
    final scheme       = Theme.of(context).colorScheme;
    final valueText    = compactMoney(metric.value);
    final deltaColor   = positive ? AppTheme.moss : AppTheme.terracotta;
    final accentColor  = switch (metric.kind) {
      _MetricKind.cashIn  => AppTheme.moss,
      _MetricKind.cashOut => AppTheme.terracotta,
      _MetricKind.neutral => AppTheme.ochre,
    };

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
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          metric.label,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      Icon(
                        positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 18,
                        color: deltaColor,
                      ),
                    ],
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      valueText,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: scheme.onSurface,
                          ),
                    ),
                  ),
                  Text(
                    '${positive ? '+' : ''}${metric.delta.toStringAsFixed(1)}%  this month',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: deltaColor,
                          fontWeight: FontWeight.w700,
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

// ── Cash flow chart card ───────────────────────────────────────────────────────

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.points});
  final List<_CashFlowPoint> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final axisStyle = GoogleFonts.epilogue(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
    );

    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Cash flow',
            trailing: Row(
              children: [
                _LegendDot(color: AppTheme.moss,       label: 'Income'),
                const SizedBox(width: 14),
                _LegendDot(color: AppTheme.terracotta, label: 'Expenses'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monthly income vs. operating spend — last 6 months (₦ millions)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
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
                      getTitlesWidget: (v, _) => Text(
                        v == 0 ? '0' : '${v.toStringAsFixed(1)}M',
                        style: axisStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= points.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(points[i].month, style: axisStyle),
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
                      final lbl = rodIndex == 0 ? 'Income' : 'Expenses';
                      final val = rod.toY;
                      return BarTooltipItem(
                        '$lbl\n₦${(val * 1000000).toStringAsFixed(0)}',
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
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barsSpace: 5,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].income,
                          width: 13,
                          color: AppTheme.moss,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                        BarChartRodData(
                          toY: points[i].expenses,
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
    );
  }
}

// ── Inventory health card ──────────────────────────────────────────────────────

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.items});
  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final total    = items.length;
    final healthy  = items.where((e) => e.quantity > e.reorderLevel).length;
    final lowStock = total - healthy;
    final progress = total == 0 ? 0.0 : healthy / total;
    final pct      = (progress * 100).round();

    final arcColor = pct >= 70 ? AppTheme.moss : pct >= 40 ? AppTheme.ochre : AppTheme.terracotta;
    final status   = pct >= 70 ? 'Good' : pct >= 40 ? 'Fair' : 'Critical';

    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Inventory health'),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: CustomPaint(
                painter: _HealthArcPainter(progress: progress, color: arcColor),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$pct%',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: arcColor,
                            ),
                      ),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _HealthChip(
                icon: Icons.check_circle_outline_rounded,
                label: '$healthy of $total healthy',
                color: AppTheme.moss,
              ),
              const SizedBox(width: 10),
              _HealthChip(
                icon: Icons.warning_amber_rounded,
                label: '$lowStock low stock',
                color: lowStock > 0 ? AppTheme.terracotta : AppTheme.moss,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Health arc custom painter ──────────────────────────────────────────────────

class _HealthArcPainter extends CustomPainter {
  _HealthArcPainter({required this.progress, required this.color});
  final double progress;
  final Color  color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 14;
    const stroke = 20.0;

    final trackPaint = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round
      ..strokeWidth = stroke
      ..color      = color.withValues(alpha: .12);

    final arcPaint = Paint()
      ..style      = PaintingStyle.stroke
      ..strokeCap  = StrokeCap.round
      ..strokeWidth = stroke
      ..color      = color;

    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HealthArcPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Recent invoice activity ────────────────────────────────────────────────────

class _InvoiceActivity extends StatelessWidget {
  const _InvoiceActivity({required this.invoices});
  final List<Invoice> invoices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Recent invoices',
            trailing: TextButton(
              onPressed: () => context.go('/invoices'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View all',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.moss,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No invoices yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          else
            for (var idx = 0; idx < invoices.length; idx++) ...[
              if (idx > 0)
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .45)),
              _InvoiceRow(invoices[idx]),
            ],
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow(this.invoice);
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long_rounded, size: 18, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  invoice.invoiceNumber,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                compactMoney(invoice.amount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              StatusPill(invoice.derivedStatus.label),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Recent expense activity ────────────────────────────────────────────────────

class _ExpenseActivity extends StatelessWidget {
  const _ExpenseActivity({required this.expenses});
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Expense watchlist',
            trailing: TextButton(
              onPressed: () => context.go('/expenses'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View all',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.moss,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No expenses recorded',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          else
            for (var idx = 0; idx < expenses.length; idx++) ...[
              if (idx > 0)
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .45)),
              _ExpenseRow(expenses[idx]),
            ],
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow(this.expense);
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.terracotta.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppTheme.terracotta),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  expense.category,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            compactMoney(expense.amount),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.terracotta,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Shared legend dot ──────────────────────────────────────────────────────────

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
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

// ── Data models ────────────────────────────────────────────────────────────────

enum _MetricKind { cashIn, cashOut, neutral }

class _MetricData {
  const _MetricData(this.label, this.value, this.delta, this.kind);
  final String      label;
  final num         value;
  final double      delta;
  final _MetricKind kind;
}

class _CashFlowPoint {
  const _CashFlowPoint(this.month, this.income, this.expenses);
  final String month;
  final double income;    // in millions
  final double expenses;  // in millions
}

List<_CashFlowPoint> _monthlyCashFlow(SproutState state) {
  final now = DateTime.now();
  return [
    for (var i = 5; i >= 0; i--)
      () {
        final m = DateTime(now.year, now.month - i);
        bool same(DateTime d) => d.year == m.year && d.month == m.month;
        final inc = state.invoices
            .where((inv) => inv.derivedStatus == InvoiceStatus.paid && same(inv.issueDate))
            .fold<num>(0, (s, inv) => s + (inv.amountPaid == 0 ? inv.amount : inv.amountPaid));
        final exp = state.expenses
            .where((e) => same(e.date))
            .fold<num>(0, (s, e) => s + e.amount);
        return _CashFlowPoint(DateFormat('MMM').format(m), inc / 1000000, exp / 1000000);
      }(),
  ];
}

