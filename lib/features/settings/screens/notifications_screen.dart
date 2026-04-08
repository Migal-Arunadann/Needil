import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _patientLateReminder = true;
  int _lateMins = 10;
  bool _missedConsultation = true;
  bool _missedSession = true;
  bool _clinicAlerts = true;
  bool _appointmentReminders = true;
  bool _newAppointmentBooked = true;
  bool _appointmentCancelled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _patientLateReminder = prefs.getBool('notif_patient_late') ?? true;
      _lateMins = prefs.getInt('notif_late_mins') ?? 10;
      _missedConsultation =
          prefs.getBool('notif_missed_consultation') ?? true;
      _missedSession = prefs.getBool('notif_missed_session') ?? true;
      _clinicAlerts = prefs.getBool('notif_clinic_alerts') ?? true;
      _appointmentReminders =
          prefs.getBool('notif_appointment_reminders') ?? true;
      _newAppointmentBooked =
          prefs.getBool('notif_new_appointment') ?? true;
      _appointmentCancelled =
          prefs.getBool('notif_appointment_cancelled') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_patient_late', _patientLateReminder);
    await prefs.setInt('notif_late_mins', _lateMins);
    await prefs.setBool('notif_missed_consultation', _missedConsultation);
    await prefs.setBool('notif_missed_session', _missedSession);
    await prefs.setBool('notif_clinic_alerts', _clinicAlerts);
    await prefs.setBool('notif_appointment_reminders', _appointmentReminders);
    await prefs.setBool('notif_new_appointment', _newAppointmentBooked);
    await prefs.setBool('notif_appointment_cancelled', _appointmentCancelled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notification preferences saved ✓'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Notifications', style: AppTextStyles.h2),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _savePrefs,
            child: Text(
              'Save',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Patient Alerts ──
                  _sectionHeader(
                      'Patient Alerts', Icons.notification_important_outlined),
                  const SizedBox(height: 12),
                  _buildToggleTile(
                    title: 'Patient Late Reminder',
                    subtitle:
                        'Alert when a scheduled patient hasn\'t arrived within $_lateMins min of appointment time',
                    icon: Icons.timer_off_outlined,
                    value: _patientLateReminder,
                    color: AppColors.warning,
                    onChanged: (v) =>
                        setState(() => _patientLateReminder = v),
                  ),
                  if (_patientLateReminder) ...[
                    const SizedBox(height: 8),
                    _buildLateMinutesPicker(),
                  ],
                  const SizedBox(height: 12),
                  _buildToggleTile(
                    title: 'Missed Consultation',
                    subtitle:
                        'Alert when a consultation appointment passes with no patient check-in',
                    icon: Icons.medical_information_outlined,
                    value: _missedConsultation,
                    color: AppColors.error,
                    onChanged: (v) =>
                        setState(() => _missedConsultation = v),
                  ),
                  const SizedBox(height: 12),
                  _buildToggleTile(
                    title: 'Missed Session',
                    subtitle:
                        'Alert when a treatment session passes with no patient check-in',
                    icon: Icons.event_busy_outlined,
                    value: _missedSession,
                    color: AppColors.error,
                    onChanged: (v) =>
                        setState(() => _missedSession = v),
                  ),

                  const SizedBox(height: 28),

                  // ── Clinic Alerts ──
                  _sectionHeader('Clinic Alerts', Icons.business_outlined),
                  const SizedBox(height: 12),
                  _buildToggleTile(
                    title: 'Clinic Alerts',
                    subtitle:
                        'Capacity warnings, scheduling conflicts, and clinic-specific notifications',
                    icon: Icons.warning_amber_outlined,
                    value: _clinicAlerts,
                    color: const Color(0xFF6366F1),
                    onChanged: (v) => setState(() => _clinicAlerts = v),
                  ),

                  const SizedBox(height: 28),

                  // ── Appointment Notifications ──
                  _sectionHeader(
                      'Appointment Notifications', Icons.event_outlined),
                  const SizedBox(height: 12),
                  _buildToggleTile(
                    title: 'Appointment Reminders',
                    subtitle: 'Remind you before upcoming appointments',
                    icon: Icons.notifications_active_outlined,
                    value: _appointmentReminders,
                    color: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => _appointmentReminders = v),
                  ),
                  const SizedBox(height: 12),
                  _buildToggleTile(
                    title: 'New Appointment Booked',
                    subtitle:
                        'Notify when a new appointment is scheduled',
                    icon: Icons.add_circle_outline,
                    value: _newAppointmentBooked,
                    color: AppColors.success,
                    onChanged: (v) =>
                        setState(() => _newAppointmentBooked = v),
                  ),
                  const SizedBox(height: 12),
                  _buildToggleTile(
                    title: 'Appointment Cancelled',
                    subtitle:
                        'Notify when an appointment is cancelled',
                    icon: Icons.cancel_outlined,
                    value: _appointmentCancelled,
                    color: AppColors.error,
                    onChanged: (v) =>
                        setState(() => _appointmentCancelled = v),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: AppTextStyles.label
                .copyWith(fontSize: 14, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textHint, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildLateMinutesPicker() {
    return Container(
      margin: const EdgeInsets.only(left: 54),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text('Alert after', style: AppTextStyles.bodyMedium.copyWith(fontSize: 13)),
          const SizedBox(width: 12),
          ...([5, 10, 15, 20].map((mins) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _lateMins = mins),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _lateMins == mins
                          ? AppColors.warning
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _lateMins == mins
                            ? AppColors.warning
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '${mins}m',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            _lateMins == mins ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ))),
        ],
      ),
    );
  }
}
