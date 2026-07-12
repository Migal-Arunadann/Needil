import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/core/services/appointment_reconciliation_service.dart';

final unresolvedAppointmentsProvider = StateNotifierProvider<UnresolvedAppointmentsNotifier, AsyncValue<void>>((ref) {
  final service = ref.watch(appointmentReconciliationServiceProvider);
  return UnresolvedAppointmentsNotifier(service);
});

class UnresolvedAppointmentsNotifier extends StateNotifier<AsyncValue<void>> {
  final AppointmentReconciliationService _service;

  UnresolvedAppointmentsNotifier(this._service) : super(const AsyncValue.loading()) {
    checkAndReconcile();
  }

  Future<void> checkAndReconcile() async {
    state = const AsyncValue.loading();
    try {
      await _service.reconcileAppointments();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
