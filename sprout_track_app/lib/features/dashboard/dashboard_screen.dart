import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../app/app_theme.dart';
import '../../core/api/features/dashboard_provider.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/sprout_card.dart';
import '../../shared/widgets/sprout_page.dart';
import '../../shared/widgets/status_pill.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardProvider);
    final bp           = ResponsiveBreakpoints.of(context);
    final isMobile     = bp.isMobile;
    final metricCols   = isMobile ? 1 : (bp.isTablet ? 2 : 4);

    return SproutPage(
      title: 'Business overview',
      subtitle: 'Cash, stock, debtors, and profit signals in one operating view.',
      action: FilledButton.icon(
        onPressed: () => context.go('/invoices'),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('New invoice'),
      ),
      children: [
        metricsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Could not load dashboard: $e',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
          data: (m) {
            final metrics = [
              _MetricData('Revenue',     m.revenueThisMonth,  m.revenueChangePct,  _MetricKind.cashIn),
              _MetricData('Expenses',    m.expensesThisMonth, m.expensesChangePct, _MetricKind.cashOut),
              _MetricData('Net profit',  m.netProfit,         m.profitMargin,      _MetricKind.neutral),
              _MetricData('Outstanding', m.outstandingBalance,
                m.outstandingBalance == 0 ? 0.0
                    : -(m.outstandingBalance / (m.stockValue == 0 ? 1 : m.stockValue) * 100).clamp(0.0, 100.0),
                _MetricKind.neutral,
              ),
            ];
            final cashFlow = m.monthlyCashFlow
                .map((p) => _CashFlowPoint(p.month, p.income / 1000000, p.expenses / 1000000))
                .toList();
            return Column(
              children: [
                _TwoColumnLayout(
                  threshold: 980,
                  leftFlex: 7,
                  rightFlex: 5,
                  left: _TwoColumnLayout(
                    threshold: 640,
                    left: _BusinessHealthCard(
                      score: m.businessHealthScore,
                      summary: m.businessHealthSummary,
                    ),
                    right: _CashPositionCard(position: m.cashPosition),
                  ),
                  right: _PriorityCard(priorities: m.todaysPriorities),
                ),
                const SizedBox(height: 14),
                _MoneyOwedCard(summary: m.moneyOwed),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: metrics.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: metricCols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: isMobile ? 96 : 124,
                  ),
                  itemBuilder: (context, i) => _MetricTile(metrics[i]),
                ),
                const SizedBox(height: 14),
                _TwoColumnLayout(
                  threshold: 860,
                  leftFlex: 7,
                  rightFlex: 5,
                  left: _CashFlowCard(points: cashFlow),
                  right: _HealthCard(
                    lowStockCount: m.lowStockCount,
                    stockValue:    m.stockValue,
                  ),
                ),
                const SizedBox(height: 14),
                _TwoColumnLayout(
                  threshold: 860,
                  left: _InvoiceActivity(invoices: m.recentInvoices),
                  right: _ExpenseActivity(expenses: m.recentExpenses),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Two-column adaptive layout ─────────────────────────────────────────────────

class _BusinessHealthCard extends StatelessWidget {
  const _BusinessHealthCard({
    required this.score,
    required this.summary,
  });

  final int score;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final color = score >= 80
        ? AppTheme.moss
        : (score >= 60 ? AppTheme.ochre : AppTheme.terracotta);
    final gaugeSize = isMobile ? 82.0 : 96.0;

    return SproutCard(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: isMobile ? 132 : 168),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _HealthGauge(
                        size: gaugeSize,
                        score: score,
                        color: color,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: _HealthSummary(score: score, summary: summary)),
                    ],
                  ),
                ],
              )
            : Row(
          children: [
            _HealthGauge(
              size: gaugeSize,
              score: score,
              color: color,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            const SizedBox(width: 16),
            Expanded(child: _HealthSummary(score: score, summary: summary)),
          ],
        ),
      ),
    );
  }
}

class _HealthGauge extends StatelessWidget {
  const _HealthGauge({
    required this.size,
    required this.score,
    required this.color,
    required this.backgroundColor,
  });

  final double size;
  final int score;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score.clamp(0, 100) / 100,
            strokeWidth: size <= 84 ? 7 : 9,
            backgroundColor: backgroundColor,
            color: color,
          ),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$score',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthSummary extends StatelessWidget {
  const _HealthSummary({required this.score, required this.summary});

  final int score;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business health',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          summary,
          maxLines: ResponsiveBreakpoints.of(context).isMobile ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.25,
              ),
        ),
        const SizedBox(height: 12),
        StatusPill(score >= 80 ? 'Strong' : (score >= 60 ? 'Watch' : 'Action needed')),
      ],
    );
  }
}

