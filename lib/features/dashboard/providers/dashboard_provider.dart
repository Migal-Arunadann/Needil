import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../appointments/models/appointment_model.dart';

class DashboardStats {
  final int todayAppointments;
  final int scheduledCount;
  final int completedCount;
  final int cancelledCount;
  final int totalPatients;
  final int activePlans;
  final int upcomingSessions;
  final List<AppointmentModel> upcomingAppointments;
  final bool isLoading;

  const DashboardStats({
    this.todayAppointments = 0,
    this.scheduledCount = 0,
    this.completedCount = 0,
    this.cancelledCount = 0,
    this.totalPatients = 0,
    this.activePlans = 0,
    this.upcomingSessions = 0,
    this.upcomingAppointments = const [],
    this.isLoading = false,
  });

  DashboardStats copyWith({
    int? todayAppointments,
    int? scheduledCount,
    int? completedCount,
    int? cancelledCount,
    int? totalPatients,
    int? activePlans,
    int? upcomingSessions,
    List<AppointmentModel>? upcomingAppointments,
    bool? isLoading,
  }) {
    return DashboardStats(
      todayAppointments: todayAppointments ?? this.todayAppointments,
      scheduledCount: scheduledCount ?? this.scheduledCount,
      completedCount: completedCount ?? this.completedCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      totalPatients: totalPatients ?? this.totalPatients,
      activePlans: activePlans ?? this.activePlans,
      upcomingSessions: upcomingSessions ?? this.upcomingSessions,
      upcomingAppointments: upcomingAppointments ?? this.upcomingAppointments,
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
      state = const DashboardStats();
      return;
    }

    final today =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

    try {
      final isClinic = auth.role == UserRole.clinic;
      final ownerField = isClinic ? 'clinic' : 'doctor';

      final results = await Future.wait([
        // [0] Today's appointments (all non-cancelled)
        pb.collection(PBCollections.appointments).getList(
              filter: '$ownerField = "$userId" && date = "$today" && status != "cancelled"',
              perPage: 1,
            ),
        // [1] Today's scheduled
        pb.collection(PBCollections.appointments).getList(
              filter: '$ownerField = "$userId" && date = "$today" && status = "scheduled"',
              perPage: 1,
            ),
        // [2] Today's completed
        pb.collection(PBCollections.appointments).getList(
              filter: '$ownerField = "$userId" && date = "$today" && status = "completed"',
              perPage: 1,
            ),
        // [3] Today's cancelled
        pb.collection(PBCollections.appointments).getList(
              filter: '$ownerField = "$userId" && date = "$today" && status = "cancelled"',
              perPage: 1,
            ),
        // [4] Total patients
        pb.collection(PBCollections.patients).getList(
              filter: '$ownerField = "$userId"',
              perPage: 1,
            ),
        // [5] Active treatment plans
        pb.collection(PBCollections.treatmentPlans).getList(
              filter: '${isClinic ? "doctor.clinic" : "doctor"} = "$userId" && status = "active"',
              perPage: 1,
            ),
        // [6] Upcoming sessions (status = "upcoming")
        pb.collection(PBCollections.sessions).getList(
              filter: '${isClinic ? "doctor.clinic" : "doctor"} = "$userId" && status = "upcoming"',
              perPage: 1,
            ),
        // [7] Today's upcoming appointments (for the list preview) 
        pb.collection(PBCollections.appointments).getList(
              filter: '$ownerField = "$userId" && date = "$today" && status = "scheduled"',
              perPage: 5,
              expand: 'patient,doctor',
            ),
      ]);

      state = DashboardStats(
        todayAppointments: results[0].totalItems,
        scheduledCount: results[1].totalItems,
        completedCount: results[2].totalItems,
        cancelledCount: results[3].totalItems,
        totalPatients: results[4].totalItems,
        activePlans: results[5].totalItems,
        upcomingSessions: results[6].totalItems,
        upcomingAppointments: results[7].items.map((r) => AppointmentModel.fromRecord(r)).toList(),
        isLoading: false,
      );
    } catch (_) {
      state = const DashboardStats();
    }
  }
}

final dashboardStatsProvider =
    StateNotifierProvider<DashboardStatsNotifier, DashboardStats>((ref) {
  final notifier = DashboardStatsNotifier(ref);
  notifier.load();
  return notifier;
});
