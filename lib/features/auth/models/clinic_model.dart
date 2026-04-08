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
    this.phone,
    this.address,
    this.area,
    this.city,
    this.state,
    this.pin,
    this.location,
    this.logoUrl,
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
    };
  }
}
