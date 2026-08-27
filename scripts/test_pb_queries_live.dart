import 'dart:io';
import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';

Future<void> main(List<String> args) async {
  String email = '';
  String password = '';
  final pbUrl = 'https://api.needil.com';

  stdout.write('📧 Enter Superadmin Email: ');
  email = stdin.readLineSync()?.trim() ?? '';
  stdout.write('🔑 Enter Superadmin Password: ');
  try {
    stdin.echoMode = false;
    password = stdin.readLineSync()?.trim() ?? '';
    stdin.echoMode = true;
  } catch (_) {
    password = stdin.readLineSync()?.trim() ?? '';
  }
  print('\n');

  final pb = PocketBase(pbUrl);

  // Authenticate
  final authRes = await HttpClient().postUrl(Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'));
  authRes.headers.contentType = ContentType.json;
  authRes.write(jsonEncode({'identity': email, 'password': password}));
  final res = await authRes.close();
  final body = await res.transform(utf8.decoder).join();
  final data = jsonDecode(body) as Map<String, dynamic>;

  String token = '';
  if (res.statusCode == 200 && data['token'] != null) {
    token = data['token'];
  } else {
    final mfaId = data['mfaId'];
    final otpReq = await HttpClient().postUrl(Uri.parse('$pbUrl/api/collections/_superusers/request-otp'));
    otpReq.headers.contentType = ContentType.json;
    otpReq.write(jsonEncode({'email': email}));
    final otpRes = await otpReq.close();
    final otpBody = await otpRes.transform(utf8.decoder).join();
    final otpData = jsonDecode(otpBody) as Map<String, dynamic>;
    final otpId = otpData['otpId'];

    stdout.write('🔑 Enter OTP Code: ');
    final otpCode = stdin.readLineSync()?.trim() ?? '';

    final verifyReq = await HttpClient().postUrl(Uri.parse('$pbUrl/api/collections/_superusers/auth-with-otp'));
    verifyReq.headers.contentType = ContentType.json;
    verifyReq.write(jsonEncode({
      'otpId': otpId,
      'password': otpCode,
      if (mfaId != null) 'mfaId': mfaId,
    }));
    final verifyRes = await verifyReq.close();
    final verifyBody = await verifyRes.transform(utf8.decoder).join();
    final verifyData = jsonDecode(verifyBody) as Map<String, dynamic>;
    token = verifyData['token'];
  }

  pb.authStore.save(token, null);
  print('✅ Authenticated!\n');

  // 1. Fetch clinics
  print('--- Testing Clinics Fetch ---');
  try {
    final clinics = await pb.collection('clinics').getList(page: 1, perPage: 5, sort: '-id');
    print('✅ Clinics success: ${clinics.items.length} clinics found');
    if (clinics.items.isNotEmpty) {
      final clinicId = clinics.items.first.id;
      final clinicName = clinics.items.first.getStringValue('name');
      print('Using Clinic ID: $clinicId ($clinicName)\n');

      // Test Patients
      print('--- Testing Patients Filter ---');
      await _testQuery(pb, 'patients', 'clinic = "$clinicId"', expand: null);
      await _testQuery(pb, 'patients', 'clinic.id = "$clinicId"', expand: null);
      await _testQuery(pb, 'patients', 'doctor.clinic = "$clinicId"', expand: null);

      // Test Consultations
      print('\n--- Testing Consultations Filter ---');
      await _testQuery(pb, 'consultations', 'doctor.clinic = "$clinicId"', expand: 'patient,doctor');
      await _testQuery(pb, 'consultations', 'patient.clinic = "$clinicId"', expand: 'patient,doctor');
      await _testQuery(pb, 'consultations', 'doctor.clinic = "$clinicId" || patient.clinic = "$clinicId"', expand: 'patient,doctor');

      // Test Treatment Plans
      print('\n--- Testing Treatment Plans Filter ---');
      await _testQuery(pb, 'treatment_plans', 'doctor.clinic = "$clinicId"', expand: 'patient,doctor');
      await _testQuery(pb, 'treatment_plans', 'patient.clinic = "$clinicId"', expand: 'patient,doctor');
      await _testQuery(pb, 'treatment_plans', 'doctor.clinic = "$clinicId" || patient.clinic = "$clinicId"', expand: 'patient,doctor');

      // Test Sessions
      print('\n--- Testing Sessions Filter ---');
      await _testQuery(pb, 'sessions', 'doctor.clinic = "$clinicId"', expand: 'patient,doctor,treatment_plan');
      await _testQuery(pb, 'sessions', 'patient.clinic = "$clinicId"', expand: 'patient,doctor,treatment_plan');
      await _testQuery(pb, 'sessions', 'treatment_plan.doctor.clinic = "$clinicId"', expand: 'patient,doctor,treatment_plan');
    }
  } catch (e) {
    print('❌ Clinics error: $e');
  }
}

Future<void> _testQuery(PocketBase pb, String collection, String filter, {String? expand}) async {
  try {
    final res = await pb.collection(collection).getList(
      page: 1,
      perPage: 10,
      filter: filter,
      sort: '-id',
      expand: expand,
    );
    print('  ✅ [filter: $filter] -> OK (${res.items.length} items)');
  } catch (e) {
    print('  ❌ [filter: $filter] -> FAILED: $e');
  }
}
