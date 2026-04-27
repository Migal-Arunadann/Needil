import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  try {
    final res = await pb.collection('appointments').getList(
      filter: 'patient = "z4sueb4otr3ueyy"',
      sort: '-created',
      perPage: 200,
    );
    print('SUCCESS: ${res.items.length}');
  } on ClientException catch (e) {
    print('ERROR: ${e.response}');
  } catch (e) {
    print('OTHER ERROR: $e');
  }
}
