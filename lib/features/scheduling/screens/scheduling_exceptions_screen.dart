import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/scheduling/slot_finder.dart';
import 'package:pms_app/core/utils/error_formatter.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/providers/session_lifecycle_provider.dart';
import 'package:pms_app/core/scheduling/treatment_scheduler.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';

/// Represents an affected booking conflict when a date is marked as time-off.
class AffectedBookingConflict {
  final String id;
  final String type; // 'session' or 'appointment'
  final String patientName;
  final String details; // e.g. "Session 3 of 10" or "Consultation (Walk-in)"
  final String currentDate;
  final String currentTime;
  final String proposedDate;
  final String proposedTime;
  final String? planId;
  final String? doctorId;

  const AffectedBookingConflict({
    required this.id,
    required this.type,
    required this.patientName,
    required this.details,
    required this.currentDate,
    required this.currentTime,
    required this.proposedDate,
    required this.proposedTime,
    this.planId,
    this.doctorId,
  });
}

/// Time Off & Clinic Holidays Screen
///
/// Allows doctors and clinic admins to view, add, and remove time-off
/// (doctor leave days and clinic-wide holiday closures). When adding a blocked date,
/// it instantly scans for existing bookings, generates a preview of next-available slots,
/// and offers 1-click automatic rescheduling.
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
  List<Map<String, String>> _doctors = [];
  Map<String, String> _doctorNames = {};

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

      // Load active doctors in the clinic for doctor selection
      if (clinicId.isNotEmpty) {
        try {
          final docRes = await pb.collection(PBCollections.doctors).getFullList(
                filter: 'clinic = "$clinicId"',
                sort: 'name',
              );
          _doctors = docRes
              .map((d) => {
                    'id': d.id,
                    'name': d.getStringValue('name').isNotEmpty
                        ? d.getStringValue('name')
                        : 'Doctor (${d.id.substring(0, 5)})',
                  })
              .toList();
          _doctorNames = {
            for (final d in _doctors) d['id']!: d['name']!,
          };
        } catch (_) {}
      }

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
        _error = 'Failed to load time off records: $e';
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
        label: const Text('Add Time Off / Holiday'),
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
                Text('Time Off & Clinic Holidays', style: context.textStyles.h2),
                Text(
                  'Manage doctor leave days and clinic closure dates',
                  style: context.textStyles.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
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
              Text(ErrorFormatter.format(_error!),
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
              Text('No time-off or holidays scheduled.',
                  style: context.textStyles.bodyMedium
                      .copyWith(color: context.colors.textSecondary)),
              const SizedBox(height: 8),
              Text(
                'Add doctor leave days or clinic holidays to prevent appointments and therapy sessions from being booked on those dates.',
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
    final type = ex['type'] as String? ?? 'leave';
    final reason = ex['reason'] as String? ?? '';
    final doctorId = ex['doctor'] as String? ?? '';

    DateTime? dt;
    try {
      dt = DateTime.parse(dateStr);
    } catch (_) {}

    final isHoliday = type == 'holiday' || doctorId.isEmpty;
    final color = isHoliday ? context.colors.warning : context.colors.primary;
    final icon = isHoliday ? Icons.event_busy_rounded : Icons.person_off_rounded;
    
    final docName = doctorId.isNotEmpty ? (_doctorNames[doctorId] ?? 'Doctor') : '';
    final label = isHoliday
        ? 'Clinic Holiday (All Doctors)'
        : (docName.isNotEmpty ? 'Leave · $docName' : 'Doctor Leave');

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
              width: 38,
              height: 38,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: context.textStyles.caption.copyWith(
                            color: color,
                            fontSize: 10.5,
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
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: context.textStyles.caption.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: context.colors.textHint),
              onPressed: () async {
                final ok = await _confirmDelete(id);
                if (ok && mounted) {
                  setState(() => _exceptions.removeWhere((e) => e['id'] == id));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Blocked Date'),
        content: const Text('Are you sure you want to remove this time-off date? Bookings will be allowed on this day again.'),
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
        if (mounted) AppToast.show('Time off removed', type: ToastType.success);
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
    final isDoctor = auth.role == UserRole.doctor;
    final loggedInDoctorId = auth.doctor?.id;
    final pb = ref.read(pocketbaseProvider);

    DateTime? selectedDate;
    String exType = isDoctor ? 'leave' : 'leave';
    String? selectedDoctorId = isDoctor
        ? loggedInDoctorId
        : (_doctors.isNotEmpty ? _doctors.first['id'] : null);
    final reasonCtrl = TextEditingController();
    bool isCheckingConflicts = false;
    List<AffectedBookingConflict> detectedConflicts = [];
    bool shiftAllFuture = true;

    // Helper to calculate conflicts & reschedule previews
    Future<void> scanConflicts(DateTime date, String type, String? docId, StateSetter setS) async {
      setS(() {
        isCheckingConflicts = true;
        detectedConflicts = [];
      });

      try {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final conflictsList = <AffectedBookingConflict>[];

        // 1. Fetch Appointments first so we can resolve times & avoid duplicates
        String apptFilter =
            "date = '$dateStr' && status != 'completed' && status != 'cancelled'";
        if (clinicId.isNotEmpty) apptFilter += " && clinic = '$clinicId'";
        if (type == 'leave' && docId != null && docId.isNotEmpty) {
          apptFilter += " && doctor = '$docId'";
        }

        final apptRecs = await pb.collection(PBCollections.appointments).getFullList(
              filter: apptFilter,
              expand: 'patient,doctor',
            );

        // 2. Fetch Sessions
        String sessionFilter =
            "(scheduled_date ~ '$dateStr' || scheduled_date = '$dateStr') && status != 'completed' && status != 'cancelled' && is_deleted != true";
        if (type == 'leave' && docId != null && docId.isNotEmpty) {
          sessionFilter += " && doctor = '$docId'";
        }

        final sessionRecs = await pb.collection(PBCollections.sessions).getFullList(
              filter: sessionFilter,
              expand: 'patient,treatment_plan,doctor',
            );

        final slotFinder = SlotFinder(pb);
        final contextLoader = SchedulingContextLoader(pb);
        final handledApptIds = <String>{};
        final handledPatientIds = <String>{};

        for (final s in sessionRecs) {
          final patientId = s.getStringValue('patient');
          if (patientId.isNotEmpty) handledPatientIds.add(patientId);

          final pName = s.getStringValue('expand.patient.full_name').isNotEmpty
              ? s.getStringValue('expand.patient.full_name')
              : (s.getStringValue('expand.patient.name').isNotEmpty
                  ? s.getStringValue('expand.patient.name')
                  : 'Patient');
          final sNum = s.getIntValue('session_number');
          var sTime = s.getStringValue('scheduled_time');
          final planId = s.getStringValue('treatment_plan');
          final sDocId = s.getStringValue('doctor');

          // Find if there is a matching appointment in apptRecs
          final matchingAppt = apptRecs.where((a) {
            final lId = a.getStringValue('linked_session_id');
            if (lId == s.id) return true;
            if (patientId.isNotEmpty && a.getStringValue('patient') == patientId) return true;
            return false;
          }).firstOrNull;

          if (matchingAppt != null) {
            handledApptIds.add(matchingAppt.id);
            if (sTime.isEmpty) {
              sTime = matchingAppt.getStringValue('time');
            }
          }

          if (sTime.isEmpty) sTime = '10:00 AM';

          String proposedDate = 'Next working day';
          String proposedTime = sTime;

          // Try to compute exact next slot via SlotFinder
          if (planId.isNotEmpty) {
            try {
              final ctx = await contextLoader.load(planId);
              final customBlocked = Set<String>.from(ctx.blockedDates)..add(dateStr);
              final customCtx = SchedulingContext(
                planId: ctx.planId,
                doctorId: ctx.doctorId,
                clinicId: ctx.clinicId,
                workingDays: ctx.workingDays,
                maxBeds: ctx.maxBeds,
                blockedDates: customBlocked,
                daySchedules: ctx.daySchedules,
              );
              final nextSlot = await slotFinder.findBestSlot(
                context: customCtx,
                startDate: date.add(const Duration(days: 1)),
                preferredTime: sTime,
              );
              proposedDate = DateFormat('EEE, MMM d').format(nextSlot.date.toLocal());
              proposedTime = nextSlot.time;
            } catch (_) {}
          }

          conflictsList.add(AffectedBookingConflict(
            id: s.id,
            type: 'session',
            patientName: pName,
            details: 'Session $sNum',
            currentDate: dateStr,
            currentTime: sTime,
            proposedDate: proposedDate,
            proposedTime: proposedTime,
            planId: planId,
            doctorId: sDocId,
          ));
        }

        // 3. Process standalone Consultations / Walk-ins only (skip session mirrors)
        for (final a in apptRecs) {
          if (handledApptIds.contains(a.id)) continue;
          if (a.getStringValue('type') == 'session') continue;
          final pId = a.getStringValue('patient');
          if (pId.isNotEmpty && handledPatientIds.contains(pId)) continue;

          final pName = a.getStringValue('patient_name').isNotEmpty
              ? a.getStringValue('patient_name')
              : (a.getStringValue('expand.patient.full_name').isNotEmpty
                  ? a.getStringValue('expand.patient.full_name')
                  : 'Patient');
          final aTime = a.getStringValue('time').isNotEmpty ? a.getStringValue('time') : '10:00 AM';
          final aType = a.getStringValue('type');
          final aDocId = a.getStringValue('doctor');

          final nextDt = date.add(const Duration(days: 1));
          final proposedDate = DateFormat('EEE, MMM d').format(nextDt);

          conflictsList.add(AffectedBookingConflict(
            id: a.id,
            type: 'appointment',
            patientName: pName,
            details: aType == 'walk_in' ? 'Walk-In' : 'Consultation',
            currentDate: dateStr,
            currentTime: aTime,
            proposedDate: proposedDate,
            proposedTime: aTime,
            doctorId: aDocId,
          ));
        }

        setS(() {
          detectedConflicts = conflictsList;
          isCheckingConflicts = false;
        });
      } catch (e) {
        setS(() {
          isCheckingConflicts = false;
        });
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
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
            if (d != null) {
              setS(() => selectedDate = d);
              scanConflicts(d, exType, selectedDoctorId, setS);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: colors.surface,
            title: Row(
              children: [
                Icon(Icons.event_busy_rounded, color: colors.primary, size: 22),
                const SizedBox(width: 10),
                Text('Add Time Off / Holiday', style: textStyles.h3),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type toggle: Doctor Leave vs Clinic Holiday
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setS(() => exType = 'leave');
                              if (selectedDate != null) {
                                scanConflicts(selectedDate!, 'leave', selectedDoctorId, setS);
                              }
                            },
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
                            onTap: () {
                              setS(() => exType = 'holiday');
                              if (selectedDate != null) {
                                scanConflicts(selectedDate!, 'holiday', null, setS);
                              }
                            },
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

                    // Doctor Selector (If Clinic Admin & Type is Leave)
                    if (exType == 'leave') ...[
                      if (!isDoctor && _doctors.isNotEmpty) ...[
                        Text('Select Doctor',
                            style: textStyles.caption.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedDoctorId,
                              isExpanded: true,
                              icon: Icon(Icons.keyboard_arrow_down_rounded,
                                  color: colors.textSecondary),
                              items: _doctors.map((d) {
                                return DropdownMenuItem<String>(
                                  value: d['id'],
                                  child: Text(d['name']!, style: textStyles.bodyMedium),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setS(() => selectedDoctorId = val);
                                  if (selectedDate != null) {
                                    scanConflicts(selectedDate!, exType, val, setS);
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if (isDoctor) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_rounded, size: 16, color: colors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Doctor: ${auth.doctor?.name ?? 'Me'}',
                                style: textStyles.caption.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],

                    // Date picker
                    Text('Select Date',
                        style: textStyles.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 6),
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
                                    : 'Tap to choose date...',
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
                    const SizedBox(height: 14),

                    // ── Inline Conflict Preview Section ──
                    if (isCheckingConflicts) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('Checking existing bookings on this date...',
                                style: textStyles.caption),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else if (selectedDate != null && detectedConflicts.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No existing bookings on this date. You are all clear to block!',
                                style: textStyles.caption.copyWith(
                                  color: const Color(0xFF059669),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else if (selectedDate != null && detectedConflicts.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFD97706), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${detectedConflicts.length} booking(s) will be affected:',
                                    style: textStyles.caption.copyWith(
                                      color: const Color(0xFFD97706),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...detectedConflicts.map((c) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: colors.border.withValues(alpha: 0.6)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.patientName,
                                          style: textStyles.label.copyWith(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: colors.primary
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            c.details,
                                            style: textStyles.caption.copyWith(
                                              color: colors.primary,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '${c.currentDate} (${c.currentTime})',
                                          style: textStyles.caption.copyWith(
                                            color: colors.textMuted,
                                            fontSize: 11,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 12,
                                            color: Color(0xFF10B981)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${c.proposedDate} (${c.proposedTime})',
                                          style: textStyles.caption.copyWith(
                                            color: const Color(0xFF059669),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),

                            // Shift mode selector (No "cascade" jargon)
                            Text(
                              'Future Sessions Handling',
                              style: textStyles.caption.copyWith(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => setS(() => shiftAllFuture = true),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: shiftAllFuture
                                      ? colors.primary.withValues(alpha: 0.08)
                                      : colors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: shiftAllFuture ? colors.primary : colors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      shiftAllFuture
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      size: 18,
                                      color: shiftAllFuture ? colors.primary : colors.textHint,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Shift All Future Sessions (Recommended)',
                                            style: textStyles.label.copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: shiftAllFuture ? colors.primary : colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Moves affected session and automatically pushes subsequent sessions forward to keep the regular gap.',
                                            style: textStyles.caption.copyWith(
                                              fontSize: 10.5,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => setS(() => shiftAllFuture = false),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: !shiftAllFuture
                                      ? colors.primary.withValues(alpha: 0.08)
                                      : colors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: !shiftAllFuture ? colors.primary : colors.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      !shiftAllFuture
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      size: 18,
                                      color: !shiftAllFuture ? colors.primary : colors.textHint,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Shift Affected Session Only',
                                            style: textStyles.label.copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: !shiftAllFuture ? colors.primary : colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Moves only this session. Subsequent sessions are pushed only if there is a direct date collision.',
                                            style: textStyles.caption.copyWith(
                                              fontSize: 10.5,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Reason field
                    Text('Reason (Optional)',
                        style: textStyles.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        hintText: exType == 'leave'
                            ? 'e.g. Personal Leave, Medical Conference'
                            : 'e.g. Diwali Holiday, Clinic Renovation',
                        hintStyle: textStyles.bodyMedium
                            .copyWith(color: colors.textHint, fontSize: 13),
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
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: TextStyle(color: colors.textSecondary)),
              ),
              if (detectedConflicts.isNotEmpty) ...[
                OutlinedButton(
                  onPressed: () async {
                    if (selectedDate == null) return;
                    Navigator.pop(ctx);
                    await _saveExceptionOnly(
                      clinicId: clinicId,
                      date: selectedDate!,
                      exType: exType,
                      docId: selectedDoctorId,
                      reason: reasonCtrl.text.trim(),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Block Date Only'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDate == null) return;
                    Navigator.pop(ctx);
                    await _saveExceptionAndRescheduleConflicts(
                      clinicId: clinicId,
                      date: selectedDate!,
                      exType: exType,
                      docId: selectedDoctorId,
                      reason: reasonCtrl.text.trim(),
                      conflicts: detectedConflicts,
                      shiftAllFuture: shiftAllFuture,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Reschedule All (${detectedConflicts.length}) & Block'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDate == null) {
                      AppToast.show('Please select a date',
                          type: ToastType.warning);
                      return;
                    }
                    if (exType == 'leave' &&
                        (selectedDoctorId == null ||
                            selectedDoctorId!.isEmpty)) {
                      AppToast.show('Please select a doctor',
                          type: ToastType.warning);
                      return;
                    }

                    Navigator.pop(ctx);
                    await _saveExceptionOnly(
                      clinicId: clinicId,
                      date: selectedDate!,
                      exType: exType,
                      docId: selectedDoctorId,
                      reason: reasonCtrl.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Block Date & Save'),
                ),
              ],
            ],
          );
        },
      ),
    );

    reasonCtrl.dispose();
  }

  Future<void> _saveExceptionOnly({
    required String clinicId,
    required DateTime date,
    required String exType,
    required String? docId,
    required String reason,
  }) async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final docToSave = exType == 'leave' ? docId : '';

      await pb.collection(PBCollections.schedulingExceptions).create(body: {
        'clinic': clinicId,
        if (docToSave != null && docToSave.isNotEmpty) 'doctor': docToSave,
        'date': dateStr,
        'type': exType,
        if (reason.isNotEmpty) 'reason': reason,
      });
      _load();
      if (mounted) {
        AppToast.show('Time off scheduled ✓', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) AppToast.show('Failed: $e', type: ToastType.error);
    }
  }

  Future<void> _saveExceptionAndRescheduleConflicts({
    required String clinicId,
    required DateTime date,
    required String exType,
    required String? docId,
    required String reason,
    required List<AffectedBookingConflict> conflicts,
    required bool shiftAllFuture,
  }) async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final docToSave = exType == 'leave' ? docId : '';
      final scheduler = ref.read(sessionLifecycleServiceProvider).scheduler;

      // 1. Create the Exception in DB first so subsequent searches know it's blocked
      await pb.collection(PBCollections.schedulingExceptions).create(body: {
        'clinic': clinicId,
        if (docToSave != null && docToSave.isNotEmpty) 'doctor': docToSave,
        'date': dateStr,
        'type': exType,
        if (reason.isNotEmpty) 'reason': reason,
      });

      // 2. Reschedule each affected session / appointment
      int rescheduledCount = 0;
      for (final conflict in conflicts) {
        if (conflict.type == 'session') {
          // Parse proposed date to standard YYYY-MM-DD
          String finalDate = conflict.proposedDate;
          final parsed = DateFormat('EEE, MMM d').tryParse(conflict.proposedDate);
          if (parsed != null) {
            final targetYear = date.year;
            final fullDt = DateTime(targetYear, parsed.month, parsed.day);
            finalDate = DateFormat('yyyy-MM-dd').format(fullDt);
          }

          // Use the scheduler with mode based on user selection
          await scheduler.rescheduleSession(
            conflict.id,
            newDate: finalDate,
            newTime: conflict.proposedTime,
            mode: shiftAllFuture ? RescheduleMode.cascadeAll : RescheduleMode.missedOnly,
            trigger: 'user_leave_creation',
            performedBy: docToSave ?? 'clinic_admin',
          );

          if (!shiftAllFuture && conflict.planId != null && conflict.planId!.isNotEmpty) {
            // Self-heal and resolve any collision on the plan
            await scheduler.realignPlanSequence(
              conflict.planId!,
              performedBy: docToSave ?? 'clinic_admin',
            );
          }

          rescheduledCount++;
        } else if (conflict.type == 'appointment') {
          final nextDt = date.add(const Duration(days: 1));
          final nextDateStr = DateFormat('yyyy-MM-dd').format(nextDt);
          await pb.collection(PBCollections.appointments).update(conflict.id, body: {
            'date': nextDateStr,
            'time': conflict.proposedTime,
          });
          rescheduledCount++;
        }
      }

      _load();
      if (mounted) {
        AppToast.show(
          'Time off saved & $rescheduledCount booking(s) rescheduled ✓',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) AppToast.show('Failed: $e', type: ToastType.error);
    }
  }
}
