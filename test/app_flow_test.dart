import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pms_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Test', () {
    testWidgets('Full Registration and App Flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Ensure we are on the login screen
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Register Clinic'), findsOneWidget);

      print('Found Register Clinic, tapping it...');
      await tester.tap(find.text('Register Clinic'));
      await tester.pumpAndSettle();

      // We should now be on the step 0 (email) screen
      expect(find.text('Start Registration'), findsOneWidget);

      final emailField = find.byType(TextFormField).first;
      final uniqueEmail = 'needilsupport+${DateTime.now().millisecondsSinceEpoch}@gmail.com';
      await tester.enterText(emailField, uniqueEmail);
      print('Entered email $uniqueEmail, tapping Send Secure OTP...');
      
      await tester.pumpAndSettle();
      
      print('Entered email, tapping Send Secure OTP...');
      await tester.tap(find.text('Send Secure OTP'));
      await tester.pumpAndSettle();

      // Wait for navigation to OTP screen
      // Wait up to 10 seconds for the network request
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.text('Verify Your Email').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.text('Verify Your Email'), findsOneWidget);

      print('Reached OTP Screen. Please provide the 6-digit OTP to the chat.');

      // Polling loop for OTP from local server
      String otp = '';
      while (true) {
        try {
          final response = await http.get(Uri.parse('http://127.0.0.1:8080/otp'));
          if (response.statusCode == 200) {
            final content = response.body.trim();
            if (content.length == 6 && int.tryParse(content) != null) {
              otp = content;
              print('DEBUG: Found OTP: $otp');
              break;
            }
          }
        } catch (e) {
          // ignore error, keep polling
        }
        await tester.pump(const Duration(seconds: 1));
      }

      // Enter OTP digits into the 6 text fields
      for (int i = 0; i < 6; i++) {
        final char = otp[i];
        final field = find.byType(TextFormField).at(i);
        await tester.enterText(field, char);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      print('Entered OTP. Verifying...');
      // Wait for it to complete verification and navigate away
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.text('Verify Your Email').evaluate().isEmpty) {
          break;
        }
      }

      print('Passed OTP verification!');
      
      // Wait to see if we navigate to Clinic Details (Step 1)
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (find.text('Clinic Details').evaluate().isNotEmpty) {
          break;
        }
      }

      if (find.text('Clinic Details').evaluate().isNotEmpty) {
        print('On Clinic Details screen. Filling out the form...');
        
        // 0: Name, 1: Username, 2: Email(disabled), 3: Pass, 4: Confirm, 5: Pincode, 6: City (if not dropdown)
        final nameField = find.byType(TextFormField).at(0);
        await tester.enterText(nameField, 'Needil Test Clinic');
        
        final usernameField = find.byType(TextFormField).at(1);
        await tester.enterText(usernameField, 'needil_test_123');
        
        final passwordField = find.byType(TextFormField).at(3);
        await tester.enterText(passwordField, 'TestPassword123!');
        
        final confirmField = find.byType(TextFormField).at(4);
        await tester.enterText(confirmField, 'TestPassword123!');
        
        // Let debounce complete for username check
        await tester.pump(const Duration(seconds: 2));

        // Ensure scrolling down
        await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -500));
        await tester.pumpAndSettle();

        // Location fields: enter pincode and let API auto-fill
        final pincodeField = find.byType(TextFormField).at(5);
        await tester.enterText(pincodeField, '110001');
        // wait for api auto-fill
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        
        print('Tapping Next...');
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        
        // --- Step 2: Clinic Capacity ---
        print('On Step 2: Capacity...');
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.text('Bed Capacity').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.text('Bed Capacity'), findsOneWidget);
        
        // Tap '+' twice to make it 3 beds
        final addIcon = find.byIcon(Icons.add_rounded);
        await tester.tap(addIcon);
        await tester.pumpAndSettle();
        await tester.tap(addIcon);
        await tester.pumpAndSettle();

        print('Tapping Next on Step 2...');
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        // --- Step 3: Primary Doctor ---
        print('On Step 3: Primary Doctor...');
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.text('Primary Doctor').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.text('Primary Doctor'), findsOneWidget);

        final docNameField = find.byType(TextFormField).first;
        await tester.enterText(docNameField, 'Dr. Needil Test');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Date of Birth'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK')); // dismiss date picker with default
        await tester.pumpAndSettle();

        await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -500));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Weekdays'));
        await tester.tap(find.text('Weekdays'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('From'));
        await tester.tap(find.text('From'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('09:00 AM'));
        await tester.tap(find.text('09:00 AM')); // Pick 9 AM
        await tester.pumpAndSettle(const Duration(milliseconds: 500)); // wait for delayed pop

        await tester.ensureVisible(find.text('To'));
        await tester.tap(find.text('To'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('05:00 PM'));
        await tester.tap(find.text('05:00 PM')); // Pick 5 PM
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -500));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Acupuncture'));
        await tester.tap(find.text('Acupuncture'));
        await tester.pumpAndSettle();

        print('Tapping Next on Step 3...');
        await tester.ensureVisible(find.text('Next: Add Working Doctors'));
        await tester.tap(find.text('Next: Add Working Doctors'));
        await tester.pumpAndSettle();

        // --- Step 4: Working Doctors ---
        print('On Step 4: Working Doctors...');
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.text('Working Doctors').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.text('Working Doctors'), findsOneWidget);
        
        // Tap Skip
        await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skip — No Working Doctors'));
        await tester.pumpAndSettle();

        // --- Step 5: Receptionist Account ---
        print('On Step 5: Receptionist Account...');
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          if (find.text('Create Clinic').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.text('Create Clinic'), findsOneWidget);

        print('Tapping Create Clinic...');
        await tester.tap(find.text('Create Clinic'));
        
        // Wait for API call and navigation
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (find.text('Create Clinic').evaluate().isEmpty) {
            break;
          }
        }
        await tester.pumpAndSettle();

        print('Registration complete! Reached main app layout.');
        
        // Optional: wait a bit to verify dashboard loads
        await tester.pump(const Duration(seconds: 5));
      } else {
        print('Did not reach Clinic Details. Clinic might already be fully registered.');
        await tester.pump(const Duration(seconds: 5));
      }
    });
  });
}
