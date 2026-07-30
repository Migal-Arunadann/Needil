import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/services/appointment_service.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/scheduling/providers/scheduling_provider.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

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
    String? existingPatientId,
    bool isNewFamilyMember = false,
    String? intendedRelation,
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
        isNewFamilyMember: isNewFamilyMember,
        intendedRelation: intendedRelation,
      );

      // ── Returning patient auto-link ────────────────────────────────────────────────
      // If existingPatientId is explicitly provided, link it immediately.
      // Otherwise, if EXACTLY ONE patient with this phone exists, and it's not a new
      // family member, link them immediately.
      try {
        if (existingPatientId != null && existingPatientId.isNotEmpty) {
          await _service.linkPatient(appointment.id, existingPatientId, setArrived: false);
          await _service.markPatientDetailsSaved(appointment.id);
        } else if (!isNewFamilyMember) {
          final matches = await _service.findAllPatientsByPhone(
            patientPhone,
            doctorId,
            clinicId: clinicId,
          );
          if (matches.length == 1) {
            // setArrived:false — this is at creation time, patient hasn't arrived yet
            await _service.linkPatient(appointment.id, matches.first.id, setArrived: false);
            await _service.markPatientDetailsSaved(appointment.id);
          }
        }
      } catch (_) {
        // Non-fatal: if lookup fails, the receptionist can still use "Fill Details"
      }
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
    String? city,
    String? area,
    String? address,
    String? pincode,
    String? emergencyContact,
    String? allergiesConditions,
    String? chronicDiseases,
    String? gender,
    String? occupation,
    String? email,
    int? age,
    String? existingPatientId, // If set, skip patient creation and reuse this ID
    String? reference,
    String? relationToPrimary,
    String? howDidYouHear,
    String? photoPath,
    bool consentGiven = true,
    bool privacyPolicyAccepted = false,
  }) async {
    try {
      final schedulingService = _ref.read(schedulingServiceProvider);
      final isBooked = await schedulingService.isSlotBooked(doctorId, date, time);
      if (isBooked) {
        state = state.copyWith(error: 'This time slot is already booked.');
        return null;
      }

      String? patientId = existingPatientId; // reuse existing patient record
      if (patientId == null && patientName != null && patientName.isNotEmpty) {
        // Only create a new patient record if no existing one was found
        final patient = await _service.createPatient(
          fullName: patientName,
          phone: patientPhone ?? '',
          doctorId: doctorId,
          clinicId: clinicId,
          dateOfBirth: dateOfBirth,
          city: city,
          area: area,
          address: address,
          pincode: pincode,
          emergencyContact: emergencyContact,
          allergiesConditions: chronicDiseases != null && chronicDiseases.isNotEmpty
              ? [if (allergiesConditions != null && allergiesConditions.isNotEmpty) allergiesConditions, 'Chronic: $chronicDiseases'].join(' | ')
              : allergiesConditions,
          gender: gender,
          occupation: occupation,
          email: email,
          age: age,
          reference: reference,
          relationToPrimary: relationToPrimary,
          howDidYouHear: howDidYouHear,
          photoPath: photoPath,
          consentGiven: consentGiven,
          privacyPolicyAccepted: privacyPolicyAccepted,
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
        // setArrived:false — walk-in already sets status=waiting at creation
        await _service.linkPatient(appointment.id, patientId, setArrived: false);
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

  Future<void> reopenMissedAppointment(String appointmentId) async {
    try {
      await _service.reopenMissedAppointment(appointmentId);
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
