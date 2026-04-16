/// Adds missing custom fields to auth collections (clinics, doctors).
/// PocketBase v0.23+ requires 'fields' not 'schema'.
///
/// Run: dart run scripts/add_fields.dart <email> <password>
library;

import 'dart:io';
import 'dart:convert';

const String pbUrl =
    'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/add_fields.dart <email> <password>');
    exit(1);
  }
  final client = HttpClient();
  try {
    print('🔐 Authenticating...');
    final token = await _adminAuth(client, args[0], args[1]);
    print('✅ Authenticated\n');

    // ── 1. Clinics collection fields ─────────────────────────────
    print('📦 Fetching clinics collection...');
    final clinicsCol = await _getCollection(client, token, 'clinics');
    final clinicsId = clinicsCol['id'] as String;

    final clinicsFields = List<Map<String, dynamic>>.from(
      clinicsCol['fields'] as List? ?? [],
    );

    _addIfMissing(clinicsFields, {
      'name': 'name',
      'type': 'text',
      'required': true,
      'presentable': false,
      'hidden': false,
      'system': false,
    });
    _addIfMissing(clinicsFields, {
      'name': 'bed_count',
      'type': 'number',
      'required': true,
      'presentable': false,
      'hidden': false,
      'system': false,
      'min': 1,
    });
    _addIfMissing(clinicsFields, {
      'name': 'clinic_id',
      'type': 'text',
      'required': true,
      'presentable': false,
      'hidden': false,
      'system': false,
    });

    await _patchCollection(client, token, clinicsId, clinicsFields);
    print('✅ clinics fields updated\n');

    // ── 2. Doctors collection fields ─────────────────────────────
    print('📦 Fetching doctors collection...');
    final doctorsCol = await _getCollection(client, token, 'doctors');
    final doctorsId = doctorsCol['id'] as String;

    final doctorsFields = List<Map<String, dynamic>>.from(
      doctorsCol['fields'] as List? ?? [],
    );

    _addIfMissing(doctorsFields, {
      'name': 'name',
      'type': 'text',
      'required': true,
      'presentable': false,
      'hidden': false,
      'system': false,
    });
    _addIfMissing(doctorsFields, {
      'name': 'age',
      'type': 'number',
      'required': true,
      'presentable': false,
      'hidden': false,
      'system': false,
    });
    _addIfMissing(doctorsFields, {
      'name': 'clinic',
      'type': 'relation',
      'required': false,
      'presentable': false,
      'hidden': false,
      'system': false,
      'collectionId': clinicsId,
      'maxSelect': 1,
    });
    _addIfMissing(doctorsFields, {
      'name': 'is_primary',
      'type': 'bool',
      'presentable': false,
      'hidden': false,
      'system': false,
    });
    _addIfMissing(doctorsFields, {
      'name': 'working_schedule',
      'type': 'json',
      'presentable': false,
      'hidden': false,
      'system': false,
    });
    _addIfMissing(doctorsFields, {
      'name': 'treatments',
      'type': 'json',
      'presentable': false,
      'hidden': false,
      'system': false,
    });
    _addIfMissing(doctorsFields, {
      'name': 'share_past_patients',
      'type': 'bool',
      'presentable': false,
      'hidden': false,
      'system': false,
    });
    _addIfMissing(doctorsFields, {
      'name': 'share_future_patients',
      'type': 'bool',
      'presentable': false,
      'hidden': false,
      'system': false,
    });

    await _patchCollection(client, token, doctorsId, doctorsFields);
    print('✅ doctors fields updated\n');

    // ── 3. Also add fields to base collections ───────────────────
    await _patchBaseCollections(client, token, clinicsId, doctorsId);

    print('🎉 All fields added. Registration should now work!');
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<void> _patchBaseCollections(
  HttpClient client,
  String token,
  String clinicsId,
  String doctorsId,
) async {
  // patients
  print('📦 Updating patients...');
  final pCol = await _getCollection(client, token, 'patients');
  final pFields = List<Map<String, dynamic>>.from(
    pCol['fields'] as List? ?? [],
  );
  _addIfMissing(pFields, {
    'name': 'full_name',
    'type': 'text',
    'required': true,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  _addIfMissing(pFields, {
    'name': 'phone',
    'type': 'text',
    'required': true,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  _addIfMissing(pFields, {
    'name': 'date_of_birth',
    'type': 'text',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  _addIfMissing(pFields, {
    'name': 'address',
    'type': 'text',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  _addIfMissing(pFields, {
    'name': 'emergency_contact',
    'type': 'text',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  _addIfMissing(pFields, {
    'name': 'allergies_conditions',
    'type': 'text',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  _addIfMissing(pFields, {
    'name': 'doctor',
    'type': 'relation',
    'required': true,
    'presentable': false,
    'hidden': false,
    'system': false,
    'collectionId': doctorsId,
    'maxSelect': 1,
  });
  _addIfMissing(pFields, {
    'name': 'clinic',
    'type': 'relation',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
    'collectionId': clinicsId,
    'maxSelect': 1,
  });
  _addIfMissing(pFields, {
    'name': 'consent_given',
    'type': 'bool',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  await _patchCollection(client, token, pCol['id'] as String, pFields);
  print('   ✅ patients updated');

  // appointments
  print('📦 Updating appointments...');
  final aCol = await _getCollection(client, token, 'appointments');
  final aFields = List<Map<String, dynamic>>.from(
    aCol['fields'] as List? ?? [],
  );
  _addIfMissing(aFields, {
    'name': 'patient',
    'type': 'relation',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
    'collectionId': pCol['id'],
    'maxSelect': 1,
  });
  _addIfMissing(aFields, {
    'name': 'doctor',
    'type': 'relation',
    'required': true,
    'presentable': false,
    'hidden': false,
    'system': false,
    'collectionId': doctorsId,
    'maxSelect': 1,
  });
  _addIfMissing(aFields, {
    'name': 'clinic',
    'type': 'relation',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
    'collectionId': clinicsId,
    'maxSelect': 1,
  });
  _addIfMissing(aFields, {
    'name': 'type',
    'type': 'select',
    'required': true,
    'presentable': false,
    'hidden': false,
    'system': false,
    'values': ['call_by', 'walk_in'],
  });
  _addIfMissing(aFields, {
    'name': 'date',
    'type': 'text',
    'required': true,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  _addIfMissing(aFields, {
    'name': 'time',
    'type': 'text',
    'required': true,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  _addIfMissing(aFields, {
    'name': 'status',
    'type': 'select',
    'required': true,
    'presentable': false,
    'hidden': false,
    'system': false,
    'values': ['scheduled', 'in_progress', 'completed', 'cancelled'],
  });
  _addIfMissing(aFields, {
    'name': 'patient_name',
    'type': 'text',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  _addIfMissing(aFields, {
    'name': 'patient_phone',
    'type': 'text',
    'required': false,
    'presentable': false,
    'hidden': false,
    'system': false,
  });
  await _patchCollection(client, token, aCol['id'] as String, aFields);
  print('   ✅ appointments updated');
}

void _addIfMissing(
  List<Map<String, dynamic>> fields,
  Map<String, dynamic> field,
) {
  final name = field['name'] as String;
  if (!fields.any((f) => f['name'] == name)) {
    fields.add(field);
    print('   + adding field: $name');
  } else {
    print('   ✓ field exists: $name');
  }
}

Future<Map<String, dynamic>> _getCollection(
  HttpClient client,
  String token,
  String name,
) async {
  final req = await client.getUrl(Uri.parse('$pbUrl/api/collections/$name'));
  req.headers.set('Authorization', token);
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw 'GET $name failed: $body';
  return jsonDecode(body) as Map<String, dynamic>;
}

Future<void> _patchCollection(
  HttpClient client,
  String token,
  String id,
  List<Map<String, dynamic>> fields,
) async {
  final req = await client.openUrl(
    'PATCH',
    Uri.parse('$pbUrl/api/collections/$id'),
  );
  req.headers.contentType = ContentType.json;
  req.headers.set('Authorization', token);
  req.write(jsonEncode({'fields': fields}));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw 'PATCH failed: $body';
}

Future<String> _adminAuth(HttpClient c, String email, String pw) async {
  final req = await c.postUrl(
    Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'),
  );
  req.headers.contentType = ContentType.json;
  req.write(jsonEncode({'identity': email, 'password': pw}));
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw 'Auth failed: $body';
  return (jsonDecode(body))['token'] as String;
}
