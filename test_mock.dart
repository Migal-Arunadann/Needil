import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';
import 'lib/features/auth/models/doctor_model.dart';

void main() {
  final scheduleJson = [
    {
      "day": "Monday",
      "start": "09:00",
      "end": "17:00",
      "breaks": [
        {"start": "13:00", "end": "14:00"}
      ]
    }
  ];

  final record = RecordModel(
    id: "test",
    collectionId: "coll",
    collectionName: "doctors",
    data: {
      "name": "Dr Test",
      "age": 30,
      "username": "dr_test",
      "working_schedule": scheduleJson,
      "treatments": []
    }
  );

  try {
    final doc = DoctorModel.fromRecord(record);
    print('Doc breaks on Monday: ${doc.workingSchedule.first.breaks}');
  } catch (e, st) {
    print('Error: $e');
    print(st);
  }
}
