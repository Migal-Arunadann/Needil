import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

class DashboardStats {
  // Today's counts by type (keep compatibility)
  final int consultationsToday;  // type = call_by or walk_in
  final int sessionAppointmentsToday;  // type = session

  // Today's status breakdown (all types)
  final int scheduledCount;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;

  // Summary bar stats
  final int walkInsToday;         // walk_in type today (non-cancelled)
  final int pendingConsultations; // walk_in/call_by today that are scheduled/waiting/in_progress

  // Today's overview detailed breakdown
  final int consultationsTotalToday;
  final int consultationsCompletedToday;
  final int consultationsPendingToday;

  final int sessionsTotalToday;
  final int sessionsCompletedToday;
  final int sessionsPendingToday;

  final int patientsSeenToday;
  final int patientsExpectedToday;
  final int patientsRemainingToday;

  final int feesTotalToday;
  final int feesOnlyConsultationToday;
  final int feesConsultationAndSessionToday;
  final int feesOnlySessionToday;

  // Practice overview
  final int totalPatients;
  final int activePlans;
  final int patientsWithActiveSessions;

  // Next upcoming appointment for today
  final AppointmentModel? nextAppointment;

  final List<AppointmentModel> todayAppointments;
  final Map<String, String> appointmentTreatmentTypes;

  final bool isLoading;

  const DashboardStats({
    this.consultationsToday = 0,
    this.sessionAppointmentsToday = 0,
    this.scheduledCount = 0,
    this.inProgressCount = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
    this.walkInsToday = 0,
    this.pendingConsultations = 0,
    this.consultationsTotalToday = 0,
    this.consultationsCompletedToday = 0,
    this.consultationsPendingToday = 0,
    this.sessionsTotalToday = 0,
    this.sessionsCompletedToday = 0,
    this.sessionsPendingToday = 0,
    this.patientsSeenToday = 0,
    this.patientsExpectedToday = 0,
    this.patientsRemainingToday = 0,
    this.feesTotalToday = 0,
    this.feesOnlyConsultationToday = 0,
    this.feesConsultationAndSessionToday = 0,
    this.feesOnlySessionToday = 0,
    this.totalPatients = 0,
    this.activePlans = 0,
    this.patientsWithActiveSessions = 0,
    this.nextAppointment,
    this.todayAppointments = const [],
    this.appointmentTreatmentTypes = const {},
    this.isLoading = false,
  });

