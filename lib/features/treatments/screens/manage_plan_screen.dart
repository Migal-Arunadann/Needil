import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/features/treatments/models/treatment_plan_model.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/providers/treatment_provider.dart';
import 'package:pms_app/features/scheduling/screens/available_slots_screen.dart';
import 'package:pms_app/core/utils/time_utils.dart';

class ManagePlanScreen extends ConsumerStatefulWidget {
  final TreatmentPlanModel plan;
  final List<SessionModel> sessions;

  const ManagePlanScreen({
    super.key,
    required this.plan,
    required this.sessions,
  });

  @override
  ConsumerState<ManagePlanScreen> createState() => _ManagePlanScreenState();
}

class _ManagePlanScreenState extends ConsumerState<ManagePlanScreen> {
  late List<SessionModel> _editableSessions;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Only allow editing for non-terminated sessions
    _editableSessions = widget.sessions
        .where((s) =>
            s.status == SessionStatus.upcoming ||
            s.status == SessionStatus.overdue ||
            s.status == SessionStatus.waiting ||
            s.status == SessionStatus.inProgress ||
            s.status == SessionStatus.paused)
        .map((s) => s.copyWith()) // Work on copies
        .toList();

    _editableSessions.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));
  }

  Future<void> _changeSlot(int index) async {
    final session = _editableSessions[index];
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AvailableSlotsScreen(
          doctorId: widget.plan.doctorId,
          treatmentDuration: 30,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final newDate = DateFormat('yyyy-MM-dd').format(result['date'] as DateTime);
    final newTime = result['time'] as String;

    setState(() {
      _editableSessions[index] = session.copyWith(
        scheduledDate: newDate,
        scheduledTime: newTime,
      );
    });
  }

  static const List<String> _treatmentTypes = [
    'Acupuncture',
    'Acupressure',
    'Cupping Therapy',
    'Physiotherapy',
    'Foot Reflexology',
  ];

  void _changeModality(int index, String newModality) {
    final session = _editableSessions[index];
    setState(() {
      _editableSessions[index] = session.copyWith(treatmentModality: newModality);
    });
  }

  bool _validateChronology() {
    // Check all sessions in the plan (we must include non-editable completed ones too to ensure Session 2 is after Session 1)
    // Create a fully merged list of ALL sessions with the current local edits applied
    final allMerged = widget.sessions.map((original) {
      final edited = _editableSessions.cast<SessionModel?>().firstWhere(
            (e) => e?.id == original.id,
            orElse: () => null,
          );
      return edited ?? original;
    }).toList();

    allMerged.sort((a, b) => a.sessionNumber.compareTo(b.sessionNumber));

    for (int i = 0; i < allMerged.length - 1; i++) {
      final current = allMerged[i];
      final next = allMerged[i + 1];

      final dtCurrent = _parseDt(current.scheduledDate, current.scheduledTime);
      final dtNext = _parseDt(next.scheduledDate, next.scheduledTime);

      if (dtCurrent != null && dtNext != null) {
        if (!dtNext.isAfter(dtCurrent)) {
          AppToast.show(
            'Chronological error: Session ${next.sessionNumber} must be after Session ${current.sessionNumber}.',
            type: ToastType.error,
          );
          return false;
        }
      }
    }
    return true;
  }

  DateTime? _parseDt(String date, String? time) {
    try {
      if (time == null || time.isEmpty) return DateTime.parse(date);
      return DateTime.parse('${date}T$time:00');
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (!_validateChronology()) return;

    // Filter only those that actually changed
    final changedSessions = <SessionModel>[];
    for (final edited in _editableSessions) {
      final original = widget.sessions.firstWhere((s) => s.id == edited.id);
      if (edited.scheduledDate != original.scheduledDate ||
          edited.scheduledTime != original.scheduledTime ||
          edited.treatmentModality != original.treatmentModality ||
          edited.sessionType != original.sessionType) {
        changedSessions.add(edited);
      }
    }

    if (changedSessions.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final service = ref.read(treatmentServiceProvider);
      await service.bulkUpdateSessions(changedSessions);
      if (mounted) {
        AppToast.show('Plan updated successfully ✓', type: ToastType.success);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to save changes: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  String _fmtDay(String d) {
    try {
      return DateFormat('EEEE').format(DateTime.parse(d)).toUpperCase();
    } catch (_) {
      return '';
    }
  }

  String _fmtDateMain(String d) {
    try {
      return DateFormat('MMMM d, yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text('Manage Treatment Plan', style: context.textStyles.h3),
          ),
          // Content
          if (_editableSessions.isEmpty)
             Padding(
               padding: const EdgeInsets.all(32.0),
               child: Text(
                 'No pending sessions to manage.',
                 style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary),
               ),
             )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _editableSessions.length,
                  itemBuilder: (context, index) {
                    final session = _editableSessions[index];
                    String getSlotStr(SessionModel s, {bool short = false, bool useAt = false}) {
                      String? tDisp;
                      if (s.scheduledTime?.isNotEmpty == true) {
                        tDisp = TimeUtils.formatStringTime(s.scheduledTime!);
                      } else {
                        try {
                          final dt = DateTime.parse(s.scheduledDate).toLocal();
                          if (dt.hour != 0 || dt.minute != 0 || dt.second != 0) {
                            final time24 = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                            tDisp = TimeUtils.formatStringTime(time24);
                          }
                        } catch (_) {}
                      }
                      
                      String dateStr;
                      if (short) {
                         try {
                           dateStr = DateFormat('MMM d, yyyy').format(DateTime.parse(s.scheduledDate));
                         } catch (_) {
                           dateStr = s.scheduledDate;
                         }
                      } else {
                         dateStr = _fmtDateMain(s.scheduledDate);
                      }
                      
                      if (tDisp != null) return '$dateStr${useAt ? ' at ' : ', '}$tDisp';
                      return '$dateStr (Time pending)';
                    }
                    
                    final originalSession = widget.sessions.firstWhere((s) => s.id == session.id);
                    final didSlotChange = (session.scheduledDate != originalSession.scheduledDate) || (session.scheduledTime != originalSession.scheduledTime);
                    final isLast = index == _editableSessions.length - 1;
                    
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Timeline Node
                          SizedBox(
                            width: 60,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 2,
                                      color: context.colors.border.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                if (index == 0)
                                  Positioned(
                                    top: 0,
                                    height: 24,
                                    left: 0,
                                    right: 0,
                                    child: Container(color: context.colors.background),
                                  ),
                                if (isLast)
                                  Positioned(
                                    top: 60,
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(color: context.colors.background),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 24.0),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: context.colors.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: context.colors.primary.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${session.sessionNumber}',
                                      style: context.textStyles.h4.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Content Card
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.colors.border.withValues(alpha: 0.5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.shadowColor.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {},
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _fmtDay(session.scheduledDate),
                                                style: context.textStyles.caption.copyWith(
                                                  color: context.colors.textHint,
                                                  letterSpacing: 1.2,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if (didSlotChange)
                                                Wrap(
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    Text(
                                                      '[${getSlotStr(originalSession, short: true)}]',
                                                      style: context.textStyles.h3.copyWith(fontSize: 14, color: context.colors.textHint, decoration: TextDecoration.lineThrough),
                                                    ),
                                                    const Padding(
                                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                                      child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF059669)),
                                                    ),
                                                    Text(
                                                      '[${getSlotStr(session, short: true)}]',
                                                      style: context.textStyles.h3.copyWith(fontSize: 15, color: const Color(0xFF059669)),
                                                    ),
                                                  ],
                                                )
                                              else if (!getSlotStr(session).contains('Time pending'))
                                                Text(
                                                  getSlotStr(session, useAt: true),
                                                  style: context.textStyles.h3.copyWith(fontSize: 18),
                                                )
                                              else
                                                RichText(
                                                  text: TextSpan(
                                                    text: '${_fmtDateMain(session.scheduledDate)} ',
                                                    style: context.textStyles.h3.copyWith(fontSize: 18, color: context.colors.textPrimary),
                                                    children: [
                                                      WidgetSpan(
                                                        alignment: PlaceholderAlignment.middle,
                                                        child: Container(
                                                          margin: const EdgeInsets.only(left: 4),
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFD97706)),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                'Time pending',
                                                                style: context.textStyles.caption.copyWith(
                                                                  color: const Color(0xFFD97706),
                                                                  fontWeight: FontWeight.bold,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              const SizedBox(height: 12),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                // Treatment / Maintenance pill (fixed/read-only)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: session.isMaintenance
                                                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                                        : context.colors.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    session.isMaintenance ? 'Maintenance Session' : 'Treatment Session',
                                                    style: context.textStyles.caption.copyWith(
                                                      color: session.isMaintenance
                                                          ? const Color(0xFF059669)
                                                          : context.colors.primary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                // Treatment Modality Dropdown
                                                PopupMenuButton<String>(
                                                  initialValue: session.treatmentModality.isNotEmpty
                                                      ? session.treatmentModality
                                                      : widget.plan.treatmentType,
                                                  tooltip: 'Change Treatment Type',
                                                  onSelected: (val) => _changeModality(index, val),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  color: context.colors.surface,
                                                  itemBuilder: (context) => _treatmentTypes.map((type) {
                                                    return PopupMenuItem<String>(
                                                      value: type,
                                                      child: Text(type, style: context.textStyles.bodyMedium),
                                                    );
                                                  }).toList(),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: context.colors.surface,
                                                      border: Border.all(color: context.colors.border.withValues(alpha: 0.5)),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          session.treatmentModality.isNotEmpty
                                                              ? session.treatmentModality
                                                              : widget.plan.treatmentType,
                                                          style: context.textStyles.caption.copyWith(
                                                            color: context.colors.textSecondary,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Icon(Icons.arrow_drop_down_rounded, size: 16, color: context.colors.textHint),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _changeSlot(index),
                                          icon: Icon(Icons.edit_calendar_rounded, size: 18, color: context.colors.primary),
                                          label: Text('Change Slot', style: TextStyle(color: context.colors.primary)),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: context.colors.primary.withValues(alpha: 0.3)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Center(
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: AppButton(
                    label: 'Save Changes',
                    isLoading: _isSaving,
                    icon: Icons.check_circle_rounded,
                    onPressed: _saveChanges,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
