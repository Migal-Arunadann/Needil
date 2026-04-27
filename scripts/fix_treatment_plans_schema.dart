import 'dart:io';
import 'dart:convert';

const String pbUrl = 'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main() async {
  final client = HttpClient();
  try {
    print('🔐 Authenticating...');
    final req = await client.postUrl(Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'identity': 'psairampg@gmail.com', 'password': 'Valam\$13245687'}));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) throw 'Auth failed: $body';
    final token = (jsonDecode(body))['token'] as String;

    print('📦 Fetching collections...');
    final cReq = await client.getUrl(Uri.parse('$pbUrl/api/collections?perPage=500'));
    cReq.headers.set('Authorization', token);
    final cRes = await cReq.close();
    final cBody = await cRes.transform(utf8.decoder).join();
    final allCols = (jsonDecode(cBody) as Map<String, dynamic>)['items'] as List<dynamic>;
    final colMap = {for (var c in allCols) c['name']: c['id']};

    final req2 = await client.getUrl(Uri.parse('$pbUrl/api/collections/treatment_plans'));
    req2.headers.set('Authorization', token);
    final res2 = await req2.close();
    final body2 = await res2.transform(utf8.decoder).join();
    final col = jsonDecode(body2) as Map<String, dynamic>;
    
    final fields = List<Map<String, dynamic>>.from(col['fields'] as List? ?? []);
    
    final missingFields = [
      {'name': 'patient', 'type': 'relation', 'required': false, 'options': {'collectionId': colMap['patients'], 'maxSelect': 1}},
      {'name': 'doctor', 'type': 'relation', 'required': false, 'options': {'collectionId': colMap['doctors'], 'maxSelect': 1}},
      {'name': 'consultation', 'type': 'relation', 'required': false, 'options': {'collectionId': colMap['consultations'], 'maxSelect': 1}},
      {'name': 'treatment_type', 'type': 'text', 'required': false},
      {'name': 'start_date', 'type': 'text', 'required': false},
      {'name': 'total_sessions', 'type': 'number', 'required': false},
      {'name': 'interval_days', 'type': 'number', 'required': false},
      {'name': 'session_fee', 'type': 'number', 'required': false},
      {'name': 'status', 'type': 'text', 'required': false},
    ];

    for (var mf in missingFields) {
      if (!fields.any((f) => f['name'] == mf['name'])) {
        final fieldData = {
          'name': mf['name'],
          'type': mf['type'],
          'required': mf['required'],
        };
        if (mf['options'] != null) {
          fieldData.addAll(mf['options'] as Map<String, dynamic>);
        }
        fields.add(fieldData);
      }
    }
    
    print('🚀 Updating schema...');
    final patchReq = await client.openUrl('PATCH', Uri.parse('$pbUrl/api/collections/${col['id']}'));
    patchReq.headers.contentType = ContentType.json;
    patchReq.headers.set('Authorization', token);
    patchReq.write(jsonEncode({'fields': fields}));
    
    final patchRes = await patchReq.close();
    final patchBody = await patchRes.transform(utf8.decoder).join();
    if (patchRes.statusCode == 200) {
      print('✅ Schema updated successfully!');
    } else {
      print('❌ Failed to patch: $patchBody');
    }
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    client.close();
  }
}
