import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('https://api.needil.com');
  try {
    await pb.collection('clinics').authWithOAuth2Code(
      'google',
      'dummy_code',
      'dummy_verifier',
      '',
    );
  } catch (e) {
    print(e.toString());
  }
}
