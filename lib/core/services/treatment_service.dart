import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../constants/pb_collections.dart';
import '../../features/consultations/models/consultation_model.dart';
import '../../features/treatments/models/treatment_plan_model.dart';
import '../../features/treatments/models/session_model.dart';
import '../../features/auth/models/doctor_model.dart';

class TreatmentService {
  final PocketBase pb;

  TreatmentService(this.pb);

  // ─── Consultations ─────────────────────────────────────────

  Future<ConsultationModel> createConsultation({
    required String patientId,
    required String doctorId,
    String? notes,
    String? chiefComplaint,
    String? medicalHistory,
    String? pastIllnesses,
    String? currentMedications,
    String? allergies,
    String? chronicDiseases,
    String? dietPattern,
    String? sleepQuality,
    String? exerciseLevel,
    String? addictions,
    String? stressLevel,
    String? pregnancyStatus,
    bool consentGiven = true,
    String? bpLevel,
    int? pulse,
    bool charged = false,
    double? chargeAmount,
    List<String> photoPaths = const [],
  }) async {
    final body = <String, dynamic>{
      'patient': patientId,
      'doctor': doctorId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (chiefComplaint != null && chiefComplaint.isNotEmpty) 'chief_complaint': chiefComplaint,
      if (medicalHistory != null && medicalHistory.isNotEmpty) 'medical_history': medicalHistory,
      if (pastIllnesses != null && pastIllnesses.isNotEmpty) 'past_illnesses': pastIllnesses,
      if (currentMedications != null && currentMedications.isNotEmpty) 'current_medications': currentMedications,
      if (allergies != null && allergies.isNotEmpty) 'allergies': allergies,
      if (chronicDiseases != null && chronicDiseases.isNotEmpty) 'chronic_diseases': chronicDiseases,
      if (dietPattern != null && dietPattern.isNotEmpty) 'diet_pattern': dietPattern,
      if (sleepQuality != null && sleepQuality.isNotEmpty) 'sleep_quality': sleepQuality,
      if (exerciseLevel != null && exerciseLevel.isNotEmpty) 'exercise_level': exerciseLevel,
      if (addictions != null && addictions.isNotEmpty) 'addictions': addictions,
      if (stressLevel != null && stressLevel.isNotEmpty) 'stress_level': stressLevel,
      if (pregnancyStatus != null && pregnancyStatus.isNotEmpty) 'pregnancy_status': pregnancyStatus,
      'consent_given': consentGiven,
      if (bpLevel != null && bpLevel.isNotEmpty) 'bp_level': bpLevel,
      if (pulse != null) 'pulse': pulse,
      'charged': charged,
      if (chargeAmount != null) 'charge_amount': chargeAmount,
      'status': 'ongoing',
    };

    final files = <http.MultipartFile>[];
    for (final path in photoPaths) {
      files.add(await http.MultipartFile.fromPath('photos', path));
    }

    final record = await pb.collection(PBCollections.consultations).create(
      body: body,
      files: files,
    );
    return ConsultationModel.fromRecord(record);
  }

  Future<ConsultationModel> updateConsultation({
    required String consultationId,
    String? notes,
    String? chiefComplaint,
    String? medicalHistory,
    String? pastIllnesses,
    String? currentMedications,
    String? allergies,
    String? chronicDiseases,
    String? dietPattern,
    String? sleepQuality,
    String? exerciseLevel,
    String? addictions,
    String? stressLevel,
    String? pregnancyStatus,
    bool? consentGiven,
    String? bpLevel,
    int? pulse,
    bool? charged,
    double? chargeAmount,
    List<String> newPhotoPaths = const [],
  }) async {
    // NOTE: Status is intentionally NOT changed here.
    // The consultation stays 'ongoing' until the doctor explicitly ends the treatment.
    final body = <String, dynamic>{
      if (notes != null) 'notes': notes,
      if (chiefComplaint != null) 'chief_complaint': chiefComplaint,
      if (medicalHistory != null) 'medical_history': medicalHistory,
      if (pastIllnesses != null) 'past_illnesses': pastIllnesses,
      if (currentMedications != null) 'current_medications': currentMedications,
      if (allergies != null) 'allergies': allergies,
      if (chronicDiseases != null) 'chronic_diseases': chronicDiseases,
      if (dietPattern != null) 'diet_pattern': dietPattern,
      if (sleepQuality != null) 'sleep_quality': sleepQuality,
      if (exerciseLevel != null) 'exercise_level': exerciseLevel,
      if (addictions != null) 'addictions': addictions,
      if (stressLevel != null) 'stress_level': stressLevel,
      if (pregnancyStatus != null) 'pregnancy_status': pregnancyStatus,
      if (consentGiven != null) 'consent_given': consentGiven,
      if (bpLevel != null) 'bp_level': bpLevel,
      if (pulse != null) 'pulse': pulse,
      if (charged != null) 'charged': charged,
      if (chargeAmount != null) 'charge_amount': chargeAmount,
    };

    final files = <http.MultipartFile>[];
    for (final path in newPhotoPaths) {
      if (!path.startsWith('http')) {
        files.add(await http.MultipartFile.fromPath('photos', path));
      }
    }

    final record = await pb.collection(PBCollections.consultations).update(
      consultationId,
      body: body,
      files: files,
    );
    return ConsultationModel.fromRecord(record);
  }

