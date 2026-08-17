import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/scheduling/treatment_scheduler.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/scheduling/screens/available_slots_screen.dart';
import 'package:intl/intl.dart';

class CascadePreviewSheet extends ConsumerStatefulWidget {
  final ReschedulePreview preview;
  final ValueChanged<ReschedulePreview> onConfirm;
  final VoidCallback onCancel;
  final bool applyTimeToAll;
  final ValueChanged<bool>? onToggleApplyTimeToAll;
  final String? newTime;
  final bool isRegenerating;
  final bool isDialogMode;
  final String? doctorId;
  final String? clinicId;
  final int treatmentDuration;
  final Future<ReschedulePreview> Function({
    required String sessionId,
    required String newDate,
    String? newTime,
    bool applyTimeToAll,
    int? overrideIntervalDays,
  })? onRegenerate;

  const CascadePreviewSheet({
    super.key,
    required this.preview,
    required this.onConfirm,
    required this.onCancel,
    this.applyTimeToAll = false,
    this.onToggleApplyTimeToAll,
    this.newTime,
    this.isRegenerating = false,
    this.isDialogMode = false,
    this.doctorId,
    this.clinicId,
    this.treatmentDuration = 30,
    this.onRegenerate,
  });

  /// Unified display helper that shows as a Centered Dialog on Web/Desktop and a Bottom Sheet on Mobile.
  static Future<ReschedulePreview?> show({
    required BuildContext context,
    required ReschedulePreview preview,
    String? newTime,
    String? doctorId,
    String? clinicId,
    int treatmentDuration = 30,
    bool applyTimeToAll = false,
    ValueChanged<bool>? onToggleApplyTimeToAll,
    Future<ReschedulePreview> Function({
      required String sessionId,
      required String newDate,
      String? newTime,
      bool applyTimeToAll,
      int? overrideIntervalDays,
    })? onRegenerate,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      return showDialog<ReschedulePreview?>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 820),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CascadePreviewSheet(
                  preview: preview,
                  newTime: newTime,
                  doctorId: doctorId,
                  clinicId: clinicId,
                  treatmentDuration: treatmentDuration,
                  applyTimeToAll: applyTimeToAll,
                  onToggleApplyTimeToAll: onToggleApplyTimeToAll,
                  onRegenerate: onRegenerate,
                  isDialogMode: true,
                  onConfirm: (p) => Navigator.pop(ctx, p),
                  onCancel: () => Navigator.pop(ctx, null),
                ),
              ),
            ),
          );
        },
      );
    } else {
      return showModalBottomSheet<ReschedulePreview?>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + kToolbarHeight),
            child: CascadePreviewSheet(
              preview: preview,
              newTime: newTime,
              doctorId: doctorId,
              clinicId: clinicId,
              treatmentDuration: treatmentDuration,
              applyTimeToAll: applyTimeToAll,
              onToggleApplyTimeToAll: onToggleApplyTimeToAll,
              onRegenerate: onRegenerate,
              isDialogMode: false,
              onConfirm: (p) => Navigator.pop(ctx, p),
              onCancel: () => Navigator.pop(ctx, null),
            ),
          );
        },
      );
    }
  }

  @override
  ConsumerState<CascadePreviewSheet> createState() => _CascadePreviewSheetState();
}

