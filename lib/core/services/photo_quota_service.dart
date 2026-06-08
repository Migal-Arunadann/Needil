import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

/// Manages per-clinic photo upload quotas.
///
/// Every clinical photo (consultation + session) counts toward the clinic's
/// lifetime upload limit. Doctor uploads are attributed to the parent clinic.
class PhotoQuotaService {
  final PocketBase pb;

  PhotoQuotaService(this.pb);

  /// Returns (photosUsed, photoLimit) for the given clinic.
  Future<(int, int)> getQuota(String clinicId) async {
    final record = await pb.collection(PBCollections.clinics).getOne(clinicId);
    final used = record.getIntValue('photos_used');
    final limit = record.getIntValue('photo_limit');
    return (used, limit > 0 ? limit : 2000);
  }

  /// Check if uploading [count] more photos is within the clinic's limit.
  Future<bool> canUpload(String clinicId, int count) async {
    final (used, limit) = await getQuota(clinicId);
    return (used + count) <= limit;
  }

  /// Get remaining upload quota.
  Future<int> getRemainingQuota(String clinicId) async {
    final (used, limit) = await getQuota(clinicId);
    return (limit - used).clamp(0, limit);
  }

  /// Increment the photos_used counter after a successful upload.
  Future<void> incrementUsage(String clinicId, int count) async {
    if (count <= 0) return;
    final record = await pb.collection(PBCollections.clinics).getOne(clinicId);
    final currentUsed = record.getIntValue('photos_used');
    await pb.collection(PBCollections.clinics).update(clinicId, body: {
      'photos_used': currentUsed + count,
    });
    debugPrint('[PhotoQuota] Incremented for $clinicId: $currentUsed → ${currentUsed + count}');
  }

  /// Decrement the photos_used counter after photo deletion. Clamps to 0.
  Future<void> decrementUsage(String clinicId, int count) async {
    if (count <= 0) return;
    final record = await pb.collection(PBCollections.clinics).getOne(clinicId);
    final currentUsed = record.getIntValue('photos_used');
    final newUsed = (currentUsed - count).clamp(0, 999999);
    await pb.collection(PBCollections.clinics).update(clinicId, body: {
      'photos_used': newUsed,
    });
    debugPrint('[PhotoQuota] Decremented for $clinicId: $currentUsed → $newUsed');
  }

  /// Resolve the clinic ID for the current authenticated user.
  /// Works for both clinic logins (direct ID) and doctor logins (lookup via relation).
  Future<String?> resolveClinicId({
    String? clinicId,
    String? doctorId,
  }) async {
    if (clinicId != null && clinicId.isNotEmpty) return clinicId;
    if (doctorId != null && doctorId.isNotEmpty) {
      try {
        final doc = await pb.collection(PBCollections.doctors).getOne(doctorId);
        return doc.getStringValue('clinic');
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// Provides a singleton [PhotoQuotaService] instance.
final photoQuotaServiceProvider = Provider<PhotoQuotaService>((ref) {
  return PhotoQuotaService(ref.read(pocketbaseProvider));
});
