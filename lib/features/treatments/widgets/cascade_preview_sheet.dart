import 'package:flutter/material.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/scheduling/treatment_scheduler.dart';
import 'package:intl/intl.dart';

class CascadePreviewSheet extends StatelessWidget {
  final ReschedulePreview preview;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool applyTimeToAll;
  final ValueChanged<bool>? onToggleApplyTimeToAll;
  final String? newTime;
  final bool isRegenerating;

  const CascadePreviewSheet({
    super.key,
    required this.preview,
    required this.onConfirm,
    required this.onCancel,
    this.applyTimeToAll = false,
    this.onToggleApplyTimeToAll,
    this.newTime,
    this.isRegenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    final proposal = preview.proposal;
    final validation = preview.validation;
    final slots = proposal.slots;

    int moved = 0;
    int skipped = 0;
    int unchanged = 0;

    for (final slot in slots) {
      if (slot.wasPinned && !slot.isTarget) {
        skipped++;
      } else if (slot.oldDate != slot.newDate || slot.oldTime != slot.newTime) {
        moved++;
      } else {
        unchanged++;
      }
    }
    
    // Add sessions that failed to get a slot
    final noSlotCount = proposal.totalExpected - slots.where((s) => !s.wasPinned).length;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_available_rounded, color: context.colors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview Reschedule',
                      style: context.textStyles.h3,
                    ),
                    Text(
                      'Review changes before confirming',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCancel,
                icon: Icon(Icons.close_rounded, color: context.colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (!validation.isValid)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: context.colors.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      validation.failureReason ?? 'Scheduling conflict detected.',
                      style: context.textStyles.bodyMedium.copyWith(color: context.colors.error),
                    ),
                  ),
                ],
              ),
            ),
            
          if (validation.warnings.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.warning.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: context.colors.warning, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Warnings',
                        style: context.textStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...validation.warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(left: 28, bottom: 4),
                        child: Text(
                          '• $w',
                          style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
                        ),
                      )),
                ],
              ),
            ),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: slots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final slot = slots[index];
                final isMoved = slot.oldDate != slot.newDate || slot.oldTime != slot.newTime;
                final isSkipped = slot.wasPinned && !slot.isTarget;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSkipped
                              ? context.colors.divider
                              : (isMoved
                                  ? context.colors.primary.withValues(alpha: 0.1)
                                  : context.colors.success.withValues(alpha: 0.1)),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${slot.sessionNumber}',
                          style: context.textStyles.bodyMedium.copyWith(
                            color: isSkipped
                                ? context.colors.textSecondary
                                : (isMoved ? context.colors.primary : context.colors.success),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _formatDate(slot.newDate),
                                  style: context.textStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: isSkipped ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (slot.newTime.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTime(slot.newTime),
                                    style: context.textStyles.bodyMedium.copyWith(
                                      color: context.colors.textSecondary,
                                      decoration: isSkipped ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (isMoved && !isSkipped)
                              Text(
                                'was ${_formatDate(slot.oldDate)} ${_formatTime(slot.oldTime)}',
                                style: context.textStyles.caption.copyWith(
                                  color: context.colors.textHint,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (slot.isTarget)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Target',
                            style: context.textStyles.caption.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (isSkipped)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.colors.divider,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.push_pin_rounded, size: 12, color: context.colors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Pinned',
                                style: context.textStyles.caption.copyWith(
                                  color: context.colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          if (noSlotCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: context.colors.warning),
                  const SizedBox(width: 8),
                  Text(
                    '+ $noSlotCount session(s) could not be scheduled',
                    style: context.textStyles.caption.copyWith(color: context.colors.warning),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),
          
          // Summary Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.divider,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(context, '$moved', 'Moved', context.colors.primary),
                _buildSummaryStat(context, '$unchanged', 'Unchanged', context.colors.success),
                if (skipped > 0) _buildSummaryStat(context, '$skipped', 'Pinned', context.colors.textSecondary),
                if (noSlotCount > 0) _buildSummaryStat(context, '$noSlotCount', 'No Slot', context.colors.error),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (onToggleApplyTimeToAll != null && moved > 0) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'Update future sessions to new time${newTime != null ? ' ($newTime)' : ''}',
                style: context.textStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
              ),
              value: applyTimeToAll,
              onChanged: (val) {
                if (val != null) onToggleApplyTimeToAll!(val);
              },
              activeColor: context.colors.primary,
            ),
            const SizedBox(height: 16),
          ],
          if (isRegenerating)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: context.colors.border),
                    ),
                    child: Text(
                      'Cancel',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: validation.isValid ? onConfirm : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Confirm',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: context.textStyles.h3.copyWith(color: color),
        ),
        Text(
          label,
          style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      // timeStr might be "10:30" or "10:30:00"
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
        return DateFormat('h:mm a').format(dt);
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }
}
