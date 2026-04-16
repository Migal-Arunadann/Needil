import 'package:pocketbase/pocketbase.dart';

enum AppointmentType { callBy, walkIn, session }

enum AppointmentStatus { scheduled, waiting, inProgress, completed, cancelled }

class AppointmentModel {
  final String id;
  final String? patientId;
  final String doctorId;
  final String? clinicId;
  final AppointmentType type;
  final String date; // YYYY-MM-DD
  final String time; // HH:mm
  final AppointmentStatus status;
  final String? patientName; // For call-by placeholder
  final String? patientPhone; // For call-by placeholder
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final DateTime? consultationStartTime;
  final DateTime? consultationEndTime;       // Set when consultation form is submitted
  final bool patientDetailsSaved;            // true once PatientInfoScreen form is submitted
  final bool patientDetailsPartial;          // true once PatientInfoScreen form is opened (but not yet submitted)
  final bool treatmentPlanPartial;           // true once treatment plan form opened but not submitted
  final String? linkedTreatmentPlanId;       // ID of created treatment plan (prevents duplicates)
  final DateTime? created;
  final DateTime? updated;

  // Expanded relations (populated when fetched with expand)
  final String? doctorName;
  final String? expandedPatientName;

  AppointmentModel({
    required this.id,
    this.patientId,
    required this.doctorId,
    this.clinicId,
    required this.type,
    required this.date,
    required this.time,
    required this.status,
    this.patientName,
    this.patientPhone,
    this.checkInTime,
    this.checkOutTime,
    this.consultationStartTime,
    this.consultationEndTime,
    this.patientDetailsSaved = false,
    this.patientDetailsPartial = false,
    this.treatmentPlanPartial = false,
    this.linkedTreatmentPlanId,
    this.created,
    this.updated,
    this.doctorName,
    this.expandedPatientName,
  });

  bool get consultationFormSaved => consultationEndTime != null;

  factory AppointmentModel.fromRecord(RecordModel record) {
    // Try to get expanded doctor/patient names
    String? doctorName;
    String? expandedPatientName;

    try {
      final expandData = record.get<Map<String, dynamic>>('expand');
      if (expandData.isNotEmpty) {
        if (expandData.containsKey('doctor')) {
          final doc = expandData['doctor'];
          if (doc is Map) doctorName = doc['name'] as String?;
        }
        if (expandData.containsKey('patient')) {
          final pat = expandData['patient'];
          if (pat is Map) expandedPatientName = pat['full_name'] as String?;
        }
      }
    } catch (_) {
      // expand might not be present or might throw if called on something missing
    }

    return AppointmentModel(
      id: record.id,
      patientId: record.getStringValue('patient'),
      doctorId: record.getStringValue('doctor'),
      clinicId: record.getStringValue('clinic'),
      type: _parseType(record.getStringValue('type')),
      date: record.getStringValue('date'),
      time: record.getStringValue('time'),
      status: _parseStatus(record.getStringValue('status')),
      patientName: record.getStringValue('patient_name'),
      patientPhone: record.getStringValue('patient_phone'),
      checkInTime: _parseDateTimeOrNull(record.getStringValue('check_in_time')),
      checkOutTime: _parseDateTimeOrNull(record.getStringValue('check_out_time')),
      consultationStartTime: _parseDateTimeOrNull(record.getStringValue('consultation_start_time')),
      consultationEndTime: _parseDateTimeOrNull(record.getStringValue('consultation_end_time')),
      patientDetailsSaved: record.getBoolValue('patient_details_saved'),
      patientDetailsPartial: record.getBoolValue('patient_details_partial'),
      treatmentPlanPartial: record.getBoolValue('treatment_plan_partial'),
      linkedTreatmentPlanId: record.getStringValue('linked_treatment_plan_id').isNotEmpty
          ? record.getStringValue('linked_treatment_plan_id')
          : null,
      created: DateTime.tryParse(record.get<String>('created')),
      updated: DateTime.tryParse(record.get<String>('updated')),
      doctorName: doctorName,
      expandedPatientName: expandedPatientName,
    );
  }

  static DateTime? _parseDateTimeOrNull(String val) {
    if (val.isEmpty) return null;
    return DateTime.tryParse(val);
  }

  Map<String, dynamic> toJson() {
    return {
      if (patientId != null && patientId!.isNotEmpty) 'patient': patientId,
      'doctor': doctorId,
      if (clinicId != null && clinicId!.isNotEmpty) 'clinic': clinicId,
      'type': typeToString(type),
      'date': date,
      'time': time,
      'status': statusToString(status),
      if (patientName != null) 'patient_name': patientName,
      if (patientPhone != null) 'patient_phone': patientPhone,
      if (checkInTime != null) 'check_in_time': checkInTime!.toUtc().toIso8601String(),
      if (checkOutTime != null) 'check_out_time': checkOutTime!.toUtc().toIso8601String(),
      if (consultationStartTime != null) 'consultation_start_time': consultationStartTime!.toUtc().toIso8601String(),
      if (consultationEndTime != null) 'consultation_end_time': consultationEndTime!.toUtc().toIso8601String(),
      'patient_details_saved': patientDetailsSaved,
      'patient_details_partial': patientDetailsPartial,
      'treatment_plan_partial': treatmentPlanPartial,
      if (linkedTreatmentPlanId != null && linkedTreatmentPlanId!.isNotEmpty)
        'linked_treatment_plan_id': linkedTreatmentPlanId,
    };
  }

  /// Display name: expanded patient name > placeholder name
  String get displayName =>
      expandedPatientName ?? patientName ?? 'Unknown Patient';

  static AppointmentType _parseType(String t) {
    if (t == 'walk_in') return AppointmentType.walkIn;
    if (t == 'session') return AppointmentType.session;
    return AppointmentType.callBy;
  }

  static String typeToString(AppointmentType t) {
    if (t == AppointmentType.walkIn) return 'walk_in';
    if (t == AppointmentType.session) return 'session';
    return 'call_by';
  }

  static AppointmentStatus _parseStatus(String s) {
    switch (s) {
      case 'waiting':
        return AppointmentStatus.waiting;
      case 'in_progress':
        return AppointmentStatus.inProgress;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      default:
        return AppointmentStatus.scheduled;
    }
  }

  static String statusToString(AppointmentStatus s) {
    switch (s) {
      case AppointmentStatus.waiting:
        return 'waiting';
      case AppointmentStatus.inProgress:
        return 'in_progress';
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.scheduled:
        return 'scheduled';
    }
  }
}
