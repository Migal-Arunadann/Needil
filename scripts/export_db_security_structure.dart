/// PocketBase Comprehensive Database Structure & Security Inspector.
///
/// Fetches all collections, fields, relations, indexes, auth options, and API rules
/// from PocketBase, performs security analysis, maps cross-collection relations,
/// and outputs both a full Markdown report and enriched JSON data.
///
/// Usage:
///   dart run scripts/export_db_security_structure.dart
///   dart run scripts/export_db_security_structure.dart <admin-email> <admin-password> [pb-url]
///   dart run scripts/export_db_security_structure.dart --offline [schema.json]
library;

import 'dart:io';
import 'dart:convert';

String defaultPbUrl = 'https://api.needil.com';

String _detectPbUrl() {
  try {
    final file = File('lib/core/providers/pocketbase_provider.dart');
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      final match = RegExp(r"pbBaseUrl\s*=\s*[\x27\x22]([^\x27\x22]+)[\x27\x22]").firstMatch(content);
      if (match != null) return match.group(1)!;
    }
  } catch (_) {}
  return defaultPbUrl;
}

Future<void> main(List<String> args) async {
  print('════════════════════════════════════════════════════════════════════════════════');
  print('🛡️  POCKETBASE COMPLETE DATABASE STRUCTURE & SECURITY INSPECTION');
  print('════════════════════════════════════════════════════════════════════════════════\n');

  List<Map<String, dynamic>> collections = [];
  String sourceInfo = '';

  bool isOffline = args.contains('--offline');

  if (isOffline) {
    String jsonPath = 'pocketbase_live_schema.json';
    for (int i = 0; i < args.length; i++) {
      if (args[i] == '--offline' && i + 1 < args.length && !args[i + 1].startsWith('-')) {
        jsonPath = args[i + 1];
      }
    }
    final file = File(jsonPath);
    if (!file.existsSync()) {
      print('❌ Error: Offline schema file "$jsonPath" not found.');
      exit(1);
    }
    print('📂 Loading offline schema from: $jsonPath...');
    final raw = jsonDecode(file.readAsStringSync());
    if (raw is List) {
      collections = raw.map((e) => e as Map<String, dynamic>).toList();
    } else if (raw is Map && raw['items'] is List) {
      collections = (raw['items'] as List).map((e) => e as Map<String, dynamic>).toList();
    }
    sourceInfo = 'Offline File: $jsonPath';
  } else {
    String pbUrl = _detectPbUrl();
    String email = '';
    String password = '';

    if (args.length >= 2 && !args[0].startsWith('-')) {
      email = args[0];
      password = args[1];
      if (args.length >= 3 && !args[2].startsWith('-')) {
        pbUrl = args[2];
      }
    }

    if (email.isEmpty || password.isEmpty) {
      print('🌐 PocketBase Server: $pbUrl');
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
    }

    if (email.isEmpty || password.isEmpty) {
      print('❌ Error: Email and password are required for live inspection.');
      print('💡 Tip: Run with --offline to analyze existing pocketbase_live_schema.json.');
      exit(1);
    }

    final client = HttpClient();
    try {
      print('1. Authenticating as Superadmin (supporting MFA & OTP)...');
      final token = await _adminAuth(client, pbUrl, email, password);
      print('   ✅ Authenticated successfully.\n');

      print('2. Fetching all collections and system schemas from PocketBase...');
      final uri = Uri.parse('$pbUrl/api/collections?perPage=500');
      final request = await client.getUrl(uri);
      request.headers.set('Authorization', token);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw 'Failed to fetch collections (${response.statusCode}): $body';
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      collections = (data['items'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();

      // Save raw schema backup
      File('pocketbase_live_schema.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(collections),
      );
      print('   💾 Raw schema saved to pocketbase_live_schema.json\n');
      sourceInfo = 'Live PocketBase Server: $pbUrl';
    } catch (e) {
      print('❌ Live connection error: $e');
      if (File('pocketbase_live_schema.json').existsSync()) {
        print('⚠️  Falling back to local pocketbase_live_schema.json...');
        final raw = jsonDecode(File('pocketbase_live_schema.json').readAsStringSync());
        collections = (raw as List).map((e) => e as Map<String, dynamic>).toList();
        sourceInfo = 'Offline Fallback: pocketbase_live_schema.json';
      } else {
        exit(1);
      }
    } finally {
      client.close();
    }
  }

  // Sort collections: regular collections first, then system collections (_*)
  collections.sort((a, b) {
    final aName = a['name'] as String? ?? '';
    final bName = b['name'] as String? ?? '';
    final aSys = aName.startsWith('_');
    final bSys = bName.startsWith('_');
    if (aSys && !bSys) return 1;
    if (!aSys && bSys) return -1;
    return aName.compareTo(bName);
  });

  // Build ID-to-Name and Name-to-Collection mapping
  final idToName = <String, String>{};
  final nameToCollection = <String, Map<String, dynamic>>{};
  for (final col in collections) {
    final id = col['id'] as String? ?? '';
    final name = col['name'] as String? ?? '';
    if (id.isNotEmpty) idToName[id] = name;
    if (name.isNotEmpty) nameToCollection[name] = col;
  }

  // Analyze relationships & cross-references
  final relations = <Map<String, dynamic>>[];
  final incomingRelations = <String, List<Map<String, dynamic>>>{};

  for (final col in collections) {
    final sourceName = col['name'] as String? ?? '';
    final sourceId = col['id'] as String? ?? '';
    final fields = _extractFields(col);

    for (final field in fields) {
      final fName = field['name'] as String? ?? '';
      final fType = field['type'] as String? ?? '';

      if (fType == 'relation') {
        final targetId = field['collectionId'] as String? ??
            field['options']?['collectionId'] as String? ??
            '';
        final targetName = idToName[targetId] ?? targetId;
        final maxSelect = field['maxSelect'] as int? ??
            field['options']?['maxSelect'] as int? ??
            1;
        final minSelect = field['minSelect'] as int? ??
            field['options']?['minSelect'] as int? ??
            0;
        final cascadeDelete = field['cascadeDelete'] as bool? ??
            field['options']?['cascadeDelete'] as bool? ??
            false;
        final isRequired = field['required'] == true;

        final relInfo = {
          'sourceCollection': sourceName,
          'sourceCollectionId': sourceId,
          'sourceField': fName,
          'targetCollection': targetName,
          'targetCollectionId': targetId,
          'relationType': maxSelect == 1 ? 'Many-to-One (N:1)' : 'Many-to-Many (N:M)',
          'maxSelect': maxSelect,
          'minSelect': minSelect,
          'cascadeDelete': cascadeDelete,
          'required': isRequired,
        };

        relations.add(relInfo);
        incomingRelations.putIfAbsent(targetName, () => []).add(relInfo);
      }
    }
  }

  // Print Terminal Summary
  _printTerminalSummary(collections, idToName, relations);

  // Generate Enriched JSON Export
  final enrichedExport = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'source': sourceInfo,
    'collectionCount': collections.length,
    'relationCount': relations.length,
    'collections': collections.map((col) {
      final name = col['name'] as String? ?? '';
      return {
        ...col,
        'resolvedIncomingRelations': incomingRelations[name] ?? [],
      };
    }).toList(),
    'allRelations': relations,
  };
  final jsonOutputFile = File('pb_db_structure.json');
  jsonOutputFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(enrichedExport));
  print('💾 Full enriched JSON structure written to: ${jsonOutputFile.path}');

  // Generate Comprehensive Markdown Security & Database Report
  final mdContent = _generateMarkdownReport(
    collections: collections,
    idToName: idToName,
    relations: relations,
    incomingRelations: incomingRelations,
    sourceInfo: sourceInfo,
  );
  final mdOutputFile = File('pb_db_security_structure.md');
  mdOutputFile.writeAsStringSync(mdContent);
  print('📄 Full Markdown security & architecture report written to: ${mdOutputFile.path}\n');

  print('════════════════════════════════════════════════════════════════════════════════');
  print('🎉 PocketBase Database Structure & Security Export Complete!');
  print('   • Markdown Report: pb_db_security_structure.md');
  print('   • Enriched JSON:   pb_db_structure.json');
  print('   • Raw JSON Schema: pocketbase_live_schema.json');
  print('════════════════════════════════════════════════════════════════════════════════');
}