class _CashPositionCard extends StatelessWidget {
  const _CashPositionCard({required this.position});
  final CashPositionSummary position;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    return SproutCard(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: isMobile ? 144 : 168),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SectionHeader(
              title: 'Cash position',
              trailing: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.moss),
            ),
            SizedBox(height: isMobile ? 12 : 18),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                compactMoney(position.total),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
              ),
            ),
            SizedBox(height: isMobile ? 14 : 18),
            Row(
              children: [
                Expanded(child: _MiniMoney(label: 'Cash', value: position.cashOnHand)),
                const SizedBox(width: 10),
                Expanded(child: _MiniMoney(label: 'Bank', value: position.bankBalance)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMoney extends StatelessWidget {
  const _MiniMoney({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              compactMoney(value),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.priorities});
  final List<DashboardPriority> priorities;

  @override
  Widget build(BuildContext context) {
    final items = priorities.isEmpty
        ? const [
            DashboardPriority(
              type: 'setup',
              title: 'Create your first activity',
              detail: 'Add an invoice, product, or expense to unlock guidance',
              severity: 'low',
            ),
          ]
        : priorities;
    return SproutCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 168),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: '3 things today'),
            const SizedBox(height: 8),
            for (var index = 0; index < math.min(items.length, 3); index++) ...[
              if (index > 0) const SizedBox(height: 9),
              Builder(
                builder: (context) {
                  final item = items[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_priorityIcon(item.type), size: 18, color: _priorityColor(item.severity)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              item.detail,
                              maxLines: ResponsiveBreakpoints.of(context).isMobile ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _priorityIcon(String type) => switch (type) {
        'receivables' => Icons.call_rounded,
        'inventory' => Icons.inventory_2_rounded,
        'budget' => Icons.receipt_long_rounded,
        'cash' => Icons.account_balance_wallet_rounded,
        _ => Icons.check_circle_rounded,
      };

  static Color _priorityColor(String severity) => switch (severity) {
        'high' => AppTheme.terracotta,
        'medium' => AppTheme.ochre,
        _ => AppTheme.moss,
      };
}

class _MoneyOwedCard extends StatelessWidget {
  const _MoneyOwedCard({required this.summary});
  final MoneyOwedSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final buckets = [
      ('Current', summary.aging['current'] ?? 0),
      ('1-30', summary.aging['1_30'] ?? 0),
      ('31-60', summary.aging['31_60'] ?? 0),
      ('61-90', summary.aging['61_90'] ?? 0),
      ('90+', summary.aging['90_plus'] ?? 0),
    ];
    return SproutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Money owed',
            trailing: Text(
              '${summary.count} open',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              compactMoney(summary.total),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final children = buckets
                  .map((b) => _AgingBucket(label: b.$1, value: b.$2))
                  .toList();
              if (box.maxWidth < 620) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: children,
                );
              }
              return Row(
                children: children
                    .map((w) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: w,
                          ),
                        ),)
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AgingBucket extends StatelessWidget {
  const _AgingBucket({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                compactMoney(value),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                            fontSize: ResponsiveBreakpoints.of(context).isMobile ? 18 : 20,
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
  const _HealthCard({required this.lowStockCount, required this.stockValue});
  final int    lowStockCount;
  final double stockValue;

  @override
  Widget build(BuildContext context) {
    final arcColor = lowStockCount == 0 ? AppTheme.moss
        : lowStockCount <= 3 ? AppTheme.ochre
        : AppTheme.terracotta;
    final status   = lowStockCount == 0 ? 'Good' : lowStockCount <= 3 ? 'Fair' : 'Critical';
    final progress = lowStockCount == 0 ? 1.0 : lowStockCount <= 3 ? 0.55 : 0.25;

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
                        status,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: arcColor,
                            ),
                      ),
                      Text(
                        compactMoney(stockValue),
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
                icon: Icons.inventory_2_outlined,
                label: 'Stock value',
                color: AppTheme.moss,
              ),
              const SizedBox(width: 10),
              _HealthChip(
                icon: Icons.warning_amber_rounded,
                label: '$lowStockCount low stock',
                color: lowStockCount > 0 ? AppTheme.terracotta : AppTheme.moss,
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
  final List<RecentInvoice> invoices;

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
  final RecentInvoice invoice;

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
                compactMoney(invoice.totalAmount),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              StatusPill(invoice.status),
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
  final List<RecentExpense> expenses;

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
  final RecentExpense expense;

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
