import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/theme/app_colors_extension.dart';
import 'package:pms_app/core/theme/app_text_styles_extension.dart';
import 'package:pms_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';

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
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
          : const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDesktop
            ? const Color(0xFF131A26).withOpacity(0.07)
            : const Color(0xFF131924),
        borderRadius: BorderRadius.circular(isDesktop ? 28 : 16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon wrapper
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              // Value
              Text(
                widget.value,
                style: textStyles.h2.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Label and trend row
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: textStyles.bodySmall.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              // Delta badge
              if (widget.delta != '-')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.delta.startsWith('+') || widget.delta.startsWith('↗')
                        ? const Color(0xFF065F46).withOpacity(0.3)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.delta,
                    style: TextStyle(
                      color: widget.delta.startsWith('+') || widget.delta.startsWith('↗')
                          ? const Color(0xFF34D399)
                          : Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'vs last 7 days',
            style: textStyles.caption.copyWith(color: Colors.white30, fontSize: 9),
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
                color: Colors.black.withOpacity(mainShadowOpacity),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: widget.color.withOpacity(hoverGlowOpacity),
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
    if (stats.isLoading) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFF131924),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6), strokeWidth: 2.5),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

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
class QuickStatRow extends StatefulWidget {
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
  State<QuickStatRow> createState() => _QuickStatRowState();
}

