import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../appointments/models/appointment_model.dart';
import '../../patients/models/patient_model.dart';

// ─── Data model ─────────────────────────────────────────────────────────────

class AnalyticsData {
  // --- Overview KPIs ---
  final int totalPatients;
  final int totalAppointments;
  final int completedAppointments;
  final int cancelledAppointments;
  final int missedAppointments; // sessions with missed status
  final int activeTreatmentPlans;

  // --- 7-day appointment breakdown (index 0 = oldest) ---
  final List<int> weeklyScheduled;
  final List<int> weeklyCompleted;
  final List<int> weeklyCancelled;
  final List<String> weeklyDayLabels;

  // --- Appointment type split (consultation vs session) ---
  final int consultationCount;
  final int sessionAppointmentCount;

  // --- Hourly heat (peak hour analysis) ---
  /// Map of hour (0-23) → appointment count
  final Map<int, int> hourlyDistribution;

  // --- Patient demographics ---
  final Map<String, int> genderDistribution; // 'Male','Female','Other'
  final Map<String, int> ageGroupDistribution; // '<20','20-40','40-60','>60'

  // --- Geographic distribution ---
  /// Top cities/areas by patient count
  final Map<String, int> locationDistribution;

  // --- Appointment status today ---
  final int todayScheduled;
  final int todayCompleted;
  final int todayCancelled;

  // --- Session stats ---
  final int sessionsCompleted;
  final int sessionsMissed;
  final int sessionsCancelled;

  // --- Consultation to plan conversion ---
  final int totalConsultations;
  final int consultationsWithPlan;

  final bool isLoading;

  const AnalyticsData({
    this.totalPatients = 0,
    this.totalAppointments = 0,
    this.completedAppointments = 0,
    this.cancelledAppointments = 0,
    this.missedAppointments = 0,
    this.activeTreatmentPlans = 0,
    this.weeklyScheduled = const [],
    this.weeklyCompleted = const [],
    this.weeklyCancelled = const [],
    this.weeklyDayLabels = const [],
    this.consultationCount = 0,
    this.sessionAppointmentCount = 0,
    this.hourlyDistribution = const {},
    this.genderDistribution = const {},
    this.ageGroupDistribution = const {},
    this.locationDistribution = const {},
    this.todayScheduled = 0,
    this.todayCompleted = 0,
    this.todayCancelled = 0,
    this.sessionsCompleted = 0,
    this.sessionsMissed = 0,
    this.sessionsCancelled = 0,
    this.totalConsultations = 0,
    this.consultationsWithPlan = 0,
    this.isLoading = false,
  });

  double get completionRate =>
      totalAppointments == 0 ? 0 : completedAppointments / totalAppointments;

  double get cancellationRate =>
      totalAppointments == 0 ? 0 : cancelledAppointments / totalAppointments;

