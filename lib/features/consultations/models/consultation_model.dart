import 'package:pocketbase/pocketbase.dart';

enum ConsultationStatus { ongoing, completed }

class ConsultationModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String? notes; // Legacy field
  final ConsultationStatus status;
  
  // Conversational / Medical
  final String? chiefComplaint;
  final String? medicalHistory;
  final String? pastIllnesses;
  final String? currentMedications;
  final String? allergies;
  final String? chronicDiseases;
  
  // Lifestyle & Habits
  final String? dietPattern;
  final String? sleepQuality;
  final String? exerciseLevel;
  final String? addictions;
  final String? stressLevel;
  
  // Consent
  final String? pregnancyStatus;
  final bool consentGiven;

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
    this.status = ConsultationStatus.ongoing,
    this.chiefComplaint,
    this.medicalHistory,
    this.pastIllnesses,
    this.currentMedications,
    this.allergies,
    this.chronicDiseases,
    this.dietPattern,
    this.sleepQuality,
    this.exerciseLevel,
    this.addictions,
    this.stressLevel,
    this.pregnancyStatus,
    this.consentGiven = true,
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
    try {
      final dynExpand = record.data['expand'];
      if (dynExpand != null && dynExpand is Map) {
        final pat = dynExpand['patient'];
        if (pat != null && pat is Map) {
          patientName = pat['full_name'] as String?;
        }
      }
    } catch (_) {}

    return ConsultationModel(
      id: record.id,
      patientId: record.getStringValue('patient'),
      doctorId: record.getStringValue('doctor'),
      notes: record.getStringValue('notes'),
      status: _parseStatus(record.getStringValue('status')),
      chiefComplaint: record.getStringValue('chief_complaint'),
      medicalHistory: record.getStringValue('medical_history'),
      pastIllnesses: record.getStringValue('past_illnesses'),
      currentMedications: record.getStringValue('current_medications'),
      allergies: record.getStringValue('allergies'),
      chronicDiseases: record.getStringValue('chronic_diseases'),
      dietPattern: record.getStringValue('diet_pattern'),
      sleepQuality: record.getStringValue('sleep_quality'),
      exerciseLevel: record.getStringValue('exercise_level'),
      addictions: record.getStringValue('addictions'),
      stressLevel: record.getStringValue('stress_level'),
      pregnancyStatus: record.getStringValue('pregnancy_status'),
      consentGiven: record.getBoolValue('consent_given'),
      bpLevel: record.getStringValue('bp_level'),
      pulse: record.getIntValue('pulse'),
      charged: record.getBoolValue('charged'),
      chargeAmount: record.getDoubleValue('charge_amount'),
      photos: record.getListValue<String>('photos'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
      patientName: patientName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient': patientId,
      'doctor': doctorId,
      'status': statusToString(status),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (chiefComplaint != null && chiefComplaint!.isNotEmpty) 'chief_complaint': chiefComplaint,
      if (medicalHistory != null && medicalHistory!.isNotEmpty) 'medical_history': medicalHistory,
      if (pastIllnesses != null && pastIllnesses!.isNotEmpty) 'past_illnesses': pastIllnesses,
      if (currentMedications != null && currentMedications!.isNotEmpty) 'current_medications': currentMedications,
      if (allergies != null && allergies!.isNotEmpty) 'allergies': allergies,
      if (chronicDiseases != null && chronicDiseases!.isNotEmpty) 'chronic_diseases': chronicDiseases,
      if (dietPattern != null && dietPattern!.isNotEmpty) 'diet_pattern': dietPattern,
      if (sleepQuality != null && sleepQuality!.isNotEmpty) 'sleep_quality': sleepQuality,
      if (exerciseLevel != null && exerciseLevel!.isNotEmpty) 'exercise_level': exerciseLevel,
      if (addictions != null && addictions!.isNotEmpty) 'addictions': addictions,
      if (stressLevel != null && stressLevel!.isNotEmpty) 'stress_level': stressLevel,
      if (pregnancyStatus != null && pregnancyStatus!.isNotEmpty) 'pregnancy_status': pregnancyStatus,
      'consent_given': consentGiven,
      if (bpLevel != null && bpLevel!.isNotEmpty) 'bp_level': bpLevel,
      if (pulse != null) 'pulse': pulse,
      'charged': charged,
      if (chargeAmount != null) 'charge_amount': chargeAmount,
    };
  }

  static ConsultationStatus _parseStatus(String s) {
    if (s == 'completed') return ConsultationStatus.completed;
    return ConsultationStatus.ongoing;
  }

  static String statusToString(ConsultationStatus s) {
    if (s == ConsultationStatus.completed) return 'completed';
    return 'ongoing';
  }
}
