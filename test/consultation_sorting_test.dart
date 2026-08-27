import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/features/consultations/models/consultation_model.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';

void main() {
  group('Consultation Sorting Tests', () {
    test('ConsultationModel.fromRecord reliably extracts created timestamp', () {
      final record = RecordModel({
        'id': 'c1',
        'created': '2026-08-20 10:00:00.000Z',
        'updated': '2026-08-20 10:00:00.000Z',
        'collectionId': 'consultations',
        'collectionName': 'consultations',
        'patient': 'p1',
        'doctor': 'd1',
      });

      final model = ConsultationModel.fromRecord(record);
      expect(model.id, 'c1');
      expect(model.created, isNotNull);
      expect(model.created!.year, 2026);
      expect(model.created!.month, 8);
      expect(model.created!.day, 20);
    });

    test('Consultations sort in descending order with newest on top', () {
      final cOld = ConsultationModel(
        id: 'c_old',
        patientId: 'p1',
        doctorId: 'd1',
        created: DateTime(2026, 1, 15, 10, 0),
      );

      final cMid = ConsultationModel(
        id: 'c_mid',
        patientId: 'p1',
        doctorId: 'd1',
        created: DateTime(2026, 5, 20, 14, 30),
      );

      final cNew = ConsultationModel(
        id: 'c_new',
        patientId: 'p1',
        doctorId: 'd1',
        created: DateTime(2026, 8, 23, 16, 45),
      );

      final list = [cOld, cNew, cMid];

      DateTime getTimestamp(ConsultationModel c) {
        return c.created ?? c.updated ?? DateTime(0);
      }

      list.sort((a, b) => getTimestamp(b).compareTo(getTimestamp(a)));

      expect(list[0].id, 'c_new');
      expect(list[1].id, 'c_mid');
      expect(list[2].id, 'c_old');
    });

    test('Fallback to appointment date works when consultation.created is absent', () {
      final cWithoutCreated = ConsultationModel(
        id: 'c_apt',
        patientId: 'p1',
        doctorId: 'd1',
      );

      final apt = AppointmentModel(
        id: 'a1',
        patientId: 'p1',
        doctorId: 'd1',
        clinicId: 'cl1',
        type: AppointmentType.callBy,
        status: AppointmentStatus.completed,
        date: '2026-08-22',
        time: '11:00',
      );

      final cOlder = ConsultationModel(
        id: 'c_older',
        patientId: 'p1',
        doctorId: 'd1',
        created: DateTime(2026, 8, 10),
      );

      DateTime getEntryTimestamp(ConsultationModel c, AppointmentModel? a) {
        if (c.created != null) return c.created!;
        if (a?.date != null && a!.date.isNotEmpty) {
          final dt = DateTime.tryParse(a!.date);
          if (dt != null) return dt;
        }
        if (c.updated != null) return c.updated!;
        return DateTime(0);
      }

      final items = [
        (cOlder, null as AppointmentModel?),
        (cWithoutCreated, apt as AppointmentModel?),
      ];

      items.sort((a, b) => getEntryTimestamp(b.$1, b.$2).compareTo(getEntryTimestamp(a.$1, a.$2)));

      expect(items[0].$1.id, 'c_apt');
      expect(items[1].$1.id, 'c_older');
    });
  });
}
