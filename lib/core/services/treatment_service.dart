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
    // Conversational / Medical
    String? chiefComplaint,
    String? medicalHistory,
    String? pastIllnesses,
    String? currentMedications,
    String? allergies,
    String? chronicDiseases,
    // Lifestyle
    String? dietPattern,
    String? sleepQuality,
    String? exerciseLevel,
    String? addictions,
    String? stressLevel,
    // Consent
    String? pregnancyStatus,
    bool consentGiven = true,
    // Vitals & Charge
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
    // Conversational / Medical
    String? chiefComplaint,
    String? medicalHistory,
    String? pastIllnesses,
    String? currentMedications,
    String? allergies,
    String? chronicDiseases,
    // Lifestyle
    String? dietPattern,
    String? sleepQuality,
    String? exerciseLevel,
    String? addictions,
    String? stressLevel,
    // Consent
    String? pregnancyStatus,
    bool? consentGiven,
    // Vitals & Charge
    String? bpLevel,
    int? pulse,
    bool? charged,
    double? chargeAmount,
    List<String> newPhotoPaths = const [],
  }) async {
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
  Future<List<ConsultationModel>> getPatientConsultations(
      String patientId) async {
    final result = await pb.collection(PBCollections.consultations).getList(
      filter: 'patient = "$patientId"',
      sort: '-created',
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
    // Attempt to fetch clinic bed count (fallback to default 3)
    int maxBeds = 3;
    String? validClinicId;
    try {
      final docId = doctorId;
      final docRec = await pb.collection('doctors').getOne(docId);
      validClinicId = docRec.getStringValue('clinic');
      if (validClinicId.isNotEmpty) {
        final clinicRec = await pb.collection('clinics').getOne(validClinicId);
        maxBeds = clinicRec.getIntValue('bed_count');
        if (maxBeds <= 0) maxBeds = 3;
      }
    } catch (_) {}

    // Create the plan
    final planBody = {
      'patient': patientId,
      'doctor': doctorId,
      if (consultationId != null && consultationId.isNotEmpty)
        'consultation': consultationId,
      'treatment_type': treatmentType,
      'start_date': startDate,
      'total_sessions': totalSessions,
      'interval_days': intervalDays,
      'session_fee': sessionFee,
      'status': 'active',
    };

    final planRecord = await pb.collection(PBCollections.treatmentPlans).create(body: planBody);
    final plan = TreatmentPlanModel.fromRecord(planRecord);

    // Auto-generate sessions
    final start = DateTime.parse(startDate);
    
    // Parse preferred time, e.g. "10:30"
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
      if (firstSessionCompletedToday && i == 0) {
        // First session was completed today in the consultation
        final now = DateTime.now();
        final nowStr = _formatDate(now);
        final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
        
        final sessionBody = {
          'treatment_plan': plan.id,
          'patient': patientId,
          'doctor': doctorId,
          if (validClinicId != null && validClinicId.isNotEmpty)
            'clinic': validClinicId,
          if (consultationId != null && consultationId.isNotEmpty)
            'consultation': consultationId,
          'session_number': 1,
          'scheduled_date': nowStr,
          'scheduled_time': timeStr,
          'status': 'completed',
        };
        await pb.collection(PBCollections.sessions).create(body: sessionBody);

        // Sync a completed appointment so this session appears in today's schedule
        try {
          await pb.collection('appointments').create(body: {
            'patient': patientId,
            'doctor': doctorId,
            if (validClinicId != null && validClinicId.isNotEmpty)
              'clinic': validClinicId,
            'type': 'session',
            'date': nowStr,
            'time': timeStr,
            'status': 'completed',
            'check_in_time': DateTime.now().toUtc().toIso8601String(),
            'check_out_time': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {}
        
        // Setup next date according to the original preferred start date
        currentSessionDate = currentSessionDate.add(Duration(days: intervalDays));
        continue;
      }

      // 2) Find a valid time slot that doesn't overlap with appointments or existing sessions
      String resolvedTimeStr = preferredTime;
      bool foundSlot = false;
      
      // Keep trying days until we find a slot (prevents same-time double-booking)
      int dayAttempts = 0;
      while (!foundSlot && dayAttempts < 30) {
        // Skip non-working days
        if (validDays.isNotEmpty) {
          while (!validDays.contains(currentSessionDate.weekday)) {
            currentSessionDate = currentSessionDate.add(const Duration(days: 1));
          }
        }
        
        final tryDateStr = _formatDate(currentSessionDate);
        
        // Try up to 16 offset slots (e.g. 10:00 -> 10:30 -> ... up to 18:00)
        DateTime slotAttempt = DateTime(currentSessionDate.year, currentSessionDate.month, currentSessionDate.day, pTimeHr, pTimeMn);

        for (int attempt = 0; attempt < 16; attempt++) {
          // Don't schedule past 20:00
          if (slotAttempt.hour >= 20) break;
          
          final checkTimeHrStr = slotAttempt.hour.toString().padLeft(2, "0");
          final checkTimeMnStr = slotAttempt.minute.toString().padLeft(2, "0");
          final checkTimeStr = '$checkTimeHrStr:$checkTimeMnStr';

          // Check appointments table — the sole source of truth for slot availability.
          // Every session syncs a matching appointment when scheduled, so checking
          // appointments alone is correct. The sessions collection does not have a
          // 'doctor' field, so filtering sessions by doctor would return a 400 error.
          final existingAppts = await pb.collection(PBCollections.appointments).getList(
            filter: 'doctor = "$doctorId" && date = "$tryDateStr" && time = "$checkTimeStr" && status != "cancelled"',
          );

          final totalOccupied = existingAppts.totalItems;
          
          if (totalOccupied < maxBeds) {
            resolvedTimeStr = checkTimeStr;
            foundSlot = true;
            break;
          }
          
          // Bump by 30 mins
          slotAttempt = slotAttempt.add(const Duration(minutes: 30));
        }
        
        if (!foundSlot) {
          // All slots on this day are full — advance to next working day
          currentSessionDate = currentSessionDate.add(const Duration(days: 1));
          dayAttempts++;
        }
      }
      
      // Re-compute the date string after potential day advance
      final sessionDateStr = _formatDate(currentSessionDate);

      final sessionBody = {
        'treatment_plan': plan.id,
        'patient': patientId,
        'doctor': doctorId,
        if (validClinicId != null && validClinicId.isNotEmpty)
          'clinic': validClinicId,
        if (consultationId != null && consultationId.isNotEmpty)
          'consultation': consultationId,
        'session_number': i + 1,
        'scheduled_date': sessionDateStr,
        'scheduled_time': resolvedTimeStr,
        'status': 'upcoming',
      };
      await pb.collection(PBCollections.sessions).create(body: sessionBody);

      // Create a synced appointment to block the doctor's calendar
      final apptBody = {
        'patient': patientId,
        'doctor': doctorId,
        if (validClinicId != null && validClinicId.isNotEmpty)
          'clinic': validClinicId,
        'type': 'session',
        'date': sessionDateStr,
        'time': resolvedTimeStr,
        'status': 'scheduled',
      };
      // Ignore errors if appointment creation fails so we don't break the session loop
      try {
        await pb.collection('appointments').create(body: apptBody);
      } catch (e) {
        throw Exception('Failed to sync appointment to calendar. Ensure "session" type is added to PocketBase! Error details: $e');
      }

      // Increment date for the next session
      currentSessionDate = currentSessionDate.add(Duration(days: intervalDays));
    }

    return plan;
  }

  /// Get treatment plans for a patient.
  Future<List<TreatmentPlanModel>> getPatientPlans(String patientId) async {
    final result = await pb.collection(PBCollections.treatmentPlans).getList(
      filter: 'patient = "$patientId"',
      sort: '-created',
      expand: 'patient',
    );
    return result.items.map((r) => TreatmentPlanModel.fromRecord(r)).toList();
  }

  /// Get treatment plans for a doctor.
  Future<List<TreatmentPlanModel>> getDoctorPlans(String doctorId) async {
    final result = await pb.collection(PBCollections.treatmentPlans).getList(
      filter: 'doctor = "$doctorId"',
      sort: '-created',
      expand: 'patient',
    );
    return result.items.map((r) => TreatmentPlanModel.fromRecord(r)).toList();
  }

  /// Update treatment plan status.
  Future<void> updatePlanStatus(
      String planId, TreatmentPlanStatus status) async {
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
    
    // Also cancel the synced appointment
    final dateStr = session.getStringValue('scheduled_date');
    final timeStr = session.getStringValue('scheduled_time');
    final doctorId = session.getStringValue('doctor');
    final patientId = session.getStringValue('patient');
    try {
      final appts = await pb.collection(PBCollections.appointments).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" && date = "$dateStr" && time = "$timeStr" && type = "session"',
      );
      for (final appt in appts.items) {
        await pb.collection(PBCollections.appointments).update(appt.id, body: {'status': 'cancelled'});
      }
    } catch (_) {}
  }

  /// End a consultation: cancel all upcoming sessions + their appointments, mark consultation completed.
  Future<void> endConsultation(String consultationId) async {
    // Step 1: Find treatment plans linked to this consultation
    // (sessions don't have a direct consultation field — they link via treatment_plan)
    final List<String> planIds = [];
    try {
      final plansRes = await pb.collection(PBCollections.treatmentPlans).getList(
        filter: 'consultation = "$consultationId"',
        perPage: 100,
      );
      planIds.addAll(plansRes.items.map((p) => p.id));
    } catch (_) {}

    // Step 2: Gather all upcoming sessions across those treatment plans
    final List<dynamic> upcomingSessions = [];
    for (final planId in planIds) {
      try {
        final sessRes = await pb.collection(PBCollections.sessions).getList(
          filter: 'treatment_plan = "$planId" && status = "upcoming"',
          perPage: 200,
        );
        upcomingSessions.addAll(sessRes.items);
      } catch (_) {}
    }

    // Step 3: Cancel each upcoming session and its synced appointment
    for (final sess in upcomingSessions) {
      final dateStr = sess.getStringValue('scheduled_date');
      final timeStr = sess.getStringValue('scheduled_time');
      final doctorId = sess.getStringValue('doctor');
      final patientId = sess.getStringValue('patient');

      try {
        await pb.collection(PBCollections.sessions).update(sess.id, body: {'status': 'cancelled'});
      } catch (_) {}

      try {
        final appts = await pb.collection(PBCollections.appointments).getList(
          filter: 'patient = "$patientId" && doctor = "$doctorId" && date = "$dateStr" && time = "$timeStr" && type = "session" && status != "cancelled"',
        );
        for (final appt in appts.items) {
          await pb.collection(PBCollections.appointments).update(appt.id, body: {'status': 'cancelled'});
        }
      } catch (_) {}
    }

    // Step 4: Mark the consultation as completed
    await pb.collection(PBCollections.consultations).update(consultationId, body: {'status': 'completed'});

    // Step 5: Mark associated treatment plans as completed
    for (final planId in planIds) {
      try {
        await pb.collection(PBCollections.treatmentPlans).update(planId, body: {'status': 'completed'});
      } catch (_) {}
    }
  }

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
    
    // Update the session record
    await pb.collection(PBCollections.sessions).update(sessionId, body: {
      'scheduled_date': newDate,
      'scheduled_time': newTime,
    });
    
    // Update the synced appointment
    try {
      final appts = await pb.collection(PBCollections.appointments).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" && date = "$oldDate" && time = "$oldTime" && type = "session" && status != "cancelled"',
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
