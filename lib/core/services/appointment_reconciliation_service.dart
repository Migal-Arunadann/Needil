import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';

final appointmentReconciliationServiceProvider = Provider<AppointmentReconciliationService>((ref) {
  final pb = ref.read(pocketbaseProvider);
  final auth = ref.read(authProvider);
  return AppointmentReconciliationService(pb, auth);
});

class AppointmentReconciliationService {
  final PocketBase pb;
  final AuthState auth;

  AppointmentReconciliationService(this.pb, this.auth);

  /// Reconciles stale appointments (from past dates).
  ///
  /// - `scheduled` or `waiting` consultation/walk-in → flagged as `overdue` for human review.
  /// - `in_progress` consultation/walk-in where form WAS saved → auto-completed.
  /// - `in_progress` consultation/walk-in where form was NOT saved → flagged as `overdue`.
  /// - Session-type appointments are handled separately via MissedSessionDetector.
  Future<void> reconcileAppointments() async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Only fetch consultation/walk-in appointments (not sessions — those are handled by MissedSessionDetector)
    String baseFilter =
        'date < "$todayStr" && (status = "scheduled" || status = "waiting" || status = "in_progress") && type != "session"';

    if (auth.role == UserRole.doctor && auth.userId != null) {
      baseFilter += ' && doctor = "${auth.userId}"';
    } else if (auth.role == UserRole.clinic && auth.clinicId != null) {
      baseFilter += ' && clinic = "${auth.clinicId}"';
    } else if (auth.role == UserRole.receptionist && auth.clinicId != null) {
      baseFilter += ' && clinic = "${auth.clinicId}"';
    } else {
      return; // Not logged in properly
    }

    try {
      final records = await pb.collection(PBCollections.appointments).getFullList(
        filter: baseFilter,
        sort: '-date,-time',
        expand: 'patient,doctor',
      );

      for (var record in records) {
        final apt = AppointmentModel.fromRecord(record);

        if (apt.status == AppointmentStatus.inProgress) {
          if (apt.consultationEndTime != null) {
            // Form was saved — auto-complete it
            try {
              await pb.collection(PBCollections.appointments).update(apt.id, body: {
                'status': 'completed',
                'previous_status': AppointmentModel.statusToString(apt.status),
                'reconciliation_reason': 'Auto-completed overnight (consultation form was saved)',
                'reconciled_at': now.toUtc().toIso8601String(),
                'reconciled_by': 'system',
              });
            } catch (e) {
              // ignore individual errors
            }
          } else {
            // Form was never saved — flag as overdue for human review
            try {
              await pb.collection(PBCollections.appointments).update(apt.id, body: {
                'status': 'overdue',
                'previous_status': AppointmentModel.statusToString(apt.status),
                'reconciliation_reason': 'Consultation started but never saved — awaiting staff review',
                'reconciled_at': now.toUtc().toIso8601String(),
                'reconciled_by': 'system',
              });
            } catch (e) {
              // ignore individual errors
            }
          }
        } else {
          // scheduled or waiting — patient may not have arrived OR staff forgot to record
          // Flag as overdue for human review ("Patient Did Not Arrive" or "Forgot to Fill Details")
          try {
            await pb.collection(PBCollections.appointments).update(apt.id, body: {
              'status': 'overdue',
              'previous_status': AppointmentModel.statusToString(apt.status),
              'reconciliation_reason': 'Appointment not resolved on scheduled date — awaiting staff review',
              'reconciled_at': now.toUtc().toIso8601String(),
              'reconciled_by': 'system',
            });
          } catch (e) {
            // ignore individual errors
          }
        }
      }
    } catch (e) {
      // Silently fail — this is a background sweep
    }
  }

  /// Retrieve all overdue consultations for the Needs Attention dashboard.
  Future<List<AppointmentModel>> getOverdueConsultations(String id, {bool isClinic = false}) async {
    try {
      String filter;
      if (isClinic) {
        // Use getFullList to avoid the 50-doctor hard cap
        final docs = await pb.collection('doctors').getFullList(
          filter: 'clinic = "$id"',
        );
        if (docs.isEmpty) return [];
        final doctorFilter = docs.map((doc) => 'doctor = "${doc.id}"').join(' || ');
        filter = '($doctorFilter) && status = "overdue" && type != "session"';
      } else {
        filter = 'doctor = "$id" && status = "overdue" && type != "session"';
      }

      final result = await pb.collection(PBCollections.appointments).getFullList(
        filter: filter,
        sort: 'date,time',
        expand: 'patient,doctor',
      );
      return result.map((r) => AppointmentModel.fromRecord(r)).toList();
    } catch (e) {
      return [];
    }
  }
}
