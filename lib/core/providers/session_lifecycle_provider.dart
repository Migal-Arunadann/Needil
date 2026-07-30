import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/services/session_lifecycle_service.dart';

/// Provides a singleton [SessionLifecycleService] instance.
///
/// Using a singleton ensures:
///   1. All call sites share the same [AuditLogger] instance, so event hooks
///      registered anywhere persist for the app's lifetime.
///   2. The same [TreatmentLifecycle] and [TreatmentScheduler] are reused,
///      avoiding redundant object construction on every scheduling call.
///
/// Usage:
/// `dart
/// final lifecycle = ref.read(sessionLifecycleServiceProvider);
/// await lifecycle.checkAndMarkMissedSessions(doctorId);
/// `
final sessionLifecycleServiceProvider = Provider<SessionLifecycleService>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return SessionLifecycleService(pb);
});
