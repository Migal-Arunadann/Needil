import 'package:pocketbase/pocketbase.dart';
import '../../../core/providers/pocketbase_provider.dart';

class ClinicModel {
  final String id;
  final String name;
  final String username;
  final String? email;
  final int bedCount;
  final String clinicId; // Unique code for doctor joining
  final bool verified;
  // Contact & location fields
  final String? phone;
  final String? address;
  final String? area;
  final String? city;
  final String? state;
  final String? pin;
  final String? location;
  final String? logoUrl;
  // Patient ID prefix
  final String? patientIdPrefix;  // e.g., "HSK" → generates HSK-001, HSK-002
  // Subscription & photo quota
  final String subscriptionTier;
  final int photosUsed;
  final int photoLimit;
  // Soft-delete / superadmin deactivation
  final bool isDeactivated;
  final DateTime? deactivatedAt;
  final DateTime? scheduledDeletionDate;
  // Clinic self-deletion (30-day retention)
  final String status; // 'active' | 'pending_deletion'
  final DateTime? deletionRequestedAt;
  final DateTime? purgeAt;
  final String? deletionRequestedBy;
  final String? deletionReason;
  final DateTime? created;
  final DateTime? updated;

  /// True when clinic has self-requested deletion and is in 30-day grace period.
  bool get isPendingDeletion => status == 'pending_deletion';

  /// Days remaining until automatic purge (0 if already past).
  int get daysUntilPurge {
    if (purgeAt == null) return 30;
    return purgeAt!.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  ClinicModel({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    required this.bedCount,
    required this.clinicId,
    this.verified = false,
    this.phone,
    this.address,
    this.area,
    this.city,
    this.state,
    this.pin,
    this.location,
    this.logoUrl,
    this.patientIdPrefix,
    this.subscriptionTier = 'base',
    this.photosUsed = 0,
    this.photoLimit = 2000,
    this.isDeactivated = false,
    this.deactivatedAt,
    this.scheduledDeletionDate,
    this.status = 'active',
    this.deletionRequestedAt,
    this.purgeAt,
    this.deletionRequestedBy,
    this.deletionReason,
    this.created,
    this.updated,
  });

  factory ClinicModel.fromRecord(RecordModel record) {
    // Build logo URL if field is present
    final logoFile = record.getStringValue('logo');
    String? logoUrl;
    if (logoFile.isNotEmpty) {
      logoUrl = '$pbBaseUrl/api/files/${record.collectionId}/${record.id}/$logoFile';
    }

    return ClinicModel(
      id: record.id,
      name: record.getStringValue('name'),
      username: record.getStringValue('username'),
      email: record.getStringValue('email'),
      bedCount: record.getIntValue('bed_count'),
      clinicId: record.getStringValue('clinic_id'),
      verified: record.getBoolValue('verified'),
      phone: record.getStringValue('phone'),
      address: record.getStringValue('address'),
      area: record.getStringValue('area'),
      city: record.getStringValue('city'),
      state: record.getStringValue('state'),
      pin: record.getStringValue('pin'),
      location: record.getStringValue('location'),
      logoUrl: logoUrl,
      patientIdPrefix: record.getStringValue('patient_id_prefix'),
      subscriptionTier: record.getStringValue('subscription_tier').isNotEmpty
          ? record.getStringValue('subscription_tier')
          : 'base',
      photosUsed: record.getIntValue('photos_used'),
      photoLimit: record.getIntValue('photo_limit') > 0
          ? record.getIntValue('photo_limit')
          : 2000,
      isDeactivated: record.getBoolValue('is_deactivated'),
      deactivatedAt: DateTime.tryParse(record.getStringValue('deactivated_at')),
      scheduledDeletionDate: DateTime.tryParse(record.getStringValue('scheduled_deletion_date')),
      status: record.getStringValue('status').isNotEmpty
          ? record.getStringValue('status')
          : 'active',
      deletionRequestedAt: DateTime.tryParse(record.getStringValue('deletion_requested_at')),
      purgeAt: DateTime.tryParse(record.getStringValue('purge_at')),
      deletionRequestedBy: record.getStringValue('deletion_requested_by'),
      deletionReason: record.getStringValue('deletion_reason'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      if (email != null && email!.isNotEmpty) 'email': email,
      'bed_count': bedCount,
      'clinic_id': clinicId,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (address != null && address!.isNotEmpty) 'address': address,
      if (area != null && area!.isNotEmpty) 'area': area,
      if (city != null && city!.isNotEmpty) 'city': city,
      if (state != null && state!.isNotEmpty) 'state': state,
      if (pin != null && pin!.isNotEmpty) 'pin': pin,
      if (location != null && location!.isNotEmpty) 'location': location,
      if (patientIdPrefix != null && patientIdPrefix!.isNotEmpty) 'patient_id_prefix': patientIdPrefix,
    };
  }
}
