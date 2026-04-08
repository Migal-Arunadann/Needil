import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../appointments/models/appointment_model.dart';

class DashboardStats {
  // Today's counts by type
  final int consultationsToday;  // type = call_by or walk_in
  final int sessionAppointmentsToday;  // type = session

  // Today's status breakdown (all types)
  final int scheduledCount;
  final int inProgressCount;
  final int completedCount;
  final int cancelledCount;

  // Practice overview
  final int totalPatients;
  final int activePlans;

  // Next upcoming appointment for today
  final AppointmentModel? nextAppointment;

  final bool isLoading;

  const DashboardStats({
    this.consultationsToday = 0,
    this.sessionAppointmentsToday = 0,
    this.scheduledCount = 0,
    this.inProgressCount = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
    this.totalPatients = 0,
    this.activePlans = 0,
    this.nextAppointment,
    this.isLoading = false,
  });

  DashboardStats copyWith({
    int? consultationsToday,
    int? sessionAppointmentsToday,
    int? scheduledCount,
    int? inProgressCount,
    int? completedCount,
    int? cancelledCount,
    int? totalPatients,
    int? activePlans,
    AppointmentModel? nextAppointment,
    bool? clearNextAppointment,
    bool? isLoading,
  }) {
    return DashboardStats(
      consultationsToday: consultationsToday ?? this.consultationsToday,
      sessionAppointmentsToday: sessionAppointmentsToday ?? this.sessionAppointmentsToday,
      scheduledCount: scheduledCount ?? this.scheduledCount,
      inProgressCount: inProgressCount ?? this.inProgressCount,
      completedCount: completedCount ?? this.completedCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      totalPatients: totalPatients ?? this.totalPatients,
      activePlans: activePlans ?? this.activePlans,
      nextAppointment: clearNextAppointment == true ? null : (nextAppointment ?? this.nextAppointment),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DashboardStatsNotifier extends StateNotifier<DashboardStats> {
  final Ref _ref;
  DashboardStatsNotifier(this._ref) : super(const DashboardStats(isLoading: true));

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final pb = _ref.read(pocketbaseProvider);
    final auth = _ref.read(authProvider);
    final userId = auth.userId;

    if (userId == null) {
      debugPrint('[Dashboard] No userId — not authenticated');
      state = const DashboardStats();
      return;
    }

    final today = _todayStr();
    final isClinic = auth.role == UserRole.clinic;
    final isReceptionist = auth.role == UserRole.receptionist;

    // Receptionists see all clinic data — resolve the clinic ID
    String ownerField;
    String ownerId;
    String planOwnerFilter;

    if (isClinic) {
      ownerField = 'clinic';
      ownerId = userId;
      planOwnerFilter = 'doctor.clinic = "$userId"';
    } else if (isReceptionist) {
      // Receptionist's clinicId comes from their record
      final clinicId = auth.clinicId ?? '';
      ownerField = 'clinic';
      ownerId = clinicId;
      planOwnerFilter = 'doctor.clinic = "$clinicId"';
    } else {
      // Doctor
      ownerField = 'doctor';
      ownerId = userId;
      planOwnerFilter = 'doctor = "$userId"';
    }

    debugPrint('[Dashboard] Loading for $ownerField=$ownerId, today=$today');

    // Helper: safe getList that returns 0 on failure
    Future<int> safeCount(String collection, String filter) async {
      try {
        final res = await pb.collection(collection).getList(
          filter: filter,
          perPage: 1,
          skipTotal: false,
        );
        return res.totalItems;
      } catch (e) {
        debugPrint('[Dashboard] FAILED $collection filter="$filter": $e');
        return 0;
      }
    }

    // Run all counts in parallel — each failure is isolated
    final counts = await Future.wait([
      // [0] Consultation appts today (call_by + walk_in, non-cancelled)
      safeCount(PBCollections.appointments,
          '$ownerField = "$ownerId" && date = "$today" && (type = "call_by" || type = "walk_in") && status != "cancelled"'),
      // [1] Session appts today (non-cancelled)
      safeCount(PBCollections.appointments,
          '$ownerField = "$ownerId" && date = "$today" && type = "session" && status != "cancelled"'),
      // [2] Scheduled today (any type)
      safeCount(PBCollections.appointments,
          '$ownerField = "$ownerId" && date = "$today" && status = "scheduled"'),
      // [3] In-progress today
      safeCount(PBCollections.appointments,
          '$ownerField = "$ownerId" && date = "$today" && status = "in_progress"'),
      // [4] Completed today
      safeCount(PBCollections.appointments,
          '$ownerField = "$ownerId" && date = "$today" && status = "completed"'),
      // [5] Cancelled today
      safeCount(PBCollections.appointments,
          '$ownerField = "$ownerId" && date = "$today" && status = "cancelled"'),
      // [6] Total patients
      safeCount(PBCollections.patients, '$ownerField = "$ownerId"'),
      // [7] Active treatment plans
      safeCount(PBCollections.treatmentPlans, '$planOwnerFilter && status = "active"'),
    ]);

    debugPrint('[Dashboard] Counts: consultations=${counts[0]}, sessions=${counts[1]}, '
        'scheduled=${counts[2]}, inProgress=${counts[3]}, completed=${counts[4]}, '
        'cancelled=${counts[5]}, patients=${counts[6]}, plans=${counts[7]}');

    // Fetch the single next upcoming appointment (sorted by time asc)
    AppointmentModel? nextAppt;
    try {
      final nextRes = await pb.collection(PBCollections.appointments).getList(
        filter: '$ownerField = "$ownerId" && date = "$today" && status = "scheduled"',
        sort: 'time',
        perPage: 1,
        expand: 'patient,doctor',
      );
      if (nextRes.items.isNotEmpty) {
        nextAppt = AppointmentModel.fromRecord(nextRes.items.first);
      }
    } catch (e) {
      debugPrint('[Dashboard] Failed to fetch next appointment: $e');
    }

    state = DashboardStats(
      consultationsToday: counts[0],
      sessionAppointmentsToday: counts[1],
      scheduledCount: counts[2],
      inProgressCount: counts[3],
      completedCount: counts[4],
      cancelledCount: counts[5],
      totalPatients: counts[6],
      activePlans: counts[7],
      nextAppointment: nextAppt,
      isLoading: false,
    );
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

final dashboardStatsProvider =
    StateNotifierProvider<DashboardStatsNotifier, DashboardStats>((ref) {
  final notifier = DashboardStatsNotifier(ref);
  notifier.load();
  return notifier;
});
