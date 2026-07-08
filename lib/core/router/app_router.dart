import 'package:flutter/material.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/auth/widgets/brand_panel.dart';
import 'package:pms_app/features/auth/screens/login_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step0_otp_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step1_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step2_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step3_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step4_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step5_screen.dart';
import 'package:pms_app/features/auth/screens/otp_verification_screen.dart';
import 'package:pms_app/features/auth/screens/forgot_password_screen.dart';
import 'package:pms_app/features/auth/screens/reset_password_screen.dart';
import 'package:pms_app/features/dashboard/screens/main_layout.dart';
import 'package:pms_app/features/appointments/screens/appointment_list_screen.dart';
import 'package:pms_app/features/appointments/screens/create_appointment_screen.dart';
import 'package:pms_app/features/appointments/screens/patient_info_screen.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/consultations/screens/consultation_screen.dart';
import 'package:pms_app/features/treatments/screens/create_treatment_plan_screen.dart';
import 'package:pms_app/features/treatments/screens/session_list_screen.dart';
import 'package:pms_app/features/treatments/screens/record_session_screen.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/scheduling/screens/available_slots_screen.dart';
import 'package:pms_app/features/settings/screens/settings_screen.dart';
import 'package:pms_app/features/settings/screens/consent_screen.dart';
import 'package:pms_app/features/patients/screens/patient_profile_screen.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_login_screen.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_clinic_detail_screen.dart';

/// Named route generator for the app.
Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return null;
    case '/login':
      return _fade(const LoginScreen(), settings);

    // Register link now goes directly to clinic registration step 0
    case '/register/clinic':
    case '/register/clinic/step0':
      return _slide(const AuthWebShell(child: ClinicStep0OtpScreen()), settings);

    case '/register/clinic/step1':
      return _slide(const AuthWebShell(child: ClinicStep1Screen()), settings);

    case '/register/clinic/step2':
      if (settings.arguments == null) return _fade(const LoginScreen(), settings);
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(AuthWebShell(child: ClinicStep2Screen(clinicData: args)), settings);

    case '/register/clinic/step3':
      if (settings.arguments == null) return _fade(const LoginScreen(), settings);
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(AuthWebShell(child: ClinicStep3Screen(clinicData: args)), settings);

    case '/register/clinic/step4':
      if (settings.arguments == null) return _fade(const LoginScreen(), settings);
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(AuthWebShell(child: ClinicStep4Screen(clinicData: args)), settings);

    case '/register/clinic/step5':
      if (settings.arguments == null) return _fade(const LoginScreen(), settings);
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(AuthWebShell(child: ClinicStep5Screen(clinicData: args)), settings);

    case '/auth/otp-verify':
      if (settings.arguments == null) return _fade(const LoginScreen(), settings);
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(
        AuthWebShell(
          child: OtpVerificationScreen(
            mode: args['mode'] as OtpMode,
            email: args['email'] as String,
            clinicData: args['clinic_data'] as Map<String, dynamic>?,
          ),
        ),
        settings,
      );

    case '/auth/forgot-password':
      return _slide(const AuthWebShell(child: ForgotPasswordScreen()), settings);

    case '/auth/reset-password':
      if (settings.arguments == null) return _fade(const LoginScreen(), settings);
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(
        AuthWebShell(
          child: ResetPasswordScreen(
            otpCode: args['otp_code'] as String,
            otpId: args['otp_id'] as String?,
          ),
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
      if (settings.arguments is SessionModel) {
        final session = settings.arguments as SessionModel;
        return _slide(RecordSessionScreen(session: session), settings);
      }
      final args = settings.arguments as Map<String, dynamic>;
      return _slide(
        RecordSessionScreen(
          session: args['session'] as SessionModel,
          patientName: args['patientName'] as String?,
        ),
        settings,
      );

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

    case '/superadmin/login':
      return _fade(const SuperadminLoginScreen(), settings);

    case '/superadmin/clinic':
      final clinicId = settings.arguments as String;
      return _slide(SuperadminClinicDetailScreen(clinicId: clinicId), settings);

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
    transitionDuration: const Duration(milliseconds: 200),
  );
}

PageRouteBuilder _slide(Widget page, RouteSettings settings) {
  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (_, a, b) => page,
    transitionsBuilder: (context, animation, secondaryAnim, child) {
      final width = MediaQuery.sizeOf(context).width;
      final isDesktop = width >= 900;

      if (isDesktop) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      }

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 200),
  );
}

class AuthWebShell extends StatelessWidget {
  final Widget child;

  const AuthWebShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    if (!isDesktop) {
      return child;
    }

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            const Expanded(
              flex: 55,
              child: BrandPanel(),
            ),
            Expanded(
              flex: 45,
              child: Container(
                color: Colors.white,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 650 : 420),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
