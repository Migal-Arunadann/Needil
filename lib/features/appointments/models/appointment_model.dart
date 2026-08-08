import 'package:pocketbase/pocketbase.dart';

// Sentinel object used by AppointmentModel.copyWith to distinguish
// "not provided" from "explicitly set to null" for nullable fields.
const _sentinel = Object();

enum AppointmentType { callBy, walkIn, session }

enum AppointmentStatus { scheduled, waiting, inProgress, completed, cancelled, missed, overdue }

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
  final DateTime? patientDetailsFilledTime;
  final DateTime? consultationStartTime;
  final DateTime? consultationEndTime;       // Set when consultation form is submitted
  final bool patientDetailsSaved;            // true once PatientInfoScreen form is submitted
  final bool patientDetailsPartial;          // true once PatientInfoScreen form is opened (but not yet submitted)
  final bool treatmentPlanPartial;           // true once treatment plan form opened but not submitted
  final bool patientDetailsSkipped;          // true when staff skipped patient details during retroactive consultation fill
  final String? linkedTreatmentPlanId;       // ID of created treatment plan (prevents duplicates)
  final String? linkedConsultationId;        // ID of linked consultation stub (avoids list queries)
  final bool isRescheduled;                   // true when appointment has been rescheduled
  final String? previousStatus;               // status before auto-reconciliation
  final String? reconciliationReason;
  final DateTime? reconciledAt;
  final String? reconciledBy;
  final String? sessionType;
  final String? linkedSessionId; // Direct FK to session record — eliminates fuzzy date+time lookup
  final bool isNewFamilyMember;
  final String? intendedRelation;
  final bool isPinned; // Mirrors session.is_pinned — set when appointment is tied to a pinned session
  final DateTime? created;
  final DateTime? updated;

  // Expanded fields
  final String? doctorName;
  final String? expandedPatientName;
  final String? expandedPatientPhone;
  final bool requiresPatientDetailsUpdate;

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
    this.patientDetailsFilledTime,
    this.consultationStartTime,
    this.consultationEndTime,
    this.patientDetailsSaved = false,
    this.patientDetailsPartial = false,
    this.treatmentPlanPartial = false,
    this.patientDetailsSkipped = false,
    this.linkedTreatmentPlanId,
    this.linkedConsultationId,
    this.isRescheduled = false,
    this.previousStatus,
    this.reconciliationReason,
    this.reconciledAt,
    this.reconciledBy,
    this.sessionType,
    this.linkedSessionId,
    this.isNewFamilyMember = false,
    this.intendedRelation,
    this.isPinned = false,
    this.created,
    this.updated,
    this.doctorName,
    this.expandedPatientName,
    this.expandedPatientPhone,
    this.requiresPatientDetailsUpdate = false,
  });

  bool get consultationFormSaved => consultationEndTime != null;

  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? clinicId,
    AppointmentType? type,
    String? date,
    String? time,
    AppointmentStatus? status,
    String? patientName,
    String? patientPhone,
    Object? checkInTime = _sentinel,
    Object? checkOutTime = _sentinel,
    Object? patientDetailsFilledTime = _sentinel,
    Object? consultationStartTime = _sentinel,
    Object? consultationEndTime = _sentinel,
    bool? patientDetailsSaved,
    bool? patientDetailsPartial,
    bool? treatmentPlanPartial,
    bool? patientDetailsSkipped,
    Object? linkedTreatmentPlanId = _sentinel,
    Object? linkedConsultationId = _sentinel,
    bool? isRescheduled,
    Object? previousStatus = _sentinel,
    Object? reconciliationReason = _sentinel,
    Object? reconciledAt = _sentinel,
    Object? reconciledBy = _sentinel,
    Object? sessionType = _sentinel,
    Object? linkedSessionId = _sentinel,
    bool? isNewFamilyMember,
    Object? intendedRelation = _sentinel,
    bool? isPinned,
    Object? created = _sentinel,
    Object? updated = _sentinel,
    String? doctorName,
    String? expandedPatientName,
    String? expandedPatientPhone,
    bool? requiresPatientDetailsUpdate,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      clinicId: clinicId ?? this.clinicId,
      type: type ?? this.type,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      checkInTime: checkInTime == _sentinel ? this.checkInTime : checkInTime as DateTime?,
      checkOutTime: checkOutTime == _sentinel ? this.checkOutTime : checkOutTime as DateTime?,
      patientDetailsFilledTime: patientDetailsFilledTime == _sentinel ? this.patientDetailsFilledTime : patientDetailsFilledTime as DateTime?,
      consultationStartTime: consultationStartTime == _sentinel ? this.consultationStartTime : consultationStartTime as DateTime?,
      consultationEndTime: consultationEndTime == _sentinel ? this.consultationEndTime : consultationEndTime as DateTime?,
      patientDetailsSaved: patientDetailsSaved ?? this.patientDetailsSaved,
      patientDetailsPartial: patientDetailsPartial ?? this.patientDetailsPartial,
      treatmentPlanPartial: treatmentPlanPartial ?? this.treatmentPlanPartial,
      patientDetailsSkipped: patientDetailsSkipped ?? this.patientDetailsSkipped,
      linkedTreatmentPlanId: linkedTreatmentPlanId == _sentinel ? this.linkedTreatmentPlanId : linkedTreatmentPlanId as String?,
      linkedConsultationId: linkedConsultationId == _sentinel ? this.linkedConsultationId : linkedConsultationId as String?,
      isRescheduled: isRescheduled ?? this.isRescheduled,
      previousStatus: previousStatus == _sentinel ? this.previousStatus : previousStatus as String?,
      reconciliationReason: reconciliationReason == _sentinel ? this.reconciliationReason : reconciliationReason as String?,
      reconciledAt: reconciledAt == _sentinel ? this.reconciledAt : reconciledAt as DateTime?,
      reconciledBy: reconciledBy == _sentinel ? this.reconciledBy : reconciledBy as String?,
      sessionType: sessionType == _sentinel ? this.sessionType : sessionType as String?,
      linkedSessionId: linkedSessionId == _sentinel ? this.linkedSessionId : linkedSessionId as String?,
      isNewFamilyMember: isNewFamilyMember ?? this.isNewFamilyMember,
      intendedRelation: intendedRelation == _sentinel ? this.intendedRelation : intendedRelation as String?,
      isPinned: isPinned ?? this.isPinned,
      created: created == _sentinel ? this.created : created as DateTime?,
      updated: updated == _sentinel ? this.updated : updated as DateTime?,
      doctorName: doctorName ?? this.doctorName,
      expandedPatientName: expandedPatientName ?? this.expandedPatientName,
      expandedPatientPhone: expandedPatientPhone ?? this.expandedPatientPhone,
      requiresPatientDetailsUpdate: requiresPatientDetailsUpdate ?? this.requiresPatientDetailsUpdate,
    );
  }

  bool get isEffectivePatientDetailsSaved {
    if (requiresPatientDetailsUpdate) return false;
    final isCallBy = type == AppointmentType.callBy;
    final hasPatientLinked = patientId != null && patientId!.isNotEmpty;
    return patientDetailsSaved || (!isCallBy && hasPatientLinked);
  }

  factory AppointmentModel.fromRecord(RecordModel record) {
    // Try to get expanded doctor/patient names
    String? doctorName;
    String? expandedPatientName;
    String? expandedPatientPhone;
    bool requiresPatientDetailsUpdate = false;

    try {
      final expandData = record.get<Map<String, dynamic>>('expand');
      if (expandData.isNotEmpty) {
        if (expandData.containsKey('doctor')) {
          final doc = expandData['doctor'];
          if (doc is Map) doctorName = doc['name'] as String?;
        }
        if (expandData.containsKey('patient')) {
          final pat = expandData['patient'];
          if (pat is Map) {
            expandedPatientName = pat['full_name'] as String?;
            expandedPatientPhone = pat['phone'] as String?;
            if (pat.containsKey('requires_patient_details_update')) {
              requiresPatientDetailsUpdate = pat['requires_patient_details_update'] as bool? ?? false;
            }
          }
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
      patientDetailsFilledTime: _parseDateTimeOrNull(record.getStringValue('patient_details_filled_time')),
      consultationStartTime: _parseDateTimeOrNull(record.getStringValue('consultation_start_time')),
      consultationEndTime: _parseDateTimeOrNull(record.getStringValue('consultation_end_time')),
      patientDetailsSaved: record.getBoolValue('patient_details_saved'),
      patientDetailsPartial: record.getBoolValue('patient_details_partial'),
      treatmentPlanPartial: record.getBoolValue('treatment_plan_partial'),
      patientDetailsSkipped: record.getBoolValue('patient_details_skipped'),
      linkedTreatmentPlanId: record.getStringValue('linked_treatment_plan_id').isNotEmpty
          ? record.getStringValue('linked_treatment_plan_id')
          : null,
      linkedConsultationId: record.getStringValue('linked_consultation_id').isNotEmpty
          ? record.getStringValue('linked_consultation_id')
          : null,
      isRescheduled: record.getBoolValue('is_rescheduled'),
      previousStatus: record.getStringValue('previous_status').isNotEmpty 
          ? record.getStringValue('previous_status') : null,
      reconciliationReason: record.getStringValue('reconciliation_reason').isNotEmpty 
          ? record.getStringValue('reconciliation_reason') : null,
      reconciledAt: _parseDateTimeOrNull(record.getStringValue('reconciled_at')),
      reconciledBy: record.getStringValue('reconciled_by').isEmpty ? null : record.getStringValue('reconciled_by'),
      sessionType: record.getStringValue('session_type').isEmpty ? null : record.getStringValue('session_type'),
      linkedSessionId: record.getStringValue('linked_session_id').isEmpty ? null : record.getStringValue('linked_session_id'),
      isNewFamilyMember: record.getBoolValue('is_new_family_member'),
      intendedRelation: record.getStringValue('intended_relation').isEmpty ? null : record.getStringValue('intended_relation'),
      isPinned: record.getBoolValue('is_pinned'),
      created: DateTime.tryParse(record.created)?.toLocal(),
      updated: DateTime.tryParse(record.updated)?.toLocal(),
      doctorName: doctorName,
      expandedPatientName: expandedPatientName,
      expandedPatientPhone: expandedPatientPhone,
      requiresPatientDetailsUpdate: requiresPatientDetailsUpdate,
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
      if (patientDetailsFilledTime != null) 'patient_details_filled_time': patientDetailsFilledTime!.toUtc().toIso8601String(),
      if (consultationStartTime != null) 'consultation_start_time': consultationStartTime!.toUtc().toIso8601String(),
      if (consultationEndTime != null) 'consultation_end_time': consultationEndTime!.toUtc().toIso8601String(),
      'patient_details_saved': patientDetailsSaved,
      'patient_details_partial': patientDetailsPartial,
      'treatment_plan_partial': treatmentPlanPartial,
      if (patientDetailsSkipped) 'patient_details_skipped': patientDetailsSkipped,
      if (linkedTreatmentPlanId != null && linkedTreatmentPlanId!.isNotEmpty)
        'linked_treatment_plan_id': linkedTreatmentPlanId,
      if (linkedConsultationId != null && linkedConsultationId!.isNotEmpty)
        'linked_consultation_id': linkedConsultationId,
      if (linkedSessionId != null && linkedSessionId!.isNotEmpty)
        'linked_session_id': linkedSessionId,
      if (isRescheduled) 'is_rescheduled': true,
      if (previousStatus != null) 'previous_status': previousStatus,
      if (reconciliationReason != null) 'reconciliation_reason': reconciliationReason,
      if (reconciledAt != null) 'reconciled_at': reconciledAt!.toUtc().toIso8601String(),
      if (reconciledBy != null) 'reconciled_by': reconciledBy,
    };
  }

  /// Display name: expanded patient name > placeholder name
  String get displayName =>
      expandedPatientName ?? patientName ?? 'Unknown Patient';

  /// Effective phone: expanded patient phone > placeholder phone
  String? get effectivePhone => expandedPatientPhone ?? patientPhone;

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
      case 'missed':
        return AppointmentStatus.missed;
      case 'overdue':
        return AppointmentStatus.overdue;
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
      case AppointmentStatus.missed:
        return 'missed';
      case AppointmentStatus.overdue:
        return 'overdue';
      case AppointmentStatus.scheduled:
        return 'scheduled';
    }
  }
}
