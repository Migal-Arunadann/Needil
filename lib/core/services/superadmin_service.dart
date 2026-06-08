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
    ]);
    return {
      'total_clinics': results[0].totalItems,
      'total_doctors': results[1].totalItems,
      'total_receptionists': results[2].totalItems,
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

    // 3. Delete treatment_plans
    final plans = await pb.collection(PBCollections.treatmentPlans).getFullList(filter: "clinic='$clinicId'");
    for (final p in plans) {
      await pb.collection(PBCollections.treatmentPlans).delete(p.id);
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
    final consentRecords = await pb.collection(PBCollections.consentRecords).getFullList(filter: "clinic_id='$clinicId'");
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

  // ── Purge Job ─────────────────────────────────────────────────────────────

  /// Check for clinics past their purge_at date and permanently delete them.
  Future<int> runPurgeCheck() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final clinics = await pb.collection(PBCollections.clinics).getFullList(
          filter: "status='pending_deletion' && purge_at != '' && purge_at <= '$now'",
        );
    int purged = 0;
    for (final clinic in clinics) {
      try {
        await permanentlyDeleteClinic(clinic.id);
        await pb.collection('audit_logs').create(body: {
          'user_id': 'system',
          'user_role': 'system',
          'action': AuditAction.clinicPurged.name,
          'target_id': clinic.id,
          'details': 'Clinic automatically purged after 30-day retention period.',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });
        purged++;
      } catch (_) {
        // Don't let one failure block others
      }
    }
    return purged;
  }
}
