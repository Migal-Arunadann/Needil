/// Migration script: adds new workflow tracking fields to the 'appointments' collection.
///
/// Run with: dart run scripts/add_appointment_workflow_fields.dart
///
/// New fields added:
///   consultation_end_time  (date)   - when consultation form was submitted
///   patient_details_saved  (bool)   - patient details form fully submitted
///   patient_details_partial (bool)  - patient details form opened but not completed
///   treatment_plan_partial  (bool)  - treatment plan form opened but not submitted
///   linked_treatment_plan_id (text) - ID of the treatment plan linked to this appointment

import 'package:pocketbase/pocketbase.dart';

const _pbUrl = 'http://127.0.0.1:8090';
const _adminEmail = 'YOUR_ADMIN_EMAIL';
const _adminPassword = 'YOUR_ADMIN_PASSWORD';

void main() async {
  final pb = PocketBase(_pbUrl);

  print('🔐 Authenticating...');
  await pb.admins.authWithPassword(_adminEmail, _adminPassword);
  print('✅ Authenticated');

  // Fetch appointments collection schema
  final collections = await pb.collections.getFullList();
  final apptCollection = collections.firstWhere(
    (c) => c.name == 'appointments',
    orElse: () => throw Exception('appointments collection not found'),
  );

  print('\n📋 Current appointments schema fields:');
  final existingFieldNames = <String>{};
  for (final f in apptCollection.schema) {
    existingFieldNames.add(f.name);
    print('  - ${f.name} (${f.type})');
  }

  // Define new fields to add
  final newFields = <Map<String, dynamic>>[];

  void addFieldIfMissing(String name, String type, [Map<String, dynamic> extra = const {}]) {
    if (!existingFieldNames.contains(name)) {
      newFields.add({'name': name, 'type': type, 'required': false, ...extra});
      print('  ➕ Queued: $name ($type)');
    } else {
      print('  ✓ Already exists: $name');
    }
  }

  print('\n🔍 Checking fields to add...');
  addFieldIfMissing('consultation_end_time', 'date');
  addFieldIfMissing('patient_details_saved', 'bool');
  addFieldIfMissing('patient_details_partial', 'bool');
  addFieldIfMissing('treatment_plan_partial', 'bool');
  addFieldIfMissing('linked_treatment_plan_id', 'text');

  if (newFields.isEmpty) {
    print('\n✅ All fields already exist. Nothing to do.');
    return;
  }

  // Build updated schema
  final updatedSchema = [
    ...apptCollection.schema.map((f) => f.toJson()),
    ...newFields,
  ];

  print('\n💾 Updating appointments collection...');
  await pb.collections.update(
    apptCollection.id,
    body: {'schema': updatedSchema},
  );

  print('\n✅ Done! Added ${newFields.length} field(s) to appointments collection.');
  print('   Fields added: ${newFields.map((f) => f['name']).join(', ')}');
}
