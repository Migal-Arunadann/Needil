import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/superadmin_service.dart';
import 'superadmin_shell.dart';

final _clinicDetailProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, id) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).getClinicWithStaff(id);
});

class SuperadminClinicDetailScreen extends ConsumerStatefulWidget {
  final String clinicId;
  const SuperadminClinicDetailScreen({super.key, required this.clinicId});

  @override
  ConsumerState<SuperadminClinicDetailScreen> createState() => _SuperadminClinicDetailScreenState();
}

class _SuperadminClinicDetailScreenState extends ConsumerState<SuperadminClinicDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? SAColors.error : SAColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _resetPassword(String collection, String recordId, String label) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Reset Password',
        subtitle: 'Set new password for $label',
        child: _darkTextField(ctrl, 'New Password', Icons.lock_outline_rounded, obscure: true),
        confirmLabel: 'Reset',
        confirmColor: SAColors.accent,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true) return;
    final pw = ctrl.text.trim();
    if (pw.length < 8) { _snack('Password must be at least 8 chars', error: true); return; }

    try {
      final pb = ref.read(pocketbaseProvider);
      final svc = SuperadminService(pb);
      if (collection == 'clinic') await svc.resetClinicPassword(recordId, pw);
      else if (collection == 'doctor') await svc.resetDoctorPassword(recordId, pw);
      else await svc.resetReceptionistPassword(recordId, pw);
      _snack('Password reset successfully');
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  Future<void> _deleteStaff(String collection, String recordId, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Delete $label?',
        subtitle: 'This action cannot be undone.',
        child: const SizedBox.shrink(),
        confirmLabel: 'Delete',
        confirmColor: SAColors.error,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      final svc = SuperadminService(pb);
      if (collection == 'doctor') await svc.deleteDoctor(recordId);
      else await svc.deleteReceptionist(recordId);
      _snack('$label deleted');
      ref.invalidate(_clinicDetailProvider(widget.clinicId));
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  Future<void> _deleteClinic(String name) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Delete Clinic',
        subtitle: 'Type the clinic name to confirm permanent deletion.',
        child: _darkTextField(ctrl, 'Type "$name"', Icons.business_outlined),
        confirmLabel: 'Permanently Delete',
        confirmColor: SAColors.error,
        onConfirm: () {
          if (ctrl.text.trim() == name) {
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Name does not match'),
              backgroundColor: SAColors.error,
            ));
          }
        },
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      await SuperadminService(pb).deleteClinic(widget.clinicId);
      _snack('Clinic deleted');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_clinicDetailProvider(widget.clinicId));

    return Scaffold(
      backgroundColor: SAColors.bg,
      appBar: AppBar(
        backgroundColor: SAColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: SAColors.textPrimary),
        title: Text('Clinic Detail', style: AppTextStyles.h4.copyWith(color: SAColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: SAColors.accent),
            onPressed: () => ref.invalidate(_clinicDetailProvider(widget.clinicId)),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: SAColors.accent,
          labelColor: SAColors.accent,
          unselectedLabelColor: SAColors.textHint,
          labelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Staff'),
            Tab(text: 'Danger'),
          ],
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: SAColors.accent)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: SAColors.error))),
        data: (data) {
          final clinic = data['clinic'] as RecordModel;
          final doctors = data['doctors'] as List<RecordModel>;
          final receptionists = data['receptionists'] as List<RecordModel>;
          return TabBarView(
            controller: _tabCtrl,
            children: [
              _InfoTab(clinic: clinic, clinicId: widget.clinicId),
              _StaffTab(
                doctors: doctors,
                receptionists: receptionists,
                onResetPassword: _resetPassword,
                onDelete: _deleteStaff,
              ),
              _DangerTab(
                clinicName: clinic.getStringValue('name'),
                onDelete: () => _deleteClinic(clinic.getStringValue('name')),
                onResetClinicPass: () => _resetPassword('clinic', widget.clinicId, clinic.getStringValue('name')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _darkDialog({
    required String title,
    required String subtitle,
    required Widget child,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
  }) {
    return Dialog(
      backgroundColor: SAColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.h4.copyWith(color: SAColors.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle, style: AppTextStyles.caption.copyWith(color: SAColors.textHint)),
            const SizedBox(height: 20),
            child,
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: TextButton(
                onPressed: onCancel,
                child: Text('Cancel', style: TextStyle(color: SAColors.textSecondary)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(confirmLabel),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _darkTextField(TextEditingController ctrl, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: AppTextStyles.bodyMedium.copyWith(color: SAColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: SAColors.textHint),
        prefixIcon: Icon(icon, color: SAColors.textHint, size: 18),
        filled: true,
        fillColor: SAColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SAColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SAColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SAColors.accent, width: 1.5)),
      ),
    );
  }
}

// ── Info Tab ──────────────────────────────────────────────────────────────────

class _InfoTab extends ConsumerStatefulWidget {
  final RecordModel clinic;
  final String clinicId;
  const _InfoTab({required this.clinic, required this.clinicId});

  @override
  ConsumerState<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends ConsumerState<_InfoTab> {
  late TextEditingController _name, _email, _phone, _city, _area, _state, _pincode, _beds;
  late bool _verified;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.clinic;
    _name    = TextEditingController(text: c.getStringValue('name'));
    _email   = TextEditingController(text: c.getStringValue('email'));
    _phone   = TextEditingController(text: c.getStringValue('phone'));
    _city    = TextEditingController(text: c.getStringValue('city'));
    _area    = TextEditingController(text: c.getStringValue('area'));
    _state   = TextEditingController(text: c.getStringValue('state'));
    _pincode = TextEditingController(text: c.getStringValue('pincode'));
    _beds    = TextEditingController(text: c.getIntValue('bed_count').toString());
    _verified = c.getBoolValue('verified');
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _city, _area, _state, _pincode, _beds]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      await SuperadminService(pb).updateClinic(widget.clinicId, {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'area': _area.text.trim(),
        'state': _state.text.trim(),
        'pincode': _pincode.text.trim(),
        'bed_count': int.tryParse(_beds.text.trim()) ?? 0,
        'verified': _verified,
      });
      ref.invalidate(_clinicDetailProvider(widget.clinicId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Saved!'), backgroundColor: SAColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: SAColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Verified toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: SAColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _verified ? SAColors.success.withValues(alpha: 0.4) : SAColors.border),
          ),
          child: Row(children: [
            Icon(Icons.verified_rounded, color: _verified ? SAColors.success : SAColors.textHint, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text('Clinic Verified', style: AppTextStyles.label.copyWith(color: SAColors.textPrimary))),
            Switch(
              value: _verified,
              activeColor: SAColors.success,
              onChanged: (v) => setState(() => _verified = v),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _section('Clinic Info'),
        _field(_name, 'Clinic Name', Icons.business_outlined),
        _field(_email, 'Email', Icons.email_outlined, readOnly: true),
        _field(_phone, 'Phone', Icons.phone_outlined),
        _field(_beds, 'Bed Count', Icons.bed_outlined, type: TextInputType.number),
        _section('Location'),
        _field(_city, 'City', Icons.location_city_outlined),
        _field(_area, 'Area', Icons.map_outlined),
        _field(_state, 'State', Icons.flag_outlined),
        _field(_pincode, 'Pincode', Icons.pin_drop_outlined),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving…' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SAColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(label, style: AppTextStyles.caption.copyWith(color: SAColors.textHint, letterSpacing: 1, fontSize: 11)),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        readOnly: readOnly,
        style: AppTextStyles.bodyMedium.copyWith(color: readOnly ? SAColors.textHint : SAColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.caption.copyWith(color: SAColors.textHint),
          prefixIcon: Icon(icon, color: SAColors.textHint, size: 18),
          filled: true,
          fillColor: SAColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SAColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SAColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SAColors.accent, width: 1.5)),
        ),
      ),
    );
  }
}

// ── Staff Tab ─────────────────────────────────────────────────────────────────

class _StaffTab extends StatelessWidget {
  final List<RecordModel> doctors;
  final List<RecordModel> receptionists;
  final Function(String, String, String) onResetPassword;
  final Function(String, String, String) onDelete;

  const _StaffTab({
    required this.doctors,
    required this.receptionists,
    required this.onResetPassword,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('Doctors (${doctors.length})', Icons.medical_services_outlined, const Color(0xFF06B6D4)),
        ...doctors.map((d) => _staffCard(
          name: d.getStringValue('name'),
          username: d.getStringValue('username'),
          icon: Icons.medical_services_outlined,
          color: const Color(0xFF06B6D4),
          onReset: () => onResetPassword('doctor', d.id, d.getStringValue('name')),
          onDelete: () => onDelete('doctor', d.id, d.getStringValue('name')),
        )),
        if (doctors.isEmpty)
          _emptyLabel('No doctors found'),
        const SizedBox(height: 20),
        _sectionHeader('Receptionists (${receptionists.length})', Icons.person_outline_rounded, SAColors.success),
        ...receptionists.map((r) => _staffCard(
          name: r.getStringValue('name'),
          username: r.getStringValue('username'),
          icon: Icons.person_outline_rounded,
          color: SAColors.success,
          onReset: () => onResetPassword('receptionist', r.id, r.getStringValue('name')),
          onDelete: () => onDelete('receptionist', r.id, r.getStringValue('name')),
        )),
        if (receptionists.isEmpty)
          _emptyLabel('No receptionists found'),
      ]),
    );
  }

  Widget _sectionHeader(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.label.copyWith(color: SAColors.textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _staffCard({
    required String name,
    required String username,
    required IconData icon,
    required Color color,
    required VoidCallback onReset,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SAColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SAColors.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isEmpty ? '(Unnamed)' : name,
            style: AppTextStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
          Text('@$username', style: AppTextStyles.caption.copyWith(color: SAColors.textHint)),
        ])),
        IconButton(
          icon: const Icon(Icons.lock_reset_rounded, color: SAColors.accent, size: 20),
          tooltip: 'Reset Password',
          onPressed: onReset,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: SAColors.error, size: 20),
          tooltip: 'Delete',
          onPressed: onDelete,
        ),
      ]),
    );
  }

  Widget _emptyLabel(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(msg, style: AppTextStyles.caption.copyWith(color: SAColors.textHint)),
  );
}

