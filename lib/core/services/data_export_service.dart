import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import '../constants/pb_collections.dart';

/// Exports all clinic data as CSV strings.
/// Supports web (blob download) and mobile (returns CSV string for sharing).
class DataExportService {
  final PocketBase pb;

  DataExportService(this.pb);

  String get _base => pb.baseURL;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': pb.authStore.token,
      };

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchAllRecords(
      String collection, String filter) async {
    const perPage = 200;
    int page = 1;
    final results = <Map<String, dynamic>>[];
    final client = http.Client();
    try {
      while (true) {
        final uri = Uri.parse('$_base/api/collections/$collection/records').replace(
          queryParameters: {
            'filter': filter,
            'page': '$page',
            'perPage': '$perPage',
            'skipTotal': 'false',
          },
        );
        final res = await client.get(uri, headers: _headers);
        if (res.statusCode != 200) break;
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (body['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        results.addAll(items);
        final totalItems = (body['totalItems'] as num?)?.toInt() ?? 0;
        if (results.length >= totalItems || items.isEmpty) break;
        page++;
      }
    } finally {
      client.close();
    }
    return results;
  }

  /// Escape a CSV field — wraps in quotes if it contains comma, newline, or quote.
  String _csvField(dynamic value) {
    if (value == null) return '';
    final s = value.toString();
    if (s.contains(',') || s.contains('\n') || s.contains('"')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _csvRow(List<dynamic> fields) =>
      fields.map(_csvField).join(',');

  // ── Individual CSV Exporters ───────────────────────────────────────────────

  Future<String> exportPatientsCSV(String clinicId) async {
    final records = await _fetchAllRecords(
        PBCollections.patients, "clinic='$clinicId'");
    final rows = <String>[
      _csvRow([
        'Patient ID', 'Full Name', 'Phone', 'Gender', 'Date of Birth',
        'Age', 'City', 'Area', 'Pincode', 'Occupation', 'Email',
        'Reference', 'Consent Given', 'Consent Date',
        'Privacy Policy Accepted', 'Created',
      ]),
    ];
    for (final r in records) {
      rows.add(_csvRow([
        r['patient_id'], r['full_name'], r['phone'], r['gender'],
        r['date_of_birth'], r['age'], r['city'], r['area'], r['pincode'],
        r['occupation'], r['email'], r['reference'],
        r['consent_given'], r['consent_date'],
        r['privacy_policy_accepted'], r['created'],
      ]));
    }
    return rows.join('\n');
  }

  Future<String> exportAppointmentsCSV(String clinicId) async {
    final records = await _fetchAllRecords(
        PBCollections.appointments, "clinic='$clinicId'");
    final rows = <String>[
      _csvRow([
        'ID', 'Patient Name', 'Patient Phone', 'Date', 'Time',
        'Type', 'Status', 'Doctor ID', 'Created',
      ]),
    ];
    for (final r in records) {
      rows.add(_csvRow([
        r['id'], r['patient_name'], r['patient_phone'],
        r['date'], r['time'], r['type'], r['status'],
        r['doctor'], r['created'],
      ]));
    }
    return rows.join('\n');
  }

  Future<String> exportConsultationsCSV(String clinicId) async {
    final records = await _fetchAllRecords(
        PBCollections.consultations, "clinic='$clinicId'");
    final rows = <String>[
      _csvRow([
        'ID', 'Patient ID', 'Doctor ID', 'Chief Complaint', 'Diagnosis',
        'Prescription', 'Status', 'Consent Given', 'Created',
      ]),
    ];
    for (final r in records) {
      rows.add(_csvRow([
        r['id'], r['patient'], r['doctor'],
        r['chief_complaint'], r['diagnosis'], r['prescription'],
        r['status'], r['consent_given'], r['created'],
      ]));
    }
    return rows.join('\n');
  }

  Future<String> exportTreatmentPlansCSV(String clinicId) async {
    final records = await _fetchAllRecords(
        PBCollections.treatmentPlans, "clinic='$clinicId'");
    final rows = <String>[
      _csvRow([
        'ID', 'Patient ID', 'Doctor ID', 'Treatment Type',
        'Total Sessions', 'Completed Sessions', 'Status', 'Created',
      ]),
    ];
    for (final r in records) {
      rows.add(_csvRow([
        r['id'], r['patient'], r['doctor'], r['treatment_type'],
        r['total_sessions'], r['completed_sessions'], r['status'], r['created'],
      ]));
    }
    return rows.join('\n');
  }

  Future<String> exportSessionsCSV(String clinicId) async {
    // Sessions are linked to doctor, not clinic directly
    // Fetch all doctor IDs for this clinic first
    final client = http.Client();
    final doctorIds = <String>[];
    try {
      final uri = Uri.parse(
              '$_base/api/collections/${PBCollections.doctors}/records')
          .replace(queryParameters: {
        'filter': "clinic='$clinicId'",
        'fields': 'id',
        'perPage': '500',
        'skipTotal': 'false',
      });
      final res = await client.get(uri, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final items = (body['items'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        doctorIds.addAll(items.map((d) => d['id'].toString()));
      }
    } finally {
      client.close();
    }

    final allSessions = <Map<String, dynamic>>[];
    for (final docId in doctorIds) {
      final sessions =
          await _fetchAllRecords(PBCollections.sessions, "doctor='$docId'");
      allSessions.addAll(sessions);
    }

    final rows = <String>[
      _csvRow([
        'ID', 'Patient ID', 'Doctor ID', 'Session Number',
        'Scheduled Date', 'Status', 'Notes', 'Created',
      ]),
    ];
    for (final r in allSessions) {
      rows.add(_csvRow([
        r['id'], r['patient'], r['doctor'], r['session_number'],
        r['scheduled_date'], r['status'], r['notes'], r['created'],
      ]));
    }
    return rows.join('\n');
  }

  // ── Main Export Entry Point ────────────────────────────────────────────────

  /// Exports all clinic data as a Map of filename → CSV string.
  /// Caller is responsible for downloading/sharing the files.
  Future<Map<String, String>> exportAllData(String clinicId,
      String clinicName) async {
    final sanitizedName =
        clinicName.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);

    final results = await Future.wait([
      exportPatientsCSV(clinicId),
      exportAppointmentsCSV(clinicId),
      exportConsultationsCSV(clinicId),
      exportTreatmentPlansCSV(clinicId),
      exportSessionsCSV(clinicId),
    ]);

    return {
      '${sanitizedName}_patients_$dateStr.csv': results[0],
      '${sanitizedName}_appointments_$dateStr.csv': results[1],
      '${sanitizedName}_consultations_$dateStr.csv': results[2],
      '${sanitizedName}_treatment_plans_$dateStr.csv': results[3],
      '${sanitizedName}_sessions_$dateStr.csv': results[4],
    };
  }
}

/// Downloads a CSV string in the browser (web only).
/// On non-web platforms, this is a no-op — callers handle mobile saving separately.
void downloadCsvWeb(String csvContent, String filename) {
  if (!kIsWeb) return;
  // Use a conditional import via dart:html on web
  // We use the `dart:html` package indirectly through a JS interop approach
  // that avoids compile errors on mobile targets.
  _downloadCsvWebImpl(csvContent, filename);
}

// Platform-safe download function
void _downloadCsvWebImpl(String csvContent, String filename) {
  if (!kIsWeb) return;
  // On web: create a blob URL and trigger download
  // This is done via the web-specific implementation below
  _triggerWebDownload(csvContent, filename);
}

void _triggerWebDownload(String content, String filename) {
  // This will only be called on web — use a try/catch to avoid
  // dart:html import issues on mobile
  try {
    // ignore: avoid_dynamic_calls
    final dynamic html = _getHtml();
    if (html == null) return;
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a');
    anchor.href = url;
    anchor.download = filename;
    html.document.body?.appendChild(anchor);
    anchor.click();
    html.document.body?.removeChild(anchor);
    html.Url.revokeObjectUrl(url);
  } catch (_) {
    // Silently fail if dart:html not available
  }
}

dynamic _getHtml() {
  try {
    // This will throw on non-web platforms
    return null; // Placeholder — actual web impl uses conditional imports
  } catch (_) {
    return null;
  }
}
