import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

// ─── Event Hook ───────────────────────────────────────────────────────────────

/// Callback signature for scheduling events.
///
/// [action] is the event type, e.g. 'session_missed', 'plan_paused'.
/// [data] contains relevant context: session IDs, plan IDs, dates, etc.
///
/// To connect WhatsApp, SMS, email, or analytics in the future:
/// ```dart
/// auditLogger.addHook((action, data) {
///   if (action == 'session_rescheduled') {
///     whatsappService.notifyPatient(data['patientId'], data['newDate']);
///   }
/// });
/// ```
typedef SchedulingEventHook = void Function(
    String action, Map<String, dynamic> data);

// ─── AuditLogger ──────────────────────────────────────────────────────────────

/// Records every scheduling action to [scheduling_audit_logs] and fires
/// lightweight in-process hooks for future integrations.
///
/// Audit failures are non-fatal — a logging error will never crash
/// the scheduling pipeline.
class AuditLogger {
  final PocketBase pb;
  final List<SchedulingEventHook> _hooks = [];

  AuditLogger(this.pb);

  /// Register a hook that fires after every scheduling action.
  ///
  /// Returns a dispose function. Call it to unregister the hook.
  ///
  /// ```dart
  /// final dispose = auditLogger.addHook(myHook);
  /// // Later:
  /// dispose();
  /// ```
  void Function() addHook(SchedulingEventHook hook) {
    _hooks.add(hook);
    return () => _hooks.remove(hook);
  }

  /// Write an audit record and fire all registered hooks.
  ///
  /// Both the DB write and hook execution are non-fatal on error.
  Future<void> log({
    String? sessionId,
    required String planId,
    required String action,
    String oldDate = '',
    String oldTime = '',
    String newDate = '',
    String newTime = '',
    required String reason,
    required String trigger,
    required String performedBy,
    required int scheduleVersion,
    Map<String, dynamic> metadata = const {},
  }) async {
    // 1. Write to scheduling_audit_logs (non-fatal)
    try {
      await pb.collection('scheduling_audit_logs').create(body: {
        if (sessionId != null && sessionId.isNotEmpty) 'session': sessionId,
        'treatment_plan': planId,
        'action': action,
        'old_date': oldDate,
        'old_time': oldTime,
        'new_date': newDate,
        'new_time': newTime,
        'reason': reason,
        'trigger': trigger,
        'performed_by': performedBy,
        'schedule_version': scheduleVersion,
        if (metadata.isNotEmpty) 'metadata': metadata,
      });
    } catch (e) {
      debugPrint('[AuditLogger] write error: $e');
    }

    // 2. Fire hooks — errors are swallowed per-hook so one bad hook
    //    cannot affect the others.
    final data = <String, dynamic>{
      if (sessionId != null) 'sessionId': sessionId,
      'planId': planId,
      'action': action,
      'oldDate': oldDate,
      'newDate': newDate,
      'reason': reason,
      'trigger': trigger,
      'scheduleVersion': scheduleVersion,
      ...metadata,
    };
    for (final hook in _hooks) {
      try {
        hook(action, data);
      } catch (e) {
        debugPrint('[AuditLogger] hook error: $e');
      }
    }
  }
}
