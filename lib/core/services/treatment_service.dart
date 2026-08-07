import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/utils/time_utils.dart';
import 'package:pms_app/features/consultations/models/consultation_model.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';
import 'package:pms_app/core/services/session_lifecycle_service.dart';
import 'package:pms_app/core/scheduling/slot_finder.dart';
import 'package:pms_app/core/scheduling/treatment_scheduler.dart' show RescheduleMode;
import 'package:pms_app/core/scheduling/appointment_sync.dart';
import 'package:image_picker/image_picker.dart';


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
    List<XFile> photos = const [],
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
    for (final file in photos) {
      try {
        final bytes = await file.readAsBytes();
        files.add(http.MultipartFile.fromBytes('photos', bytes, filename: file.name));
      } catch (_) {}
    }
    final record = await pb.collection(PBCollections.consultations).create(
      body: body,
      files: files,
    );
    return ConsultationModel.fromRecord(record);
  }

  Future<ConsultationModel> updateConsultation({
    required String consultationId,
    String? status,
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
    List<XFile> newPhotos = const [],
  }) async {
    final body = <String, dynamic>{
      if (status != null) 'status': status,
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
    for (final file in newPhotos) {
      if (!file.path.startsWith('http')) {
        try {
          final bytes = await file.readAsBytes();
          files.add(http.MultipartFile.fromBytes('photos', bytes, filename: file.name));
        } catch (_) {}
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
    int expiryDays = 90,
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
      expiryDays: expiryDays,
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
    int expiryDays = 90,
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
      'expiry_days': expiryDays,
    };

    final planRecord = await pb.collection(PBCollections.treatmentPlans).create(body: planBody);
    final plan = TreatmentPlanModel.fromRecord(planRecord);

    // Auto-generate sessions
    final start = DateTime.parse(startDate);
    final timeParts = preferredTime.split(':');
    final pTimeHr = int.parse(timeParts[0]);
    final pTimeMn = int.parse(timeParts[1]);

    // Build a SchedulingContext so SlotFinder can handle all slot logic
    // (per-clinic capacity, break windows, scheduling_exceptions, 90-day search).
    final contextLoader = SchedulingContextLoader(pb);
    final slotFinder = SlotFinder(pb);
    SchedulingContext? schedCtx;
    try {
      schedCtx = await contextLoader.load(plan.id);
    } catch (_) {
      // Context load failed — fall through without SlotFinder
    }

    // Retrieve doctor's working days as a plain list (needed for the
    // firstSessionCompletedToday path which skips SlotFinder).
    List<int> validDays = schedCtx?.workingDays ?? [];
    if (validDays.isEmpty) {
      try {
        final docRec = await pb.collection('doctors').getOne(doctorId);
        final doctor = DoctorModel.fromRecord(docRec);
        validDays = doctor.workingDays;
      } catch (_) {}
    }

    DateTime currentSessionDate = start;

    for (int i = 0; i < totalSessions; i++) {
      if (firstSessionCompletedToday && i == 0 && planType == 'treatment') {
        // First treatment session starts today — no slot finding needed.
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
          'treatment_type': treatmentType,
          'check_in_time': now.toUtc().toIso8601String(),
        };
        await pb.collection(PBCollections.sessions).create(body: sessionBody);

        // Create linked appointment for Session 1 (starting today)
        final session1Rec = await pb.collection(PBCollections.sessions).getList(
          filter: 'treatment_plan = "${plan.id}" && session_number = 1',
          perPage: 1,
        );
        final session1Id = session1Rec.items.isNotEmpty ? session1Rec.items.first.id : '';
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
            if (session1Id.isNotEmpty) 'linked_session_id': session1Id,
          });
        } catch (_) {}

        currentSessionDate = DateTime.now().add(Duration(days: intervalDays));
        continue;
      }

      // Use SlotFinder (v2) when context is available — respects per-clinic
      // capacity, break windows, scheduling_exceptions, and 90-day search.
      String resolvedDateStr;
      String resolvedTimeStr;

      if (schedCtx != null) {
        try {
          final slotResult = await slotFinder.findBestSlot(
            context: schedCtx,
            startDate: currentSessionDate,
            preferredTime: preferredTime,
          );
          resolvedDateStr = _formatDate(slotResult.date);
          resolvedTimeStr = slotResult.time;
          currentSessionDate = slotResult.date;
        } on NoSlotFoundException {
          // No slot found within 90 days — fall back to force-placing on
          // currentSessionDate so plan creation never hard-fails.
          resolvedDateStr = _formatDate(currentSessionDate);
          resolvedTimeStr = preferredTime;
        }
      } else {
        // Fallback: legacy inline logic when context loader fails.
        resolvedDateStr = _formatDate(currentSessionDate);
        resolvedTimeStr = preferredTime;
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
              resolvedDateStr = tryDateStr;
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
      }

      final sessionDateStr = resolvedDateStr;

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
        'treatment_type': treatmentType,
      };
      // Create the session record first to get its ID
      final sessionRec2 = await pb.collection(PBCollections.sessions).create(body: sessionBody);

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
          'linked_session_id': sessionRec2.id,
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

  /// Add a single session to an existing treatment or maintenance plan.
  /// Creates the session record, a linked appointment, and increments
  /// the plan's `total_sessions` counter.
  Future<SessionModel> addSessionToPlan({
    required String planId,
    required String patientId,
    required String doctorId,
    required String scheduledDate,   // 'YYYY-MM-DD'
    required String scheduledTime,   // 'HH:mm'
    required String sessionType,     // 'treatment' or 'maintenance'
    String? clinicId,
    String? consultationId,
    String? treatmentType,
    bool startImmediately = false,
  }) async {
    // 1. Resolve clinicId from doctor if null or empty
    String? resolvedClinicId = clinicId;
    if (resolvedClinicId == null || resolvedClinicId.isEmpty) {
      try {
        final docRec = await pb.collection('doctors').getOne(doctorId);
        resolvedClinicId = docRec.getStringValue('clinic');
      } catch (_) {}
    }

    // 2. Determine next session number
    final existing = await pb.collection(PBCollections.sessions).getList(
      filter: 'treatment_plan = "$planId"',
      sort: '-session_number',
      perPage: 1,
    );
    final nextNumber = existing.items.isNotEmpty
        ? (existing.items.first.getIntValue('session_number') + 1)
        : 1;

    // 3. Create session record
    final sessionStatus = startImmediately ? 'waiting' : 'upcoming';
    final sessionBody = <String, dynamic>{
      'treatment_plan': planId,
      'patient': patientId,
      'doctor': doctorId,
      if (resolvedClinicId != null && resolvedClinicId.isNotEmpty) 'clinic': resolvedClinicId,
      if (consultationId != null && consultationId.isNotEmpty)
        'consultation': consultationId,
      'session_number': nextNumber,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'status': sessionStatus,
      'session_type': sessionType,
      if (treatmentType != null && treatmentType.isNotEmpty)
        'treatment_type': treatmentType,
      if (startImmediately)
        'check_in_time': DateTime.now().toUtc().toIso8601String(),
    };
    final sessionRec =
        await pb.collection(PBCollections.sessions).create(body: sessionBody);
    final session = SessionModel.fromRecord(sessionRec);

    // 4. Create linked appointment
    try {
      await pb.collection('appointments').create(body: {
        'patient': patientId,
        'doctor': doctorId,
        if (resolvedClinicId != null && resolvedClinicId.isNotEmpty) 'clinic': resolvedClinicId,
        'type': 'session',
        'date': scheduledDate,
        'time': scheduledTime,
        'status': startImmediately ? 'waiting' : 'scheduled',
        'session_type': sessionType,
        'linked_session_id': session.id,
        if (startImmediately)
          'check_in_time': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Appointment creation failure is non-fatal
    }

    // 4. Increment total_sessions on the plan
    try {
      final planRec =
          await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final currentTotal = planRec.getIntValue('total_sessions');
      await pb.collection(PBCollections.treatmentPlans).update(
        planId,
        body: {'total_sessions': currentTotal + 1},
      );
    } catch (_) {
      // Plan update failure is non-fatal
    }

    return session;
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
    List<XFile> photos = const [],
    bool isCompleted = true,
    String? treatmentModality,
    String? doctorId,
    String? reconciliationReason,
  }) async {
    final body = <String, dynamic>{
      if (isCompleted) 'status': 'completed',
      'session_notes_': notes ?? '',
      'vitals_bp': bpLevel ?? '',
      if (pulse != null) 'vitals_pulse': pulse,
      if (remarks != null) 'remarks': remarks,
      if (remarks != null) 'session_remarks': remarks,
      if (remarks != null) 'session_remarks_': remarks,
      if (remarks != null) 'remark': remarks,
      if (treatmentModality != null && treatmentModality.isNotEmpty)
        'treatment_type': treatmentModality,
      if (doctorId != null && doctorId.isNotEmpty)
        'doctor': doctorId,
    };

    if (photos.isNotEmpty) {
      try {
        final existing = await pb.collection(PBCollections.sessions).getOne(sessionId);
        final existingPhotos = existing.getListValue<String>('photos');
        if (existingPhotos.isNotEmpty) {
          body['photos'] = existingPhotos;
        }
      } catch (_) {}
    }

    final files = <http.MultipartFile>[];
    for (final file in photos) {
      try {
        final bytes = await file.readAsBytes();
        files.add(http.MultipartFile.fromBytes('photos', bytes, filename: file.name));
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
      // Stamp completed_at timestamp (v2 scheduling field)
      try {
        await pb.collection(PBCollections.sessions).update(sessionId, body: {
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}

      // Also mark the linked appointment as completed
      await AppointmentSync(pb).syncStatus(session, 'completed', reconciliationReason: reconciliationReason);

      // v2: update plan statistics (reset consecutive_misses, increment completed_sessions)
      try {
        final lifecycle = SessionLifecycleService(pb).lifecycle;
        await lifecycle.onSessionCompleted(session.treatmentPlanId);
      } catch (_) {
        // Fallback: just reset consecutive_misses (v1 behaviour)
        try {
          await pb.collection(PBCollections.treatmentPlans).update(
            session.treatmentPlanId,
            body: {'consecutive_misses': 0},
          );
        } catch (_) {}
      }
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

  /// Mark session as missed. Increments the plan's consecutive_misses counter
  /// and triggers auto-rescheduling if the count is still below 3.
  Future<void> markSessionMissed(String sessionId, {DateTime? anchorDate}) async {
    final record = await pb.collection(PBCollections.sessions).update(
      sessionId,
      body: {'status': 'missed'},
    );
    final session = SessionModel.fromRecord(record);

    // Sync appointment status (no checkout time)
    await AppointmentSync(pb).syncStatus(session, 'cancelled');

    // Increment the plan's consecutive miss counter + total_misses
    try {
      final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(
        session.treatmentPlanId,
      );
      final plan = TreatmentPlanModel.fromRecord(planRec);

      // Skip if plan is already paused, completed, or closed
      if (plan.isPaused ||
          plan.status == TreatmentPlanStatus.completed ||
          plan.status == TreatmentPlanStatus.closed) return;

      // Stamp missed_at on the session
      try {
        await pb.collection(PBCollections.sessions).update(sessionId, body: {
          'missed_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}

      final lifecycle = SessionLifecycleService(pb);
      final newMissCount = await lifecycle.lifecycle.onSessionMissed(plan.id);

      // If < 3 misses, auto-reschedule from anchorDate (defaults to today)
      if (newMissCount < 3) {
        try {
          await lifecycle.rescheduleFromToday(plan.id, [session], anchorDate: anchorDate);
        } catch (e) {
          debugPrint('[TreatmentService] markSessionMissed reschedule error: $e');
        }
      } else {
        // >= 3 misses: transition to manualReview if not already there
        try {
          await lifecycle.lifecycle.transition(
            plan.id,
            TreatmentPlanStatus.manualReview,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[TreatmentService] markSessionMissed counter error: $e');
    }
  }

  /// Close a treatment plan early.
  ///
  /// Cancels all remaining sessions and appointments, records the closure
  /// reason, and transitions the plan to [closed] status.
  /// Delegates to [TreatmentScheduler.closeTreatment].
  Future<void> closeTreatment(
    String planId, {
    required ClosureReason reason,
    required String performedBy,
  }) async {
    final lifecycle = SessionLifecycleService(pb);
    await lifecycle.scheduler.closeTreatment(
      planId,
      reason: reason,
      performedBy: performedBy,
    );
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
        final remarks = sess.getStringValue('remarks').isNotEmpty ? sess.getStringValue('remarks') : sess.getStringValue('session_remarks');
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

  /// Reschedule a single session to a new date and/or time, automatically
  /// cascading shifts to all subsequent sessions in the treatment plan.
  ///
  /// Delegates to the v2 TreatmentScheduler via the facade.
  /// Sets is_pinned = true on the target session.
  Future<void> rescheduleSession({
    required String sessionId,
    required String newDate,
    required String newTime,
    String performedBy = 'system',
    RescheduleMode mode = RescheduleMode.cascadeAll,
  }) async {
    final lifecycle = SessionLifecycleService(pb);
    await lifecycle.rescheduleSessionAndCascade(
      sessionId: sessionId,
      newDate: newDate,
      newTime: newTime,
      performedBy: performedBy,
      mode: mode,
    );
  }

  // ─── Pause / Resume ─────────────────────────────────────────

  /// Pause a treatment plan: delegates to [TreatmentScheduler.pausePlan].
  ///
  /// Pauses BOTH upcoming AND missed sessions (v2 fix — v1 only paused upcoming).
  /// Cancels all linked appointments.
  Future<void> pauseSessions(String planId, {String performedBy = 'system'}) async {
    final lifecycle = SessionLifecycleService(pb);
    await lifecycle.scheduler.pausePlan(
      planId,
      performedBy: performedBy,
      trigger: performedBy == 'system' ? 'system' : 'doctor_manual',
    );
  }

  /// Resume a treatment plan: delegates to [TreatmentScheduler.resumePlan].
  ///
  /// [startFromFirst] = true  → clears all pins, rebuilds entire schedule
  /// [startFromFirst] = false → preserves pinned sessions, reschedules non-pinned
  Future<void> resumeSessions(String planId, {bool startFromFirst = false, String performedBy = 'system'}) async {
    final lifecycle = SessionLifecycleService(pb);
    await lifecycle.scheduler.resumePlan(
      planId,
      rescheduleAll: startFromFirst,
      performedBy: performedBy,
      trigger: performedBy == 'system' ? 'system' : 'doctor_manual',
    );
  }

  /// Manually update multiple sessions at once (dates, times, types).
  ///
  /// This auto-pins manually moved sessions and ensures linked appointments
  /// are updated in sync via [AppointmentSync].
  Future<void> bulkUpdateSessions(List<SessionModel> updatedSessions) async {
    final appointmentSync = AppointmentSync(pb);
    for (final session in updatedSessions) {
      String newTime = '10:00';
      if (session.scheduledTime != null && session.scheduledTime!.isNotEmpty) {
        newTime = session.scheduledTime!;
      } else {
        try {
          final dt = DateTime.parse(session.scheduledDate).toLocal();
          if (dt.hour != 0 || dt.minute != 0 || dt.second != 0) {
            newTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }
        } catch (_) {}
      }

      // 1. Update session record
      await pb.collection(PBCollections.sessions).update(session.id, body: {
        'scheduled_date': session.scheduledDate,
        'scheduled_time': newTime,
        'session_type': session.sessionType,
        'treatment_modality': session.treatmentModality,
        'is_pinned': true, // Auto-pin manually placed sessions
      });

      // 2. Sync appointment
      await appointmentSync.updateForSession(
        session: session,
        newDate: session.scheduledDate,
        newTime: newTime,
        sessionType: session.sessionType,
        clinicId: null,
      );
    }
  }


  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
