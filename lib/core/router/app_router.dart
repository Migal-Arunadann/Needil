import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/clinic_registration/clinic_step0_otp_screen.dart';
import '../../features/auth/screens/clinic_registration/clinic_step1_screen.dart';
import '../../features/auth/screens/clinic_registration/clinic_step2_screen.dart';
import '../../features/auth/screens/clinic_registration/clinic_step3_screen.dart';
import '../../features/auth/screens/clinic_registration/clinic_step4_screen.dart';
import '../../features/auth/screens/clinic_registration/clinic_step5_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/dashboard/screens/main_layout.dart';
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
import '../../features/patients/screens/patient_profile_screen.dart';
import '../../features/patients/models/patient_model.dart';

/// Named route generator for the app.
Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
    case '/login':
      return _fade(const LoginScreen(), settings);

    // Register link now goes directly to clinic registration step 0
    case '/register/clinic':
    case '/register/clinic/step0':
      return _slide(const ClinicStep0OtpScreen(), settings);

    case '/register/clinic/step1':
      return _slide(const ClinicStep1Screen(), settings);

    case '/register/clinic/step2':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(ClinicStep2Screen(clinicData: args), settings);

    case '/register/clinic/step3':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(ClinicStep3Screen(clinicData: args), settings);

    case '/register/clinic/step4':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(ClinicStep4Screen(clinicData: args), settings);

    case '/register/clinic/step5':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(ClinicStep5Screen(clinicData: args), settings);

    case '/auth/otp-verify':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(
        OtpVerificationScreen(
          mode: args['mode'] as OtpMode,
          email: args['email'] as String,
          clinicData: args['clinic_data'] as Map<String, dynamic>?,
        ),
        settings,
      );

    case '/auth/forgot-password':
      return _slide(const ForgotPasswordScreen(), settings);

    case '/auth/reset-password':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(
        ResetPasswordScreen(
          otpCode: args['otp_code'] as String,
          otpId: args['otp_id'] as String?,
        ),
        settings,
      );

    case '/dashboard':
      return _fade(MainLayout(), settings);

    case '/appointments':
      return _slide(const AppointmentListScreen(), settings);

    case '/appointments/create':
      final args = settings.arguments as Map<String, dynamic>? ?? {};
      return _slide(
          CreateAppointmentScreen(initialIsCallBy: args['isCallBy'] ?? true),
          settings);

    case '/appointments/patient-info':
      final apt = settings.arguments as AppointmentModel;
      return _slide(PatientInfoScreen(appointment: apt), settings);

    case '/consultation':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(
        ConsultationScreen(
          patientId: args['patientId'] as String,
          patientName: args['patientName'] as String,
          doctorId: args['doctorId'] as String,
          consultationId: args['consultationId'] as String?,
          isViewMode: args['isViewMode'] as bool? ?? false,
        ),
        settings,
      );

    case '/treatment-plan/create':
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(
        CreateTreatmentPlanScreen(
          patientId: args['patientId'] as String,
          patientName: args['patientName'] as String,
          doctorId: args['doctorId'] as String,
          consultationId: args['consultationId'] as String?,
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
      final args = settings.arguments as Map<String, dynamic>? ?? {};
      return _slide(
        AvailableSlotsScreen(
          doctorId: args['doctorId'] ?? '',
          clinicId: args['clinicId'],
          treatmentDuration: args['treatmentDuration'] ?? 30,
        ),
        settings,
      );

    case '/patient-profile':
      final patient = settings.arguments as PatientModel;
      return _slide(PatientProfileScreen(patient: patient), settings);

    case '/settings':
      return _slide(const SettingsScreen(), settings);

    case '/consent':
      return _slide(const ConsentScreen(), settings);

    default:
      return _fade(const LoginScreen(), settings);
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
