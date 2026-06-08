import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import 'package:pms_app/features/analytics/providers/analytics_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/responsive_wrapper.dart';
import 'package:pms_app/features/dashboard/widgets/dashboard_widgets.dart';

// --- Color palette for charts ------------------------------------------------
const _kCompleted = Color(0xFF10B981);
const _kScheduled = Color(0xFF3B82F6);
const _kCancelled = Color(0xFFEF4444);
const _kMissed = Color(0xFFF59E0B);
const _kAccent = Color(0xFF8B5CF6);

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(analyticsProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: isDesktop ? Colors.transparent : context.colors.background,
      body: SafeArea(
        child: ResponsiveWrapper(
          child: data.isLoading
              ? const _LoadingView()
              : RefreshIndicator(
                  color: context.colors.primary,
                  onRefresh: () => ref.read(analyticsProvider.notifier).load(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: isDesktop
                            ? const EdgeInsets.fromLTRB(36, 12, 36, 100)
                            : const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _AnalyticsHeader(data: data),
                            const SizedBox(height: 16),
                            // -- KPI Row 1 ------------------------------
                            _KpiRow(data: data),
                            const SizedBox(height: 16),
                            // -- Revenue KPI -----------------------------
                            _RevenueCard(data: data),
                            const SizedBox(height: 24),
                            // -- Today's Snapshot -----------------------
                            const _SectionHeader(
                              icon: Icons.today_rounded,
                              title: "Today's Snapshot",
                            ),
                            const SizedBox(height: 10),
                            _TodaySnapshotRow(data: data),
                            const SizedBox(height: 24),
                            if (isDesktop) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const _SectionHeader(
                                          icon: Icons.bar_chart_rounded,
                                          title: '7-Day Activity',
                                        ),
                                        const SizedBox(height: 10),
                                        _WeeklyActivityChart(data: data),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const _SectionHeader(
                                          icon: Icons.access_time_rounded,
                                          title: 'Appointment Volume by Hour',
                                        ),
                                        const SizedBox(height: 10),
                                        _HourlyVolumeChart(data: data),
                                        const SizedBox(height: 12),
                                        _PeakInsightRow(data: data),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ] else ...[
                              // -- 7-Day Activity Chart -------------------
                              const _SectionHeader(
                                icon: Icons.bar_chart_rounded,
                                title: '7-Day Activity',
                              ),
                              const SizedBox(height: 10),
                              _WeeklyActivityChart(data: data),
                              const SizedBox(height: 24),
                              // -- Peak Hours -----------------------------
                              const _SectionHeader(
                                icon: Icons.access_time_rounded,
                                title: 'Appointment Volume by Hour',
                              ),
                              const SizedBox(height: 10),
                              _HourlyVolumeChart(data: data),
                              const SizedBox(height: 12),
                              _PeakInsightRow(data: data),
                              const SizedBox(height: 24),
                            ],
                            if (isDesktop) ...[
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const _SectionHeader(
                                            icon: Icons.pie_chart_rounded,
                                            title: 'Appointment Type Split',
                                          ),
                                          const SizedBox(height: 10),
                                          Expanded(child: _TypeSplitRow(data: data)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const _SectionHeader(
                                            icon: Icons.healing_rounded,
                                            title: 'Session Performance',
                                          ),
                                          const SizedBox(height: 10),
                                          Expanded(child: _SessionPerformanceRow(data: data)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const _SectionHeader(
                                            icon: Icons.assignment_turned_in_rounded,
                                            title: 'Consultation → Treatment Plan Conversion',
                                          ),
                                          const SizedBox(height: 10),
                                          Expanded(child: _PlanConversionCard(data: data)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ] else ...[
                              // -- Appointment Type Split -----------------
                              const _SectionHeader(
                                icon: Icons.pie_chart_rounded,
                                title: 'Appointment Type Split',
                              ),
                              const SizedBox(height: 10),
                              _TypeSplitRow(data: data),
                              const SizedBox(height: 24),
                              // -- Session Performance --------------------
                              const _SectionHeader(
                                icon: Icons.healing_rounded,
                                title: 'Session Performance',
                              ),
                              const SizedBox(height: 10),
                              _SessionPerformanceRow(data: data),
                              const SizedBox(height: 24),
                              // -- Plan Conversion ------------------------
                              const _SectionHeader(
                                icon: Icons.assignment_turned_in_rounded,
                                title: 'Consultation → Treatment Plan Conversion',
                              ),
                              const SizedBox(height: 10),
                              _PlanConversionCard(data: data),
                              const SizedBox(height: 24),
                            ],
                            // -- Patient Demographics -------------------
                            const _SectionHeader(
                              icon: Icons.people_rounded,
                              title: 'Patient Demographics',
                            ),
                            const SizedBox(height: 10),
                            _DemographicsRow(data: data),
                            const SizedBox(height: 24),
                            // -- Geographic Distribution ----------------
                            const _SectionHeader(
                              icon: Icons.location_on_rounded,
                              title: 'Patient Locations',
                            ),
                            const SizedBox(height: 10),
                            _LocationCard(data: data),
                            const SizedBox(height: 24),
                            // -- Completion Rate ------------------------
                            const _SectionHeader(
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
      ),
    );
  }
}

// ------
// Flat Dashboard Header
// ------

class _AnalyticsHeader extends ConsumerWidget {
  final AnalyticsData data;
  const _AnalyticsHeader({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics',
          style: context.textStyles.h1.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Track your clinic's performance and insights",
          style: context.textStyles.bodyMedium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );

    final actionsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Date picker dropdown
        PopupMenuButton<int>(
          onSelected: (days) {
            ref.read(analyticsProvider.notifier).load(days: days);
          },
          initialValue: data.selectedDays,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 7, child: Text('Last 7 days')),
            const PopupMenuItem(value: 30, child: Text('Last 30 days')),
            const PopupMenuItem(value: 90, child: Text('Last 90 days')),
            const PopupMenuItem(value: 365, child: Text('Last 365 days')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: context.colors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  data.selectedDays == 7
                      ? 'Last 7 days'
                      : data.selectedDays == 30
                          ? 'Last 30 days'
                          : data.selectedDays == 90
                              ? 'Last 90 days'
                              : 'Last 365 days',
                  style: context.textStyles.buttonMedium.copyWith(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: context.colors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Export report button
        InkWell(
          onTap: () => _showExportDialog(context, data),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.file_download_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Export Report',
                  style: context.textStyles.buttonMedium.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                titleColumn,
                actionsRow,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleColumn,
                const SizedBox(height: 16),
                actionsRow,
              ],
            ),
    );
  }
}

void _showExportDialog(BuildContext context, AnalyticsData data) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _ExportProgressDialog(data: data);
    },
  );
}

class _ExportProgressDialog extends StatefulWidget {
  final AnalyticsData data;
  const _ExportProgressDialog({required this.data});

  @override
  State<_ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<_ExportProgressDialog> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (_isLoading) {
      return Dialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: context.colors.primary),
              const SizedBox(height: 24),
              Text(
                'Generating Analytics Report...',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Analyzing and formatting your clinic data...',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final csvContent = _generateCsv(widget.data);

    return Dialog(
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Generated!',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Last ${widget.data.selectedDays} days summary is ready to export.',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Report Preview:',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.border.withValues(alpha: 0.5)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  csvContent,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            isDesktop
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: csvContent));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Report copied to clipboard!'),
                              backgroundColor: context.colors.primary,
                            ),
                          );
                        },
                        child: Text(
                          'Copy CSV',
                          style: TextStyle(color: context.colors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final bytes = utf8.encode(csvContent);
                          final base64Csv = base64.encode(bytes);
                          final url = 'data:text/csv;base64,$base64Csv';
                          final uri = Uri.parse(url);
                          try {
                            await launchUrl(uri);
                          } catch (e) {
                            debugPrint('Error launching export: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.file_download_rounded, size: 16),
                        label: const Text('Download'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Done',
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          final bytes = utf8.encode(csvContent);
                          final base64Csv = base64.encode(bytes);
                          final url = 'data:text/csv;base64,$base64Csv';
                          final uri = Uri.parse(url);
                          try {
                            await launchUrl(uri);
                          } catch (e) {
                            debugPrint('Error launching export: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.file_download_rounded, size: 16),
                        label: const Text('Download CSV Report'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: csvContent));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Report copied to clipboard!'),
                              backgroundColor: context.colors.primary,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.primary,
                          side: BorderSide(color: context.colors.primary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Copy CSV to Clipboard'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Done',
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
        ),
      ),
    );
  }

  String _generateCsv(AnalyticsData data) {
    final csvRows = [
      'PMS Clinic Analytics Report',
      'Export Date,${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      'Date Range,Last ${data.selectedDays} days',
      '',
      'Overview KPI,Value,Description',
      'Total Patients,${data.totalPatients},Total registered patients in the clinic',
      'Total Appointments,${data.totalAppointments},Total appointments in the selected date range',
      'Completed Appointments,${data.completedAppointments},Completed appointments in the selected range',
      'Cancelled Appointments,${data.cancelledAppointments},Cancelled appointments in the selected range',
      'Active Treatment Plans,${data.activeTreatmentPlans},Current active treatment plans',
      'Total Revenue,₹${data.totalRevenue},Revenue generated from completed sessions and consultations',
      '',
      'Today Snapshot,Value,Description',
      'Today Scheduled,${data.todayScheduled},Appointments scheduled for today',
      'Today Completed,${data.todayCompleted},Appointments completed today',
      'Today Cancelled,${data.todayCancelled},Appointments cancelled today',
      '',
      'Treatment Sessions,Value,Description',
      'Sessions Completed,${data.sessionsCompleted},Total completed sessions',
      'Sessions Missed,${data.sessionsMissed},Total missed sessions',
      'Sessions Cancelled,${data.sessionsCancelled},Total cancelled sessions',
      '',
      'Performance Metrics,Value,Description',
      'Completion Rate,${(data.completionRate * 100).toStringAsFixed(1)}%,Percentage of completed appointments',
      'Cancellation Rate,${(data.cancellationRate * 100).toStringAsFixed(1)}%,Percentage of cancelled appointments',
      'Plan Conversion Rate,${(data.planConversionRate * 100).toStringAsFixed(1)}%,Percentage of consultations converted to plans',
    ];
    return csvRows.join('\n');
  }
}

// ------
// Section Header
// ------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.colors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ------
// Loading view
// ------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: context.colors.primary),
          const SizedBox(height: 16),
          Text(
            'Loading analytics…',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ------
// KPI Row & Cards
// ------

class _KpiRow extends StatelessWidget {
  final AnalyticsData data;
  const _KpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    final cards = [
      _KpiCard(
        label: 'Total Patients',
        value: '${data.totalPatients}',
        icon: Icons.people_rounded,
        color: const Color(0xFF3B82F6),
        trendText: '12%',
        isTrendPositive: true,
        selectedDays: data.selectedDays,
        sparklineSpots: const [
          FlSpot(0, 2),
          FlSpot(1, 4),
          FlSpot(2, 3),
          FlSpot(3, 5),
          FlSpot(4, 4),
          FlSpot(5, 7),
        ],
      ),
      _KpiCard(
        label: 'Appointments',
        value: '${data.totalAppointments}',
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFF8B5CF6),
        trendText: '18%',
        isTrendPositive: true,
        selectedDays: data.selectedDays,
        sparklineSpots: const [
          FlSpot(0, 10),
          FlSpot(1, 25),
          FlSpot(2, 20),
          FlSpot(3, 35),
          FlSpot(4, 45),
          FlSpot(5, 54),
        ],
      ),
      _KpiCard(
        label: 'Completed',
        value: '${data.completedAppointments}',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
        trendText: '18%',
        isTrendPositive: true,
        selectedDays: data.selectedDays,
        sparklineSpots: const [
          FlSpot(0, 1),
          FlSpot(1, 3),
          FlSpot(2, 2),
          FlSpot(3, 6),
          FlSpot(4, 5),
          FlSpot(5, 9),
        ],
      ),
      _KpiCard(
        label: 'Active Plans',
        value: '${data.activeTreatmentPlans}',
        icon: Icons.assignment_rounded,
        color: const Color(0xFFF59E0B),
        trendText: '14%',
        isTrendPositive: false,
        selectedDays: data.selectedDays,
        sparklineSpots: const [
          FlSpot(0, 5),
          FlSpot(1, 4),
          FlSpot(2, 6),
          FlSpot(3, 3),
          FlSpot(4, 5),
          FlSpot(5, 3),
        ],
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: c,
        ))).toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: cards,
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String trendText;
  final bool isTrendPositive;
  final List<FlSpot> sparklineSpots;
  final int selectedDays;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.trendText,
    required this.isTrendPositive,
    required this.sparklineSpots,
    required this.selectedDays,
  });

  @override
  Widget build(BuildContext context) {
    final trendColor = isTrendPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final trendIcon = isTrendPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final content = Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(isDesktop ? 8 : 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: isDesktop ? 20 : 18),
                ),
                SizedBox(height: isDesktop ? 12 : 8),
                Text(
                  label,
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isDesktop ? 6 : 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: context.textStyles.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 22 : 19,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(trendIcon, color: trendColor, size: 8),
                          const SizedBox(width: 1),
                          Text(
                            trendText,
                            style: TextStyle(
                              color: trendColor,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isDesktop ? 4 : 2),
                Text(
                  'vs last $selectedDays days',
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.textHint,
                    fontSize: isDesktop ? 10 : 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: isDesktop ? 60 : 50,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sparklineSpots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );

    if (isDesktop) {
      return WebGlassCard(
        borderRadius: 28,
        glowColor: color,
        padding: const EdgeInsets.all(16),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}

// ------
// Revenue Card
// ------

class _RevenueCard extends StatelessWidget {
  final AnalyticsData data;
  const _RevenueCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final formatted = NumberFormat('#,##,###').format(data.totalRevenue);
    final themeColor = const Color(0xFF0D9488); // Teal
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final leftFlex = isDesktop ? 3 : 5;
    final rightFlex = isDesktop ? 7 : 5;

    final content = Row(
        children: [
          Expanded(
            flex: leftFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_balance_wallet_rounded, color: themeColor, size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  'Total Revenue',
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '₹$formatted',
                      style: context.textStyles.h2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 24 : 20,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_upward_rounded, color: Color(0xFF10B981), size: 10),
                          SizedBox(width: 2),
                          Text(
                            '15%',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'vs last ${data.selectedDays} days',
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.textHint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: rightFlex,
            child: SizedBox(
              height: 120,
              child: Stack(
                children: [
                  LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 1000),
                            FlSpot(1, 1500),
                            FlSpot(2, 1200),
                            FlSpot(3, 2200),
                            FlSpot(4, 2500),
                            FlSpot(5, 3110),
                          ],
                          isCurved: true,
                          color: themeColor,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                themeColor.withValues(alpha: 0.25),
                                themeColor.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Text(
                      'From Consultations + Sessions',
                      style: context.textStyles.caption.copyWith(
                        color: context.colors.textHint,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

    if (isDesktop) {
      return WebGlassCard(
        borderRadius: 28,
        glowColor: themeColor,
        padding: const EdgeInsets.all(18),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}

// ------
// Today's Snapshot
// ------

class _TodaySnapshotRow extends StatelessWidget {
  final AnalyticsData data;
  const _TodaySnapshotRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final content = Row(
        children: [
          _TodayTile(
            label: 'Scheduled',
            value: data.todayScheduled,
            color: _kScheduled,
            icon: Icons.schedule_rounded,
          ),
          _divider(context),
          _TodayTile(
            label: 'Completed',
            value: data.todayCompleted,
            color: _kCompleted,
            icon: Icons.check_circle_rounded,
          ),
          _divider(context),
          _TodayTile(
            label: 'Cancelled',
            value: data.todayCancelled,
            color: _kCancelled,
            icon: Icons.cancel_rounded,
          ),
        ],
      );

    if (isDesktop) {
      return WebGlassCard(
        borderRadius: 28,
        glowColor: context.colors.primary,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 40,
        color: context.colors.border.withValues(alpha: 0.4),
        margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ------
// 7-Day Activity Line Chart
// ------

class _WeeklyActivityChart extends StatelessWidget {
  final AnalyticsData data;
  const _WeeklyActivityChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> completedSpots = [];
    final List<FlSpot> scheduledSpots = [];
    final List<FlSpot> cancelledSpots = [];
    for (int i = 0; i < 7; i++) {
      completedSpots.add(FlSpot(i.toDouble(), data.weeklyCompleted.length > i ? data.weeklyCompleted[i].toDouble() : 0.0));
      scheduledSpots.add(FlSpot(i.toDouble(), data.weeklyScheduled.length > i ? data.weeklyScheduled[i].toDouble() : 0.0));
      cancelledSpots.add(FlSpot(i.toDouble(), data.weeklyCancelled.length > i ? data.weeklyCancelled[i].toDouble() : 0.0));
    }

    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _Legend(color: _kCompleted, label: 'Completed'),
              const SizedBox(width: 16),
              _Legend(color: _kScheduled, label: 'Scheduled'),
              const SizedBox(width: 16),
              _Legend(color: _kCancelled, label: 'Cancelled'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: context.colors.border.withValues(alpha: 0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(color: context.colors.textHint, fontSize: 10),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.weeklyDayLabels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            data.weeklyDayLabels[index],
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: completedSpots,
                    isCurved: true,
                    color: _kCompleted,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: scheduledSpots,
                    isCurved: true,
                    color: _kScheduled,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: cancelledSpots,
                    isCurved: true,
                    color: _kCancelled,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

    if (isDesktop) {
      return WebGlassCard(
        borderRadius: 28,
        glowColor: context.colors.primary,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
      ),
      child: content,
    );
  }
}

// ------
// Hourly Volume Bar Chart
// ------

class _HourlyVolumeChart extends StatelessWidget {
  final AnalyticsData data;
  const _HourlyVolumeChart({required this.data});

  static const _start = 8;
  static const _end = 20;

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(_end - _start + 1, (i) => _start + i);
    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < hours.length; i++) {
      final hour = hours[i];
      final count = data.hourlyDistribution[hour] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: context.colors.primary,
              width: 12,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 10,
                color: context.colors.border.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final content = Column(
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.colors.border.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(color: context.colors.textHint, fontSize: 10),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= hours.length) return const SizedBox();
                        final hour = hours[idx];
                        if (hour % 2 != 0) return const SizedBox();
                        final d = DateTime(2024, 1, 1, hour);
                        final label = DateFormat('h a').format(d);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      );

    if (isDesktop) {
      return WebGlassCard(
        borderRadius: 28,
        glowColor: context.colors.primary,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: content,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
      ),
      child: content,
    );
  }
}

// ------
// Peak and Quiet Hours Insight Row
// ------

class _PeakInsightRow extends StatelessWidget {
  final AnalyticsData data;
  const _PeakInsightRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final peakFmt = DateFormat('h a').format(DateTime(2024, 1, 1, data.peakHour));
    final lowFmt = DateFormat('h a').format(DateTime(2024, 1, 1, data.lowHour));

    return Row(
      children: [
        Expanded(
          child: _InsightChip(
            icon: Icons.trending_up_rounded,
            label: 'Peak Hour',
            value: peakFmt,
            color: const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InsightChip(
            icon: Icons.trending_down_rounded,
            label: 'Quiet Hour',
            value: lowFmt,
            color: const Color(0xFF3B82F6),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textStyles.caption.copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------
// Appointment Type Split Donut Chart
// ------

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
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          // Donut
          SizedBox(
            width: 120,
            height: 120,
            child: total == 0
                ? _emptyDonut(context)
                : PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          value: data.consultationCount.toDouble(),
                          color: context.colors.primary,
                          radius: 12,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: data.sessionAppointmentCount.toDouble(),
                          color: _kAccent,
                          radius: 12,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 24),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TypeRow(
                  color: context.colors.primary,
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
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          color: color,
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          '${(pct * 100).toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ------
// Session Performance
// ------

class _SessionPerformanceRow extends StatelessWidget {
  final AnalyticsData data;
  const _SessionPerformanceRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.sessionsCompleted + data.sessionsMissed + data.sessionsCancelled;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
      ),
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
              style: TextStyle(
                fontSize: 10,
                color: context.colors.textSecondary,
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

// ------
// Consultation to Plan Conversion Card
// ------

class _PlanConversionCard extends StatelessWidget {
  final AnalyticsData data;
  const _PlanConversionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = data.planConversionRate;
    final pctDisplay = (pct * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          // Radial Progress Gauge
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
                    strokeWidth: 8,
                    backgroundColor: context.colors.border.withValues(alpha: 0.3),
                    color: const Color(0xFF10B981),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$pctDisplay%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversion Stats',
                  style: context.textStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                _StatRow(
                  label: 'Total Consultations',
                  value: '${data.totalConsultations}',
                  color: context.colors.primary,
                ),
                const SizedBox(height: 6),
                _StatRow(
                  label: 'With Treatment Plan',
                  value: '${data.consultationsWithPlan}',
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 6),
                _StatRow(
                  label: 'Without Plan',
                  value: '${(data.totalConsultations - data.consultationsWithPlan).clamp(0, 9999)}',
                  color: const Color(0xFFF59E0B),
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
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
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
    final colors = [context.colors.primary, _kAccent, _kMissed];
    final entries = data.genderDistribution.entries.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(context),
      child: Column(
        children: [
          Text(
            'Gender',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: total == 0
                ? _emptyDonut(context)
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
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
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
    final colors = [_kAccent, context.colors.primary, _kCompleted, _kMissed];
    final entries = data.ageGroupDistribution.entries.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(context),
      child: Column(
        children: [
          Text(
            'Age Groups',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
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
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
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
                    backgroundColor: context.colors.border,
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

// ------
// Location Distribution
// ------

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
        decoration: _cardDeco(context),
        child: Center(
          child: Text(
            'No location data yet',
            style: TextStyle(color: context.colors.textHint),
          ),
        ),
      );
    }

    final barColors = [
      context.colors.primary,
      _kAccent,
      _kCompleted,
      _kMissed,
      _kCancelled,
      context.colors.primaryLight,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(context),
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
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
                        backgroundColor: context.colors.border,
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

// ------
// Overall Performance Metrics
// ------

class _PerformanceMetricsCard extends StatelessWidget {
  final AnalyticsData data;
  const _PerformanceMetricsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final completionPct = (data.completionRate * 100).toStringAsFixed(1);
    final cancelPct = (data.cancellationRate * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(context),
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
            color: context.colors.primary,
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                color: color,
                backgroundColor: context.colors.border,
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

// ------
// Shared helpers
// ------

BoxDecoration _cardDeco(BuildContext context) {
  return BoxDecoration(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: context.colors.border),
    boxShadow: [
      BoxShadow(
        color: context.colors.textPrimary.withValues(alpha: 0.04),
        blurRadius: 14,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

Widget _emptyDonut(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: context.colors.border, width: 8),
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
          style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}
