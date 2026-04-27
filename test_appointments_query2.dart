import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  
  Future<void> runQuery(String name, String? filter, String? sort) async {
    try {
      final res = await pb.collection('appointments').getList(
        filter: filter,
        sort: sort,
        perPage: 200,
      );
      print('SUCCESS $name: ${res.items.length}');
    } on ClientException catch (e) {
      print('ERROR $name: ${e.response}');
    } catch (e) {
      print('OTHER ERROR $name: $e');
    }
  }

  // Test 1: No sort
  await runQuery('No Sort', 'patient = "z4sueb4otr3ueyy"', null);
  // Test 2: Sort by time
  await runQuery('Sort by time', 'patient = "z4sueb4otr3ueyy"', '-time');
  // Test 3: Sort by created
  await runQuery('Sort by created', 'patient = "z4sueb4otr3ueyy"', '-created');
  // Test 4: No filter, sort created
  await runQuery('No filter, Sort created', null, '-created');
}
