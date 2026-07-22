import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/utils/time_utils.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/consultations/models/consultation_model.dart';
import 'package:pms_app/core/services/session_lifecycle_service.dart';
import 'package:pms_app/core/utils/validators.dart';

class AppointmentService {
  final PocketBase pb;

  AppointmentService(this.pb);

  Future<RecordModel?> _findSessionRecordForAppointment({
    required String patientId,
    required String date,
    required String time,
    required String doctorId,
    String? linkedSessionId,
  }) async {
    // Fast path: appointment already carries the session FK — skip all fuzzy matching
    if (linkedSessionId != null && linkedSessionId.isNotEmpty) {
      try {
        return await pb.collection(PBCollections.sessions).getOne(linkedSessionId);
      } catch (_) {
        // Fall through to fuzzy matching if the record was somehow deleted
      }
    }

    String datePart = date;
    try {
      final dt = DateTime.parse(date);
      datePart = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {}

    final timeCandidates = TimeUtils.generateTimeCandidates(time);
    final timeFilter = timeCandidates.isNotEmpty
        ? timeCandidates.map((t) => 'scheduled_time = "$t"').join(' || ')
        : 'scheduled_time = "$time"';

    // Priority 1: Exact match (date + time candidates) with active status (upcoming, waiting, in_progress)
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& (scheduled_date = "$datePart" || (scheduled_date >= "$datePart 00:00:00.000Z" && scheduled_date <= "$datePart 23:59:59.999Z")) '
            '&& ($timeFilter) && (status = "upcoming" || status = "waiting" || status = "in_progress")',
        perPage: 1,
        sort: 'session_number',
      );
      if (res.items.isNotEmpty) return res.items.first;
    } catch (_) {}

