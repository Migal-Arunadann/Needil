import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/core/constants/pb_collections.dart';

class PatientService {
  final PocketBase pb;

  PatientService(this.pb);

  /// Fetch all patients for a specific clinic.
  Future<List<PatientModel>> getClinicPatients(String clinicId) async {
    final result = await pb.collection(PBCollections.patients).getList(
      filter: 'clinic = "$clinicId"',
      perPage: 200,
    );
    return result.items.map((r) => PatientModel.fromRecord(r)).toList();
  }

  /// Fetch all patients assigned to a specific doctor.
  Future<List<PatientModel>> getDoctorPatients(String doctorId) async {
    Set<String> patientIds = {};
    try {
      final appointments = await pb.collection(PBCollections.appointments).getFullList(
        filter: 'doctor = "$doctorId"',
        fields: 'patient',
      );
      patientIds = appointments
          .map((a) => a.getStringValue('patient'))
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {}

    String filter = 'doctor = "$doctorId"';
    if (patientIds.isNotEmpty) {
      final idsFilter = patientIds.map((id) => 'id = "$id"').join(' || ');
      filter = '($filter) || ($idsFilter)';
    }

    final result = await pb.collection(PBCollections.patients).getList(
      filter: filter,
      perPage: 200,
    );
    return result.items.map((r) => PatientModel.fromRecord(r)).toList();
  }

  /// Update an existing patient record.
  Future<PatientModel> updatePatient(String patientId, Map<String, dynamic> body) async {
    final record = await pb.collection(PBCollections.patients).update(patientId, body: body);
    return PatientModel.fromRecord(record);
  }

  /// Fetch the latest completed appointment date for a list of patient IDs.
  Future<Map<String, DateTime>> getLastVisitDates(List<String> patientIds) async {
    if (patientIds.isEmpty) return {};

    final Map<String, DateTime> lastVisits = {};
    const chunkSize = 50;

    for (var i = 0; i < patientIds.length; i += chunkSize) {
      final chunk = patientIds.sublist(i, (i + chunkSize).clamp(0, patientIds.length));
      final idsFilter = chunk.map((id) => 'patient = "$id"').join(' || ');
      final filter = 'status = "completed" && ($idsFilter)';

      try {
        final records = await pb.collection(PBCollections.appointments).getFullList(
          filter: filter,
          sort: '-date,-time',
          fields: 'patient,date',
        );

        for (final r in records) {
          final pId = r.getStringValue('patient');
          final dateStr = r.getStringValue('date');
          if (pId.isNotEmpty && dateStr.isNotEmpty && !lastVisits.containsKey(pId)) {
            final dt = DateTime.tryParse(dateStr);
            if (dt != null) {
              lastVisits[pId] = dt;
            }
          }
        }
      } catch (_) {
        // Continue to the next chunk even if one fails
      }
    }

    return lastVisits;
  }
}