  /// Get consultations for a patient.
  Future<List<ConsultationModel>> getPatientConsultations(String patientId) async {
    final result = await pb.collection(PBCollections.consultations).getList(
      filter: 'patient = "$patientId"',
      expand: 'patient',
    );
    return result.items.map((r) => ConsultationModel.fromRecord(r)).toList();
  }

  // ─── Treatment Plans ───────────────────────────────────────

  /// Create a treatment plan and auto-generate session records using smart scheduling.
  Future<TreatmentPlanModel> createSmartTreatmentPlan({
    required String patientId,
    required String doctorId,
    String? consultationId,
    required String treatmentType,
    required String startDate,
    required String preferredTime,
    required int totalSessions,
    required int intervalDays,
    required double sessionFee,
    bool firstSessionCompletedToday = false,
  }) async {
    return _createPlan(
      patientId: patientId,
      doctorId: doctorId,
      consultationId: consultationId,
      treatmentType: treatmentType,
      startDate: startDate,
      preferredTime: preferredTime,
      totalSessions: totalSessions,
      intervalDays: intervalDays,
      sessionFee: sessionFee,
      planType: 'treatment',
      intervalUnit: 'days',
      firstSessionCompletedToday: firstSessionCompletedToday,
    );
  }

  /// Create a maintenance plan linked to a completed treatment plan.
  Future<TreatmentPlanModel> createMaintenancePlan({
    required String patientId,
    required String doctorId,
    String? consultationId,
    required String parentPlanId,
    required String treatmentType,
    required String startDate,
    required String preferredTime,
    required int totalSessions,
    required int intervalValue,   // the numeric part (e.g. 2)
    required String intervalUnit, // 'days', 'months', 'years'
    required double sessionFee,
  }) async {
    // Convert the interval to days for internal scheduling
    final intervalDays = _toIntervalDays(intervalValue, intervalUnit);
    return _createPlan(
      patientId: patientId,
      doctorId: doctorId,
      consultationId: consultationId,
      parentPlanId: parentPlanId,
      treatmentType: treatmentType,
      startDate: startDate,
      preferredTime: preferredTime,
      totalSessions: totalSessions,
      intervalDays: intervalDays,
      sessionFee: sessionFee,
      planType: 'maintenance',
      intervalUnit: intervalUnit,
      firstSessionCompletedToday: false, // never auto-start first maintenance session today
    );
  }

  /// Converts an interval value + unit to number of days for scheduling.
  int _toIntervalDays(int value, String unit) {
    switch (unit) {
      case 'months':
        return value * 30;
      case 'years':
        return value * 365;
      default:
        return value;
    }
  }

