import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'edit_doctor_details_screen.dart';
import 'add_staff_doctor_screen.dart';

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
      backgroundColor: error ? AppColors.error : AppColors.success,
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
        label: 'Dr. $docName',
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Manage Doctors', style: AppTextStyles.h3),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const AddStaffDoctorScreen()),
              );
              if (added == true && mounted) _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // ── Primary Doctor ──
                      _sectionLabel('Primary Doctor (Clinic Owner)', Icons.admin_panel_settings_rounded, AppColors.primary),
                      const SizedBox(height: 10),
                      ..._doctors
                          .where((d) => d['is_primary'] == true)
                          .map((d) => _primaryDoctorCard(d)),
                      if (_doctors.where((d) => d['is_primary'] == true).isEmpty)
                        _emptyState('No primary doctor found.', Icons.warning_amber_rounded),

                      const SizedBox(height: 28),

                      // ── Working Doctors ──
                      _sectionLabel('Working Doctors', Icons.group_rounded, AppColors.accent),
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
                ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Text('Failed to load doctors', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Text(_error ?? '', style: AppTextStyles.caption, textAlign: TextAlign.center),
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
    Text(text, style: AppTextStyles.label.copyWith(fontSize: 14, color: AppColors.textPrimary)),
  ]);

  Widget _emptyState(String msg, IconData icon) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 36, color: AppColors.textHint),
      const SizedBox(height: 8),
      Text(msg, style: AppTextStyles.caption, textAlign: TextAlign.center),
    ]),
  );

  // ── Primary Doctor Card — view only, NO reset password ──
  Widget _primaryDoctorCard(Map<String, dynamic> doc) {
    final photoUrl = _photoUrl(doc);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _avatar(photoUrl, isPrimary: true),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('Dr. ${doc['name'] ?? ''}', style: AppTextStyles.label.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              _badge('OWNER', AppColors.primary),
            ]),
            Text('@${doc['username'] ?? ''}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ])),
          // Edit schedule/treatments allowed
          _iconBtn(Icons.edit_rounded, AppColors.primary, () => _openEdit(doc['id'])),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Password is managed via the clinic account (Privacy & Security).',
              style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.info),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? AppColors.border : AppColors.error.withValues(alpha: 0.3)),
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
                Flexible(child: Text('Dr. ${doc['name'] ?? ''}', style: AppTextStyles.label.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                _badge(isActive ? 'ACTIVE' : 'INACTIVE', isActive ? AppColors.success : AppColors.error),
              ]),
              Text('@${doc['username'] ?? ''}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ])),
            _iconBtn(Icons.edit_rounded, AppColors.primary, () => _openEdit(doc['id'])),
          ]),
        ),

        const SizedBox(height: 12),
        Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
        const SizedBox(height: 12),

        // Restrictions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Access & Restrictions', style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 11,
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
          activeColor: isActive ? AppColors.success : AppColors.error,
        ),

        const SizedBox(height: 8),
        Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
        const SizedBox(height: 12),

        // Reset Password button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GestureDetector(
            onTap: () => _showResetPasswordDialog(doc['id'], doc['name'] ?? ''),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_reset_rounded, size: 15, color: AppColors.warning),
                const SizedBox(width: 6),
                Text('Reset Login Password', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
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
    Color activeColor = AppColors.primary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        secondary: Icon(icon, size: 18, color: value ? activeColor : AppColors.textHint),
        title: Text(label, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textPrimary)),
        subtitle: Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 10)),
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
        dense: true,
      ),
    );
  }

  Widget _avatar(String? photoUrl, {required bool isPrimary}) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      gradient: photoUrl == null ? (isPrimary ? AppColors.heroGradient : null) : null,
      color: photoUrl == null && !isPrimary ? AppColors.accent.withValues(alpha: 0.1) : null,
      borderRadius: BorderRadius.circular(12),
      image: photoUrl != null ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover) : null,
    ),
    child: photoUrl == null
        ? Icon(isPrimary ? Icons.star_rounded : Icons.person_rounded,
            color: isPrimary ? Colors.white : AppColors.accent, size: 22)
        : null,
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: AppTextStyles.caption.copyWith(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
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
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.lock_reset_rounded, color: AppColors.warning, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Reset Password', style: AppTextStyles.h3),
        Text(widget.label, style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11)),
      ])),
    ]),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 11))),
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
        child: Text('Cancel', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ),
      ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: _loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Reset', style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    ],
  );

  Widget _field(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) =>
    TextField(
      controller: ctrl,
      obscureText: obscure,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint, size: 18),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textHint, size: 18),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
        filled: true, fillColor: AppColors.background, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
}
