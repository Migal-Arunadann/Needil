import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardStats {
  final int todayAppointments;
  final int totalPatients;
  final int activePlans;
  final bool isLoading;

  const DashboardStats({
    this.todayAppointments = 0,
    this.totalPatients = 0,
    this.activePlans = 0,
    this.isLoading = false,
  });

  DashboardStats copyWith({
    int? todayAppointments,
    int? totalPatients,
    int? activePlans,
    bool? isLoading,
  }) {
    return DashboardStats(
      todayAppointments: todayAppointments ?? this.todayAppointments,
      totalPatients: totalPatients ?? this.totalPatients,
      activePlans: activePlans ?? this.activePlans,
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
    final doctorId = auth.userId;
    if (doctorId == null) {
      state = const DashboardStats();
      return;
    }

    try {
      final today =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        // Today's appointments
        pb.collection(PBCollections.appointments).getList(
              filter: 'doctor = "$doctorId" && date = "$today" && status != "cancelled"',
              perPage: 1,
            ),
        // Total unique patients
        pb.collection(PBCollections.patients).getList(
              filter: 'doctor = "$doctorId"',
              perPage: 1,
            ),
        // Active treatment plans
        pb.collection(PBCollections.treatmentPlans).getList(
              filter: 'doctor = "$doctorId" && status = "active"',
              perPage: 1,
            ),
      ]);

      state = DashboardStats(
        todayAppointments: results[0].totalItems,
        totalPatients: results[1].totalItems,
        activePlans: results[2].totalItems,
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
