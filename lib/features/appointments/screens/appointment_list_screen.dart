import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/appointment_model.dart';
import '../providers/appointment_provider.dart';
import '../../../core/utils/time_utils.dart';
import 'patient_info_screen.dart';

class AppointmentListScreen extends ConsumerStatefulWidget {
  const AppointmentListScreen({super.key});

  @override
  ConsumerState<AppointmentListScreen> createState() =>
      _AppointmentListScreenState();
}

class _AppointmentListScreenState
    extends ConsumerState<AppointmentListScreen> {
  late DateTime _selectedDate;
  String _searchQuery = '';
  // Built-in fixed filters replacing the modal Enum mapping
  final List<String> _filters = ['All', 'Scheduled', 'Done', 'Missed'];
  String _activeFilter = 'All';

  final _dateScrollCtrl = ScrollController();

  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _generateDates();

    // Initial scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });
  }

  void _generateDates() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final lastDay = DateTime(year, month + 1, 0).day;
    _dates = List.generate(
      lastDay,
      (index) => DateTime(year, month, index + 1),
    );
  }

  void _scrollToSelectedDate() {
    if (!_dateScrollCtrl.hasClients) return;
    // We want yesterday (index = selectedDate.day - 2) to be at the left edge.
    // Since day is 1-indexed, today's index is day - 1. Yesterday's index is day - 2.
    // Each item is 64 wide + 12 margin = 76 width
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
          colorScheme: ColorScheme.light(
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedDate();
      });
      ref.read(appointmentListProvider.notifier).changeDate(_formatDate(picked));
    }
  }

  List<AppointmentModel> _filtered(List<AppointmentModel> all) {
    var list = all;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) => a.displayName.toLowerCase().contains(q)).toList();
    }
    if (_activeFilter != 'All') {
      if (_activeFilter == 'Scheduled') {
        list = list.where((a) => a.status == AppointmentStatus.scheduled).toList();
      } else if (_activeFilter == 'Done') {
        list = list.where((a) => a.status == AppointmentStatus.completed).toList();
      } else if (_activeFilter == 'Missed') {
        // Mapping cancelled / inProgress to missed/done logic depending on user flow.
        list = list.where((a) => a.status == AppointmentStatus.cancelled).toList();
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentListProvider);
    final filtered = _filtered(state.appointments);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header (Title & Calendar Icon) ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appointments', style: AppTextStyles.h1),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Horizontal Date Strip ────────────────────────────────
            SizedBox(
              height: 84, // Approximate height for dates
              child: ListView.builder(
                controller: _dateScrollCtrl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _dates.length,
                itemBuilder: (context, index) {
                  final d = _dates[index];
                  final isSelected = d.year == _selectedDate.year &&
                      d.month == _selectedDate.month &&
                      d.day == _selectedDate.day;

                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final yesterday = today.subtract(const Duration(days: 1));
                  final dDate = DateTime(d.year, d.month, d.day);

                  final isToday = dDate == today;
                  final isYesterday = dDate == yesterday;

                  String dayLabel = DateFormat('E').format(d);
                  if (isToday) dayLabel = 'Today';
                  if (isYesterday) dayLabel = 'Yest';

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
                          Text(
                            dayLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            d.day.toString(),
                            style: AppTextStyles.h2.copyWith(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Small dot indicator for active selected item
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white.withValues(alpha: 0.5) : AppColors.primary.withValues(alpha: isToday && !isSelected ? 1.0 : 0.0),
                            ),
                          )
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
            const SizedBox(height: 16),

            // ── Inline Filter Chips ──────────────────────────
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final f = _filters[index];
                  final isActive = _activeFilter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _activeFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.transparent : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? Colors.white : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        f,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isActive ? Colors.white : AppColors.textHint,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── Header Subtitle count ──
            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Row(
                      children: [
                        Container(
                           padding: const EdgeInsets.all(4),
                           decoration: BoxDecoration(
                             color: AppColors.primary.withValues(alpha: 0.1),
                             borderRadius: BorderRadius.circular(6)
                           ),
                           child: Icon(Icons.assignment_ind_rounded, size: 14, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Text('Consultations', style: AppTextStyles.h3),
                      ]
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Text(
                        '${filtered.length}',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      ),
                    ),
                 ]
               )
            ),

            // ── List ─────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 3))
                  : state.error != null
                      ? _errorView(state.error!)
                      : filtered.isEmpty
                          ? _emptyView()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () => ref
                                  .read(appointmentListProvider.notifier)
                                  .loadAppointments(),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100), // extra padding for FAB
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  return _AnimatedCard(
                                    index: index,
                                    child: _appointmentCard(filtered[index]),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentCard(AppointmentModel apt) {
    // Styling mapped to status and type
    Color statusColor = AppColors.success;
    String statusStr = 'Done';
    IconData statusIcon = Icons.check_circle_rounded;
    
    if (apt.status == AppointmentStatus.cancelled) {
       statusColor = AppColors.error;
       statusStr = 'Missed';
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
    
    IconData typeIcon = Icons.person_rounded;
    Color typeColor = AppColors.accent;
    String typeLabel = 'Walk-In Patient';
    
    if (isCallBy) {
      typeIcon = Icons.phone_rounded;
      typeColor = AppColors.info;
      typeLabel = 'Call-By Consultation';
    } else if (isSession) {
      typeIcon = Icons.healing_rounded;
      typeColor = AppColors.primary;
      typeLabel = 'Treatment Session';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Top Row: Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar / Phone Icon box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    typeIcon,
                    color: typeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                // Name and Detail
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
                      const SizedBox(height: 4),
                      Text(
                        typeLabel,
                        style: AppTextStyles.caption.copyWith(color: typeColor),
                      ),
                    ],
                  ),
                ),
                // Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(height: 4),
                    Text(
                      TimeUtils.formatStringTime(apt.time),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Divider
          const Divider(color: AppColors.border, height: 1),
          
          // Bottom Row: Status Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusStr,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Actions
                if (apt.status == AppointmentStatus.scheduled) ...[
                  _iconAction(Icons.open_in_new_rounded, AppColors.primary,
                      onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientInfoScreen(appointment: apt),
                      ),
                    ).then((_) => ref
                        .read(appointmentListProvider.notifier)
                        .loadAppointments());
                  }),
                  const SizedBox(width: 12),
                  _iconAction(Icons.cancel_outlined, AppColors.error,
                      onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('Cancel Appointment?'),
                        content: const Text(
                            'This appointment will be marked as cancelled.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Yes, Cancel',
                                style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref
                          .read(appointmentListProvider.notifier)
                          .updateStatus(apt.id, AppointmentStatus.cancelled);
                    }
                  }),
                ] else if (apt.status == AppointmentStatus.inProgress) ...[
                  _iconAction(Icons.check_circle_outlined, AppColors.success,
                      onTap: () {
                    ref
                        .read(appointmentListProvider.notifier)
                        .updateStatus(apt.id, AppointmentStatus.completed);
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(IconData icon, Color defaultColor,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: defaultColor.withValues(alpha: 0.8)),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded,
              size: 64, color: AppColors.textHint.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'No appointments found',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the New Appointment button to create one.',
            style: AppTextStyles.caption,
          ),
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
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(appointmentListProvider.notifier).loadAppointments(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Staggered slide-in animation wrapper for list cards.
class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedCard({required this.child, required this.index});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Stagger by index
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
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
