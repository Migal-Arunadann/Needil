import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/analytics_provider.dart';

// ─── Color palette for charts ────────────────────────────────────────────────
const _kCompleted = Color(0xFF10B981);
const _kScheduled = Color(0xFF3B82F6);
const _kCancelled = Color(0xFFEF4444);
const _kMissed = Color(0xFFF59E0B);
const _kPrimary = AppColors.primary;
const _kAccent = Color(0xFF8B5CF6);

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: data.isLoading
            ? const _LoadingView()
            : RefreshIndicator(
                color: _kPrimary,
                onRefresh: () => ref.read(analyticsProvider.notifier).load(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _AnalyticsAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 8),
                          // ── KPI Row 1 ──────────────────────────────
                          _KpiRow(data: data),
                          const SizedBox(height: 16),
                          // ── Today's Snapshot ───────────────────────
                          _SectionHeader(
                            icon: Icons.today_rounded,
                            title: "Today's Snapshot",
                          ),
                          const SizedBox(height: 10),
                          _TodaySnapshotRow(data: data),
                          const SizedBox(height: 20),
                          // ── 7-Day Activity Chart ───────────────────
                          _SectionHeader(
                            icon: Icons.bar_chart_rounded,
                            title: '7-Day Activity',
                          ),
                          const SizedBox(height: 10),
                          _WeeklyBarChart(data: data),
                          const SizedBox(height: 20),
                          // ── Peak Hours ─────────────────────────────
                          _SectionHeader(
                            icon: Icons.access_time_rounded,
                            title: 'Appointment Volume by Hour',
                          ),
                          const SizedBox(height: 10),
                          _HourlyHeatBar(data: data),
                          const SizedBox(height: 8),
                          _PeakInsightRow(data: data),
                          const SizedBox(height: 20),
                          // ── Appointment Type Split ─────────────────
                          _SectionHeader(
                            icon: Icons.pie_chart_rounded,
                            title: 'Appointment Type Split',
                          ),
                          const SizedBox(height: 10),
                          _TypeSplitRow(data: data),
                          const SizedBox(height: 20),
                          // ── Session Performance ────────────────────
                          _SectionHeader(
                            icon: Icons.healing_rounded,
                            title: 'Session Performance',
                          ),
                          const SizedBox(height: 10),
                          _SessionPerformanceRow(data: data),
                          const SizedBox(height: 20),
                          // ── Plan Conversion ────────────────────────
                          _SectionHeader(
                            icon: Icons.assignment_turned_in_rounded,
                            title: 'Consultation → Treatment Plan Conversion',
                          ),
                          const SizedBox(height: 10),
                          _PlanConversionCard(data: data),
                          const SizedBox(height: 20),
                          // ── Patient Demographics ───────────────────
                          _SectionHeader(
                            icon: Icons.people_rounded,
                            title: 'Patient Demographics',
                          ),
                          const SizedBox(height: 10),
                          _DemographicsRow(data: data),
                          const SizedBox(height: 20),
                          // ── Geographic Distribution ────────────────
                          _SectionHeader(
                            icon: Icons.location_on_rounded,
                            title: 'Patient Locations',
                          ),
                          const SizedBox(height: 10),
                          _LocationCard(data: data),
                          const SizedBox(height: 20),
                          // ── Completion Rate ────────────────────────
                          _SectionHeader(
                            icon: Icons.speed_rounded,
                            title: 'Overall Performance',
                          ),
                          const SizedBox(height: 10),
                          _PerformanceMetricsCard(data: data),
                          const SizedBox(height: 8),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Last 30 days · Live data',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kPrimary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading view
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _kPrimary),
          SizedBox(height: 16),
          Text(
            'Loading analytics…',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Row
// ─────────────────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final AnalyticsData data;
  const _KpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.4, // Changed from 1.7 to afford more height on narrow phones
      children: [
        _KpiCard(
          label: 'Total Patients',
          value: '${data.totalPatients}',
          icon: Icons.people_rounded,
          color: _kPrimary,
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          ),
        ),
        _KpiCard(
          label: 'Appointments (30d)',
          value: '${data.totalAppointments}',
          icon: Icons.calendar_month_rounded,
          color: _kAccent,
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
          ),
        ),
        _KpiCard(
          label: 'Completed',
          value: '${data.completedAppointments}',
          icon: Icons.check_circle_rounded,
          color: _kCompleted,
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF34D399)],
          ),
        ),
        _KpiCard(
          label: 'Active Plans',
          value: '${data.activeTreatmentPlans}',
          icon: Icons.assignment_rounded,
          color: _kMissed,
          gradient: const LinearGradient(
            colors: [Color(0xFFD97706), Color(0xFFFBBF24)],
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's Snapshot
// ─────────────────────────────────────────────────────────────────────────────

class _TodaySnapshotRow extends StatelessWidget {
  final AnalyticsData data;
  const _TodaySnapshotRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _TodayTile(
            label: 'Scheduled',
            value: data.todayScheduled,
            color: _kScheduled,
            icon: Icons.schedule_rounded,
          ),
          _divider(),
          _TodayTile(
            label: 'Completed',
            value: data.todayCompleted,
            color: _kCompleted,
            icon: Icons.check_circle_outline_rounded,
          ),
          _divider(),
          _TodayTile(
            label: 'Cancelled',
            value: data.todayCancelled,
            color: _kCancelled,
            icon: Icons.cancel_outlined,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 50,
    color: AppColors.border,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _TodayTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _TodayTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7-Day Grouped Bar Chart
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final AnalyticsData data;
  const _WeeklyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = [
      ...data.weeklyScheduled,
      ...data.weeklyCompleted,
      ...data.weeklyCancelled,
    ].fold<int>(0, math.max);

    final groups = List.generate(7, (i) {
      return BarChartGroupData(
        x: i,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
            toY: data.weeklyCompleted.length > i
                ? data.weeklyCompleted[i].toDouble()
                : 0,
            color: _kCompleted,
            width: 7,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: data.weeklyScheduled.length > i
                ? data.weeklyScheduled[i].toDouble()
                : 0,
            color: _kScheduled,
            width: 7,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: data.weeklyCancelled.length > i
                ? data.weeklyCancelled[i].toDouble()
                : 0,
            color: _kCancelled,
            width: 7,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Wrap(
            spacing: 16,
            children: [
              _Legend(color: _kCompleted, label: 'Completed'),
              _Legend(color: _kScheduled, label: 'Scheduled'),
              _Legend(color: _kCancelled, label: 'Cancelled'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxVal + 2).toDouble(),
                barGroups: groups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.weeklyDayLabels.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            data.weeklyDayLabels[i],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hourly Heat Bar
// ─────────────────────────────────────────────────────────────────────────────

class _HourlyHeatBar extends StatelessWidget {
  final AnalyticsData data;
  const _HourlyHeatBar({required this.data});

  // Clinic working hours: 8 AM – 8 PM
  static const _start = 8;
  static const _end = 20;

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(_end - _start, (i) => _start + i);
    final maxCount = hours
        .map((h) => data.hourlyDistribution[h] ?? 0)
        .fold<int>(0, math.max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: hours.map((h) {
                final count = data.hourlyDistribution[h] ?? 0;
                final ratio = maxCount == 0 ? 0.0 : count / maxCount;
                final isPeak = h == data.peakHour && maxCount > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Tooltip(
                      message:
                          '${_fmt(h)} – $count appt${count == 1 ? '' : 's'}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: Duration(
                              milliseconds: 400 + (h - _start) * 30,
                            ),
                            height: math.max(4, ratio * 44),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isPeak
                                  ? _kCancelled
                                  : ratio > 0.6
                                  ? _kPrimary
                                  : ratio > 0.3
                                  ? AppColors.primaryLight
                                  : AppColors.border,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(_start),
                style: const TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
              Text(
                _fmt((_start + _end) ~/ 2),
                style: const TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
              Text(
                _fmt(_end),
                style: const TextStyle(fontSize: 10, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int h) {
    final d = DateTime(2024, 1, 1, h);
    return DateFormat('h a').format(d);
  }
}

class _PeakInsightRow extends StatelessWidget {
  final AnalyticsData data;
  const _PeakInsightRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final peakFmt = DateFormat(
      'h a',
    ).format(DateTime(2024, 1, 1, data.peakHour));
    final lowFmt = DateFormat('h a').format(DateTime(2024, 1, 1, data.lowHour));
    return Row(
      children: [
        Expanded(
          child: _InsightChip(
            icon: Icons.trending_up_rounded,
            label: 'Peak Hour',
            value: peakFmt,
            color: _kCancelled,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _InsightChip(
            icon: Icons.trending_down_rounded,
            label: 'Quiet Hour',
            value: lowFmt,
            color: _kScheduled,
          ),
        ),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InsightChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appointment Type Split – Donut + bars
// ─────────────────────────────────────────────────────────────────────────────

class _TypeSplitRow extends StatelessWidget {
  final AnalyticsData data;
  const _TypeSplitRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.consultationCount + data.sessionAppointmentCount;
    final consultPct = total == 0 ? 0.0 : data.consultationCount / total;
    final sessionPct = total == 0 ? 0.0 : data.sessionAppointmentCount / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(
        children: [
          // Donut
          SizedBox(
            width: 120,
            height: 120,
            child: total == 0
                ? _emptyDonut()
                : PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 34,
                      sections: [
                        PieChartSectionData(
                          value: data.consultationCount.toDouble(),
                          color: _kPrimary,
                          radius: 28,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: data.sessionAppointmentCount.toDouble(),
                          color: _kAccent,
                          radius: 28,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeRow(
                  color: _kPrimary,
                  label: 'Consultations',
                  count: data.consultationCount,
                  pct: consultPct,
                ),
                const SizedBox(height: 14),
                _TypeRow(
                  color: _kAccent,
                  label: 'Sessions',
                  count: data.sessionAppointmentCount,
                  pct: sessionPct,
                ),
                const Divider(height: 20),
                Text(
                  'Total: $total',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final double pct;
  const _TypeRow({
    required this.color,
    required this.label,
    required this.count,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: AppColors.border,
          color: color,
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 2),
        Text(
          '${(pct * 100).toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 10, color: AppColors.textHint),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Performance
// ─────────────────────────────────────────────────────────────────────────────

class _SessionPerformanceRow extends StatelessWidget {
  final AnalyticsData data;
  const _SessionPerformanceRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final total =
        data.sessionsCompleted + data.sessionsMissed + data.sessionsCancelled;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            children: [
              _SessionStat(
                label: 'Completed',
                value: data.sessionsCompleted,
                total: total,
                color: _kCompleted,
              ),
              const SizedBox(width: 8),
              _SessionStat(
                label: 'Missed',
                value: data.sessionsMissed,
                total: total,
                color: _kMissed,
              ),
              const SizedBox(width: 8),
              _SessionStat(
                label: 'Cancelled',
                value: data.sessionsCancelled,
                total: total,
                color: _kCancelled,
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (data.sessionsCompleted > 0)
                      Expanded(
                        flex: data.sessionsCompleted,
                        child: Container(color: _kCompleted),
                      ),
                    if (data.sessionsMissed > 0)
                      Expanded(
                        flex: data.sessionsMissed,
                        child: Container(color: _kMissed),
                      ),
                    if (data.sessionsCancelled > 0)
                      Expanded(
                        flex: data.sessionsCancelled,
                        child: Container(color: _kCancelled),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionStat extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _SessionStat({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (total > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Conversion Card
// ─────────────────────────────────────────────────────────────────────────────

class _PlanConversionCard extends StatelessWidget {
  final AnalyticsData data;
  const _PlanConversionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = data.planConversionRate;
    final pctDisplay = (pct * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Row(
        children: [
          // Radial progress
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    strokeWidth: 10,
                    backgroundColor: AppColors.border,
                    color: _kCompleted,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$pctDisplay%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kCompleted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversion Rate',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _StatRow(
                  label: 'Total Consultations',
                  value: '${data.totalConsultations}',
                  color: _kPrimary,
                ),
                const SizedBox(height: 4),
                _StatRow(
                  label: 'With Treatment Plan',
                  value: '${data.consultationsWithPlan}',
                  color: _kCompleted,
                ),
                const SizedBox(height: 4),
                _StatRow(
                  label: 'Without Plan',
                  value:
                      '${(data.totalConsultations - data.consultationsWithPlan).clamp(0, 9999)}',
                  color: _kMissed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Demographics
// ─────────────────────────────────────────────────────────────────────────────

class _DemographicsRow extends StatelessWidget {
  final AnalyticsData data;
  const _DemographicsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _GenderDonut(data: data)),
        const SizedBox(width: 12),
        Expanded(child: _AgeGroupBars(data: data)),
      ],
    );
  }
}

class _GenderDonut extends StatelessWidget {
  final AnalyticsData data;
  const _GenderDonut({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.genderDistribution.values.fold(0, (a, b) => a + b);
    final colors = [_kPrimary, _kAccent, _kMissed];
    final entries = data.genderDistribution.entries.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        children: [
          const Text(
            'Gender',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: total == 0
                ? _emptyDonut()
                : PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 28,
                      sections: entries.asMap().entries.map((e) {
                        final idx = e.key;
                        final entry = e.value;
                        return PieChartSectionData(
                          value: entry.value.toDouble(),
                          color: colors[idx % colors.length],
                          radius: 22,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          ...entries.asMap().entries.map((e) {
            final pct = total == 0 ? 0.0 : e.value.value / total * 100;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors[e.key % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      e.value.key,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AgeGroupBars extends StatelessWidget {
  final AnalyticsData data;
  const _AgeGroupBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.ageGroupDistribution.values.fold(0, (a, b) => a + b);
    final colors = [_kAccent, _kPrimary, _kCompleted, _kMissed];
    final entries = data.ageGroupDistribution.entries.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        children: [
          const Text(
            'Age Groups',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...entries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            final pct = total == 0 ? 0.0 : entry.value / total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors[idx % colors.length],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  LinearProgressIndicator(
                    value: pct,
                    color: colors[idx % colors.length],
                    backgroundColor: AppColors.border,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Location Distribution
// ─────────────────────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final AnalyticsData data;
  const _LocationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.locationDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isEmpty ? 1 : sorted.first.value;

    if (sorted.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDeco(),
        child: const Center(
          child: Text(
            'No location data yet',
            style: TextStyle(color: AppColors.textHint),
          ),
        ),
      );
    }

    final barColors = [
      _kPrimary,
      _kAccent,
      _kCompleted,
      _kMissed,
      _kCancelled,
      AppColors.primaryLight,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: sorted.asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value;
          final ratio = entry.value / maxVal;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: barColors[idx % barColors.length].withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: barColors[idx % barColors.length],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: ratio,
                        color: barColors[idx % barColors.length],
                        backgroundColor: AppColors.border,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: barColors[idx % barColors.length],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overall Performance Metrics
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceMetricsCard extends StatelessWidget {
  final AnalyticsData data;
  const _PerformanceMetricsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final completionPct = (data.completionRate * 100).toStringAsFixed(1);
    final cancelPct = (data.cancellationRate * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(
        children: [
          _MetricTile(
            icon: Icons.check_circle_rounded,
            label: 'Completion Rate',
            subtitle: 'Appointments completed vs total',
            value: '$completionPct%',
            color: _kCompleted,
            progress: data.completionRate.clamp(0.0, 1.0),
          ),
          const Divider(height: 20),
          _MetricTile(
            icon: Icons.cancel_rounded,
            label: 'Cancellation Rate',
            subtitle: 'Appointments cancelled vs total',
            value: '$cancelPct%',
            color: _kCancelled,
            progress: data.cancellationRate.clamp(0.0, 1.0),
          ),
          const Divider(height: 20),
          _MetricTile(
            icon: Icons.assignment_turned_in_rounded,
            label: 'Plan Conversion',
            subtitle: 'Consultations converted to treatment plans',
            value: '${(data.planConversionRate * 100).toStringAsFixed(1)}%',
            color: _kPrimary,
            progress: data.planConversionRate.clamp(0.0, 1.0),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final Color color;
  final double progress;
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                color: color,
                backgroundColor: AppColors.border,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

BoxDecoration _cardDeco() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: AppColors.textPrimary.withValues(alpha: 0.04),
        blurRadius: 14,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

Widget _emptyDonut() {
  return Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.border, width: 8),
    ),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