  int get peakHour {
    if (hourlyDistribution.isEmpty) return 10;
    return hourlyDistribution.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  int get lowHour {
    if (hourlyDistribution.isEmpty) return 14;
    final nonZero =
        hourlyDistribution.entries.where((e) => e.value > 0).toList();
    if (nonZero.isEmpty) return 14;
    return nonZero.reduce((a, b) => a.value <= b.value ? a : b).key;
  }

  double get planConversionRate =>
      totalConsultations == 0 ? 0 : consultationsWithPlan / totalConsultations;
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AnalyticsNotifier extends StateNotifier<AnalyticsData> {
  final Ref _ref;
  AnalyticsNotifier(this._ref) : super(const AnalyticsData(isLoading: true));

  Future<void> load() async {
    state = const AnalyticsData(isLoading: true);
    final pb = _ref.read(pocketbaseProvider);
    final auth = _ref.read(authProvider);
    final userId = auth.userId;

    if (userId == null) {
      state = const AnalyticsData();
      return;
    }

    final isClinic = auth.role == UserRole.clinic;
    final ownerField = isClinic ? 'clinic' : 'doctor';
    final planOwnerFilter =
        isClinic ? 'doctor.clinic = "$userId"' : 'doctor = "$userId"';

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Date 30 days ago
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final fromStr =
        '${thirtyDaysAgo.year}-${thirtyDaysAgo.month.toString().padLeft(2, '0')}-${thirtyDaysAgo.day.toString().padLeft(2, '0')}';

    // Helper: safe count
    Future<int> safeCount(String col, String filter) async {
      try {
        final r = await pb
            .collection(col)
            .getList(filter: filter, perPage: 1, skipTotal: false);
        return r.totalItems;
      } catch (e) {
        debugPrint('[Analytics] count error $col: $e');
        return 0;
      }
    }

    // ── Parallel KPI counts ──────────────────────────────────────────────────
    final kpis = await Future.wait([
      safeCount(PBCollections.patients, '$ownerField = "$userId"'), // 0
      safeCount(PBCollections.appointments,
          '$ownerField = "$userId" && date >= "$fromStr"'), // 1 total 30d
      safeCount(PBCollections.appointments,
          '$ownerField = "$userId" && date >= "$fromStr" && status = "completed"'), // 2
      safeCount(PBCollections.appointments,
          '$ownerField = "$userId" && date >= "$fromStr" && status = "cancelled"'), // 3
      safeCount(PBCollections.treatmentPlans,
          '$planOwnerFilter && status = "active"'), // 4
      // consultation type
      safeCount(PBCollections.appointments,
          '$ownerField = "$userId" && date >= "$fromStr" && (type = "call_by" || type = "walk_in")'), // 5
      safeCount(PBCollections.appointments,
          '$ownerField = "$userId" && date >= "$fromStr" && type = "session"'), // 6
      // today
      safeCount(PBCollections.appointments,
          '$ownerField = "$userId" && date = "$todayStr" && status = "scheduled"'), // 7
      safeCount(PBCollections.appointments,
          '$ownerField = "$userId" && date = "$todayStr" && status = "completed"'), // 8
      safeCount(PBCollections.appointments,
          '$ownerField = "$userId" && date = "$todayStr" && status = "cancelled"'), // 9
      // sessions
      safeCount(PBCollections.sessions,
          '$ownerField = "$userId" && status = "completed"'), // 10
      safeCount(PBCollections.sessions,
          '$ownerField = "$userId" && status = "missed"'), // 11
      safeCount(PBCollections.sessions,
          '$ownerField = "$userId" && status = "cancelled"'), // 12
      // consultations
      safeCount(PBCollections.consultations,
          '$ownerField = "$userId"'), // 13 total consultations
      safeCount(PBCollections.treatmentPlans,
          '$planOwnerFilter'), // 14 consultations with plan (approx)
    ]);

    // ── Fetch raw appointments for hourly + 7-day analysis ──────────────────
    List<AppointmentModel> recentAppointments = [];
    try {
      // Fetch up to 500 appointments in the last 30 days for local analysis
      final r = await pb.collection(PBCollections.appointments).getList(
            filter: '$ownerField = "$userId" && date >= "$fromStr"',
            perPage: 500,
            skipTotal: true,
          );
      recentAppointments =
          r.items.map((e) => AppointmentModel.fromRecord(e)).toList();
    } catch (e) {
      debugPrint('[Analytics] fetch appointments error: $e');
    }

    // ── Fetch patients for demographics ─────────────────────────────────────
    List<PatientModel> patients = [];
    try {
      final r = await pb.collection(PBCollections.patients).getList(
            filter: '$ownerField = "$userId"',
            perPage: 500,
            skipTotal: true,
          );
      patients = r.items.map((e) => PatientModel.fromRecord(e)).toList();
    } catch (e) {
      debugPrint('[Analytics] fetch patients error: $e');
    }

    // ── Build 7-day breakdown ────────────────────────────────────────────────
    final dayLabels = <String>[];
    final weeklyScheduled = <int>[];
    final weeklyCompleted = <int>[];
    final weeklyCancelled = <int>[];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      dayLabels.add(days[d.weekday - 1]);
      final dayAppts =
          recentAppointments.where((a) => a.date == dStr).toList();
      weeklyScheduled.add(
          dayAppts.where((a) => a.status == AppointmentStatus.scheduled).length);
      weeklyCompleted.add(
          dayAppts.where((a) => a.status == AppointmentStatus.completed).length);
      weeklyCancelled.add(
          dayAppts.where((a) => a.status == AppointmentStatus.cancelled).length);
    }

    // ── Build hourly distribution ────────────────────────────────────────────
    final hourly = <int, int>{};
    for (final a in recentAppointments) {
      final parts = a.time.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]);
        if (hour != null) {
          hourly[hour] = (hourly[hour] ?? 0) + 1;
        }
      }
    }

    // ── Patient demographics ─────────────────────────────────────────────────
    final gender = <String, int>{'Male': 0, 'Female': 0, 'Other': 0};
    final ageGroup = <String, int>{
      '<20': 0,
      '20-40': 0,
      '40-60': 0,
      '>60': 0
    };
    final location = <String, int>{};

    for (final p in patients) {
      // Gender
      final g = (p.gender ?? '').toLowerCase();
      if (g == 'male') {
        gender['Male'] = gender['Male']! + 1;
      } else if (g == 'female') {
        gender['Female'] = gender['Female']! + 1;
      } else {
        gender['Other'] = gender['Other']! + 1;
      }

      // Age group
      final age = p.age ?? 0;
      if (age < 20) {
        ageGroup['<20'] = ageGroup['<20']! + 1;
      } else if (age < 40) {
        ageGroup['20-40'] = ageGroup['20-40']! + 1;
      } else if (age < 60) {
        ageGroup['40-60'] = ageGroup['40-60']! + 1;
      } else {
        ageGroup['>60'] = ageGroup['>60']! + 1;
      }

      // Location (prefer city, fallback area, fallback address)
      final loc =
          (p.city?.trim().isNotEmpty == true ? p.city! : p.area?.trim().isNotEmpty == true ? p.area! : 'Unknown')
              .trim();
      if (loc.isNotEmpty) {
        location[loc] = (location[loc] ?? 0) + 1;
      }
    }

    // Sort location by count, take top 6
    final sortedLoc = Map.fromEntries(
      location.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    final top6Loc = Map.fromEntries(sortedLoc.entries.take(6));

    state = AnalyticsData(
      totalPatients: kpis[0],
      totalAppointments: kpis[1],
      completedAppointments: kpis[2],
      cancelledAppointments: kpis[3],
      activeTreatmentPlans: kpis[4],
      consultationCount: kpis[5],
      sessionAppointmentCount: kpis[6],
      todayScheduled: kpis[7],
      todayCompleted: kpis[8],
      todayCancelled: kpis[9],
      sessionsCompleted: kpis[10],
      sessionsMissed: kpis[11],
      sessionsCancelled: kpis[12],
      totalConsultations: kpis[13],
      consultationsWithPlan: kpis[14],
      weeklyDayLabels: dayLabels,
      weeklyScheduled: weeklyScheduled,
      weeklyCompleted: weeklyCompleted,
      weeklyCancelled: weeklyCancelled,
      hourlyDistribution: hourly,
      genderDistribution: gender,
      ageGroupDistribution: ageGroup,
      locationDistribution: top6Loc,
      isLoading: false,
    );
  }
}

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsData>((ref) {
  final n = AnalyticsNotifier(ref);
  n.load();
  return n;
});
