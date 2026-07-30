import 'package:flutter/material.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class ConflictWarningDialog extends StatelessWidget {
  final int successfulMoves;
  final int skippedSessions;
  final int totalConflicts;

  const ConflictWarningDialog({
    super.key,
    required this.successfulMoves,
    required this.skippedSessions,
    required this.totalConflicts,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: context.colors.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, size: 48, color: context.colors.warning),
            ),
            const SizedBox(height: 24),
            Text(
              'Scheduling Conflicts',
              style: context.textStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Some sessions could not be rescheduled due to conflicts or lack of availability.',
              style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.divider,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildRow(context, 'Successfully Moved', '$successfulMoves', context.colors.success),
                  const Divider(height: 16),
                  _buildRow(context, 'Skipped (Pinned)', '$skippedSessions', context.colors.textSecondary),
                  const Divider(height: 16),
                  _buildRow(context, 'Conflicts / No Slot', '$totalConflicts', context.colors.error),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: context.colors.border),
                    ),
                    child: Text('Close', style: context.textStyles.bodyMedium),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/scheduling/exceptions');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('View Exceptions', style: context.textStyles.bodyMedium.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: context.textStyles.bodyMedium),
        Text(
          value,
          style: context.textStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