List<Map<String, dynamic>> _extractFields(Map<String, dynamic> col) {
  final fields = (col['fields'] as List<dynamic>?) ??
      (col['schema'] as List<dynamic>?) ??
      [];
  return fields.map((e) => e as Map<String, dynamic>).toList();
}

String _ruleBadge(dynamic rule) {
  if (rule == null) return '🔒 ADMIN ONLY';
  if (rule == '') return '🔴 PUBLIC OPEN';
  return '🟡 AUTH SCOPED';
}

void _printTerminalSummary(
  List<Map<String, dynamic>> collections,
  Map<String, String> idToName,
  List<Map<String, dynamic>> relations,
) {
  print('📋 DATABASE SUMMARY: ${collections.length} COLLECTIONS, ${relations.length} RELATIONS');
  print('────────────────────────────────────────────────────────────────────────────────');

  for (final col in collections) {
    final name = col['name'] ?? '';
    final type = col['type'] ?? 'base';
    final id = col['id'] ?? '';
    final fields = _extractFields(col);

    print('\n📦 Collection: $name (Type: $type, ID: $id)');
    print('   API Rules:');
    print('     • List:   ${_ruleBadge(col['listRule'])} -> ${col['listRule'] ?? 'null'}');
    print('     • View:   ${_ruleBadge(col['viewRule'])} -> ${col['viewRule'] ?? 'null'}');
    print('     • Create: ${_ruleBadge(col['createRule'])} -> ${col['createRule'] ?? 'null'}');
    print('     • Update: ${_ruleBadge(col['updateRule'])} -> ${col['updateRule'] ?? 'null'}');
    print('     • Delete: ${_ruleBadge(col['deleteRule'])} -> ${col['deleteRule'] ?? 'null'}');
    if (type == 'auth') {
      print('     • Manage: ${_ruleBadge(col['manageRule'])} -> ${col['manageRule'] ?? 'null'}');
    }

    print('   Fields (${fields.length}):');
    for (final f in fields) {
      final fName = f['name'] ?? '';
      final fType = f['type'] ?? '';
      final isReq = f['required'] == true ? ' [REQ]' : '';
      final isSys = f['system'] == true ? ' [SYS]' : '';
      String extra = '';

      if (fType == 'relation') {
        final targetId = f['collectionId'] ?? f['options']?['collectionId'] ?? '';
        final targetName = idToName[targetId] ?? targetId;
        final max = f['maxSelect'] ?? f['options']?['maxSelect'] ?? 1;
        extra = ' ──> $targetName (max: $max)';
      } else if (fType == 'select') {
        final values = f['values'] ?? f['options']?['values'] ?? [];
        extra = ' $values';
      }

      print('     ├─ $fName ($fType)$isReq$isSys$extra');
    }
  }
  print('\n────────────────────────────────────────────────────────────────────────────────');
}

