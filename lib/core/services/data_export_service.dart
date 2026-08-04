import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'web_download_stub.dart' if (dart.library.html) 'web_download.dart';

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
  Future<String> exportSinglePatientData(String patientId) async {
    final StringBuffer out = StringBuffer();

    // 1. Fetch Patient
    final patientRecord = await pb.collection(PBCollections.patients).getOne(patientId);
    out.writeln('# PATIENT DATA EXPORT');
    out.writeln('Generated: ${DateTime.now().toIso8601String()}');
    out.writeln('--------------------------------------------------');
    out.writeln('Patient ID: ${patientRecord.getStringValue('patient_id')}');
    out.writeln('Name: ${patientRecord.getStringValue('full_name')}');
    out.writeln('Phone: ${patientRecord.getStringValue('phone')}');
    out.writeln('Gender: ${patientRecord.getStringValue('gender')}');
    out.writeln('DOB: ${patientRecord.getStringValue('date_of_birth')}');
    out.writeln('City: ${patientRecord.getStringValue('city')}');
    out.writeln('--------------------------------------------------');
    out.writeln('');

    // 2. Fetch Consultations
    final consultations = await _fetchAllRecords(PBCollections.consultations, "patient='$patientId'");
    out.writeln('## CONSULTATIONS (${consultations.length})');
    for (final c in consultations) {
      out.writeln('- Date: ${c['created']}');
      out.writeln('  Notes: ${c['notes']}');
      out.writeln('  Complaint: ${c['chief_complaint']}');
      out.writeln('  History: ${c['medical_history']}');
      out.writeln('');
    }
    out.writeln('--------------------------------------------------');

    // 3. Fetch Treatment Plans
    final plans = await _fetchAllRecords(PBCollections.treatmentPlans, "patient='$patientId'");
    out.writeln('## TREATMENT PLANS (${plans.length})');
    for (final p in plans) {
      out.writeln('- Plan Status: ${p['status']}');
      out.writeln('  Created: ${p['created']}');
      out.writeln('  Total Sessions: ${p['total_sessions']}');
      out.writeln('  Modality: ${p['treatment_modality']}');
      out.writeln('  Notes: ${p['plan_notes']}');
      out.writeln('');
    }
    out.writeln('--------------------------------------------------');

    // 4. Fetch Sessions
    final sessions = await _fetchAllRecords(PBCollections.sessions, "patient='$patientId'");
    // Sort sessions by date if possible, but they are just maps here
    sessions.sort((a, b) => (a['scheduled_date'] as String? ?? '').compareTo(b['scheduled_date'] as String? ?? ''));
    
    out.writeln('## SESSIONS (${sessions.length})');
    for (final s in sessions) {
      out.writeln('- Session ${s['session_number']} (${s['session_type']})');
      out.writeln('  Status: ${s['status']}');
      out.writeln('  Date: ${s['scheduled_date']} ${s['scheduled_time']}');
      out.writeln('  Vitals: BP ${s['vitals_bp']} | Pulse ${s['vitals_pulse']}');
      out.writeln('  Remarks: ${s['remarks'] ?? s['session_remarks'] ?? ''}');
      out.writeln('  Notes: ${s['session_notes_']}');
      out.writeln('');
    }

    return out.toString();
  }

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
  downloadFileWeb(csvContent, filename);
}
