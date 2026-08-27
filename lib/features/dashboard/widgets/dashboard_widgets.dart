import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/shimmer_effect.dart';

import 'package:pms_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/dashboard/screens/main_layout.dart';

// Helper to format time (e.g., "10:00" -> "10:00 AM")
String formatTimeString(String timeStr) {
  try {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final formattedMinute = minute.toString().padLeft(2, '0');
      return '$formattedHour:$formattedMinute $ampm';
    }
  } catch (_) {}
  return timeStr;
}

// ─── Today's Summary Card Item ──────────────────────────────────
class SummaryCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String delta;

  const SummaryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.delta,
  });

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textStyles = context.textStyles;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    Widget content = Container(
      padding: isDesktop
          ? const EdgeInsets.symmetric(horizontal: 22, vertical: 18)
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDesktop
            ? context.colors.cardBackground.withValues(alpha: 0.72)
            : context.colors.cardBackground,
        borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Accent bar + Icon row ──────────────────────────
          Row(
            children: [
              // Slim colour accent bar
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Icon(widget.icon, color: widget.color, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          // ── Big number ─────────────────────────────────────
          Text(
            widget.value,
            style: textStyles.displayNumber.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          // ── Label ──────────────────────────────────────────
          Text(
            widget.label,
            style: textStyles.caption.copyWith(
              color: context.colors.textSecondary,
              fontSize: 11,
              letterSpacing: 0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (isDesktop) {
      final translationY = _isHovered ? -3.0 : 0.0;
      final hoverGlowOpacity = _isHovered ? 0.08 : 0.04;
      final mainShadowOpacity = _isHovered ? 0.40 : 0.35;

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0.0, translationY, 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadowColor.withValues(alpha: mainShadowOpacity),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: context.colors.shadowColor.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: hoverGlowOpacity),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: content,
            ),
          ),
        ),
      );
    }
    return content;
  }
}

// ─── Today's Summary Bar (holds the 3 Summary Cards) ───────────
class TodaySummaryBar extends StatelessWidget {
  final DashboardStats stats;
  const TodaySummaryBar({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    if (stats.isLoading) {
      final skeletonCards = List.generate(
        3,
        (_) => Container(
          height: 110,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonCircle(size: 28),
                  SkeletonBox(width: 40, height: 16, borderRadius: 6),
                ],
              ),
              const SkeletonBox(width: 60, height: 22, borderRadius: 6),
              const SkeletonBox(width: 90, height: 12, borderRadius: 4),
            ],
          ),
        ),
      );

      return ShimmerEffect(
        child: isDesktop
            ? Row(
                children: [
                  Expanded(child: skeletonCards[0]),
                  const SizedBox(width: 20),
                  Expanded(child: skeletonCards[1]),
                  const SizedBox(width: 20),
                  Expanded(child: skeletonCards[2]),
                ],
              )
            : Column(
                children: [
                  skeletonCards[0],
                  const SizedBox(height: 12),
                  skeletonCards[1],
                  const SizedBox(height: 12),
                  skeletonCards[2],
                ],
              ),
      );
    }

    final cards = [
      SummaryCard(
        icon: Icons.people_rounded,
        label: 'Total Patients',
        value: '${stats.totalPatients}',
        color: const Color(0xFF3B82F6),
        delta: '+12%',
      ),
      SummaryCard(
        icon: Icons.directions_walk_rounded,
        label: 'Walk-Ins Today',
        value: '${stats.walkInsToday}',
        color: const Color(0xFF10B981),
        delta: '-',
      ),
      SummaryCard(
        icon: Icons.pending_actions_rounded,
        label: 'Pending',
        value: '${stats.pendingConsultations}',
        color: const Color(0xFFF59E0B),
        delta: '-',
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 20),
          Expanded(child: cards[1]),
          const SizedBox(width: 20),
          Expanded(child: cards[2]),
        ],
      );
    }

    return Column(
      children: [
        cards[0],
        const SizedBox(height: 12),
        cards[1],
        const SizedBox(height: 12),
        cards[2],
      ],
    );
  }
}