    // Priority 2: Exact match (date + time candidates) with any status
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& scheduled_date >= "$date 00:00:00.000Z" && scheduled_date <= "$date 23:59:59.999Z" '
            '&& ($timeFilter)',
        perPage: 1,
        sort: 'session_number',
      );
      if (res.items.isNotEmpty) return res.items.first;
    } catch (_) {}

    // Priority 3: Date-only match with active status (upcoming, waiting, in_progress)
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& scheduled_date >= "$date 00:00:00.000Z" && scheduled_date <= "$date 23:59:59.999Z" '
            '&& (status = "upcoming" || status = "waiting" || status = "in_progress")',
        perPage: 1,
        sort: 'session_number',
      );
      if (res.items.isNotEmpty) return res.items.first;
    } catch (_) {}

    // Priority 4: Date-only match with any status
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& scheduled_date >= "$date 00:00:00.000Z" && scheduled_date <= "$date 23:59:59.999Z"',
        perPage: 1,
        sort: 'session_number',
      );
      if (res.items.isNotEmpty) return res.items.first;
    } catch (_) {}

    // Priority 5: Patient-doctor match with active status (upcoming, waiting, in_progress), sorted by date, session number
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" '
            '&& (status = "upcoming" || status = "waiting" || status = "in_progress")',
        perPage: 1,
        sort: 'scheduled_date,session_number',
      );
      if (res.items.isNotEmpty) return res.items.first;
    } catch (_) {}

    // Priority 6: Patient-doctor match with any status, sorted by date, session number
    try {
      final res = await pb.collection(PBCollections.sessions).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId"',
        perPage: 1,
        sort: 'scheduled_date,session_number',
      );
      if (res.items.isNotEmpty) return res.items.first;
    } catch (_) {}

    return null;
  }

  /// Fetch today's appointments for a doctor.
  Future<List<AppointmentModel>> getDoctorAppointments(
    String doctorId, {
    String? dateFilter,
  }) async {
    final date = dateFilter ?? _todayString();
    String filter;
    String sortOrder = 'time';
    if (date == 'all') {
      filter = 'doctor = "$doctorId"';
      sortOrder = 'date,time';
    } else if (date.startsWith('range:')) {
      final parts = date.substring(6).split(':');
      final start = parts[0];
      final end = parts[1];
      filter = 'doctor = "$doctorId" && date >= "$start" && date <= "$end"';
      sortOrder = 'date,time';
    } else {
      filter = 'doctor = "$doctorId" && date = "$date"';
    }

    final result = await pb.collection(PBCollections.appointments).getList(
      filter: filter,
      sort: sortOrder,
      expand: 'patient,doctor',
      perPage: 100,
    );
    return result.items.map((r) => AppointmentModel.fromRecord(r)).toList();
  }

  /// Fetch appointments for a clinic (all doctors).
  Future<List<AppointmentModel>> getClinicAppointments(
    String clinicId, {
    String? dateFilter,
  }) async {
    final date = dateFilter ?? _todayString();
    String filter;
    String sortOrder = 'time';
    if (date == 'all') {
      filter = 'clinic = "$clinicId"';
      sortOrder = 'date,time';
    } else if (date.startsWith('range:')) {
      final parts = date.substring(6).split(':');
      final start = parts[0];
      final end = parts[1];
      filter = 'clinic = "$clinicId" && date >= "$start" && date <= "$end"';
      sortOrder = 'date,time';
    } else {
      filter = 'clinic = "$clinicId" && date = "$date"';
    }

    final result = await pb.collection(PBCollections.appointments).getList(
      filter: filter,
      sort: sortOrder,
      expand: 'patient,doctor',
      perPage: 100,
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

  /// Create a walk-in appointment.
  /// Status starts as 'waiting' — patient is present but consultation
  /// has not started yet. startConsultationRecord() moves it to in_progress.
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
      'status': 'waiting',
      'check_in_time': DateTime.now().toUtc().toIso8601String(),
      // Walk-in details are collected upfront in the creation form, so mark as saved immediately
      'patient_details_saved': true,
      'patient_details_partial': false,
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


  /// Link a patient record to an appointment.
  /// [setArrived] — when true (default), also sets status=waiting + check_in_time.
  ///   Pass false when auto-linking at creation time (patient hasn't arrived yet).
  Future<AppointmentModel> linkPatient(
      String appointmentId, String patientId, {bool setArrived = true}) async {
    final body = <String, dynamic>{'patient': patientId};
    if (setArrived) {
      body['status'] = 'waiting';
      body['check_in_time'] = DateTime.now().toUtc().toIso8601String();
    }
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: body,
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
    String? patientId,
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
    String? reference,
    String? howDidYouHear,
    String? relationToPrimary,
    String? photoPath,
    bool consentGiven = true,
    bool privacyPolicyAccepted = false,
  }) async {
    // ── Auto-generate patient ID from clinic prefix ──
    String? resolvedPatientId = patientId;
    if ((resolvedPatientId == null || resolvedPatientId.isEmpty) &&
        clinicId != null && clinicId.isNotEmpty) {
      try {
        final clinicRec = await pb.collection(PBCollections.clinics).getOne(clinicId);
        final prefix = clinicRec.getStringValue('patient_id_prefix');
        if (prefix.isNotEmpty) {
          // Find the highest existing patient_id with this prefix
          int nextNumber = 1;
          try {
            final existing = await pb.collection(PBCollections.patients).getList(
              filter: 'clinic = "$clinicId" && patient_id ~ "$prefix-"',
              sort: '-patient_id',
              perPage: 1,
            );
            if (existing.items.isNotEmpty) {
              final lastId = existing.items.first.getStringValue('patient_id');
              final parts = lastId.split('-');
              if (parts.length >= 2) {
                final lastNum = int.tryParse(parts.last);
                if (lastNum != null) nextNumber = lastNum + 1;
              }
            }
          } catch (_) {}
          resolvedPatientId = '$prefix-${nextNumber.toString().padLeft(3, '0')}';
        }
      } catch (_) {}
    }

    final body = {
      'full_name': fullName,
      'phone': phone,
      'doctor': doctorId,
      if (clinicId != null && clinicId.isNotEmpty) 'clinic': clinicId,
      if (resolvedPatientId != null && resolvedPatientId.isNotEmpty) 'patient_id': resolvedPatientId,
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
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (howDidYouHear != null && howDidYouHear.isNotEmpty)
        'how_did_you_hear': howDidYouHear,
      if (relationToPrimary != null && relationToPrimary.isNotEmpty)
        'relation_to_primary': relationToPrimary,
      'consent_given': consentGiven,
      'consent_date': _todayString(),
      'privacy_policy_accepted': privacyPolicyAccepted,
      if (privacyPolicyAccepted) 'privacy_policy_accepted_date': _todayString(),
    };

    if (photoPath != null && photoPath.isNotEmpty) {
      final files = [
        await http.MultipartFile.fromPath('photo', photoPath),
      ];
      final record = await pb.collection(PBCollections.patients).create(
        body: body,
        files: files,
      );
      return PatientModel.fromRecord(record);
    }

    final record =
        await pb.collection(PBCollections.patients).create(body: body);
    return PatientModel.fromRecord(record);
  }

  /// Search patients by name or phone.
  Future<List<PatientModel>> searchPatients(
      String query, String doctorId, {String? clinicId}) async {
    if (clinicId != null && clinicId.isNotEmpty) {
      final filter = '(full_name ~ "$query" || phone ~ "$query") && clinic = "$clinicId"';
      final result = await pb.collection(PBCollections.patients).getList(
        filter: filter,
        perPage: 20,
      );
      return result.items.map((r) => PatientModel.fromRecord(r)).toList();
    } else {
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

      String patientFilter = 'doctor = "$doctorId"';
      if (patientIds.isNotEmpty) {
        final idsFilter = patientIds.map((id) => 'id = "$id"').join(' || ');
        patientFilter = '($patientFilter) || ($idsFilter)';
      }
      final filter = '(full_name ~ "$query" || phone ~ "$query") && ($patientFilter)';

      final result = await pb.collection(PBCollections.patients).getList(
        filter: filter,
        perPage: 20,
      );
      return result.items.map((r) => PatientModel.fromRecord(r)).toList();
    }
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

  /// Find an existing patient by phone number for the given doctor/clinic.
  /// Returns the first match (primary patient). Use [findAllPatientsByPhone]
  /// to retrieve all family members sharing the same phone.
  Future<PatientModel?> findPatientByPhone(String phone, String doctorId, {String? clinicId}) async {
    final all = await findAllPatientsByPhone(phone, doctorId, clinicId: clinicId);
    return all.isNotEmpty ? all.first : null;
  }

  /// Find ALL patients registered under the same phone number for the given
  /// doctor/clinic. Returns an empty list if none found.
  /// Used by the family-member selection flow.
  ///
  /// Uses getFullList (skipTotal=true) which is compatible with all PocketBase
  /// server versions. Filters by clinic/doctor in Dart after fetching by phone.
  Future<List<PatientModel>> findAllPatientsByPhone(String phone, String doctorId, {String? clinicId}) async {
    try {
      final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final parsed = PhoneParser.parse(clean);
      final countryCode = parsed.$1;
      final nationalNumber = parsed.$2;
      final combinedWithPlus = '$countryCode$nationalNumber';
      final combinedRaw = combinedWithPlus.replaceAll('+', '');

      final filterStr = 'phone = "$phone" || phone = "$combinedWithPlus" || phone = "$combinedRaw" || phone = "$nationalNumber"';

      final all = await pb.collection(PBCollections.patients).getFullList(
        filter: filterStr,
      );
      return all
          .map((rec) => PatientModel.fromRecord(rec))
          .where((p) {
            final belongsToClinic = clinicId != null && clinicId.isNotEmpty && p.clinicId == clinicId;
            final belongsToDoctor = p.doctorId == doctorId;
            return belongsToClinic || belongsToDoctor;
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Check if a scheduled appointment already exists for this phone + doctor today or in the future.
  /// Warns about double-booking if the patient already has an active scheduled appointment today or in the future.
  Future<AppointmentModel?> findExistingAppointment(String phone, String doctorId, {required String date}) async {
    try {
      final today = _todayString();
      final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final parsed = PhoneParser.parse(clean);
      final countryCode = parsed.$1;
      final nationalNumber = parsed.$2;
      final combinedWithPlus = '$countryCode$nationalNumber';
      final combinedRaw = combinedWithPlus.replaceAll('+', '');

      final filterStr = '(patient_phone = "$phone" || patient_phone = "$combinedWithPlus" || patient_phone = "$combinedRaw" || patient_phone = "$nationalNumber") && doctor = "$doctorId" && status = "scheduled" && date >= "$today"';

      final result = await pb.collection(PBCollections.appointments).getList(
        filter: filterStr,
        perPage: 1,
        sort: 'date,time',
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
      final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final parsed = PhoneParser.parse(clean);
      final countryCode = parsed.$1;
      final nationalNumber = parsed.$2;
      final combinedWithPlus = '$countryCode$nationalNumber';
      final combinedRaw = combinedWithPlus.replaceAll('+', '');

      final filterStr = '(patient_phone = "$phone" || patient_phone = "$combinedWithPlus" || patient_phone = "$combinedRaw" || patient_phone = "$nationalNumber") && doctor = "$doctorId" && date = "$today" && status != "cancelled"';

      final result = await pb.collection(PBCollections.appointments).getList(
        filter: filterStr,
        perPage: 1,
      );
      if (result.items.isNotEmpty) {
        return AppointmentModel.fromRecord(result.items.first);
      }
    } catch (_) {}
    return null;
  }

  /// Mark a consultation patient as arrived: sets status = waiting.
  /// The consultation does NOT start until startConsultationRecord() is called.
  Future<AppointmentModel> markArrived(String appointmentId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'waiting',
        'check_in_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return AppointmentModel.fromRecord(record);
  }

  /// Move a consultation appointment from waiting → in_progress
  /// when the doctor clicks Start Consultation.
  Future<AppointmentModel> startConsultationRecord(String appointmentId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'in_progress',
        'consultation_start_time': DateTime.now().toUtc().toIso8601String(),
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
    final appt = AppointmentModel.fromRecord(record);
    if (appt.patientId != null) {
      try {
        final s = await _findSessionRecordForAppointment(
          patientId: appt.patientId!,
          date: appt.date,
          time: appt.time,
          doctorId: appt.doctorId,
          linkedSessionId: appt.linkedSessionId,
        );
        if (s != null) {
          await pb.collection(PBCollections.sessions).update(
            s.id,
            body: {
              'status': 'waiting',
            },
          );
        }
      } catch (_) {}
    }
    return appt;
  }

  /// Start the session: sets appointment status = in_progress,
  /// syncs the linked session record to in_progress.
  Future<AppointmentModel> startSession(String appointmentId) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'in_progress',
        'consultation_start_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
    final appt = AppointmentModel.fromRecord(record);
    if (appt.patientId != null) {
      try {
        final s = await _findSessionRecordForAppointment(
          patientId: appt.patientId!,
          date: appt.date,
          time: appt.time,
          doctorId: appt.doctorId,
          linkedSessionId: appt.linkedSessionId,
        );
        if (s != null) {
          await pb.collection(PBCollections.sessions).update(
            s.id,
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
  Future<AppointmentModel> markSessionEnded(String appointmentId, {String? sessionId}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'completed',
        'check_out_time': now,
        'patient_left_at': now,
      },
    );
    final appt = AppointmentModel.fromRecord(record);
    
    // Sync the session record to completed
    if (sessionId != null && sessionId.isNotEmpty) {
      try {
        await pb.collection(PBCollections.sessions).update(
          sessionId,
          body: {
            'status': 'completed',
            'check_out_time': DateTime.now().toUtc().toIso8601String(),
          },
        );
      } catch (_) {}
    } else if (appt.patientId != null) {
      try {
        final s = await _findSessionRecordForAppointment(
          patientId: appt.patientId!,
          date: appt.date,
          time: appt.time,
          doctorId: appt.doctorId,
          linkedSessionId: appt.linkedSessionId,
        );
        if (s != null) {
          await pb.collection(PBCollections.sessions).update(
            s.id,
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
      final s = await _findSessionRecordForAppointment(
        patientId: apt.patientId!,
        date: apt.date,
        time: apt.time,
        doctorId: apt.doctorId,
        linkedSessionId: apt.linkedSessionId,
      );
      if (s != null) {
        return {
          'sessionId': s.id,
          'treatmentPlanId': s.getStringValue('treatment_plan'),
          'consultationId': s.getStringValue('consultation'),
        };
      }
    } catch (_) {}
    return null;
  }

  /// Reschedule a SESSION appointment AND sync the matching session record
  /// with automatic cascading shifts for subsequent sessions in the plan.
  Future<AppointmentModel> rescheduleSessionAppointment(
      String appointmentId, AppointmentModel apt, String newDate, String newTime) async {
    if (apt.patientId != null) {
      try {
        final s = await _findSessionRecordForAppointment(
          patientId: apt.patientId!,
          date: apt.date,
          time: apt.time,
          doctorId: apt.doctorId,
          linkedSessionId: apt.linkedSessionId,
        );
        if (s != null) {
          final lifecycle = SessionLifecycleService(pb);
          await lifecycle.rescheduleSessionAndCascade(
            sessionId: s.id,
            newDate: newDate,
            newTime: newTime,
          );

          // Return fresh updated appointment record
          final record = await pb.collection(PBCollections.appointments).getOne(appointmentId);
          return AppointmentModel.fromRecord(record);
        }
      } catch (_) {}
    }

    // Fallback: direct update if session record lookup fails
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {'date': newDate, 'time': newTime, 'is_rescheduled': true},
    );
    return AppointmentModel.fromRecord(record);
  }

  /// Reschedule a regular (consultation) appointment to a new date and time.
  Future<AppointmentModel> rescheduleAppointment(String appointmentId, String newDate, String newTime) async {
    final record = await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {'date': newDate, 'time': newTime, 'is_rescheduled': true},
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
    final appt = AppointmentModel.fromRecord(record);
    if (appt.patientId != null) {
      try {
        final s = await _findSessionRecordForAppointment(
          patientId: appt.patientId!,
          date: appt.date,
          time: appt.time,
          doctorId: appt.doctorId,
          linkedSessionId: appt.linkedSessionId,
        );
        if (s != null) {
          await pb.collection(PBCollections.sessions).update(
            s.id,
            body: {
              'status': 'upcoming',
            },
          );
        }
      } catch (_) {}
    }
    return appt;
  }

  /// Get or create a consultation for an appointment — uses getOne() only,
  /// avoiding list queries that fail on this PocketBase configuration.
  ///
  /// Returns (consultationId, isNew).
  Future<(String, bool)> getOrCreateConsultationForAppointment(AppointmentModel apt) async {
    // 1. Appointment already has a linked consultation ID → try getOne to resume
    if (apt.linkedConsultationId != null && apt.linkedConsultationId!.isNotEmpty) {
      try {
        final record = await pb
            .collection(PBCollections.consultations)
            .getOne(apt.linkedConsultationId!);
        final c = ConsultationModel.fromRecord(record);
        // Return regardless of status — ongoing = resume, completed = view only.
        // Never create a second consultation for the same appointment.
        return (c.id, false);
      } catch (_) {
        // Record deleted or unreachable — fall through to create
      }
    }

    // 2. No linked stub → create one and persist its ID back to the appointment
    final consultation = await createConsultation(apt.patientId!, apt.doctorId);
    await saveConsultationToAppointment(apt.id, consultation.id);
    return (consultation.id, true);
  }

  /// Persist the consultation ID onto the appointment record so future
  /// resumes can use getOne() instead of a list query.
  Future<void> saveConsultationToAppointment(
      String appointmentId, String consultationId) async {
    try {
      await pb.collection(PBCollections.appointments).update(
        appointmentId,
        body: {'linked_consultation_id': consultationId},
      );
    } catch (_) {
      // Non-fatal — consultation was created; ID just won't persist
    }
  }

  /// Find an ongoing consultation via list query (used by profile FAB which
  /// has no appointment context). May fail on some PocketBase configs — callers
  /// must handle the null return gracefully.
  Future<ConsultationModel?> findOngoingConsultation(String patientId, String doctorId) async {
    try {
      final list = await pb.collection(PBCollections.consultations).getFullList(
        filter: 'patient = "$patientId"',
      );
      final ongoing = list
          .map((r) => ConsultationModel.fromRecord(r))
          .where((c) => c.status == ConsultationStatus.ongoing && (c.doctorId == doctorId || doctorId.isEmpty))
          .toList();
      if (ongoing.isNotEmpty) {
        return ongoing.first;
      }
    } catch (_) {}
    return null;
  }


  /// Create a new consultation stub.
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

  /// Soft deletes a consultation and its associated treatment plans and sessions.
  Future<void> softDeleteConsultation(String consultationId) async {
    final nowStr = DateTime.now().toUtc().toIso8601String();
    
    // 1. Soft delete the consultation
    await pb.collection(PBCollections.consultations).update(
      consultationId,
      body: {
        'is_deleted': true,
        'deleted_at': nowStr,
      },
    );

    // 2. Find and soft delete associated treatment plans
    try {
      final plans = await pb.collection(PBCollections.treatmentPlans).getList(
        filter: 'consultation = "$consultationId" && is_deleted = false',
      );
      for (final plan in plans.items) {
        await pb.collection(PBCollections.treatmentPlans).update(
          plan.id,
          body: {
            'is_deleted': true,
            'deleted_at': nowStr,
          },
        );

        // 3. Find and soft delete associated sessions for each plan
        try {
          final sessions = await pb.collection(PBCollections.sessions).getList(
            filter: 'treatment_plan = "${plan.id}" && is_deleted = false',
          );
          for (final session in sessions.items) {
            await pb.collection(PBCollections.sessions).update(
              session.id,
              body: {
                'is_deleted': true,
                'deleted_at': nowStr,
              },
            );
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Restores a soft-deleted consultation and its associated treatment plans and sessions.
  Future<void> restoreConsultation(String consultationId) async {
    // 1. Restore the consultation
    await pb.collection(PBCollections.consultations).update(
      consultationId,
      body: {
        'is_deleted': false,
        'deleted_at': null,
      },
    );

    // 2. Find and restore associated treatment plans
    try {
      final plans = await pb.collection(PBCollections.treatmentPlans).getList(
        filter: 'consultation = "$consultationId" && is_deleted = true',
      );
      for (final plan in plans.items) {
        await pb.collection(PBCollections.treatmentPlans).update(
          plan.id,
          body: {
            'is_deleted': false,
            'deleted_at': null,
          },
        );

        // 3. Find and restore associated sessions for each plan
        try {
          final sessions = await pb.collection(PBCollections.sessions).getList(
            filter: 'treatment_plan = "${plan.id}" && is_deleted = true',
          );
          for (final session in sessions.items) {
            await pb.collection(PBCollections.sessions).update(
              session.id,
              body: {
                'is_deleted': false,
                'deleted_at': null,
              },
            );
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Set the consultation_start_time on an appointment and move status to in_progress.
  Future<void> setConsultationStartTime(String appointmentId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'status': 'in_progress',
        'consultation_start_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Mark consultation form as saved by recording the consultation_end_time.
  /// (consultation_form_saved is a computed getter backed by consultationEndTime)
  Future<void> markConsultationFormSaved(String appointmentId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'consultation_end_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Check if the most recent consultation for this patient+doctor is completed
  /// (i.e. chief_complaint has been filled in, meaning the form was submitted).
  Future<bool> isConsultationCompleted(String patientId, String doctorId) async {
    try {
      final result = await pb.collection(PBCollections.consultations).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId"',
        perPage: 1,
        query: {'skipTotal': '1'},
      );
      if (result.items.isEmpty) return false;
      final c = ConsultationModel.fromRecord(result.items.first);
      return c.status == ConsultationStatus.completed;
    } catch (_) {}
    return false;
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// For an in-progress consultation appointment, returns the unfilled consultation id
  /// and whether a treatment plan already exists for it.
  /// Returns null if no unfilled consultation stub is found.
  Future<Map<String, dynamic>?> getConsultationPlanInfo(
      String patientId, String doctorId) async {
    try {
      final result = await pb.collection(PBCollections.consultations).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" && status = "ongoing"',
        perPage: 1,
        query: {'skipTotal': '1'},
      );
      if (result.items.isEmpty) return null;
      final c = ConsultationModel.fromRecord(result.items.first);
      final consultationId = c.id;

      bool hasPlan = false;
      try {
        final plans = await pb.collection(PBCollections.treatmentPlans).getList(
          filter: 'consultation = "$consultationId"',
          perPage: 1,
          query: {'skipTotal': '1'},
        );
        hasPlan = plans.items.isNotEmpty;
      } catch (_) {}

      return {'consultationId': consultationId, 'hasPlan': hasPlan};
    } catch (_) {}
    return null;
  }

  /// Mark that the patient details form has been OPENED but not yet submitted.
  Future<void> markPatientDetailsPartial(String appointmentId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'patient_details_partial': true,
        'patient_details_saved': false,
      },
    );
  }

  /// Mark that the patient details form has been fully submitted.
  Future<void> markPatientDetailsSaved(String appointmentId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'patient_details_saved': true,
        'patient_details_partial': false,
        'patient_details_filled_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Record the consultation end time when the consultation form is submitted.
  Future<void> markConsultationEndTime(String appointmentId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'consultation_end_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Record the consultation start time when start consultation is clicked.
  Future<void> markConsultationStartTime(String appointmentId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'consultation_start_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Mark that the treatment plan form has been opened but not yet submitted.
  Future<void> markTreatmentPlanPartial(String appointmentId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {'treatment_plan_partial': true},
    );
  }

  /// Link a created treatment plan to the appointment and clear the partial flag.
  Future<void> markLinkedPlan(String appointmentId, String planId) async {
    await pb.collection(PBCollections.appointments).update(
      appointmentId,
      body: {
        'linked_treatment_plan_id': planId,
        'treatment_plan_partial': false,
      },
    );
  }

  /// Fetch the treatment plan linked to a given consultation (one-plan guard).
  /// Returns the plan ID if one already exists, null otherwise.
  Future<String?> getExistingPlanForConsultation(String consultationId) async {
    try {
      final plans = await pb.collection(PBCollections.treatmentPlans).getList(
        filter: 'consultation = "$consultationId"',
        perPage: 1,
      );
      if (plans.items.isNotEmpty) return plans.items.first.id;
    } catch (_) {}
    return null;
  }

  /// Look up the session_number for a session-type appointment.
  /// Returns 0 if the session record cannot be found.
  Future<int> getSessionNumberForAppointment(AppointmentModel apt) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) return 0;
    try {
      final s = await _findSessionRecordForAppointment(
        patientId: apt.patientId!,
        date: apt.date,
        time: apt.time,
        doctorId: apt.doctorId,
      );
      if (s != null) {
        return s.getIntValue('session_number');
      }
    } catch (_) {}
    return 0;
  }

  /// Look up session_number AND session_type for a session-type appointment.
  /// Returns {id: String, number: int, type: 'treatment'|'maintenance'} or null.
  Future<Map<String, dynamic>?> getSessionInfoForAppointment(AppointmentModel apt) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) return null;
    try {
      final s = await _findSessionRecordForAppointment(
        patientId: apt.patientId!,
        date: apt.date,
        time: apt.time,
        doctorId: apt.doctorId,
        linkedSessionId: apt.linkedSessionId,
      );
      if (s != null) {
        return {
          'id': s.id,
          'number': s.getIntValue('session_number'),
          'type': s.getStringValue('session_type').isNotEmpty
              ? s.getStringValue('session_type')
              : 'treatment',
        };
      }
    } catch (_) {}
    return null;
  }

  /// Fetch a treatment plan linked to a patient's ongoing consultation, if any.
  /// Returns the plan or null.
  Future<Map<String, dynamic>?> getLinkedTreatmentPlan(String patientId, String doctorId) async {
    try {
      // Find ongoing consultation
      final consRes = await pb.collection(PBCollections.consultations).getList(
        filter: 'patient = "$patientId" && doctor = "$doctorId" && status = "ongoing"',
        perPage: 1,
      );
      if (consRes.items.isEmpty) return null;
      final consultationId = consRes.items.first.id;
      // Find plan for this consultation
      final planRes = await pb.collection(PBCollections.treatmentPlans).getList(
        filter: 'consultation = "$consultationId"',
        perPage: 1,
      );
      if (planRes.items.isEmpty) return null;
      final plan = planRes.items.first;
      return {
        'planId': plan.id,
        'consultationId': consultationId,
        'treatmentType': plan.getStringValue('treatment_type'),
        'totalSessions': plan.getIntValue('total_sessions'),
      };
    } catch (_) {}
    return null;
  }
}

