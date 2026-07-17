import 'package:pocketbase/pocketbase.dart';

enum SessionStatus { upcoming, waiting, inProgress, completed, missed, cancelled, paused }

class SessionModel {
  final String id;
  final String treatmentPlanId;
  final String patientId;
  final String doctorId;
  final int sessionNumber;
  final String scheduledDate;
  final String? scheduledTime;
  final SessionStatus status;
  final String sessionType;   // 'treatment' or 'maintenance'
  final String treatmentModality; // e.g. 'Acupuncture', 'Cupping Therapy', etc.
  final String? notes;
  final String? bpLevel;
  final int? pulse;
  final List<String> photos;
  final String? remarks;
  final bool isRescheduled;
  final int rescheduleCount;
  final String? originalDate;
  final DateTime? created;
  final DateTime? updated;

  SessionModel({
    required this.id,
    required this.treatmentPlanId,
    required this.patientId,
    required this.doctorId,
    required this.sessionNumber,
    required this.scheduledDate,
    this.scheduledTime,
    required this.status,
    this.sessionType = 'treatment',
    this.treatmentModality = '',
    this.notes,
    this.bpLevel,
    this.pulse,
    this.photos = const [],
    this.remarks,
    this.isRescheduled = false,
    this.rescheduleCount = 0,
    this.originalDate,
    this.created,
    this.updated,
  });

  bool get isMaintenance => sessionType == 'maintenance';

  factory SessionModel.fromRecord(RecordModel record) {
    final sessionTypeVal = record.getStringValue('session_type');
    final treatmentTypeVal = record.getStringValue('treatment_type');
    return SessionModel(
      id: record.id,
      treatmentPlanId: record.getStringValue('treatment_plan'),
      patientId: record.getStringValue('patient'),
      doctorId: record.getStringValue('doctor'),
      sessionNumber: record.getIntValue('session_number'),
      scheduledDate: record.getStringValue('scheduled_date'),
      scheduledTime: record.getStringValue('scheduled_time'),
      status: _parseStatus(record.getStringValue('status')),
      sessionType: sessionTypeVal.isNotEmpty ? sessionTypeVal : 'treatment',
      treatmentModality: treatmentTypeVal,
      notes: record.getStringValue('session_notes_'),
      bpLevel: record.getStringValue('vitals_bp'),
      pulse: record.getIntValue('vitals_pulse'),
      photos: record.getListValue<String>('photos'),
      remarks: record.getStringValue('remarks').isNotEmpty ? record.getStringValue('remarks') 
          : record.getStringValue('session_remarks').isNotEmpty ? record.getStringValue('session_remarks')
          : record.getStringValue('session_remarks_').isNotEmpty ? record.getStringValue('session_remarks_')
          : record.getStringValue('remark'),
      isRescheduled: record.getBoolValue('is_rescheduled'),
      rescheduleCount: record.getIntValue('reschedule_count'),
      originalDate: record.getStringValue('original_date').isNotEmpty
          ? record.getStringValue('original_date')
          : null,
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'treatment_plan': treatmentPlanId,
      'patient': patientId,
      'doctor': doctorId,
      'session_number': sessionNumber,
      'scheduled_date': scheduledDate,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
      'status': statusToString(status),
      'session_type': sessionType,
      if (treatmentModality.isNotEmpty) 'treatment_type': treatmentModality,
      if (notes != null && notes!.isNotEmpty) 'session_notes_': notes,
      if (bpLevel != null && bpLevel!.isNotEmpty) 'vitals_bp': bpLevel,
      if (pulse != null) 'vitals_pulse': pulse,
      if (isRescheduled) 'is_rescheduled': true,
      if (rescheduleCount > 0) 'reschedule_count': rescheduleCount,
      if (originalDate != null && originalDate!.isNotEmpty) 'original_date': originalDate,
    };
  }

  static SessionStatus _parseStatus(String s) {
    switch (s) {
      case 'completed':
        return SessionStatus.completed;
      case 'missed':
        return SessionStatus.missed;
      case 'cancelled':
        return SessionStatus.cancelled;
      case 'paused':
        return SessionStatus.paused;
      case 'waiting':
        return SessionStatus.waiting;
      case 'in_progress':
        return SessionStatus.inProgress;
      default:
        return SessionStatus.upcoming;
    }
  }

  static String statusToString(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:
        return 'upcoming';
      case SessionStatus.waiting:
        return 'waiting';
      case SessionStatus.inProgress:
        return 'in_progress';
      case SessionStatus.completed:
        return 'completed';
      case SessionStatus.missed:
        return 'missed';
      case SessionStatus.cancelled:
        return 'cancelled';
      case SessionStatus.paused:
        return 'paused';
    }
  }
}
