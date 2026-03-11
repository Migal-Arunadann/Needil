/// PocketBase collection setup script.
///
/// Run this once after PocketBase is deployed to create all collections:
///   dart run scripts/setup_pocketbase.dart <admin_email> <admin_password>
///
/// This script uses the PocketBase Admin API to create collections.
library;

import 'dart:io';
import 'dart:convert';

const String pbUrl =
    'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/setup_pocketbase.dart <admin_email> <admin_password>');
    exit(1);
  }

  final email = args[0];
  final password = args[1];
  final client = HttpClient();

  try {
    // 1. Authenticate as admin
    print('🔐 Authenticating as admin...');
    final token = await _adminAuth(client, email, password);
    print('✅ Authenticated');

    // 2. Create collections in dependency order
    final collections = [
      _clinicsCollection(),
      _doctorsCollection(),
      _patientsCollection(),
      _appointmentsCollection(),
      _consultationsCollection(),
      _treatmentPlansCollection(),
      _sessionsCollection(),
      _auditLogsCollection(),
    ];

    for (final col in collections) {
      final name = col['name'];
      print('📦 Creating collection: $name...');
      await _createCollection(client, token, col);
      print('✅ $name created');
    }

    print('\n🎉 All collections created successfully!');
    print('   Visit $pbUrl/_/ to verify.');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<String> _adminAuth(HttpClient client, String email, String password) async {
  final uri = Uri.parse('$pbUrl/api/admins/auth-with-password');
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode({'identity': email, 'password': password}));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode != 200) {
    throw 'Admin auth failed (${response.statusCode}): $body';
  }
  final data = jsonDecode(body);
  return data['token'] as String;
}

Future<void> _createCollection(
    HttpClient client, String token, Map<String, dynamic> col) async {
  final uri = Uri.parse('$pbUrl/api/collections');
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.headers.set('Authorization', token);
  request.write(jsonEncode(col));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode != 200) {
    // Collection may already exist
    if (body.contains('already exists')) {
      print('   ⚠️  Collection already exists, skipping.');
      return;
    }
    throw 'Failed to create ${col['name']} (${response.statusCode}): $body';
  }
}

// ─── Collection Definitions ─────────────────────────────────────

Map<String, dynamic> _clinicsCollection() => {
      'name': 'clinics',
      'type': 'auth',
      'schema': [
        {'name': 'name', 'type': 'text', 'required': true},
        {'name': 'bed_count', 'type': 'number', 'required': true, 'options': {'min': 1}},
        {'name': 'clinic_id', 'type': 'text', 'required': true},
      ],
      'options': {
        'allowEmailAuth': false,
        'allowUsernameAuth': true,
        'minPasswordLength': 8,
      },
    };

Map<String, dynamic> _doctorsCollection() => {
      'name': 'doctors',
      'type': 'auth',
      'schema': [
        {'name': 'name', 'type': 'text', 'required': true},
        {'name': 'age', 'type': 'number', 'required': true},
        {'name': 'clinic', 'type': 'relation', 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'is_primary', 'type': 'bool'},
        {'name': 'working_schedule', 'type': 'json'},
        {'name': 'treatments', 'type': 'json'},
        {'name': 'share_past_patients', 'type': 'bool'},
        {'name': 'share_future_patients', 'type': 'bool'},
      ],
      'options': {
        'allowEmailAuth': false,
        'allowUsernameAuth': true,
        'minPasswordLength': 8,
      },
    };

Map<String, dynamic> _patientsCollection() => {
      'name': 'patients',
      'type': 'base',
      'schema': [
        {'name': 'full_name', 'type': 'text', 'required': true},
        {'name': 'phone', 'type': 'text', 'required': true},
        {'name': 'date_of_birth', 'type': 'date'},
        {'name': 'address', 'type': 'text'},
        {'name': 'emergency_contact', 'type': 'text'},
        {'name': 'allergies_conditions', 'type': 'text'},
        {'name': 'doctor', 'type': 'relation', 'required': true, 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'clinic', 'type': 'relation', 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'consent_given', 'type': 'bool'},
        {'name': 'consent_date', 'type': 'date'},
      ],
    };

