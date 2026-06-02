import 'package:pocketbase/pocketbase.dart';
import '../models/patient_model.dart';
import '../../../core/constants/pb_collections.dart';

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
}
