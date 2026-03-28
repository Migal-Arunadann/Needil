import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/appointment_model.dart';
import '../providers/appointment_provider.dart';
import '../../../core/utils/time_utils.dart';
import '../../patients/models/patient_model.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../scheduling/screens/available_slots_screen.dart';
import 'patient_info_screen.dart';

class AppointmentListScreen extends ConsumerStatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  ConsumerState<AppointmentListScreen> createState() =>
      _AppointmentListScreenState();
}

class _AppointmentListScreenState
    extends ConsumerState<AppointmentListScreen> with TickerProviderStateMixin {
  late DateTime _selectedDate;
  final _dateScrollCtrl = ScrollController();
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  void _generateDates() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final lastDay = DateTime(year, month + 1, 0).day;
    _dates = List.generate(lastDay, (i) => DateTime(year, month, i + 1));
  }

  void _scrollToSelectedDate() {
    if (!_dateScrollCtrl.hasClients) return;
    final offset = ((_selectedDate.day - 2) * 76.0);
    _dateScrollCtrl.animateTo(
      offset.clamp(0.0, _dateScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _dateScrollCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _generateDates();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
      ref.read(appointmentListProvider.notifier).changeDate(_formatDate(picked));
    }
  }

  bool _isLate(AppointmentModel apt) {
    if (apt.status != AppointmentStatus.scheduled) return false;
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    if (apt.date != todayStr) return false;
    final parts = apt.time.split(':');
    if (parts.length != 2) return false;
    final aptTime = DateTime(now.year, now.month, now.day,
        int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
    return now.isAfter(aptTime);
  }

  bool _isMissed(AppointmentModel apt) {
    if (apt.status != AppointmentStatus.scheduled) return false;
    final now = DateTime.now();
    final todayStr = _formatDate(now);
    // If the appointment date is before today, it's missed
    return apt.date.compareTo(todayStr) < 0;
  }

  bool _isFutureDate(AppointmentModel apt) {
    final todayStr = _formatDate(DateTime.now());
    return apt.date.compareTo(todayStr) > 0;
  }

  Future<void> _markArrived(AppointmentModel apt) async {
    try {
      final service = ref.read(appointmentServiceProvider);
      await service.markArrived(apt.id);
      ref.read(appointmentListProvider.notifier).loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${apt.displayName} marked as arrived ✓'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _markEnded(AppointmentModel apt) async {
    try {
      final service = ref.read(appointmentServiceProvider);
      await service.markEnded(apt.id);
      ref.read(appointmentListProvider.notifier).loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${apt.displayName} appointment ended ✓'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _cancelAppointment(AppointmentModel apt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Appointment?', style: TextStyle(color: AppColors.error)),
        content: Text('Cancel appointment for ${apt.displayName} at ${TimeUtils.formatStringTime(apt.time)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(appointmentListProvider.notifier).updateStatus(apt.id, AppointmentStatus.cancelled);
    }
  }

  Future<void> _undoArrived(AppointmentModel apt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.undo_rounded, color: AppColors.warning, size: 22),
            const SizedBox(width: 10),
            const Text('Undo Arrival?'),
          ],
        ),
        content: Text('Revert ${apt.displayName}\'s arrived status back to scheduled?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Undo'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final service = ref.read(appointmentServiceProvider);
        await service.undoArrived(apt.id);
        ref.read(appointmentListProvider.notifier).loadAppointments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${apt.displayName} arrival reverted ✓'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _rescheduleAppointment(AppointmentModel apt) async {
    final doctorId = apt.doctorId;
    final clinicId = apt.clinicId;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableSlotsScreen(
          doctorId: doctorId,
          clinicId: (clinicId != null && clinicId.isNotEmpty) ? clinicId : null,
          treatmentDuration: 30,
        ),
      ),
    );

    if (result != null && mounted) {
      final dateObj = result['date'] as DateTime;
      final newDate = DateFormat('yyyy-MM-dd').format(dateObj);
      final newTime = result['time'] as String;
      try {
        final service = ref.read(appointmentServiceProvider);
        await service.rescheduleAppointment(apt.id, newDate, newTime);
        ref.read(appointmentListProvider.notifier).loadAppointments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${apt.displayName} rescheduled to $newDate at ${TimeUtils.formatStringTime(newTime)} ✓'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _navigateToPatient(AppointmentModel apt) async {
    if (apt.patientId == null || apt.patientId!.isEmpty) {
      // Silently ignore — card is just informational until patient is linked
      return;
    }
    try {
      final pb = ref.read(pocketbaseProvider);
      final record = await pb.collection(PBCollections.patients).getOne(apt.patientId!);
      final patient = PatientModel.fromRecord(record);
      if (mounted) {
        Navigator.pushNamed(context, '/patient-profile', arguments: patient);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load patient: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentListProvider);
    final all = state.appointments;

    // Split into consultations (call_by + walk_in) and sessions
    final consultations = all.where((a) => a.type != AppointmentType.session).toList();
    final sessions = all.where((a) => a.type == AppointmentType.session).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule', style: AppTextStyles.h1),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedDate),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, size: 20, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Horizontal Date Strip ──
            SizedBox(
              height: 84,
              child: ListView.builder(
                controller: _dateScrollCtrl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _dates.length,
                itemBuilder: (context, index) {
                  final d = _dates[index];
                  final isSelected = d.day == _selectedDate.day &&
                      d.month == _selectedDate.month &&
                      d.year == _selectedDate.year;
                  final now = DateTime.now();
                  final isToday = d.day == now.day && d.month == now.month && d.year == now.year;
                  String dayLabel = DateFormat('E').format(d);
                  if (isToday) dayLabel = 'Today';

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = d);
                      ref.read(appointmentListProvider.notifier).changeDate(_formatDate(d));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(dayLabel, style: AppTextStyles.caption.copyWith(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          )),
                          const SizedBox(height: 6),
                          Text(d.day.toString(), style: AppTextStyles.h2.copyWith(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            height: 1,
                          )),
                          const SizedBox(height: 6),
                          Container(
                            width: 4, height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : isToday ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(color: AppColors.border, height: 1),
            ),
            const SizedBox(height: 8),

            // ── Main Content ──
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3))
                  : state.error != null
                      ? _errorView(state.error!)
                      : (consultations.isEmpty && sessions.isEmpty)
                          ? _emptyView()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () => ref.read(appointmentListProvider.notifier).loadAppointments(),
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                                children: [
                                  // ── Consultations Section ──
                                  _sectionHeader('Consultations', Icons.assignment_ind_rounded, consultations.length, AppColors.info),
                                  const SizedBox(height: 12),
                                  if (consultations.isEmpty)
                                    _emptySectionLabel('No consultations scheduled')
                                  else
                                    ...consultations.asMap().entries.map((e) =>
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: _ScheduleCard(
                                          key: ValueKey(e.value.id),
                                          index: e.key,
                                          apt: e.value,
                                          isLate: _isLate(e.value),
                                          isFutureDate: _isFutureDate(e.value),
                                          isMissed: _isMissed(e.value),
                                          onArrived: () => _markArrived(e.value),
                                          onFillDetails: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PatientInfoScreen(appointment: e.value),
                                              ),
                                            ).then((_) => ref.read(appointmentListProvider.notifier).loadAppointments());
                                          },
                                          onEnded: () => _markEnded(e.value),
                                          onReschedule: () => _rescheduleAppointment(e.value),
                                          onUndoArrived: () => _undoArrived(e.value),
                                          onTap: () => _navigateToPatient(e.value),
                                          onLongPress: () => _cancelAppointment(e.value),
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 24),
                                  const Divider(color: AppColors.border),
                                  const SizedBox(height: 16),

                                  // ── Sessions Section ──
                                  _sectionHeader('Treatment Sessions', Icons.healing_rounded, sessions.length, AppColors.primary),
                                  const SizedBox(height: 12),
                                  if (sessions.isEmpty)
                                    _emptySectionLabel('No sessions scheduled')
                                  else
                                    ...sessions.asMap().entries.map((e) =>
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: _ScheduleCard(
                                          key: ValueKey(e.value.id),
                                          index: e.key,
                                          apt: e.value,
                                          isLate: _isLate(e.value),
                                          isFutureDate: _isFutureDate(e.value),
                                          isMissed: _isMissed(e.value),
                                          onArrived: () => _markArrived(e.value),
                                          onFillDetails: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PatientInfoScreen(appointment: e.value),
                                              ),
                                            ).then((_) => ref.read(appointmentListProvider.notifier).loadAppointments());
                                          },
                                          onEnded: () => _markEnded(e.value),
                                          onReschedule: () => _rescheduleAppointment(e.value),
                                          onUndoArrived: () => _undoArrived(e.value),
                                          onTap: () => _navigateToPatient(e.value),
                                          onLongPress: () => _cancelAppointment(e.value),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppTextStyles.h3),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _emptySectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: AppColors.textHint.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No appointments today', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Tap the + button to create one.', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(appointmentListProvider.notifier).loadAppointments(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Schedule Card Widget (Stateful for animations)
// ════════════════════════════════════════════════════════════════════

class _ScheduleCard extends StatefulWidget {
  final AppointmentModel apt;
  final int index;
  final bool isLate;
  final bool isFutureDate;
  final bool isMissed;
  final VoidCallback onArrived;
  final VoidCallback onFillDetails;
  final VoidCallback onEnded;
  final VoidCallback onReschedule;
  final VoidCallback onUndoArrived;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ScheduleCard({
    super.key,
    required this.apt,
    required this.index,
    required this.isLate,
    required this.isFutureDate,
    required this.isMissed,
    required this.onArrived,
    required this.onFillDetails,
    required this.onEnded,
    required this.onReschedule,
    required this.onUndoArrived,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apt = widget.apt;

    // Status styling
    Color statusColor = AppColors.success;
    String statusStr = 'Completed';
    IconData statusIcon = Icons.check_circle_rounded;

    if (widget.isMissed) {
      statusColor = AppColors.error;
      statusStr = 'Missed';
      statusIcon = Icons.event_busy_rounded;
    } else if (apt.status == AppointmentStatus.cancelled) {
      statusColor = AppColors.error;
      statusStr = 'Cancelled';
      statusIcon = Icons.cancel_rounded;
    } else if (apt.status == AppointmentStatus.inProgress) {
      statusColor = AppColors.warning;
      statusStr = 'In Progress';
      statusIcon = Icons.sync_rounded;
    } else if (apt.status == AppointmentStatus.scheduled) {
      statusColor = AppColors.info;
      statusStr = 'Scheduled';
      statusIcon = Icons.access_time_filled;
    }

    // Type styling
    final isCallBy = apt.type == AppointmentType.callBy;
    final isSession = apt.type == AppointmentType.session;
    final isWalkIn = apt.type == AppointmentType.walkIn;

    IconData typeIcon = Icons.person_rounded;
    Color typeColor = AppColors.accent;
    String typeLabel = 'Walk-In';

    if (isCallBy) {
      typeIcon = Icons.phone_rounded;
      typeColor = AppColors.info;
      typeLabel = 'Call-By';
    } else if (isSession) {
      typeIcon = Icons.healing_rounded;
      typeColor = AppColors.primary;
      typeLabel = 'Session';
    }

    // Determine which action buttons to show
    final isScheduled = apt.status == AppointmentStatus.scheduled;
    final isInProgress = apt.status == AppointmentStatus.inProgress;
    final hasPatientLinked = apt.patientId != null && apt.patientId!.isNotEmpty;

    // Today's scheduled cards: show "Patient Arrived" (except walk-ins)
    // Future scheduled cards: show "Reschedule"
    // Missed: no action buttons
    final showArrivedBtn = isScheduled && !isWalkIn && !widget.isFutureDate && !widget.isMissed;
    final showRescheduleBtn = isScheduled && widget.isFutureDate && !widget.isMissed;
    final showFillDetailsBtn = isInProgress && !hasPatientLinked;
    final showEndedBtn = isInProgress && hasPatientLinked;

    final cardOpacity = widget.isMissed ? 0.6 : 1.0;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: () {
            HapticFeedback.mediumImpact();
            widget.onLongPress();
          },
          child: Opacity(
            opacity: cardOpacity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isMissed
                      ? AppColors.error.withValues(alpha: 0.4)
                      : widget.isLate
                          ? AppColors.error.withValues(alpha: 0.5)
                          : AppColors.border,
                  width: (widget.isLate || widget.isMissed) ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isLate ? AppColors.error : Colors.black).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── Top Row: Patient Info ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        // Type Icon
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(typeIcon, color: typeColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        // Name and Type
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                apt.displayName,
                                style: AppTextStyles.h3.copyWith(fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(typeLabel, style: AppTextStyles.labelSmall.copyWith(
                                      color: typeColor, fontWeight: FontWeight.w600, fontSize: 10,
                                    )),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.schedule_rounded, size: 12, color: AppColors.textHint),
                                  const SizedBox(width: 4),
                                  Text(
                                    TimeUtils.formatStringTime(apt.time),
                                    style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 4),
                              Text(statusStr, style: AppTextStyles.labelSmall.copyWith(
                                color: statusColor, fontWeight: FontWeight.w600, fontSize: 10,
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Missed Indicator ──
                  if (widget.isMissed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppColors.error.withValues(alpha: 0.06),
                      child: Row(
                        children: [
                          Icon(Icons.event_busy_rounded, size: 14, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text(
                            'Patient missed this appointment',
                            style: AppTextStyles.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                  // ── Late Indicator ──
                  if (widget.isLate && !widget.isMissed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppColors.error.withValues(alpha: 0.06),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text(
                            'Patient is late — hasn\'t arrived yet',
                            style: AppTextStyles.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                  // ── Check-in info (non-clickable, with undo) ──
                  if (apt.checkInTime != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.login_rounded, size: 12, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(
                            'Arrived at ${DateFormat('h:mm a').format(apt.checkInTime!.toLocal())}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.success, fontSize: 11),
                          ),
                          const Spacer(),
                          // Undo button — only show if still in_progress (not yet ended)
                          if (isInProgress)
                            GestureDetector(
                              onTap: widget.onUndoArrived,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.undo_rounded, size: 11, color: AppColors.warning),
                                    const SizedBox(width: 4),
                                    Text('Undo', style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 10,
                                    )),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // ── Action Buttons ──
                  if (showArrivedBtn || showRescheduleBtn || showFillDetailsBtn || showEndedBtn) ...[
                    const Divider(color: AppColors.border, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          if (showArrivedBtn)
                            Expanded(
                              child: _ActionButton(
                                label: 'Patient Arrived',
                                icon: Icons.how_to_reg_rounded,
                                color: AppColors.success,
                                onTap: widget.onArrived,
                              ),
                            ),
                          if (showRescheduleBtn)
                            Expanded(
                              child: _ActionButton(
                                label: 'Reschedule',
                                icon: Icons.event_repeat_rounded,
                                color: AppColors.info,
                                onTap: widget.onReschedule,
                              ),
                            ),
                          if (showFillDetailsBtn)
                            Expanded(
                              child: _ActionButton(
                                label: 'Fill Details',
                                icon: Icons.badge_rounded,
                                color: AppColors.info,
                                onTap: widget.onFillDetails,
                              ),
                            ),
                          if (showEndedBtn)
                            Expanded(
                              child: _ActionButton(
                                label: 'Appointment Ended',
                                icon: Icons.check_circle_outline_rounded,
                                color: AppColors.success,
                                onTap: widget.onEnded,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
