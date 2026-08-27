import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/services/audit_service.dart';

/// All admin-level PocketBase operations for the superadmin panel.
/// Uses the official PocketBase SDK, automatically handling token injection
/// and standardizing query construction/request execution.
class SuperadminService {
  final PocketBase pb;

  SuperadminService(this.pb);

  // ── Platform Stats ─────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchPlatformStats() async {
    final results = await Future.wait([
      pb.collection(PBCollections.clinics).getList(page: 1, perPage: 1),
      pb.collection(PBCollections.doctors).getList(page: 1, perPage: 1),
      pb.collection(PBCollections.receptionists).getList(page: 1, perPage: 1),
      pb.collection(PBCollections.patients).getList(page: 1, perPage: 1),
      pb.collection(PBCollections.consultations).getList(page: 1, perPage: 1),
      pb.collection(PBCollections.sessions).getList(page: 1, perPage: 1),
    ]);

    // Fetch active clinics and expiring soon
    int expiringSoonCount = 0;
    int activeClinicsCount = 0;
    try {
      final allClinics = await pb.collection(PBCollections.clinics).getFullList(fields: 'id,subscription_status,subscription_end_date,is_deactivated,status');
      final now = DateTime.now();
      final in7Days = now.add(const Duration(days: 7));
      for (final c in allClinics) {
        final isDeactivated = c.getBoolValue('is_deactivated');
        final status = c.getStringValue('status');
        final subStatus = c.getStringValue('subscription_status');
        final endDateStr = c.getStringValue('subscription_end_date');
        final endDate = DateTime.tryParse(endDateStr);

        if (!isDeactivated && status != 'pending_deletion' && subStatus != 'canceled' && subStatus != 'expired') {
          activeClinicsCount++;
        }

        if (endDate != null && endDate.isAfter(now) && endDate.isBefore(in7Days)) {
          expiringSoonCount++;
        }
      }
    } catch (_) {}

