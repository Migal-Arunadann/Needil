import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/auth/widgets/brand_panel.dart';
import 'package:pms_app/features/auth/screens/login_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_deletion_screen.dart';
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
import 'package:pms_app/features/dashboard/screens/clinic_dashboard_screen.dart';
import 'package:pms_app/features/dashboard/screens/doctor_dashboard_screen.dart';
import 'package:pms_app/features/dashboard/screens/receptionist_dashboard_screen.dart';
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
import 'package:pms_app/features/patients/screens/patient_list_screen.dart';
import 'package:pms_app/features/patients/screens/patient_profile_screen.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/analytics/screens/analytics_screen.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_login_screen.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_shell.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_clinic_detail_screen.dart';
import 'package:pms_app/features/billing/screens/billing_screen.dart';
import 'package:pms_app/features/billing/screens/subscription_locked_screen.dart';
import 'package:pms_app/features/scheduling/screens/scheduling_exceptions_screen.dart';
import 'package:pms_app/features/scheduling/screens/scheduling_audit_history_screen.dart';
import 'package:pms_app/core/providers/session_lifecycle_provider.dart';
import 'package:pms_app/core/services/appointment_reconciliation_service.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/features/appointments/screens/auto_scheduling_dashboard.dart';

/// Global root navigator key
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Maintain appNavigatorKey alias for backwards compatibility
GlobalKey<NavigatorState> get appNavigatorKey => rootNavigatorKey;

