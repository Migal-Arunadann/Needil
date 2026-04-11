import 'package:pocketbase/pocketbase.dart';
import '../constants/pb_collections.dart';
import '../../features/appointments/models/appointment_model.dart';
import '../../features/patients/models/patient_model.dart';
import '../../features/consultations/models/consultation_model.dart';

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
    String? city,
    String? area,
    String? address,
    String? pincode,
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
      if (city != null && city.isNotEmpty) 'city': city,
      if (area != null && area.isNotEmpty) 'area': area,
      if (address != null && address.isNotEmpty) 'address': address,
      if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
      if (emergencyContact != null && emergencyContact.isNotEmpty)
        'emergency_contact': emergencyContact,
      if (allergiesConditions != null && allergiesConditions.isNotEmpty)
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

  /// Check if a scheduled appointment already exists for this phone + doctor on a specific date.
  /// Only warns about double-booking on the SAME date. Different dates are freely allowed.
  Future<AppointmentModel?> findExistingAppointment(String phone, String doctorId, {required String date}) async {
    try {
      final result = await pb.collection(PBCollections.appointments).getList(
        filter: 'patient_phone = "$phone" && doctor = "$doctorId" && status = "scheduled" && date = "$date"',
        perPage: 1,
        sort: 'time',
      );
      if (result.items.isNotEmpty) {
        return AppointmentModel.fromRecord(result.items.first);
      }
    } catch (_) {}
    return null;
  }

  /// Check if an appointment with this phone number already exists today (any status except cancelled),
  /// used to prevent creating a second consultation for the same patient under a different name.
  Future<AppointmentModel?> findAnyActiveTodayByPhone(String phone, String doctorId) async {
    try {
      final today = _todayString();
      final result = await pb.collection(PBCollections.appointments).getList(
        filter: 'patient_phone = "$phone" && doctor = "$doctorId" && date = "$today" && status != "cancelled"',
        perPage: 1,
        sort: '-created',
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

  /// Mark a SESSION appointment as arrived: sets appointment status = waiting.
  /// The session does NOT start until startSession() is called.
  Future<AppointmentModel> markSessionArrived(String appointmentId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'waiting',
        'check_in_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return AppointmentModel.fromRecord(record);
  }

  /// Start the session: sets appointment status = in_progress,
  /// syncs the linked session record to in_progress.
  Future<AppointmentModel> startSession(String appointmentId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {'status': 'in_progress'},
    );
    final appt = AppointmentModel.fromRecord(record);
    if (appt.patientId != null) {
      try {
        final sessions = await pb.collection(PBCollections.sessions).getList(
          filter:
              'patient = "${appt.patientId}" && doctor = "${appt.doctorId}" && scheduled_date = "${appt.date}" && scheduled_time = "${appt.time}" && (status = "upcoming" || status = "in_progress")',
          perPage: 1,
        );
        if (sessions.items.isNotEmpty) {
          await pb.collection(PBCollections.sessions).update(
            sessions.items.first.id,
            body: {
              'status': 'in_progress',
              'check_in_time': DateTime.now().toUtc().toIso8601String(),
            },
          );
        }
      } catch (_) {}
    }
    return appt;
  }

  /// Mark a SESSION appointment as ended: sets appointment + session to completed.
  Future<AppointmentModel> markSessionEnded(String appointmentId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'completed',
        'check_out_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
    final appt = AppointmentModel.fromRecord(record);
    // Sync the session record to completed
    if (appt.patientId != null) {
      try {
        final sessions = await pb.collection(PBCollections.sessions).getList(
          filter:
              'patient = "${appt.patientId}" && doctor = "${appt.doctorId}" && scheduled_date = "${appt.date}" && scheduled_time = "${appt.time}" && (status = "upcoming" || status = "in_progress")',
          perPage: 1,
        );
        if (sessions.items.isNotEmpty) {
          await pb.collection(PBCollections.sessions).update(
            sessions.items.first.id,
            body: {
              'status': 'completed',
              'check_out_time': DateTime.now().toUtc().toIso8601String(),
            },
          );
        }
      } catch (_) {}
    }
    return appt;
  }

  /// Look up the session record linked to a session appointment.
  /// Returns null if not found.
  Future<Map<String, String>?> findSessionForAppointment(AppointmentModel apt) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) return null;
    try {
      final sessions = await pb.collection(PBCollections.sessions).getList(
        filter:
            'patient = "${apt.patientId}" && doctor = "${apt.doctorId}" && scheduled_date = "${apt.date}" && scheduled_time = "${apt.time}"',
        perPage: 1,
      );
      if (sessions.items.isNotEmpty) {
        final s = sessions.items.first;
        return {
          'sessionId': s.id,
          'treatmentPlanId': s.getStringValue('treatment_plan'),
          'consultationId': s.getStringValue('consultation'),
        };
      }
    } catch (_) {}
    return null;
  }

  /// Reschedule a SESSION appointment AND sync the matching session record.
  Future<AppointmentModel> rescheduleSessionAppointment(
      String appointmentId, AppointmentModel apt, String newDate, String newTime) async {
    // Update appointment first
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {'date': newDate, 'time': newTime},
    );
    // Sync the linked sessions record
    if (apt.patientId != null) {
      try {
        final sessions = await pb.collection(PBCollections.sessions).getList(
          filter:
              'patient = "${apt.patientId}" && doctor = "${apt.doctorId}" && scheduled_date = "${apt.date}" && scheduled_time = "${apt.time}" && status = "upcoming"',
          perPage: 1,
        );
        for (final s in sessions.items) {
          await pb.collection(PBCollections.sessions).update(s.id, body: {
            'scheduled_date': newDate,
            'scheduled_time': newTime,
          });
        }
      } catch (_) {}
    }
    return AppointmentModel.fromRecord(record);
  }

  /// Reschedule a regular (consultation) appointment to a new date and time.
  Future<AppointmentModel> rescheduleAppointment(String appointmentId, String newDate, String newTime) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {'date': newDate, 'time': newTime},
    );
    return AppointmentModel.fromRecord(record);
  }

  /// Undo arrived — reset status to scheduled, clear check_in_time.
  Future<AppointmentModel> undoArrived(String appointmentId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'scheduled',
        'check_in_time': '',
      },
    );
    return AppointmentModel.fromRecord(record);
  }

  /// Find an ongoing consultation for a patient + doctor.
  Future<ConsultationModel?> findOngoingConsultation(String patientId, String doctorId) async {
    try {
      final result = await pb.collection(PBCollections.consultations).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" && status = "ongoing"',
        perPage: 1,
        sort: '-created',
        expand: 'patient',
      );
      if (result.items.isNotEmpty) {
        return ConsultationModel.fromRecord(result.items.first);
      }
    } catch (_) {}
    return null;
  }

  /// Create a new consultation (ongoing status).
  Future<ConsultationModel> createConsultation(String patientId, String doctorId) async {
    final record = await pb.collection(PBCollections.consultations).create(
      body: {
        'patient': patientId,
        'doctor': doctorId,
        'status': 'ongoing',
        'consent_given': true,
      },
    );
    return ConsultationModel.fromRecord(record);
  }

  /// Set the consultation_start_time on an appointment.
  Future<void> setConsultationStartTime(String appointmentId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'consultation_start_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Mark consultation_form_saved = true on an appointment, so the card
  /// shows "Create Plan" + "End Consultation" and blocks re-opening the form.
  Future<void> markConsultationFormSaved(String appointmentId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {'consultation_form_saved': true},
    );
  }

  /// Check if the consultation linked to this appointment's patient is completed.
  Future<bool> isConsultationCompleted(String patientId, String doctorId) async {
    try {
      final result = await pb.collection(PBCollections.consultations).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" && status = "ongoing"',
        perPage: 1,
      );
      // If there's no ongoing consultation, it means it's been completed (or never created)
      return result.items.isEmpty;
    } catch (_) {}
    return false;
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// For an in-progress consultation appointment, returns the ongoing consultation id
  /// and whether a treatment plan already exists for it.
  /// Returns null if no ongoing consultation is found.
  Future<Map<String, dynamic>?> getConsultationPlanInfo(
      String patientId, String doctorId) async {
    try {
      final result = await pb.collection(PBCollections.consultations).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" && status = "ongoing"',
        perPage: 1,
        sort: '-created',
      );
      if (result.items.isEmpty) return null;
      final consultationId = result.items.first.id;

      // Check if there's already a treatment plan for this consultation
      bool hasPlan = false;
      try {
        final plans = await pb.collection(PBCollections.treatmentPlans).getList(
          filter: 'consultation = "$consultationId"',
          perPage: 1,
        );
        hasPlan = plans.items.isNotEmpty;
      } catch (_) {}

      return {'consultationId': consultationId, 'hasPlan': hasPlan};
    } catch (_) {}
    return null;
  }
}

