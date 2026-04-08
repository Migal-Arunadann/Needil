import 'package:pocketbase/pocketbase.dart';
import '../../../core/providers/pocketbase_provider.dart';

class ReceptionistModel {
  final String id;
  final String name;
  final String username;
  final String? phone;
  final String clinicId;
  final bool isActive;
  final String receptionistId; // Unique support ID
  final String? photoUrl;
  final DateTime? created;
  final DateTime? updated;

  ReceptionistModel({
    required this.id,
    required this.name,
    required this.username,
    this.phone,
    required this.clinicId,
    this.isActive = true,
    required this.receptionistId,
    this.photoUrl,
    this.created,
    this.updated,
  });

  factory ReceptionistModel.fromRecord(RecordModel record) {
    final photoFile = record.getStringValue('photo');
    String? photoUrl;
    if (photoFile.isNotEmpty) {
      photoUrl =
          '$pbBaseUrl/api/files/${record.collectionId}/${record.id}/$photoFile';
    }

    return ReceptionistModel(
      id: record.id,
      name: record.getStringValue('name'),
      username: record.getStringValue('username'),
      phone: record.getStringValue('phone'),
      clinicId: record.getStringValue('clinic'),
      isActive: record.getBoolValue('is_active'),
      receptionistId: record.getStringValue('receptionist_id'),
      photoUrl: photoUrl,
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      'clinic': clinicId,
      'is_active': isActive,
      'receptionist_id': receptionistId,
    };
  }
}
