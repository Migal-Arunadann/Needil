import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:pms_app/features/dashboard/widgets/dashboard_widgets.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/appointments/screens/create_appointment_screen.dart';

void main() {
  group('Receptionist Module & Revenue Restriction Tests', () {
    testWidgets('DashboardOverviewSection with showRevenue: false hides revenue and shows Front Desk Queue', (tester) async {
      const mockStats = DashboardStats(
        consultationsTotalToday: 5,
        consultationsCompletedToday: 2,
        consultationsPendingToday: 3,
        sessionsTotalToday: 4,
        sessionsCompletedToday: 1,
        sessionsPendingToday: 3,
        patientsSeenToday: 3,
        patientsExpectedToday: 9,
        patientsRemainingToday: 6,
        feesTotalToday: 5000,
        feesOnlyConsultationToday: 2000,
        feesOnlySessionToday: 3000,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DashboardOverviewSection(
                stats: mockStats,
                showRevenue: false,
              ),
            ),
          ),
        ),
      );

      // Verify Front Desk Queue is rendered
      expect(find.text('Front Desk Queue'), findsOneWidget);
      expect(find.text('Checked In'), findsOneWidget);
      expect(find.text('In Waiting'), findsOneWidget);
      expect(find.text('Total Expected'), findsOneWidget);

      // Verify Revenue is NOT rendered anywhere
      expect(find.text("Today's Revenue"), findsNothing);
      expect(find.text("Total Collected"), findsNothing);
      expect(find.text("₹5000"), findsNothing);
    });

    testWidgets('DashboardOverviewSection with showRevenue: true renders Todays Revenue', (tester) async {
      const mockStats = DashboardStats(
        consultationsTotalToday: 5,
        consultationsCompletedToday: 2,
        consultationsPendingToday: 3,
        sessionsTotalToday: 4,
        sessionsCompletedToday: 1,
        sessionsPendingToday: 3,
        patientsSeenToday: 3,
        patientsExpectedToday: 9,
        patientsRemainingToday: 6,
        feesTotalToday: 5000,
        feesOnlyConsultationToday: 2000,
        feesOnlySessionToday: 3000,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: DashboardOverviewSection(
                stats: mockStats,
                showRevenue: true,
              ),
            ),
          ),
        ),
      );

      // Verify Revenue is rendered
      expect(find.text("Today's Revenue"), findsOneWidget);
      expect(find.text("Total Collected"), findsOneWidget);
      expect(find.text("₹5000"), findsOneWidget);

      // Verify Front Desk Queue is not rendered in this mode
      expect(find.text('Front Desk Queue'), findsNothing);
    });

    testWidgets('CreateAppointmentScreen pre-fills patient fields when initialPatient is provided', (tester) async {
      final mockPatient = PatientModel(
        id: 'pat_123',
        fullName: 'John Doe',
        phone: '+919876543210',
        gender: 'Male',
        age: 30,
        doctorId: 'doc_456',
        city: 'Chennai',
        area: 'Anna Nagar',
        dateOfBirth: '1996-05-15',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: CreateAppointmentScreen(
              initialPatient: mockPatient,
              initialIsCallBy: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify patient name and phone are pre-filled in text fields
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
    });
  });
}
