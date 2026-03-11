import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/clinic_registration/clinic_step1_screen.dart';
import '../../features/auth/screens/clinic_registration/clinic_step2_screen.dart';
import '../../features/auth/screens/clinic_registration/clinic_step3_screen.dart';
import '../../features/auth/screens/doctor_registration/doctor_registration_screen.dart';
import '../../features/dashboard/screens/clinic_dashboard_screen.dart';
import '../../features/appointments/screens/appointment_list_screen.dart';
import '../../features/appointments/screens/create_appointment_screen.dart';
import '../../features/appointments/screens/patient_info_screen.dart';
import '../../features/appointments/models/appointment_model.dart';
import '../../features/consultations/screens/consultation_screen.dart';
import '../../features/treatments/screens/create_treatment_plan_screen.dart';
import '../../features/treatments/screens/session_list_screen.dart';
import '../../features/treatments/screens/record_session_screen.dart';
import '../../features/treatments/models/treatment_plan_model.dart';
import '../../features/treatments/models/session_model.dart';
import '../../features/scheduling/screens/available_slots_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/consent_screen.dart';

/// Named route generator for the app.
Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
    case '/login':
      return _fade(const LoginScreen(), settings);

    case '/register':
      return _slide(const RoleSelectionScreen(), settings);

    case '/register/clinic':
      return _slide(const ClinicStep1Screen(), settings);

    case '/register/clinic/step2':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(ClinicStep2Screen(clinicData: args), settings);

    case '/register/clinic/step3':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(ClinicStep3Screen(clinicData: args), settings);

    case '/register/doctor':
      return _slide(const DoctorRegistrationScreen(), settings);

    case '/dashboard':
      return _fade(const _DashboardRouter(), settings);

    case '/appointments':
      return _slide(const AppointmentListScreen(), settings);

    case '/appointments/create':
      return _slide(const CreateAppointmentScreen(), settings);

    case '/appointments/patient-info':
      final apt = settings.arguments as AppointmentModel;
      return _slide(PatientInfoScreen(appointment: apt), settings);

    case '/consultation':
      final args = settings.arguments as Map<String, String>;
      return _slide(
        ConsultationScreen(
          patientId: args['patientId']!,
          patientName: args['patientName']!,
        ),
        settings,
      );

    case '/treatment-plan/create':
      final args = settings.arguments as Map<String, String>;
      return _slide(
        CreateTreatmentPlanScreen(
          patientId: args['patientId']!,
          patientName: args['patientName']!,
          consultationId: args['consultationId'],
        ),
        settings,
      );

    case '/treatment-plan/sessions':
      final plan = settings.arguments as TreatmentPlanModel;
      return _slide(SessionListScreen(plan: plan), settings);

    case '/sessions/record':
      final session = settings.arguments as SessionModel;
      return _slide(RecordSessionScreen(session: session), settings);

    case '/available-slots':
      return _slide(const AvailableSlotsScreen(), settings);

    case '/settings':
      return _slide(const SettingsScreen(), settings);

    case '/consent':
      return _slide(const ConsentScreen(), settings);

    default:
      return _fade(const LoginScreen(), settings);
  }
}

/// Decides which dashboard to show based on auth state.
/// This is a simple widget that reads the role from route args or auth state.
class _DashboardRouter extends StatelessWidget {
  const _DashboardRouter();

  @override
  Widget build(BuildContext context) {
    // We'll use a Consumer in app.dart to determine the correct dashboard.
    // For now, default to clinic.
    return const ClinicDashboardScreen();
  }
}

// Route animations
PageRouteBuilder _fade(Widget page, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, a, b) => page,
    transitionsBuilder: (_, animation, secondaryAnim, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 250),
  );
}

PageRouteBuilder _slide(Widget page, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, a, b) => page,
    transitionsBuilder: (_, animation, secondaryAnim, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}
