import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
import 'package:pms_app/core/theme/app_theme.dart';


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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Patient Profile', style: context.textStyles.h4),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.colors.primary,
          unselectedLabelColor: context.colors.textHint,
          indicatorColor: context.colors.primary,
          indicatorWeight: 3,
          labelStyle: context.textStyles.h4,
          unselectedLabelStyle: context.textStyles.bodyMedium,
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
            setState(() {
              _refreshKey++;
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
              backgroundColor: context.colors.error,
            ));
          }
        }
      },
      backgroundColor: context.colors.primary,
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
          return Center(
              child: CircularProgressIndicator(color: context.colors.primary, strokeWidth: 3));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading treatments: ${snapshot.error}',
                style: context.textStyles.bodyMedium),
          );
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: Text('No consultations yet.',
                style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary)),
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
          return Center(child: CircularProgressIndicator(color: context.colors.primary, strokeWidth: 3));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading history: ${snapshot.error}', style: context.textStyles.bodyMedium));
        }

        final appointments = snapshot.data!.items;
        final events = <_HistoryEvent>[];

        for (var a in appointments) {
          final status = a.getStringValue('status');
          final checkInStr = a.getStringValue('check_in_time');
          final detailsFilledStr = a.getStringValue('patient_details_filled_time');
          final startConsultStr = a.getStringValue('consultation_start_time');
          final endConsultStr = a.getStringValue('consultation_end_time');
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

          final List<String> timeline = [];
          if (checkInStr.isNotEmpty) {
            timeline.add('Patient Arrived: ${DateFormat("h:mm a").format(DateTime.parse(checkInStr).toLocal())}');
          }
          if (detailsFilledStr.isNotEmpty) {
            timeline.add('Details Filled: ${DateFormat("h:mm a").format(DateTime.parse(detailsFilledStr).toLocal())}');
          }
          if (startConsultStr.isNotEmpty) {
            final label = typeVal == 'session' ? 'Session Started' : 'Consultation Started';
            timeline.add('$label: ${DateFormat("h:mm a").format(DateTime.parse(startConsultStr).toLocal())}');
          }
          if (endConsultStr.isNotEmpty) {
            final label = typeVal == 'session' ? 'Session Ended' : 'Consultation Ended';
            timeline.add('$label: ${DateFormat("h:mm a").format(DateTime.parse(endConsultStr).toLocal())}');
          }
          final patientLeftStr = a.getStringValue('patient_left_at');
          if (patientLeftStr.isNotEmpty) {
            final label = typeVal == 'session' ? 'Session Ended' : 'Patient Left At';
            timeline.add('$label: ${DateFormat("h:mm a").format(DateTime.parse(patientLeftStr).toLocal())}');
          } else if (checkOutStr.isNotEmpty && endConsultStr.isEmpty) {
            final label = typeVal == 'session' ? 'Session Ended' : 'Patient Left At';
            timeline.add('$label: ${DateFormat("h:mm a").format(DateTime.parse(checkOutStr).toLocal())}');
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
                ? context.colors.success
                : context.colors.primary,
            title: title,
            subtitle: 'Time: $timeStr | Status: $status',
            detailsTimeline: timeline,
          ));
        }

        events.sort((a, b) => b.date.compareTo(a.date));

        if (events.isEmpty) {
          return Center(
            child: Text('No history found.',
                style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary)),
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
                        Container(width: 2, height: 40, color: context.colors.border),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMM d, yyyy').format(e.date), style: context.textStyles.caption),
                        const SizedBox(height: 4),
                        Text(e.title, style: context.textStyles.h4),
                        const SizedBox(height: 4),
                        Text(e.subtitle,
                            style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary)),
                        if (e.detailsTimeline.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final d in e.detailsTimeline)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(d,
                                  style: context.textStyles.bodyMedium
                                      .copyWith(fontSize: 13, color: context.colors.primary)),
                            ),
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
    final initials = p.fullName.trim().split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Avatar + Name + Phone ─────────────────────────────────────────
          Column(
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  gradient: context.colors.heroGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(p.fullName, style: context.textStyles.h2.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_rounded, size: 14, color: context.colors.textSecondary),
                  const SizedBox(width: 4),
                  Text(p.phone, style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Personal Info Card ────────────────────────────────────────────
          _profileInfoCard(
            title: 'Personal Info',
            icon: Icons.person_rounded,
            children: [
              if (p.age != null) _profileDetailRow('Age', '${p.age} years'),
              if (p.dateOfBirth?.isNotEmpty == true) _profileDetailRow('Date of Birth', p.dateOfBirth!),
              if (p.gender?.isNotEmpty == true) _profileDetailRow('Gender', p.gender!),
              if (p.occupation?.isNotEmpty == true) _profileDetailRow('Occupation', p.occupation!),
            ],
          ),
          const SizedBox(height: 14),

          // ── Contact & Location Card ───────────────────────────────────────
          _profileInfoCard(
            title: 'Contact & Location',
            icon: Icons.location_on_rounded,
            children: [
              if (p.city?.isNotEmpty == true) _profileDetailRow('City', p.city!),
              if (p.area?.isNotEmpty == true) _profileDetailRow('Area', p.area!),
              if (p.email?.isNotEmpty == true) _profileDetailRow('Email', p.email!),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _profileInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    final visible = children.where((w) => w is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: context.colors.primary),
            const SizedBox(width: 6),
            Text(title, style: context.textStyles.label.copyWith(color: context.colors.primary, fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _profileDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: context.textStyles.caption.copyWith(color: context.colors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: context.textStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
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
          Text(label, style: context.textStyles.label.copyWith(color: context.colors.primary)),
          const SizedBox(height: 4),
          Text(value, style: context.textStyles.bodyMedium),
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

  /// Compute display status: if session is 'upcoming' but date is past, treat as 'missed'.
  SessionStatus _displayStatus(SessionModel s) {
    if (s.status == SessionStatus.upcoming) {
      final dt = DateTime.tryParse(s.scheduledDate);
      if (dt != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final sessionDay = DateTime(dt.year, dt.month, dt.day);
        if (sessionDay.isBefore(today)) return SessionStatus.missed;
      }
    }
    return s.status;
  }

  bool get _allTreatmentDone =>
      _treatmentPlan != null &&
      _treatmentSessions.isNotEmpty &&
      _treatmentSessions.every((s) {
        final ds = _displayStatus(s);
        return ds == SessionStatus.completed ||
            ds == SessionStatus.cancelled ||
            ds == SessionStatus.missed;
      });

  @override
  Widget build(BuildContext context) {

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: !_formFilled && _isOngoing
              ? context.colors.warning.withValues(alpha: 0.5)   // unfilled: orange
              : _formFilled && _isOngoing
                  ? context.colors.primary.withValues(alpha: 0.5) // filled+ongoing: blue
                  : context.colors.border,                        // completed: grey
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
                                style: context.textStyles.h4,
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
                          style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
                        ),
                        if (_planLoaded) ...[
                          if (_treatmentPlan != null) ...[
                            Builder(builder: (_) {
                              final activeSessions = _treatmentSessions.where((s) => _displayStatus(s) != SessionStatus.cancelled).toList();
                              final doneCount = activeSessions.where((s) => _displayStatus(s) == SessionStatus.completed).length;
                              final mActiveSessions = _maintenanceSessions.where((s) => _displayStatus(s) != SessionStatus.cancelled).toList();
                              final mDoneCount = mActiveSessions.where((s) => _displayStatus(s) == SessionStatus.completed).length;
                              return Text(
                                '$doneCount/${activeSessions.length} treatment sessions done'
                                '${_maintenancePlan != null ? ' · $mDoneCount/${mActiveSessions.length} maintenance' : ''}',
                                style: context.textStyles.caption.copyWith(color: context.colors.primary),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: context.colors.textHint,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded body ──
          if (_expanded) ...[
            Divider(height: 1, indent: 16, endIndent: 16, color: context.colors.border),
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
    if (!_isOngoing) return context.colors.success;                        // completed
    if (!_formFilled) return context.colors.warning;                       // ongoing, form not filled
    if (_planLoaded && _treatmentPlan != null) return context.colors.info;  // ongoing, plan exists
    return context.colors.primary;                                         // ongoing, form submitted, no plan
  }

  Widget _statusChip() {
    final String label;
    final Color color;
    if (!_isOngoing) {
      label = 'Completed'; color = context.colors.success;
    } else if (!_formFilled) {
      label = 'In Progress'; color = context.colors.warning;
    } else if (_planLoaded && _treatmentPlan != null) {
      label = 'Ongoing'; color = context.colors.info;
    } else {
      label = 'Plan Needed'; color = context.colors.primary;
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
        style: context.textStyles.caption.copyWith(
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
                  backgroundColor: context.colors.warning,
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

          // ── Case 2: Form filled ──
          if (_formFilled) ...[
            if (_planLoaded && _treatmentPlan == null) ...[
              Row(
                children: [
                  Expanded(
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
                      icon: const Icon(Icons.description_rounded, size: 14),
                      label: const Text('View Consult'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.info,
                        side: BorderSide(color: context.colors.info.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
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
                      icon: const Icon(Icons.add_chart_rounded, size: 14),
                      label: const Text('Create Plan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else ...[
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
                  label: const Text('View Consultation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.info,
                    side: BorderSide(color: context.colors.info.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
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
          Divider(height: 1, color: context.colors.border),
          const SizedBox(height: 12),

          if (!_planLoaded)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            // Treatment sessions
            if (_treatmentPlan != null) ...[
              _planHeader(
                label: 'Treatment Plan',
                plan: _treatmentPlan!,
                color: context.colors.primary,
                icon: Icons.healing_rounded,
              ),
              const SizedBox(height: 8),
              if (_treatmentSessions.isEmpty)
                Text('No sessions found.',
                    style: context.textStyles.caption.copyWith(color: context.colors.textSecondary))
              else
                ...List.generate(
                  _treatmentSessions.length,
                  (index) => _sessionTile(_treatmentSessions[index], index, _treatmentSessions.length),
                ),
              const SizedBox(height: 12),

              // End Sessions button (visible when pending sessions exist)
              if (_treatmentSessions.any((s) {
                  final ds = _displayStatus(s);
                  return ds == SessionStatus.upcoming ||
                      ds == SessionStatus.waiting ||
                      ds == SessionStatus.inProgress;
              })) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _endSessionsForConsultation(),
                    icon: const Icon(Icons.stop_circle_rounded, size: 16),
                    label: const Text('End Sessions for this Consultation'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.error,
                      side: BorderSide(color: context.colors.error.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // Create Maintenance Plan button
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
                    backgroundColor: context.colors.success,
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

            // Maintenance sessions
            if (_maintenancePlan != null) ...[
              _planHeader(
                label: 'Maintenance Plan',
                plan: _maintenancePlan!,
                color: context.colors.success,
                icon: Icons.autorenew_rounded,
              ),
              const SizedBox(height: 8),
              if (_maintenanceSessions.isEmpty)
                Text('No maintenance sessions found.',
                    style: context.textStyles.caption.copyWith(color: context.colors.textSecondary))
              else
                ...List.generate(
                  _maintenanceSessions.length,
                  (index) => _sessionTile(_maintenanceSessions[index], index, _maintenanceSessions.length),
                ),
            ],
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
        Text(label, style: context.textStyles.label.copyWith(fontSize: 13, color: color)),
        const Spacer(),
        Text(
          '${plan.treatmentType} · ₹${plan.sessionFee.toInt()}/session',
          style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }

  Widget _sessionTile(SessionModel session, int index, int totalCount) {
    final isMaintenance = session.isMaintenance;
    final effectiveStatus = _displayStatus(session);
    final statusColor = _sessionStatusColor(effectiveStatus);
    final accentColor = isMaintenance ? context.colors.success : context.colors.primary;
    final date = DateTime.tryParse(session.scheduledDate);
    final dateLabel = date != null ? DateFormat('EEE, MMM d').format(date) : '—';
    final isEditable = effectiveStatus == SessionStatus.inProgress;
    final hasClinicalData = (session.notes?.trim().isNotEmpty == true) ||
        (session.bpLevel?.trim().isNotEmpty == true) ||
        (session.pulse != null && session.pulse! > 0) ||
        (session.photos.isNotEmpty) ||
        (session.remarks?.trim().isNotEmpty == true);
    final isViewable = effectiveStatus == SessionStatus.completed ||
        effectiveStatus == SessionStatus.missed ||
        hasClinicalData;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = date != null
        ? DateTime(date.toLocal().year, date.toLocal().month, date.toLocal().day)
        : null;
    final isToday = sessionDay != null && sessionDay.isAtSameMomentAs(today);

    // Timeline dots styling
    final isCompleted = effectiveStatus == SessionStatus.completed;
    final isInProgress = effectiveStatus == SessionStatus.inProgress;
    final isMissed = effectiveStatus == SessionStatus.missed;
    final isCancelled = effectiveStatus == SessionStatus.cancelled;

    Widget dotWidget;
    if (isCompleted) {
      dotWidget = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: context.colors.success,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.check, size: 13, color: Colors.white),
      );
    } else if (isInProgress) {
      dotWidget = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: context.colors.warning,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '${session.sessionNumber}',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else if (isMissed || isCancelled) {
      dotWidget = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: context.colors.error,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          isCancelled ? Icons.close_rounded : Icons.priority_high_rounded,
          size: 11,
          color: Colors.white,
        ),
      );
    } else {
      // Upcoming
      dotWidget = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: context.colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.border, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          '${session.sessionNumber}',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        if (!isEditable && !isViewable) return;
        if (isEditable) {
          final sessionDay = date != null
              ? DateTime(date.toLocal().year, date.toLocal().month, date.toLocal().day)
              : null;
          final isFutureSession = sessionDay != null && sessionDay.isAfter(today);

          if (isFutureSession) {
            final proceed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Date Mismatch'),
                content: const Text('This session is not scheduled for today. Record anyway?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Proceed', style: TextStyle(color: context.colors.primary))),
                ],
              ),
            );
            if (proceed != true || !mounted) return;
          }
        }

        await Navigator.pushNamed(context, '/sessions/record', arguments: {
          'session': session,
          'patientName': patient.fullName,
        });
        if (mounted) {
          final planId = isMaintenance ? _maintenancePlan?.id : _treatmentPlan?.id;
          if (planId != null) {
            setState(() {
              if (isMaintenance) _maintenanceSessions = [];
              else _treatmentSessions = [];
            });
            await _loadSessions(planId, isMaintenance: isMaintenance);
          }
          widget.onReturn();
        }
      },
      onLongPress: () => _showSessionActions(session),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left vertical line + dot
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 2,
                      color: index == 0 ? Colors.transparent : context.colors.border.withValues(alpha: 0.8),
                    ),
                  ),
                  dotWidget,
                  Expanded(
                    child: Container(
                      width: 2,
                      color: index == totalCount - 1 ? Colors.transparent : context.colors.border.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Session details card
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isEditable
                      ? accentColor.withValues(alpha: 0.03)
                      : context.colors.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isEditable
                        ? accentColor.withValues(alpha: 0.2)
                        : context.colors.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${isMaintenance ? "Maintenance" : "Session"} ${session.sessionNumber}',
                                style: context.textStyles.label.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (isMaintenance) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: context.colors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('M',
                                      style: context.textStyles.caption.copyWith(
                                          color: context.colors.success, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(dateLabel, style: context.textStyles.caption.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        _sessionStatusLabel(session, effectiveStatus),
                        style: context.textStyles.caption.copyWith(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isEditable) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: context.colors.textHint, size: 16),
                      Icon(Icons.more_vert_rounded, color: context.colors.textHint.withValues(alpha: 0.4), size: 13),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show action popup menu for session management.
  void _showSessionActions(SessionModel session) {
    final canAct = session.status == SessionStatus.upcoming ||
        session.status == SessionStatus.waiting ||
        session.status == SessionStatus.inProgress;
    if (!canAct) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
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
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${session.isMaintenance ? "Maintenance" : "Session"} ${session.sessionNumber}',
              style: context.textStyles.h4,
            ),
            Text(
              'Scheduled: ${session.scheduledDate}${session.scheduledTime != null ? " at ${session.scheduledTime}" : ""}',
              style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 20),
            _actionTile(
              ctx,
              icon: Icons.calendar_month_rounded,
              color: context.colors.primary,
              label: 'Reschedule Session',
              onTap: () async {
                Navigator.pop(ctx);
                await _rescheduleSession(session);
              },
            ),
            _actionTile(
              ctx,
              icon: Icons.warning_amber_rounded,
              color: context.colors.warning,
              label: 'Mark as Missed',
              onTap: () async {
                Navigator.pop(ctx);
                await _markMissed(session);
              },
            ),
            _actionTile(
              ctx,
              icon: Icons.cancel_outlined,
              color: context.colors.error,
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
      title: Text(label, style: context.textStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
  Future<void> _startSession(SessionModel session) async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final aptService = ref.read(appointmentServiceProvider);
      final treatmentService = ref.read(treatmentServiceProvider);
      
      String datePart = session.scheduledDate;
      try {
        final dt = DateTime.parse(session.scheduledDate);
        datePart = DateFormat('yyyy-MM-dd').format(dt);
      } catch (_) {}

      final apts = await pb.collection(PBCollections.appointments).getList(
        filter: 'type = "session" && patient = "${patient.id}" && date >= "$datePart 00:00:00.000Z" && date <= "$datePart 23:59:59.999Z"',
      );
      
      if (apts.items.isNotEmpty) {
        final aptId = apts.items.first.id;
        await aptService.startSession(aptId);
      }
      
      await treatmentService.startSessionRecord(session.id);
      
      if (mounted) {
        await Navigator.pushNamed(context, '/sessions/record', arguments: {
          'session': session,
          'patientName': patient.fullName,
        });
        setState(() {
          _planLoaded = false;
          if (session.isMaintenance) {
            _maintenanceSessions = [];
          } else {
            _treatmentSessions = [];
          }
        });
        await _loadPlans();
        widget.onReturn();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting session: $e')));
      }
    }
  }

  /// Force-end all remaining upcoming sessions for this consultation.
  Future<void> _endSessionsForConsultation() async {
    final allSessions = [..._treatmentSessions, ..._maintenanceSessions];
    final pendingCount = allSessions.where((s) =>
        s.status == SessionStatus.upcoming ||
        s.status == SessionStatus.waiting ||
        s.status == SessionStatus.inProgress).length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End All Sessions?'),
        content: Text(
          'This will cancel $pendingCount remaining session(s) and remove them from the schedule.\n\n'
          'You can create maintenance sessions afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Sessions'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final service = ref.read(treatmentServiceProvider);
      await service.endConsultation(c.id);
      try {
        ref.read(appointmentListProvider.notifier).loadAppointments();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$pendingCount session(s) cancelled and removed from schedule.'),
          backgroundColor: context.colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        // Refresh sessions
        setState(() {
          _planLoaded = false;
          _treatmentSessions = [];
          _maintenanceSessions = [];
        });
        await _loadPlans();
        widget.onReturn();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: context.colors.error,
        ));
      }
    }
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
          backgroundColor: context.colors.success,
        ));
        final isMaintenance = session.isMaintenance;
        final planId = isMaintenance ? _maintenancePlan?.id : _treatmentPlan?.id;
        if (planId != null) await _loadSessions(planId, isMaintenance: isMaintenance);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: context.colors.error,
        ));
      }
    }
  }

  Future<void> _markMissed(SessionModel session) async {
    try {
      final service = ref.read(treatmentServiceProvider);
      await service.markSessionMissed(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session marked as missed.'), backgroundColor: context.colors.warning,
        ));
        final isMaintenance = session.isMaintenance;
        final planId = isMaintenance ? _maintenancePlan?.id : _treatmentPlan?.id;
        if (planId != null) await _loadSessions(planId, isMaintenance: isMaintenance);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: context.colors.error,
        ));
      }
    }
  }

  Future<void> _cancelSession(SessionModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Session #${session.sessionNumber}?'),
        content: const Text('This will cancel this session and remove it from the schedule.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: Colors.white),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session cancelled.'), backgroundColor: context.colors.success,
        ));
        final isMaintenance = session.isMaintenance;
        final planId = isMaintenance ? _maintenancePlan?.id : _treatmentPlan?.id;
        if (planId != null) await _loadSessions(planId, isMaintenance: isMaintenance);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'), backgroundColor: context.colors.error,
        ));
      }
    }
  }

  Color _sessionStatusColor(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:    return context.colors.info;
      case SessionStatus.waiting:     return context.colors.warning;
      case SessionStatus.inProgress:  return const Color(0xFFF59E0B);
      case SessionStatus.completed:   return context.colors.success;
      case SessionStatus.missed:      return context.colors.warning;
      case SessionStatus.cancelled:   return context.colors.error;
      case SessionStatus.paused:       return context.colors.info;
    }
  }

  String _sessionStatusLabel(SessionModel session, SessionStatus s) {
    // 'waiting' = Patient Arrived button was clicked
    if (s == SessionStatus.waiting) return 'Patient Waiting';
    if (s == SessionStatus.inProgress) return 'Ongoing';
    if (s == SessionStatus.completed) return 'Completed';
    if (s == SessionStatus.missed) return 'Missed';
    if (s == SessionStatus.cancelled) return 'Cancelled';

    // upcoming — check if today or future
    if (s == SessionStatus.upcoming) {
      final dt = DateTime.tryParse(session.scheduledDate);
      if (dt != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final sessionDay = DateTime(dt.year, dt.month, dt.day);
        if (sessionDay.isAtSameMomentAs(today)) {
          return 'Waiting to Start';
        }
      }
      return 'Upcoming';
    }
    return 'Upcoming';
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
  final List<String> detailsTimeline;

  _HistoryEvent({
    required this.type,
    required this.date,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.detailsTimeline = const [],
  });
}