    return {
      'total_clinics': results[0].totalItems,
      'total_doctors': results[1].totalItems,
      'total_receptionists': results[2].totalItems,
      'total_patients': results[3].totalItems,
      'total_consultations': results[4].totalItems,
      'total_sessions': results[5].totalItems,
      'active_clinics': activeClinicsCount > 0 ? activeClinicsCount : results[0].totalItems,
      'expiring_soon': expiringSoonCount,
    };
  }

  Future<List<RecordModel>> fetchRecentClinics({int limit = 10}) async {
    final list = await pb.collection(PBCollections.clinics).getList(
          page: 1,
          perPage: limit,
          sort: '-id',
        );
    return list.items;
  }

  // ── Clinic Management ─────────────────────────────────────────

  Future<List<RecordModel>> fetchAllClinics({String? search}) async {
    String? filter;
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim();
      filter = "name ~ '$q' || city ~ '$q' || clinic_id ~ '$q'";
    }
    final list = await pb.collection(PBCollections.clinics).getList(
          page: 1,
          perPage: 500,
          sort: '-id',
          filter: filter,
        );
    return list.items;
  }

  /// Returns the clinic record, plus its list of doctors and receptionists.
  Future<Map<String, dynamic>> getClinicWithStaff(String clinicId) async {
    final results = await Future.wait([
      pb.collection(PBCollections.clinics).getOne(clinicId),
      pb.collection(PBCollections.doctors).getList(
            filter: "clinic='$clinicId'",
            sort: 'name',
          ),
      pb.collection(PBCollections.receptionists).getList(
            filter: "clinic='$clinicId'",
            sort: 'name',
          ),
    ]);

    return {
      'clinic': results[0] as RecordModel,
      'doctors': (results[1] as ResultList<RecordModel>).items,
      'receptionists': (results[2] as ResultList<RecordModel>).items,
    };
  }

  Future<void> updateClinic(String clinicId, Map<String, dynamic> body) async {
    await pb.collection(PBCollections.clinics).update(clinicId, body: body);
  }

  Future<void> toggleClinicVerified(String clinicId, bool verified) async {
    await pb.collection(PBCollections.clinics).update(clinicId, body: {'verified': verified});
  }

  /// Soft-deactivates a clinic — blocks all logins and sets a 30-day deletion window.
  /// The clinic record stays in PocketBase; staff accounts are NOT deleted yet.
  Future<void> deactivateClinic(String clinicId) async {
    final now = DateTime.now().toUtc();
    final deletionDate = now.add(const Duration(days: 30));
    await pb.collection(PBCollections.clinics).update(clinicId, body: {
      'is_deactivated': true,
      'deactivated_at': now.toIso8601String(),
      'scheduled_deletion_date': deletionDate.toIso8601String(),
    });
  }

  /// Reactivates a previously deactivated clinic, restoring full login access.
  Future<void> reactivateClinic(String clinicId) async {
    await pb.collection(PBCollections.clinics).update(clinicId, body: {
      'is_deactivated': false,
      'deactivated_at': '',
      'scheduled_deletion_date': '',
    });
  }

  /// Cancels a clinic's self-initiated deletion request (status = pending_deletion)
  /// and restores it to active status. This is separate from superadmin-initiated
  /// deactivation (which uses is_deactivated).
  Future<void> cancelSelfDeletion(String clinicId) async {
    await pb.collection(PBCollections.clinics).update(clinicId, body: {
      'status': 'active',
      'deletion_requested_at': '',
      'purge_at': '',
      'deletion_requested_by': '',
      'deletion_reason': '',
    });
    try {
      await pb.collection('audit_logs').create(body: {
        'user_id': pb.authStore.record?.id ?? 'superadmin',
        'user_role': 'superadmin',
        'action': AuditAction.clinicSelfDeletionCancelled.name,
        'target_id': clinicId,
        'details': 'Clinic self-deletion cancelled by superadmin. Status restored to active.',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Permanently deletes a clinic and cascades through ALL 10 collections.
  Future<void> permanentlyDeleteClinic(String clinicId) async {
    // 1. Fetch all doctor IDs (needed for sessions/consultations filter)
    final doctors = await pb.collection(PBCollections.doctors).getFullList(filter: "clinic='$clinicId'");
    final doctorIds = doctors.map((d) => d.id).toList();

    // 2. Delete sessions (filter by doctor or clinic)
    for (final docId in doctorIds) {
      final sessions = await pb.collection(PBCollections.sessions).getFullList(filter: "doctor='$docId'");
      for (final s in sessions) {
        await pb.collection(PBCollections.sessions).delete(s.id);
      }
    }

    // 3. Delete treatment_plans (filter by doctor)
    for (final docId in doctorIds) {
      final plans = await pb.collection(PBCollections.treatmentPlans).getFullList(filter: "doctor='$docId'");
      for (final p in plans) {
        await pb.collection(PBCollections.treatmentPlans).delete(p.id);
      }
    }

    // 4. Delete consultations
    final consultations = await pb.collection(PBCollections.consultations).getFullList(filter: "clinic='$clinicId'");
    for (final c in consultations) {
      await pb.collection(PBCollections.consultations).delete(c.id);
    }

    // 5. Delete appointments
    final appointments = await pb.collection(PBCollections.appointments).getFullList(filter: "clinic='$clinicId'");
    for (final a in appointments) {
      await pb.collection(PBCollections.appointments).delete(a.id);
    }

    // 6. Delete patients
    final patients = await pb.collection(PBCollections.patients).getFullList(filter: "clinic='$clinicId'");
    for (final p in patients) {
      await pb.collection(PBCollections.patients).delete(p.id);
    }

    // 7. Delete consent_records
    final consentRecords = await pb.collection(PBCollections.consentRecords).getFullList(filter: "user_id='$clinicId'");
    for (final cr in consentRecords) {
      await pb.collection(PBCollections.consentRecords).delete(cr.id);
    }

    // 8. Delete audit_logs
    final auditLogs = await pb.collection(PBCollections.auditLogs).getFullList(filter: "clinic='$clinicId'");
    for (final al in auditLogs) {
      await pb.collection(PBCollections.auditLogs).delete(al.id);
    }

    // 9. Delete doctors
    for (final d in doctors) {
      await pb.collection(PBCollections.doctors).delete(d.id);
    }

    // 10. Delete receptionists
    final recs = await pb.collection(PBCollections.receptionists).getFullList(filter: "clinic='$clinicId'");
    for (final r in recs) {
      await pb.collection(PBCollections.receptionists).delete(r.id);
    }

    // 11. Finally delete the clinic itself
    await pb.collection(PBCollections.clinics).delete(clinicId);
  }

  Future<void> resetClinicPassword(String clinicId, String newPassword) async {
    await pb.collection(PBCollections.clinics).update(clinicId, body: {
      'password': newPassword,
      'passwordConfirm': newPassword,
    });
  }

  // ── Doctor Management ─────────────────────────────────────────

  Future<void> resetDoctorPassword(String doctorId, String newPassword) async {
    await pb.collection(PBCollections.doctors).update(doctorId, body: {
      'password': newPassword,
      'passwordConfirm': newPassword,
    });
  }

  Future<void> deleteDoctor(String doctorId) async {
    await pb.collection(PBCollections.doctors).delete(doctorId);
  }

  Future<void> toggleDoctorActive(String doctorId, bool active) async {
    await pb.collection(PBCollections.doctors).update(doctorId, body: {
      'is_active': active,
    });
  }

  // ── Receptionist Management ───────────────────────────────────

  Future<void> resetReceptionistPassword(String recId, String newPassword) async {
    await pb.collection(PBCollections.receptionists).update(recId, body: {
      'password': newPassword,
      'passwordConfirm': newPassword,
    });
  }

  Future<void> deleteReceptionist(String recId) async {
    await pb.collection(PBCollections.receptionists).delete(recId);
  }

  Future<void> toggleReceptionistActive(String recId, bool active) async {
    await pb.collection(PBCollections.receptionists).update(recId, body: {
      'is_active': active,
    });
  }

  // ── Reactivation Requests ──────────────────────────────────────────────

  /// Fetch all pending reactivation requests.
  Future<List<RecordModel>> fetchReactivationRequests() async {
    final list = await pb.collection(PBCollections.clinicReactivationRequests).getList(
          filter: "status='pending'",
          sort: '-requested_at',
          perPage: 200,
        );
    return list.items;
  }

  /// Approve a reactivation request — restores the clinic to active status.
  Future<void> approveReactivation(String requestId, String clinicId) async {
    // Restore clinic to active
    await pb.collection(PBCollections.clinics).update(clinicId, body: {
      'status': 'active',
      'deletion_requested_at': '',
      'purge_at': '',
      'deletion_requested_by': '',
      'deletion_reason': '',
      'reactivation_requested_at': '',
      'reactivation_reason': '',
    });
    // Mark request as approved
    await pb.collection(PBCollections.clinicReactivationRequests).update(requestId, body: {
      'status': 'approved',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    });
    // Audit log via SDK (superadmin token is set in pb.authStore)
    try {
      await pb.collection('audit_logs').create(body: {
        'user_id': pb.authStore.record?.id ?? 'superadmin',
        'user_role': 'superadmin',
        'action': AuditAction.clinicReactivationApproved.name,
        'target_id': clinicId,
        'details': 'Reactivation approved. Clinic restored to active.',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Reject a reactivation request — clinic remains in pending_deletion state.
  Future<void> rejectReactivation(String requestId, String clinicId) async {
    await pb.collection(PBCollections.clinicReactivationRequests).update(requestId, body: {
      'status': 'rejected',
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    });
    try {
      await pb.collection('audit_logs').create(body: {
        'user_id': pb.authStore.record?.id ?? 'superadmin',
        'user_role': 'superadmin',
        'action': AuditAction.clinicReactivationRejected.name,
        'target_id': clinicId,
        'details': 'Reactivation request rejected. Deletion countdown continues.',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  // ── Clinic Data Inspection (Patients, Consultations, Sessions) ──

  /// Fetches patients belonging to a specific clinic.
  Future<ResultList<RecordModel>> fetchClinicPatients(
    String clinicId, {
    String? search,
    int page = 1,
    int perPage = 50,
  }) async {
    String filter = "clinic = '$clinicId'";
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim();
      filter += " && (full_name ~ '$q' || phone ~ '$q' || patient_id ~ '$q')";
    }
    return await pb.collection(PBCollections.patients).getList(
          page: page,
          perPage: perPage,
          filter: filter,
          sort: '-id',
        );
  }

  /// Fetches consultations belonging to a clinic, expanding doctor and patient.
  Future<ResultList<RecordModel>> fetchClinicConsultations(
    String clinicId, {
    String? search,
    int page = 1,
    int perPage = 50,
  }) async {
    String filter = "clinic = '$clinicId'";
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim();
      filter += " && (chief_complaint ~ '$q' || acupuncture_diagnosis ~ '$q' || medical_history ~ '$q')";
    }
    return await pb.collection(PBCollections.consultations).getList(
          page: page,
          perPage: perPage,
          filter: filter,
          sort: '-id',
          expand: 'patient,doctor',
        );
  }

  /// Fetches treatment plans for a clinic.
  Future<ResultList<RecordModel>> fetchClinicTreatmentPlans(
    String clinicId, {
    int page = 1,
    int perPage = 50,
  }) async {
    return await pb.collection(PBCollections.treatmentPlans).getList(
          page: page,
          perPage: perPage,
          filter: "patient.clinic = '$clinicId' || doctor.clinic = '$clinicId'",
          sort: '-id',
          expand: 'patient,doctor',
        );
  }

  /// Fetches sessions for a clinic's treatment plans.
  Future<ResultList<RecordModel>> fetchClinicSessions(
    String clinicId, {
    int page = 1,
    int perPage = 100,
  }) async {
    return await pb.collection(PBCollections.sessions).getList(
          page: page,
          perPage: perPage,
          filter: "patient.clinic = '$clinicId' || doctor.clinic = '$clinicId'",
          sort: '-id',
          expand: 'patient,doctor,treatment_plan',
        );
  }

  // ── Subscription & Quota Editor ─────────────────────────────

  Future<void> updateClinicSubscription(
    String clinicId, {
    required String tier,
    required String status,
    DateTime? endDate,
    required int photoLimit,
    int? bedCount,
  }) async {
    final body = <String, dynamic>{
      'subscription_tier': tier,
      'subscription_status': status,
      'photo_limit': photoLimit,
      'subscription_end_date': endDate?.toUtc().toIso8601String() ?? '',
      if (bedCount != null) 'bed_count': bedCount,
    };
    await pb.collection(PBCollections.clinics).update(clinicId, body: body);
  }

  // ── Patient CRUD (Superadmin Read & Write) ───────────────────

  Future<void> updatePatient(String patientId, Map<String, dynamic> body) async {
    await pb.collection(PBCollections.patients).update(patientId, body: body);
  }

  Future<void> deletePatient(String patientId) async {
    await pb.collection(PBCollections.patients).delete(patientId);
  }

  // ── Consultation CRUD (Superadmin Read & Write) ─────────────

  Future<void> updateConsultation(String consultationId, Map<String, dynamic> body) async {
    await pb.collection(PBCollections.consultations).update(consultationId, body: body);
  }

  Future<void> deleteConsultation(String consultationId) async {
    await pb.collection(PBCollections.consultations).delete(consultationId);
  }

  // ── Session CRUD (Superadmin Read & Write) ───────────────────

  Future<void> deleteSession(String sessionId) async {
    await pb.collection(PBCollections.sessions).delete(sessionId);
  }

  // ── System-Wide Settings ────────────────────────────────────

  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final records = await pb.collection(PBCollections.systemSettings).getList(page: 1, perPage: 1);
      if (records.items.isNotEmpty) {
        final rec = records.items.first;
        return {
          'id': rec.id,
          'default_trial_days': rec.getIntValue('default_trial_days', 14),
          'grace_period_days': rec.getIntValue('grace_period_days', 3),
          'default_photo_limit': rec.getIntValue('default_photo_limit', 2000),
        };
      }
    } catch (_) {}

    // Fallback default system settings
    return {
      'default_trial_days': 14,
      'grace_period_days': 3,
      'default_photo_limit': 2000,
    };
  }

  Future<void> saveSystemSettings(Map<String, dynamic> settings) async {
    try {
      final records = await pb.collection(PBCollections.systemSettings).getList(page: 1, perPage: 1);
      if (records.items.isNotEmpty) {
        await pb.collection(PBCollections.systemSettings).update(records.items.first.id, body: settings);
      } else {
        await pb.collection(PBCollections.systemSettings).create(body: settings);
      }
    } catch (_) {}
  }

  /// Checks for clinics whose purge_at date has passed and permanently purges them.
  Future<int> runPurgeCheck() async {
    int purgedCount = 0;
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final expiredPending = await pb.collection(PBCollections.clinics).getFullList(
            filter: "status='pending_deletion' && purge_at != '' && purge_at <= '$nowIso'",
          );
      for (final clinic in expiredPending) {
        await permanentlyDeleteClinic(clinic.id);
        purgedCount++;
      }
    } catch (_) {}
    return purgedCount;
  }
}