  DashboardStats copyWith({
    int? consultationsToday,
    int? sessionAppointmentsToday,
    int? scheduledCount,
    int? inProgressCount,
    int? completedCount,
    int? cancelledCount,
    int? walkInsToday,
    int? pendingConsultations,
    int? consultationsTotalToday,
    int? consultationsCompletedToday,
    int? consultationsPendingToday,
    int? sessionsTotalToday,
    int? sessionsCompletedToday,
    int? sessionsPendingToday,
    int? patientsSeenToday,
    int? patientsExpectedToday,
    int? patientsRemainingToday,
    int? feesTotalToday,
    int? feesOnlyConsultationToday,
    int? feesConsultationAndSessionToday,
    int? feesOnlySessionToday,
    int? totalPatients,
    int? activePlans,
    int? patientsWithActiveSessions,
    AppointmentModel? nextAppointment,
    List<AppointmentModel>? todayAppointments,
    Map<String, String>? appointmentTreatmentTypes,
    bool? clearNextAppointment,
    bool? isLoading,
  }) {
    return DashboardStats(
      consultationsToday: consultationsToday ?? this.consultationsToday,
      sessionAppointmentsToday: sessionAppointmentsToday ?? this.sessionAppointmentsToday,
      scheduledCount: scheduledCount ?? this.scheduledCount,
      inProgressCount: inProgressCount ?? this.inProgressCount,
      completedCount: completedCount ?? this.completedCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      walkInsToday: walkInsToday ?? this.walkInsToday,
      pendingConsultations: pendingConsultations ?? this.pendingConsultations,
      consultationsTotalToday: consultationsTotalToday ?? this.consultationsTotalToday,
      consultationsCompletedToday: consultationsCompletedToday ?? this.consultationsCompletedToday,
      consultationsPendingToday: consultationsPendingToday ?? this.consultationsPendingToday,
      sessionsTotalToday: sessionsTotalToday ?? this.sessionsTotalToday,
      sessionsCompletedToday: sessionsCompletedToday ?? this.sessionsCompletedToday,
      sessionsPendingToday: sessionsPendingToday ?? this.sessionsPendingToday,
      patientsSeenToday: patientsSeenToday ?? this.patientsSeenToday,
      patientsExpectedToday: patientsExpectedToday ?? this.patientsExpectedToday,
      patientsRemainingToday: patientsRemainingToday ?? this.patientsRemainingToday,
      feesTotalToday: feesTotalToday ?? this.feesTotalToday,
      feesOnlyConsultationToday: feesOnlyConsultationToday ?? this.feesOnlyConsultationToday,
      feesConsultationAndSessionToday: feesConsultationAndSessionToday ?? this.feesConsultationAndSessionToday,
      feesOnlySessionToday: feesOnlySessionToday ?? this.feesOnlySessionToday,
      totalPatients: totalPatients ?? this.totalPatients,
      activePlans: activePlans ?? this.activePlans,
      patientsWithActiveSessions: patientsWithActiveSessions ?? this.patientsWithActiveSessions,
      nextAppointment: clearNextAppointment == true ? null : (nextAppointment ?? this.nextAppointment),
      todayAppointments: todayAppointments ?? this.todayAppointments,
      appointmentTreatmentTypes: appointmentTreatmentTypes ?? this.appointmentTreatmentTypes,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DashboardStatsNotifier extends StateNotifier<DashboardStats> {
  final Ref _ref;
  DashboardStatsNotifier(this._ref) : super(const DashboardStats(isLoading: true));

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final pb = _ref.read(pocketbaseProvider);
    final auth = _ref.read(authProvider);
    final userId = auth.userId;

    if (userId == null) {
      debugPrint('[Dashboard] No userId — not authenticated');
      state = const DashboardStats();
      return;
    }

    final today = _todayStr();
    final isClinic = auth.role == UserRole.clinic;
    final isReceptionist = auth.role == UserRole.receptionist;

    // Receptionists see all clinic data — resolve the clinic ID
    String ownerField;
    String ownerId;
    String planOwnerFilter;

    if (isClinic) {
      ownerField = 'clinic';
      ownerId = userId;
      planOwnerFilter = 'doctor.clinic = "$userId"';
    } else if (isReceptionist) {
      // Receptionist's clinicId comes from their record
      final clinicId = auth.clinicId ?? '';
      ownerField = 'clinic';
      ownerId = clinicId;
      planOwnerFilter = 'doctor.clinic = "$clinicId"';
    } else {
      // Doctor
      ownerField = 'doctor';
      ownerId = userId;
      planOwnerFilter = 'doctor = "$userId"';
    }

    final String sessionOwnerFilter;
    if (isClinic || isReceptionist) {
      sessionOwnerFilter = 'doctor.clinic = "$ownerId"';
    } else {
      sessionOwnerFilter = 'doctor = "$ownerId"';
    }

    debugPrint('[Dashboard] Loading for $ownerField=$ownerId, today=$today');

    // Helper: safe getList count
    Future<int> safeCount(String collection, String filter) async {
      try {
        final res = await pb.collection(collection).getList(
          filter: filter,
          perPage: 1,
          skipTotal: false,
        );
        return res.totalItems;
      } catch (e) {
        debugPrint('[Dashboard] FAILED $collection filter="$filter": $e');
        return 0;
      }
    }

    // 1. Fetch today's appointments in parallel
    List<AppointmentModel> todayAppointments = [];
    try {
      final res = await pb.collection(PBCollections.appointments).getList(
        filter: '$ownerField = "$ownerId" && date = "$today"',
        perPage: 500,
        expand: 'patient',
      );
      todayAppointments = res.items.map((r) => AppointmentModel.fromRecord(r)).toList();
    } catch (e) {
      debugPrint('[DashboardStats] Error fetching today\'s appointments: $e');
    }

    // 2. Count stats from today's appointments list
    final consultationsToday = todayAppointments
        .where((a) => (a.type == AppointmentType.callBy || a.type == AppointmentType.walkIn) && a.status != AppointmentStatus.cancelled)
        .length;
    
    final sessionAppointmentsToday = todayAppointments
        .where((a) => a.type == AppointmentType.session && a.status != AppointmentStatus.cancelled)
        .length;

    final consultationsTotalToday = consultationsToday;
    final consultationsCompletedToday = todayAppointments
        .where((a) => (a.type == AppointmentType.callBy || a.type == AppointmentType.walkIn) && a.status == AppointmentStatus.completed)
        .length;
    final consultationsPendingToday = todayAppointments
        .where((a) => (a.type == AppointmentType.callBy || a.type == AppointmentType.walkIn) && 
            (a.status == AppointmentStatus.scheduled || a.status == AppointmentStatus.waiting || a.status == AppointmentStatus.inProgress))
        .length;

    final sessionsTotalToday = sessionAppointmentsToday;
    final sessionsCompletedToday = todayAppointments
        .where((a) => a.type == AppointmentType.session && a.status == AppointmentStatus.completed)
        .length;
    final sessionsPendingToday = todayAppointments
        .where((a) => a.type == AppointmentType.session && 
            (a.status == AppointmentStatus.scheduled || a.status == AppointmentStatus.waiting || a.status == AppointmentStatus.inProgress))
        .length;

    final scheduledCount = todayAppointments.where((a) => a.status == AppointmentStatus.scheduled).length;
    final inProgressCount = todayAppointments.where((a) => a.status == AppointmentStatus.inProgress).length;
    final completedCount = todayAppointments.where((a) => a.status == AppointmentStatus.completed).length;
    final cancelledCount = todayAppointments.where((a) => a.status == AppointmentStatus.cancelled).length;

    final walkInsToday = todayAppointments
        .where((a) => a.type == AppointmentType.walkIn && a.status != AppointmentStatus.cancelled)
        .length;
    final pendingConsultations = consultationsPendingToday;

    // 3. Unique patients seen today & total expected
    final seenPatients = <String>{};
    final allExpectedPatients = <String>{};
    for (final appt in todayAppointments) {
      final pKey = appt.patientId ?? appt.effectivePhone ?? appt.displayName;
      if (pKey.trim().isNotEmpty && appt.status != AppointmentStatus.cancelled) {
        allExpectedPatients.add(pKey.trim());
      }
      final isSeen = appt.status == AppointmentStatus.completed ||
                     appt.status == AppointmentStatus.inProgress ||
                     appt.status == AppointmentStatus.waiting ||
                     appt.checkInTime != null;
      if (isSeen && pKey.trim().isNotEmpty) {
        seenPatients.add(pKey.trim());
      }
    }
    final patientsSeenToday = seenPatients.length;
    final patientsExpectedToday = allExpectedPatients.length;
    final patientsRemainingToday = (patientsExpectedToday - patientsSeenToday).clamp(0, 999);

    // 4. Calculate fee collections today
    final completedConsultationIds = todayAppointments
        .where((a) => (a.type == AppointmentType.callBy || a.type == AppointmentType.walkIn) && 
            a.status == AppointmentStatus.completed && 
            a.linkedConsultationId != null)
        .map((a) => a.linkedConsultationId!)
        .toSet()
        .toList();

    final consultationChargesMap = <String, double>{};
    if (completedConsultationIds.isNotEmpty) {
      try {
        final filter = completedConsultationIds.map((id) => 'id = "$id"').join(' || ');
        final consultRes = await pb.collection(PBCollections.consultations).getList(
          filter: filter,
          perPage: completedConsultationIds.length,
        );
        for (final r in consultRes.items) {
          final charged = r.getBoolValue('charged');
          if (charged) {
            consultationChargesMap[r.id] = r.getDoubleValue('charge_amount');
          }
        }
      } catch (e) {
        debugPrint('[DashboardStats] Error fetching consultation fees: $e');
      }
    }

    final todaySessionsList = <RecordModel>[];
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: '$sessionOwnerFilter && scheduled_date >= "$today 00:00:00.000Z" && scheduled_date <= "$today 23:59:59.999Z"',
        perPage: 500,
        expand: 'treatment_plan',
      );
      todaySessionsList.addAll(res.items);
    } catch (e) {
      debugPrint('[DashboardStats] Error fetching today sessions: $e');
    }

    final completedSessionsList = todaySessionsList.where((s) => s.getStringValue('status') == 'completed').toList();

    final treatmentTypesMap = <String, String>{};
    for (final appt in todayAppointments) {
      if (appt.type == AppointmentType.callBy) {
        treatmentTypesMap[appt.id] = 'Consultation';
      } else if (appt.type == AppointmentType.walkIn) {
        treatmentTypesMap[appt.id] = 'Walk-in';
      } else if (appt.type == AppointmentType.session) {
        RecordModel? match;
        if (appt.linkedSessionId != null && appt.linkedSessionId!.isNotEmpty) {
          match = todaySessionsList.cast<RecordModel?>().firstWhere((s) => s?.id == appt.linkedSessionId, orElse: () => null);
        }
        if (match == null && appt.patientId != null && appt.patientId!.isNotEmpty) {
          match = todaySessionsList.cast<RecordModel?>().firstWhere(
            (s) => s != null && s.getStringValue('patient') == appt.patientId,
            orElse: () => null,
          );
        }

        String modality = '';
        String sType = appt.sessionType ?? 'treatment';
        if (match != null) {
          modality = match.getStringValue('treatment_type');
          if (modality.isEmpty) {
            final plans = match.get<List<RecordModel>>('expand.treatment_plan');
            final planRec = plans.isNotEmpty ? plans.first : null;
            modality = planRec?.getStringValue('treatment_type') ?? '';
          }
          final recType = match.getStringValue('session_type');
          if (recType.isNotEmpty) sType = recType;
        }

        if (modality.trim().isNotEmpty) {
          treatmentTypesMap[appt.id] = modality.trim();
        } else if (sType == 'maintenance') {
          treatmentTypesMap[appt.id] = 'Maintenance';
        } else {
          treatmentTypesMap[appt.id] = 'Treatment';
        }
      }
    }

    final planIds = completedSessionsList
        .map((s) => s.getStringValue('treatment_plan'))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final planFeesMap = <String, double>{};
    if (planIds.isNotEmpty) {
      try {
        final plansFilter = planIds.map((id) => 'id = "$id"').join(' || ');
        final plansRes = await pb.collection(PBCollections.treatmentPlans).getList(
          filter: plansFilter,
          perPage: planIds.length,
        );
        for (final p in plansRes.items) {
          planFeesMap[p.id] = p.getDoubleValue('session_fee');
        }
      } catch (e) {
        debugPrint('[DashboardStats] Error fetching plan fees: $e');
      }
    }

    final patientSessionFeesMap = <String, double>{};
    for (final s in completedSessionsList) {
      final fee = planFeesMap[s.getStringValue('treatment_plan')] ?? 0.0;
      final patientKey = s.getStringValue('patient');
      if (patientKey.isNotEmpty) {
        patientSessionFeesMap[patientKey] = (patientSessionFeesMap[patientKey] ?? 0.0) + fee;
      }
    }

    final patientCompletedVisits = <String, List<AppointmentModel>>{};
    for (final appt in todayAppointments) {
      if (appt.status == AppointmentStatus.completed) {
        final patientKey = appt.patientId ?? appt.effectivePhone ?? appt.displayName;
        if (patientKey.trim().isNotEmpty) {
          patientCompletedVisits.putIfAbsent(patientKey.trim(), () => []).add(appt);
        }
      }
    }

    double onlyConsultationFees = 0;
    double onlySessionFees = 0;
    double consultationAndSessionFees = 0;

    for (final entry in patientCompletedVisits.entries) {
      final patientKey = entry.key;
      final appts = entry.value;

      final hasConsultation = appts.any((a) => a.type == AppointmentType.callBy || a.type == AppointmentType.walkIn);
      final hasSession = appts.any((a) => a.type == AppointmentType.session);

      double consultCharge = 0;
      for (final a in appts) {
        if ((a.type == AppointmentType.callBy || a.type == AppointmentType.walkIn) && a.linkedConsultationId != null) {
          consultCharge += consultationChargesMap[a.linkedConsultationId] ?? 0.0;
        }
      }

      double sessionCharge = patientSessionFeesMap[patientKey] ?? 0.0;

      if (hasConsultation && hasSession) {
        consultationAndSessionFees += (consultCharge + sessionCharge);
      } else if (hasConsultation) {
        onlyConsultationFees += consultCharge;
      } else if (hasSession) {
        onlySessionFees += sessionCharge;
      }
    }

    final feesTotalToday = (onlyConsultationFees + onlySessionFees + consultationAndSessionFees).toInt();
    final feesOnlyConsultationToday = onlyConsultationFees.toInt();
    final feesConsultationAndSessionToday = consultationAndSessionFees.toInt();
    final feesOnlySessionToday = onlySessionFees.toInt();

    // 5. Fetch overview stats
    final generalCounts = await Future.wait([
      safeCount(PBCollections.patients, '$ownerField = "$ownerId"'),
      safeCount(PBCollections.treatmentPlans, '$planOwnerFilter && status = "active"'),
    ]);

    final totalPatients = generalCounts[0];
    final activePlans = generalCounts[1];

    int patientsWithActiveSessions = 0;
    try {
      final activeSessionsRes = await pb.collection(PBCollections.sessions).getList(
        filter: '$sessionOwnerFilter && (status = "upcoming" || status = "waiting" || status = "in_progress")',
        perPage: 1000,
        fields: 'patient',
      );
      patientsWithActiveSessions = activeSessionsRes.items
          .map((s) => s.getStringValue('patient'))
          .where((id) => id.isNotEmpty)
          .toSet()
          .length;
    } catch (e) {
      debugPrint('[DashboardStats] Error calculating patients with active sessions: $e');
    }

    // 6. Fetch the single next upcoming appointment
    AppointmentModel? nextAppt;
    try {
      final nextRes = await pb.collection(PBCollections.appointments).getList(
        filter: '$ownerField = "$ownerId" && date = "$today" && status = "scheduled"',
        sort: 'time',
        perPage: 1,
        expand: 'patient,doctor',
      );
      if (nextRes.items.isNotEmpty) {
        nextAppt = AppointmentModel.fromRecord(nextRes.items.first);
      }
    } catch (e) {
      debugPrint('[Dashboard] Failed to fetch next appointment: $e');
    }

    state = DashboardStats(
      consultationsToday: consultationsToday,
      sessionAppointmentsToday: sessionAppointmentsToday,
      scheduledCount: scheduledCount,
      inProgressCount: inProgressCount,
      completedCount: completedCount,
      cancelledCount: cancelledCount,
      walkInsToday: walkInsToday,
      pendingConsultations: pendingConsultations,
      consultationsTotalToday: consultationsTotalToday,
      consultationsCompletedToday: consultationsCompletedToday,
      consultationsPendingToday: consultationsPendingToday,
      sessionsTotalToday: sessionsTotalToday,
      sessionsCompletedToday: sessionsCompletedToday,
      sessionsPendingToday: sessionsPendingToday,
      patientsSeenToday: patientsSeenToday,
      patientsExpectedToday: patientsExpectedToday,
      patientsRemainingToday: patientsRemainingToday,
      feesTotalToday: feesTotalToday,
      feesOnlyConsultationToday: feesOnlyConsultationToday,
      feesConsultationAndSessionToday: feesConsultationAndSessionToday,
      feesOnlySessionToday: feesOnlySessionToday,
      totalPatients: totalPatients,
      activePlans: activePlans,
      patientsWithActiveSessions: patientsWithActiveSessions,
      nextAppointment: nextAppt,
      todayAppointments: todayAppointments,
      appointmentTreatmentTypes: treatmentTypesMap,
      isLoading: false,
    );
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

final dashboardStatsProvider =
    StateNotifierProvider<DashboardStatsNotifier, DashboardStats>((ref) {
  final notifier = DashboardStatsNotifier(ref);
  notifier.load();
  return notifier;
});
