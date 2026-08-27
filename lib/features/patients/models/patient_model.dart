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
  final String? nationality;
  final String? foreignNumber;
  final String? occupation;
  final String? email;
  final int? age;
  final String? reference;        // Specific name/reference (e.g. Dr. Smith)
  final String? howDidYouHear;    // Category (e.g. Doctor Referral, Google)
  final String? personalNotes;    // Independent personal notes by doctor
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
    this.nationality = 'India',
    this.foreignNumber,
    this.occupation,
    this.email,
    this.age,
    this.reference,
    this.howDidYouHear,
    this.personalNotes,
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
      nationality: record.getStringValue('nationality').isNotEmpty
          ? record.getStringValue('nationality')
          : 'India',
      foreignNumber: record.getStringValue('foreign_number').isNotEmpty
          ? record.getStringValue('foreign_number')
          : null,
      occupation: record.getStringValue('occupation'),
      email: record.getStringValue('email'),
      age: record.getIntValue('age'),
      reference: record.getStringValue('reference'),
      howDidYouHear: record.getStringValue('how_did_you_hear'),
      personalNotes: record.getStringValue('personal_notes'),
      relationToPrimary: record.getStringValue('relation_to_primary').isNotEmpty
          ? record.getStringValue('relation_to_primary')
          : null,
      consentGiven: record.getBoolValue('consent_given'),
      consentDate: record.getStringValue('consent_date'),
      privacyPolicyAccepted: record.getBoolValue('privacy_policy_accepted'),
      privacyPolicyAcceptedDate: record.getStringValue('privacy_policy_accepted_date'),
      created: parseDate(record, 'created'),
      updated: parseDate(record, 'updated'),
      requiresPatientDetailsUpdate: record.getBoolValue('requires_patient_details_update'),
    );
  }

  static DateTime? parseDate(RecordModel record, String field) {
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
      if (nationality != null && nationality!.isNotEmpty) 'nationality': nationality,
      if (foreignNumber != null && foreignNumber!.isNotEmpty) 'foreign_number': foreignNumber,
      if (occupation != null && occupation!.isNotEmpty) 'occupation': occupation,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (age != null) 'age': age,
      if (reference != null && reference!.isNotEmpty)
        'reference': reference,
      if (howDidYouHear != null && howDidYouHear!.isNotEmpty)
        'how_did_you_hear': howDidYouHear,
      if (personalNotes != null && personalNotes!.isNotEmpty)
        'personal_notes': personalNotes,
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

  PatientModel copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? patientId,
    String? photo,
    String? dateOfBirth,
    String? address,
    String? city,
    String? area,
    String? pincode,
    String? emergencyContact,
    String? allergiesConditions,
    String? doctorId,
    String? clinicId,
    String? gender,
    String? nationality,
    String? foreignNumber,
    String? occupation,
    String? email,
    int? age,
    String? reference,
    String? howDidYouHear,
    String? personalNotes,
    String? relationToPrimary,
    bool? consentGiven,
    String? consentDate,
    bool? privacyPolicyAccepted,
    String? privacyPolicyAcceptedDate,
    DateTime? created,
    DateTime? updated,
    bool? requiresPatientDetailsUpdate,
  }) {
    return PatientModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      patientId: patientId ?? this.patientId,
      photo: photo ?? this.photo,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      city: city ?? this.city,
      area: area ?? this.area,
      pincode: pincode ?? this.pincode,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      allergiesConditions: allergiesConditions ?? this.allergiesConditions,
      doctorId: doctorId ?? this.doctorId,
      clinicId: clinicId ?? this.clinicId,
      gender: gender ?? this.gender,
      nationality: nationality ?? this.nationality,
      foreignNumber: foreignNumber ?? this.foreignNumber,
      occupation: occupation ?? this.occupation,
      email: email ?? this.email,
      age: age ?? this.age,
      reference: reference ?? this.reference,
      howDidYouHear: howDidYouHear ?? this.howDidYouHear,
      personalNotes: personalNotes ?? this.personalNotes,
      relationToPrimary: relationToPrimary ?? this.relationToPrimary,
      consentGiven: consentGiven ?? this.consentGiven,
      consentDate: consentDate ?? this.consentDate,
      privacyPolicyAccepted: privacyPolicyAccepted ?? this.privacyPolicyAccepted,
      privacyPolicyAcceptedDate: privacyPolicyAcceptedDate ?? this.privacyPolicyAcceptedDate,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      requiresPatientDetailsUpdate: requiresPatientDetailsUpdate ?? this.requiresPatientDetailsUpdate,
    );
  }
}