  /// Internal plan creation engine shared by treatment and maintenance plans.
  Future<TreatmentPlanModel> _createPlan({
    required String patientId,
    required String doctorId,
    String? consultationId,
    String? parentPlanId,
    required String treatmentType,
    required String startDate,
    required String preferredTime,
    required int totalSessions,
    required int intervalDays,
    required double sessionFee,
    required String planType,     // 'treatment' or 'maintenance'
    required String intervalUnit, // 'days', 'months', 'years'
    bool firstSessionCompletedToday = false,
  }) async {
    // Attempt to fetch clinic bed count (fallback to default 3)
    int maxBeds = 3;
    String? validClinicId;
    try {
      final docRec = await pb.collection('doctors').getOne(doctorId);
      validClinicId = docRec.getStringValue('clinic');
      if (validClinicId.isNotEmpty) {
        final clinicRec = await pb.collection('clinics').getOne(validClinicId);
        maxBeds = clinicRec.getIntValue('bed_count');
        if (maxBeds <= 0) maxBeds = 3;
      }
    } catch (_) {}

    // Create the plan record
    final planBody = {
      'patient': patientId,
      'doctor': doctorId,
      if (consultationId != null && consultationId.isNotEmpty)
        'consultation': consultationId,
      if (parentPlanId != null && parentPlanId.isNotEmpty)
        'parent_plan': parentPlanId,
      'treatment_type': treatmentType,
      'start_date': startDate,
      'total_sessions': totalSessions,
      'interval_days': intervalDays,
      'session_fee': sessionFee,
      'status': 'active',
      'plan_type': planType,
      'interval_unit': intervalUnit,
    };

    final planRecord = await pb.collection(PBCollections.treatmentPlans).create(body: planBody);
    final plan = TreatmentPlanModel.fromRecord(planRecord);

    // Auto-generate sessions
    final start = DateTime.parse(startDate);
    final timeParts = preferredTime.split(':');
    final pTimeHr = int.parse(timeParts[0]);
    final pTimeMn = int.parse(timeParts[1]);

    // Retrieve doctor's working days
    List<int> validDays = [];
    try {
      final docRec = await pb.collection('doctors').getOne(doctorId);
      final doctor = DoctorModel.fromRecord(docRec);
      validDays = doctor.workingDays;
    } catch (_) {}

    DateTime currentSessionDate = start;

    for (int i = 0; i < totalSessions; i++) {
      if (firstSessionCompletedToday && i == 0 && planType == 'treatment') {
        // First treatment session starts today
        final now = DateTime.now();
        final nowStr = _formatDate(now);
        final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        final sessionBody = {
          'treatment_plan': plan.id,
          'patient': patientId,
          'doctor': doctorId,
          if (validClinicId != null && validClinicId.isNotEmpty) 'clinic': validClinicId,
          if (consultationId != null && consultationId.isNotEmpty) 'consultation': consultationId,
          'session_number': 1,
          'scheduled_date': nowStr,
          'scheduled_time': timeStr,
          'status': 'upcoming',
          'session_type': planType,
          'check_in_time': now.toUtc().toIso8601String(),
        };
        await pb.collection(PBCollections.sessions).create(body: sessionBody);

        try {
          await pb.collection('appointments').create(body: {
            'patient': patientId,
            'doctor': doctorId,
            if (validClinicId != null && validClinicId.isNotEmpty) 'clinic': validClinicId,
            'type': 'session',
            'date': nowStr,
            'time': timeStr,
            'status': 'waiting',
            'session_type': planType,
            'check_in_time': now.toUtc().toIso8601String(),
          });
        } catch (_) {}

        currentSessionDate = currentSessionDate.add(Duration(days: intervalDays));
        continue;
      }

      // Find a valid slot
      String resolvedTimeStr = preferredTime;
      bool foundSlot = false;
      int dayAttempts = 0;

      while (!foundSlot && dayAttempts < 30) {
        if (validDays.isNotEmpty) {
          while (!validDays.contains(currentSessionDate.weekday)) {
            currentSessionDate = currentSessionDate.add(const Duration(days: 1));
          }
        }

        final tryDateStr = _formatDate(currentSessionDate);
        DateTime slotAttempt = DateTime(
            currentSessionDate.year, currentSessionDate.month,
            currentSessionDate.day, pTimeHr, pTimeMn);

        for (int attempt = 0; attempt < 16; attempt++) {
          if (slotAttempt.hour >= 20) break;

          final checkTimeStr =
              '${slotAttempt.hour.toString().padLeft(2, "0")}:${slotAttempt.minute.toString().padLeft(2, "0")}';

          final existingAppts = await pb.collection(PBCollections.appointments).getList(
            filter:
                'doctor = "$doctorId" && date = "$tryDateStr" && time = "$checkTimeStr" && status != "cancelled"',
          );

          if (existingAppts.totalItems < maxBeds) {
            resolvedTimeStr = checkTimeStr;
            foundSlot = true;
            break;
          }

          slotAttempt = slotAttempt.add(const Duration(minutes: 30));
        }

        if (!foundSlot) {
          currentSessionDate = currentSessionDate.add(const Duration(days: 1));
          dayAttempts++;
        }
      }

      final sessionDateStr = _formatDate(currentSessionDate);

      final sessionBody = {
        'treatment_plan': plan.id,
        'patient': patientId,
        'doctor': doctorId,
        if (validClinicId != null && validClinicId.isNotEmpty) 'clinic': validClinicId,
        if (consultationId != null && consultationId.isNotEmpty) 'consultation': consultationId,
        'session_number': i + 1,
        'scheduled_date': sessionDateStr,
        'scheduled_time': resolvedTimeStr,
        'status': 'upcoming',
        'session_type': planType,
      };
      await pb.collection(PBCollections.sessions).create(body: sessionBody);

      try {
        await pb.collection('appointments').create(body: {
          'patient': patientId,
          'doctor': doctorId,
          if (validClinicId != null && validClinicId.isNotEmpty) 'clinic': validClinicId,
          'type': 'session',
          'date': sessionDateStr,
          'time': resolvedTimeStr,
          'status': 'scheduled',
          'session_type': planType,
        });
      } catch (e) {
        throw Exception(
            'Failed to sync appointment to calendar. Ensure "session" type is added to PocketBase! Error: $e');
      }

      currentSessionDate = currentSessionDate.add(Duration(days: intervalDays));
    }

    return plan;
  }