/// Listenable that notifies GoRouter whenever AuthState changes in Riverpod
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (prev, next) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Riverpod provider for GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: routerNotifier,
    initialLocation: '/dashboard',
    redirect: (BuildContext context, GoRouterState state) {
      final auth = ref.read(authProvider);

      if (auth.isInitializing) {
        return null; // Let the builder render splash while initializing
      }

      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' ||
          loc.startsWith('/register') ||
          loc.startsWith('/auth') ||
          loc == '/superadmin/login';

      if (!auth.isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      // Authenticated users
      if (auth.role == UserRole.superadmin) {
        if (loc == '/login' || loc == '/') {
          return '/superadmin/dashboard';
        }
        return null;
      }

      if (auth.role == UserRole.clinic) {
        if (auth.isPendingDeletion && loc != '/deletion') {
          return '/deletion';
        }
        if (auth.clinic != null &&
            auth.clinic!.name.isEmpty &&
            !loc.startsWith('/register')) {
          return '/register/clinic/step1';
        }
        if (auth.clinic != null &&
            !auth.clinic!.isSubscriptionActive &&
            loc != '/subscription-locked' &&
            loc != '/billing') {
          return '/subscription-locked';
        }
      }

      // Staff (Doctor / Receptionist) Lockout: If clinic subscription expired & grace passed
      if (auth.role == UserRole.doctor || auth.role == UserRole.receptionist) {
        if (auth.clinic != null &&
            !auth.clinic!.isSubscriptionActive &&
            loc != '/subscription-locked') {
          return '/subscription-locked';
        }
      }

      // Receptionist Role Guard: Financials, Analytics, and Clinical Recording restricted
      if (auth.role == UserRole.receptionist) {
        if (loc == '/analytics' ||
            loc.startsWith('/analytics') ||
            loc == '/billing' ||
            loc.startsWith('/billing') ||
            loc == '/sessions/record' ||
            loc.startsWith('/sessions/record') ||
            loc == '/consultation' ||
            loc.startsWith('/consultation')) {
          return '/dashboard';
        }
      }

      // Logged in user hitting root or login -> redirect to /dashboard (Home)
      if (loc == '/' || loc == '/login') {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // ── Auth & Onboarding Routes (No Shell) ───────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register/clinic',
        pageBuilder: (context, state) => _slidePage(
          context: context,
          state: state,
          child: const AuthWebShell(child: ClinicStep0OtpScreen()),
        ),
      ),
      GoRoute(
        path: '/register/clinic/step0',
        pageBuilder: (context, state) => _slidePage(
          context: context,
          state: state,
          child: const AuthWebShell(child: ClinicStep0OtpScreen()),
        ),
      ),
      GoRoute(
        path: '/register/clinic/step1',
        pageBuilder: (context, state) => _slidePage(
          context: context,
          state: state,
          child: const AuthWebShell(child: ClinicStep1Screen()),
        ),
      ),
      GoRoute(
        path: '/register/clinic/step2',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: AuthWebShell(child: ClinicStep2Screen(clinicData: args)),
          );
        },
      ),
      GoRoute(
        path: '/register/clinic/step3',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: AuthWebShell(child: ClinicStep3Screen(clinicData: args)),
          );
        },
      ),
      GoRoute(
        path: '/register/clinic/step4',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: AuthWebShell(child: ClinicStep4Screen(clinicData: args)),
          );
        },
      ),
      GoRoute(
        path: '/register/clinic/step5',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: AuthWebShell(child: ClinicStep5Screen(clinicData: args)),
          );
        },
      ),
      GoRoute(
        path: '/auth/otp-verify',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: AuthWebShell(
              child: OtpVerificationScreen(
                mode: args['mode'] as OtpMode? ?? OtpMode.registration,
                email: args['email'] as String? ?? '',
                clinicData: args['clinic_data'] as Map<String, dynamic>?,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/auth/forgot-password',
        pageBuilder: (context, state) => _slidePage(
          context: context,
          state: state,
          child: const AuthWebShell(child: ForgotPasswordScreen()),
        ),
      ),
      GoRoute(
        path: '/auth/reset-password',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: AuthWebShell(
              child: ResetPasswordScreen(
                otpCode: args['otp_code'] as String? ?? '',
                otpId: args['otp_id'] as String?,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/deletion',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const ClinicDeletionScreen(),
        ),
      ),
      GoRoute(
        path: '/subscription-locked',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const SubscriptionLockedScreen(),
        ),
      ),
      GoRoute(
        path: '/superadmin/login',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const SuperadminLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/superadmin/dashboard',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const SuperadminShell(),
        ),
      ),
      GoRoute(
        path: '/superadmin/clinic',
        pageBuilder: (context, state) {
          final clinicId = state.extra as String? ?? '';
          return _slidePage(
            context: context,
            state: state,
            child: SuperadminClinicDetailScreen(clinicId: clinicId),
          );
        },
      ),

      // ── Main Shell with Persistent Sidebar Tabs ────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayout(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard (Home)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: RoleDashboardWrapper(),
                ),
              ),
            ],
          ),
          // Branch 1: Appointments
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/appointments',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AppointmentListScreen(),
                ),
              ),
            ],
          ),
          // Branch 2: Analytics
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AnalyticsScreen(),
                ),
              ),
            ],
          ),
          // Branch 3: Patients
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patients',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: PatientListScreen(),
                ),
              ),
            ],
          ),
          // Branch 4: Profile / Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SettingsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Sub-Screens (Pushed over root navigator) ──────────────────────
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/appointments/create',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: CreateAppointmentScreen(
              initialIsCallBy: args['isCallBy'] ?? true,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/appointments/patient-info',
        pageBuilder: (context, state) {
          final apt = state.extra as AppointmentModel;
          return _slidePage(
            context: context,
            state: state,
            child: PatientInfoScreen(appointment: apt),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/consultation',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: ConsultationScreen(
              patientId: args['patientId'] as String? ?? '',
              patientName: args['patientName'] as String? ?? '',
              doctorId: args['doctorId'] as String? ?? '',
              consultationId: args['consultationId'] as String?,
              isViewMode: args['isViewMode'] as bool? ?? false,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/treatment-plan/create',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: CreateTreatmentPlanScreen(
              patientId: args['patientId'] as String? ?? '',
              patientName: args['patientName'] as String? ?? '',
              doctorId: args['doctorId'] as String? ?? '',
              consultationId: args['consultationId'] as String?,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/treatment-plan/sessions',
        pageBuilder: (context, state) {
          final plan = state.extra as TreatmentPlanModel;
          return _slidePage(
            context: context,
            state: state,
            child: SessionListScreen(plan: plan),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/sessions/record',
        pageBuilder: (context, state) {
          if (state.extra is SessionModel) {
            return _slidePage(
              context: context,
              state: state,
              child: RecordSessionScreen(
                session: state.extra as SessionModel,
              ),
            );
          }
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: RecordSessionScreen(
              session: args['session'] as SessionModel,
              patientName: args['patientName'] as String?,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/available-slots',
        pageBuilder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return _slidePage(
            context: context,
            state: state,
            child: AvailableSlotsScreen(
              doctorId: args['doctorId'] ?? '',
              clinicId: args['clinicId'],
              treatmentDuration: args['treatmentDuration'] ?? 30,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/patient-profile',
        pageBuilder: (context, state) {
          final patient = state.extra as PatientModel?;
          if (patient == null) {
            return _fadePage(
              state: state,
              child: const AppointmentListScreen(),
            );
          }
          return _slidePage(
            context: context,
            state: state,
            child: PatientProfileScreen(patient: patient),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/settings',
        pageBuilder: (context, state) => _slidePage(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/consent',
        pageBuilder: (context, state) => _slidePage(
          context: context,
          state: state,
          child: const ConsentScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/billing',
        pageBuilder: (context, state) => _slidePage(
          context: context,
          state: state,
          child: const BillingScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/scheduling/exceptions',
        pageBuilder: (context, state) => _slidePage(
          context: context,
          state: state,
          child: const SchedulingExceptionsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/scheduling/audit',
        pageBuilder: (context, state) {
          final plan = state.extra as TreatmentPlanModel;
          return _slidePage(
            context: context,
            state: state,
            child: SchedulingAuditHistoryScreen(plan: plan),
          );
        },
      ),
    ],
  );
});

/// Wrapper that renders the active role's dashboard for branch 0,
/// and handles the initial / resumed overdue lifecycle check + auto-opening Needs Attention on the home page.
class RoleDashboardWrapper extends ConsumerStatefulWidget {
  const RoleDashboardWrapper({super.key});

  @override
  ConsumerState<RoleDashboardWrapper> createState() => _RoleDashboardWrapperState();
}

class _RoleDashboardWrapperState extends ConsumerState<RoleDashboardWrapper>
    with WidgetsBindingObserver {
  String? _lifecycleCheckedDate;
  bool _didAutoPopupDashboard = false;

  String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runLifecycleCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _runLifecycleCheck();
    }
  }

  Future<void> _runLifecycleCheck() async {
    final todayStr = _todayDateKey();
    if (_lifecycleCheckedDate == todayStr) return;
    _lifecycleCheckedDate = todayStr;
    _didAutoPopupDashboard = false;

    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    final pb = ref.read(pocketbaseProvider);
    final lifecycle = ref.read(sessionLifecycleServiceProvider);
    final reconciliation = ref.read(appointmentReconciliationServiceProvider);

    if ((auth.role == UserRole.clinic || auth.role == UserRole.receptionist) &&
        auth.clinicId != null) {
      try {
        final docs = await pb.collection('doctors').getList(
          filter: 'clinic = "${auth.clinicId}"',
          perPage: 50,
        );
        for (final doc in docs.items) {
          await lifecycle.flagOverdueSessions(doc.id);
        }
      } catch (_) {}
    } else if (auth.userId != null) {
      await lifecycle.flagOverdueSessions(auth.userId!);
    }

    // Load overdue items
    List<SessionModel> overdueSessions = [];
    List<AppointmentModel> overdueConsultations = [];
    try {
      if ((auth.role == UserRole.clinic || auth.role == UserRole.receptionist) &&
          auth.clinicId != null) {
        overdueSessions = await lifecycle.getOverdueSessionsForClinic(auth.clinicId!);
        overdueConsultations = await reconciliation.getOverdueConsultations(auth.clinicId!, isClinic: true);
      } else if (auth.userId != null) {
        overdueSessions = await lifecycle.getOverdueSessions(auth.userId!);
        overdueConsultations = await reconciliation.getOverdueConsultations(auth.userId!);
      }
    } catch (_) {}

    if (mounted) {
      if ((overdueSessions.isNotEmpty || overdueConsultations.isNotEmpty) &&
          !_didAutoPopupDashboard &&
          !AutoSchedulingDashboard.notificationDismissed.value) {
        _didAutoPopupDashboard = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            AutoSchedulingDashboard.show(
              context,
              overdueSessions: overdueSessions,
              overdueConsultations: overdueConsultations,
              onRefresh: () {
                _lifecycleCheckedDate = null;
                _runLifecycleCheck();
              },
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    switch (role) {
      case UserRole.clinic:
        return const ClinicDashboardScreen();
      case UserRole.doctor:
        return const DoctorDashboardScreen();
      case UserRole.receptionist:
        return const ReceptionistDashboardScreen();
      default:
        return const Center(child: Text('Unknown Role'));
    }
  }
}

// ── Custom Page Transition Helpers ──────────────────────────────────────────
Page<dynamic> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

Page<dynamic> _slidePage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
  );
}

/// Web Shell for Auth Screens
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
