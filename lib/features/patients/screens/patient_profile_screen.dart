import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../appointments/models/appointment_model.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../models/patient_model.dart';
import '../../consultations/models/consultation_model.dart';
import '../../consultations/screens/consultation_screen.dart';
import '../../treatments/models/treatment_plan_model.dart';
import '../../treatments/models/session_model.dart';
import '../../treatments/screens/create_treatment_plan_screen.dart';
import '../../treatments/providers/treatment_provider.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  final PatientModel patient;
  final AppointmentModel? appointment;
  final int initialTabIndex;

  const PatientProfileScreen({super.key, required this.patient, this.appointment, this.initialTabIndex = 0});

  @override
  ConsumerState<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// null = not yet checked; '' = none found; non-empty = ongoing consultation ID.
  String? _ongoingConsultationId;

  /// Incremented to force FutureBuilder + card rebuild after plan creation.
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _checkOngoingConsultation();
  }

  Future<void> _checkOngoingConsultation() async {
    try {
      if (widget.appointment != null) {
        final apt = widget.appointment!;
        if (apt.linkedConsultationId != null && apt.linkedConsultationId!.isNotEmpty) {
          if (!apt.consultationFormSaved) {
            if (mounted) setState(() => _ongoingConsultationId = apt.linkedConsultationId);
            return;
          }
        }
        if (mounted) setState(() => _ongoingConsultationId = '');
        return;
      }

      final aptService = ref.read(appointmentServiceProvider);
      final ongoing = await aptService.findOngoingConsultation(
        widget.patient.id,
        widget.patient.doctorId,
      );
      if (mounted) setState(() => _ongoingConsultationId = ongoing?.id ?? '');
    } catch (_) {
      if (mounted) setState(() => _ongoingConsultationId = '');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasOngoing = _ongoingConsultationId != null && _ongoingConsultationId!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Patient Profile', style: AppTextStyles.h4),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: AppTextStyles.h4,
          unselectedLabelStyle: AppTextStyles.bodyMedium,
          tabs: const [
            Tab(text: 'Treatments'),
            Tab(text: 'History'),
            Tab(text: 'Patient Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTreatmentsTab(),
          _buildHistoryTab(),
          _buildBasicDetailsTab(),
        ],
      ),
      floatingActionButton: _buildFAB(hasOngoing),
    );
  }

  Widget? _buildFAB(bool hasOngoing) {
    if (_tabController.index != 0) return null;
    if (hasOngoing) return null;

    return FloatingActionButton.extended(
      onPressed: () async {
        final aptService = ref.read(appointmentServiceProvider);
        try {
          String consultationId;
          if (widget.appointment != null) {
            final (id, _) = await aptService.getOrCreateConsultationForAppointment(widget.appointment!);
            consultationId = id;
          } else {
            final newC = await aptService.createConsultation(
              widget.patient.id,
              widget.patient.doctorId,
            );
            consultationId = newC.id;
          }
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConsultationScreen(
                patientId: widget.patient.id,
                patientName: widget.patient.fullName,
                doctorId: widget.patient.doctorId,
                consultationId: consultationId,
                appointmentId: widget.appointment?.id,
              ),
            ),
          );
          if (mounted) {
            await _checkOngoingConsultation();
            setState(() {});
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
              backgroundColor: AppColors.error,
            ));
          }
        }
      },
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
      label: const Text('Start Consult',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  // ─── TREATMENTS TAB ──────────────────────────────────────────────────────────

  Future<List<_ConsultationEntry>> _loadConsultations() async {
    final pb = ref.read(pocketbaseProvider);
    final patientId = widget.patient.id;

    final aptsRes = await pb.collection(PBCollections.appointments).getList(
      filter: 'patient = "$patientId"',
      sort: '-date,-time',
      perPage: 200,
    );

    final entries = <_ConsultationEntry>[];
    for (final apt in aptsRes.items) {
      final consultationId = apt.getStringValue('linked_consultation_id');
      if (consultationId.isEmpty) continue;
      try {
        final cRecord = await pb.collection(PBCollections.consultations).getOne(consultationId);
        final c = ConsultationModel.fromRecord(cRecord);
        final aptModel = AppointmentModel.fromRecord(apt);
        entries.add(_ConsultationEntry(consultation: c, appointment: aptModel));
      } catch (_) {}
    }

    final seen = <String>{};
    entries.retainWhere((e) => seen.add(e.consultation.id));
    entries.sort((a, b) =>
        (b.consultation.created ?? DateTime(0)).compareTo(a.consultation.created ?? DateTime(0)));

    return entries;
  }

  Widget _buildTreatmentsTab() {
    return FutureBuilder<List<_ConsultationEntry>>(
      key: ValueKey('treatments_$_refreshKey'),
      future: _loadConsultations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading treatments: ${snapshot.error}',
                style: AppTextStyles.bodyMedium),
          );
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: Text('No consultations yet.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ConsultationCard(
                key: ValueKey('cc_${entry.consultation.id}_$_refreshKey'),
                entry: entry,
                patient: widget.patient,
                onReturn: () => setState(() => _refreshKey++),
              ),
            );
          },
        );
      },
    );
  }

  // ─── HISTORY TAB ─────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final pb = ref.read(pocketbaseProvider);
    final patientId = widget.patient.id;

    return FutureBuilder(
      future: pb.collection(PBCollections.appointments).getList(
        filter: 'patient = "$patientId"',
        sort: '-date,-time',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading history: ${snapshot.error}', style: AppTextStyles.bodyMedium));
        }

        final appointments = snapshot.data!.items;
        final events = <_HistoryEvent>[];

        for (var a in appointments) {
          final status = a.getStringValue('status');
          final checkInStr = a.getStringValue('check_in_time');
          final checkOutStr = a.getStringValue('check_out_time');
          if (status == 'scheduled' && checkInStr.isEmpty) continue;

          final dateStr = a.getStringValue('date');
          final timeStr = a.getStringValue('time');
          final typeVal = a.getStringValue('type');
          final sessionTypeVal = a.getStringValue('session_type');
          final dt = DateTime.tryParse('$dateStr $timeStr') ??
              DateTime.tryParse(a.getStringValue('created'));

          String title = 'Scheduled Appointment';
          if (typeVal == 'walk_in') title = 'Walk-In Patient';
          if (typeVal == 'session') {
            title = sessionTypeVal == 'maintenance' ? 'Maintenance Session' : 'Treatment Session';
          }

          String? details1;
          String? details2;
          if (checkInStr.isNotEmpty) {
            String label = typeVal == 'session' ? 'Session Started' : 'Check-in';
            details1 = '$label: ${DateFormat("h:mm a").format(DateTime.parse(checkInStr).toLocal())}';
          }
          if (checkOutStr.isNotEmpty) {
            String label = typeVal == 'session' ? 'Session Ended' : 'Check-out';
            details2 = '$label: ${DateFormat("h:mm a").format(DateTime.parse(checkOutStr).toLocal())}';
          }

          events.add(_HistoryEvent(
            type: 'Appointment',
            date: dt ?? DateTime.now(),
            icon: typeVal == 'session'
                ? (sessionTypeVal == 'maintenance'
                    ? Icons.autorenew_rounded
                    : Icons.healing_rounded)
                : Icons.event_available_rounded,
            color: typeVal == 'session' && sessionTypeVal == 'maintenance'
                ? AppColors.success
                : AppColors.primary,
            title: title,
            subtitle: 'Time: $timeStr | Status: $status',
            details: details1,
            details2: details2,
          ));
        }

        events.sort((a, b) => b.date.compareTo(a.date));

        if (events.isEmpty) {
          return Center(
            child: Text('No history found.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final e = events[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: e.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(e.icon, size: 20, color: e.color),
                      ),
                      if (index != events.length - 1)
                        Container(width: 2, height: 40, color: AppColors.border),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMM d, yyyy').format(e.date), style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text(e.title, style: AppTextStyles.h4),
                        const SizedBox(height: 4),
                        Text(e.subtitle,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                        if (e.details != null) ...[
                          const SizedBox(height: 4),
                          Text(e.details!,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(fontSize: 13, color: AppColors.primary)),
                        ],
                        if (e.details2 != null) ...[
                          const SizedBox(height: 2),
                          Text(e.details2!,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(fontSize: 13, color: AppColors.primary)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── PATIENT DETAILS TAB ─────────────────────────────────────────────────────

  Widget _buildBasicDetailsTab() {
    final p = widget.patient;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
                style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(p.fullName, style: AppTextStyles.h3)),
          Center(
            child: Text(p.phone,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 32),
          _detailRow('Age', p.age?.toString() ?? 'Not provided'),
          _detailRow('Date of Birth', p.dateOfBirth ?? 'Not provided'),
          _detailRow('Gender', p.gender ?? 'Not provided'),
          _detailRow('City', p.city?.isNotEmpty == true ? p.city! : 'Not provided'),
          _detailRow('Area / Locality', p.area?.isNotEmpty == true ? p.area! : 'Not provided'),
          _detailRow('Occupation', p.occupation ?? 'Not provided'),
          _detailRow('Email', p.email ?? 'Not provided'),
          _detailRow('Allergies/Conditions', p.allergiesConditions ?? 'None known'),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label.copyWith(color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

// ─── Data containers ──────────────────────────────────────────────────────────

class _ConsultationEntry {
  final ConsultationModel consultation;
  final AppointmentModel appointment;
  const _ConsultationEntry({required this.consultation, required this.appointment});
}

// ─── Expandable Consultation Card ────────────────────────────────────────────

class _ConsultationCard extends ConsumerStatefulWidget {
  final _ConsultationEntry entry;
  final PatientModel patient;
  final VoidCallback onReturn;

  const _ConsultationCard({
    super.key,
    required this.entry,
    required this.patient,
    required this.onReturn,
  });

  @override
  ConsumerState<_ConsultationCard> createState() => _ConsultationCardState();
}

class _ConsultationCardState extends ConsumerState<_ConsultationCard> {
  bool _expanded = false;
  // Treatment plan + sessions
  TreatmentPlanModel? _treatmentPlan;
  List<SessionModel> _treatmentSessions = [];
  // Maintenance plan + sessions
  TreatmentPlanModel? _maintenancePlan;
  List<SessionModel> _maintenanceSessions = [];
  bool _planLoaded = false;

  ConsultationModel get c => widget.entry.consultation;
  PatientModel get patient => widget.patient;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final res = await pb.collection(PBCollections.treatmentPlans).getList(
        filter: 'consultation = "${c.id}"',
        perPage: 10,
      );
      if (!mounted) return;

      for (final rec in res.items) {
        final plan = TreatmentPlanModel.fromRecord(rec);
        if (plan.isMaintenance) {
          _maintenancePlan = plan;
          await _loadSessions(plan.id, isMaintenance: true);
        } else {
          _treatmentPlan = plan;
          await _loadSessions(plan.id, isMaintenance: false);
        }
      }

      // Fallback: if no treatment plan found by consultation,
      // try via the appointment's linked_treatment_plan_id
      if (_treatmentPlan == null) {
        final aptPlanId = widget.entry.appointment.linkedTreatmentPlanId;
        if (aptPlanId != null && aptPlanId.isNotEmpty) {
          try {
            final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(aptPlanId);
            final plan = TreatmentPlanModel.fromRecord(planRec);
            if (plan.isMaintenance) {
              _maintenancePlan = plan;
              await _loadSessions(plan.id, isMaintenance: true);
            } else {
              _treatmentPlan = plan;
              await _loadSessions(plan.id, isMaintenance: false);
            }
          } catch (_) {}
        }
      }

      // Also look for maintenance plans linked by parent_plan (if not linked via consultation)
      if (_treatmentPlan != null && _maintenancePlan == null) {
        try {
          final mRes = await pb.collection(PBCollections.treatmentPlans).getList(
            filter: 'parent_plan = "${_treatmentPlan!.id}"',
            perPage: 1,
          );
          if (mRes.items.isNotEmpty) {
            _maintenancePlan = TreatmentPlanModel.fromRecord(mRes.items.first);
            await _loadSessions(_maintenancePlan!.id, isMaintenance: true);
          }
        } catch (_) {}
      }

      if (mounted) setState(() => _planLoaded = true);
    } catch (_) {
      if (mounted) setState(() => _planLoaded = true);
    }
  }

  Future<void> _loadSessions(String planId, {required bool isMaintenance}) async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'treatment_plan = "$planId"',
        sort: 'session_number',
        perPage: 200,
      );
      if (mounted) {
        final sessions = res.items.map((r) => SessionModel.fromRecord(r)).toList();
        setState(() {
          if (isMaintenance) {
            _maintenanceSessions = sessions;
          } else {
            _treatmentSessions = sessions;
          }
        });
      }
    } catch (_) {}
  }

  bool get _isOngoing => c.status == ConsultationStatus.ongoing;

  /// True when the consultation form has been meaningfully filled in.
  /// We use chiefComplaint as the canonical indicator — it's the first
  /// required field in the form and is always set on submission.
  bool get _formFilled =>
      c.chiefComplaint != null && c.chiefComplaint!.trim().isNotEmpty;

  bool get _allTreatmentDone =>
      _treatmentPlan != null &&
      _treatmentSessions.isNotEmpty &&
      _treatmentSessions.every((s) =>
          s.status == SessionStatus.completed ||
          s.status == SessionStatus.cancelled ||
          s.status == SessionStatus.missed);

  @override
  Widget build(BuildContext context) {
    final treatmentDone = _treatmentSessions
        .where((s) => s.status == SessionStatus.completed)
        .length;
    final maintenanceDone = _maintenanceSessions
        .where((s) => s.status == SessionStatus.completed)
        .length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !_formFilled && _isOngoing
              ? AppColors.warning.withValues(alpha: 0.5)   // unfilled: orange
              : _formFilled && _isOngoing
                  ? AppColors.primary.withValues(alpha: 0.5) // filled+ongoing: blue
                  : AppColors.border,                        // completed: grey
          width: _isOngoing ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Tappable header ──
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _cardColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.medical_information_rounded,
                      color: _cardColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.chiefComplaint?.isNotEmpty == true
                                    ? c.chiefComplaint!
                                    : 'General Consultation',
                                style: AppTextStyles.h4,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _statusChip(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.created != null
                              ? DateFormat('MMM d, yyyy · h:mm a').format(c.created!.toLocal())
                              : '—',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                        if (_planLoaded) ...[
                          if (_treatmentPlan != null)
                            Text(
                              '$treatmentDone/${_treatmentSessions.length} treatment sessions done'
                              '${_maintenancePlan != null ? ' · $maintenanceDone/${_maintenanceSessions.length} maintenance' : ''}',
                              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ──
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildConsultationDetails(),
            if (_planLoaded) _buildSessionsSection(),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// Returns the accent color for this card based on its workflow state.
  Color get _cardColor {
    if (!_isOngoing) return AppColors.success;                        // completed
    if (!_formFilled) return AppColors.warning;                       // ongoing, form not filled
    if (_planLoaded && _treatmentPlan != null) return AppColors.info;  // ongoing, plan exists
    return AppColors.primary;                                         // ongoing, form submitted, no plan
  }

  Widget _statusChip() {
    final String label;
    final Color color;
    if (!_isOngoing) {
      label = 'Completed'; color = AppColors.success;
    } else if (!_formFilled) {
      label = 'In Progress'; color = AppColors.warning;
    } else if (_planLoaded && _treatmentPlan != null) {
      label = 'Ongoing'; color = AppColors.info;
    } else {
      label = 'Plan Needed'; color = AppColors.primary;
    }
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildConsultationDetails() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Case 1: Form not yet filled → show Resume button ──
          if (_isOngoing && !_formFilled) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConsultationScreen(
                        patientId: patient.id,
                        patientName: patient.fullName,
                        doctorId: patient.doctorId,
                        consultationId: c.id,
                        appointmentId: widget.entry.appointment.id,
                      ),
                    ),
                  );
                  widget.onReturn();
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Resume Consultation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Case 2: Form filled → show consultation details ──
          if (_formFilled) ...[
            _infoRow('Chief Complaint', c.chiefComplaint),
            _infoRow('Medical History', c.medicalHistory),
            _infoRow('Past Illnesses', c.pastIllnesses),
            _infoRow('Current Medications', c.currentMedications),
            _infoRow('Allergies', c.allergies),
            _infoRow('Diet Pattern', c.dietPattern),
            _infoRow('Sleep Quality', c.sleepQuality),
            _infoRow('Stress Level', c.stressLevel),
            _infoRow('Notes', c.notes),
            // View Full Record button (always available once form is filled)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    '/consultation',
                    arguments: {
                      'patientId': patient.id,
                      'patientName': patient.fullName,
                      'doctorId': patient.doctorId,
                      'consultationId': c.id,
                      'isViewMode': true,
                    },
                  );
                  widget.onReturn();
                },
                icon: const Icon(Icons.description_rounded, size: 16),
                label: const Text('View Full Record'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: BorderSide(color: AppColors.info.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          if (!_planLoaded)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            // ── Create Treatment Plan button ──
            // Show when: form is filled (submitted) AND no plan created yet.
            // Works for both ongoing (just submitted) and completed consultations.
            if (_formFilled && _treatmentPlan == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                  final result = await Navigator.push<dynamic>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTreatmentPlanScreen(
                        patientId: patient.id,
                        patientName: patient.fullName,
                        doctorId: patient.doctorId,
                        consultationId: c.id,
                        appointmentId: widget.entry.appointment.id,
                      ),
                    ),
                  );
                  
                  if (!mounted) return;
                  if (result is Map && result['firstSessionToday'] == true) {
                    final aptService = ref.read(appointmentServiceProvider);
                    await aptService.markEnded(widget.entry.appointment.id);
                  }

                  setState(() {
                    _planLoaded = false;
                    _treatmentPlan = null;
                    _treatmentSessions = [];
                    _maintenancePlan = null;
                    _maintenanceSessions = [];
                  });
                  await _loadPlans();
                  widget.onReturn();
                },
                icon: const Icon(Icons.add_chart_rounded, size: 18),
                label: const Text('Create Treatment Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  elevation: 0,
                ),
              ),
            ),
          ],

          // ── Treatment sessions ──
          if (_treatmentPlan != null) ...[
            _planHeader(
              label: 'Treatment Sessions',
              plan: _treatmentPlan!,
              color: AppColors.primary,
              icon: Icons.healing_rounded,
            ),
            const SizedBox(height: 8),
            if (_treatmentSessions.isEmpty)
              Text('No sessions found.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))
            else
              ...(_treatmentSessions.map((s) => _sessionTile(s))),
            const SizedBox(height: 12),
          ],

          // ── Create Maintenance Plan button ──
          if (_treatmentPlan != null && _maintenancePlan == null && _allTreatmentDone) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateTreatmentPlanScreen(
                        patientId: patient.id,
                        patientName: patient.fullName,
                        doctorId: patient.doctorId,
                        consultationId: c.id,
                        appointmentId: widget.entry.appointment.id,
                        isMaintenance: true,
                        parentPlanId: _treatmentPlan!.id,
                        defaultTreatmentType: _treatmentPlan!.treatmentType,
                        defaultFee: _treatmentPlan!.sessionFee,
                      ),
                    ),
                  );
                  setState(() {
                    _planLoaded = false;
                    _maintenancePlan = null;
                    _maintenanceSessions = [];
                  });
                  await _loadPlans();
                  widget.onReturn();
                },
                icon: const Icon(Icons.autorenew_rounded, size: 18),
                label: const Text('Create Maintenance Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Maintenance sessions ──
          if (_maintenancePlan != null) ...[
            _planHeader(
              label: 'Maintenance Sessions',
              plan: _maintenancePlan!,
              color: AppColors.success,
              icon: Icons.autorenew_rounded,
            ),
            const SizedBox(height: 8),
            if (_maintenanceSessions.isEmpty)
              Text('No maintenance sessions found.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))
            else
              ...(_maintenanceSessions.map((s) => _sessionTile(s))),
          ],
        ],
      ),
    );
  }

  Widget _planHeader({
    required String label,
    required TreatmentPlanModel plan,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.label.copyWith(fontSize: 13, color: color)),
        const Spacer(),
        Text(
          '${plan.treatmentType} · ₹${plan.sessionFee.toInt()}/session',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _sessionTile(SessionModel session) {
    final isMaintenance = session.isMaintenance;
    final statusColor = _sessionStatusColor(session.status);
    final accentColor = isMaintenance ? AppColors.success : AppColors.primary;
    final date = DateTime.tryParse(session.scheduledDate);
    final dateLabel = date != null ? DateFormat('EEE, MMM d').format(date) : '—';
    final isEditable = session.status == SessionStatus.upcoming ||
        session.status == SessionStatus.waiting;
    final isViewable = session.status == SessionStatus.completed;

    return GestureDetector(
      onTap: () async {
        // Navigate to session detail for upcoming/waiting (record) or completed (view)
        if (!isEditable && !isViewable) return;

        if (isEditable) {
          // Check date mismatch for upcoming sessions
          final now = DateTime.now();
          if (date != null &&
              (date.toLocal().year != now.year ||
                  date.toLocal().month != now.month ||
                  date.toLocal().day != now.day)) {
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Date Mismatch'),
                content: const Text('This session is not scheduled for today. Record anyway?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Proceed', style: TextStyle(color: AppColors.primary))),
                ],
              ),
            );
            if (proceed != true || !mounted) return;
          }
        }

        await Navigator.pushNamed(context, '/sessions/record', arguments: session);
        if (mounted) {
          final planId = isMaintenance ? _maintenancePlan?.id : _treatmentPlan?.id;
          if (planId != null) {
            setState(() {
              if (isMaintenance) _maintenanceSessions = [];
              else _treatmentSessions = [];
            });
            await _loadSessions(planId, isMaintenance: isMaintenance);
          }
        }
      },
      onLongPress: () => _showSessionActions(session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isEditable
              ? accentColor.withValues(alpha: 0.04)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEditable
                ? accentColor.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // Session number badge
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '#${session.sessionNumber}',
                style: AppTextStyles.caption.copyWith(
                    color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${isMaintenance ? "Maintenance" : "Session"} ${session.sessionNumber}',
                        style: AppTextStyles.label.copyWith(fontSize: 13),
                      ),
                      if (isMaintenance) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('M',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(dateLabel, style: AppTextStyles.caption),
                ],
              ),
            ),
            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _sessionStatusLabel(session.status),
                style: AppTextStyles.caption.copyWith(color: statusColor, fontSize: 10),
              ),
            ),
            if (isEditable) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 18),
            ],
            // Long-press hint icon for upcoming sessions
            if (isEditable) ...[
              const SizedBox(width: 2),
              Icon(Icons.more_vert_rounded, color: AppColors.textHint.withValues(alpha: 0.5), size: 14),
            ],
          ],
        ),
      ),
    );
  }

  /// Show action popup menu for session management.
  void _showSessionActions(SessionModel session) {
    final canAct = session.status == SessionStatus.upcoming ||
        session.status == SessionStatus.waiting;
    if (!canAct) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${session.isMaintenance ? "Maintenance" : "Session"} ${session.sessionNumber}',
              style: AppTextStyles.h4,
            ),
            Text(
              'Scheduled: ${session.scheduledDate}${session.scheduledTime != null ? " at ${session.scheduledTime}" : ""}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _actionTile(
              ctx,
              icon: Icons.calendar_month_rounded,
              color: AppColors.primary,
              label: 'Reschedule Session',
              onTap: () async {
                Navigator.pop(ctx);
                await _rescheduleSession(session);
              },
            ),
            _actionTile(
              ctx,
              icon: Icons.warning_amber_rounded,
              color: AppColors.warning,
              label: 'Mark as Missed',
              onTap: () async {
                Navigator.pop(ctx);
                await _markMissed(session);
              },
            ),
            _actionTile(
              ctx,
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              label: 'Cancel Session',
              onTap: () async {
                Navigator.pop(ctx);
                await _cancelSession(session);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  Future<void> _rescheduleSession(SessionModel session) async {
    final dt = DateTime.tryParse(session.scheduledDate) ?? DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: dt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (newDate == null || !mounted) return;

    TimeOfDay initialTime = const TimeOfDay(hour: 10, minute: 0);
    if (session.scheduledTime != null && session.scheduledTime!.contains(':')) {
      final parts = session.scheduledTime!.split(':');
      initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    final newTime = await showTimePicker(context: context, initialTime: initialTime);
    if (newTime == null || !mounted) return;

    final newDateStr =
        '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
    final newTimeStr =
        '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';

    try {
      final service = ref.read(treatmentServiceProvider);
      await service.rescheduleSession(sessionId: session.id, newDate: newDateStr, newTime: newTimeStr);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session ${session.sessionNumber} rescheduled.'),
          backgroundColor: AppColors.success,
        ));
        final isMaintenance = session.isMaintenance;
        final planId = isMaintenance ? _maintenancePlan?.id : _treatmentPlan?.id;
        if (planId != null) await _loadSessions(planId, isMaintenance: isMaintenance);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _markMissed(SessionModel session) async {
    try {
      final service = ref.read(treatmentServiceProvider);
      await service.markSessionMissed(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Session marked as missed.'), backgroundColor: AppColors.warning,
        ));
        final isMaintenance = session.isMaintenance;
        final planId = isMaintenance ? _maintenancePlan?.id : _treatmentPlan?.id;
        if (planId != null) await _loadSessions(planId, isMaintenance: isMaintenance);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _cancelSession(SessionModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Session #${session.sessionNumber}?'),
        content: const Text('This will cancel this session and remove it from the schedule.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Session'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final service = ref.read(treatmentServiceProvider);
      await service.cancelSession(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Session cancelled.'), backgroundColor: AppColors.success,
        ));
        final isMaintenance = session.isMaintenance;
        final planId = isMaintenance ? _maintenancePlan?.id : _treatmentPlan?.id;
        if (planId != null) await _loadSessions(planId, isMaintenance: isMaintenance);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Color _sessionStatusColor(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:  return AppColors.info;
      case SessionStatus.waiting:   return AppColors.warning;
      case SessionStatus.completed: return AppColors.success;
      case SessionStatus.missed:    return AppColors.warning;
      case SessionStatus.cancelled: return AppColors.error;
    }
  }

  String _sessionStatusLabel(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:  return 'Upcoming';
      case SessionStatus.waiting:   return 'Waiting';
      case SessionStatus.completed: return 'Done';
      case SessionStatus.missed:    return 'Missed';
      case SessionStatus.cancelled: return 'Cancelled';
    }
  }
}

// ─── Supporting models ────────────────────────────────────────────────────────

class _HistoryEvent {
  final String type;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? details;
  final String? details2;

  _HistoryEvent({
    required this.type,
    required this.date,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.details,
    this.details2,
  });
}