  /// Get treatment plans for a patient.
  Future<List<TreatmentPlanModel>> getPatientPlans(String patientId) async {
    final result = await pb.collection(PBCollections.treatmentPlans).getList(
      filter: 'patient = "$patientId"',
      expand: 'patient',
    );
    return result.items.map((r) => TreatmentPlanModel.fromRecord(r)).toList();
  }

  /// Get treatment plans for a doctor.
  Future<List<TreatmentPlanModel>> getDoctorPlans(String doctorId) async {
    final result = await pb.collection(PBCollections.treatmentPlans).getList(
      filter: 'doctor = "$doctorId"',
      expand: 'patient',
    );
    return result.items.map((r) => TreatmentPlanModel.fromRecord(r)).toList();
  }

  /// Update treatment plan status.
  Future<void> updatePlanStatus(String planId, TreatmentPlanStatus status) async {
    await pb.collection(PBCollections.treatmentPlans).update(
      planId,
      body: {'status': TreatmentPlanModel.statusToString(status)},
    );
  }

  // ─── Sessions ──────────────────────────────────────────────

  /// Get sessions for a treatment plan.
  Future<List<SessionModel>> getPlanSessions(String planId) async {
    final result = await pb.collection(PBCollections.sessions).getList(
      filter: 'treatment_plan = "$planId"',
      sort: 'session_number',
    );
    return result.items.map((r) => SessionModel.fromRecord(r)).toList();
  }

  /// Get today's sessions for a doctor.
  Future<List<SessionModel>> getDoctorTodaySessions(String doctorId) async {
    final today = _formatDate(DateTime.now());
    final result = await pb.collection(PBCollections.sessions).getList(
      filter: 'doctor = "$doctorId" && scheduled_date = "$today"',
      sort: 'scheduled_time',
    );
    return result.items.map((r) => SessionModel.fromRecord(r)).toList();
  }

  /// Record a completed session with vitals and photos.
  Future<SessionModel> recordSession({
    required String sessionId,
    String? notes,
    String? bpLevel,
    int? pulse,
    String? remarks,
    List<String> photoPaths = const [],
  }) async {
    final body = <String, dynamic>{
      'status': 'completed',
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (bpLevel != null && bpLevel.isNotEmpty) 'bp_level': bpLevel,
      if (pulse != null) 'pulse': pulse,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    };

    final files = <http.MultipartFile>[];
    for (final path in photoPaths) {
      files.add(await http.MultipartFile.fromPath('photos', path));
    }

    final record = await pb.collection(PBCollections.sessions).update(
      sessionId,
      body: body,
      files: files,
    );
    return SessionModel.fromRecord(record);
  }

  /// Mark session as missed.
  Future<void> markSessionMissed(String sessionId) async {
    await pb.collection(PBCollections.sessions).update(
      sessionId,
      body: {'status': 'missed'},
    );
  }

