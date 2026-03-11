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
      sort: '-created',
      perPage: 200,
    );
    return result.items.map((r) => PatientModel.fromRecord(r)).toList();
  }

  /// Fetch all patients assigned to a specific doctor.
  Future<List<PatientModel>> getDoctorPatients(String doctorId) async {
    final result = await pb.collection(PBCollections.patients).getList(
      filter: 'doctor = "$doctorId"',
      sort: '-created',
      perPage: 200,
    );
    return result.items.map((r) => PatientModel.fromRecord(r)).toList();
  }
}
