/// Photo Quota Reconciliation Script
///
/// Run this script AFTER adding `photos_used` (number, default 0) and
/// `photo_limit` (number, default 2000) fields to the `clinics` collection
/// in PocketBase Admin UI.
///
/// Usage:
///   dart run scripts/reconcile_photo_counts.dart
///
/// What it does:
///   1. Fetches all clinics
///   2. For each clinic, finds all doctors
///   3. Counts photos in all consultations and sessions by those doctors
///   4. Updates the clinic's `photos_used` field with the total count

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

const pbUrl = 'https://api.needil.com';

// ── Auth: Choose ONE method ──────────────────────────────────────────────────
//
// METHOD A: API Key (recommended — go to PocketBase Admin → Settings → API Keys)
const apiKey = 'PASTE_YOUR_API_KEY_HERE'; // ← paste key here, leave email/password blank
//
// METHOD B: Email + Password (only works if MFA is disabled on superadmin)
const adminEmail = '';
const adminPassword = '';
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  print('═══════════════════════════════════════════');
  print('  Photo Quota Reconciliation Script');
  print('═══════════════════════════════════════════\n');

  final pb = PocketBase(pbUrl);

  // Authenticate
  print('🔐 Authenticating...');
  try {
    if (apiKey.isNotEmpty && apiKey != 'PASTE_YOUR_API_KEY_HERE') {
      // Method A: API Key — inject directly as token
      pb.authStore.save(apiKey, null);
      print('   ✓ Using API key\n');
    } else if (adminEmail.isNotEmpty && adminPassword.isNotEmpty) {
      // Method B: Email + password (MFA must be disabled)
      final authRes = await http.post(
        Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identity': adminEmail, 'password': adminPassword}),
      );
      if (authRes.statusCode != 200) {
        print('   ✗ Auth failed (${authRes.statusCode}): ${authRes.body}');
        print('   → MFA may be enabled. Use an API key instead (Method A).');
        return;
      }
      final token = (jsonDecode(authRes.body) as Map)['token'] as String;
      pb.authStore.save(token, null);
      print('   ✓ Authenticated via email/password\n');
    } else {
      print('   ✗ No auth credentials set.');
      print('   → Set apiKey or adminEmail+adminPassword at the top of this script.');
      return;
    }
  } catch (e) {
    print('   ✗ Connection error: $e');
    return;
  }

  // Fetch all clinics
  print('📋 Fetching all clinics...');
  final clinics = await pb.collection('clinics').getFullList();
  print('   Found ${clinics.length} clinic(s)\n');

  int totalUpdated = 0;
  int totalPhotos = 0;

  for (final clinic in clinics) {
    final clinicId = clinic.id;
    final clinicName = clinic.getStringValue('name');
    print('─── Clinic: $clinicName ($clinicId) ───');

    // Find doctors for this clinic
    final doctors = await pb.collection('doctors').getFullList(
      filter: 'clinic = "$clinicId"',
    );
    final doctorIds = doctors.map((d) => d.id).toList();
    print('   Doctors: ${doctorIds.length}');

    if (doctorIds.isEmpty) {
      print('   No doctors → skipping\n');
      continue;
    }

    int photoCount = 0;

    for (final doctorId in doctorIds) {
      // Count consultation photos
      try {
        final consultations = await pb.collection('consultations').getFullList(
          filter: 'doctor = "$doctorId"',
        );
        for (final c in consultations) {
          final photos = c.getListValue<String>('photos');
          final validPhotos = photos.where((p) => p.isNotEmpty).length;
          photoCount += validPhotos;
        }
      } catch (e) {
        print('   ⚠ Error fetching consultations for doctor $doctorId: $e');
      }

      // Count session photos
      try {
        final sessions = await pb.collection('sessions').getFullList(
          filter: 'doctor = "$doctorId"',
        );
        for (final s in sessions) {
          final photos = s.getListValue<String>('photos');
          final validPhotos = photos.where((p) => p.isNotEmpty).length;
          photoCount += validPhotos;
        }
      } catch (e) {
        print('   ⚠ Error fetching sessions for doctor $doctorId: $e');
      }
    }

    // Update the clinic record
    try {
      await pb.collection('clinics').update(clinicId, body: {
        'photos_used': photoCount,
        'photo_limit': 2000, // Ensure limit is set
      });
      print('   ✓ photos_used = $photoCount (updated)');
      totalUpdated++;
    } catch (e) {
      print('   ✗ Failed to update: $e');
    }

    totalPhotos += photoCount;
    print('');
  }

  print('═══════════════════════════════════════════');
  print('  Summary');
  print('═══════════════════════════════════════════');
  print('  Clinics updated: $totalUpdated / ${clinics.length}');
  print('  Total photos counted: $totalPhotos');
  print('═══════════════════════════════════════════');
}
