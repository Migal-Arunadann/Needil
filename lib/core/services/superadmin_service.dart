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

  /// Permanently deletes a clinic and ALL its doctors and receptionists.
  Future<void> deleteClinic(String clinicId) async {
    // Fetch and delete doctors
    final docBody = await _get('collections/${PBCollections.doctors}/records',
        query: {'filter': "clinic='$clinicId'", 'skipTotal': 'false'});
    for (final d in _parseItems(docBody)) {
      await _delete('collections/${PBCollections.doctors}/records/${d.id}');
    }
    // Fetch and delete receptionists
    final recBody = await _get(
        'collections/${PBCollections.receptionists}/records',
        query: {'filter': "clinic='$clinicId'", 'skipTotal': 'false'});
    for (final r in _parseItems(recBody)) {
      await _delete(
          'collections/${PBCollections.receptionists}/records/${r.id}');
    }
    // Delete clinic
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
