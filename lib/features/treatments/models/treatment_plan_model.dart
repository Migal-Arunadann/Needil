import 'package:pocketbase/pocketbase.dart';

enum TreatmentPlanStatus { active, completed, paused }

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
  final DateTime? created;
  final DateTime? updated;

  // Expanded
  final String? patientName;

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
    this.created,
    this.updated,
    this.patientName,
  });

  bool get isMaintenance => planType == 'maintenance';

  factory TreatmentPlanModel.fromRecord(RecordModel record) {
    String? patientName;
    try {
      final dynExpand = record.data['expand'];
      if (dynExpand != null && dynExpand is Map) {
        final pat = dynExpand['patient'];
        if (pat != null && pat is Map) {
          patientName = pat['full_name'] as String?;
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
      status: _parseStatus(record.getStringValue('status')),
      planType: planTypeVal.isNotEmpty ? planTypeVal : 'treatment',
      intervalUnit: intervalUnitVal.isNotEmpty ? intervalUnitVal : 'days',
      parentPlanId: record.getStringValue('parent_plan').isNotEmpty
          ? record.getStringValue('parent_plan')
          : null,
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
      patientName: patientName,
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
    };
  }

  static TreatmentPlanStatus _parseStatus(String s) {
    switch (s) {
      case 'completed':
        return TreatmentPlanStatus.completed;
      case 'paused':
        return TreatmentPlanStatus.paused;
      default:
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
    }
  }
}