// ─── Practice Overview Quick Stat Row ───────────────────────
class QuickStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const QuickStatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State Placeholder ────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: context.colors.textMuted),
          const SizedBox(height: 10),
          Text(
            message,
            style: context.textStyles.caption.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Overview Section (2x2 Grid) ───────────────────
class DashboardOverviewSection extends StatelessWidget {
  final DashboardStats stats;
  final bool showRevenue;
  const DashboardOverviewSection({
    super.key,
    required this.stats,
    this.showRevenue = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    final card1 = DashboardOverviewCard(
      title: "Today's Consultations",
      icon: Icons.calendar_today_rounded,
      color: const Color(0xFF0F5D4F),
      onTap: () => mainLayoutKey.currentState?.switchToTab(1),
      children: [
        DashboardOverviewItem(
          label: "Total Scheduled",
          value: '${stats.consultationsTotalToday}',
          color: const Color(0xFF0F5D4F),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Completed",
          value: '${stats.consultationsCompletedToday}',
          color: const Color(0xFF16A34A),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Pending",
          value: '${stats.consultationsPendingToday}',
          color: const Color(0xFFD97706),
        ),
      ],
    );

    final card2 = DashboardOverviewCard(
      title: "Today's Sessions",
      icon: Icons.personal_injury_outlined,
      color: const Color(0xFF0F5D4F),
      onTap: () => mainLayoutKey.currentState?.switchToTab(1),
      children: [
        DashboardOverviewItem(
          label: "Scheduled",
          value: '${stats.sessionsTotalToday}',
          color: const Color(0xFF0F5D4F),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Completed",
          value: '${stats.sessionsCompletedToday}',
          color: const Color(0xFF16A34A),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Pending",
          value: '${stats.sessionsPendingToday}',
          color: const Color(0xFFD97706),
        ),
      ],
    );

    final card3 = DashboardOverviewCard(
      title: "Patients Seen Today",
      icon: Icons.group_outlined,
      color: const Color(0xFF4F46E5),
      onTap: () => mainLayoutKey.currentState?.switchToTab(1),
      children: [
        DashboardOverviewItem(
          label: "Visited",
          value: '${stats.patientsSeenToday}',
          color: const Color(0xFF4F46E5),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Expected",
          value: '${stats.patientsExpectedToday}',
          color: const Color(0xFF0F5D4F),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Remaining",
          value: '${stats.patientsRemainingToday}',
          color: const Color(0xFFD97706),
        ),
      ],
    );

    final card4 = showRevenue
        ? DashboardOverviewCard(
            title: "Today's Revenue",
            icon: Icons.payments_outlined,
            color: const Color(0xFFD97706),
            onTap: () => mainLayoutKey.currentState?.switchToTab(2),
            children: [
              DashboardOverviewItem(
                label: "Total Collected",
                value: '₹${stats.feesTotalToday}',
                color: const Color(0xFF111827),
              ),
              const DashboardOverviewDivider(),
              DashboardOverviewItem(
                label: "Consultations",
                value: '₹${stats.feesOnlyConsultationToday}',
                color: const Color(0xFF4B5563),
              ),
              const DashboardOverviewDivider(),
              DashboardOverviewItem(
                label: "Sessions",
                value: '₹${stats.feesOnlySessionToday}',
                color: const Color(0xFF4B5563),
              ),
            ],
          )
        : DashboardOverviewCard(
            title: "Front Desk Queue",
            icon: Icons.how_to_reg_rounded,
            color: const Color(0xFF0F5D4F),
            onTap: () => mainLayoutKey.currentState?.switchToTab(1),
            children: [
              DashboardOverviewItem(
                label: "Checked In",
                value: '${stats.patientsSeenToday}',
                color: const Color(0xFF16A34A),
              ),
              const DashboardOverviewDivider(),
              DashboardOverviewItem(
                label: "In Waiting",
                value: '${stats.patientsRemainingToday}',
                color: const Color(0xFFD97706),
              ),
              const DashboardOverviewDivider(),
              DashboardOverviewItem(
                label: "Total Expected",
                value: '${stats.patientsExpectedToday}',
                color: const Color(0xFF0F5D4F),
              ),
            ],
          );

    if (isDesktop) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card1),
              const SizedBox(width: 20),
              Expanded(child: card2),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: card3),
              const SizedBox(width: 20),
              Expanded(child: card4),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        card1,
        const SizedBox(height: 16),
        card2,
        const SizedBox(height: 16),
        card3,
        const SizedBox(height: 16),
        card4,
      ],
    );
  }
}

// ─── Dashboard Helper Card widget ────────────────────────────
class DashboardOverviewCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final VoidCallback? onTap;

  const DashboardOverviewCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
    this.onTap,
  });

  @override
  State<DashboardOverviewCard> createState() => _DashboardOverviewCardState();
}

