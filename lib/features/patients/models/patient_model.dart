import 'package:pocketbase/pocketbase.dart';

class PatientModel {
  final String id;
  final String fullName;
  final String phone;
  final String? patientId;        // Custom clinic prefix ID (e.g. HSK-001)
  final String? photo;            // Profile photo filename
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
  final bool privacyPolicyAccepted;
  final String? privacyPolicyAcceptedDate;
  final String? gender;
  final String? occupation;
  final String? email;
  final int? age;
  final String? reference;        // Referred by (doctor, friend, etc.)
  final String? howDidYouHear;    // How do you know us
  /// Relation of this patient to the primary phone-account holder.
  /// Values: "Self", "Spouse", "Child", "Parent", "Sibling", "Other".
  /// Null for legacy records or the original/primary patient.
  final String? relationToPrimary;
  final DateTime? created;
  final DateTime? updated;
  final bool requiresPatientDetailsUpdate;

  PatientModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.patientId,
    this.photo,
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
    this.reference,
    this.howDidYouHear,
    this.relationToPrimary,
    this.consentGiven = false,
    this.consentDate,
    this.privacyPolicyAccepted = false,
    this.privacyPolicyAcceptedDate,
    this.created,
    this.updated,
    this.requiresPatientDetailsUpdate = false,
  });

  /// Build the full photo URL from PocketBase.
  String? getPhotoUrl(String baseUrl) {
    if (photo == null || photo!.isEmpty || id.isEmpty) return null;
    return '$baseUrl/api/files/patients/$id/$photo';
  }

  factory PatientModel.fromRecord(RecordModel record) {
    return PatientModel(
      id: record.id,
      fullName: record.getStringValue('full_name'),
      phone: record.getStringValue('phone'),
      patientId: record.getStringValue('patient_id'),
      photo: record.getStringValue('photo'),
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
      reference: record.getStringValue('reference'),
      howDidYouHear: record.getStringValue('how_did_you_hear'),
      relationToPrimary: record.getStringValue('relation_to_primary').isNotEmpty
          ? record.getStringValue('relation_to_primary')
          : null,
      consentGiven: record.getBoolValue('consent_given'),
      consentDate: record.getStringValue('consent_date'),
      privacyPolicyAccepted: record.getBoolValue('privacy_policy_accepted'),
      privacyPolicyAcceptedDate: record.getStringValue('privacy_policy_accepted_date'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
      requiresPatientDetailsUpdate: record.getBoolValue('requires_patient_details_update'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'phone': phone,
      if (patientId != null && patientId!.isNotEmpty)
        'patient_id': patientId,
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
      if (reference != null && reference!.isNotEmpty) 'reference': reference,
      if (howDidYouHear != null && howDidYouHear!.isNotEmpty)
        'how_did_you_hear': howDidYouHear,
      if (relationToPrimary != null && relationToPrimary!.isNotEmpty)
        'relation_to_primary': relationToPrimary,
      'consent_given': consentGiven,
      if (consentDate != null && consentDate!.isNotEmpty)
        'consent_date': consentDate,
      'privacy_policy_accepted': privacyPolicyAccepted,
      if (privacyPolicyAcceptedDate != null && privacyPolicyAcceptedDate!.isNotEmpty)
        'privacy_policy_accepted_date': privacyPolicyAcceptedDate,
      'requires_patient_details_update': requiresPatientDetailsUpdate,
    };
  }
}
