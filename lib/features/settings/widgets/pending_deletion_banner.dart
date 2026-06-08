import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/clinic_deletion_service.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

/// Full-width warning banner shown at the top of the clinic dashboard
/// when the clinic has requested deletion (status = 'pending_deletion').
///
/// Shows the purge date countdown and a "Request Reactivation" button.
class PendingDeletionBanner extends ConsumerStatefulWidget {
  const PendingDeletionBanner({super.key});

  @override
  ConsumerState<PendingDeletionBanner> createState() =>
      _PendingDeletionBannerState();
}

class _PendingDeletionBannerState
    extends ConsumerState<PendingDeletionBanner> {
  bool _isSubmitting = false;

  int _daysRemaining(DateTime? purgeAt) {
    if (purgeAt == null) return 30;
    return purgeAt.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'soon';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _showReactivationDialog() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.restore_rounded, color: Color(0xFF10B981), size: 22),
          SizedBox(width: 10),
          Text('Request Reactivation',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Your reactivation request will be reviewed by the Needil team. '
            'Approval is required to restore your clinic access.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Reason for reactivation (required)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Please provide a reason'),
                  backgroundColor: Color(0xFFEF4444),
                ));
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final reason = reasonCtrl.text.trim();
    final auth = ref.read(authProvider);
    final clinicId = auth.clinic?.id ?? '';
    final clinicName = auth.clinic?.name ?? '';
    final userId = auth.userId ?? clinicId;

    setState(() => _isSubmitting = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final svc = ClinicDeletionService(pb);
      final error = await svc.requestReactivation(
        clinicId: clinicId,
        clinicName: clinicName,
        requestedBy: userId,
        reason: reason,
      );
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFEF4444),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              '✓ Reactivation request submitted. You will be notified once reviewed.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isPendingDeletion) return const SizedBox.shrink();

    final days = _daysRemaining(auth.purgeAt);
    final dateStr = _formatDate(auth.purgeAt);
    final urgentColor = days <= 7
        ? const Color(0xFFEF4444)
        : days <= 14
            ? const Color(0xFFF59E0B)
            : const Color(0xFFF59E0B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: urgentColor.withOpacity(0.12),
        border: Border(
          bottom: BorderSide(color: urgentColor.withOpacity(0.4), width: 1),
        ),
      ),
      child: Row(children: [
        Icon(
          days <= 7
              ? Icons.error_rounded
              : Icons.warning_amber_rounded,
          color: urgentColor,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clinic Scheduled For Deletion',
                style: TextStyle(
                  color: urgentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                'Deletion Date: $dateStr ($days days remaining). '
                'Submit a reactivation request to restore access.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : TextButton(
                onPressed: _showReactivationDialog,
                style: TextButton.styleFrom(
                  backgroundColor: urgentColor.withOpacity(0.2),
                  foregroundColor: urgentColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Request Reactivation',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
      ]),
    );
  }
}
