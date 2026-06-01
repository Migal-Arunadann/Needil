import 'dart:io';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../constants/pb_collections.dart';
import '../utils/time_utils.dart';
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
    String? medicalHistory, // legacy
    String? previousTreatments,
    String? painAreas,
    String? pastIllnesses,
    String? pastSurgeries,
    String? currentMedications,
    String? allergies,
    String? chronicDiseases,
    String? dietPattern,
    String? sleepQuality,
    String? exerciseLevel,
    String? addictions,
    String? pregnancyStatus,
    bool consentGiven = true,
    String? bpLevel,
    int? pulse,
    String? sugarLevel,
    String? vitD3,
    String? vitB12,
    String? thyroidLevel,
    String? cholesterolLevel,
    bool charged = false,
    int? chargeAmount,
    String? acupunctureDiagnosis,
    String? eyeDiagnosis,
    String? pulseDiagnosis,
    bool coronaVaccinated = false,
    List<String> photoPaths = const [],
  }) async {
    final body = <String, dynamic>{
      'patient': patientId,
      'doctor': doctorId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (chiefComplaint != null && chiefComplaint.isNotEmpty) 'chief_complaint': chiefComplaint,
      if (medicalHistory != null && medicalHistory.isNotEmpty) 'medical_history': medicalHistory,
      if (previousTreatments != null && previousTreatments.isNotEmpty) 'previous_treatments': previousTreatments,
      if (painAreas != null && painAreas.isNotEmpty) 'pain_areas': painAreas,
      if (pastIllnesses != null && pastIllnesses.isNotEmpty) 'past_illnesses': pastIllnesses,
      if (pastSurgeries != null && pastSurgeries.isNotEmpty) 'past_surgeries': pastSurgeries,
      if (currentMedications != null && currentMedications.isNotEmpty) 'current_medications': currentMedications,
      if (allergies != null && allergies.isNotEmpty) 'allergies': allergies,
      if (chronicDiseases != null && chronicDiseases.isNotEmpty) 'chronic_diseases': chronicDiseases,
      if (dietPattern != null && dietPattern.isNotEmpty) 'diet_pattern': dietPattern,
      if (sleepQuality != null && sleepQuality.isNotEmpty) 'sleep_quality': sleepQuality,
      if (exerciseLevel != null && exerciseLevel.isNotEmpty) 'exercise_level': exerciseLevel,
      if (addictions != null && addictions.isNotEmpty) 'addictions': addictions,
      if (pregnancyStatus != null && pregnancyStatus.isNotEmpty) 'pregnancy_status': pregnancyStatus,
      'consent_given': consentGiven,
      if (bpLevel != null && bpLevel.isNotEmpty) 'bp_level': bpLevel,
      if (pulse != null) 'pulse': pulse,
      if (sugarLevel != null && sugarLevel.isNotEmpty) 'sugar_level': sugarLevel,
      if (vitD3 != null && vitD3.isNotEmpty) 'vit_d3': vitD3,
      if (vitB12 != null && vitB12.isNotEmpty) 'vit_b12': vitB12,
      if (thyroidLevel != null && thyroidLevel.isNotEmpty) 'thyroid_level': thyroidLevel,
      if (cholesterolLevel != null && cholesterolLevel.isNotEmpty) 'cholesterol_level': cholesterolLevel,
      'charged': charged,
      if (chargeAmount != null) 'charge_amount': chargeAmount,
      if (acupunctureDiagnosis != null && acupunctureDiagnosis.isNotEmpty) 'acupuncture_diagnosis': acupunctureDiagnosis,
      if (eyeDiagnosis != null && eyeDiagnosis.isNotEmpty) 'eye_diagnosis': eyeDiagnosis,
      if (pulseDiagnosis != null && pulseDiagnosis.isNotEmpty) 'pulse_diagnosis': pulseDiagnosis,
      'corona_vaccinated': coronaVaccinated,
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
    String? medicalHistory, // legacy
    String? previousTreatments,
    String? painAreas,
    String? pastIllnesses,
    String? pastSurgeries,
    String? currentMedications,
    String? allergies,
    String? chronicDiseases,
    String? dietPattern,
    String? sleepQuality,
    String? exerciseLevel,
    String? addictions,
    String? pregnancyStatus,
    bool? consentGiven,
    String? bpLevel,
    int? pulse,
    String? sugarLevel,
    String? vitD3,
    String? vitB12,
    String? thyroidLevel,
    String? cholesterolLevel,
    bool? charged,
    int? chargeAmount,
    String? acupunctureDiagnosis,
    String? eyeDiagnosis,
    String? pulseDiagnosis,
    bool? coronaVaccinated,
    List<String> newPhotoPaths = const [],
  }) async {
    // NOTE: Status is intentionally NOT changed here.
    // The consultation stays 'ongoing' until the doctor explicitly ends the treatment.
    final body = <String, dynamic>{
      if (notes != null) 'notes': notes,
      if (chiefComplaint != null) 'chief_complaint': chiefComplaint,
      if (medicalHistory != null) 'medical_history': medicalHistory,
      if (previousTreatments != null) 'previous_treatments': previousTreatments,
      if (painAreas != null) 'pain_areas': painAreas,
      if (pastIllnesses != null) 'past_illnesses': pastIllnesses,
      if (pastSurgeries != null) 'past_surgeries': pastSurgeries,
      if (currentMedications != null) 'current_medications': currentMedications,
      if (allergies != null) 'allergies': allergies,
      if (chronicDiseases != null) 'chronic_diseases': chronicDiseases,
      if (dietPattern != null) 'diet_pattern': dietPattern,
      if (sleepQuality != null) 'sleep_quality': sleepQuality,
      if (exerciseLevel != null) 'exercise_level': exerciseLevel,
      if (addictions != null) 'addictions': addictions,
      if (pregnancyStatus != null) 'pregnancy_status': pregnancyStatus,
      if (consentGiven != null) 'consent_given': consentGiven,
      if (bpLevel != null) 'bp_level': bpLevel,
      if (pulse != null) 'pulse': pulse,
      if (sugarLevel != null) 'sugar_level': sugarLevel,
      if (vitD3 != null) 'vit_d3': vitD3,
      if (vitB12 != null) 'vit_b12': vitB12,
      if (thyroidLevel != null) 'thyroid_level': thyroidLevel,
      if (cholesterolLevel != null) 'cholesterol_level': cholesterolLevel,
      if (charged != null) 'charged': charged,
      if (chargeAmount != null) 'charge_amount': chargeAmount,
      if (acupunctureDiagnosis != null) 'acupuncture_diagnosis': acupunctureDiagnosis,
      if (eyeDiagnosis != null) 'eye_diagnosis': eyeDiagnosis,
      if (pulseDiagnosis != null) 'pulse_diagnosis': pulseDiagnosis,
      if (coronaVaccinated != null) 'corona_vaccinated': coronaVaccinated,
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

        currentSessionDate = DateTime.now().add(Duration(days: intervalDays));
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
      filter: 'doctor = "$doctorId" && scheduled_date >= "$today 00:00:00.000Z" && scheduled_date <= "$today 23:59:59.999Z"',
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
    bool isCompleted = true,
  }) async {
    final body = <String, dynamic>{
      if (isCompleted) 'status': 'completed',
      'session_notes_': notes ?? '',
      'vitals_bp': bpLevel ?? '',
      if (pulse != null) 'vitals_pulse': pulse,
      if (remarks != null) 'session_remarks': remarks,
    };

    final files = <http.MultipartFile>[];
    for (final path in photoPaths) {
      // Guard: skip files that no longer exist on disk (e.g., already uploaded)
      if (!await File(path).exists()) continue;
      try {
        files.add(await http.MultipartFile.fromPath('photos', path));
      } catch (_) {
        // Skip unreadable files rather than crashing the save
      }
    }

    final record = await pb.collection(PBCollections.sessions).update(
      sessionId,
      body: body,
      files: files,
    );
    final session = SessionModel.fromRecord(record);

    if (isCompleted) {
      // Also mark the linked appointment as completed
      await _syncAppointmentStatus(session, 'completed');
    }

    return session;
  }

  /// Mark a session as in-progress (started by doctor).
  Future<void> startSessionRecord(String sessionId) async {
    await pb.collection(PBCollections.sessions).update(
      sessionId,
      body: {'status': 'in_progress'},
    );
  }

  /// Find the session record linked to an appointment by patient + date + time.
  Future<SessionModel?> findSessionForAppointment({
    required String patientId,
    required String date,
    required String time,
    required String doctorId,
  }) async {
    final timeCandidates = TimeUtils.generateTimeCandidates(time);
    final timeFilter = timeCandidates.isNotEmpty
        ? timeCandidates.map((t) => 'scheduled_time = "$t"').join(' || ')
        : 'scheduled_time = "$time"';

    // Priority 1: Exact match (date + time candidates) with active status (upcoming, waiting, in_progress)
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& scheduled_date >= "$date 00:00:00.000Z" && scheduled_date <= "$date 23:59:59.999Z" '
            '&& ($timeFilter) && (status = "upcoming" || status = "waiting" || status = "in_progress")',
        perPage: 1,
        sort: 'session_number',
      );
      if (res.items.isNotEmpty) return SessionModel.fromRecord(res.items.first);
    } catch (_) {}

    // Priority 2: Exact match (date + time candidates) with any status
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& scheduled_date >= "$date 00:00:00.000Z" && scheduled_date <= "$date 23:59:59.999Z" '
            '&& ($timeFilter)',
        perPage: 1,
        sort: 'session_number',
      );
      if (res.items.isNotEmpty) return SessionModel.fromRecord(res.items.first);
    } catch (_) {}

    // Priority 3: Date-only match with active status (upcoming, waiting, in_progress)
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& scheduled_date >= "$date 00:00:00.000Z" && scheduled_date <= "$date 23:59:59.999Z" '
            '&& (status = "upcoming" || status = "waiting" || status = "in_progress")',
        perPage: 1,
        sort: 'session_number',
      );
      if (res.items.isNotEmpty) return SessionModel.fromRecord(res.items.first);
    } catch (_) {}

    // Priority 4: Date-only match with any status
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& scheduled_date >= "$date 00:00:00.000Z" && scheduled_date <= "$date 23:59:59.999Z"',
        perPage: 1,
        sort: 'session_number',
      );
      if (res.items.isNotEmpty) return SessionModel.fromRecord(res.items.first);
    } catch (_) {}

    // Priority 5: Patient-doctor match with active status (upcoming, waiting, in_progress), sorted by date, session number
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& (status = "upcoming" || status = "waiting" || status = "in_progress")',
        perPage: 1,
        sort: 'scheduled_date,session_number',
      );
      if (res.items.isNotEmpty) return SessionModel.fromRecord(res.items.first);
    } catch (_) {}

    // Priority 6: Patient-doctor match with any status, sorted by date, session number
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId"',
        perPage: 1,
        sort: 'scheduled_date,session_number',
      );
      if (res.items.isNotEmpty) return SessionModel.fromRecord(res.items.first);
    } catch (_) {}

    return null;
  }

  /// Mark session as missed.
  Future<void> markSessionMissed(String sessionId) async {
    final record = await pb.collection(PBCollections.sessions).update(
      sessionId,
      body: {'status': 'missed'},
    );
    final session = SessionModel.fromRecord(record);

    // Also mark the linked appointment as cancelled
    await _syncAppointmentStatus(session, 'cancelled');
  }

  /// Cancel a session and its synced appointment.
  Future<void> cancelSession(String sessionId) async {
    final session = await pb.collection(PBCollections.sessions).getOne(sessionId);
    await pb.collection(PBCollections.sessions).update(sessionId, body: {'status': 'cancelled'});

    final rawDate = session.getStringValue('scheduled_date');
    String datePart = rawDate;
    try {
      final dt = DateTime.parse(rawDate);
      datePart = _formatDate(dt);
    } catch (_) {}
    final timeStr = session.getStringValue('scheduled_time');
    final doctorId = session.getStringValue('doctor');
    final patientId = session.getStringValue('patient');
    try {
      final appts = await pb.collection(PBCollections.appointments).getList(
        filter:
            'patient = "$patientId" && doctor = "$doctorId" '
            '&& date >= "$datePart 00:00:00.000Z" && date <= "$datePart 23:59:59.999Z" '
            '&& time = "$timeStr" && type = "session"',
      );
      for (final appt in appts.items) {
        await pb.collection(PBCollections.appointments).update(appt.id, body: {'status': 'cancelled'});
      }
    } catch (_) {}
  }

  /// Cancel all remaining sessions in a plan after [afterSessionNumber].
  /// Returns the count of sessions cancelled.
  Future<int> cancelFutureSessionsForPlan(String planId, int afterSessionNumber) async {
    int cancelled = 0;
    try {
      final sessRes = await pb.collection(PBCollections.sessions).getList(
        filter:
            'treatment_plan = "$planId" && session_number > $afterSessionNumber '
            '&& (status = "upcoming" || status = "waiting")',
        perPage: 200,
      );
      for (final sess in sessRes.items) {
        final notes = sess.getStringValue('session_notes_');
        final bp = sess.getStringValue('vitals_bp');
        final pulse = sess.getIntValue('vitals_pulse');
        final remarks = sess.getStringValue('session_remarks');
        final photos = sess.getListValue<String>('photos');

        final hasClinicalData = notes.trim().isNotEmpty ||
            bp.trim().isNotEmpty ||
            (pulse != null && pulse > 0) ||
            remarks.trim().isNotEmpty ||
            photos.isNotEmpty;

        if (hasClinicalData) continue;

        try {
          await pb.collection(PBCollections.sessions).update(sess.id, body: {'status': 'cancelled'});
          cancelled++;
        } catch (_) {}

        // Cancel the linked appointment
        final rawDate = sess.getStringValue('scheduled_date');
        String datePart = rawDate;
        try {
          final dt = DateTime.parse(rawDate);
          datePart = _formatDate(dt);
        } catch (_) {}
        final timeStr = sess.getStringValue('scheduled_time');
        final doctorId = sess.getStringValue('doctor');
        final patientId = sess.getStringValue('patient');
        try {
          final appts = await pb.collection(PBCollections.appointments).getList(
            filter:
                'patient = "$patientId" && doctor = "$doctorId" '
                '&& date >= "$datePart 00:00:00.000Z" && date <= "$datePart 23:59:59.999Z" '
                '&& time = "$timeStr" && type = "session" && status != "cancelled"',
          );
          for (final appt in appts.items) {
            await pb.collection(PBCollections.appointments).update(appt.id, body: {'status': 'cancelled'});
          }
        } catch (_) {}
      }
    } catch (_) {}
    return cancelled;
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

    // Step 2: Gather all upcoming/waiting/in_progress sessions across those plans
    final List<dynamic> pendingSessions = [];
    for (final planId in planIds) {
      try {
        final sessRes = await pb.collection(PBCollections.sessions).getList(
          filter: 'treatment_plan = "$planId" && (status = "upcoming" || status = "waiting" || status = "in_progress")',
          perPage: 200,
        );
        pendingSessions.addAll(sessRes.items);
      } catch (_) {}
    }

    // Step 3: Cancel each pending session and its synced appointment
    for (final sess in pendingSessions) {
      final notes = sess.getStringValue('session_notes_');
      final bp = sess.getStringValue('vitals_bp');
      final pulse = sess.getIntValue('vitals_pulse');
      final remarks = sess.getStringValue('session_remarks');
      final photos = sess.getListValue<String>('photos');

      final hasClinicalData = notes.trim().isNotEmpty ||
          bp.trim().isNotEmpty ||
          (pulse != null && pulse > 0) ||
          remarks.trim().isNotEmpty ||
          photos.isNotEmpty;

      if (hasClinicalData) continue;

      final rawDate = sess.getStringValue('scheduled_date');
      String datePart = rawDate;
      try {
        final dt = DateTime.parse(rawDate);
        datePart = _formatDate(dt);
      } catch (_) {}
      final timeStr = sess.getStringValue('scheduled_time');
      final doctorId = sess.getStringValue('doctor');
      final patientId = sess.getStringValue('patient');

      try {
        await pb.collection(PBCollections.sessions).update(sess.id, body: {'status': 'cancelled'});
      } catch (_) {}

      try {
        final appts = await pb.collection(PBCollections.appointments).getList(
          filter:
              'patient = "$patientId" && doctor = "$doctorId" '
              '&& date >= "$datePart 00:00:00.000Z" && date <= "$datePart 23:59:59.999Z" '
              '&& time = "$timeStr" && type = "session" && status != "cancelled"',
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

  // ─── Pause / Resume ─────────────────────────────────────────

  /// Pause a treatment plan: change all upcoming sessions → paused,
  /// cancel their linked appointments, and set plan's is_paused flag.
  Future<void> pauseSessions(String planId) async {
    // 1) Set plan as paused
    await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
      'is_paused': true,
      'paused_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'paused',
    });

    // 2) Find all upcoming sessions for this plan
    final sessRes = await pb.collection(PBCollections.sessions).getList(
      filter: 'treatment_plan = "$planId" && status = "upcoming"',
      sort: 'session_number',
      perPage: 200,
    );

    // 3) Mark each as paused and cancel linked appointments
    for (final sess in sessRes.items) {
      await pb.collection(PBCollections.sessions).update(sess.id, body: {
        'status': 'paused',
      });

      // Cancel linked appointment
      final rawDate = sess.getStringValue('scheduled_date');
      String datePart = rawDate;
      try {
        final dt = DateTime.parse(rawDate);
        datePart = _formatDate(dt);
      } catch (_) {}
      final timeStr = sess.getStringValue('scheduled_time');
      final doctorId = sess.getStringValue('doctor');
      final patientId = sess.getStringValue('patient');
      try {
        final appts = await pb.collection(PBCollections.appointments).getList(
          filter:
              'patient = "$patientId" && doctor = "$doctorId" '
              '&& date >= "$datePart 00:00:00.000Z" && date <= "$datePart 23:59:59.999Z" '
              '&& time = "$timeStr" && type = "session" && status != "cancelled"',
        );
        for (final appt in appts.items) {
          await pb.collection(PBCollections.appointments).update(appt.id, body: {'status': 'cancelled'});
        }
      } catch (_) {}
    }
  }

  /// Resume a treatment plan: reschedule all paused sessions from today
  /// using the smart scheduling engine. If [startFromFirst] is true,
  /// all paused sessions are rescheduled starting from the lowest session
  /// number. Otherwise, they continue from where they left off (same order).
  ///
  /// Both modes reschedule from today forward — the difference is only
  /// semantic (both reschedule the same paused sessions in order).
  Future<void> resumeSessions(String planId, {bool startFromFirst = false}) async {
    // 1) Load plan
    final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
    final plan = TreatmentPlanModel.fromRecord(planRec);

    // 2) Load doctor info for working days
    List<int> validDays = [];
    int maxBeds = 3;
    String? validClinicId;
    try {
      final docRec = await pb.collection('doctors').getOne(plan.doctorId);
      final doctor = DoctorModel.fromRecord(docRec);
      validDays = doctor.workingDays;
      validClinicId = doctor.clinicId;
      if (validClinicId != null && validClinicId.isNotEmpty) {
        try {
          final clinicRec = await pb.collection('clinics').getOne(validClinicId);
          maxBeds = clinicRec.getIntValue('bed_count');
          if (maxBeds <= 0) maxBeds = 3;
        } catch (_) {}
      }
    } catch (_) {}

    // 3) Get all paused sessions sorted by session_number
    final sessRes = await pb.collection(PBCollections.sessions).getList(
      filter: 'treatment_plan = "$planId" && status = "paused"',
      sort: 'session_number',
      perPage: 200,
    );

    if (sessRes.items.isEmpty) return;

    // 4) Determine preferred time from the plan's first session
    String preferredTime = '10:00';
    try {
      final allSessions = await pb.collection(PBCollections.sessions).getList(
        filter: 'treatment_plan = "$planId"',
        sort: 'session_number',
        perPage: 1,
      );
      if (allSessions.items.isNotEmpty) {
        final t = allSessions.items.first.getStringValue('scheduled_time');
        if (t.isNotEmpty) preferredTime = t;
      }
    } catch (_) {}

    final timeParts = preferredTime.split(':');
    final pTimeHr = int.parse(timeParts[0]);
    final pTimeMn = int.parse(timeParts[1]);

    // 5) Schedule from today forward
    DateTime cursor = DateTime.now();
    final pausedSessions = sessRes.items.toList();

    for (int i = 0; i < pausedSessions.length; i++) {
      final sess = pausedSessions[i];

      if (i > 0) {
        cursor = cursor.add(Duration(days: plan.intervalDays));
      }

      // Skip to next working day
      if (validDays.isNotEmpty) {
        while (!validDays.contains(cursor.weekday)) {
          cursor = cursor.add(const Duration(days: 1));
        }
      }

      // Find available slot
      String resolvedTime = preferredTime;
      bool foundSlot = false;
      DateTime tryDate = cursor;
      int dayAttempts = 0;

      while (!foundSlot && dayAttempts < 30) {
        if (validDays.isNotEmpty) {
          while (!validDays.contains(tryDate.weekday)) {
            tryDate = tryDate.add(const Duration(days: 1));
          }
        }

        final tryDateStr = _formatDate(tryDate);
        DateTime slotAttempt = DateTime(tryDate.year, tryDate.month, tryDate.day, pTimeHr, pTimeMn);

        for (int attempt = 0; attempt < 16; attempt++) {
          if (slotAttempt.hour >= 20) break;
          final checkTimeStr =
              '${slotAttempt.hour.toString().padLeft(2, "0")}:${slotAttempt.minute.toString().padLeft(2, "0")}';

          final existing = await pb.collection(PBCollections.appointments).getList(
            filter: 'doctor = "${plan.doctorId}" && date = "$tryDateStr" && time = "$checkTimeStr" && status != "cancelled"',
          );
          if (existing.totalItems < maxBeds) {
            resolvedTime = checkTimeStr;
            cursor = tryDate;
            foundSlot = true;
            break;
          }
          slotAttempt = slotAttempt.add(const Duration(minutes: 30));
        }

        if (!foundSlot) {
          tryDate = tryDate.add(const Duration(days: 1));
          dayAttempts++;
        }
      }

      final newDate = _formatDate(cursor);

      // Update session
      await pb.collection(PBCollections.sessions).update(sess.id, body: {
        'scheduled_date': newDate,
        'scheduled_time': resolvedTime,
        'status': 'upcoming',
        'is_rescheduled': true,
      });

      // Recreate linked appointment
      try {
        await pb.collection('appointments').create(body: {
          'patient': sess.getStringValue('patient'),
          'doctor': sess.getStringValue('doctor'),
          if (validClinicId != null && validClinicId.isNotEmpty) 'clinic': validClinicId,
          'type': 'session',
          'date': newDate,
          'time': resolvedTime,
          'status': 'scheduled',
        });
      } catch (_) {}
    }

    // 6) Un-pause the plan
    await pb.collection(PBCollections.treatmentPlans).update(planId, body: {
      'is_paused': false,
      'paused_at': '',
      'status': 'active',
      'consecutive_misses': 0,
    });
  }

  /// Sync a session's status change to its linked appointment record.
  Future<void> _syncAppointmentStatus(SessionModel session, String newStatus) async {
    try {
      String datePart = session.scheduledDate;
      try {
        final dt = DateTime.parse(session.scheduledDate);
        datePart = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {}

      final appts = await pb.collection(PBCollections.appointments).getList(
        filter:
            'patient = "${session.patientId}" && doctor = "${session.doctorId}" '
            '&& date >= "$datePart 00:00:00.000Z" && date <= "$datePart 23:59:59.999Z" && time = "${session.scheduledTime}" '
            '&& type = "session" && status != "cancelled"',
      );
      final now = DateTime.now().toUtc().toIso8601String();
      for (final appt in appts.items) {
        final body = <String, dynamic>{'status': newStatus};
        if (newStatus == 'completed') {
          // Record session-ended + patient-left timestamps for history
          body['check_out_time'] = now;
          body['patient_left_at'] = now;
        }
        await pb.collection(PBCollections.appointments).update(appt.id, body: body);
      }
    } catch (_) {}
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
