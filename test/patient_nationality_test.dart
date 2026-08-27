import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';

void main() {
  group('PatientModel Nationality and Foreign Number Tests', () {
    test('Defaults nationality to India and foreignNumber to null when not specified', () {
      final patient = PatientModel(
        id: 'pat-1',
        fullName: 'Aarav Patel',
        phone: '+919876543210',
        doctorId: 'doc-1',
      );

      expect(patient.nationality, 'India');
      expect(patient.foreignNumber, isNull);
    });

    test('Explicit nationality and foreignNumber are stored correctly in model', () {
      final patient = PatientModel(
        id: 'pat-2',
        fullName: 'John Doe',
        phone: '+919876543210',
        doctorId: 'doc-1',
        nationality: 'United States',
        foreignNumber: '+1 555-0199',
      );

      expect(patient.nationality, 'United States');
      expect(patient.foreignNumber, '+1 555-0199');
    });

    test('toJson contains nationality and foreign_number when provided', () {
      final patient = PatientModel(
        id: 'pat-3',
        fullName: 'Sarah Jenkins',
        phone: '+919876543210',
        doctorId: 'doc-1',
        nationality: 'United Kingdom',
        foreignNumber: '+44 7911 123456',
      );

      final json = patient.toJson();
      expect(json['nationality'], 'United Kingdom');
      expect(json['foreign_number'], '+44 7911 123456');
    });

    test('toJson contains nationality as India and omits foreign_number when empty', () {
      final patient = PatientModel(
        id: 'pat-4',
        fullName: 'Priya Sharma',
        phone: '+919876543210',
        doctorId: 'doc-1',
      );

      final json = patient.toJson();
      expect(json['nationality'], 'India');
      expect(json.containsKey('foreign_number'), isFalse);
    });

    test('copyWith updates nationality and foreignNumber correctly', () {
      final patient = PatientModel(
        id: 'pat-5',
        fullName: 'Ravi Kumar',
        phone: '+919876543210',
        doctorId: 'doc-1',
      );

      final updated = patient.copyWith(
        nationality: 'United Arab Emirates',
        foreignNumber: '+971 50 123 4567',
      );

      expect(updated.nationality, 'United Arab Emirates');
      expect(updated.foreignNumber, '+971 50 123 4567');
      expect(updated.fullName, 'Ravi Kumar');
    });

    test('fromRecord parses nationality and foreign_number correctly from RecordModel', () {
      final record = RecordModel({
        'id': 'rec-1',
        'created': '2026-08-23 10:00:00.000Z',
        'updated': '2026-08-23 10:00:00.000Z',
        'collectionId': 'patients_col',
        'collectionName': 'patients',
        'full_name': 'David Miller',
        'phone': '+919876543210',
        'doctor': 'doc-1',
        'nationality': 'Canada',
        'foreign_number': '+1 416-555-0143',
      });

      final patient = PatientModel.fromRecord(record);
      expect(patient.id, 'rec-1');
      expect(patient.fullName, 'David Miller');
      expect(patient.nationality, 'Canada');
      expect(patient.foreignNumber, '+1 416-555-0143');
    });

    test('fromRecord falls back to India when nationality field is empty or missing in RecordModel', () {
      final record = RecordModel({
        'id': 'rec-2',
        'created': '2026-08-23 10:00:00.000Z',
        'updated': '2026-08-23 10:00:00.000Z',
        'collectionId': 'patients_col',
        'collectionName': 'patients',
        'full_name': 'Vikram Singh',
        'phone': '+919876543210',
        'doctor': 'doc-1',
      });

      final patient = PatientModel.fromRecord(record);
      expect(patient.nationality, 'India');
      expect(patient.foreignNumber, isNull);
    });
  });
}