  /// Cancel a session and its synced appointment.
  Future<void> cancelSession(String sessionId) async {
    final session = await pb.collection(PBCollections.sessions).getOne(sessionId);
    await pb.collection(PBCollections.sessions).update(sessionId, body: {'status': 'cancelled'});

    final dateStr = session.getStringValue('scheduled_date');
    final timeStr = session.getStringValue('scheduled_time');
    final doctorId = session.getStringValue('doctor');
    final patientId = session.getStringValue('patient');
    try {
      final appts = await pb.collection(PBCollections.appointments).getList(
        filter:
            'patient = "$patientId" && doctor = "$doctorId" && date = "$dateStr" && time = "$timeStr" && type = "session"',
      );
      for (final appt in appts.items) {
        await pb.collection(PBCollections.appointments).update(appt.id, body: {'status': 'cancelled'});
      }
    } catch (_) {}
  }

  /// End Treatment: cancels ALL unattended sessions (treatment + maintenance)
  /// across all plans linked to this consultation, marks consultation completed.
  Future<void> endTreatment(String consultationId) async {
    // Step 1: Find all treatment plans linked to this consultation
    final List<String> planIds = [];
    try {
      final plansRes = await pb.collection(PBCollections.treatmentPlans).getList(
        filter: 'consultation = "$consultationId"',
        perPage: 100,
      );
      planIds.addAll(plansRes.items.map((p) => p.id));
    } catch (_) {}

    // Step 2: Gather all upcoming/waiting sessions across those plans
    final List<dynamic> pendingSessions = [];
    for (final planId in planIds) {
      try {
        final sessRes = await pb.collection(PBCollections.sessions).getList(
          filter: 'treatment_plan = "$planId" && (status = "upcoming" || status = "waiting")',
          perPage: 200,
        );
        pendingSessions.addAll(sessRes.items);
      } catch (_) {}
    }

    // Step 3: Cancel each pending session and its synced appointment
    for (final sess in pendingSessions) {
      final dateStr = sess.getStringValue('scheduled_date');
      final timeStr = sess.getStringValue('scheduled_time');
      final doctorId = sess.getStringValue('doctor');
      final patientId = sess.getStringValue('patient');

      try {
        await pb.collection(PBCollections.sessions).update(sess.id, body: {'status': 'cancelled'});
      } catch (_) {}

      try {
        final appts = await pb.collection(PBCollections.appointments).getList(
          filter:
              'patient = "$patientId" && doctor = "$doctorId" && date = "$dateStr" && time = "$timeStr" && type = "session" && status != "cancelled"',
        );
        for (final appt in appts.items) {
          await pb.collection(PBCollections.appointments).update(appt.id, body: {'status': 'cancelled'});
        }
      } catch (_) {}
    }

    // Step 4: Mark the consultation as completed
    await pb.collection(PBCollections.consultations).update(
      consultationId,
      body: {'status': 'completed'},
    );

    // Step 5: Mark all associated treatment plans as completed
    for (final planId in planIds) {
      try {
        await pb.collection(PBCollections.treatmentPlans).update(planId, body: {'status': 'completed'});
      } catch (_) {}
    }
  }

  // Keep old name as alias for backward compatibility
  Future<void> endConsultation(String consultationId) => endTreatment(consultationId);

  /// Reschedule a single session to a new date and/or time.
  Future<void> rescheduleSession({
    required String sessionId,
    required String newDate,
    required String newTime,
  }) async {
    final session = await pb.collection(PBCollections.sessions).getOne(sessionId);
    final oldDate = session.getStringValue('scheduled_date');
    final oldTime = session.getStringValue('scheduled_time');
    final doctorId = session.getStringValue('doctor');
    final patientId = session.getStringValue('patient');

    await pb.collection(PBCollections.sessions).update(sessionId, body: {
      'scheduled_date': newDate,
      'scheduled_time': newTime,
    });

    try {
      final appts = await pb.collection(PBCollections.appointments).getList(
        filter:
            'patient = "$patientId" && doctor = "$doctorId" && date = "$oldDate" && time = "$oldTime" && type = "session" && status != "cancelled"',
      );
      for (final appt in appts.items) {
        await pb.collection(PBCollections.appointments).update(appt.id, body: {
          'date': newDate,
          'time': newTime,
        });
      }
    } catch (_) {}
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