Map<String, dynamic> _appointmentsCollection() => {
      'name': 'appointments',
      'type': 'base',
      'schema': [
        {'name': 'patient', 'type': 'relation', 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'doctor', 'type': 'relation', 'required': true, 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'clinic', 'type': 'relation', 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'type', 'type': 'select', 'required': true, 'options': {'values': ['call_by', 'walk_in']}},
        {'name': 'date', 'type': 'date', 'required': true},
        {'name': 'time', 'type': 'text', 'required': true},
        {'name': 'status', 'type': 'select', 'required': true, 'options': {'values': ['scheduled', 'in_progress', 'completed', 'cancelled']}},
        {'name': 'patient_name', 'type': 'text'},
        {'name': 'patient_phone', 'type': 'text'},
      ],
    };

Map<String, dynamic> _consultationsCollection() => {
      'name': 'consultations',
      'type': 'base',
      'schema': [
        {'name': 'patient', 'type': 'relation', 'required': true, 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'doctor', 'type': 'relation', 'required': true, 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'notes', 'type': 'text'},
        {'name': 'bp_level', 'type': 'text'},
        {'name': 'pulse', 'type': 'number'},
        {'name': 'charged', 'type': 'bool'},
        {'name': 'charge_amount', 'type': 'number'},
        {'name': 'photos', 'type': 'file', 'options': {'maxSelect': 10, 'maxSize': 5242880}},
      ],
    };

Map<String, dynamic> _treatmentPlansCollection() => {
      'name': 'treatment_plans',
      'type': 'base',
      'schema': [
        {'name': 'patient', 'type': 'relation', 'required': true, 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'doctor', 'type': 'relation', 'required': true, 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'consultation', 'type': 'relation', 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'treatment_type', 'type': 'text', 'required': true},
        {'name': 'start_date', 'type': 'date', 'required': true},
        {'name': 'total_sessions', 'type': 'number', 'required': true},
        {'name': 'interval_days', 'type': 'number', 'required': true},
        {'name': 'session_fee', 'type': 'number', 'required': true},
        {'name': 'status', 'type': 'select', 'required': true, 'options': {'values': ['active', 'completed', 'paused']}},
      ],
    };

Map<String, dynamic> _sessionsCollection() => {
      'name': 'sessions',
      'type': 'base',
      'schema': [
        {'name': 'treatment_plan', 'type': 'relation', 'required': true, 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'patient', 'type': 'relation', 'required': true, 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'doctor', 'type': 'relation', 'required': true, 'options': {'collectionId': '', 'maxSelect': 1}},
        {'name': 'session_number', 'type': 'number', 'required': true},
        {'name': 'scheduled_date', 'type': 'date', 'required': true},
        {'name': 'scheduled_time', 'type': 'text'},
        {'name': 'status', 'type': 'select', 'required': true, 'options': {'values': ['upcoming', 'completed', 'missed', 'cancelled']}},
        {'name': 'notes', 'type': 'text'},
        {'name': 'bp_level', 'type': 'text'},
        {'name': 'pulse', 'type': 'number'},
        {'name': 'photos', 'type': 'file', 'options': {'maxSelect': 10, 'maxSize': 5242880}},
        {'name': 'remarks', 'type': 'text'},
      ],
    };

Map<String, dynamic> _auditLogsCollection() => {
      'name': 'audit_logs',
      'type': 'base',
      'schema': [
        {'name': 'user', 'type': 'text', 'required': true},
        {'name': 'user_role', 'type': 'text', 'required': true},
        {'name': 'action', 'type': 'text', 'required': true},
        {'name': 'record_id', 'type': 'text'},
        {'name': 'collection', 'type': 'text'},
      ],
    };
