import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/auth/models/receptionist_model.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/services/appointment_service.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/appointments/providers/appointment_provider.dart';
import 'package:pms_app/features/settings/screens/edit_profile_screen.dart';
import 'package:pms_app/features/settings/screens/privacy_security_screen.dart';
import 'package:pms_app/features/settings/screens/settings_screen.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/patients/screens/patient_profile_screen.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';

class MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  MockAuthNotifier(AuthState initial) : super(initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final mockReceptionist = ReceptionistModel(
    id: 'rec_123',
    name: 'Sarah Connor',
    username: 'sarah_desk',
    phone: '9876543210',
    clinicId: 'clinic_abc',
    isActive: true,
    receptionistId: 'REC-001',
    photoUrl: null,
  );

  final receptionistAuthState = AuthState(
    isInitializing: false,
    isAuthenticated: true,
    role: UserRole.receptionist,
    receptionist: mockReceptionist,
  );

  group('Receptionist Profile & Settings Tests', () {
    testWidgets('EditProfileScreen renders only receptionist fields when logged in as receptionist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(receptionistAuthState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Edit Receptionist Profile'), findsOneWidget);
      expect(find.text('Front Desk Staff Profile'), findsOneWidget);

      // Check pre-populated fields
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);

      // Check read-only account details
      expect(find.text('@sarah_desk'), findsOneWidget);
      expect(find.text('REC-001'), findsOneWidget);
      expect(find.text('Front Desk / Receptionist'), findsOneWidget);

      // Check Save button
      expect(find.text('Save Changes'), findsOneWidget);

      // Verify doctor and clinic specific fields are NOT rendered
      expect(find.text('Clinic Information'), findsNothing);
      expect(find.text('Doctor Information'), findsNothing);
      expect(find.text('Bed Count'), findsNothing);
      expect(find.text('Patient ID Prefix (e.g. HSK)'), findsNothing);
      expect(find.text('Age'), findsNothing);
      expect(find.text('Date of Birth (DD/MM/YYYY)'), findsNothing);
    });

    testWidgets('SettingsScreen customizes options specifically for Receptionist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(receptionistAuthState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Hero card contains Receptionist identity
      expect(find.text('Sarah Connor'), findsWidgets);
      expect(find.text('@sarah_desk'), findsWidgets);
      expect(find.text('RECEPTIONIST'), findsWidgets);
      expect(find.text('ID: REC-001'), findsWidgets);

      // Verify Staff Information section
      expect(find.text('Staff Information'), findsOneWidget);
      expect(find.text('Staff ID'), findsOneWidget);

      // Verify common settings exist
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Privacy & Security'), findsOneWidget);
      expect(find.text('About Needil'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Verify Clinic and Doctor management sections are NOT visible
      expect(find.text('Clinic Management'), findsNothing);
      expect(find.text('Manage Doctors'), findsNothing);
      expect(find.text('Manage Receptionist'), findsNothing);
      expect(find.text('Doctor Leaves & Clinic Holidays'), findsNothing);
      expect(find.text('Delete Clinic Account'), findsNothing);
      expect(find.text('Professional Practice'), findsNothing);
      expect(find.text('Edit Schedule & Treatments'), findsNothing);
    });

    testWidgets('PrivacySecurityScreen shows Receptionist account info and hides Google link', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(receptionistAuthState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PrivacySecurityScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Account section displays Receptionist info
      expect(find.text('Receptionist / Staff'), findsOneWidget);
      expect(find.text('sarah_desk'), findsOneWidget);
      expect(find.text('REC-001'), findsOneWidget);

      // Verify Google connected account switch is hidden for staff
      expect(find.text('Connected Accounts'), findsNothing);
    });

    test('AppointmentListNotifier loads clinic appointments for receptionist', () async {
      String? requestedClinicId;
      String? requestedDoctorId;

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(receptionistAuthState)),
          appointmentServiceProvider.overrideWithValue(
            _MockAppointmentService(
              onGetClinicAppointments: (clinicId, dateFilter) {
                requestedClinicId = clinicId;
                return Future.value([
                  AppointmentModel(
                    id: 'apt_1',
                    date: '2026-08-24',
                    time: '10:00',
                    patientName: 'Alice',
                    patientPhone: '9999999999',
                    type: AppointmentType.callBy,
                    status: AppointmentStatus.scheduled,
                    doctorId: 'doc_1',
                    clinicId: clinicId,
                  ),
                ]);
              },
              onGetDoctorAppointments: (doctorId, dateFilter) {
                requestedDoctorId = doctorId;
                return Future.value([]);
              },
            ),
          ),
        ],
      );

      final state = container.read(appointmentListProvider);
      expect(state.isLoading, true);

      // Wait for initial load
      await Future.delayed(const Duration(milliseconds: 50));

      final updatedState = container.read(appointmentListProvider);
      expect(updatedState.isLoading, false);
      expect(updatedState.appointments.length, 1);
      expect(updatedState.appointments.first.patientName, 'Alice');
      expect(requestedClinicId, 'clinic_abc');
      expect(requestedDoctorId, isNull);
    });

    testWidgets('PatientProfileScreen hides Treatments tab and shows only History and Details for Receptionist', (tester) async {
      final testPatient = PatientModel(
        id: 'pat_001',
        fullName: 'Jane Doe',
        phone: '9876543210',
        gender: 'female',
        age: 28,
        doctorId: 'doc_123',
        clinicId: 'clinic_abc',
      );

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(receptionistAuthState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PatientProfileScreen(patient: testPatient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On mobile for Receptionist:
      expect(find.text('History'), findsWidgets);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Treatments'), findsNothing);
    });

    testWidgets('PatientProfileScreen shows single History tab in right pane on Desktop for Receptionist', (tester) async {
      final testPatient = PatientModel(
        id: 'pat_001',
        fullName: 'Jane Doe',
        phone: '9876543210',
        gender: 'female',
        age: 28,
        doctorId: 'doc_123',
        clinicId: 'clinic_abc',
      );

      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(receptionistAuthState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PatientProfileScreen(patient: testPatient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On desktop for Receptionist:
      expect(find.text('History'), findsWidgets);
      expect(find.text('Treatments'), findsNothing);
      expect(find.text('Book Appointment'), findsOneWidget);
    });

    testWidgets('PatientProfileScreen shows Treatments, History, and Details for Doctor', (tester) async {
      final mockDoctor = DoctorModel(
        id: 'doc_123',
        name: 'Dr. Gregory House',
        age: 45,
        username: 'dr_house',
        email: 'house@clinic.com',
        phone: '9876543210',
        clinicId: 'clinic_abc',
        workingSchedule: [],
        treatments: [],
      );

      final doctorAuthState = AuthState(
        isInitializing: false,
        isAuthenticated: true,
        role: UserRole.doctor,
        doctor: mockDoctor,
      );

      final testPatient = PatientModel(
        id: 'pat_001',
        fullName: 'Jane Doe',
        phone: '9876543210',
        gender: 'female',
        age: 28,
        doctorId: 'doc_123',
        clinicId: 'clinic_abc',
      );

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(doctorAuthState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PatientProfileScreen(patient: testPatient),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On mobile for Doctor:
      expect(find.text('Treatments'), findsOneWidget);
      expect(find.text('History'), findsWidgets);
      expect(find.text('Details'), findsOneWidget);
    });
  });
}

class _MockAppointmentService implements AppointmentService {
  final Future<List<AppointmentModel>> Function(String clinicId, String? dateFilter)? onGetClinicAppointments;
  final Future<List<AppointmentModel>> Function(String doctorId, String? dateFilter)? onGetDoctorAppointments;

  _MockAppointmentService({
    this.onGetClinicAppointments,
    this.onGetDoctorAppointments,
  });

  @override
  Future<List<AppointmentModel>> getClinicAppointments(String clinicId, {String? dateFilter}) {
    if (onGetClinicAppointments != null) {
      return onGetClinicAppointments!(clinicId, dateFilter);
    }
    return Future.value([]);
  }

  @override
  Future<List<AppointmentModel>> getDoctorAppointments(String doctorId, {String? dateFilter}) {
    if (onGetDoctorAppointments != null) {
      return onGetDoctorAppointments!(doctorId, dateFilter);
    }
    return Future.value([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
