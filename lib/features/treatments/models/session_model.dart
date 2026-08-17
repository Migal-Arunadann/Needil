import 'package:pocketbase/pocketbase.dart';

enum SessionStatus { upcoming, overdue, waiting, inProgress, completed, missed, cancelled, paused }

class SessionModel {
  final String id;
  final String treatmentPlanId;
  final String patientId;
  final String doctorId;
  final String? patientName;
  final String? doctorName;
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
  // ── v2 scheduling fields ──────────────────────────────────────
  /// True when a doctor or receptionist manually rescheduled this session.
  /// Auto-cascades will skip pinned sessions during rescheduling.
  final bool isPinned;
  final DateTime? completedAt;
  final DateTime? missedAt;
  final DateTime? pausedAt;
  // ─────────────────────────────────────────────────────────────
  final DateTime? created;
  final DateTime? updated;

  // Soft Delete
  final bool isDeleted;
  final DateTime? deletedAt;

  SessionModel({
    required this.id,
    required this.treatmentPlanId,
    required this.patientId,
    required this.doctorId,
    this.patientName,
    this.doctorName,
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
    this.isPinned = false,
    this.completedAt,
    this.missedAt,
    this.pausedAt,
    this.created,
    this.updated,
    this.isDeleted = false,
    this.deletedAt,
  });

  bool get isMaintenance => sessionType == 'maintenance';

  SessionModel copyWith({
    String? id,
    String? treatmentPlanId,
    String? patientId,
    String? doctorId,
    String? patientName,
    String? doctorName,
    int? sessionNumber,
    String? scheduledDate,
    String? scheduledTime,
    SessionStatus? status,
    String? sessionType,
    String? treatmentModality,
    String? notes,
    String? bpLevel,
    int? pulse,
    List<String>? photos,
    String? remarks,
    bool? isRescheduled,
    int? rescheduleCount,
    String? originalDate,
    bool? isPinned,
    DateTime? completedAt,
    DateTime? missedAt,
    DateTime? pausedAt,
    DateTime? created,
    DateTime? updated,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      treatmentPlanId: treatmentPlanId ?? this.treatmentPlanId,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      sessionType: sessionType ?? this.sessionType,
      treatmentModality: treatmentModality ?? this.treatmentModality,
      notes: notes ?? this.notes,
      bpLevel: bpLevel ?? this.bpLevel,
      pulse: pulse ?? this.pulse,
      photos: photos ?? this.photos,
      remarks: remarks ?? this.remarks,
      isRescheduled: isRescheduled ?? this.isRescheduled,
      rescheduleCount: rescheduleCount ?? this.rescheduleCount,
      originalDate: originalDate ?? this.originalDate,
      isPinned: isPinned ?? this.isPinned,
      completedAt: completedAt ?? this.completedAt,
      missedAt: missedAt ?? this.missedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory SessionModel.fromRecord(RecordModel record) {
    final sessionTypeVal = record.getStringValue('session_type');
    final treatmentTypeVal = record.getStringValue('treatment_type');

    String? pName;
    String? dName;
    try {
      final expandData = record.get<Map<String, dynamic>>('expand');
      if (expandData.isNotEmpty) {
        if (expandData.containsKey('patient')) {
          final pMap = expandData['patient'];
          if (pMap is Map) pName = pMap['full_name'] as String?;
        }
        if (expandData.containsKey('doctor')) {
          final dMap = expandData['doctor'];
          if (dMap is Map) dName = dMap['name'] as String?;
        }
      }
    } catch (_) {}

    return SessionModel(
      id: record.id,
      treatmentPlanId: record.getStringValue('treatment_plan'),
      patientId: record.getStringValue('patient'),
      doctorId: record.getStringValue('doctor'),
      patientName: (pName != null && pName.isNotEmpty) ? pName : null,
      doctorName: (dName != null && dName.isNotEmpty) ? dName : null,
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
      isPinned: record.getBoolValue('is_pinned'),
      completedAt: record.getStringValue('completed_at').isNotEmpty
          ? DateTime.tryParse(record.getStringValue('completed_at'))
          : null,
      missedAt: record.getStringValue('missed_at').isNotEmpty
          ? DateTime.tryParse(record.getStringValue('missed_at'))
          : null,
      pausedAt: record.getStringValue('paused_at').isNotEmpty
          ? DateTime.tryParse(record.getStringValue('paused_at'))
          : null,
      created: _parseDate(record, 'created'),
      updated: _parseDate(record, 'updated'),
      isDeleted: record.getBoolValue('is_deleted'),
      deletedAt: DateTime.tryParse(record.getStringValue('deleted_at')),
    );
  }

  static DateTime? _parseDate(RecordModel record, String field) {
    try {
      final val = record.get<String>(field);
      if (val.isNotEmpty) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed.toLocal();
      }
    } catch (_) {}

    try {
      final raw = record.data[field]?.toString();
      if (raw != null && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed.toLocal();
      }
    } catch (_) {}

    try {
      if (field == 'created') {
        // ignore: deprecated_member_use
        final val = record.created;
        if (val.isNotEmpty) {
          final parsed = DateTime.tryParse(val);
          if (parsed != null) return parsed.toLocal();
        }
      } else if (field == 'updated') {
        // ignore: deprecated_member_use
        final val = record.updated;
        if (val.isNotEmpty) {
          final parsed = DateTime.tryParse(val);
          if (parsed != null) return parsed.toLocal();
        }
      }
    } catch (_) {}

    return null;
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
      if (isPinned) 'is_pinned': true,
      if (completedAt != null) 'completed_at': completedAt!.toUtc().toIso8601String(),
      if (missedAt != null) 'missed_at': missedAt!.toUtc().toIso8601String(),
      if (pausedAt != null) 'paused_at': pausedAt!.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
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
      case 'overdue':
        return SessionStatus.overdue;
      default:
        return SessionStatus.upcoming;
    }
  }

  static String statusToString(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:
        return 'upcoming';
      case SessionStatus.overdue:
        return 'overdue';
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
