/// PocketBase schema update script for billing fields.
///
/// Run this once to add billing fields to the clinics collection:
///   dart run scripts/update_billing_schema.dart <admin_email> <admin_password>
library;

import 'dart:io';
import 'dart:convert';

const String pbUrl =
    'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run scripts/update_billing_schema.dart <admin_email> <admin_password>');
    exit(1);
  }

  final email = args[0];
  final password = args[1];
  final client = HttpClient();

  try {
    print('🔐 Authenticating as admin...');
    final token = await _adminAuth(client, email, password);
    print('✅ Authenticated');

    print('📦 Fetching clinics collection schema...');
    final collection = await _getCollection(client, token, 'clinics');
    
    print('🔧 Updating schema with billing fields...');
    final currentSchema = List<Map<String, dynamic>>.from(collection['schema'] as List);
    
    // Add new fields
    currentSchema.add({
      'name': 'subscription_status',
      'type': 'select',
      'options': {
        'maxSelect': 1,
        'values': ['trialing', 'active', 'past_due', 'canceled']
      }
    });
    
    currentSchema.add({
      'name': 'subscription_end_date',
      'type': 'date'
    });
    
    currentSchema.add({
      'name': 'razorpay_customer_id',
      'type': 'text'
    });
    
    currentSchema.add({
      'name': 'razorpay_subscription_id',
      'type': 'text'
    });

    collection['schema'] = currentSchema;

    print('📤 Pushing updated schema...');
    await _updateCollection(client, token, 'clinics', collection);
    print('✅ Billing schema updated successfully!');
    
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    client.close();
  }
}

Future<String> _adminAuth(HttpClient client, String email, String password) async {
  final uri = Uri.parse('$pbUrl/api/collections/_superusers/auth-with-password');
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

Future<Map<String, dynamic>> _getCollection(HttpClient client, String token, String name) async {
  final uri = Uri.parse('$pbUrl/api/collections/$name');
  final request = await client.getUrl(uri);
  request.headers.set('Authorization', token);
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode != 200) {
    throw 'Failed to fetch collection $name (${response.statusCode}): $body';
  }
  return jsonDecode(body) as Map<String, dynamic>;
}

Future<void> _updateCollection(
    HttpClient client, String token, String name, Map<String, dynamic> col) async {
  final uri = Uri.parse('$pbUrl/api/collections/$name');
  final request = await client.patchUrl(uri);
  request.headers.contentType = ContentType.json;
  request.headers.set('Authorization', token);
  request.write(jsonEncode(col));
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode != 200) {
    throw 'Failed to update $name (${response.statusCode}): $body';
  }
}
