import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import '../constants/pb_collections.dart';

/// All admin-level PocketBase operations for the superadmin panel.
/// Uses raw HTTP calls with the superuser token in the Authorization header,
/// guaranteeing they bypass collection API rules regardless of SDK behaviour.
class SuperadminService {
  final PocketBase pb;
  late final http.Client _client;

  SuperadminService(this.pb) : _client = http.Client();

  /// Derived from the PocketBase instance — always uses the correct base URL.
  String get _base => pb.baseURL;

  /// Authorization header value from the stored superadmin token.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': pb.authStore.token,
      };

  // ── Generic helpers ────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? query}) async {
    final uri = Uri.parse('$_base/api/$path').replace(
        queryParameters: query ?? {});
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw 'GET $path failed (${res.statusCode}): ${res.body}';
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _patch(String path,
      Map<String, dynamic> body) async {
    final uri = Uri.parse('$_base/api/$path');
    final res = await _client.patch(uri,
        headers: _headers, body: jsonEncode(body));
    if (res.statusCode != 200) {
      throw 'PATCH $path failed (${res.statusCode}): ${res.body}';
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> _delete(String path) async {
    final uri = Uri.parse('$_base/api/$path');
    final res = await _client.delete(uri, headers: _headers);
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw 'DELETE $path failed (${res.statusCode}): ${res.body}';
    }
  }

  /// Parse a PocketBase list response and return items as RecordModels.
  List<RecordModel> _parseItems(Map<String, dynamic> body) {
    final items = (body['items'] as List<dynamic>? ?? []);
    return items
        .map((e) => RecordModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Platform Stats ─────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchPlatformStats() async {
    final results = await Future.wait([
      _get('collections/${PBCollections.clinics}/records',
          query: {'page': '1', 'perPage': '1', 'skipTotal': 'false'}),
      _get('collections/${PBCollections.doctors}/records',
          query: {'page': '1', 'perPage': '1', 'skipTotal': 'false'}),
      _get('collections/${PBCollections.receptionists}/records',
          query: {'page': '1', 'perPage': '1', 'skipTotal': 'false'}),
    ]);
    return {
      'total_clinics': results[0]['totalItems'] ?? 0,
      'total_doctors': results[1]['totalItems'] ?? 0,
      'total_receptionists': results[2]['totalItems'] ?? 0,
    };
  }

  Future<List<RecordModel>> fetchRecentClinics({int limit = 10}) async {
    final body = await _get('collections/${PBCollections.clinics}/records',
        query: {
          'page': '1',
          'perPage': '$limit',
          'sort': '-created',
          'skipTotal': 'false',
        });
    return _parseItems(body);
  }

  // ── Clinic Management ─────────────────────────────────────────

  Future<List<RecordModel>> fetchAllClinics({String? search}) async {
    final query = <String, String>{
      'page': '1',
      'perPage': '500',
      'sort': '-created',
      'skipTotal': 'false',
    };
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim();
      query['filter'] = "(name ~ '$q' || city ~ '$q' || clinic_id ~ '$q')";
    }
    final body = await _get(
        'collections/${PBCollections.clinics}/records',
        query: query);
    return _parseItems(body);
  }

  /// Returns the clinic record, plus its list of doctors and receptionists.
  Future<Map<String, dynamic>> getClinicWithStaff(String clinicId) async {
    final results = await Future.wait([
      _get('collections/${PBCollections.clinics}/records/$clinicId'),
      _get('collections/${PBCollections.doctors}/records',
          query: {'filter': "clinic='$clinicId'", 'sort': 'name', 'skipTotal': 'false'}),
      _get('collections/${PBCollections.receptionists}/records',
          query: {'filter': "clinic='$clinicId'", 'sort': 'name', 'skipTotal': 'false'}),
    ]);

    return {
      'clinic': RecordModel.fromJson(results[0]),
      'doctors': _parseItems(results[1]),
      'receptionists': _parseItems(results[2]),
    };
  }

  Future<void> updateClinic(String clinicId, Map<String, dynamic> body) async {
    await _patch(
        'collections/${PBCollections.clinics}/records/$clinicId', body);
  }

  Future<void> toggleClinicVerified(String clinicId, bool verified) async {
    await _patch('collections/${PBCollections.clinics}/records/$clinicId',
        {'verified': verified});
  }

  /// Soft-deactivates a clinic — blocks all logins and sets a 30-day deletion window.
  /// The clinic record stays in PocketBase; staff accounts are NOT deleted yet.
  Future<void> deactivateClinic(String clinicId) async {
    final now = DateTime.now().toUtc();
    final deletionDate = now.add(const Duration(days: 30));
    await _patch('collections/${PBCollections.clinics}/records/$clinicId', {
      'is_deactivated': true,
      'deactivated_at': now.toIso8601String(),
      'scheduled_deletion_date': deletionDate.toIso8601String(),
    });
  }

  /// Reactivates a previously deactivated clinic, restoring full login access.
  Future<void> reactivateClinic(String clinicId) async {
    await _patch('collections/${PBCollections.clinics}/records/$clinicId', {
      'is_deactivated': false,
      'deactivated_at': '',
      'scheduled_deletion_date': '',
    });
  }

  /// Helper: fetch ALL records for a collection with a given filter, handling pagination.
  Future<List<RecordModel>> _fetchAll(String collection, String filter) async {
    const perPage = 200;
    int page = 1;
    final results = <RecordModel>[];
    while (true) {
      final body = await _get('collections/$collection/records', query: {
        'filter': filter,
        'page': '$page',
        'perPage': '$perPage',
        'skipTotal': 'false',
      });
      final items = _parseItems(body);
      results.addAll(items);
      final totalItems = (body['totalItems'] as num?)?.toInt() ?? 0;
      if (results.length >= totalItems || items.isEmpty) break;
      page++;
    }
    return results;
  }

  /// Permanently deletes a clinic and cascades through ALL 10 collections.
  /// Fixes the previous gap where 7 collection types were left orphaned.
  Future<void> permanentlyDeleteClinic(String clinicId) async {
    // 1. Fetch all doctor IDs (needed for sessions/consultations filter)
    final doctors = await _fetchAll(PBCollections.doctors, "clinic='$clinicId'");
    final doctorIds = doctors.map((d) => d.id).toList();

    // 2. Delete sessions (filter by doctor or clinic)
    for (final docId in doctorIds) {
      final sessions = await _fetchAll(PBCollections.sessions, "doctor='$docId'");
      for (final s in sessions) {
        await _delete('collections/${PBCollections.sessions}/records/${s.id}');
      }
    }

    // 3. Delete treatment_plans
    final plans = await _fetchAll(PBCollections.treatmentPlans, "clinic='$clinicId'");
    for (final p in plans) {
      await _delete('collections/${PBCollections.treatmentPlans}/records/${p.id}');
    }

    // 4. Delete consultations
    final consultations = await _fetchAll(PBCollections.consultations, "clinic='$clinicId'");
    for (final c in consultations) {
      await _delete('collections/${PBCollections.consultations}/records/${c.id}');
    }

    // 5. Delete appointments
    final appointments = await _fetchAll(PBCollections.appointments, "clinic='$clinicId'");
    for (final a in appointments) {
      await _delete('collections/${PBCollections.appointments}/records/${a.id}');
    }

    // 6. Delete patients
    final patients = await _fetchAll(PBCollections.patients, "clinic='$clinicId'");
    for (final p in patients) {
      await _delete('collections/${PBCollections.patients}/records/${p.id}');
    }

    // 7. Delete consent_records
    final consentRecords = await _fetchAll(PBCollections.consentRecords, "clinic_id='$clinicId'");
    for (final cr in consentRecords) {
      await _delete('collections/${PBCollections.consentRecords}/records/${cr.id}');
    }

    // 8. Delete audit_logs
    final auditLogs = await _fetchAll(PBCollections.auditLogs, "clinic='$clinicId'");
    for (final al in auditLogs) {
      await _delete('collections/${PBCollections.auditLogs}/records/${al.id}');
    }

    // 9. Delete doctors
    for (final d in doctors) {
      await _delete('collections/${PBCollections.doctors}/records/${d.id}');
    }

    // 10. Delete receptionists
    final recs = await _fetchAll(PBCollections.receptionists, "clinic='$clinicId'");
    for (final r in recs) {
      await _delete('collections/${PBCollections.receptionists}/records/${r.id}');
    }

    // 11. Finally delete the clinic itself
    await _delete('collections/${PBCollections.clinics}/records/$clinicId');
  }


  Future<void> resetClinicPassword(String clinicId, String newPassword) async {
    await _patch('collections/${PBCollections.clinics}/records/$clinicId',
        {'password': newPassword, 'passwordConfirm': newPassword});
  }

  // ── Doctor Management ─────────────────────────────────────────

  Future<void> resetDoctorPassword(String doctorId, String newPassword) async {
    await _patch('collections/${PBCollections.doctors}/records/$doctorId',
        {'password': newPassword, 'passwordConfirm': newPassword});
  }

  Future<void> deleteDoctor(String doctorId) async {
    await _delete('collections/${PBCollections.doctors}/records/$doctorId');
  }

  Future<void> toggleDoctorActive(String doctorId, bool active) async {
    await _patch('collections/${PBCollections.doctors}/records/$doctorId',
        {'is_active': active});
  }

  // ── Receptionist Management ───────────────────────────────────

  Future<void> resetReceptionistPassword(String recId, String newPassword) async {
    await _patch('collections/${PBCollections.receptionists}/records/$recId',
        {'password': newPassword, 'passwordConfirm': newPassword});
  }

  Future<void> deleteReceptionist(String recId) async {
    await _delete(
        'collections/${PBCollections.receptionists}/records/$recId');
  }

  Future<void> toggleReceptionistActive(String recId, bool active) async {
    await _patch('collections/${PBCollections.receptionists}/records/$recId',
        {'is_active': active});
  }
}
