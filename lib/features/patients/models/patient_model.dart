import 'package:pocketbase/pocketbase.dart';

class PatientModel {
  final String id;
  final String fullName;
  final String phone;
  final String? dateOfBirth;
  final String? address;  // Legacy single-line address (kept for backwards-compat)
  final String? city;
  final String? area;
  final String? pincode;
  final String? emergencyContact;
  final String? allergiesConditions;
  final String doctorId;
  final String? clinicId;
  final bool consentGiven;
  final String? consentDate;
  final String? gender;
  final String? occupation;
  final String? email;
  final int? age;
  final DateTime? created;
  final DateTime? updated;

  PatientModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.dateOfBirth,
    this.address,
    this.city,
    this.area,
    this.pincode,
    this.emergencyContact,
    this.allergiesConditions,
    required this.doctorId,
    this.clinicId,
    this.gender,
    this.occupation,
    this.email,
    this.age,
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
      city: record.getStringValue('city'),
      area: record.getStringValue('area'),
      pincode: record.getStringValue('pincode'),
      emergencyContact: record.getStringValue('emergency_contact'),
      allergiesConditions: record.getStringValue('allergies_conditions'),
      doctorId: record.getStringValue('doctor'),
      clinicId: record.getStringValue('clinic'),
      gender: record.getStringValue('gender'),
      occupation: record.getStringValue('occupation'),
      email: record.getStringValue('email'),
      age: record.getIntValue('age'),
      consentGiven: record.getBoolValue('consent_given'),
      consentDate: record.getStringValue('consent_date'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone': phone,
      if (dateOfBirth != null && dateOfBirth!.isNotEmpty)
        'date_of_birth': dateOfBirth,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (city != null && city!.isNotEmpty) 'city': city,
      if (area != null && area!.isNotEmpty) 'area': area,
      if (pincode != null && pincode!.isNotEmpty) 'pincode': pincode,
      if (emergencyContact != null && emergencyContact!.isNotEmpty)
        'emergency_contact': emergencyContact,
      if (allergiesConditions != null && allergiesConditions!.isNotEmpty)
        'allergies_conditions': allergiesConditions,
      'doctor': doctorId,
      if (clinicId != null && clinicId!.isNotEmpty) 'clinic': clinicId,
      if (gender != null && gender!.isNotEmpty) 'gender': gender,
      if (occupation != null && occupation!.isNotEmpty) 'occupation': occupation,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (age != null) 'age': age,
      'consent_given': consentGiven,
      if (consentDate != null && consentDate!.isNotEmpty)
        'consent_date': consentDate,
    };
  }
}
