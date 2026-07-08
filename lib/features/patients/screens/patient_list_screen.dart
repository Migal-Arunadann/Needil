import 'dart:ui';
import 'package:flutter/foundation.dart' show AsyncCallback, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pms_app/core/utils/whatsapp_helper.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/patients/providers/patient_provider.dart';
import 'package:pms_app/features/patients/screens/patient_profile_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/responsive_wrapper.dart';
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
  final _searchCtrl = TextEditingController();

  // Only used on web
  static const int _pageSize = 10;
  int _currentPage = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PatientModel> _filtered(List<PatientModel> all) {
    List<PatientModel> result = all;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((p) =>
              p.fullName.toLowerCase().contains(q) || p.phone.contains(q))
          .toList();
    }
    switch (_sortMode) {
      case 'a-z':
        result = List.of(result)
          ..sort((a, b) =>
              a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        break;
      case 'z-a':
        result = List.of(result)
          ..sort((a, b) =>
              b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase()));
        break;
      case 'phone':
        result = List.of(result)
          ..sort((a, b) => a.phone.compareTo(b.phone));
        break;
      default:
        result = List.of(result)
          ..sort((a, b) => (b.created ?? DateTime(2000))
              .compareTo(a.created ?? DateTime(2000)));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _WebPatientScreen(
        searchCtrl: _searchCtrl,
        searchQuery: _searchQuery,
        sortMode: _sortMode,
        currentPage: _currentPage,
        pageSize: _pageSize,
        filtered: _filtered,
        onSearchChanged: (v) => setState(() {
          _searchQuery = v;
          _currentPage = 0;
        }),
        onSortChanged: (m) => setState(() {
          _sortMode = m;
          _currentPage = 0;
        }),
        onPageChanged: (p) => setState(() => _currentPage = p),
        onNavigateToAppointment: (isCallBy) {
          Navigator.pushNamed(
            context,
            '/appointments/create',
            arguments: {'isCallBy': isCallBy},
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
        filtered: _filtered,
        onSearchChanged: (v) => setState(() {
          _searchQuery = v;
        }),
        onSortChanged: (m) => setState(() {
          _sortMode = m;
        }),
        onNavigateToAppointment: (isCallBy) {
          Navigator.pushNamed(
            context,
            '/appointments/create',
            arguments: {'isCallBy': isCallBy},
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// WEB LAYOUT â€” redesigned table layout
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _WebPatientScreen extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final String sortMode;
  final int currentPage;
  final int pageSize;
  final List<PatientModel> Function(List<PatientModel>) filtered;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<bool> onNavigateToAppointment;
  final VoidCallback onRetry;
  final AsyncCallback onRefresh;
  final ValueChanged<PatientModel> onOpenProfile;

  const _WebPatientScreen({
    required this.searchCtrl,
    required this.searchQuery,
    required this.sortMode,
    required this.currentPage,
    required this.pageSize,
    required this.filtered,
    required this.onSearchChanged,
    required this.onSortChanged,
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
      color: context.colors.surface,
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: true,
          child: Row(
            children: [
              Icon(Icons.event_note_rounded, color: context.colors.info, size: 18),
              const SizedBox(width: 10),
              Text('Call-By Appointment', style: context.textStyles.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem(
          value: false,
          child: Row(
            children: [
              Icon(Icons.directions_walk_rounded, color: context.colors.accent, size: 18),
              const SizedBox(width: 10),
              Text('Walk-In Appointment', style: context.textStyles.bodyMedium),
            ],
          ),
        ),
      ],
      child: const _NewAppointmentCTAButton(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patientListProvider);
    final filteredList = filtered(state.patients);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

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
        child: ResponsiveWrapper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: EdgeInsets.fromLTRB(isDesktop ? 36 : 20, 20, isDesktop ? 36 : 20, 0),
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Patients',
                                style: context.textStyles.h1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${state.patients.length} total registered patients',
                                style: context.textStyles.bodyMedium.copyWith(
                                  color: context.colors.textSecondary,
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
                                    '${state.patients.length} total registered',
                                    style: context.textStyles.bodyMedium.copyWith(
                                        color: context.colors.textSecondary),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Compact button on narrow web
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
              const SizedBox(height: 16),

              // â”€â”€ Sort chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 20),
                child: Row(
                  children: [
                    _WebSortChip(
                      label: 'Recent',
                      icon: Icons.schedule_rounded,
                      isActive: sortMode == 'recent',
                      onTap: () => onSortChanged('recent'),
                    ),
                    const SizedBox(width: 8),
                    _WebSortChip(
                      label: 'A-Z',
                      icon: Icons.sort_by_alpha_rounded,
                      isActive: sortMode == 'a-z',
                      onTap: () => onSortChanged('a-z'),
                    ),
                    const SizedBox(width: 8),
                    _WebSortChip(
                      label: 'Z-A',
                      icon: Icons.sort_rounded,
                      isActive: sortMode == 'z-a',
                      onTap: () => onSortChanged('z-a'),
                    ),
                    const SizedBox(width: 8),
                    _WebSortChip(
                      label: 'Phone',
                      icon: Icons.dialpad_rounded,
                      isActive: sortMode == 'phone',
                      onTap: () => onSortChanged('phone'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Expanded(
                child: state.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: context.colors.primary,
                          strokeWidth: 3,
                        ),
                      )
                    : state.error != null
                        ? _WebErrorView(error: state.error!, onRetry: onRetry)
                        : filteredList.isEmpty
                            ? _WebEmptyView(hasQuery: searchQuery.isNotEmpty)
                            : Column(
                                children: [
                                  Expanded(
                                    child: RefreshIndicator(
                                      color: context.colors.primary,
                                      onRefresh: onRefresh,
                                      child: isDesktop
                                          ? _WebDesktopTable(
                                              patients: pageItems,
                                              onPatientTap: onOpenProfile,
                                            )
                                          : _WebMobileList(
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
            ],
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// WEB COMPONENTS
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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

class _WebSortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _WebSortChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? context.colors.primary.withValues(alpha: 0.12)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? context.colors.primary.withValues(alpha: 0.5)
                : context.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color:
                    isActive ? context.colors.primary : context.colors.textHint),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.textStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? context.colors.primary
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Desktop table â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _WebDesktopTable extends StatelessWidget {
  final List<PatientModel> patients;
  final ValueChanged<PatientModel> onPatientTap;
  const _WebDesktopTable({required this.patients, required this.onPatientTap});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Padding(
      padding: EdgeInsets.fromLTRB(isDesktop ? 36 : 20, 0, isDesktop ? 36 : 20, 8),
      child: WebGlassCard(
        borderRadius: 24,
        child: Column(
          children: [
            // Header row
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDesktop ? context.colors.divider : context.colors.background.withValues(alpha: 0.6),
                border: Border(
                  bottom: BorderSide(
                      color: isDesktop ? context.colors.border : context.colors.border.withValues(alpha: 0.5)),
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
                      flex: 2, child: _tableHeader(context, 'Last Visit')),
                  SizedBox(
                      width: 80,
                      child: _tableHeader(context, 'Actions')),
                  const SizedBox(width: 24),
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
  }

  Widget _tableHeader(BuildContext context, String label) {
    return Text(
      label,
      style: context.textStyles.caption.copyWith(
        color: context.colors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.3,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final patient = widget.patient;
    
    final lastVisitDates = ref.watch(patientListProvider.select((s) => s.lastVisitDates));
    final lastVisitDate = lastVisitDates[patient.id];
    final lastVisit = lastVisitDate != null
        ? DateFormat('MMM d, yyyy').format(lastVisitDate)
        : '\u2014';
    final initials =
        patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : '?';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? (isDesktop ? context.colors.divider : context.colors.primary.withValues(alpha: 0.04))
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                  color: isDesktop ? context.colors.divider : context.colors.border.withValues(alpha: 0.3)),
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
                child: Text(
                  lastVisit,
                  style: context.textStyles.bodyMedium.copyWith(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              // Web â€” WhatsApp ONLY, no call button
              SizedBox(
                width: 80,
                child: patient.phone.isNotEmpty
                    ? _WebActionBtn(
                        icon: Icons.chat_rounded,
                        color: const Color(0xFF25D366),
                        tooltip: 'WhatsApp',
                        onTap: () => WhatsAppHelper.openChat(patient.phone),
                      )
                    : const SizedBox.shrink(),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: context.colors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Mobile web list â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
            // Web mobile â€” WhatsApp ONLY
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

// â”€â”€ Pagination â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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

// â”€â”€ Shared web helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
              error,
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

// â”€â”€ Web animated row stagger â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// APP â€” Animated card (original, for mobile only)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

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
  final List<PatientModel> Function(List<PatientModel>) filtered;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onNavigateToAppointment;
  final VoidCallback onRetry;
  final AsyncCallback onRefresh;
  final ValueChanged<PatientModel> onOpenProfile;

  const _AppPatientScreen({
    required this.searchCtrl,
    required this.searchQuery,
    required this.sortMode,
    required this.filtered,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onNavigateToAppointment,
    required this.onRetry,
    required this.onRefresh,
    required this.onOpenProfile,
  });

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
        shape: const CircleBorder(),
        backgroundColor: context.colors.primary,
        onPressed: () => _showAppointmentTypeSelector(context),
        child: Icon(Icons.add, color: context.colors.textPrimary, size: 24),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Patients',
                      style: context.textStyles.h1.copyWith(
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.patients.length} total registered',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Search bar
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: context.colors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: context.colors.textHint),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: searchCtrl,
                              style: context.textStyles.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'Search by name or phone...',
                                hintStyle: context.textStyles.bodyMedium.copyWith(
                                  color: context.colors.textHint,
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
                                searchCtrl.clear();
                                onSearchChanged('');
                              },
                              child: Icon(Icons.close_rounded, color: context.colors.textHint),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Sort Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _AppSortChip(
                            label: 'Recent',
                            icon: Icons.schedule_rounded,
                            isActive: sortMode == 'recent',
                            onTap: () => onSortChanged('recent'),
                          ),
                          const SizedBox(width: 8),
                          _AppSortChip(
                            label: 'A-Z',
                            icon: Icons.sort_by_alpha_rounded,
                            isActive: sortMode == 'a-z',
                            onTap: () => onSortChanged('a-z'),
                          ),
                          const SizedBox(width: 8),
                          _AppSortChip(
                            label: 'Phone',
                            icon: Icons.phone_rounded,
                            isActive: sortMode == 'phone',
                            onTap: () => onSortChanged('phone'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
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
                  child: _WebEmptyView(hasQuery: searchQuery.isNotEmpty),
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
                        return _AnimatedCard(
                          index: index,
                          child: GestureDetector(
                            onTap: () => onOpenProfile(patient),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.colors.border.withValues(alpha: 0.4),
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF1E88E5), Color(0xFF64B5F6)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Name and Phone
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          patient.fullName,
                                          style: context.textStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (patient.phone.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.phone_rounded,
                                                size: 14,
                                                color: context.colors.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                patient.phone,
                                                style: context.textStyles.bodySmall.copyWith(
                                                  color: context.colors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Action Buttons & Chevron
                                  if (patient.phone.isNotEmpty) ...[
                                    // WhatsApp Button
                                    GestureDetector(
                                      onTap: () => WhatsAppHelper.openChat(patient.phone),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF25D366).withValues(alpha: 0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.message_rounded,
                                          color: Color(0xFF25D366),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Dial/Phone Button
                                    GestureDetector(
                                      onTap: () => _makePhoneCall(patient.phone),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFF00BFA5).withValues(alpha: 0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.phone_rounded,
                                          color: Color(0xFF00BFA5),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: context.colors.textHint,
                                    size: 20,
                                  ),
                                ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? context.colors.primary.withValues(alpha: 0.12)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? context.colors.primary
                : context.colors.border.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? context.colors.primary : context.colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: context.textStyles.bodyMedium.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? context.colors.primary : context.colors.textSecondary,
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
        transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
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
                  Icon(Icons.add_rounded, color: context.colors.textPrimary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'New Appointment',
                    style: context.textStyles.buttonMedium.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  VerticalDivider(color: context.colors.textHint, width: 1, indent: 10, endIndent: 10),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textSecondary, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

