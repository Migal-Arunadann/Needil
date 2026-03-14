import 'package:pocketbase/pocketbase.dart';

class ClinicModel {
  final String id;
  final String name;
  final String username;
  final String? email;
  final int bedCount;
  final String clinicId; // Unique code for doctor joining
  final bool verified;
  final DateTime? created;
  final DateTime? updated;

  ClinicModel({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    required this.bedCount,
    required this.clinicId,
    this.verified = false,
    this.created,
    this.updated,
  });

  factory ClinicModel.fromRecord(RecordModel record) {
    return ClinicModel(
      id: record.id,
      name: record.getStringValue('name'),
      username: record.getStringValue('username'),
      email: record.getStringValue('email'),
      bedCount: record.getIntValue('bed_count'),
      clinicId: record.getStringValue('clinic_id'),
      verified: record.getBoolValue('verified'),
      created: DateTime.tryParse(record.get<String>('created')),
      updated: DateTime.tryParse(record.get<String>('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      if (email != null && email!.isNotEmpty) 'email': email,
      'bed_count': bedCount,
      'clinic_id': clinicId,
    };
  }
}
