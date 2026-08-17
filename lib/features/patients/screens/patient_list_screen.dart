import 'dart:ui';
import 'package:flutter/foundation.dart' show AsyncCallback, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pms_app/core/utils/whatsapp_helper.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/patients/providers/patient_provider.dart';
import 'package:pms_app/features/analytics/screens/analytics_screen.dart';
import 'package:pms_app/core/widgets/shimmer_effect.dart';
import 'package:pms_app/features/patients/screens/patient_profile_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/responsive_wrapper.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/utils/error_formatter.dart';
import 'package:pms_app/features/appointments/providers/appointment_provider.dart';
import 'package:pms_app/features/dashboard/widgets/dashboard_widgets.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  String _searchQuery = '';
  String _sortMode = 'recent';
  String _lastVisitFilter = 'all'; // 'all', 'month', '30days', '90days'
  String _statusFilter = 'all';    // 'all', 'active', 'new'
  String _kpiFilter = 'all';       // 'all', 'visited_this_month', 'due_follow_up', 'new_this_month'
  final _searchCtrl = TextEditingController();

  // Only used on web (matches mockup 7 rows)
  static const int _pageSize = 7;
  int _currentPage = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, DateTime> _lastVisitDates = const {};
  Set<String> _arrivedPatientIds = const {};

  List<PatientModel> _filtered(List<PatientModel> all) {
    List<PatientModel> result = all;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((p) =>
              p.fullName.toLowerCase().contains(q) || p.phone.contains(q))
          .toList();
    }

    // Filter by Last Visit
    if (_lastVisitFilter != 'all') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      result = result.where((p) {
        final lastVisit = _lastVisitDates[p.id];
        if (lastVisit == null) return false;
        final diffDays = today.difference(DateTime(lastVisit.year, lastVisit.month, lastVisit.day)).inDays;

        if (_lastVisitFilter == 'month') {
          return lastVisit.year == now.year && lastVisit.month == now.month;
        } else if (_lastVisitFilter == '30days') {
          return diffDays <= 30;
        } else if (_lastVisitFilter == '90days') {
          return diffDays <= 90;
        }
        return true;
      }).toList();
    }

    // Filter by Status
    if (_statusFilter != 'all') {
      final now = DateTime.now();
      result = result.where((p) {
        final lastVisit = _lastVisitDates[p.id];
        if (_statusFilter == 'active') {
          return lastVisit != null;
        } else if (_statusFilter == 'new') {
          return lastVisit == null;
        } else if (_statusFilter == 'arrived') {
          final isArrived = _arrivedPatientIds.contains(p.id);
          final isVisitedToday = lastVisit != null &&
              lastVisit.year == now.year &&
              lastVisit.month == now.month &&
              lastVisit.day == now.day;
          return isArrived || isVisitedToday;
        }
        return true;
      }).toList();
    }

    // Filter by KPI
    if (_kpiFilter != 'all') {
      final now = DateTime.now();
      result = result.where((p) {
        if (_kpiFilter == 'visited_this_month') {
          final lastVisit = _lastVisitDates[p.id];
          if (lastVisit == null) return false;
          return lastVisit.year == now.year && lastVisit.month == now.month;
        } else if (_kpiFilter == 'due_follow_up') {
          final lastVisit = _lastVisitDates[p.id];
          if (lastVisit == null) return false;
          final today = DateTime(now.year, now.month, now.day);
          final diff = today.difference(DateTime(lastVisit.year, lastVisit.month, lastVisit.day)).inDays;
          return diff >= 30;
        } else if (_kpiFilter == 'new_this_month') {
          final created = p.created;
          if (created == null) return false;
          return created.year == now.year && created.month == now.month;
        }
        return true;
      }).toList();
    }

    switch (_sortMode) {
      case 'a-z':
        result = List.of(result)
          ..sort((a, b) =>
              a.fullName.trim().toLowerCase().compareTo(b.fullName.trim().toLowerCase()));
        break;
      case 'z-a':
        result = List.of(result)
          ..sort((a, b) =>
              b.fullName.trim().toLowerCase().compareTo(a.fullName.trim().toLowerCase()));
        break;
      case 'phone':
        result = List.of(result)
          ..sort((a, b) => a.phone.compareTo(b.phone));
        break;
      case 'last_visit_desc':
        result = List.of(result)
          ..sort((a, b) => (_lastVisitDates[b.id] ?? DateTime(2000))
              .compareTo(_lastVisitDates[a.id] ?? DateTime(2000)));
        break;
      case 'last_visit_asc':
        result = List.of(result)
          ..sort((a, b) => (_lastVisitDates[a.id] ?? DateTime(2000))
              .compareTo(_lastVisitDates[b.id] ?? DateTime(2000)));
        break;
      case 'recent':
      default:
        result = List.of(result)
          ..sort((a, b) {
            final bTime = b.created ?? b.updated ?? DateTime(2000);
            final aTime = a.created ?? a.updated ?? DateTime(2000);
            final cmp = bTime.compareTo(aTime);
            if (cmp != 0) return cmp;
            return b.id.compareTo(a.id);
          });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientListProvider);
    _lastVisitDates = state.lastVisitDates;
    _arrivedPatientIds = state.arrivedPatientIds;
    final filteredList = _filtered(state.patients);

    if (kIsWeb) {
      return _WebPatientScreen(
        searchCtrl: _searchCtrl,
        searchQuery: _searchQuery,
        sortMode: _sortMode,
        lastVisitFilter: _lastVisitFilter,
        statusFilter: _statusFilter,
        currentPage: _currentPage,
        pageSize: _pageSize,
        filteredList: filteredList,
        kpiFilter: _kpiFilter,
        onKpiFilterChanged: (v) => setState(() {
          _kpiFilter = v;
          _currentPage = 0;
        }),
        onSearchChanged: (v) => setState(() {
          _searchQuery = v;
          _currentPage = 0;
        }),
        onSortChanged: (m) => setState(() {
          _sortMode = m;
          _currentPage = 0;
        }),
        onLastVisitFilterChanged: (v) => setState(() {
          _lastVisitFilter = v;
          _currentPage = 0;
        }),
        onStatusFilterChanged: (v) => setState(() {
          _statusFilter = v;
          _currentPage = 0;
        }),
        onClearFilters: () => setState(() {
          _searchQuery = '';
          _searchCtrl.clear();
          _sortMode = 'recent';
          _lastVisitFilter = 'all';
          _statusFilter = 'all';
          _currentPage = 0;
        }),
        onPageChanged: (p) => setState(() => _currentPage = p),
        onNavigateToAppointment: (isCallBy) {
          context.push(
            '/appointments/create',
            extra: {'isCallBy': isCallBy},
          ).then((_) {
            ref.read(appointmentListProvider.notifier).loadAppointments();
          });
        },
        onRetry: () => ref.read(patientListProvider.notifier).loadPatients(),
        onRefresh: () => ref.read(patientListProvider.notifier).loadPatients(),
        onOpenProfile: (p) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PatientProfileScreen(patient: p)),
        ),
      );
    } else {
      return _AppPatientScreen(
        searchCtrl: _searchCtrl,
        searchQuery: _searchQuery,
        sortMode: _sortMode,
        statusFilter: _statusFilter,
        filtered: _filtered,
        onSearchChanged: (v) => setState(() {
          _searchQuery = v;
        }),
        onSortChanged: (m) => setState(() {
          _sortMode = m;
          _statusFilter = 'all';
        }),
        onStatusFilterChanged: (s) => setState(() {
          _statusFilter = s;
        }),
        onNavigateToAppointment: (isCallBy) {
          context.push(
            '/appointments/create',
            extra: {'isCallBy': isCallBy},
          ).then((_) {
            ref.read(appointmentListProvider.notifier).loadAppointments();
          });
        },
        onRetry: () => ref.read(patientListProvider.notifier).loadPatients(),
        onRefresh: () => ref.read(patientListProvider.notifier).loadPatients(),
        onOpenProfile: (p) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PatientProfileScreen(patient: p)),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEB LAYOUT — redesigned table layout
// ─────────────────────────────────────────────────────────────────────────────

class _WebPatientScreen extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final String sortMode;
  final String lastVisitFilter;
  final String statusFilter;
  final String kpiFilter;
  final int currentPage;
  final int pageSize;
  final List<PatientModel> filteredList;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onLastVisitFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onKpiFilterChanged;
  final VoidCallback onClearFilters;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<bool> onNavigateToAppointment;
  final VoidCallback onRetry;
  final AsyncCallback onRefresh;
  final ValueChanged<PatientModel> onOpenProfile;

  const _WebPatientScreen({
    required this.searchCtrl,
    required this.searchQuery,
    required this.sortMode,
    required this.lastVisitFilter,
    required this.statusFilter,
    required this.kpiFilter,
    required this.currentPage,
    required this.pageSize,
    required this.filteredList,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onLastVisitFilterChanged,
    required this.onStatusFilterChanged,
    required this.onKpiFilterChanged,
    required this.onClearFilters,
    required this.onPageChanged,
    required this.onNavigateToAppointment,
    required this.onRetry,
    required this.onRefresh,
    required this.onOpenProfile,
  });

  Widget _buildNewAppointmentButton(BuildContext context) {
    return PopupMenuButton<bool>(
      onSelected: onNavigateToAppointment,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: true,
          child: Row(
            children: [
              Icon(Icons.event_note_rounded, color: const Color(0xFF0F5D4F), size: 18),
              const SizedBox(width: 10),
              Text('Call-By Appointment', style: context.textStyles.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem(
          value: false,
          child: Row(
            children: [
              Icon(Icons.directions_walk_rounded, color: const Color(0xFF10B981), size: 18),
              const SizedBox(width: 10),
              Text('Walk-In Appointment', style: context.textStyles.bodyMedium),
            ],
          ),
        ),
      ],
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F5D4F),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'New Appointment',
              style: context.textStyles.buttonMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 20,
              width: 1,
              color: Colors.white24,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSidebar(BuildContext context) {
    final sortOptions = [
      {'value': 'recent', 'label': 'Recent', 'icon': Icons.schedule_rounded},
      {'value': 'a-z', 'label': 'A - Z', 'icon': Icons.sort_by_alpha_rounded},
      {'value': 'z-a', 'label': 'Z - A', 'icon': Icons.sort_by_alpha_rounded},
      {'value': 'phone', 'label': 'Phone', 'icon': Icons.dialpad_rounded},
    ];

    final Map<String, String> lastVisitLabels = {
      'all': 'All Time',
      'month': 'This Month',
      '30days': 'Last 30 Days',
      '90days': 'Last 90 Days',
    };

    final Map<String, String> statusLabels = {
      'all': 'All Patients',
      'active': 'Active / Returning',
      'new': 'New (No visit yet)',
      'arrived': 'Arrived (Today)',
    };

    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter & Sort',
                    style: context.textStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Sort By
                  Text(
                    'Sort By',
                    style: context.textStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...sortOptions.map((opt) {
                    final isSelected = sortMode == opt['value'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () => onSortChanged(opt['value'] as String),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0F5D4F).withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                opt['icon'] as IconData,
                                size: 16,
                                color: isSelected ? const Color(0xFF0F5D4F) : context.colors.textMuted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  opt['label'] as String,
                                  style: context.textStyles.bodyMedium.copyWith(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF0F5D4F) : context.colors.textSecondary,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Color(0xFF0F5D4F),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 20),
                  
                  // Last Visit Dropdown
                  Text(
                    'Last Visit',
                    style: context.textStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    onSelected: onLastVisitFilterChanged,
                    offset: const Offset(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    itemBuilder: (ctx) => lastVisitLabels.entries.map((e) => PopupMenuItem(
                      value: e.key,
                      child: Text(e.value, style: context.textStyles.bodyMedium),
                    )).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastVisitLabels[lastVisitFilter] ?? 'All Time',
                              style: context.textStyles.bodyMedium.copyWith(fontSize: 13, color: context.colors.textSecondary),
                            ),
                          ),
                          Icon(Icons.calendar_today_rounded, size: 14, color: context.colors.textMuted),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Status Dropdown
                  Text(
                    'Status',
                    style: context.textStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    onSelected: onStatusFilterChanged,
                    offset: const Offset(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    itemBuilder: (ctx) => statusLabels.entries.map((e) => PopupMenuItem(
                      value: e.key,
                      child: Text(e.value, style: context.textStyles.bodyMedium),
                    )).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              statusLabels[statusFilter] ?? 'All Patients',
                              style: context.textStyles.bodyMedium.copyWith(fontSize: 13, color: context.colors.textSecondary),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: context.colors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Clear Filters Button
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16, color: Color(0xFF0F5D4F)),
              label: Text(
                'Clear Filters',
                style: context.textStyles.buttonMedium.copyWith(
                  color: const Color(0xFF0F5D4F),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF0F5D4F).withOpacity(0.06),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patientListProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Dynamic KPI stats calculations
    final totalPatients = state.patients.length;
    final visitedThisMonth = state.lastVisitDates.values
        .where((d) => d.year == now.year && d.month == now.month)
        .length;
    final dueFollowUp = state.patients.where((p) {
      final lastVisit = state.lastVisitDates[p.id];
      if (lastVisit == null) return false;
      final diff = today.difference(DateTime(lastVisit.year, lastVisit.month, lastVisit.day)).inDays;
      return diff >= 30; // 30+ days ago is due for follow-up
    }).length;
    final newThisMonth = state.patients.where((p) {
      final created = p.created;
      if (created == null) return false;
      return created.year == now.year && created.month == now.month;
    }).length;

    // Pagination
    final totalPages = filteredList.isEmpty ? 1 : (filteredList.length / pageSize).ceil();
    final pageStart = currentPage * pageSize;
    final pageEnd = (pageStart + pageSize).clamp(0, filteredList.length);
    final pageItems = filteredList.isEmpty
        ? <PatientModel>[]
        : filteredList.sublist(pageStart, pageEnd);

    return Scaffold(
      backgroundColor: isDesktop ? Colors.transparent : context.colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(isDesktop ? 36 : 24, 20, isDesktop ? 36 : 24, 0),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patients',
                              style: context.textStyles.h1.copyWith(
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your patients and their information',
                              style: context.textStyles.bodyMedium.copyWith(
                                color: context.colors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        _WebSearchBar(
                          controller: searchCtrl,
                          onChanged: onSearchChanged,
                        ),
                        const SizedBox(width: 12),
                        _buildNewAppointmentButton(context),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Patients',
                                    style: context.textStyles.h1
                                        .copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  'Manage your patients',
                                  style: context.textStyles.bodyMedium.copyWith(
                                      color: context.colors.textSecondary),
                                ),
                              ],
                            ),
                            const Spacer(),
                            PopupMenuButton<bool>(
                              onSelected: onNavigateToAppointment,
                              offset: const Offset(0, 44),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              color: context.colors.surface,
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: true,
                                  child: Row(children: [
                                    Icon(Icons.event_note_rounded,
                                        color: context.colors.info, size: 18),
                                    const SizedBox(width: 10),
                                    Text('Call-By',
                                        style: context.textStyles.bodyMedium),
                                  ]),
                                ),
                                PopupMenuItem(
                                  value: false,
                                  child: Row(children: [
                                    Icon(Icons.directions_walk_rounded,
                                        color: context.colors.accent, size: 18),
                                    const SizedBox(width: 10),
                                    Text('Walk-In',
                                        style: context.textStyles.bodyMedium),
                                  ]),
                                ),
                              ],
                              child: Container(
                                height: 40,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: context.colors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add,
                                        color: context.colors.textPrimary, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _WebSearchBar(
                          controller: searchCtrl,
                          onChanged: onSearchChanged,
                          fullWidth: true,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),

            // ── KPI Stats Cards (Desktop Only) ──
            if (isDesktop) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Row(
                  children: [
                    _StatCard(
                      label: 'Total Patients',
                      value: '$totalPatients',
                      subLabel: 'Registered',
                      icon: Icons.people_alt_outlined,
                      iconColor: const Color(0xFF0F5D4F),
                      iconBgColor: const Color(0xFFEEF7F4),
                      isSelected: kpiFilter == 'all',
                      onTap: () => onKpiFilterChanged('all'),
                    ),
                    const SizedBox(width: 16),
                    _StatCard(
                      label: 'Visited This Month',
                      value: '$visitedThisMonth',
                      subLabel: 'Patients',
                      icon: Icons.calendar_today_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      iconBgColor: const Color(0xFFF3E8FF),
                      isSelected: kpiFilter == 'visited_this_month',
                      onTap: () => onKpiFilterChanged('visited_this_month'),
                    ),
                    const SizedBox(width: 16),
                    _StatCard(
                      label: 'Due for Follow Up',
                      value: '$dueFollowUp',
                      subLabel: 'Patients',
                      icon: Icons.history_rounded,
                      iconColor: const Color(0xFFD97706),
                      iconBgColor: const Color(0xFFFEF3C7),
                      isSelected: kpiFilter == 'due_follow_up',
                      onTap: () => onKpiFilterChanged('due_follow_up'),
                    ),
                    const SizedBox(width: 16),
                    _StatCard(
                      label: 'New This Month',
                      value: '$newThisMonth',
                      subLabel: 'Patients',
                      icon: Icons.person_add_alt_1_outlined,
                      iconColor: const Color(0xFF0284C7),
                      iconBgColor: const Color(0xFFE0F2FE),
                      isSelected: kpiFilter == 'new_this_month',
                      onTap: () => onKpiFilterChanged('new_this_month'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // ── Main Content Area ──
            Expanded(
              child: state.isLoading
                  ? _buildSkeletonList(context)
                  : state.error != null
                      ? _WebErrorView(error: state.error!, onRetry: onRetry)
                      : filteredList.isEmpty
                          ? _WebEmptyView(hasQuery: searchQuery.isNotEmpty)
                          : Padding(
                              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 24),
                              child: isDesktop
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildFilterSidebar(context),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: RefreshIndicator(
                                                  color: context.colors.primary,
                                                  onRefresh: onRefresh,
                                                  child: _WebDesktopTable(
                                                    patients: pageItems,
                                                    onPatientTap: onOpenProfile,
                                                    sortMode: sortMode,
                                                    onSortChanged: onSortChanged,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              _WebPaginationBar(
                                                currentPage: currentPage,
                                                totalPages: totalPages,
                                                totalItems: filteredList.length,
                                                pageStart: pageStart,
                                                pageEnd: pageEnd,
                                                onPageChanged: onPageChanged,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        Expanded(
                                          child: RefreshIndicator(
                                            color: context.colors.primary,
                                            onRefresh: onRefresh,
                                            child: _WebMobileList(
                                              patients: pageItems,
                                              onPatientTap: onOpenProfile,
                                            ),
                                          ),
                                        ),
                                        if (filteredList.length > pageSize)
                                          _WebPaginationBar(
                                            currentPage: currentPage,
                                            totalPages: totalPages,
                                            totalItems: filteredList.length,
                                            pageStart: pageStart,
                                            pageEnd: pageEnd,
                                            onPageChanged: onPageChanged,
                                          ),
                                      ],
                                    ),
                            ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      itemCount: 8,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShimmerEffect(
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subLabel;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback? onTap;
  final bool isSelected;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subLabel,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected ? context.colors.primary.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected 
                    ? context.colors.primary 
                    : context.colors.border.withValues(alpha: 0.4),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (!isSelected)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.textStyles.caption.copyWith(
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: context.textStyles.h2.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: context.textStyles.caption.copyWith(
                      color: context.colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
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

// ─────────────────────────────────────────────────────────────────────────────
// WEB COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _WebSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool fullWidth;
  const _WebSearchBar({
    required this.controller,
    required this.onChanged,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: fullWidth ? double.infinity : 300,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: context.colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 18, color: context.colors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: context.textStyles.bodyMedium.copyWith(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by name or phone number...',
                hintStyle: context.textStyles.caption
                    .copyWith(fontSize: 13, color: context.colors.textHint),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.close_rounded,
                    size: 16, color: context.colors.textHint),
              ),
            ),
        ],
      ),
    );
  }
}
class _WebDesktopTable extends StatelessWidget {
  final List<PatientModel> patients;
  final ValueChanged<PatientModel> onPatientTap;
  final String sortMode;
  final ValueChanged<String> onSortChanged;
  const _WebDesktopTable({
    required this.patients,
    required this.onPatientTap,
    required this.sortMode,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: constraints.maxWidth > 700 ? constraints.maxWidth : 700,
              child: Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _tableHeader(context, 'Patient'),
                        ),
                        Expanded(flex: 2, child: _tableHeader(context, 'Phone')),
                        Expanded(
                          flex: 2, 
                          child: _tableHeader(
                            context, 
                            'Last Visit',
                            isSortable: sortMode.startsWith('last_visit'),
                            isAscending: sortMode == 'last_visit_asc',
                            onTap: () {
                              if (sortMode == 'last_visit_desc') {
                                onSortChanged('last_visit_asc');
                              } else {
                                onSortChanged('last_visit_desc');
                              }
                            },
                          ),
                        ),
                        const SizedBox(
                          width: 120,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Actions',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  // Rows
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: patients.length,
                      itemBuilder: (context, index) {
                        return _WebAnimatedRow(
                          index: index,
                          child: _WebDesktopTableRow(
                            patient: patients[index],
                            onTap: () => onPatientTap(patients[index]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tableHeader(
    BuildContext context,
    String label, {
    bool isSortable = false,
    bool isAscending = false,
    VoidCallback? onTap,
  }) {
    Widget content = Text(
      label,
      style: context.textStyles.caption.copyWith(
        color: context.colors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.3,
      ),
    );

    if (isSortable || onTap != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          if (isSortable) ...[
            const SizedBox(width: 4),
            Icon(
              isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 14,
              color: context.colors.primary,
            ),
          ] else if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.unfold_more_rounded,
              size: 14,
              color: context.colors.textHint,
            ),
          ],
        ],
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: content,
        ),
      );
    }

    return content;
  }
}

class _WebDesktopTableRow extends ConsumerStatefulWidget {
  final PatientModel patient;
  final VoidCallback onTap;
  const _WebDesktopTableRow({required this.patient, required this.onTap});

  @override
  ConsumerState<_WebDesktopTableRow> createState() => _WebDesktopTableRowState();
}

class _WebDesktopTableRowState extends ConsumerState<_WebDesktopTableRow> {
  bool _hovered = false;

  Widget _buildLastVisitColumn(BuildContext context, DateTime? date) {
    if (date == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '—',
            style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'No visit yet',
            style: context.textStyles.caption.copyWith(color: context.colors.textMuted, fontSize: 11),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visitDay = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(visitDay).inDays;

    String relativeText;
    Color relativeColor = const Color(0xFF10B981); // default green
    bool isToday = diffDays == 0;

    if (isToday) {
      relativeText = 'Today';
    } else if (diffDays == 1) {
      relativeText = 'Yesterday';
      relativeColor = context.colors.textSecondary;
    } else {
      relativeText = '$diffDays days ago';
      relativeColor = context.colors.textSecondary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DateFormat('MMM d, yyyy').format(date),
          style: context.textStyles.bodyMedium.copyWith(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          relativeText,
          style: context.textStyles.caption.copyWith(
            color: relativeColor,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.patient;
    
    final lastVisitDates = ref.watch(patientListProvider.select((s) => s.lastVisitDates));
    final lastVisitDate = lastVisitDates[patient.id];
    final initials =
        patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? context.colors.primary.withOpacity(0.02)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                  color: context.colors.border.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _WebAvatar(initials: initials, name: patient.fullName),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        patient.fullName,
                        style: context.textStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(Icons.phone_rounded,
                        size: 13, color: context.colors.textHint),
                    const SizedBox(width: 6),
                    Text(
                      patient.phone.isNotEmpty ? patient.phone : '\u2014',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildLastVisitColumn(context, lastVisitDate),
              ),
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (patient.phone.isNotEmpty)
                      GestureDetector(
                        onTap: () => WhatsAppHelper.openChat(patient.phone),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F5D4F).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0F5D4F), size: 16),
                        ),
                      ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, color: context.colors.textMuted),
                      offset: const Offset(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      color: Colors.white,
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 16, color: context.colors.textSecondary),
                              const SizedBox(width: 8),
                              Text('Open Profile', style: context.textStyles.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'profile') {
                          widget.onTap();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Mobile web list ─────────────────────────────────────────────────────────

class _WebMobileList extends StatelessWidget {
  final List<PatientModel> patients;
  final ValueChanged<PatientModel> onPatientTap;
  const _WebMobileList({required this.patients, required this.onPatientTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: context.colors.border.withValues(alpha: 0.5)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: patients.length,
            separatorBuilder: (ctx, i) => Divider(
              height: 1,
              color: context.colors.border.withValues(alpha: 0.4),
            ),
            itemBuilder: (context, index) {
              return _WebAnimatedRow(
                index: index,
                child: _WebMobileRow(
                  patient: patients[index],
                  onTap: () => onPatientTap(patients[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WebMobileRow extends StatelessWidget {
  final PatientModel patient;
  final VoidCallback onTap;
  const _WebMobileRow({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initials =
        patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _WebAvatar(initials: initials, name: patient.fullName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: context.textStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (patient.phone.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded,
                            size: 12, color: context.colors.textHint),
                        const SizedBox(width: 4),
                        Text(
                          patient.phone,
                          style: context.textStyles.caption.copyWith(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Web mobile — WhatsApp ONLY
            if (patient.phone.isNotEmpty)
              _WebActionBtn(
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                tooltip: 'WhatsApp',
                onTap: () => WhatsAppHelper.openChat(patient.phone),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: context.colors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Pagination ──────────────────────────────────────────────────────────────

class _WebPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageStart;
  final int pageEnd;
  final ValueChanged<int> onPageChanged;
  const _WebPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageStart,
    required this.pageEnd,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pages = List.generate(totalPages, (i) => i)
        .where((i) => (i - currentPage).abs() <= 2 || i == 0 || i == totalPages - 1)
        .toList();

    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 36 : 24, 8, isDesktop ? 36 : 24, 12),
      child: Row(
        children: [
          Text(
            'Showing ${pageStart + 1}\u2013$pageEnd of $totalItems patients',
            style: context.textStyles.caption.copyWith(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          _PgBtn(
            label: '< Prev',
            enabled: currentPage > 0,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 6),
          for (int i = 0; i < pages.length; i++) ...[
            if (i > 0 && pages[i] - pages[i - 1] > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('\u2026',
                    style: TextStyle(color: context.colors.textHint)),
              ),
            _PgNum(
              page: pages[i],
              isCurrent: pages[i] == currentPage,
              onTap: () => onPageChanged(pages[i]),
            ),
          ],
          const SizedBox(width: 6),
          _PgBtn(
            label: 'Next >',
            enabled: currentPage < totalPages - 1,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _PgBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _PgBtn({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: context.colors.border.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: context.textStyles.caption.copyWith(
            fontSize: 12,
            color:
                enabled ? context.colors.textPrimary : context.colors.textHint,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PgNum extends StatelessWidget {
  final int page;
  final bool isCurrent;
  final VoidCallback onTap;
  const _PgNum(
      {required this.page, required this.isCurrent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isCurrent ? context.colors.primary : context.colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent
                ? context.colors.primary
                : context.colors.border.withValues(alpha: 0.5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${page + 1}',
          style: context.textStyles.caption.copyWith(
            fontSize: 12,
            color: isCurrent ? Colors.white : context.colors.textSecondary,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Shared web helpers ──────────────────────────────────────────────────────

class _WebAvatar extends StatelessWidget {
  final String initials;
  final String name;
  const _WebAvatar({required this.initials, required this.name});

  static const _colors = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[name.hashCode.abs() % _colors.length];
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
            color: color, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _WebActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _WebActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

class _WebEmptyView extends StatelessWidget {
  final bool hasQuery;
  const _WebEmptyView({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery
                ? Icons.search_off_rounded
                : Icons.people_outline_rounded,
            size: 56,
            color: context.colors.textHint.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No matches found' : 'No patients registered yet',
            style: context.textStyles.bodyMedium
                .copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WebErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _WebErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: context.colors.error),
            const SizedBox(height: 12),
            Text(
              ErrorFormatter.format(error),
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium
                  .copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Web animated row stagger ────────────────────────────────────────────────

class _WebAnimatedRow extends StatefulWidget {
  final Widget child;
  final int index;
  const _WebAnimatedRow({required this.child, required this.index});

  @override
  State<_WebAnimatedRow> createState() => _WebAnimatedRowState();
}

class _WebAnimatedRowState extends State<_WebAnimatedRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 40),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP — Animated card (original, for mobile only)
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final int index;
  const _AnimatedCard({required this.child, required this.index});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _AppPatientScreen extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final String sortMode;
  final String statusFilter;
  final List<PatientModel> Function(List<PatientModel>) filtered;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<bool> onNavigateToAppointment;
  final VoidCallback onRetry;
  final AsyncCallback onRefresh;
  final ValueChanged<PatientModel> onOpenProfile;

  const _AppPatientScreen({
    required this.searchCtrl,
    required this.searchQuery,
    required this.sortMode,
    required this.statusFilter,
    required this.filtered,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onStatusFilterChanged,
    required this.onNavigateToAppointment,
    required this.onRetry,
    required this.onRefresh,
    required this.onOpenProfile,
  });

  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF0D9488), Color(0xFF14B8A6)], // Emerald / Teal
    [Color(0xFF2563EB), Color(0xFF60A5FA)], // Royal Blue
    [Color(0xFF7C3AED), Color(0xFFA78BFA)], // Violet
    [Color(0xFFD97706), Color(0xFFFBBF24)], // Amber
    [Color(0xFF0284C7), Color(0xFF38BDF8)], // Cyan
    [Color(0xFFE11D48), Color(0xFFFB7185)], // Rose
    [Color(0xFF059669), Color(0xFF34D399)], // Jade Green
    [Color(0xFF4F46E5), Color(0xFF818CF8)], // Indigo
  ];

  static List<Color> _getAvatarGradient(String name) {
    if (name.isEmpty) return _avatarGradients[0];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return _avatarGradients[hash % _avatarGradients.length];
  }

  String _formatPhoneNumber(String raw) {
    if (raw.isEmpty) return raw;
    final cleaned = raw.replaceAll(' ', '');
    if (cleaned.startsWith('+91') && cleaned.length == 13) {
      return '+91 ${cleaned.substring(3, 8)} ${cleaned.substring(8)}';
    } else if (cleaned.length == 10 && !cleaned.startsWith('+')) {
      return '${cleaned.substring(0, 5)} ${cleaned.substring(5)}';
    }
    return raw;
  }

  String _formatLastVisit(DateTime? dt, DateTime? createdDt) {
    if (dt == null) {
      if (createdDt != null) {
        return 'Added ${DateFormat('d MMM yyyy').format(createdDt)}';
      }
      return 'New Patient · No visits yet';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visitDay = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(visitDay).inDays;

    if (diffDays == 0) return 'Visited today';
    if (diffDays == 1) return 'Visited yesterday';
    if (diffDays < 7) return 'Visited $diffDays days ago';
    if (diffDays < 30) {
      final weeks = (diffDays / 7).floor();
      return 'Visited $weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    return 'Last visit: ${DateFormat('d MMM yyyy').format(dt)}';
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    try {
      await launchUrl(url);
    } catch (e) {
      debugPrint('Could not launch phone call: $e');
    }
  }

  void _showAppointmentTypeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Appointment',
                      style: context.textStyles.h3,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSelectorTile(
                  context: context,
                  icon: Icons.event_note_rounded,
                  color: context.colors.info,
                  title: 'Call-By Appointment',
                  subtitle: 'Schedule a pre-booked time slot via phone call',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToAppointment(true);
                  },
                ),
                const SizedBox(height: 12),
                _buildSelectorTile(
                  context: context,
                  icon: Icons.directions_walk_rounded,
                  color: context.colors.accent,
                  title: 'Walk-In Appointment',
                  subtitle: 'Register a patient waiting at the clinic',
                  onTap: () {
                    Navigator.pop(context);
                    onNavigateToAppointment(false);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectorTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patientListProvider);
    final filteredList = filtered(state.patients);

    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        shape: const CircleBorder(),
        backgroundColor: context.colors.primary,
        onPressed: () => _showAppointmentTypeSelector(context),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.colors.primary,
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header & Controls
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Title & Count Badge Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Patients',
                          style: context.textStyles.h1.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: context.colors.primary.withValues(alpha: 0.22),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${state.patients.length} Registered',
                            style: TextStyle(
                              color: context.colors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search and manage patient records',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Modern Search bar
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.7),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: context.colors.textHint, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              style: context.textStyles.bodyMedium.copyWith(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search by name or phone...',
                                hintStyle: context.textStyles.bodyMedium.copyWith(
                                  color: context.colors.textHint,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: onSearchChanged,
                            ),
                          ),
                          if (searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                searchCtrl.clear();
                                onSearchChanged('');
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, color: context.colors.textSecondary, size: 18),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Smart Filter & Sort Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _AppSortChip(
                            label: 'Recent',
                            icon: Icons.schedule_rounded,
                            isActive: sortMode == 'recent' && statusFilter == 'all',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSortChanged('recent');
                            },
                          ),
                          const SizedBox(width: 8),
                          _AppSortChip(
                            label: 'Arrived Today',
                            icon: Icons.directions_walk_rounded,
                            isActive: statusFilter == 'arrived',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onStatusFilterChanged(statusFilter == 'arrived' ? 'all' : 'arrived');
                            },
                          ),
                          const SizedBox(width: 8),
                          _AppSortChip(
                            label: 'New Patients',
                            icon: Icons.fiber_new_rounded,
                            isActive: statusFilter == 'new',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onStatusFilterChanged(statusFilter == 'new' ? 'all' : 'new');
                            },
                          ),
                          const SizedBox(width: 8),
                          _AppSortChip(
                            label: 'A–Z',
                            icon: Icons.sort_by_alpha_rounded,
                            isActive: sortMode == 'a-z' && statusFilter == 'all',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSortChanged('a-z');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ]),
                ),
              ),

              // Patient List View
              if (state.isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.colors.primary,
                      strokeWidth: 3,
                    ),
                  ),
                )
              else if (state.error != null)
                SliverFillRemaining(
                  child: _WebErrorView(error: state.error!, onRetry: onRetry),
                )
              else if (filteredList.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            searchQuery.isNotEmpty
                                ? Icons.search_off_rounded
                                : (statusFilter == 'arrived'
                                    ? Icons.directions_walk_rounded
                                    : Icons.people_outline_rounded),
                            size: 48,
                            color: context.colors.textHint.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            searchQuery.isNotEmpty
                                ? 'No matches for "$searchQuery"'
                                : (statusFilter == 'arrived'
                                    ? 'No patients marked arrived today'
                                    : (statusFilter == 'new'
                                        ? 'No new patients without visits'
                                        : 'No patients found')),
                            style: context.textStyles.bodyMedium.copyWith(
                              color: context.colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (statusFilter != 'all' || searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                searchCtrl.clear();
                                onSearchChanged('');
                                onSortChanged('recent');
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Reset filters'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final patient = filteredList[index];
                        final initials = patient.fullName.isNotEmpty
                            ? patient.fullName[0].toUpperCase()
                            : '?';
                        final lastVisit = state.lastVisitDates[patient.id];
                        final lastVisitStr = _formatLastVisit(lastVisit, patient.created);
                        final gradient = _getAvatarGradient(patient.fullName);

                        return _AnimatedCard(
                          index: index,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: context.colors.border.withValues(alpha: 0.65),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => onOpenProfile(patient),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Deterministic Avatar
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: gradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: gradient.first.withValues(alpha: 0.25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Patient Info Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Row 1: Name + Demographics Badge
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    patient.fullName,
                                                    style: context.textStyles.bodyMedium.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 15,
                                                      letterSpacing: -0.2,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (patient.age != null && patient.age! > 0) ...[
                                                  const SizedBox(width: 5),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: context.colors.divider.withValues(alpha: 0.35),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '${patient.age}y${patient.gender != null && patient.gender!.isNotEmpty ? '·${patient.gender![0].toUpperCase()}' : ''}',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: context.colors.textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2.5),

                                            // Row 2: Phone number & Patient ID Tag
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.phone_rounded,
                                                  size: 12,
                                                  color: context.colors.textSecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    _formatPhoneNumber(patient.phone),
                                                    style: context.textStyles.bodySmall.copyWith(
                                                      color: context.colors.textSecondary,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (patient.patientId != null && patient.patientId!.isNotEmpty) ...[
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                                    child: Text(
                                                      '·',
                                                      style: TextStyle(
                                                        color: context.colors.textHint,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    '#${patient.patientId}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: context.colors.textHint,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2.5),

                                            // Row 3: Last visit / Registration metadata
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.history_rounded,
                                                  size: 11.5,
                                                  color: context.colors.textHint,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    lastVisitStr,
                                                    style: context.textStyles.caption.copyWith(
                                                      color: context.colors.textHint,
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Micro-Action Buttons
                                      if (patient.phone.isNotEmpty) ...[
                                        // WhatsApp Button
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              WhatsAppHelper.openChat(patient.phone);
                                            },
                                            borderRadius: BorderRadius.circular(10),
                                            child: Ink(
                                              width: 35,
                                              height: 35,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF25D366).withValues(alpha: 0.10),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: const Color(0xFF25D366).withValues(alpha: 0.3),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.message_rounded,
                                                  color: Color(0xFF25D366),
                                                  size: 16.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Call Button
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              _makePhoneCall(patient.phone);
                                            },
                                            borderRadius: BorderRadius.circular(10),
                                            child: Ink(
                                              width: 35,
                                              height: 35,
                                              decoration: BoxDecoration(
                                                color: context.colors.primary.withValues(alpha: 0.09),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: context.colors.primary.withValues(alpha: 0.3),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.phone_rounded,
                                                  color: context.colors.primary,
                                                  size: 16.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: context.colors.textHint.withValues(alpha: 0.6),
                                        size: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filteredList.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppSortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _AppSortChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isActive
              ? context.colors.primary
              : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? context.colors.primary
                : context.colors.border.withValues(alpha: 0.7),
            width: 1.0,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : context.colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewAppointmentCTAButton extends StatefulWidget {
  const _NewAppointmentCTAButton();

  @override
  State<_NewAppointmentCTAButton> createState() => _NewAppointmentCTAButtonState();
}

class _NewAppointmentCTAButtonState extends State<_NewAppointmentCTAButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.diagonal3Values(_isHovered ? 1.03 : 1.0, _isHovered ? 1.03 : 1.0, 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: _isHovered ? 0.35 : 0.2),
              blurRadius: _isHovered ? 20 : 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF60A5FA).withValues(alpha: _isHovered ? 0.4 : 0.3),
                    const Color(0xFF1D4ED8).withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF60A5FA).withValues(alpha: _isHovered ? 0.45 : 0.35),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'New Appointment',
                    style: context.textStyles.buttonMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  VerticalDivider(color: Colors.white54, width: 1, indent: 10, endIndent: 10),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