class _DashboardOverviewCardState extends State<DashboardOverviewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0.0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withValues(alpha: 0.35)
                  : context.colors.border.withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.color.withValues(alpha: 0.08)
                    : context.colors.shadowColor.withValues(alpha: 0.04),
                blurRadius: _isHovered ? 28 : 24,
                offset: Offset(0, _isHovered ? 10 : 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: context.textStyles.h3.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onTap != null)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _isHovered ? 0.8 : 0.0,
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: widget.color,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: widget.children,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardOverviewItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const DashboardOverviewItem({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF71717A), // Slightly darker gray for readability
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class DashboardOverviewDivider extends StatelessWidget {
  const DashboardOverviewDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: context.colors.divider,
    );
  }
}

// ─── Weekly Appointments Trend Chart ─────────────────────────
class AppointmentsTrendChart extends StatefulWidget {
  const AppointmentsTrendChart({super.key});

  @override
  State<AppointmentsTrendChart> createState() => _AppointmentsTrendChartState();
}

class _AppointmentsTrendChartState extends State<AppointmentsTrendChart> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    Widget content = Container(
      padding: isDesktop ? const EdgeInsets.all(24) : const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDesktop
            ? context.colors.cardBackground.withValues(alpha: 0.72)
            : context.colors.cardBackground,
        borderRadius: BorderRadius.circular(isDesktop ? 28 : 16),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Appointments Trend',
                style: context.textStyles.h3.copyWith(
                  fontSize: 16,
                  color: context.colors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colors.cardBackgroundAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Text(
                      'This Week',
                      style: context.textStyles.caption.copyWith(
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textHint, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: context.textStyles.caption.copyWith(color: context.colors.textMuted, fontSize: 9),
                        );
                      },
                      reservedSize: 22,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value >= 0 && value < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              days[value.toInt()],
                              style: context.textStyles.caption.copyWith(color: context.colors.textHint, fontSize: 9),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 80,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 22),
                      FlSpot(1, 31),
                      FlSpot(2, 35),
                      FlSpot(3, 42),
                      FlSpot(4, 52),
                      FlSpot(5, 61),
                      FlSpot(6, 78),
                    ],
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF1D4ED8),
                          strokeWidth: 2,
                          strokeColor: context.colors.textOnPrimary,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          const Color(0xFF3B82F6).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (isDesktop) {
      final translationY = _isHovered ? -3.0 : 0.0;
      final hoverGlowOpacity = _isHovered ? 0.08 : 0.04;
      final mainShadowOpacity = _isHovered ? 0.40 : 0.35;

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0.0, translationY, 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadowColor.withValues(alpha: mainShadowOpacity),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: context.colors.shadowColor.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: hoverGlowOpacity),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: content,
            ),
          ),
        ),
      );
    }
    return content;
  }
}

// ─── Patient Timeline Stream ──────────────────────────────────
class PatientTimelineStream extends StatelessWidget {
  final List<AppointmentModel> appointments;

  const PatientTimelineStream({super.key, required this.appointments});

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = appointments.isEmpty;
    final List<_StreamItem> items = [];
    
