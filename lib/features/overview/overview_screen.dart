import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/router.dart';
import '../../shared/widgets/async_value_view.dart';
import '../../shared/widgets/common.dart';
import 'overview.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(overviewProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(overviewProvider.future),
        child: AsyncValueView(
          value: overview,
          onRetry: () => ref.invalidate(overviewProvider),
          data: (o) => PageBody(
            maxWidth: 1100,
            children: [
              _KpiGrid(totals: o.totals),
              SectionCard(
                title: 'Sign-ups',
                subtitle: 'New accounts per day, last 30 days',
                child: SizedBox(height: 220, child: SignupsChart(points: o.signups)),
              ),
              SectionCard(
                title: 'Users per app',
                subtitle: 'Total, new and active in the last 30 days',
                child: _AppUsageList(apps: o.apps),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.totals});
  final OverviewTotals totals;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Kpi('Active users', totals.activeUsers, Icons.person_outline),
      _Kpi('Sign-ups (30 d)', totals.signups30d, Icons.person_add_alt),
      _Kpi('Active sessions (30 d)', totals.activeSessions30d, Icons.devices_outlined),
      _Kpi('Suspended', totals.suspendedUsers, Icons.block),
      _Kpi('Apps', totals.apps, Icons.apps_outlined),
      _Kpi('Clients', totals.clients, Icons.key_outlined),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 900 ? 6 : (c.maxWidth >= 560 ? 3 : 2);
        const gap = 12.0;
        final width = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon);
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(formatCount(value), style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daily sign-ups as a line chart.
class SignupsChart extends StatelessWidget {
  const SignupsChart({super.key, required this.points});
  final List<DailySignups> points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    if (points.isEmpty) return const EmptyView(title: 'No data yet', icon: Icons.show_chart);
    final maxY = points.map((p) => p.signups).fold<int>(0, math.max);
    final top = maxY == 0 ? 4.0 : (maxY * 1.2).ceilToDouble();
    final interval = math.max(1, (top / 4).ceil()).toDouble();
    final dayFormat = DateFormat.MMMd();
    final total = points.fold<int>(0, (a, p) => a + p.signups);

    return Semantics(
      label: 'Sign-ups chart: $total sign-ups over ${points.length} days, peak $maxY in a day',
      excludeSemantics: true,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: top,
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: interval,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(v.toInt().toString(), style: text),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 7,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(dayFormat.format(points[i].day), style: text),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${dayFormat.format(points[s.x.toInt()].day)}\n${s.y.toInt()} sign-ups',
                    TextStyle(color: scheme.onInverseSurface),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].signups.toDouble())],
              isCurved: true,
              preventCurveOverShooting: true,
              color: scheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: scheme.primary.withValues(alpha: 0.12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppUsageList extends StatelessWidget {
  const _AppUsageList({required this.apps});
  final List<AppUsage> apps;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const EmptyView(title: 'No apps yet', icon: Icons.apps_outlined);
    final theme = Theme.of(context);
    final maxUsers = apps.map((a) => a.users).fold<int>(1, math.max);
    return Column(
      children: [
        for (final a in apps)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(a.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: a.users / maxUsers,
                    minHeight: 6,
                    semanticsLabel: '${a.name} share of users',
                  ),
                ),
                const SizedBox(height: 6),
                Text('${formatCount(a.new30d)} new · ${formatCount(a.active30d)} active (30 d)'),
              ],
            ),
            trailing: Text(formatCount(a.users), style: theme.textTheme.titleMedium),
            onTap: () => context.go(Routes.app(a.slug)),
          ),
      ],
    );
  }
}
