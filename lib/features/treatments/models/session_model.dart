import 'package:pocketbase/pocketbase.dart';

enum SessionStatus { upcoming, waiting, completed, missed, cancelled }

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
  final String? notes;
  final String? bpLevel;
  final int? pulse;
  final List<String> photos;
  final String? remarks;
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
    this.notes,
    this.bpLevel,
    this.pulse,
    this.photos = const [],
    this.remarks,
    this.created,
    this.updated,
  });

  bool get isMaintenance => sessionType == 'maintenance';

  factory SessionModel.fromRecord(RecordModel record) {
    final sessionTypeVal = record.getStringValue('session_type');
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
      notes: record.getStringValue('notes'),
      bpLevel: record.getStringValue('bp_level'),
      pulse: record.getIntValue('pulse'),
      photos: record.getListValue<String>('photos'),
      remarks: record.getStringValue('remarks'),
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
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (bpLevel != null && bpLevel!.isNotEmpty) 'bp_level': bpLevel,
      if (pulse != null) 'pulse': pulse,
      if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
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
      case 'waiting':
        return SessionStatus.waiting;
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
      case SessionStatus.completed:
        return 'completed';
      case SessionStatus.missed:
        return 'missed';
      case SessionStatus.cancelled:
        return 'cancelled';
    }
  }
}
