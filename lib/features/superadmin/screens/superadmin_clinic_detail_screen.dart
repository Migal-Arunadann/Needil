import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/superadmin_service.dart';
import '../../../core/services/data_export_service.dart';
import 'superadmin_shell.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';


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

  Future<void> _deactivateClinic(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Deactivate Clinic?',
        subtitle: 'This will block all logins for "$name". The clinic has 30 days to reactivate before permanent deletion.',
        child: const SizedBox.shrink(),
        confirmLabel: 'Deactivate',
        confirmColor: SAColors.warning,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      await SuperadminService(pb).deactivateClinic(widget.clinicId);
      _snack('Clinic deactivated. Scheduled for deletion in 30 days.');
      ref.invalidate(_clinicDetailProvider(widget.clinicId));
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  Future<void> _reactivateClinic(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Reactivate Clinic?',
        subtitle: 'This will restore full login access for "$name" and cancel the pending deletion.',
        child: const SizedBox.shrink(),
        confirmLabel: 'Reactivate',
        confirmColor: SAColors.success,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      await SuperadminService(pb).reactivateClinic(widget.clinicId);
      _snack('Clinic reactivated successfully.');
      ref.invalidate(_clinicDetailProvider(widget.clinicId));
    } catch (e) {
      _snack('Failed: $e', error: true);
    }
  }

  Future<void> _permanentlyDeleteClinic(String name) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Permanently Delete Clinic',
        subtitle: 'This CANNOT be undone. All data across all 10 collections will be wiped. Type the clinic name to confirm.',
        child: _darkTextField(ctrl, 'Type "$name"', Icons.business_outlined),
        confirmLabel: 'Delete Forever',
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
      await SuperadminService(pb).permanentlyDeleteClinic(widget.clinicId);
      _snack('Clinic permanently deleted.');
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
        title: Text('Clinic Detail', style: context.textStyles.h4.copyWith(color: SAColors.textPrimary)),
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
          labelStyle: context.textStyles.caption.copyWith(fontWeight: FontWeight.w700),
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
                clinicRecord: clinic,
                clinicId: widget.clinicId,
                onDeactivate: () => _deactivateClinic(clinic.getStringValue('name')),
                onReactivate: () => _reactivateClinic(clinic.getStringValue('name')),
                onPermanentDelete: () => _permanentlyDeleteClinic(clinic.getStringValue('name')),
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
            Text(title, style: context.textStyles.h4.copyWith(color: SAColors.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle, style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
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
      style: context.textStyles.bodyMedium.copyWith(color: SAColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.textStyles.caption.copyWith(color: SAColors.textHint),
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
            Expanded(child: Text('Clinic Verified', style: context.textStyles.label.copyWith(color: SAColors.textPrimary))),
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
    child: Text(label, style: context.textStyles.caption.copyWith(color: SAColors.textHint, letterSpacing: 1, fontSize: 11)),
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        readOnly: readOnly,
        style: context.textStyles.bodyMedium.copyWith(color: readOnly ? SAColors.textHint : SAColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: context.textStyles.caption.copyWith(color: SAColors.textHint),
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
        _sectionHeader(context, 'Doctors (${doctors.length})', Icons.medical_services_outlined, const Color(0xFF06B6D4)),
        ...doctors.map((d) => _staffCard(context, 
          name: d.getStringValue('name'),
          username: d.getStringValue('username'),
          icon: Icons.medical_services_outlined,
          color: const Color(0xFF06B6D4),
          onReset: () => onResetPassword('doctor', d.id, d.getStringValue('name')),
          onDelete: () => onDelete('doctor', d.id, d.getStringValue('name')),
        )),
        if (doctors.isEmpty)
          _emptyLabel(context, 'No doctors found'),
        const SizedBox(height: 20),
        _sectionHeader(context, 'Receptionists (${receptionists.length})', Icons.person_outline_rounded, SAColors.success),
        ...receptionists.map((r) => _staffCard(context, 
          name: r.getStringValue('name'),
          username: r.getStringValue('username'),
          icon: Icons.person_outline_rounded,
          color: SAColors.success,
          onReset: () => onResetPassword('receptionist', r.id, r.getStringValue('name')),
          onDelete: () => onDelete('receptionist', r.id, r.getStringValue('name')),
        )),
        if (receptionists.isEmpty)
          _emptyLabel(context, 'No receptionists found'),
      ]),
    );
  }

  Widget _sectionHeader(BuildContext context, String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: context.textStyles.label.copyWith(color: SAColors.textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _staffCard(BuildContext context, {
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
            style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
          Text('@$username', style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
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

  Widget _emptyLabel(BuildContext context, String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(msg, style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
  );
}

// ── Danger Tab ────────────────────────────────────────────────────────────────

class _DangerTab extends ConsumerStatefulWidget {
  final RecordModel clinicRecord;
  final String clinicId;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;
  final VoidCallback onPermanentDelete;
  final VoidCallback onResetClinicPass;

  const _DangerTab({
    required this.clinicRecord,
    required this.clinicId,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onPermanentDelete,
    required this.onResetClinicPass,
  });

  @override
  ConsumerState<_DangerTab> createState() => _DangerTabState();
}

class _DangerTabState extends ConsumerState<_DangerTab> {
  bool _isExporting = false;
  String? _exportStatus;

  bool get _isDeactivated =>
      widget.clinicRecord.getBoolValue('is_deactivated');

  DateTime? get _scheduledDeletion => DateTime.tryParse(
      widget.clinicRecord.getStringValue('scheduled_deletion_date'));

  int get _daysRemaining {
    final del = _scheduledDeletion;
    if (del == null) return 30;
    return del.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'Fetching data…';
    });
    try {
      final pb = ref.read(pocketbaseProvider);
      final svc = DataExportService(pb);
      final clinicName = widget.clinicRecord.getStringValue('name');
      setState(() => _exportStatus = 'Generating CSVs…');
      final csvFiles = await svc.exportAllData(widget.clinicId, clinicName);

      if (kIsWeb) {
        // On web: trigger browser downloads one by one
        for (final entry in csvFiles.entries) {
          setState(() => _exportStatus = 'Downloading ${entry.key}…');
          downloadCsvWeb(entry.value, entry.key);
          await Future.delayed(const Duration(milliseconds: 500));
        }
        setState(() => _exportStatus = '✓ ${csvFiles.length} files exported successfully!');
      } else {
        // On mobile: show snack with file count (share logic can be added later)
        final totalRows = csvFiles.values.fold<int>(
            0, (sum, csv) => sum + csv.split('\n').length - 1);
        setState(() => _exportStatus = '✓ Exported $totalRows records across ${csvFiles.length} CSV files.');
      }
    } catch (e) {
      setState(() => _exportStatus = '✗ Export failed: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinicName = widget.clinicRecord.getStringValue('name');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Status Banner ──────────────────────────────────────────────────
        if (_isDeactivated)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SAColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SAColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded, color: SAColors.warning, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Clinic Deactivated', style: const TextStyle(color: SAColors.warning, fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  _scheduledDeletion != null
                      ? 'Scheduled deletion in $_daysRemaining days (${_scheduledDeletion!.toLocal().toString().substring(0, 10)})'
                      : 'Pending deletion.',
                  style: const TextStyle(color: SAColors.textHint, fontSize: 12),
                ),
              ])),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SAColors.success.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SAColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: SAColors.success, size: 22),
              const SizedBox(width: 12),
              const Expanded(child: Text('Clinic Status: Active',
                  style: TextStyle(color: SAColors.success, fontWeight: FontWeight.w700, fontSize: 14))),
            ]),
          ),

        const SizedBox(height: 16),

        // ── Reset Password ─────────────────────────────────────────────────
        _actionCard(context,
          icon: Icons.lock_reset_rounded,
          color: SAColors.accent,
          title: 'Reset Clinic Password',
          subtitle: 'Set a new login password for the clinic admin account.',
          buttonLabel: 'Reset Password',
          onTap: widget.onResetClinicPass,
        ),
        const SizedBox(height: 12),

        // ── Data Export ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SAColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SAColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SAColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.download_rounded, color: SAColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Export All Clinic Data', style: TextStyle(color: SAColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Download patients, appointments, consultations,\ntreatment plans, and sessions as CSV files.',
                    style: TextStyle(color: SAColors.textHint, fontSize: 12, height: 1.4)),
              ])),
            ]),
            if (_exportStatus != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _exportStatus!.startsWith('✓')
                      ? SAColors.success.withValues(alpha: 0.08)
                      : _exportStatus!.startsWith('✗')
                          ? SAColors.error.withValues(alpha: 0.08)
                          : SAColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_exportStatus!,
                    style: TextStyle(
                      color: _exportStatus!.startsWith('✓')
                          ? SAColors.success
                          : _exportStatus!.startsWith('✗')
                              ? SAColors.error
                              : SAColors.accent,
                      fontSize: 12,
                    )),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 40,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportData,
                icon: _isExporting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(_isExporting ? 'Exporting…' : 'Export Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SAColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Danger Zone ────────────────────────────────────────────────────
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
              const Text('Danger Zone', style: TextStyle(color: SAColors.error, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 10),

            if (!_isDeactivated) ...[
              Text(
                'Deactivating "$clinicName" will block all clinic, doctor, and receptionist logins immediately. '
                'The clinic data is preserved for 30 days, after which it can be permanently deleted.',
                style: const TextStyle(color: SAColors.textHint, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton.icon(
                  onPressed: widget.onDeactivate,
                  icon: const Icon(Icons.lock_outline_rounded, size: 20),
                  label: const Text('Deactivate Clinic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SAColors.warning,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else ...[
              Text(
                'This clinic is deactivated. You can reactivate it within the 30-day window, '
                'or permanently delete all data now. Permanent deletion removes all records '
                'across all 10 collections and cannot be undone.',
                style: const TextStyle(color: SAColors.textHint, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton.icon(
                  onPressed: widget.onReactivate,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text('Reactivate Clinic'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SAColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton.icon(
                  onPressed: widget.onPermanentDelete,
                  icon: const Icon(Icons.delete_forever_rounded, size: 20),
                  label: const Text('Permanently Delete All Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SAColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _actionCard(BuildContext context, {
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
          Text(title, style: const TextStyle(color: SAColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          Text(subtitle, style: const TextStyle(color: SAColors.textHint, fontSize: 12)),
        ])),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(foregroundColor: color),
          child: Text(buttonLabel, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ]),
    );
  }
}