class _QuickStatRowState extends State<QuickStatRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    Widget content = Container(
      padding: isDesktop
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDesktop
            ? const Color(0xFF131A26).withOpacity(0.07)
            : const Color(0xFF131924),
        borderRadius: BorderRadius.circular(isDesktop ? 28 : 14),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: widget.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.label,
              style: context.textStyles.bodyMedium.copyWith(color: Colors.white),
            ),
          ),
          Text(
            widget.value,
            style: context.textStyles.h3.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
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
                color: Colors.black.withOpacity(mainShadowOpacity),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: widget.color.withOpacity(hoverGlowOpacity),
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
        color: const Color(0xFF131924),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.white24),
          const SizedBox(height: 10),
          Text(
            message,
            style: context.textStyles.caption.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Overview Section (2x2 Grid) ───────────────────
class DashboardOverviewSection extends StatelessWidget {
  final DashboardStats stats;
  const DashboardOverviewSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    final card1 = DashboardOverviewCard(
      title: "Today's Consultations",
      icon: Icons.medical_information_rounded,
      color: const Color(0xFF3B82F6),
      children: [
        DashboardOverviewItem(
          label: "Total Scheduled",
          value: '${stats.consultationsTotalToday}',
          color: Colors.white70,
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Completed",
          value: '${stats.consultationsCompletedToday}',
          color: const Color(0xFF10B981),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Pending",
          value: '${stats.consultationsPendingToday}',
          color: const Color(0xFFF59E0B),
        ),
      ],
    );

    final card2 = DashboardOverviewCard(
      title: "Today's Sessions",
      icon: Icons.event_repeat_rounded,
      color: const Color(0xFF10B981),
      children: [
        DashboardOverviewItem(
          label: "Total Scheduled",
          value: '${stats.sessionsTotalToday}',
          color: const Color(0xFF10B981),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Completed",
          value: '${stats.sessionsCompletedToday}',
          color: const Color(0xFF34D399),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Pending",
          value: '${stats.sessionsPendingToday}',
          color: const Color(0xFFF59E0B),
        ),
      ],
    );

    final card3 = DashboardOverviewCard(
      title: "Patients Seen Today",
      icon: Icons.people_outline_rounded,
      color: const Color(0xFFA78BFA),
      children: [
        DashboardOverviewItem(
          label: "Unique Patients Checked-In / Visited Today",
          value: '${stats.patientsSeenToday}',
          color: const Color(0xFFA78BFA),
        ),
      ],
    );

    final card4 = DashboardOverviewCard(
      title: "Today's Fee Collections",
      icon: Icons.payments_outlined,
      color: const Color(0xFFF59E0B),
      children: [
        DashboardOverviewItem(
          label: "Total Collected",
          value: '₹${stats.feesTotalToday}',
          color: const Color(0xFFF59E0B),
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Only Consult",
          value: '₹${stats.feesOnlyConsultationToday}',
          color: Colors.white60,
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Consult + Sess",
          value: '₹${stats.feesConsultationAndSessionToday}',
          color: Colors.white60,
        ),
        const DashboardOverviewDivider(),
        DashboardOverviewItem(
          label: "Only Session",
          value: '₹${stats.feesOnlySessionToday}',
          color: Colors.white60,
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
        card2,
        card3,
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

  const DashboardOverviewCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  State<DashboardOverviewCard> createState() => _DashboardOverviewCardState();
}

class _DashboardOverviewCardState extends State<DashboardOverviewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    Widget content = Container(
      padding: isDesktop
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDesktop
            ? const Color(0xFF131A26).withOpacity(0.07)
            : const Color(0xFF131924),
        borderRadius: BorderRadius.circular(isDesktop ? 28 : 16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.0,
        ),
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
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                widget.title,
                style: context.textStyles.h3.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
    );

    if (isDesktop) {
      final translationY = _isHovered ? -3.0 : 0.0;
      final hoverGlowOpacity = _isHovered ? 0.08 : 0.04;
      final mainShadowOpacity = _isHovered ? 0.40 : 0.35;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: MouseRegion(
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
                  color: Colors.black.withOpacity(mainShadowOpacity),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: widget.color.withOpacity(hoverGlowOpacity),
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
        ),
      );
    }
    return content;
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
            style: context.textStyles.h2.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: context.textStyles.caption.copyWith(
              fontSize: 10,
              color: Colors.white38,
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
      color: Colors.white.withValues(alpha: 0.05),
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
            ? const Color(0xFF131A26).withOpacity(0.07)
            : const Color(0xFF131924),
        borderRadius: BorderRadius.circular(isDesktop ? 28 : 16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
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
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2230),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Text(
                      'This Week',
                      style: context.textStyles.caption.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 14),
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
                          style: context.textStyles.caption.copyWith(color: Colors.white30, fontSize: 9),
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
                              style: context.textStyles.caption.copyWith(color: Colors.white54, fontSize: 9),
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
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3B82F6).withOpacity(0.15),
                          const Color(0xFF3B82F6).withOpacity(0.0),
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
                color: Colors.black.withOpacity(mainShadowOpacity),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(hoverGlowOpacity),
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
class PatientTimelineStream extends StatefulWidget {
  final List<AppointmentModel> appointments;
  const PatientTimelineStream({super.key, required this.appointments});

  @override
  State<PatientTimelineStream> createState() => _PatientTimelineStreamState();
}

class _PatientTimelineStreamState extends State<PatientTimelineStream> {
  bool _isHovered = false;

  String _getTypeLabel(AppointmentType type) {
    switch (type) {
      case AppointmentType.walkIn:
        return 'Walk-in';
      case AppointmentType.session:
        return 'Session';
      case AppointmentType.callBy:
        return 'Consultation';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    Widget content;
    
    if (widget.appointments.isEmpty) {
      content = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: isDesktop
              ? const Color(0xFF131A26).withOpacity(0.07)
              : const Color(0xFF131924),
          borderRadius: BorderRadius.circular(isDesktop ? 28 : 16),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_toggle_off_rounded, color: Colors.white24, size: 36),
              const SizedBox(height: 10),
              Text(
                'No events today',
                style: context.textStyles.caption.copyWith(color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    } else {
      // Sort chronologically by scheduled time
      final sorted = List<AppointmentModel>.from(widget.appointments)
        ..sort((a, b) => a.time.compareTo(b.time));

      content = Container(
        padding: isDesktop
            ? const EdgeInsets.symmetric(horizontal: 24, vertical: 20)
            : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDesktop
              ? const Color(0xFF131A26).withOpacity(0.07)
              : const Color(0xFF131924),
          borderRadius: BorderRadius.circular(isDesktop ? 28 : 16),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
            width: 1.0,
          ),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final appt = sorted[index];
            final isLast = index == sorted.length - 1;

            // Determine icon, colors, and timeline descriptions
            IconData nodeIcon;
            Color nodeColor;
            String statusText = '';
            String timeText = formatTimeString(appt.time);
            
            final inProgress = appt.status == AppointmentStatus.inProgress;
            final isCompleted = appt.status == AppointmentStatus.completed;
            final isCancelled = appt.status == AppointmentStatus.cancelled;
            final isWaiting = appt.status == AppointmentStatus.waiting;

            if (isCompleted) {
              nodeIcon = Icons.check_circle_rounded;
              nodeColor = context.colors.success;
              
              if (appt.checkInTime != null && appt.consultationStartTime != null) {
                final waitDiff = appt.consultationStartTime!.difference(appt.checkInTime!);
                final waitMin = waitDiff.inMinutes;
                statusText = 'Completed • Waited ${waitMin}m';
              } else {
                statusText = 'Completed';
              }
              if (appt.consultationStartTime != null) {
                timeText = DateFormat('h:mm a').format(appt.consultationStartTime!.toLocal());
              }
            } else if (inProgress) {
              nodeIcon = Icons.play_circle_filled_rounded;
              nodeColor = context.colors.info;
              
              if (appt.checkInTime != null && appt.consultationStartTime != null) {
                final waitDiff = appt.consultationStartTime!.difference(appt.checkInTime!);
                statusText = 'In Session • Waited ${waitDiff.inMinutes}m';
              } else {
                statusText = 'In Session';
              }
              if (appt.consultationStartTime != null) {
                timeText = DateFormat('h:mm a').format(appt.consultationStartTime!.toLocal());
              }
            } else if (isWaiting) {
              nodeIcon = Icons.hourglass_empty_rounded;
              nodeColor = const Color(0xFFFBBF24); // Warm yellow
              
              if (appt.checkInTime != null) {
                final waitDiff = DateTime.now().difference(appt.checkInTime!);
                statusText = 'Waiting Room • Arrived ${DateFormat('h:mm a').format(appt.checkInTime!.toLocal())} (${waitDiff.inMinutes}m ago)';
              } else {
                statusText = 'Waiting Room';
              }
            } else if (isCancelled) {
              nodeIcon = Icons.cancel_rounded;
              nodeColor = context.colors.error;
              statusText = 'Cancelled';
            } else {
              // Scheduled / Upcoming
              nodeIcon = Icons.radio_button_unchecked_rounded;
              nodeColor = context.colors.textHint;
              statusText = 'Scheduled';
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left timeline lines and circle
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: nodeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          nodeIcon,
                          color: nodeColor,
                          size: 15,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  // Right contents
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                appt.displayName,
                                style: context.textStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeText,
                              style: context.textStyles.caption.copyWith(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: context.textStyles.caption.copyWith(
                            color: inProgress ? context.colors.info : (isWaiting ? const Color(0xFFFBBF24) : Colors.white38),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getTypeLabel(appt.type),
                                style: TextStyle(
                                  color: appt.type == AppointmentType.session 
                                      ? const Color(0xFF34D399) 
                                      : (appt.type == AppointmentType.walkIn ? const Color(0xFFFBBF24) : const Color(0xFF60A5FA)),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (appt.doctorName != null && appt.doctorName!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Dr. ${appt.doctorName}',
                                style: context.textStyles.caption.copyWith(
                                  color: Colors.white24,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16), // Bottom spacing for nodes
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    if (isDesktop) {
      final translationY = _isHovered ? -3.0 : 0.0;
      final hoverGlowOpacity = _isHovered ? 0.06 : 0.02;
      final mainShadowOpacity = _isHovered ? 0.40 : 0.35;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: MouseRegion(
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
                  color: Colors.black.withOpacity(mainShadowOpacity),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(hoverGlowOpacity),
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
        ),
      );
    }
    return content;
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
              color: Colors.black.withOpacity(0.08),
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
          color: const Color(0xFF131A26).withOpacity(0.07),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(mainShadowOpacity),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: activeGlowColor.withOpacity(hoverGlowOpacity),
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

