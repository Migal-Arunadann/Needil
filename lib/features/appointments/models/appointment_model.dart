import 'package:pocketbase/pocketbase.dart';

enum AppointmentType { callBy, walkIn }

enum AppointmentStatus { scheduled, inProgress, completed, cancelled }

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
    this.created,
    this.updated,
    this.doctorName,
    this.expandedPatientName,
  });

  factory AppointmentModel.fromRecord(RecordModel record) {
    // Try to get expanded doctor/patient names
    String? doctorName;
    String? expandedPatientName;

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

    return AppointmentModel(
      id: record.id,
      patientId: record.getStringValue('patient'),
      doctorId: record.getStringValue('doctor'),
      clinicId: record.getStringValue('clinic'),
      type: record.getStringValue('type') == 'walk_in'
          ? AppointmentType.walkIn
          : AppointmentType.callBy,
      date: record.getStringValue('date'),
      time: record.getStringValue('time'),
      status: _parseStatus(record.getStringValue('status')),
      patientName: record.getStringValue('patient_name'),
      patientPhone: record.getStringValue('patient_phone'),
      created: DateTime.tryParse(record.get<String>('created')),
      updated: DateTime.tryParse(record.get<String>('updated')),
      doctorName: doctorName,
      expandedPatientName: expandedPatientName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (patientId != null && patientId!.isNotEmpty) 'patient': patientId,
      'doctor': doctorId,
      if (clinicId != null && clinicId!.isNotEmpty) 'clinic': clinicId,
      'type': type == AppointmentType.walkIn ? 'walk_in' : 'call_by',
      'date': date,
      'time': time,
      'status': statusToString(status),
      if (patientName != null) 'patient_name': patientName,
      if (patientPhone != null) 'patient_phone': patientPhone,
    };
  }

  /// Display name: expanded patient name > placeholder name
  String get displayName =>
      expandedPatientName ?? patientName ?? 'Unknown Patient';

  static AppointmentStatus _parseStatus(String s) {
    switch (s) {
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
