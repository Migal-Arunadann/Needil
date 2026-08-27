import 'package:flutter/foundation.dart';
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
  clinicSelfDeletionCancelled,
  clinicPurged,
}

/// Audit logging service for compliance tracking.
class AuditService {
  final PocketBase pb;

  AuditService(this.pb);

  /// Log an auditable action.
  Future<void> log({
    String? userId,
    String? userRole,
    String? clinicId,
    required AuditAction action,
    String? targetId,
    String? details,
  }) async {
    try {
      var uid = userId ?? '';
      var urole = userRole ?? '';
      var cid = clinicId ?? '';

      final authModel = pb.authStore.model;
      if (uid.isEmpty && authModel != null) {
        uid = authModel.id;
      }
      if (urole.isEmpty && authModel is RecordModel) {
        urole = authModel.collectionName;
      }
      if (cid.isEmpty && authModel is RecordModel) {
        if (authModel.collectionName == 'clinics') {
          cid = authModel.id;
        } else {
          cid = authModel.getStringValue('clinic');
        }
      }
      if (uid.isEmpty) return;

      await pb.collection('audit_logs').create(body: {
        'user_id': uid,
        'user_role': urole,
        'clinic_id': cid,
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
        sort: '-timestamp',
        perPage: 100,
      );
      return result.items.map((r) => r.toJson()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get audit logs for a specific receptionist.
  Future<List<Map<String, dynamic>>> getReceptionistLogs(
    String receptionistId, {
    String? fallbackId,
    String? username,
    int perPage = 50,
  }) async {
    try {
      final filters = <String>[];
      if (receptionistId.isNotEmpty) {
        filters.add('user_id = "$receptionistId"');
      }
      if (fallbackId != null && fallbackId.isNotEmpty && fallbackId != receptionistId) {
        filters.add('user_id = "$fallbackId"');
      }
      if (username != null && username.isNotEmpty) {
        filters.add('user_id = "$username"');
      }
      final filterStr = filters.isNotEmpty ? '(${filters.join(' || ')})' : '';

      final result = await pb.collection('audit_logs').getList(
        filter: filterStr.isNotEmpty ? filterStr : null,
        sort: '-timestamp',
        perPage: perPage,
      );
      debugPrint('[AUDIT_DEBUG] Found ${result.items.length} logs for filter: $filterStr');
      return result.items.map((r) => r.toJson()).toList();
    } catch (e) {
      debugPrint('[AUDIT_ERROR] getReceptionistLogs failed: $e');
      return [];
    }
  }
}

/// Riverpod provider for [AuditService].
final auditServiceProvider = Provider<AuditService>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return AuditService(pb);
});
