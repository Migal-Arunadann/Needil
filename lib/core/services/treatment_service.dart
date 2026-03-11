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

  /// Create a consultation for a patient.
  Future<ConsultationModel> createConsultation({
    required String patientId,
    required String doctorId,
    String? notes,
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
      if (bpLevel != null && bpLevel.isNotEmpty) 'bp_level': bpLevel,
      if (pulse != null) 'pulse': pulse,
      'charged': charged,
      if (chargeAmount != null) 'charge_amount': chargeAmount,
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

  /// Create a treatment plan and auto-generate session records.
  Future<TreatmentPlanModel> createTreatmentPlan({
    required String patientId,
    required String doctorId,
    String? consultationId,
    required String treatmentType,
    required String startDate,
    required int totalSessions,
    required int intervalDays,
    required double sessionFee,
  }) async {
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

    final planRecord = await pb
        .collection(PBCollections.treatmentPlans)
        .create(body: planBody);
    final plan = TreatmentPlanModel.fromRecord(planRecord);

    // Auto-generate sessions
    final start = DateTime.parse(startDate);
    for (int i = 0; i < totalSessions; i++) {
      final sessionDate = start.add(Duration(days: i * intervalDays));
      final sessionBody = {
        'treatment_plan': plan.id,
        'patient': patientId,
        'doctor': doctorId,
        'session_number': i + 1,
        'scheduled_date': _formatDate(sessionDate),
        'status': 'upcoming',
      };
      await pb.collection(PBCollections.sessions).create(body: sessionBody);
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
