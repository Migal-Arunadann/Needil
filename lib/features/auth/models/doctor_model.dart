import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';

class WorkingSchedule {
  final String day;
  final String startTime;
  final String endTime;
  final String? breakStart;
  final String? breakEnd;

  WorkingSchedule({
    required this.day,
    required this.startTime,
    required this.endTime,
    this.breakStart,
    this.breakEnd,
  });

  factory WorkingSchedule.fromJson(Map<String, dynamic> json) {
    return WorkingSchedule(
      day: json['day'] as String,
      startTime: json['start'] as String,
      endTime: json['end'] as String,
      breakStart: json['break_start'] as String?,
      breakEnd: json['break_end'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'start': startTime,
      'end': endTime,
      if (breakStart != null) 'break_start': breakStart,
      if (breakEnd != null) 'break_end': breakEnd,
    };
  }
}

class TreatmentConfig {
  final String type;
  final int durationMinutes;
  final double fee;

  TreatmentConfig({
    required this.type,
    required this.durationMinutes,
    required this.fee,
  });

  factory TreatmentConfig.fromJson(Map<String, dynamic> json) {
    return TreatmentConfig(
      type: json['type'] as String,
      durationMinutes: json['duration_min'] as int,
      fee: (json['fee'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'duration_min': durationMinutes,
      'fee': fee,
    };
  }
}

class DoctorModel {
  final String id;
  final String name;
  final int age;
  final String username;
  final String? email;
  final String? clinicId; // Relation to clinics collection
  final bool isPrimary;
  final List<WorkingSchedule> workingSchedule;
  final List<TreatmentConfig> treatments;
  final bool sharePastPatients;
  final bool shareFuturePatients;
  final DateTime? created;
  final DateTime? updated;

  DoctorModel({
    required this.id,
    required this.name,
    required this.age,
    required this.username,
    this.email,
    this.clinicId,
    this.isPrimary = false,
    required this.workingSchedule,
    required this.treatments,
    this.sharePastPatients = false,
    this.shareFuturePatients = false,
    this.created,
    this.updated,
  });

  factory DoctorModel.fromRecord(RecordModel record) {
    // Parse working_schedule JSON
    List<WorkingSchedule> schedule = [];
    final scheduleData = record.getListValue<dynamic>('working_schedule');
    if (scheduleData.isNotEmpty) {
      schedule = scheduleData.map((item) {
        if (item is String) {
          return WorkingSchedule.fromJson(
              jsonDecode(item) as Map<String, dynamic>);
        }
        return WorkingSchedule.fromJson(item as Map<String, dynamic>);
      }).toList();
    }

    // Parse treatments JSON
    List<TreatmentConfig> treatments = [];
    final treatmentsData = record.getListValue<dynamic>('treatments');
    if (treatmentsData.isNotEmpty) {
      treatments = treatmentsData.map((item) {
        if (item is String) {
          return TreatmentConfig.fromJson(
              jsonDecode(item) as Map<String, dynamic>);
        }
        return TreatmentConfig.fromJson(item as Map<String, dynamic>);
      }).toList();
    }

    return DoctorModel(
      id: record.id,
      name: record.getStringValue('name'),
      age: record.getIntValue('age'),
      username: record.getStringValue('username'),
      email: record.getStringValue('email'),
      clinicId: record.getStringValue('clinic'),
      isPrimary: record.getBoolValue('is_primary'),
      workingSchedule: schedule,
      treatments: treatments,
      sharePastPatients: record.getBoolValue('share_past_patients'),
      shareFuturePatients: record.getBoolValue('share_future_patients'),
      created: DateTime.tryParse(record.get<String>('created')),
      updated: DateTime.tryParse(record.get<String>('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'username': username,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (clinicId != null && clinicId!.isNotEmpty) 'clinic': clinicId,
      'is_primary': isPrimary,
      'working_schedule': workingSchedule.map((s) => s.toJson()).toList(),
      'treatments': treatments.map((t) => t.toJson()).toList(),
      'share_past_patients': sharePastPatients,
      'share_future_patients': shareFuturePatients,
    };
  }
}
