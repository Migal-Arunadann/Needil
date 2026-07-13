import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('https://api.needil.com');
  final authMethods = await pb.collection('clinics').listAuthMethods();
  for (var p in authMethods.oauth2.providers) {
    if (p.name == 'google') {
      print('AuthURL: ${p.authURL}');
    }
  }
}
