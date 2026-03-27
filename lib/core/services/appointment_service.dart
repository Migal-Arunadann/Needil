import 'package:pocketbase/pocketbase.dart';
import '../constants/pb_collections.dart';
import '../../features/appointments/models/appointment_model.dart';
import '../../features/patients/models/patient_model.dart';

class AppointmentService {
  final PocketBase pb;

  AppointmentService(this.pb);

  /// Fetch today's appointments for a doctor.
  Future<List<AppointmentModel>> getDoctorAppointments(
    String doctorId, {
    String? dateFilter,
  }) async {
    final date = dateFilter ?? _todayString();
    final result = await pb.collection(PBCollections.appointments).getList(
      filter: 'doctor = "$doctorId" && date = "$date"',
      sort: 'time',
      expand: 'patient,doctor',
    );
    return result.items.map((r) => AppointmentModel.fromRecord(r)).toList();
  }

  /// Fetch appointments for a clinic (all doctors).
  Future<List<AppointmentModel>> getClinicAppointments(
    String clinicId, {
    String? dateFilter,
  }) async {
    final date = dateFilter ?? _todayString();
    final result = await pb.collection(PBCollections.appointments).getList(
      filter: 'clinic = "$clinicId" && date = "$date"',
      sort: 'time',
      expand: 'patient,doctor',
    );
    return result.items.map((r) => AppointmentModel.fromRecord(r)).toList();
  }

  /// Create a call-by appointment (patient info placeholder).
  Future<AppointmentModel> createCallByAppointment({
    required String doctorId,
    String? clinicId,
    required String patientName,
    required String patientPhone,
    required String date,
    required String time,
  }) async {
    final body = {
      'doctor': doctorId,
      if (clinicId != null && clinicId.isNotEmpty) 'clinic': clinicId,
      'type': 'call_by',
      'date': date,
      'time': time,
      'status': 'scheduled',
      'patient_name': patientName,
      'patient_phone': patientPhone,
    };

    final record =
        await pb.collection(PBCollections.appointments).create(body: body);
    return AppointmentModel.fromRecord(record);
  }

  /// Create a walk-in appointment (auto assigns current time).
  Future<AppointmentModel> createWalkInAppointment({
    required String doctorId,
    String? clinicId,
    required String date,
    required String time,
    String? patientName,
    String? patientPhone,
    String? patientId,
  }) async {
    final body = {
      'doctor': doctorId,
      if (clinicId != null && clinicId.isNotEmpty) 'clinic': clinicId,
      'type': 'walk_in',
      'date': date,
      'time': time,
      'status': 'in_progress',
      'check_in_time': DateTime.now().toUtc().toIso8601String(),
      if (patientName != null && patientName.isNotEmpty)
        'patient_name': patientName,
      if (patientPhone != null && patientPhone.isNotEmpty)
        'patient_phone': patientPhone,
      if (patientId != null && patientId.isNotEmpty)
        'patient': patientId,
    };

    final record =
        await pb.collection(PBCollections.appointments).create(body: body);
    return AppointmentModel.fromRecord(record);
  }

  /// Link a patient record to an appointment (for call-by after patient arrives).
  Future<AppointmentModel> linkPatient(
      String appointmentId, String patientId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'patient': patientId, 
        'status': 'in_progress',
        'check_in_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return AppointmentModel.fromRecord(record);
  }

  /// Update appointment status.
  Future<AppointmentModel> updateStatus(
      String appointmentId, AppointmentStatus status) async {
    final body = <String, dynamic>{
      'status': AppointmentModel.statusToString(status),
    };
    
    if (status == AppointmentStatus.inProgress) {
      body['check_in_time'] = DateTime.now().toUtc().toIso8601String();
    } else if (status == AppointmentStatus.completed) {
      body['check_out_time'] = DateTime.now().toUtc().toIso8601String();
    }

    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: body,
    );
    return AppointmentModel.fromRecord(record);
  }

  /// Create or find a patient record.
  Future<PatientModel> createPatient({
    required String fullName,
    required String phone,
    required String doctorId,
    String? clinicId,
    String? dateOfBirth,
    String? address,
    String? emergencyContact,
    String? allergiesConditions,
    String? gender,
    String? occupation,
    String? email,
    int? age,
  }) async {
    final body = {
      'full_name': fullName,
      'phone': phone,
      'doctor': doctorId,
      if (clinicId != null && clinicId.isNotEmpty) 'clinic': clinicId,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty)
        'date_of_birth': dateOfBirth,
      if (address != null && address.isNotEmpty) 'address': address,
      if (emergencyContact != null && emergencyContact.isNotEmpty)
        'emergency_contact': emergencyContact,
        'allergies_conditions': allergiesConditions,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (occupation != null && occupation.isNotEmpty) 'occupation': occupation,
      if (email != null && email.isNotEmpty) 'email': email,
      if (age != null) 'age': age,
      'consent_given': true,
      'consent_date': _todayString(),
    };

    final record =
        await pb.collection(PBCollections.patients).create(body: body);
    return PatientModel.fromRecord(record);
  }

  /// Search patients by name or phone.
  Future<List<PatientModel>> searchPatients(
      String query, String doctorId) async {
    final result = await pb.collection(PBCollections.patients).getList(
      filter:
          '(full_name ~ "$query" || phone ~ "$query") && doctor = "$doctorId"',
      perPage: 20,
    );
    return result.items.map((r) => PatientModel.fromRecord(r)).toList();
  }

  /// Get all doctors in a clinic (for doctor selection dropdown).
  Future<List<Map<String, String>>> getClinicDoctors(String clinicId) async {
    final result = await pb.collection(PBCollections.doctors).getList(
      filter: 'clinic = "$clinicId"',
      sort: 'name',
    );
    return result.items
        .map((r) => {
              'id': r.id,
              'name': r.getStringValue('name'),
            })
        .toList();
  }

  /// Find an existing patient by phone number for the given doctor.
  Future<PatientModel?> findPatientByPhone(String phone, String doctorId) async {
    try {
      final result = await pb.collection(PBCollections.patients).getList(
        filter: 'phone = "$phone" && doctor = "$doctorId"',
        perPage: 1,
      );
      if (result.items.isNotEmpty) {
        return PatientModel.fromRecord(result.items.first);
      }
    } catch (_) {}
    return null;
  }

  /// Check if a scheduled appointment already exists for this phone + doctor + date.
  Future<AppointmentModel?> findExistingAppointment(String phone, String doctorId, {String? date}) async {
    try {
      final dateFilter = date != null ? ' && date = "$date"' : '';
      final result = await pb.collection(PBCollections.appointments).getList(
        filter: 'patient_phone = "$phone" && doctor = "$doctorId" && status = "scheduled"$dateFilter',
        perPage: 1,
        sort: '-date,-time',
      );
      if (result.items.isNotEmpty) {
        return AppointmentModel.fromRecord(result.items.first);
      }
    } catch (_) {}
    return null;
  }

  /// Mark a patient as arrived (set check_in_time + status to in_progress).
  Future<AppointmentModel> markArrived(String appointmentId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'in_progress',
        'check_in_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return AppointmentModel.fromRecord(record);
  }

  /// Mark appointment as ended (set check_out_time + status to completed).
  Future<AppointmentModel> markEnded(String appointmentId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'completed',
        'check_out_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return AppointmentModel.fromRecord(record);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
