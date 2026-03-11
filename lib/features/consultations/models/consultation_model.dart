import 'package:pocketbase/pocketbase.dart';

class ConsultationModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String? notes;
  final String? bpLevel;
  final int? pulse;
  final bool charged;
  final double? chargeAmount;
  final List<String> photos;
  final DateTime? created;
  final DateTime? updated;

  // Expanded
  final String? patientName;

  ConsultationModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    this.notes,
    this.bpLevel,
    this.pulse,
    this.charged = false,
    this.chargeAmount,
    this.photos = const [],
    this.created,
    this.updated,
    this.patientName,
  });

  factory ConsultationModel.fromRecord(RecordModel record) {
    String? patientName;
    final expandData = record.get<Map<String, dynamic>>('expand');
    if (expandData.isNotEmpty && expandData.containsKey('patient')) {
      final pat = expandData['patient'];
      if (pat is Map) patientName = pat['full_name'] as String?;
    }

    return ConsultationModel(
      id: record.id,
      patientId: record.getStringValue('patient'),
      doctorId: record.getStringValue('doctor'),
      notes: record.getStringValue('notes'),
      bpLevel: record.getStringValue('bp_level'),
      pulse: record.getIntValue('pulse'),
      charged: record.getBoolValue('charged'),
      chargeAmount: record.getDoubleValue('charge_amount'),
      photos: record.getListValue<String>('photos'),
      created: DateTime.tryParse(record.get<String>('created')),
      updated: DateTime.tryParse(record.get<String>('updated')),
      patientName: patientName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient': patientId,
      'doctor': doctorId,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (bpLevel != null && bpLevel!.isNotEmpty) 'bp_level': bpLevel,
      if (pulse != null) 'pulse': pulse,
      'charged': charged,
      if (chargeAmount != null) 'charge_amount': chargeAmount,
    };
  }
}
