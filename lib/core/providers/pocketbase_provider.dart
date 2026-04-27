import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

/// The base URL of the PocketBase server (HTTPS enabled via Let's Encrypt).
const String pbBaseUrl = 'https://api.needil.com';

/// Provides a singleton [PocketBase] client instance.
final pocketbaseProvider = Provider<PocketBase>((ref) {
  return PocketBase(pbBaseUrl);
});

