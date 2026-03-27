import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import '../constants/pb_collections.dart';
import '../../features/consultations/models/consultation_model.dart';
import '../../features/treatments/models/treatment_plan_model.dart';
import '../../features/treatments/models/session_model.dart';

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
  }) async {
    // Attempt to fetch clinic bed count (fallback to default 3)
    int maxBeds = 3;
    try {
      final docId = doctorId;
      final docRec = await pb.collection('doctors').getOne(docId);
      final clinicRelId = docRec.getStringValue('clinicId');
      if (clinicRelId.isNotEmpty) {
        final clinicRec = await pb.collection('clinics').getOne(clinicRelId);
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

    for (int i = 0; i < totalSessions; i++) {
      final sessionDate = start.add(Duration(days: i * intervalDays));
      final sessionDateStr = _formatDate(sessionDate);
      
      // Smart slot finder finding a valid time
      String resolvedTimeStr = preferredTime;
      bool foundSlot = false;
      
      // We will try up to 8 offset slots (e.g. 10:00 -> 10:30 -> 11:00) before ignoring overlap rules
      DateTime slotAttempt = DateTime(sessionDate.year, sessionDate.month, sessionDate.day, pTimeHr, pTimeMn);

      for (int attempt = 0; attempt < 8; attempt++) {
        final checkTimeHrStr = slotAttempt.hour.toString().padLeft(2, "0");
        final checkTimeMnStr = slotAttempt.minute.toString().padLeft(2, "0");
        final checkTimeStr = '$checkTimeHrStr:$checkTimeMnStr';
        // See how many sessions are exactly at this time
        final existing = await pb.collection(PBCollections.sessions).getList(
          filter: 'scheduled_date = "$sessionDateStr" && scheduled_time = "$checkTimeStr"',
        );
        
        if (existing.totalItems < maxBeds) {
          resolvedTimeStr = checkTimeStr;
          foundSlot = true;
          break;
        }
        
        // Bump by 30 mins
        slotAttempt = slotAttempt.add(const Duration(minutes: 30));
      }
      
      // If we literally couldn't find a slot, fallback to preferredTime anyway (force overlap)
      if (!foundSlot) resolvedTimeStr = preferredTime;

      final sessionBody = {
        'treatment_plan': plan.id,
        'patient': patientId,
        'doctor': doctorId,
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

  /// Cancel a session.
  Future<void> cancelSession(String sessionId) async {
    await pb.collection(PBCollections.sessions).update(
      sessionId,
      body: {'status': 'cancelled'},
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
