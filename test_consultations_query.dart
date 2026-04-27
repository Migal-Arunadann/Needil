import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io');
  
  try {
    final res = await pb.collection('consultations').getList(
      sort: '-created',
      perPage: 1,
    );
    print('SUCCESS consultations: ${res.items.length}');
  } on ClientException catch (e) {
    print('ERROR consultations: ${e.response}');
  } catch (e) {
    print('OTHER ERROR consultations: $e');
  }
}
