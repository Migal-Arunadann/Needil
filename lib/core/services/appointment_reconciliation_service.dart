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
  /// - `scheduled` or `waiting` -> Auto-marked as `missed`.
  /// - `in_progress` -> Checks if consultation was saved. If yes, completes it. If no, misses it.
  Future<void> reconcileAppointments() async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    // We want to find any appointments where date < today 
    // AND status IN ('scheduled', 'waiting', 'in_progress')
    
    // Depending on the role, we only want to fetch relevant appointments.
    String baseFilter = 'date < "$todayStr" && (status = "scheduled" || status = "waiting" || status = "in_progress")';
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
          // If in progress, check if they clicked "Save Consultation" (which sets consultation_end_time)
          if (apt.consultationEndTime != null) {
            // They saved the form. Auto-complete it.
            try {
              await pb.collection(PBCollections.appointments).update(apt.id, body: {
                'status': 'completed',
                'previous_status': AppointmentModel.statusToString(apt.status),
                'reconciliation_reason': 'Auto-completed overnight (User did not end the consultation)',
                'reconciled_at': now.toUtc().toIso8601String(),
                'reconciled_by': 'system',
              });
            } catch (e) {
              print('Error completing appointment ${apt.id}: $e');
            }
          } else {
            // They never saved the form. Treat it as if they never saw the patient.
            try {
              await pb.collection(PBCollections.appointments).update(apt.id, body: {
                'status': 'missed',
                'previous_status': AppointmentModel.statusToString(apt.status),
                'reconciliation_reason': 'Auto-missed overnight (Form never saved)',
                'reconciled_at': now.toUtc().toIso8601String(),
                'reconciled_by': 'system',
              });
            } catch (e) {
              print('Error missing in_progress appointment ${apt.id}: $e');
            }
          }
        } else if (apt.status == AppointmentStatus.scheduled || apt.status == AppointmentStatus.waiting) {
          // Reconcile as missed
          try {
            await pb.collection(PBCollections.appointments).update(apt.id, body: {
              'status': 'missed',
              'previous_status': AppointmentModel.statusToString(apt.status),
              'reconciliation_reason': 'Automatic end-of-day reconciliation',
              'reconciled_at': now.toUtc().toIso8601String(),
              'reconciled_by': 'system',
            });
          } catch (e) {
            // Ignore individual update errors to not block the whole batch
            print('Error reconciling appointment ${apt.id}: $e');
          }
        }
      }
    } catch (e) {
      print('Failed to reconcile appointments: $e');
    }
  }
}
