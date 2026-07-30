import 'package:pocketbase/pocketbase.dart';

/// Lifecycle states for a treatment plan.
///
/// [active]       — Normal operation.
/// [paused]       — Doctor/receptionist paused the plan.
/// [manualReview] — Requires human intervention (3+ consecutive misses or expiry).
/// [completed]    — All sessions finished successfully (terminal).
/// [closed]       — Terminated early (see [closureReason]).
enum TreatmentPlanStatus { active, completed, paused, manualReview, closed }

/// Reason a treatment plan was closed early.
enum ClosureReason {
  completed,       // Natural completion — also set automatically
  discontinued,    // Doctor decided to stop
  patientStopped,  // Patient chose to discontinue
  medicalDecision, // Clinical reason
  financial,       // Payment / billing issues
}

class TreatmentPlanModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String? consultationId;
  final String treatmentType;
  final String startDate;
  final int totalSessions;
  final int intervalDays;
  final double sessionFee;
  final TreatmentPlanStatus status;
  final String planType;       // 'treatment' or 'maintenance'
  final String intervalUnit;   // 'days', 'months', 'years'
  final String? parentPlanId;  // links maintenance → original treatment plan
  final int consecutiveMisses;
  // ── v2 scheduling fields ──────────────────────────────────────
  final int totalMisses;
  final int completedSessions;
  final int scheduleVersion;
  final int expiryDays;
  final DateTime? lastActivityAt;
  final String? closureReason;
  final String? closedBy;
  // ─────────────────────────────────────────────────────────────
  final bool isPaused;
  final String? pausedAt;
  final DateTime? created;
  final DateTime? updated;

  // Soft Delete
  final bool isDeleted;
  final DateTime? deletedAt;

  // Expanded
  final String? patientName;
  final String? patientPhone;

  TreatmentPlanModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    this.consultationId,
    required this.treatmentType,
    required this.startDate,
    required this.totalSessions,
    required this.intervalDays,
    required this.sessionFee,
    required this.status,
    this.planType = 'treatment',
    this.intervalUnit = 'days',
    this.parentPlanId,
    this.consecutiveMisses = 0,
    this.totalMisses = 0,
    this.completedSessions = 0,
    this.scheduleVersion = 1,
    this.expiryDays = 90,
    this.lastActivityAt,
    this.closureReason,
    this.closedBy,
    this.isPaused = false,
    this.pausedAt,
    this.created,
    this.updated,
    this.isDeleted = false,
    this.deletedAt,
    this.patientName,
    this.patientPhone,
  });

  bool get isMaintenance => planType == 'maintenance';

  factory TreatmentPlanModel.fromRecord(RecordModel record) {
    String? patientName;
    String? patientPhone;
    try {
      final dynExpand = record.data['expand'];
      if (dynExpand != null && dynExpand is Map) {
        final pat = dynExpand['patient'];
        if (pat != null && pat is Map) {
          patientName = pat['full_name'] as String?;
          patientPhone = pat['phone'] as String?;
        }
      }
    } catch (_) {}

    final planTypeVal = record.getStringValue('plan_type');
    final intervalUnitVal = record.getStringValue('interval_unit');

    return TreatmentPlanModel(
      id: record.id,
      patientId: record.getStringValue('patient'),
      doctorId: record.getStringValue('doctor'),
      consultationId: record.getStringValue('consultation'),
      treatmentType: record.getStringValue('treatment_type'),
      startDate: record.getStringValue('start_date'),
      totalSessions: record.getIntValue('total_sessions'),
      intervalDays: record.getIntValue('interval_days'),
      sessionFee: record.getDoubleValue('session_fee'),
      status: parseStatus(record.getStringValue('status')),
      planType: planTypeVal.isNotEmpty ? planTypeVal : 'treatment',
      intervalUnit: intervalUnitVal.isNotEmpty ? intervalUnitVal : 'days',
      parentPlanId: record.getStringValue('parent_plan').isNotEmpty
          ? record.getStringValue('parent_plan')
          : null,
      consecutiveMisses: record.getIntValue('consecutive_misses'),
      totalMisses: record.getIntValue('total_misses'),
      completedSessions: record.getIntValue('completed_sessions'),
      scheduleVersion: record.getIntValue('schedule_version') > 0
          ? record.getIntValue('schedule_version')
          : 1,
      expiryDays: record.getIntValue('expiry_days') > 0
          ? record.getIntValue('expiry_days')
          : 90,
      lastActivityAt: record.getStringValue('last_activity_at').isNotEmpty
          ? DateTime.tryParse(record.getStringValue('last_activity_at'))
          : null,
      closureReason: record.getStringValue('closure_reason').isNotEmpty
          ? record.getStringValue('closure_reason')
          : null,
      closedBy: record.getStringValue('closed_by').isNotEmpty
          ? record.getStringValue('closed_by')
          : null,
      isPaused: record.getBoolValue('is_paused'),
      pausedAt: record.getStringValue('paused_at').isNotEmpty
          ? record.getStringValue('paused_at')
          : null,
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
      isDeleted: record.getBoolValue('is_deleted'),
      deletedAt: DateTime.tryParse(record.getStringValue('deleted_at')),
      patientName: patientName,
      patientPhone: patientPhone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient': patientId,
      'doctor': doctorId,
      if (consultationId != null && consultationId!.isNotEmpty)
        'consultation': consultationId,
      'treatment_type': treatmentType,
      'start_date': startDate,
      'total_sessions': totalSessions,
      'interval_days': intervalDays,
      'session_fee': sessionFee,
      'status': statusToString(status),
      'plan_type': planType,
      'interval_unit': intervalUnit,
      if (parentPlanId != null && parentPlanId!.isNotEmpty)
        'parent_plan': parentPlanId,
      'consecutive_misses': consecutiveMisses,
      'total_misses': totalMisses,
      'completed_sessions': completedSessions,
      'schedule_version': scheduleVersion,
      'expiry_days': expiryDays,
      if (lastActivityAt != null) 'last_activity_at': lastActivityAt!.toUtc().toIso8601String(),
      if (closureReason != null && closureReason!.isNotEmpty) 'closure_reason': closureReason,
      if (closedBy != null && closedBy!.isNotEmpty) 'closed_by': closedBy,
      'is_paused': isPaused,
      if (pausedAt != null && pausedAt!.isNotEmpty) 'paused_at': pausedAt,
      'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt!.toUtc().toIso8601String(),
    };
  }

  /// Parse a status string from PocketBase into the enum.
  /// Public so external components (e.g. TreatmentLifecycle) can parse
  /// status strings without duplicating the logic.
  static TreatmentPlanStatus parseStatus(String s) {
    switch (s) {
      case 'completed':
        return TreatmentPlanStatus.completed;
      case 'paused':
        return TreatmentPlanStatus.paused;
      case 'manual_review':
        return TreatmentPlanStatus.manualReview;
      case 'closed':
        return TreatmentPlanStatus.closed;
      default:
        // Unknown values (including legacy data) fall back to active.
        return TreatmentPlanStatus.active;
    }
  }

  static String statusToString(TreatmentPlanStatus s) {
    switch (s) {
      case TreatmentPlanStatus.active:
        return 'active';
      case TreatmentPlanStatus.completed:
        return 'completed';
      case TreatmentPlanStatus.paused:
        return 'paused';
      case TreatmentPlanStatus.manualReview:
        return 'manual_review';
      case TreatmentPlanStatus.closed:
        return 'closed';
    }
  }

  /// Serialize a [ClosureReason] enum value to the string stored in PocketBase.
  static String closureReasonToString(ClosureReason r) {
    switch (r) {
      case ClosureReason.completed:
        return 'completed';
      case ClosureReason.discontinued:
        return 'discontinued';
      case ClosureReason.patientStopped:
        return 'patient_stopped';
      case ClosureReason.medicalDecision:
        return 'medical_decision';
      case ClosureReason.financial:
        return 'financial';
    }
  }

  /// Parse a closure reason string from PocketBase into the enum.
  static ClosureReason parseClosureReason(String s) {
    switch (s) {
      case 'completed':
        return ClosureReason.completed;
      case 'patient_stopped':
        return ClosureReason.patientStopped;
      case 'medical_decision':
        return ClosureReason.medicalDecision;
      case 'financial':
        return ClosureReason.financial;
      default:
        return ClosureReason.discontinued;
    }
  }
}
