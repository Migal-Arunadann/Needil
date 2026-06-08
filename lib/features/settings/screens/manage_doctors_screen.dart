import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'edit_doctor_details_screen.dart';
import 'add_staff_doctor_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';


class ManageDoctorsScreen extends ConsumerStatefulWidget {
  const ManageDoctorsScreen({super.key});

  @override
  ConsumerState<ManageDoctorsScreen> createState() => _ManageDoctorsScreenState();
}

class _ManageDoctorsScreenState extends ConsumerState<ManageDoctorsScreen> {
  List<Map<String, dynamic>> _doctors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);
      final result = await pb.collection(PBCollections.doctors).getList(
        filter: 'clinic = "${auth.clinicId}"',
        sort: '-is_primary,name',
      );
      if (!mounted) return;
      setState(() {
        _doctors = result.items.map((r) => {
          'id': r.id,
          'name': r.getStringValue('name'),
          'username': r.getStringValue('username'),
          'is_primary': r.getBoolValue('is_primary'),
          'share_past_patients': r.getBoolValue('share_past_patients'),
          'share_future_patients': r.getBoolValue('share_future_patients'),
          'is_active': r.getBoolValue('is_active'),
          'phone': r.getStringValue('phone'),
          'dob': r.getStringValue('dob'),
          'photo': r.getStringValue('photo'),
          'collectionId': r.collectionId,
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? context.colors.error : context.colors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _toggleField(String docId, String field, bool current) async {
    try {
      final pb = ref.read(pocketbaseProvider);
      await pb.collection(PBCollections.doctors).update(
        docId, body: {field: !current},
      );
      await _load();
      _snack('Updated successfully.');
    } catch (e) {
      _snack('Failed to update. Check PocketBase update rules.', error: true);
    }
  }

  // ── Reset Password Dialog (proper StatefulWidget dialog, not bottom sheet) ──
  Future<void> _showResetPasswordDialog(String docId, String docName) async {
    final pb = ref.read(pocketbaseProvider); // read BEFORE async gap
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResetPasswordDialog(
        label: docName,
        newPassCtrl: newPassCtrl,
        confirmCtrl: confirmCtrl,
        onSubmit: (newPass, confirm) async {
          await pb.collection(PBCollections.doctors).update(
            docId, body: {'password': newPass, 'passwordConfirm': confirm},
          );
        },
      ),
    );

    newPassCtrl.dispose();
    confirmCtrl.dispose();

    if (result == true && mounted) _snack('Password reset successfully.');
  }

  // ── Navigate to full edit screen ──
  Future<void> _openEdit(String docId) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditDoctorDetailsScreen(doctorId: docId)),
    );
    if (refreshed == true && mounted) _load();
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Manage Doctors', style: context.textStyles.h3),
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: context.colors.primary),
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => AddStaffDoctorScreen()),
              );
              if (added == true && mounted) _load();
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.colors.primary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.colors.primary, strokeWidth: 2))
          : _error != null
              ? _buildError()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;

                    final mainBody = RefreshIndicator(
                      onRefresh: _load,
                      color: context.colors.primary,
                      child: ListView(
                        shrinkWrap: isDesktop,
                        physics: isDesktop ? const NeverScrollableScrollPhysics() : null,
                        padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.all(20),
                        children: [
                          // ── Primary Doctor ──
                          _sectionLabel('Primary Doctor (Clinic Owner)', Icons.admin_panel_settings_rounded, context.colors.primary),
                          const SizedBox(height: 10),
                          ..._doctors
                              .where((d) => d['is_primary'] == true)
                              .map((d) => _primaryDoctorCard(d)),
                          if (_doctors.where((d) => d['is_primary'] == true).isEmpty)
                            _emptyState('No primary doctor found.', Icons.warning_amber_rounded),

                          const SizedBox(height: 28),

                          // ── Working Doctors ──
                          _sectionLabel('Working Doctors', Icons.group_rounded, context.colors.accent),
                          const SizedBox(height: 10),
                          ..._doctors
                              .where((d) => d['is_primary'] != true)
                              .map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _workingDoctorCard(d),
                                  )),
                          if (_doctors.where((d) => d['is_primary'] != true).isEmpty)
                            _emptyState('No working doctors added yet.', Icons.group_add_rounded),
                        ],
                      ),
                    );

                    if (isDesktop) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: mainBody,
                            ),
                          ),
                        ),
                      );
                    } else {
                      return mainBody;
                    }
                  },
                ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 48, color: context.colors.error),
        const SizedBox(height: 12),
        Text('Failed to load doctors', style: context.textStyles.label),
        const SizedBox(height: 8),
        Text(_error ?? '', style: context.textStyles.caption, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _load, child: const Text('Retry')),
      ]),
    ),
  );

  Widget _sectionLabel(String text, IconData icon, Color color) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: color),
    ),
    const SizedBox(width: 10),
    Text(text, style: context.textStyles.label.copyWith(fontSize: 14, color: context.colors.textPrimary)),
  ]);

  Widget _emptyState(String msg, IconData icon) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.colors.border)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 36, color: context.colors.textHint),
      const SizedBox(height: 8),
      Text(msg, style: context.textStyles.caption, textAlign: TextAlign.center),
    ]),
  );

  // ── Primary Doctor Card — view only, NO reset password ──
  Widget _primaryDoctorCard(Map<String, dynamic> doc) {
    final photoUrl = _photoUrl(doc);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _avatar(photoUrl, isPrimary: true),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(doc['name'] ?? '', style: context.textStyles.label.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              _badge('OWNER', context.colors.primary),
            ]),
            // Primary doctor uses an internal auto-generated username — don't show it
          ])),
          // Edit schedule/treatments allowed
          _iconBtn(Icons.edit_rounded, context.colors.primary, () => _openEdit(doc['id'])),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, color: context.colors.border),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.info.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colors.info.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: context.colors.info),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Password is managed via the clinic account (Privacy & Security).',
              style: context.textStyles.caption.copyWith(fontSize: 11, color: context.colors.info),
            )),
          ]),
        ),
      ]),
    );
  }

  // ── Working Doctor Card — full edit + restrictions + reset password ──
  Widget _workingDoctorCard(Map<String, dynamic> doc) {
    final photoUrl = _photoUrl(doc);
    final sharePast = doc['share_past_patients'] as bool? ?? false;
    final shareFuture = doc['share_future_patients'] as bool? ?? false;
    final isActive = doc['is_active'] as bool? ?? true;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? context.colors.border : context.colors.error.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            _avatar(photoUrl, isPrimary: false),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(doc['name'] ?? '', style: context.textStyles.label.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                _badge(isActive ? 'ACTIVE' : 'INACTIVE', isActive ? context.colors.success : context.colors.error),
              ]),
              Text('@${doc['username'] ?? ''}', style: context.textStyles.caption.copyWith(fontSize: 11)),
            ])),
            _iconBtn(Icons.edit_rounded, context.colors.primary, () => _openEdit(doc['id'])),
          ]),
        ),

        const SizedBox(height: 12),
        Divider(height: 1, color: context.colors.border, indent: 16, endIndent: 16),
        const SizedBox(height: 12),

        // Restrictions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Access & Restrictions', style: context.textStyles.caption.copyWith(
            fontWeight: FontWeight.w600, color: context.colors.textSecondary, fontSize: 11,
          )),
        ),
        const SizedBox(height: 6),

        _restrictionTile(
          icon: Icons.history_rounded,
          label: 'View Past Patients',
          subtitle: 'Access to previously registered patients',
          value: sharePast,
          onChanged: (_) => _toggleField(doc['id'], 'share_past_patients', sharePast),
        ),
        _restrictionTile(
          icon: Icons.event_available_rounded,
          label: 'View Future Appointments',
          subtitle: 'Access to upcoming patient bookings',
          value: shareFuture,
          onChanged: (_) => _toggleField(doc['id'], 'share_future_patients', shareFuture),
        ),
        _restrictionTile(
          icon: Icons.toggle_on_rounded,
          label: 'Account Active',
          subtitle: 'Allow this doctor to log in',
          value: isActive,
          onChanged: (_) => _toggleField(doc['id'], 'is_active', isActive),
          activeColor: isActive ? context.colors.success : context.colors.error,
        ),

        const SizedBox(height: 8),
        Divider(height: 1, color: context.colors.border, indent: 16, endIndent: 16),
        const SizedBox(height: 12),

        // Reset Password button
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GestureDetector(
            onTap: () => _showResetPasswordDialog(doc['id'], doc['name'] ?? ''),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_reset_rounded, size: 15, color: context.colors.warning),
                const SizedBox(width: 6),
                Text('Reset Login Password', style: context.textStyles.caption.copyWith(color: context.colors.warning, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _restrictionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    activeColor ??= context.colors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        secondary: Icon(icon, size: 18, color: value ? activeColor : context.colors.textHint),
        title: Text(label, style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 12, color: context.colors.textPrimary)),
        subtitle: Text(subtitle, style: context.textStyles.caption.copyWith(fontSize: 10)),
        value: value,
        onChanged: (v) {
          HapticFeedback.lightImpact();
          onChanged(v);
        },
        activeColor: activeColor,
        dense: true,
      ),
    );
  }

  Widget _avatar(String? photoUrl, {required bool isPrimary}) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      gradient: photoUrl == null ? (isPrimary ? context.colors.heroGradient : null) : null,
      color: photoUrl == null && !isPrimary ? context.colors.accent.withValues(alpha: 0.1) : null,
      borderRadius: BorderRadius.circular(12),
      image: photoUrl != null ? DecorationImage(image: NetworkImage(ImageHelper.getSecureUrl(photoUrl)), fit: BoxFit.cover) : null,
    ),
    child: photoUrl == null
        ? Icon(isPrimary ? Icons.star_rounded : Icons.person_rounded,
            color: isPrimary ? Colors.white : context.colors.accent, size: 22)
        : null,
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: context.textStyles.caption.copyWith(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
  );

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 16, color: color),
    ),
  );

  String? _photoUrl(Map<String, dynamic> doc) {
    final photo = doc['photo'] as String?;
    if (photo == null || photo.isEmpty) return null;
    final colId = doc['collectionId'] as String?;
    final id = doc['id'] as String?;
    if (colId == null || id == null) return null;
    return '$pbBaseUrl/api/files/$colId/$id/$photo';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Reusable Reset Password Dialog — proper StatefulWidget avoids all frame /
// dependency scope issues that plague StatefulBuilder in bottom sheets.
// ════════════════════════════════════════════════════════════════════════════

class _ResetPasswordDialog extends StatefulWidget {
  final String label;
  final TextEditingController newPassCtrl;
  final TextEditingController confirmCtrl;
  final Future<void> Function(String newPass, String confirm) onSubmit;

  const _ResetPasswordDialog({
    required this.label,
    required this.newPassCtrl,
    required this.confirmCtrl,
    required this.onSubmit,
  });

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final newPass = widget.newPassCtrl.text.trim();
    final confirm = widget.confirmCtrl.text.trim();
    if (newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onSubmit(newPass, confirm);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Failed: Check PocketBase update rule for doctors.'; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: context.colors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: context.colors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.lock_reset_rounded, color: context.colors.warning, size: 18),
      ),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reset Password', style: context.textStyles.h3),
        Text(widget.label, style: context.textStyles.caption.copyWith(color: context.colors.textHint, fontSize: 11)),
      ])),
    ]),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) ...[
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: context.colors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: 14, color: context.colors.error),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: context.textStyles.caption.copyWith(color: context.colors.error, fontSize: 11))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        _field('New Password', widget.newPassCtrl, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
        const SizedBox(height: 12),
        _field('Confirm Password', widget.confirmCtrl, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
      ]),
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context, false),
        child: Text('Cancel', style: context.textStyles.caption.copyWith(color: context.colors.textSecondary)),
      ),
      ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.warning,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: _loading
            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Reset', style: context.textStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    ],
  );

  Widget _field(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) =>
    TextField(
      controller: ctrl,
      obscureText: obscure,
      style: context.textStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.textStyles.caption.copyWith(color: context.colors.textHint),
        prefixIcon: Icon(Icons.lock_outline_rounded, color: context.colors.textHint, size: 18),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: context.colors.textHint, size: 18),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.colors.primary)),
        filled: true, fillColor: context.colors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
}