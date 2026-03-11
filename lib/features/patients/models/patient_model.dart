import 'package:pocketbase/pocketbase.dart';

class PatientModel {
  final String id;
  final String fullName;
  final String phone;
  final String? dateOfBirth;
  final String? address;
  final String? emergencyContact;
  final String? allergiesConditions;
  final String doctorId;
  final String? clinicId;
  final bool consentGiven;
  final String? consentDate;
  final DateTime? created;
  final DateTime? updated;

  PatientModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.dateOfBirth,
    this.address,
    this.emergencyContact,
    this.allergiesConditions,
    required this.doctorId,
    this.clinicId,
    this.consentGiven = false,
    this.consentDate,
    this.created,
    this.updated,
  });

  factory PatientModel.fromRecord(RecordModel record) {
    return PatientModel(
      id: record.id,
      fullName: record.getStringValue('full_name'),
      phone: record.getStringValue('phone'),
      dateOfBirth: record.getStringValue('date_of_birth'),
      address: record.getStringValue('address'),
      emergencyContact: record.getStringValue('emergency_contact'),
      allergiesConditions: record.getStringValue('allergies_conditions'),
      doctorId: record.getStringValue('doctor'),
      clinicId: record.getStringValue('clinic'),
      consentGiven: record.getBoolValue('consent_given'),
      consentDate: record.getStringValue('consent_date'),
      created: DateTime.tryParse(record.get<String>('created')),
      updated: DateTime.tryParse(record.get<String>('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone': phone,
      if (dateOfBirth != null && dateOfBirth!.isNotEmpty)
        'date_of_birth': dateOfBirth,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (emergencyContact != null && emergencyContact!.isNotEmpty)
        'emergency_contact': emergencyContact,
      if (allergiesConditions != null && allergiesConditions!.isNotEmpty)
        'allergies_conditions': allergiesConditions,
      'doctor': doctorId,
      if (clinicId != null && clinicId!.isNotEmpty) 'clinic': clinicId,
      'consent_given': consentGiven,
      if (consentDate != null && consentDate!.isNotEmpty)
        'consent_date': consentDate,
    };
  }
}
