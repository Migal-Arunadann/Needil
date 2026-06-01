import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pms_app/core/theme/app_theme.dart';

/// Utility for launching WhatsApp chats with pre-formatted clinical messages.
class WhatsAppHelper {
  WhatsAppHelper._();

  /// Strips a phone number down to digits only, prepends country code if needed.
  static String _cleanPhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    // If it's a 10-digit Indian number, prepend 91
    if (digits.length == 10) digits = '91$digits';
    return digits;
  }

  /// Launches WhatsApp with an optional pre-filled [message].
  static Future<bool> _launch(String phone, String message) async {
    final digits = _cleanPhone(phone);
    if (digits.isEmpty) return false;
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$digits?text=$encoded');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Opens WhatsApp chat directly — no prefilled text, just a simple redirect.
  static Future<bool> openChat(String phone) async {
    final digits = _cleanPhone(phone);
    if (digits.isEmpty) return false;
    final uri = Uri.parse('https://wa.me/$digits');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Shows the WhatsApp action bottom-sheet.
  ///
  /// [phone]           — patient phone number  
  /// [patientName]     — patient's full name  
  /// [appointmentTime] — optional appointment time string (e.g. "10:30 AM")  
  /// [clinicName]      — optional clinic / doctor name to personalise messages  
  /// [isEnded]         — when true, shows Follow-up; hides Reminder and Reschedule
  /// [isMissed]        — when true, shows missed-schedule messaging options
  /// [clinicLocation]  — optional clinic Google Maps link or address for location sharing
  static Future<void> showMenu({
    required BuildContext context,
    required String phone,
    required String patientName,
    String? appointmentTime,
    String? appointmentDate,
    String? clinicName,
    bool isEnded = false,
    bool isMissed = false,
    String? clinicLocation,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WhatsAppSheet(
        phone: phone,
        patientName: patientName,
        appointmentTime: appointmentTime,
        appointmentDate: appointmentDate,
        clinicName: clinicName,
        isEnded: isEnded,
        isMissed: isMissed,
        clinicLocation: clinicLocation,
      ),
    );
  }
}

class _WhatsAppSheet extends StatefulWidget {
  final String phone;
  final String patientName;
  final String? appointmentTime;
  final String? appointmentDate;
  final String? clinicName;
  final bool isEnded;
  final bool isMissed;
  final String? clinicLocation;

  const _WhatsAppSheet({
    required this.phone,
    required this.patientName,
    this.appointmentTime,
    this.appointmentDate,
    this.clinicName,
    this.isEnded = false,
    this.isMissed = false,
    this.clinicLocation,
  });

  @override
  State<_WhatsAppSheet> createState() => _WhatsAppSheetState();
}

class _WhatsAppSheetState extends State<_WhatsAppSheet> {
  bool _launching = false;

  String get _firstName => widget.patientName.trim().split(' ').first;
  String get _clinic => widget.clinicName ?? 'our clinic';

  String get _reminderMsg {
    final time = widget.appointmentTime != null
        ? 'at *${widget.appointmentTime}*'
        : '';
    final date = widget.appointmentDate != null
        ? 'on *${widget.appointmentDate}*'
        : 'today';
    return 'Hello $_firstName 👋,\n\nThis is a reminder for your appointment $date $time at $_clinic.\n\nPlease arrive 5–10 minutes early. If you need to reschedule, kindly let us know.\n\nThank you! 🙏';
  }

  String get _followUpMsg =>
      'Hello $_firstName 👋,\n\nHope you are feeling better! We just wanted to check in after your recent visit to $_clinic.\n\nIf you have any questions or need anything, feel free to reach out.\n\nTake care! 🌟';

  String get _rescheduleMsg {
    final time = widget.appointmentTime != null
        ? 'at ${widget.appointmentTime}'
        : '';
    final date = widget.appointmentDate != null
        ? 'on ${widget.appointmentDate}'
        : 'today';
    return 'Hello $_firstName,\n\nWe need to reschedule your appointment $date $time. Please let us know your preferred time and we will confirm a new slot.\n\nSorry for the inconvenience! 🙏';
  }

  String get _missedMsg {
    final time = widget.appointmentTime != null
        ? 'at ${widget.appointmentTime}'
        : '';
    final date = widget.appointmentDate != null
        ? 'on ${widget.appointmentDate}'
        : '';
    return 'Hello $_firstName,\n\nWe noticed you missed your scheduled appointment $date $time at $_clinic.\n\nWe hope everything is alright. Please let us know if you would like to reschedule to a convenient time.\n\nTake care! 🙏';
  }

  String get _locationMsg =>
      'Hello $_firstName 👋,\n\nHere is the location of $_clinic:\n\n📍 ${widget.clinicLocation}\n\nSee you soon! 🙏';

  Future<void> _send(String message) async {
    setState(() => _launching = true);
    final ok = await WhatsAppHelper._launch(widget.phone, message);
    if (mounted) {
      setState(() => _launching = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open WhatsApp. Is it installed?'),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which options to show based on state
    final showReminder = !widget.isEnded && !widget.isMissed;
    final showReschedule = !widget.isEnded && !widget.isMissed;
    final showFollowUp = widget.isEnded;
    final showMissed = widget.isMissed;
    final showLocation = widget.clinicLocation != null && widget.clinicLocation!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24, 16, 24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WhatsApp', style: context.textStyles.h3),
                      Text(
                        widget.patientName,
                        style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_launching)
                  SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF25D366)),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Options — conditional based on appointment state
            if (showReminder) ...[
              _option(
                icon: Icons.alarm_rounded,
                color: const Color(0xFF25D366),
                title: 'Appointment Reminder',
                subtitle: 'Send a reminder with date & time',
                onTap: () => _send(_reminderMsg),
              ),
              const SizedBox(height: 10),
            ],
            if (showReschedule) ...[
              _option(
                icon: Icons.event_repeat_rounded,
                color: context.colors.warning,
                title: 'Reschedule Request',
                subtitle: 'Inform them to reschedule their appointment',
                onTap: () => _send(_rescheduleMsg),
              ),
              const SizedBox(height: 10),
            ],
            if (showFollowUp) ...[
              _option(
                icon: Icons.favorite_rounded,
                color: context.colors.primary,
                title: 'Follow-Up Check-In',
                subtitle: 'Check how they are doing post-visit',
                onTap: () => _send(_followUpMsg),
              ),
              const SizedBox(height: 10),
            ],
            if (showMissed) ...[
              _option(
                icon: Icons.event_busy_rounded,
                color: context.colors.error,
                title: 'Missed Appointment',
                subtitle: 'Inform about the missed appointment & offer reschedule',
                onTap: () => _send(_missedMsg),
              ),
              const SizedBox(height: 10),
            ],
            if (showLocation) ...[
              _option(
                icon: Icons.location_on_rounded,
                color: const Color(0xFF1A73E8),
                title: 'Send Clinic Location',
                subtitle: 'Share Google Maps link to reach the clinic',
                onTap: () => _send(_locationMsg),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _launching ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.label.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.textStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }
}
