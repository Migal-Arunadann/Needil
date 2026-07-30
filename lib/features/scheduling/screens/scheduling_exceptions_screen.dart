import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';

/// Screening Exceptions Screen
///
/// Allows doctors and clinic admins to view, add, and remove scheduling
/// exceptions (doctor leave days and clinic holidays). The scheduling engine
/// uses these records when finding the next available slot.
class SchedulingExceptionsScreen extends ConsumerStatefulWidget {
  const SchedulingExceptionsScreen({super.key});

  @override
  ConsumerState<SchedulingExceptionsScreen> createState() =>
      _SchedulingExceptionsScreenState();
}

class _SchedulingExceptionsScreenState
    extends ConsumerState<SchedulingExceptionsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _exceptions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final clinicId = auth.clinicId ?? '';
      final doctorId = auth.doctor?.id;
      final pb = ref.read(pocketbaseProvider);

      String filter = 'clinic = "$clinicId"';
      if (doctorId != null) {
        filter = '(clinic = "$clinicId" && (doctor = "" || doctor = "$doctorId"))';
      }

      final result = await pb
          .collection(PBCollections.schedulingExceptions)
          .getList(
            filter: filter,
            sort: 'date',
            perPage: 200,
          );
      setState(() {
        _exceptions =
            result.items.map((r) => r.data..['id'] = r.id).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load exceptions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Exception'),
        backgroundColor: context.colors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom:
              BorderSide(color: context.colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 20, color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scheduling Exceptions', style: context.textStyles.h2),
                Text(
                  'Leave days & clinic holidays',
                  style: context.textStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: context.colors.textSecondary),
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 3));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: context.colors.error),
              const SizedBox(height: 12),
              Text(_error!,
                  style: context.textStyles.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_exceptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_rounded,
                  size: 56, color: context.colors.textHint),
              const SizedBox(height: 12),
              Text('No scheduling exceptions added.',
                  style: context.textStyles.bodyMedium
                      .copyWith(color: context.colors.textSecondary)),
              const SizedBox(height: 8),
              Text(
                'Add doctor leave days or clinic holidays to prevent sessions from being scheduled on those dates.',
                style: context.textStyles.bodySmall
                    .copyWith(color: context.colors.textHint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group by month
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final ex in _exceptions) {
      final dateStr = ex['date'] as String? ?? '';
      DateTime? dt;
      try {
        dt = DateTime.parse(dateStr);
      } catch (_) {}
      final key = dt != null ? DateFormat('MMMM yyyy').format(dt) : 'Unknown';
      grouped.putIfAbsent(key, () => []).add(ex);
    }

    final keys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: keys.length,
      itemBuilder: (context, sIndex) {
        final month = keys[sIndex];
        final items = grouped[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8, top: sIndex > 0 ? 16 : 0),
              child: Text(
                month,
                style: context.textStyles.label.copyWith(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...items.map((ex) => _exceptionCard(ex)),
          ],
        );
      },
    );
  }

  Widget _exceptionCard(Map<String, dynamic> ex) {
    final id = ex['id'] as String? ?? '';
    final dateStr = ex['date'] as String? ?? '';
    final type = ex['type'] as String? ?? 'leave'; // 'leave' or 'holiday'
    final reason = ex['reason'] as String? ?? '';
    final doctorId = ex['doctor'] as String? ?? '';

    DateTime? dt;
    try {
      dt = DateTime.parse(dateStr);
    } catch (_) {}

    final isHoliday = type == 'holiday' || doctorId.isEmpty;
    final color = isHoliday ? context.colors.warning : context.colors.primary;
    final icon = isHoliday ? Icons.event_busy_rounded : Icons.person_off_rounded;
    final label = isHoliday ? 'Clinic Holiday' : 'Doctor Leave';

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: context.colors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.delete_outline_rounded, color: context.colors.error),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDelete(id);
      },
      onDismissed: (_) => setState(() => _exceptions.removeWhere((e) => e['id'] == id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: context.textStyles.caption.copyWith(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dt != null
                            ? DateFormat('EEE, MMM d, yyyy').format(dt)
                            : dateStr,
                        style: context.textStyles.label.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      reason,
                      style: context.textStyles.caption.copyWith(
                          color: context.colors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _confirmDelete(id).then((confirmed) {
                if (confirmed == true) {
                  setState(() => _exceptions.removeWhere((e) => e['id'] == id));
                }
              }),
              child: Icon(Icons.delete_outline_rounded,
                  size: 20, color: context.colors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.surface,
        title: Text('Remove Exception?', style: context.textStyles.h3),
        content: const Text('This exception will be removed. Future slot-finding will include this date again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final pb = ref.read(pocketbaseProvider);
        await pb.collection(PBCollections.schedulingExceptions).delete(id);
        if (mounted) AppToast.show('Exception removed', type: ToastType.info);
        return true;
      } catch (e) {
        if (mounted) AppToast.show('Failed to remove: $e', type: ToastType.error);
        return false;
      }
    }
    return false;
  }

  Future<void> _showAddDialog() async {
    final auth = ref.read(authProvider);
    final clinicId = auth.clinicId ?? '';
    final doctorId = auth.doctor?.id;

    DateTime? selectedDate;
    String exType = 'leave';
    final reasonCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final colors = ctx.colors;
          final textStyles = ctx.textStyles;

          Future<void> pickDate() async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
            );
            if (d != null) setS(() => selectedDate = d);
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: colors.surface,
            title: Row(
              children: [
                Icon(Icons.event_busy_rounded, color: colors.primary, size: 22),
                const SizedBox(width: 10),
                Text('Add Exception', style: textStyles.h3),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type toggle
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => exType = 'leave'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: exType == 'leave'
                                ? colors.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: exType == 'leave'
                                  ? colors.primary
                                  : colors.border,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.person_off_rounded,
                                  color: exType == 'leave'
                                      ? colors.primary
                                      : colors.textHint),
                              const SizedBox(height: 4),
                              Text('Doctor Leave',
                                  style: textStyles.caption.copyWith(
                                    color: exType == 'leave'
                                        ? colors.primary
                                        : colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => exType = 'holiday'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: exType == 'holiday'
                                ? colors.warning.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: exType == 'holiday'
                                  ? colors.warning
                                  : colors.border,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.event_busy_rounded,
                                  color: exType == 'holiday'
                                      ? colors.warning
                                      : colors.textHint),
                              const SizedBox(height: 4),
                              Text('Clinic Holiday',
                                  style: textStyles.caption.copyWith(
                                    color: exType == 'holiday'
                                        ? colors.warning
                                        : colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Date picker
                GestureDetector(
                  onTap: pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 18, color: colors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedDate != null
                                ? DateFormat('EEE, MMM d, yyyy')
                                    .format(selectedDate!)
                                : 'Select Date',
                            style: textStyles.bodyMedium.copyWith(
                              color: selectedDate != null
                                  ? colors.textPrimary
                                  : colors.textHint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Reason field
                TextField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    hintText: 'Reason (optional)',
                    hintStyle: textStyles.bodyMedium
                        .copyWith(color: colors.textHint),
                    filled: true,
                    fillColor: colors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  style: textStyles.bodyMedium,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: TextStyle(color: colors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedDate == null) {
                    AppToast.show('Please select a date', type: ToastType.warning);
                    return;
                  }
                  Navigator.pop(ctx);

                  try {
                    final pb = ref.read(pocketbaseProvider);
                    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
                    await pb
                        .collection(PBCollections.schedulingExceptions)
                        .create(body: {
                      'clinic': clinicId,
                      if (exType == 'leave' && doctorId != null) 'doctor': doctorId,
                      'date': dateStr,
                      'type': exType,
                      if (reasonCtrl.text.trim().isNotEmpty) 'reason': reasonCtrl.text.trim(),
                    });
                    _load();
                    if (mounted) AppToast.show('Exception added ✓', type: ToastType.success);
                  } catch (e) {
                    if (mounted) AppToast.show('Failed: $e', type: ToastType.error);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add Exception'),
              ),
            ],
          );
        },
      ),
    );

    reasonCtrl.dispose();
  }
}
