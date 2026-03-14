import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/appointment_service.dart';
import '../models/appointment_model.dart';
import '../../scheduling/providers/scheduling_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';

/// Provides the [AppointmentService] singleton.
final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  final pb = ref.watch(pocketbaseProvider);
  return AppointmentService(pb);
});

/// State class for appointment list.
class AppointmentListState {
  final bool isLoading;
  final List<AppointmentModel> appointments;
  final String? error;
  final String selectedDate; // YYYY-MM-DD

  const AppointmentListState({
    this.isLoading = false,
    this.appointments = const [],
    this.error,
    required this.selectedDate,
  });

  AppointmentListState copyWith({
    bool? isLoading,
    List<AppointmentModel>? appointments,
    String? error,
    String? selectedDate,
  }) {
    return AppointmentListState(
      isLoading: isLoading ?? this.isLoading,
      appointments: appointments ?? this.appointments,
      error: error,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }
}

/// Manages appointment list state.
class AppointmentListNotifier extends StateNotifier<AppointmentListState> {
  final AppointmentService _service;
  final Ref _ref;
  final AuthState _authState;

  AppointmentListNotifier(this._service, this._ref, this._authState)
      : super(AppointmentListState(selectedDate: _todayString())) {
    loadAppointments();
  }

  Future<void> loadAppointments({String? date}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final filterDate = date ?? state.selectedDate;
      List<AppointmentModel> result;

      if (_authState.role == UserRole.clinic && _authState.userId != null) {
        result = await _service.getClinicAppointments(
          _authState.userId!,
          dateFilter: filterDate,
        );
      } else if (_authState.userId != null) {
        result = await _service.getDoctorAppointments(
          _authState.userId!,
          dateFilter: filterDate,
        );
      } else {
        result = [];
      }

      state = state.copyWith(
        isLoading: false,
        appointments: result,
        selectedDate: filterDate,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> changeDate(String date) async {
    await loadAppointments(date: date);
  }

  Future<AppointmentModel?> createCallBy({
    required String doctorId,
    String? clinicId,
    required String patientName,
    required String patientPhone,
    required String date,
    required String time,
  }) async {
    try {
      final schedulingService = _ref.read(schedulingServiceProvider);
      final isBooked = await schedulingService.isSlotBooked(doctorId, date, time);
      if (isBooked) {
        state = state.copyWith(error: 'This time slot is already booked.');
        return null;
      }

      final appointment = await _service.createCallByAppointment(
        doctorId: doctorId,
        clinicId: clinicId,
        patientName: patientName,
        patientPhone: patientPhone,
        date: date,
        time: time,
      );
      await loadAppointments();
      return appointment;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<AppointmentModel?> createWalkIn({
    required String doctorId,
    String? clinicId,
    required String date,
    required String time,
    String? patientName,
    String? patientPhone,
    String? dateOfBirth,
    String? address,
    String? emergencyContact,
    String? allergiesConditions,
    String? gender,
    String? occupation,
    String? email,
    int? age,
  }) async {
    try {
      final schedulingService = _ref.read(schedulingServiceProvider);
      final isBooked = await schedulingService.isSlotBooked(doctorId, date, time);
      if (isBooked) {
        state = state.copyWith(error: 'This time slot is already booked.');
        return null;
      }

      String? patientId;
      if (patientName != null && patientName.isNotEmpty) {
        final patient = await _service.createPatient(
          fullName: patientName,
          phone: patientPhone ?? '',
          doctorId: doctorId,
          clinicId: clinicId,
          dateOfBirth: dateOfBirth,
          address: address,
          emergencyContact: emergencyContact,
          allergiesConditions: allergiesConditions,
          gender: gender,
          occupation: occupation,
          email: email,
          age: age,
        );
        patientId = patient.id;
      }

      final appointment = await _service.createWalkInAppointment(
        doctorId: doctorId,
        clinicId: clinicId,
        date: date,
        time: time,
        patientName: patientName,
        patientPhone: patientPhone,
        patientId: patientId, // Pass patientId here
      );
      
      // Auto-link patient to appointment if one was created
      if (patientId != null) {
        await _service.linkPatient(appointment.id, patientId);
      }

      await loadAppointments();
      return appointment;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> updateStatus(
      String appointmentId, AppointmentStatus status) async {
    try {
      await _service.updateStatus(appointmentId, status);
      await loadAppointments();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// The main appointment list provider.
final appointmentListProvider =
    StateNotifierProvider<AppointmentListNotifier, AppointmentListState>((ref) {
  final service = ref.watch(appointmentServiceProvider);
  final auth = ref.watch(authProvider);
  return AppointmentListNotifier(service, ref, auth);
});
