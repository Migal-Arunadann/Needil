import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/services/audit_service.dart';

/// Handles clinic self-initiated deletion and reactivation request flows.
class ClinicDeletionService {
  final PocketBase pb;
  final AuditService _audit;

  ClinicDeletionService(this.pb) : _audit = AuditService(pb);

  /// Request deletion of the clinic account.
  ///
  /// Verifies the [password] matches the current session, then transitions
  /// the clinic to `status = pending_deletion` with a 30-day purge window.
  ///
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> requestDeletion({
    required String clinicId,
    required String username,
    required String password,
    String? reason,
  }) async {
    try {
      // Re-authenticate to verify password before allowing deletion
      await pb.collection(PBCollections.clinics).authWithPassword(username, password);
    } on Exception catch (e) {
      return 'Password verification failed: ${e.toString().replaceAll('ClientException: ', '')}';
    }

    try {
      final now = DateTime.now().toUtc();
      final purgeAt = now.add(const Duration(days: 30));

      await pb.collection(PBCollections.clinics).update(clinicId, body: {
        'status': 'pending_deletion',
        'deletion_requested_at': now.toIso8601String(),
        'purge_at': purgeAt.toIso8601String(),
        'deletion_requested_by': clinicId,
        if (reason != null && reason.isNotEmpty) 'deletion_reason': reason,
      });

      // Write audit log (non-blocking)
      await _audit.log(
        userId: clinicId,
        userRole: 'clinic',
        action: AuditAction.clinicDeletionRequested,
        targetId: clinicId,
        details: 'Clinic deletion requested. '
            'Purge scheduled for ${purgeAt.toIso8601String().substring(0, 10)}. '
            'Reason: ${reason ?? 'Not provided'}',
      );

      return null; // success
    } catch (e) {
      return 'Failed to request deletion: $e';
    }
  }

  /// Submit a reactivation request (requires superadmin approval).
  ///
  /// Creates a record in [clinic_reactivation_requests] and updates
  /// the clinic record with the reactivation request timestamp.
  ///
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> requestReactivation({
    required String clinicId,
    required String clinicName,
    required String requestedBy,
    required String reason,
  }) async {
    try {
      final now = DateTime.now().toUtc();

      // Create the reactivation request record
      await pb.collection(PBCollections.clinicReactivationRequests).create(body: {
        'clinic_id': clinicId,
        'clinic_name': clinicName,
        'requested_by': requestedBy,
        'requested_at': now.toIso8601String(),
        'reason': reason,
        'status': 'pending',
      });

      // Update clinic with reactivation request timestamp
      await pb.collection(PBCollections.clinics).update(clinicId, body: {
        'reactivation_requested_at': now.toIso8601String(),
        'reactivation_reason': reason,
      });

      // Write audit log
      await _audit.log(
        userId: requestedBy,
        userRole: 'clinic',
        action: AuditAction.clinicReactivationRequested,
        targetId: clinicId,
        details: 'Reactivation request submitted. Reason: $reason',
      );

      return null; // success
    } catch (e) {
      return 'Failed to submit reactivation request: $e';
    }
  }
}
