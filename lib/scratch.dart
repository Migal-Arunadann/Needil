import 'package:pocketbase/pocketbase.dart'; void main() { final pb = PocketBase('http://a'); pb.collection('a').authWithOAuth2Code('google', 'code', 'codeVerifier', 'redirectUrl'); }
