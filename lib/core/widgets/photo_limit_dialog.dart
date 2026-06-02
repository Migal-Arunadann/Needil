import 'package:flutter/material.dart';
import 'package:pms_app/core/theme/app_theme.dart';

/// Shows a dialog when the clinic's photo upload limit has been reached.
///
/// [used] and [limit] are the current quota values.
/// [onManagePhotos] is called when the user taps "Manage Photos".
/// [isClinicAdmin] controls whether the "Upgrade Plan" button is shown.
Future<void> showPhotoLimitDialog(
  BuildContext context, {
  required int used,
  required int limit,
  VoidCallback? onManagePhotos,
  bool isClinicAdmin = true,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ctx.colors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.photo_library_rounded, color: ctx.colors.warning, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Photo Limit Reached',
              style: ctx.textStyles.h4,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your clinic has used all available photo uploads.',
            style: ctx.textStyles.bodyMedium,
          ),
          const SizedBox(height: 16),

          // Quota bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ctx.colors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ctx.colors.error.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Photos Used', style: ctx.textStyles.labelSmall),
                    Text(
                      '$used / $limit',
                      style: ctx.textStyles.label.copyWith(
                        color: ctx.colors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: limit > 0 ? (used / limit).clamp(0.0, 1.0) : 1.0,
                    backgroundColor: ctx.colors.border,
                    valueColor: AlwaysStoppedAnimation(ctx.colors.error),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Free up space by deleting old photos, or contact your clinic administrator to upgrade your plan.',
            style: ctx.textStyles.bodySmall,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        if (onManagePhotos != null)
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              onManagePhotos();
            },
            icon: Icon(Icons.delete_sweep_rounded, size: 18, color: ctx.colors.primary),
            label: Text(
              'Manage Photos',
              style: TextStyle(color: ctx.colors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        if (isClinicAdmin)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Upgrade plans coming soon!'),
                  backgroundColor: context.colors.info,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            icon: const Icon(Icons.rocket_launch_rounded, size: 18),
            label: const Text('Upgrade Plan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.colors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        if (!isClinicAdmin && onManagePhotos == null)
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: ctx.colors.textSecondary)),
          ),
      ],
    ),
  );
}
