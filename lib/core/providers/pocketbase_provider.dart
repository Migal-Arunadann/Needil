import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

/// The base URL of the PocketBase server.
const String pbBaseUrl =
    'http://pocketbase-ibzovc8gc0m0e8mt4g1pw5aa.178.16.138.198.sslip.io';

/// Provides a singleton [PocketBase] client instance.
final pocketbaseProvider = Provider<PocketBase>((ref) {
  return PocketBase(pbBaseUrl);
});