String _generateMarkdownReport({
  required List<Map<String, dynamic>> collections,
  required Map<String, String> idToName,
  required List<Map<String, dynamic>> relations,
  required Map<String, List<Map<String, dynamic>>> incomingRelations,
  required String sourceInfo,
}) {
  final buf = StringBuffer();

  buf.writeln('# PocketBase Database Security & Structure Report');
  buf.writeln();
  buf.writeln('> **Generated:** ${DateTime.now().toUtc().toIso8601String()} UTC  ');
  buf.writeln('> **Data Source:** $sourceInfo  ');
  buf.writeln('> **Total Collections:** ${collections.length}  ');
  buf.writeln('> **Total Foreign-Key Relations:** ${relations.length}  ');
  buf.writeln();

  // 1. Executive Security Analysis
  buf.writeln('## 1. Security Overview & API Rule Audit');
  buf.writeln();
  buf.writeln('| Collection | Type | List Rule | View Rule | Create Rule | Update Rule | Delete Rule |');
  buf.writeln('| :--- | :--- | :--- | :--- | :--- | :--- | :--- |');

  for (final col in collections) {
    final name = col['name'] ?? '';
    final type = col['type'] ?? 'base';
    final lR = _formatMdRule(col['listRule']);
    final vR = _formatMdRule(col['viewRule']);
    final cR = _formatMdRule(col['createRule']);
    final uR = _formatMdRule(col['updateRule']);
    final dR = _formatMdRule(col['deleteRule']);
    buf.writeln('| **`$name`** | `$type` | $lR | $vR | $cR | $uR | $dR |');
  }
  buf.writeln();

  // Public Rules Warning
  final publicRules = <String>[];
  for (final col in collections) {
    final name = col['name'] ?? '';
    if (col['listRule'] == '') publicRules.add('`$name.list`');
    if (col['viewRule'] == '') publicRules.add('`$name.view`');
    if (col['createRule'] == '') publicRules.add('`$name.create`');
    if (col['updateRule'] == '') publicRules.add('`$name.update`');
    if (col['deleteRule'] == '') publicRules.add('`$name.delete`');
  }

  if (publicRules.isNotEmpty) {
    buf.writeln('> [!WARNING]');
    buf.writeln('> **Public Open Endpoints Detected (`""` rule - No authentication required):**');
    for (final p in publicRules) {
      buf.writeln('> - $p');
    }
    buf.writeln();
  } else {
    buf.writeln('> [!NOTE]');
    buf.writeln('> No completely open/unauthenticated endpoints detected across all collections.');
    buf.writeln();
  }

  // 2. Entity-Relationship Graph (Mermaid)
  buf.writeln('## 2. Database Entity-Relationship Diagram');
  buf.writeln();
  buf.writeln('```mermaid');
  buf.writeln('erDiagram');

  for (final rel in relations) {
    final src = rel['sourceCollection'];
    final tgt = rel['targetCollection'];
    final fld = rel['sourceField'];
    final isMany = (rel['maxSelect'] as int? ?? 1) > 1;
    final relSymbol = isMany ? '}o--||' : '}o--||';
    buf.writeln('    $src $relSymbol $tgt : "$fld"');
  }
  buf.writeln('```');
  buf.writeln();

  // 3. Complete Foreign Key Relations Matrix
  buf.writeln('## 3. Foreign Key Relations Matrix');
  buf.writeln();
  buf.writeln('| Source Collection | Field Name | Target Collection | Cardinality | Cascade Delete | Required |');
  buf.writeln('| :--- | :--- | :--- | :--- | :--- | :--- |');

  for (final r in relations) {
    final src = r['sourceCollection'];
    final fld = r['sourceField'];
    final tgt = r['targetCollection'];
    final card = r['relationType'];
    final cascade = r['cascadeDelete'] == true ? '✅ Yes' : '❌ No';
    final req = r['required'] == true ? '✅ Yes' : '❌ No';
    buf.writeln('| **`$src`** | `$fld` | **`$tgt`** | $card | $cascade | $req |');
  }
  buf.writeln();

  // 4. Detailed Collection Specifications
  buf.writeln('## 4. Detailed Collection Specifications');
  buf.writeln();

  for (final col in collections) {
    final name = col['name'] ?? '';
    final type = col['type'] ?? 'base';
    final id = col['id'] ?? '';
    final system = col['system'] == true;
    final fields = _extractFields(col);
    final indexes = (col['indexes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    buf.writeln('### Collection: `$name`');
    buf.writeln();
    buf.writeln('- **Collection ID:** `$id`');
    buf.writeln('- **Type:** `$type` ${system ? '(System Collection)' : ''}');
    buf.writeln();

    // API Rules block
    buf.writeln('#### API Access Rules');
    buf.writeln('```');
    buf.writeln('List Rule:   ${col['listRule'] == null ? 'null (Superadmin Only)' : col['listRule'] == '' ? '"" (Public Open)' : col['listRule']}');
    buf.writeln('View Rule:   ${col['viewRule'] == null ? 'null (Superadmin Only)' : col['viewRule'] == '' ? '"" (Public Open)' : col['viewRule']}');
    buf.writeln('Create Rule: ${col['createRule'] == null ? 'null (Superadmin Only)' : col['createRule'] == '' ? '"" (Public Open)' : col['createRule']}');
    buf.writeln('Update Rule: ${col['updateRule'] == null ? 'null (Superadmin Only)' : col['updateRule'] == '' ? '"" (Public Open)' : col['updateRule']}');
    buf.writeln('Delete Rule: ${col['deleteRule'] == null ? 'null (Superadmin Only)' : col['deleteRule'] == '' ? '"" (Public Open)' : col['deleteRule']}');
    if (type == 'auth') {
      buf.writeln('Manage Rule: ${col['manageRule'] == null ? 'null (Superadmin Only)' : col['manageRule'] == '' ? '"" (Public Open)' : col['manageRule']}');
      buf.writeln('Auth Rule:   ${col['authRule'] ?? 'Default'}');
    }
    buf.writeln('```');
    buf.writeln();

    // Auth configuration (if auth collection)
    if (type == 'auth') {
      buf.writeln('#### Auth Configuration');
      buf.writeln('- **Password Auth Enabled:** ${col['passwordAuth']?['enabled'] ?? true}');
      buf.writeln('- **Identity Fields:** `${col['passwordAuth']?['identityFields'] ?? ['email', 'username']}`');
      buf.writeln('- **MFA Enabled:** ${col['mfa']?['enabled'] ?? false}');
      buf.writeln('- **OTP Enabled:** ${col['otp']?['enabled'] ?? false}');
      buf.writeln('- **Auth Token Duration:** `${col['authToken']?['duration'] ?? 'N/A'}`');
      buf.writeln();
    }

    // Indexes
    if (indexes.isNotEmpty) {
      buf.writeln('#### Database Indexes (${indexes.length})');
      for (final idx in indexes) {
        buf.writeln('- `$idx`');
      }
      buf.writeln();
    }

    // Incoming Relations
    final incoming = incomingRelations[name] ?? [];
    if (incoming.isNotEmpty) {
      buf.writeln('#### Referenced By (${incoming.length} Inbound Relations)');
      for (final inc in incoming) {
        buf.writeln('- `${inc['sourceCollection']}.${inc['sourceField']}` (${inc['relationType']})');
      }
      buf.writeln();
    }

    // Field table
    buf.writeln('#### Fields (${fields.length})');
    buf.writeln();
    buf.writeln('| Field Name | Type | Required | Unique | System | Details / Target / Constraints |');
    buf.writeln('| :--- | :--- | :--- | :--- | :--- | :--- |');

    for (final f in fields) {
      final fName = f['name'] ?? '';
      final fType = f['type'] ?? '';
      final fReq = f['required'] == true ? '✅' : '—';
      final fUniq = f['unique'] == true ? '✅' : '—';
      final fSys = f['system'] == true ? '🔒' : '—';
      final details = _formatFieldDetails(f, idToName);

      buf.writeln('| **`$fName`** | `$fType` | $fReq | $fUniq | $fSys | $details |');
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln();
  }

  return buf.toString();
}

String _formatMdRule(dynamic rule) {
  if (rule == null) return '🔒 `null`';
  if (rule == '') return '🔴 `""` *(Open)*';
  final rStr = rule.toString();
  if (rStr.length > 50) {
    return '🟡 `${rStr.substring(0, 47)}...`';
  }
  return '🟡 `$rStr`';
}

String _formatFieldDetails(Map<String, dynamic> f, Map<String, String> idToName) {
  final fType = f['type'] ?? '';
  final parts = <String>[];

  if (fType == 'relation') {
    final targetId = f['collectionId'] ?? f['options']?['collectionId'] ?? '';
    final targetName = idToName[targetId] ?? targetId;
    final max = f['maxSelect'] ?? f['options']?['maxSelect'] ?? 1;
    final cascade = f['cascadeDelete'] ?? f['options']?['cascadeDelete'] ?? false;
    parts.add('-> **`$targetName`** (max: $max${cascade == true ? ', cascadeDelete' : ''})');
  } else if (fType == 'select') {
    final values = f['values'] ?? f['options']?['values'] ?? [];
    final max = f['maxSelect'] ?? f['options']?['maxSelect'] ?? 1;
    parts.add('Options: `$values` (max: $max)');
  } else if (fType == 'file') {
    final maxSelect = f['maxSelect'] ?? f['options']?['maxSelect'] ?? 1;
    final maxSize = f['maxSize'] ?? f['options']?['maxSize'] ?? 'N/A';
    final mimeTypes = f['mimeTypes'] ?? f['options']?['mimeTypes'] ?? [];
    final isProtected = f['protected'] ?? f['options']?['protected'] ?? false;
    parts.add('maxSelect: $maxSelect, maxSize: ${maxSize}B${isProtected == true ? ', protected' : ''}');
    if (mimeTypes is List && mimeTypes.isNotEmpty) {
      parts.add('MIME: `${mimeTypes.join(", ")}`');
    }
  } else if (fType == 'text') {
    final min = f['min'] ?? f['options']?['min'];
    final max = f['max'] ?? f['options']?['max'];
    final pattern = f['pattern'] ?? f['options']?['pattern'];
    if (min != null && min > 0) parts.add('min: $min');
    if (max != null && max > 0) parts.add('max: $max');
    if (pattern != null && pattern.toString().isNotEmpty) parts.add('pattern: `$pattern`');
  } else if (fType == 'number') {
    final min = f['min'] ?? f['options']?['min'];
    final max = f['max'] ?? f['options']?['max'];
    final noDecimal = f['noDecimal'] ?? f['options']?['noDecimal'];
    if (min != null) parts.add('min: $min');
    if (max != null) parts.add('max: $max');
    if (noDecimal == true) parts.add('integer only');
  }

  return parts.isEmpty ? '—' : parts.join('; ');
}

Future<String> _adminAuth(HttpClient client, String pbUrl, String email, String password) async {
  final uri = Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password');
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode({'identity': email, 'password': password}));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  Map<String, dynamic> data = {};
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {}

  if (response.statusCode == 200 && data['token'] != null) {
    return data['token'] as String;
  }

  final mfaId = data['mfaId'] as String?;
  final bool isMfa = mfaId != null || response.statusCode == 401 || response.statusCode == 403;

  if (!isMfa && response.statusCode != 200) {
    throw 'Superadmin credential check failed (${response.statusCode}): ${data['message'] ?? body}';
  }

  print('   📲 OTP 2FA required for superadmin account: $email');
  stdout.write('   📨 Requesting OTP from PocketBase... ');

  final otpUri = Uri.parse('$pbUrl/api/collections/_superusers/request-otp');
  final otpReq = await client.postUrl(otpUri);
  otpReq.headers.contentType = ContentType.json;
  otpReq.write(jsonEncode({'email': email}));
  final otpRes = await otpReq.close();
  final otpBody = await otpRes.transform(utf8.decoder).join();

  if (otpRes.statusCode != 200) {
    throw 'Failed to send OTP (${otpRes.statusCode}): $otpBody';
  }

  final otpData = jsonDecode(otpBody) as Map<String, dynamic>;
  final otpId = otpData['otpId'] as String?;
  if (otpId == null) {
    throw 'PocketBase did not return an otpId: $otpBody';
  }
  print('✅ Sent!');
  print('\n   👉 Check your email ($email) for the 6-digit OTP code.');
  stdout.write('   🔑 Enter OTP Code: ');
  final otpCode = stdin.readLineSync()?.trim() ?? '';

  if (otpCode.isEmpty) {
    throw 'OTP code cannot be empty.';
  }

  stdout.write('   ⏳ Verifying OTP... ');
  final verifyUri = Uri.parse('$pbUrl/api/collections/_superusers/auth-with-otp');
  final verifyReq = await client.postUrl(verifyUri);
  verifyReq.headers.contentType = ContentType.json;
  verifyReq.write(jsonEncode({
    'otpId': otpId,
    'password': otpCode,
    if (mfaId != null) 'mfaId': mfaId,
  }));
  final verifyRes = await verifyReq.close();
  final verifyBody = await verifyRes.transform(utf8.decoder).join();

  if (verifyRes.statusCode != 200) {
    throw 'OTP verification failed (${verifyRes.statusCode}): $verifyBody';
  }

  final verifyData = jsonDecode(verifyBody) as Map<String, dynamic>;
  final token = verifyData['token'] as String?;
  if (token == null) {
    throw 'No token returned after OTP verification: $verifyBody';
  }
  print('✅ Verified!');
  return token;
}