    if (!isEmpty) {
      // Build from real appointments
      final sorted = List<AppointmentModel>.from(appointments)
        ..sort((a, b) => a.time.compareTo(b.time));
      for (final appt in sorted) {
        final inProgress = appt.status == AppointmentStatus.inProgress;
        final isCompleted = appt.status == AppointmentStatus.completed;
        final isWaiting = appt.status == AppointmentStatus.waiting;

        String detail = 'Upcoming Appointment';
        bool isUpcoming = true;

        if (isCompleted) {
          detail = appt.type == AppointmentType.session ? 'Completed Session' : 'Completed Consultation';
          isUpcoming = false;
        } else if (inProgress) {
          detail = appt.type == AppointmentType.session ? 'In session for treatment' : 'In Consultation';
          isUpcoming = false;
        } else if (isWaiting) {
          detail = appt.type == AppointmentType.session ? 'Checked in for treatment' : 'Checked in for Consultation';
          isUpcoming = false;
        }

        items.add(_StreamItem(
          name: appt.displayName,
          detail: detail,
          time: formatTimeString(appt.time),
          isUpcoming: isUpcoming,
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timeline_rounded,
                      size: 32,
                      color: context.colors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No patient stream activity today',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isLast = index == items.length - 1;
                
                final initials = item.name.split(' ').map((e) => e[0]).take(2).join().toUpperCase();

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Row(
                    children: [
                      // Patient Avatar
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F5D4F).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F5D4F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.detail,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Time & Status Dot
                      Row(
                        children: [
                          Text(
                            item.time,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: context.colors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: item.isUpcoming ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }
}

class _StreamItem {
  final String name;
  final String detail;
  final String time;
  final bool isUpcoming;

  const _StreamItem({
    required this.name,
    required this.detail,
    required this.time,
    required this.isUpcoming,
  });
}

// ─── Patients Waiting List ─────────────────────────────────────
class PatientsWaitingList extends StatelessWidget {
  final List<AppointmentModel> appointments;

  const PatientsWaitingList({super.key, required this.appointments});

  @override
  Widget build(BuildContext context) {
    // Filter today's appointments for status == AppointmentStatus.waiting
    final waitingAppointments = appointments
        .where((appt) => appt.status == AppointmentStatus.waiting)
        .toList();

    // Sort by check-in time (longest waiting first)
    waitingAppointments.sort((a, b) {
      if (a.checkInTime == null && b.checkInTime == null) return 0;
      if (a.checkInTime == null) return 1;
      if (b.checkInTime == null) return -1;
      return a.checkInTime!.compareTo(b.checkInTime!); // oldest checkInTime first
    });

    final bool isEmpty = waitingAppointments.isEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.done_all_rounded,
                      size: 32,
                      color: const Color(0xFF16A34A).withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No patients waiting right now',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: List.generate(waitingAppointments.length, (index) {
                final appt = waitingAppointments[index];
                final isLast = index == waitingAppointments.length - 1;
                
                final name = appt.displayName;
                final initials = name.split(' ').map((e) => e[0]).take(2).join().toUpperCase();

                // Compute wait time
                String waitText = 'Checked in';
                if (appt.checkInTime != null) {
                  final diff = DateTime.now().difference(appt.checkInTime!).inMinutes;
                  if (diff <= 0) {
                    waitText = 'Waiting < 1 min';
                  } else if (diff < 60) {
                    waitText = 'Waiting for $diff mins';
                  } else {
                    final hours = diff ~/ 60;
                    final mins = diff % 60;
                    waitText = mins > 0 ? 'Waiting for ${hours}h ${mins}m' : 'Waiting for ${hours}h';
                  }
                }

                final typeLabel = appt.type == AppointmentType.session ? 'Session' : 'Consultation';

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Row(
                    children: [
                      // Patient Avatar
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F5D4F).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F5D4F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  mainLayoutKey.currentState?.switchToTab(1, highlightAppointmentId: appt.id);
                                },
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F5D4F),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$typeLabel • $waitText',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Start Action Link
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            mainLayoutKey.currentState?.switchToTab(1, highlightAppointmentId: appt.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F5D4F).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Start',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F5D4F),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 12,
                                  color: const Color(0xFF0F5D4F),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }
}

class WebGlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;
  final bool animateHover;

  const WebGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
    this.glowColor,
    this.animateHover = true,
  });

  @override
  State<WebGlassCard> createState() => _WebGlassCardState();
}

class _WebGlassCardState extends State<WebGlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    if (!isDesktop) {
      return Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadowColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.child,
      );
    }

    final translationY = widget.animateHover && _isHovered ? -3.0 : 0.0;
    final hoverGlowOpacity = widget.animateHover && _isHovered ? 0.08 : 0.04;
    final mainShadowOpacity = widget.animateHover && _isHovered ? 0.40 : 0.35;
    final activeGlowColor = widget.glowColor ?? const Color(0xFF3B82F6);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0.0, translationY, 0.0),
        decoration: BoxDecoration(
          color: context.colors.cardBackground.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: context.colors.border.withValues(alpha: 0.4),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadowColor.withValues(alpha: mainShadowOpacity),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: context.colors.shadowColor.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: activeGlowColor.withValues(alpha: hoverGlowOpacity),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dashboard Full Layout Skeleton View ───────────────────────

class DashboardSkeletonView extends StatelessWidget {
  final bool isDesktop;
  final bool showBottomCards;

  const DashboardSkeletonView({
    super.key,
    required this.isDesktop,
    this.showBottomCards = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Main Pane (flex 7)
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerEffect(
                  child: SkeletonBox(width: 170, height: 22, borderRadius: 6),
                ),
                const SizedBox(height: 18),
                const _DashboardOverviewSkeleton(isDesktop: true),
                if (showBottomCards) ...[
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Expanded(
                        child: _CardContainerSkeleton(height: 310),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        child: _CardContainerSkeleton(height: 310),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Right Side Pane (flex 3)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerEffect(
                  child: SkeletonBox(width: 150, height: 22, borderRadius: 6),
                ),
                const SizedBox(height: 18),
                const _QuickStatRowSkeleton(),
                const SizedBox(height: 16),
                const _QuickStatRowSkeleton(),
                const SizedBox(height: 36),
                const ShimmerEffect(
                  child: SkeletonBox(width: 130, height: 20, borderRadius: 6),
                ),
                const SizedBox(height: 12),
                const _WaitingListSkeleton(),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile View
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerEffect(
          child: SkeletonBox(width: 170, height: 22, borderRadius: 6),
        ),
        const SizedBox(height: 16),
        const _DashboardOverviewSkeleton(isDesktop: false),
        const SizedBox(height: 24),
        const ShimmerEffect(
          child: SkeletonBox(width: 150, height: 20, borderRadius: 6),
        ),
        const SizedBox(height: 12),
        const _QuickStatRowSkeleton(),
        const SizedBox(height: 10),
        const _QuickStatRowSkeleton(),
        if (showBottomCards) ...[
          const SizedBox(height: 24),
          const _CardContainerSkeleton(height: 250),
          const SizedBox(height: 24),
          const _CardContainerSkeleton(height: 250),
        ],
      ],
    );
  }
}

class _DashboardOverviewSkeleton extends StatelessWidget {
  final bool isDesktop;

  const _DashboardOverviewSkeleton({required this.isDesktop});

  Widget _buildCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
      ),
      child: ShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                SkeletonCircle(size: 24),
                SizedBox(width: 10),
                SkeletonBox(width: 140, height: 16, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 60, height: 10, borderRadius: 3),
                      SizedBox(height: 6),
                      SkeletonBox(width: 40, height: 18, borderRadius: 4),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: context.colors.divider),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 60, height: 10, borderRadius: 3),
                      SizedBox(height: 6),
                      SkeletonBox(width: 40, height: 18, borderRadius: 4),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: context.colors.divider),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 60, height: 10, borderRadius: 3),
                      SizedBox(height: 6),
                      SkeletonBox(width: 40, height: 18, borderRadius: 4),
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

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildCard(context)),
              const SizedBox(width: 20),
              Expanded(child: _buildCard(context)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCard(context)),
              const SizedBox(width: 20),
              Expanded(child: _buildCard(context)),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildCard(context),
        const SizedBox(height: 12),
        _buildCard(context),
        const SizedBox(height: 12),
        _buildCard(context),
        const SizedBox(height: 12),
        _buildCard(context),
      ],
    );
  }
}

