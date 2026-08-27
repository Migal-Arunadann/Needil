import 'package:flutter_test/flutter_test.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pocketbase/pocketbase.dart';

void main() {
  group('AppointmentModel ageGenderDisplay tests', () {
    test('displays age and gender code correctly for Male', () {
      final apt = AppointmentModel(
        id: 'apt1',
        doctorId: 'doc1',
        type: AppointmentType.callBy,
        date: '2026-08-23',
        time: '10:00',
        status: AppointmentStatus.scheduled,
        expandedPatientAge: 34,
        expandedPatientGender: 'Male',
      );

      expect(apt.ageGenderDisplay, '34M');
    });

    test('displays age and gender code correctly for Female', () {
      final apt = AppointmentModel(
        id: 'apt2',
        doctorId: 'doc1',
        type: AppointmentType.callBy,
        date: '2026-08-23',
        time: '10:30',
        status: AppointmentStatus.scheduled,
        expandedPatientAge: 28,
        expandedPatientGender: 'Female',
      );

      expect(apt.ageGenderDisplay, '28F');
    });

    test('displays age and gender code correctly for Other', () {
      final apt = AppointmentModel(
        id: 'apt3',
        doctorId: 'doc1',
        type: AppointmentType.callBy,
        date: '2026-08-23',
        time: '11:00',
        status: AppointmentStatus.scheduled,
        expandedPatientAge: 45,
        expandedPatientGender: 'Other',
      );

      expect(apt.ageGenderDisplay, '45O');
    });

    test('calculates age from DOB when expandedPatientAge is null', () {
      final now = DateTime.now();
      final birthYear = now.year - 25;
      final dobStr = '$birthYear-01-01';

      final apt = AppointmentModel(
        id: 'apt4',
        doctorId: 'doc1',
        type: AppointmentType.callBy,
        date: '2026-08-23',
        time: '11:30',
        status: AppointmentStatus.scheduled,
        expandedPatientDob: dobStr,
        expandedPatientGender: 'Male',
      );

      expect(apt.ageGenderDisplay, '25M');
    });

    test('displays only age when gender is null', () {
      final apt = AppointmentModel(
        id: 'apt5',
        doctorId: 'doc1',
        type: AppointmentType.callBy,
        date: '2026-08-23',
        time: '12:00',
        status: AppointmentStatus.scheduled,
        expandedPatientAge: 34,
      );

      expect(apt.ageGenderDisplay, '34');
    });

    test('displays only gender when age is null', () {
      final apt = AppointmentModel(
        id: 'apt6',
        doctorId: 'doc1',
        type: AppointmentType.callBy,
        date: '2026-08-23',
        time: '12:30',
        status: AppointmentStatus.scheduled,
        expandedPatientGender: 'Female',
      );

      expect(apt.ageGenderDisplay, 'F');
    });

    test('returns null when neither age nor gender is available', () {
      final apt = AppointmentModel(
        id: 'apt7',
        doctorId: 'doc1',
        type: AppointmentType.callBy,
        date: '2026-08-23',
        time: '13:00',
        status: AppointmentStatus.scheduled,
      );

      expect(apt.ageGenderDisplay, isNull);
    });

    test('correctly extracts demographics in fromRecord with Map expand', () {
      final record = RecordModel({
        'id': 'rec1',
        'doctor': 'doc1',
        'patient': 'pat1',
        'type': 'walk_in',
        'date': '2026-08-23',
        'time': '14:00',
        'status': 'scheduled',
        'expand': {
          'patient': {
            'id': 'pat1',
            'full_name': 'Ravi Kumar',
            'phone': '9876543210',
            'age': 34,
            'gender': 'Male',
          },
          'doctor': {
            'id': 'doc1',
            'name': 'Dr. Sharma',
          }
        }
      });

      final apt = AppointmentModel.fromRecord(record);
      expect(apt.displayName, 'Ravi Kumar');
      expect(apt.expandedPatientAge, 34);
      expect(apt.expandedPatientGender, 'Male');
      expect(apt.ageGenderDisplay, '34M');
    });
  });
}