class _CascadePreviewSheetState extends ConsumerState<CascadePreviewSheet> {
  late ReschedulePreview _currentPreview;
  late int _intervalDays;
  late bool _applyTimeToAll;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentPreview = widget.preview;
    final prop = widget.preview.proposal;
    _intervalDays = prop.updatedIntervalDays ??
        (prop.currentIntervalDays > 0 ? prop.currentIntervalDays : 1);
    _applyTimeToAll = widget.applyTimeToAll;
  }

  @override
  void didUpdateWidget(covariant CascadePreviewSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview != widget.preview) {
      _currentPreview = widget.preview;
    }
  }

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDateStr(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  DateTime _addDaysSkippingSundays(DateTime from, int days) {
    var dt = from;
    final step = days > 0 ? days : 1;
    for (int i = 0; i < step; i++) {
      dt = dt.add(const Duration(days: 1));
      if (dt.weekday == DateTime.sunday) {
        dt = dt.add(const Duration(days: 1));
      }
    }
    return dt;
  }

  Future<void> _updateInterval(int newInterval) async {
    if (newInterval < 1 || newInterval > 30 || _isProcessing) return;
    HapticFeedback.lightImpact();

    setState(() {
      _intervalDays = newInterval;
      _isProcessing = true;
    });

    final targetSlot = _currentPreview.proposal.slots.firstWhere(
      (s) => s.isTarget,
      orElse: () => _currentPreview.proposal.slots.first,
    );

    if (widget.onRegenerate != null) {
      try {
        final newPreview = await widget.onRegenerate!(
          sessionId: targetSlot.sessionId,
          newDate: targetSlot.newDate,
          newTime: targetSlot.newTime,
          applyTimeToAll: _applyTimeToAll,
          overrideIntervalDays: _intervalDays,
        );
        if (mounted) {
          setState(() {
            _currentPreview = newPreview;
            _isProcessing = false;
          });
        }
        return;
      } catch (_) {}
    }

    // In-memory cascade recalculation fallback
    _recalculateSlotsInMemory(newInterval: _intervalDays);
    if (mounted) setState(() => _isProcessing = false);
  }

  void _recalculateSlotsInMemory({int? newInterval, int fromIndex = 0}) {
    final interval = newInterval ?? _intervalDays;
    final currentSlots = List<ProposedSlot>.from(_currentPreview.proposal.slots);
    if (currentSlots.isEmpty) return;

    for (int i = fromIndex + 1; i < currentSlots.length; i++) {
      if (currentSlots[i].wasPinned && !currentSlots[i].isTarget) continue;

      final prevDate = _parseDate(currentSlots[i - 1].newDate);
      final nextDate = _addDaysSkippingSundays(prevDate, interval);
      final nextDateStr = _formatDateStr(nextDate);

      currentSlots[i] = currentSlots[i].copyWith(
        newDate: nextDateStr,
        newTime: _applyTimeToAll && widget.newTime != null
            ? widget.newTime!
            : currentSlots[i].newTime,
      );
    }

    final updatedProposal = _currentPreview.proposal.copyWith(
      slots: currentSlots,
      updatedIntervalDays: interval,
    );

    _currentPreview = ReschedulePreview(
      updatedProposal,
      const ValidationResult.ok(),
    );
  }

  Future<void> _onPickSessionDate(int index) async {
    final slots = _currentPreview.proposal.slots;
    if (index < 0 || index >= slots.length || _isProcessing) return;
    HapticFeedback.lightImpact();

    final targetSlot = slots[index];
    final currentDt = _parseDate(targetSlot.newDate);

    // Constraint: Session N+1 must be strictly after Session N
    DateTime minDate;
    if (index == 0) {
      minDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    } else {
      final prevDate = _parseDate(slots[index - 1].newDate);
      minDate = prevDate.add(const Duration(days: 1));
    }

    final initialDate = currentDt.isBefore(minDate) ? minDate : currentDt;

    // Resolve doctorId from widget or lookup
    String? resolvedDoctorId = widget.doctorId;
    if (resolvedDoctorId == null || resolvedDoctorId.isEmpty) {
      try {
        final pb = ref.read(pocketbaseProvider);
        final sess = await pb.collection('sessions').getOne(targetSlot.sessionId, expand: 'treatment_plan');
        resolvedDoctorId = sess.getStringValue('doctor');
        final planExpand = sess.expand['treatment_plan'];
        if ((resolvedDoctorId == null || resolvedDoctorId.isEmpty) && planExpand != null && planExpand.isNotEmpty) {
          resolvedDoctorId = planExpand.first.getStringValue('doctor');
        }
      } catch (_) {}
    }

    if (resolvedDoctorId == null || resolvedDoctorId.isEmpty) {
      final auth = ref.read(authProvider);
      resolvedDoctorId = auth.role == UserRole.doctor ? auth.userId : null;
    }

    Map<String, dynamic>? result;
    if (resolvedDoctorId != null && resolvedDoctorId.isNotEmpty) {
      result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => AvailableSlotsScreen(
            doctorId: resolvedDoctorId!,
            clinicId: widget.clinicId,
            treatmentDuration: widget.treatmentDuration,
            initialDate: initialDate,
            minDate: minDate,
          ),
        ),
      );
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: minDate,
        lastDate: DateTime.now().add(const Duration(days: 730)),
        helpText: 'Select Date for Session ${targetSlot.sessionNumber}',
        builder: (ctx, child) {
          return Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(
                primary: context.colors.primary,
                onPrimary: Colors.white,
                surface: context.colors.surface,
                onSurface: context.colors.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        result = {'date': picked, 'time': targetSlot.newTime};
      }
    }

    if (result == null || !mounted) return;

    final pickedDate = result['date'] as DateTime;
    final pickedTime = (result['time'] as String?) ?? targetSlot.newTime;
    final pickedStr = _formatDateStr(pickedDate);
    final currentSlots = List<ProposedSlot>.from(_currentPreview.proposal.slots);

    // Update target slot with selected date AND slot time
    currentSlots[index] = currentSlots[index].copyWith(
      newDate: pickedStr,
      newTime: pickedTime,
      wasPinned: true,
    );

    // Check if downstream cascade is needed: if picked date is >= subsequent session date
    bool needsCascade = false;
    if (index < currentSlots.length - 1) {
      final nextDt = _parseDate(currentSlots[index + 1].newDate);
      if (!pickedDate.isBefore(nextDt)) {
        needsCascade = true;
      }
    }

    if (needsCascade) {
      var prevDt = pickedDate;
      for (int k = index + 1; k < currentSlots.length; k++) {
        if (currentSlots[k].wasPinned && !currentSlots[k].isTarget) {
          final pinnedDt = _parseDate(currentSlots[k].newDate);
          if (pinnedDt.isAfter(prevDt)) {
            prevDt = pinnedDt;
            continue;
          }
        }
        final cascadedDt = _addDaysSkippingSundays(prevDt, _intervalDays);
        currentSlots[k] = currentSlots[k].copyWith(
          newDate: _formatDateStr(cascadedDt),
          newTime: _applyTimeToAll && widget.newTime != null
              ? widget.newTime!
              : currentSlots[k].newTime,
        );
        prevDt = cascadedDt;
      }
    }

    final updatedProposal = _currentPreview.proposal.copyWith(
      slots: currentSlots,
      updatedIntervalDays: _intervalDays,
    );

    setState(() {
      _currentPreview = ReschedulePreview(
        updatedProposal,
        const ValidationResult.ok(),
      );
    });
  }

  Widget _buildPresetChip({required int days, required String label}) {
    final isSelected = _intervalDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateInterval(days),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? context.colors.primary : context.colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? context.colors.primary : context.colors.border,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proposal = _currentPreview.proposal;
    final validation = _currentPreview.validation;
    final slots = proposal.slots;
    final isDesktop = widget.isDialogMode || MediaQuery.of(context).size.width >= 700;

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

    final noSlotCount = proposal.totalExpected - slots.where((s) => !s.wasPinned).length;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: isDesktop
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: isDesktop ? 20 : 12,
        left: 20,
        right: 20,
        bottom: isDesktop ? 20 : MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle (Mobile only)
          if (!isDesktop)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event_repeat_rounded, color: context.colors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift Upcoming Sessions',
                      style: context.textStyles.h3.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Review auto-adjusted dates or change interval',
                      style: context.textStyles.caption.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: widget.onCancel,
                icon: Icon(Icons.close_rounded, color: context.colors.textSecondary, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Live Treatment Interval Card ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border.withValues(alpha: 0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.repeat_rounded, size: 16, color: context.colors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Treatment Interval',
                          style: context.textStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    // Stepper control
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            padding: const EdgeInsets.all(3),
                            constraints: const BoxConstraints(),
                            onPressed: _intervalDays > 1 ? () => _updateInterval(_intervalDays - 1) : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_intervalDays ${_intervalDays == 1 ? 'day' : 'days'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: context.colors.primary,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            padding: const EdgeInsets.all(3),
                            constraints: const BoxConstraints(),
                            onPressed: _intervalDays < 30 ? () => _updateInterval(_intervalDays + 1) : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Preset choice chips
                Row(
                  children: [
                    _buildPresetChip(days: 1, label: 'Daily'),
                    const SizedBox(width: 6),
                    _buildPresetChip(days: 2, label: '2 Days'),
                    const SizedBox(width: 6),
                    _buildPresetChip(days: 3, label: '3 Days'),
                    const SizedBox(width: 6),
                    _buildPresetChip(days: 7, label: 'Weekly'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (!validation.isValid)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: context.colors.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      validation.failureReason ?? 'Scheduling conflict detected.',
                      style: context.textStyles.bodyMedium.copyWith(color: context.colors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          if (_isProcessing || widget.isRegenerating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: slots.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  final isMoved = slot.oldDate != slot.newDate || slot.oldTime != slot.newTime;
                  final isSkipped = slot.wasPinned && !slot.isTarget;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: slot.isTarget
                          ? context.colors.primary.withValues(alpha: 0.04)
                          : context.colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: slot.isTarget
                            ? context.colors.primary.withValues(alpha: 0.5)
                            : context.colors.border.withValues(alpha: 0.8),
                        width: slot.isTarget ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Session number circle
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isSkipped
                                ? context.colors.divider
                                : (slot.isTarget
                                    ? context.colors.primary
                                    : (isMoved
                                        ? context.colors.primary.withValues(alpha: 0.12)
                                        : context.colors.success.withValues(alpha: 0.12))),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${slot.sessionNumber}',
                            style: TextStyle(
                              color: isSkipped
                                  ? context.colors.textSecondary
                                  : (slot.isTarget
                                      ? Colors.white
                                      : (isMoved
                                          ? context.colors.primary
                                          : context.colors.success)),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Date, Time and Subtitle Line (Original Date + New Date Badge)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 5,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    _formatDisplayDate(slot.newDate),
                                    style: context.textStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      decoration: isSkipped ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (slot.newTime.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: context.colors.primary.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _formatDisplayTime(slot.newTime),
                                        style: TextStyle(
                                          color: context.colors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2.5),
                              Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (isMoved && !isSkipped)
                                    Text(
                                      'Original: ${_formatDisplayDate(slot.oldDate)}',
                                      style: context.textStyles.caption.copyWith(
                                        color: context.colors.textHint,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  if (slot.isTarget)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: context.colors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: context.colors.primary.withValues(alpha: 0.25),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'New Date',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: context.colors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Visually pleasing Change Pill Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _onPickSessionDate(index),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                              decoration: BoxDecoration(
                                color: context.colors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: context.colors.primary.withValues(alpha: 0.28),
                                  width: 1.1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_calendar_rounded,
                                    size: 13.5,
                                    color: context.colors.primary,
                                  ),
                                  const SizedBox(width: 4.5),
                                  Text(
                                    'Change',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.primary,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 12),

          // Summary Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_mode_rounded, size: 14, color: context.colors.primary),
                const SizedBox(width: 6),
                Text(
                  '$moved ${moved == 1 ? 'session' : 'sessions'} shifted',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: context.colors.primary,
                  ),
                ),
                if (unchanged > 0) ...[
                  Text('  ·  ', style: TextStyle(color: context.colors.textHint, fontSize: 11)),
                  Text(
                    '$unchanged unchanged',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                if (skipped > 0) ...[
                  Text('  ·  ', style: TextStyle(color: context.colors.textHint, fontSize: 11)),
                  Text(
                    '$skipped pinned',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                if (noSlotCount > 0 && noSlotCount < 100) ...[
                  Text('  ·  ', style: TextStyle(color: context.colors.textHint, fontSize: 11)),
                  Text(
                    '$noSlotCount no slot',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
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
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: validation.isValid && !_isProcessing
                      ? () {
                          HapticFeedback.lightImpact();
                          widget.onConfirm(_currentPreview);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Confirm Schedule',
                    style: context.textStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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

  String _formatDisplayDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEE, d MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDisplayTime(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
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
