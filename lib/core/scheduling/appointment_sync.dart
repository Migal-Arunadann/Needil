import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';

/// Single source of truth for all appointment CRUD operations related to sessions.
///
/// Key improvements over v1:
///   1. Finds appointments by [linked_session_id] FK first (O(1), exact).
///   2. Falls back to composite lookup for legacy records, then stamps the FK.
///   3. All date formatting uses local time via [formatLocalDate].
///   4. Never touches appointments for a session based on date/time match alone
///      without also matching the session FK when available.
class AppointmentSync {
  final PocketBase pb;

  AppointmentSync(this.pb);

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Create a new appointment and link it to [sessionId].
  Future<void> createForSession({
    required String sessionId,
    required String patientId,
    required String doctorId,
    required String date,
    required String time,
    required String? clinicId,
    required String sessionType,
    String status = 'scheduled',
  }) async {
    try {
      await pb.collection(PBCollections.appointments).create(body: {
        'patient': patientId,
        'doctor': doctorId,
        if (clinicId != null && clinicId.isNotEmpty) 'clinic': clinicId,
        'type': 'session',
        'date': date,
        'time': time,
        'status': status,
        'session_type': sessionType,
        'linked_session_id': sessionId,
      });
    } catch (e) {
      debugPrint('[AppointmentSync] createForSession error: $e');
    }
  }

  /// Move an existing appointment to a new date and time.
  ///
  /// Lookup order:
  ///   1. [linked_session_id] = [sessionId]  (fast, exact — preferred)
  ///   2. Composite: patient + doctor + old date + type = "session"  (legacy fallback)
  ///
  /// Always stamps [linked_session_id] on update so future lookups are fast.
  /// If no existing appointment is found, creates a fresh one.
  Future<void> updateForSession({
    required SessionModel session,
    required String newDate,
    required String newTime,
    required String? clinicId,
    required String sessionType,
    bool isRescheduled = true,
  }) async {
    try {
      // Fast path: FK lookup
      var apptItems = await _findBySessionId(session.id);

      // Legacy fallback: composite lookup
      if (apptItems.isEmpty) {
        apptItems = await _findByDateComposite(session);
      }

      if (apptItems.isNotEmpty) {
        for (final appt in apptItems) {
          await pb.collection(PBCollections.appointments).update(appt.id, body: {
            'date': newDate,
            'time': newTime,
            'status': 'scheduled',
            'is_rescheduled': isRescheduled,
            'linked_session_id': session.id, // stamp FK for future fast lookups
            if (clinicId != null && clinicId.isNotEmpty) 'clinic': clinicId,
          });
        }
      } else {
        // No existing appointment — create fresh
        await createForSession(
          sessionId: session.id,
          patientId: session.patientId,
          doctorId: session.doctorId,
          date: newDate,
          time: newTime,
          clinicId: clinicId,
          sessionType: sessionType,
        );
      }
    } catch (e) {
      debugPrint('[AppointmentSync] updateForSession error: $e');
    }
  }

  /// Cancel all appointments linked to [sessionId].
  Future<void> cancelForSession(String sessionId, {
    SessionModel? session,
  }) async {
    try {
      // Fast path: FK lookup
      var apptItems = await _findBySessionId(sessionId);

      // Fallback using session composite if model available
      if (apptItems.isEmpty && session != null) {
        apptItems = await _findByDateComposite(session);
      }

      for (final appt in apptItems) {
        await pb.collection(PBCollections.appointments).update(
          appt.id,
          body: {'status': 'cancelled'},
        );
      }
    } catch (e) {
      debugPrint('[AppointmentSync] cancelForSession error: $e');
    }
  }

  /// Sync a session's appointment to a given [newStatus].
  ///
  /// Used for completed/cancelled status propagation.
  /// Stamps checkout timestamps when completing.
  Future<void> syncStatus(
    SessionModel session,
    String newStatus, {
    String? reconciliationReason,
  }) async {
    try {
      var apptItems = await _findBySessionId(session.id);
      if (apptItems.isEmpty) {
        apptItems = await _findByDateComposite(session);
      }

      final now = DateTime.now().toUtc().toIso8601String();
      for (final appt in apptItems) {
        final body = <String, dynamic>{'status': newStatus};
        if (newStatus == 'completed') {
          body['check_out_time'] = now;
          body['patient_left_at'] = now;
        }
        if (reconciliationReason != null) {
          body['reconciliation_reason'] = reconciliationReason;
        }
        await pb.collection(PBCollections.appointments).update(appt.id, body: body);
      }
    } catch (e) {
      debugPrint('[AppointmentSync] syncStatus error: $e');
    }
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  Future<List<RecordModel>> _findBySessionId(String sessionId) async {
    try {
      final result = await pb.collection(PBCollections.appointments).getList(
        filter: 'linked_session_id = "$sessionId" && type = "session"',
        perPage: 5,
      );
      return result.items;
    } catch (_) {
      return [];
    }
  }

  Future<List<RecordModel>> _findByDateComposite(SessionModel session) async {
    try {
      // Normalise scheduled_date to local YYYY-MM-DD
      final datePart = formatLocalDate(
        DateTime.tryParse(session.scheduledDate)?.toLocal() ??
            DateTime.now(),
      );
      
      // ONLY find appointments that are either unlinked OR linked to THIS session.
      // Do not steal appointments linked to other sessions!
      final result = await pb.collection(PBCollections.appointments).getList(
        filter: 'patient = "${session.patientId}" && doctor = "${session.doctorId}" '
            '&& date = "$datePart" && type = "session" && (linked_session_id = "" || linked_session_id = "${session.id}")',
        perPage: 5,
      );
      
      // Guard: if multiple appointments match, only return ONE to prevent
      // mass duplication/corruption. Prefer matching time if available.
      if (result.items.length > 1 && session.scheduledTime != null) {
        final withTime = result.items
            .where((a) => a.getStringValue('time') == session.scheduledTime)
            .toList();
        if (withTime.isNotEmpty) return [withTime.first];
      }
      
      if (result.items.isNotEmpty) return [result.items.first];
      
      return [];
    } catch (_) {
      return [];
    }
  }
}

// ─── Shared Date Utility ───────────────────────────────────────────────────────

/// Format a DateTime as YYYY-MM-DD using LOCAL time.
///
/// All date storage in Needil uses plain YYYY-MM-DD strings.
/// Using local time prevents the UTC-day-shift bug where a session
/// at 23:00 UTC is stored as the next calendar day.
String formatLocalDate(DateTime dt) {
  final local = dt.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
