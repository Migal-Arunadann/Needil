import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/scheduling_service.dart';
import '../../auth/models/doctor_model.dart';

/// Provides the [SchedulingService] singleton.
final schedulingServiceProvider = Provider<SchedulingService>((ref) {
  final pb = ref.watch(pocketbaseProvider);
  return SchedulingService(pb);
});

// ─── Available Slots State ───────────────────────────────────

class AvailableSlotsState {
  final bool isLoading;
  final List<TimeSlot> slots;
  final List<WorkingSchedule> schedules;
  final String? error;
  final DateTime? selectedDate;

  const AvailableSlotsState({
    this.isLoading = false,
    this.slots = const [],
    this.schedules = const [],
    this.error,
    this.selectedDate,
  });

  AvailableSlotsState copyWith({
    bool? isLoading,
    List<TimeSlot>? slots,
    List<WorkingSchedule>? schedules,
    String? error,
    DateTime? selectedDate,
  }) {
    return AvailableSlotsState(
      isLoading: isLoading ?? this.isLoading,
      slots: slots ?? this.slots,
      schedules: schedules ?? this.schedules,
      error: error,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  int get availableCount => slots.where((s) => s.isAvailable).length;
  int get bookedCount =>
      slots.where((s) => !s.isAvailable && !s.isDuringBreak).length;
}

class AvailableSlotsNotifier extends StateNotifier<AvailableSlotsState> {
  final SchedulingService _service;

  AvailableSlotsNotifier(this._service) : super(const AvailableSlotsState());

  Future<void> loadSlots({
    required String doctorId,
    required DateTime date,
    List<WorkingSchedule>? schedules,
    int slotDurationMinutes = 30,
  }) async {
    state = state.copyWith(isLoading: true, error: null, selectedDate: date);
    try {
      List<WorkingSchedule> activeSchedules = schedules ?? state.schedules;
      
      // Lazy load schedules if empty and no param was passed
      if (activeSchedules.isEmpty) {
        activeSchedules = await _service.getDoctorSchedules(doctorId);
      }

      final slots = await _service.getAvailableSlots(
        doctorId: doctorId,
        date: date,
        schedules: activeSchedules,
        slotDurationMinutes: slotDurationMinutes,
      );
      state = state.copyWith(isLoading: false, slots: slots, schedules: activeSchedules);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final availableSlotsProvider =
    StateNotifierProvider<AvailableSlotsNotifier, AvailableSlotsState>((ref) {
  final service = ref.watch(schedulingServiceProvider);
  return AvailableSlotsNotifier(service);
});