// ── Danger Tab ────────────────────────────────────────────────────────────────

class _DangerTab extends StatelessWidget {
  final String clinicName;
  final VoidCallback onDelete;
  final VoidCallback onResetClinicPass;

  const _DangerTab({required this.clinicName, required this.onDelete, required this.onResetClinicPass});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _actionCard(
          icon: Icons.lock_reset_rounded,
          color: SAColors.accent,
          title: 'Reset Clinic Password',
          subtitle: 'Set a new login password for the clinic admin account.',
          buttonLabel: 'Reset Password',
          onTap: onResetClinicPass,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SAColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SAColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.warning_amber_rounded, color: SAColors.error, size: 22),
              const SizedBox(width: 10),
              Text('Danger Zone', style: AppTextStyles.label.copyWith(color: SAColors.error, fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            Text(
              'Deleting "$clinicName" is permanent. All doctors, receptionists, and their accounts will be permanently removed. Patient records are not affected.',
              style: AppTextStyles.caption.copyWith(color: SAColors.textHint, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_forever_rounded, size: 20),
                label: const Text('Delete This Clinic'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SAColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SAColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SAColors.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.label.copyWith(color: SAColors.textPrimary)),
          Text(subtitle, style: AppTextStyles.caption.copyWith(color: SAColors.textHint)),
        ])),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: color),
          child: Text(buttonLabel, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
