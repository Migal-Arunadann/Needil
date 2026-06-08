import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

/// Actions that can be audited.
enum AuditAction {
  login,
  logout,
  createPatient,
  updatePatient,
  viewPatient,
  createAppointment,
  updateAppointment,
  createConsultation,
  createTreatmentPlan,
  recordSession,
  joinClinic,
  leaveClinic,
  updateSharingPrefs,
  consentGiven,
  consentWithdrawn,
  markArrived,
  cancelAppointment,
  rescheduleAppointment,
  // Clinic lifecycle
  clinicDeletionRequested,
  clinicReactivationRequested,
  clinicReactivationApproved,
  clinicReactivationRejected,
  clinicPurged,
}

/// Audit logging service for compliance tracking.
class AuditService {
  final PocketBase pb;

  AuditService(this.pb);

  /// Log an auditable action.
  Future<void> log({
    required String userId,
    required String userRole,
    required AuditAction action,
    String? targetId,
    String? details,
  }) async {
    try {
      await pb.collection('audit_logs').create(body: {
        'user_id': userId,
        'user_role': userRole,
        'action': action.name,
        'target_id': targetId ?? '',
        'details': details ?? '',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'ip_address': '', // Will be populated server-side if needed
      });
    } catch (_) {
      // Audit logging should never block the main flow
    }
  }

  /// Get audit logs for a user (for DPDP compliance - data access history).
  Future<List<Map<String, dynamic>>> getUserLogs(String userId) async {
    try {
      final result = await pb.collection('audit_logs').getList(
        filter: 'user_id = "$userId"',
        sort: '-created',
        perPage: 100,
      );
      return result.items.map((r) => r.toJson()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get audit logs for a specific receptionist.
  Future<List<Map<String, dynamic>>> getReceptionistLogs(String receptionistId, {int perPage = 50}) async {
    try {
      final result = await pb.collection('audit_logs').getList(
        filter: 'user_id = "$receptionistId" && user_role = "receptionist"',
        sort: '-created',
        perPage: perPage,
      );
      return result.items.map((r) => r.toJson()).toList();
    } catch (_) {
      return [];
    }
  }
}

/// Riverpod provider for [AuditService].
final auditServiceProvider = Provider<AuditService>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return AuditService(pb);
});