class _CardContainerSkeleton extends StatelessWidget {
  final double height;

  const _CardContainerSkeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
      ),
      child: ShimmerEffect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(width: 120, height: 18, borderRadius: 4),
                SkeletonBox(width: 50, height: 14, borderRadius: 4),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: const [
                        SkeletonCircle(size: 36),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 100, height: 14, borderRadius: 4),
                              SizedBox(height: 6),
                              SkeletonBox(width: 60, height: 10, borderRadius: 3),
                            ],
                          ),
                        ),
                        SkeletonBox(width: 45, height: 14, borderRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatRowSkeleton extends StatelessWidget {
  const _QuickStatRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: ShimmerEffect(
        child: Row(
          children: const [
            SkeletonBox(width: 36, height: 36, borderRadius: 10),
            SizedBox(width: 14),
            Expanded(child: SkeletonBox(width: 110, height: 14, borderRadius: 4)),
            SkeletonBox(width: 30, height: 18, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

class _WaitingListSkeleton extends StatelessWidget {
  const _WaitingListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
      ),
      child: ShimmerEffect(
        child: Column(
          children: List.generate(
            3,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
              child: Row(
                children: const [
                  SkeletonCircle(size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 80, height: 13, borderRadius: 3),
                        SizedBox(height: 4),
                        SkeletonBox(width: 50, height: 9, borderRadius: 3),
                      ],
                    ),
                  ),
                  SkeletonBox(width: 40, height: 16, borderRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


