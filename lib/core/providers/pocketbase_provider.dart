import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

/// The base URL of the PocketBase server (HTTPS enabled via Let's Encrypt).
const String pbBaseUrl = 'https://api.needil.com';

/// Provides a singleton [PocketBase] client instance.
final pocketbaseProvider = Provider<PocketBase>((ref) {
  return PocketBase(pbBaseUrl);
});

