import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/providers/pocketbase_provider.dart';

class WorkingSchedule {
  final String day;
  final String startTime;
  final String endTime;
  /// Multiple break windows per day: [{'start': 'HH:mm', 'end': 'HH:mm'}, ...]
  final List<Map<String, String>> breaks;

  WorkingSchedule({
    required this.day,
    required this.startTime,
    required this.endTime,
    List<Map<String, String>>? breaks,
  }) : breaks = breaks ?? [];

  factory WorkingSchedule.fromJson(Map<String, dynamic> json) {
    // Support new array format: breaks: [{start, end}, ...]
    List<Map<String, String>> breaks = [];
    final rawBreaks = json['breaks'];
    if (rawBreaks is List && rawBreaks.isNotEmpty) {
      breaks = rawBreaks.map((b) {
        final m = b as Map<String, dynamic>;
        return {'start': m['start'] as String, 'end': m['end'] as String};
      }).toList();
    } else {
      // Fall back to old flat format for backward compat
      final bs = json['break_start'] as String?;
      final be = json['break_end'] as String?;
      if (bs != null && be != null) {
        breaks = [{'start': bs, 'end': be}];
      }
    }

    return WorkingSchedule(
      day: json['day'] as String,
      startTime: json['start'] as String,
      endTime: json['end'] as String,
      breaks: breaks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'start': startTime,
      'end': endTime,
      if (breaks.isNotEmpty) 'breaks': breaks,
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
  final bool verified;
  // New profile fields
  final String? phone;
  final String? dateOfBirth;
  final String? photoUrl;
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
    this.verified = false,
    this.phone,
    this.dateOfBirth,
    this.photoUrl,
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

    final photoFile = record.getStringValue('photo');
    String? photoUrl;
    if (photoFile.isNotEmpty) {
      photoUrl = '$pbBaseUrl/api/files/${record.collectionId}/${record.id}/$photoFile';
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
      verified: record.getBoolValue('verified'),
      phone: record.getStringValue('phone'),
      dateOfBirth: record.getStringValue('dob'),
      photoUrl: photoUrl,
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  List<int> get workingDays {
    final Map<String, int> dayMap = {
      'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4,
      'Friday': 5, 'Saturday': 6, 'Sunday': 7
    };
    return workingSchedule
        .map((s) => dayMap[s.day])
        .where((d) => d != null)
        .cast<int>()
        .toList();
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
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (dateOfBirth != null && dateOfBirth!.isNotEmpty) 'dob': dateOfBirth,
    };
  }
}
