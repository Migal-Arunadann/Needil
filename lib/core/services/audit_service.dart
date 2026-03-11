import 'package:pocketbase/pocketbase.dart';

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
}
