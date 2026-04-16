/// Script to add the consultation_start_time field to the appointments collection in PocketBase.
/// Run this with: dart run scripts/add_consultation_start_time.dart
///
/// Make sure to set the correct PocketBase URL and admin credentials below.
library;

import 'package:pocketbase/pocketbase.dart';

void main() async {
  // ===== CONFIGURATION =====
  final pbUrl = 'http://YOUR_POCKETBASE_URL:8090';
  final adminEmail = 'YOUR_ADMIN_EMAIL';
  final adminPassword = 'YOUR_ADMIN_PASSWORD';
  // ==========================

  final pb = PocketBase(pbUrl);
  await pb.admins.authWithPassword(adminEmail, adminPassword);

  print('Authenticated as admin.');
  print('Adding consultation_start_time field to appointments collection...');

  try {
    // Get the appointments collection
    final collections = await pb.collections.getList();
    final apptCollection = collections.items.firstWhere(
      (c) => c.name == 'appointments',
      orElse: () => throw Exception('appointments collection not found'),
    );

    // Check if field already exists
    final existingFields = apptCollection.schema;
    final hasField = existingFields.any(
      (f) => f['name'] == 'consultation_start_time',
    );

    if (hasField) {
      print('Field consultation_start_time already exists. Skipping.');
      return;
    }

    // Add the new field
    final updatedSchema = [
      ...existingFields,
      {
        'name': 'consultation_start_time',
        'type': 'date',
        'required': false,
        'options': {'min': '', 'max': ''},
      },
    ];

    await pb.collections.update(
      apptCollection.id,
      body: {'schema': updatedSchema},
    );

    print('✓ consultation_start_time field added successfully!');
  } catch (e) {
    print('Error: $e');
  }
}
