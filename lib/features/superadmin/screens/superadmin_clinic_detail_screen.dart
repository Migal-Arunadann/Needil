import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/services/superadmin_service.dart';
import 'package:pms_app/core/utils/error_formatter.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_shell.dart';
import 'package:pms_app/core/theme/app_theme.dart';

// Providers for Clinic Sub-Resources
final _clinicDetailProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, id) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).getClinicWithStaff(id);
});

final _clinicPatientsProvider = FutureProvider.family.autoDispose<ResultList<RecordModel>, (String, String)>((ref, arg) {
  final (clinicId, search) = arg;
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchClinicPatients(clinicId, search: search, perPage: 100);
});

final _clinicConsultationsProvider = FutureProvider.family.autoDispose<ResultList<RecordModel>, (String, String)>((ref, arg) {
  final (clinicId, search) = arg;
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchClinicConsultations(clinicId, search: search, perPage: 100);
});

final _clinicPlansProvider = FutureProvider.family.autoDispose<ResultList<RecordModel>, String>((ref, clinicId) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchClinicTreatmentPlans(clinicId, perPage: 100);
});

final _clinicSessionsProvider = FutureProvider.family.autoDispose<ResultList<RecordModel>, String>((ref, clinicId) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchClinicSessions(clinicId, perPage: 150);
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

  // Search states for Patients & Consultations tabs
  String _patientSearch = '';
  String _consultationSearch = '';
  final _patientSearchCtrl = TextEditingController();
  final _consultationSearchCtrl = TextEditingController();

  // Subscription editor state
  String _selectedTier = 'base';
  String _selectedStatus = 'active';
  DateTime? _selectedEndDate;
  late TextEditingController _photoLimitCtrl;
  late TextEditingController _bedCountCtrl;
  bool _subEditorInitialized = false;
  bool _isSavingSub = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _photoLimitCtrl = TextEditingController();
    _bedCountCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _patientSearchCtrl.dispose();
    _consultationSearchCtrl.dispose();
    _photoLimitCtrl.dispose();
    _bedCountCtrl.dispose();
    super.dispose();
  }

  void _initSubEditor(RecordModel clinic) {
    if (_subEditorInitialized) return;
    _selectedTier = clinic.getStringValue('subscription_tier').isNotEmpty
        ? clinic.getStringValue('subscription_tier')
        : 'base';
    _selectedStatus = clinic.getStringValue('subscription_status').isNotEmpty
        ? clinic.getStringValue('subscription_status')
        : 'active';
    final endStr = clinic.getStringValue('subscription_end_date');
    _selectedEndDate = DateTime.tryParse(endStr);
    _photoLimitCtrl.text = '${clinic.getIntValue('photo_limit', 2000)}';
    _bedCountCtrl.text = '${clinic.getIntValue('bed_count', 0)}';
    _subEditorInitialized = true;
  }

  // ── Save Subscription Changes ──────────────────────────────
  Future<void> _saveSubscription() async {
    setState(() => _isSavingSub = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final photoLimit = int.tryParse(_photoLimitCtrl.text.trim()) ?? 2000;
      final bedCount = int.tryParse(_bedCountCtrl.text.trim()) ?? 0;

      await SuperadminService(pb).updateClinicSubscription(
        widget.clinicId,
        tier: _selectedTier,
        status: _selectedStatus,
        endDate: _selectedEndDate,
        photoLimit: photoLimit,
        bedCount: bedCount,
      );

      ref.invalidate(_clinicDetailProvider(widget.clinicId));
      if (mounted) {
        AppToast.show('✓ Subscription plan updated successfully', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to update subscription: ${ErrorFormatter.format(e)}', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSavingSub = false);
    }
  }

  // ── Password Reset ──────────────────────────────────────────
  Future<void> _resetPassword(String collection, String recordId, String label) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Reset Password',
        subtitle: 'Set new password for $label',
        child: _darkTextField(ctrl, 'New Password (min 8 chars)', Icons.lock_outline_rounded, obscure: true),
        confirmLabel: 'Reset',
        confirmColor: SAColors.accent,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true) return;
    final pw = ctrl.text.trim();
    if (pw.length < 8) {
      AppToast.show('Password must be at least 8 chars', type: ToastType.error);
      return;
    }

    try {
      final pb = ref.read(pocketbaseProvider);
      final svc = SuperadminService(pb);
      if (collection == 'clinic') {
        await svc.resetClinicPassword(recordId, pw);
      } else if (collection == 'doctor') {
        await svc.resetDoctorPassword(recordId, pw);
      } else {
        await svc.resetReceptionistPassword(recordId, pw);
      }
      AppToast.show('✓ Password reset successfully', type: ToastType.success);
    } catch (e) {
      AppToast.show('Failed: $e', type: ToastType.error);
    }
  }

  // ── Helper: Safe relation name extraction ─────────────────────
  String _getExpandedName(RecordModel r, String relationKey, String fallback) {
    try {
      final expanded = r.get<RecordModel?>('expand.$relationKey');
      if (expanded != null) {
        final fullName = expanded.getStringValue('full_name');
        if (fullName.isNotEmpty) return fullName;
        final name = expanded.getStringValue('name');
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return fallback;
  }

  // ── Patient Edit Modal ──────────────────────────────────────
  Future<void> _showEditPatientDialog(RecordModel patient) async {
    final existingName = patient.getStringValue('full_name').isNotEmpty
        ? patient.getStringValue('full_name')
        : patient.getStringValue('name');
    final nameCtrl = TextEditingController(text: existingName);
    final phoneCtrl = TextEditingController(text: patient.getStringValue('phone'));
    final ageCtrl = TextEditingController(text: '${patient.getIntValue('age', 0)}');
    final genderCtrl = TextEditingController(text: patient.getStringValue('gender'));
    final bloodCtrl = TextEditingController(text: patient.getStringValue('blood_group'));
    final addressCtrl = TextEditingController(text: patient.getStringValue('address'));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SAColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Patient Record', style: context.textStyles.h4.copyWith(color: SAColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _darkTextField(nameCtrl, 'Full Name', Icons.person_outline),
              const SizedBox(height: 10),
              _darkTextField(phoneCtrl, 'Phone Number', Icons.phone_outlined),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _darkTextField(ageCtrl, 'Age', Icons.cake_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: _darkTextField(genderCtrl, 'Gender', Icons.wc_outlined)),
                ],
              ),
              const SizedBox(height: 10),
              _darkTextField(bloodCtrl, 'Blood Group', Icons.bloodtype_outlined),
              const SizedBox(height: 10),
              _darkTextField(addressCtrl, 'Address', Icons.location_on_outlined),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: SAColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: SAColors.accent, foregroundColor: Colors.white),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final pb = ref.read(pocketbaseProvider);
      await SuperadminService(pb).updatePatient(patient.id, {
        'full_name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'age': int.tryParse(ageCtrl.text.trim()) ?? 0,
        'gender': genderCtrl.text.trim(),
        'blood_group': bloodCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
      });
      ref.invalidate(_clinicPatientsProvider((widget.clinicId, _patientSearch)));
      AppToast.show('✓ Patient record updated', type: ToastType.success);
    } catch (e) {
      AppToast.show('Failed: ${ErrorFormatter.format(e)}', type: ToastType.error);
    }
  }

  // ── Patient Delete Modal ────────────────────────────────────
  Future<void> _deletePatient(RecordModel patient) async {
    final name = patient.getStringValue('full_name').isNotEmpty
        ? patient.getStringValue('full_name')
        : patient.getStringValue('name');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Delete Patient?',
        subtitle: 'Are you sure you want to delete "$name"? All consultation logs associated with this patient will be affected.',
        child: const SizedBox.shrink(),
        confirmLabel: 'Delete Patient',
        confirmColor: SAColors.error,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true) return;

    try {
      final pb = ref.read(pocketbaseProvider);
      await SuperadminService(pb).deletePatient(patient.id);
      ref.invalidate(_clinicPatientsProvider((widget.clinicId, _patientSearch)));
      AppToast.show('Patient deleted', type: ToastType.success);
    } catch (e) {
      AppToast.show('Failed: ${ErrorFormatter.format(e)}', type: ToastType.error);
    }
  }

  // ── Consultation Delete Modal ───────────────────────────────
  Future<void> _deleteConsultation(RecordModel consultation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Delete Consultation?',
        subtitle: 'Are you sure you want to permanently delete this consultation entry?',
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
      await SuperadminService(pb).deleteConsultation(consultation.id);
      ref.invalidate(_clinicConsultationsProvider((widget.clinicId, _consultationSearch)));
      AppToast.show('Consultation deleted', type: ToastType.success);
    } catch (e) {
      AppToast.show('Failed: ${ErrorFormatter.format(e)}', type: ToastType.error);
    }
  }

  // ── Session Delete Modal ────────────────────────────────────
  Future<void> _deleteSession(RecordModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'Delete Session?',
        subtitle: 'Delete Session #${session.getIntValue('session_number')} from treatment plan?',
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
      await SuperadminService(pb).deleteSession(session.id);
      ref.invalidate(_clinicSessionsProvider(widget.clinicId));
      AppToast.show('Session deleted', type: ToastType.success);
    } catch (e) {
      AppToast.show('Failed: ${ErrorFormatter.format(e)}', type: ToastType.error);
    }
  }

  // ── Deactivate / Reactivate / Delete Clinic ─────────────────
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
      AppToast.show('Clinic deactivated', type: ToastType.success);
      ref.invalidate(_clinicDetailProvider(widget.clinicId));
    } catch (e) {
      AppToast.show('Failed: $e', type: ToastType.error);
    }
  }

  Future<void> _reactivateClinic() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      await SuperadminService(pb).reactivateClinic(widget.clinicId);
      AppToast.show('✓ Clinic reactivated', type: ToastType.success);
      ref.invalidate(_clinicDetailProvider(widget.clinicId));
    } catch (e) {
      AppToast.show('Failed: $e', type: ToastType.error);
    }
  }

  Future<void> _permanentlyDeleteClinic(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _darkDialog(
        title: 'PERMANENTLY Delete Clinic?',
        subtitle: 'This will irreversibly delete "$name", all staff, patients, appointments, and medical records. This CANNOT be undone.',
        child: const SizedBox.shrink(),
        confirmLabel: 'Permanently Delete',
        confirmColor: SAColors.error,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (confirmed != true) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      await SuperadminService(pb).permanentlyDeleteClinic(widget.clinicId);
      if (mounted) {
        AppToast.show('Clinic permanently deleted', type: ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      AppToast.show('Failed: $e', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_clinicDetailProvider(widget.clinicId));

    return Scaffold(
      backgroundColor: SAColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: SAColors.gradient),
        child: SafeArea(
          child: detailAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: SAColors.accent)),
            error: (e, _) => Center(
              child: Text('Error: ${ErrorFormatter.format(e)}', style: const TextStyle(color: SAColors.error)),
            ),
            data: (data) {
              final clinic = data['clinic'] as RecordModel;
              final doctors = (data['doctors'] as List<RecordModel>?) ?? [];
              final receptionists = (data['receptionists'] as List<RecordModel>?) ?? [];

              _initSubEditor(clinic);

              final name = clinic.getStringValue('name');
              final clinicCode = clinic.getStringValue('clinic_id');
              final isDeactivated = clinic.getBoolValue('is_deactivated');
              final verified = clinic.getBoolValue('verified');
              final status = clinic.getStringValue('status');
              final isPendingDeletion = status == 'pending_deletion';

              return Column(
                children: [
                  // Top App Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: SAColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name.isEmpty ? '(Incomplete Registration)' : name,
                                      style: context.textStyles.h4.copyWith(color: SAColors.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Code Chip
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: clinicCode));
                                      AppToast.show('Clinic code copied: $clinicCode');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: SAColors.card,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: SAColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            clinicCode.isEmpty ? 'NO CODE' : clinicCode,
                                            style: const TextStyle(color: SAColors.accentLight, fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.copy_rounded, color: SAColors.textHint, size: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                isPendingDeletion
                                    ? '⏳ Pending Deletion'
                                    : isDeactivated
                                        ? '⊘ Deactivated'
                                        : (verified ? '✓ Active & Verified' : '⚠ Pending Verification'),
                                style: context.textStyles.caption.copyWith(
                                  color: isPendingDeletion || isDeactivated ? SAColors.warning : SAColors.success,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Quick Action Menu
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: SAColors.textSecondary),
                          color: SAColors.card,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            if (val == 'pw') _resetPassword('clinic', clinic.id, name);
                            if (val == 'deact') _deactivateClinic(name);
                            if (val == 'react') _reactivateClinic();
                            if (val == 'delete') _permanentlyDeleteClinic(name);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'pw', child: Text('Reset Clinic Password', style: TextStyle(color: SAColors.textPrimary))),
                            if (!isDeactivated && !isPendingDeletion)
                              const PopupMenuItem(value: 'deact', child: Text('Deactivate Clinic', style: TextStyle(color: SAColors.warning)))
                            else
                              const PopupMenuItem(value: 'react', child: Text('Reactivate Clinic', style: TextStyle(color: SAColors.success))),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'delete', child: Text('Permanently Delete', style: TextStyle(color: SAColors.error))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tab Bar (5 Tabs)
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: SAColors.border, width: 0.8)),
                    ),
                    child: TabBar(
                      controller: _tabCtrl,
                      isScrollable: true,
                      indicatorColor: SAColors.accent,
                      indicatorWeight: 3,
                      labelColor: SAColors.accentLight,
                      unselectedLabelColor: SAColors.textHint,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(icon: Icon(Icons.stars_rounded, size: 18), text: 'Plan & Quotas'),
                        Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Patients'),
                        Tab(icon: Icon(Icons.medical_information_rounded, size: 18), text: 'Consultations'),
                        Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Treatment & Sessions'),
                        Tab(icon: Icon(Icons.badge_rounded, size: 18), text: 'Staff Accounts'),
                      ],
                    ),
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabCtrl,
                      children: [
                        // Tab 1: Subscription & Quota Editor
                        _buildSubscriptionTab(clinic),
                        // Tab 2: Patients (Read & Write)
                        _buildPatientsTab(),
                        // Tab 3: Consultations (Read & Write)
                        _buildConsultationsTab(),
                        // Tab 4: Treatment Plans & Sessions (Read & Write)
                        _buildTreatmentSessionsTab(),
                        // Tab 5: Staff (Doctors & Receptionists)
                        _buildStaffTab(doctors, receptionists),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 1: Subscription & Quotas Editor
  // ══════════════════════════════════════════════════════════════
  Widget _buildSubscriptionTab(RecordModel clinic) {
    final photosUsed = clinic.getIntValue('photos_used', 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subscription Tier', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['base', 'starter', 'pro', 'enterprise', 'custom'].map((tier) {
                  final isSel = _selectedTier.toLowerCase() == tier;
                  return ChoiceChip(
                    label: Text(tier.toUpperCase()),
                    selected: isSel,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTier = tier);
                    },
                    selectedColor: SAColors.accent.withValues(alpha: 0.25),
                    backgroundColor: SAColors.card,
                    labelStyle: TextStyle(
                      color: isSel ? SAColors.accentLight : SAColors.textSecondary,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(color: isSel ? SAColors.accent : SAColors.border),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Text('Subscription Status', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['active', 'trialing', 'past_due', 'expired', 'canceled'].map((st) {
                  final isSel = _selectedStatus == st;
                  return ChoiceChip(
                    label: Text(st.replaceAll('_', ' ').toUpperCase()),
                    selected: isSel,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedStatus = st);
                    },
                    selectedColor: (st == 'active' ? SAColors.success : (st == 'expired' || st == 'canceled' ? SAColors.error : SAColors.warning)).withValues(alpha: 0.25),
                    backgroundColor: SAColors.card,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : SAColors.textSecondary,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(color: isSel ? (st == 'active' ? SAColors.success : SAColors.accent) : SAColors.border),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Text('Plan Expiration Period', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SAColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: SAColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_note_rounded, color: SAColors.accentLight, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _selectedEndDate != null
                              ? 'Expires on: ${DateFormat('dd MMMM yyyy').format(_selectedEndDate!)}'
                              : 'No Expiry (Lifetime / Unlimited)',
                          style: const TextStyle(color: SAColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedEndDate ?? now.add(const Duration(days: 30)),
                              firstDate: now.subtract(const Duration(days: 365)),
                              lastDate: now.add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setState(() => _selectedEndDate = picked);
                            }
                          },
                          child: const Text('Pick Date', style: TextStyle(color: SAColors.accentLight)),
                        ),
                      ],
                    ),
                    const Divider(color: SAColors.border, height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _presetDateBtn('+14 Days Trial', const Duration(days: 14)),
                        _presetDateBtn('+1 Month', const Duration(days: 30)),
                        _presetDateBtn('+3 Months', const Duration(days: 90)),
                        _presetDateBtn('+1 Year', const Duration(days: 365)),
                        OutlinedButton(
                          onPressed: () => setState(() => _selectedEndDate = null),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: SAColors.textSecondary,
                            side: const BorderSide(color: SAColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Clear / Lifetime'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Photo Quota Limit', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
                        const SizedBox(height: 6),
                        _darkTextField(_photoLimitCtrl, 'e.g. 2000', Icons.photo_library_outlined, isNumber: true),
                        const SizedBox(height: 4),
                        Text('Photos used so far: $photosUsed', style: const TextStyle(color: SAColors.textHint, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bed Count', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
                        const SizedBox(height: 6),
                        _darkTextField(_bedCountCtrl, 'e.g. 10', Icons.bed_outlined, isNumber: true),
                        const SizedBox(height: 4),
                        const Text('Total clinical beds', style: TextStyle(color: SAColors.textHint, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSavingSub ? null : _saveSubscription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SAColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSavingSub
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Plan & Quota Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetDateBtn(String label, Duration duration) {
    return ElevatedButton(
      onPressed: () => setState(() => _selectedEndDate = DateTime.now().add(duration)),
      style: ElevatedButton.styleFrom(
        backgroundColor: SAColors.surface,
        foregroundColor: SAColors.accentLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 2: Patients Inspector (Read & Write)
  // ══════════════════════════════════════════════════════════════
  Widget _buildPatientsTab() {
    final patientsAsync = ref.watch(_clinicPatientsProvider((widget.clinicId, _patientSearch)));

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: SAColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SAColors.border),
            ),
            child: TextField(
              controller: _patientSearchCtrl,
              style: const TextStyle(color: SAColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search patients by name, phone, ID...',
                hintStyle: const TextStyle(color: SAColors.textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: SAColors.textHint, size: 18),
                suffixIcon: _patientSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: SAColors.textHint, size: 16),
                        onPressed: () {
                          _patientSearchCtrl.clear();
                          setState(() => _patientSearch = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _patientSearch = v),
            ),
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            color: SAColors.accent,
            backgroundColor: SAColors.card,
            onRefresh: () async => ref.invalidate(_clinicPatientsProvider((widget.clinicId, _patientSearch))),
            child: patientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: SAColors.accent)),
              error: (e, _) => Center(child: Text('Error: ${ErrorFormatter.format(e)}', style: const TextStyle(color: SAColors.error))),
              data: (resultList) {
                final patients = resultList.items;
                if (patients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline_rounded, color: SAColors.textHint, size: 40),
                        const SizedBox(height: 8),
                        Text('No patients found', style: TextStyle(color: SAColors.textHint)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: patients.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final p = patients[i];
                    final name = p.getStringValue('full_name').isNotEmpty
                        ? p.getStringValue('full_name')
                        : p.getStringValue('name');
                    final phone = p.getStringValue('phone');
                    final pId = p.getStringValue('patient_id');
                    final age = p.getIntValue('age', 0);
                    final gender = p.getStringValue('gender');
                    final blood = p.getStringValue('blood_group');
                    final created = DateTime.tryParse(p.getStringValue('created'));

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SAColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SAColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_rounded, color: Color(0xFF38BDF8), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(name.isEmpty ? 'Unnamed' : name, style: const TextStyle(color: SAColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                                    const SizedBox(width: 6),
                                    if (pId.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(color: SAColors.surface, borderRadius: BorderRadius.circular(4)),
                                        child: Text(pId, style: const TextStyle(color: SAColors.accentLight, fontSize: 10, fontWeight: FontWeight.w700)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  [if (phone.isNotEmpty) phone, if (age > 0) '$age yrs', if (gender.isNotEmpty) gender, if (blood.isNotEmpty) 'Blood: $blood'].join(' · '),
                                  style: const TextStyle(color: SAColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (created != null)
                            Text(DateFormat('dd MMM yyyy').format(created), style: const TextStyle(color: SAColors.textHint, fontSize: 10)),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: SAColors.accentLight, size: 18),
                            onPressed: () => _showEditPatientDialog(p),
                            tooltip: 'Edit Patient',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: SAColors.error, size: 18),
                            onPressed: () => _deletePatient(p),
                            tooltip: 'Delete Patient',
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 3: Consultations Inspector (Read & Write)
  // ══════════════════════════════════════════════════════════════
  Widget _buildConsultationsTab() {
    final consultsAsync = ref.watch(_clinicConsultationsProvider((widget.clinicId, _consultationSearch)));

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: SAColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SAColors.border),
            ),
            child: TextField(
              controller: _consultationSearchCtrl,
              style: const TextStyle(color: SAColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search consultations by complaints or diagnosis...',
                hintStyle: const TextStyle(color: SAColors.textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: SAColors.textHint, size: 18),
                suffixIcon: _consultationSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: SAColors.textHint, size: 16),
                        onPressed: () {
                          _consultationSearchCtrl.clear();
                          setState(() => _consultationSearch = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _consultationSearch = v),
            ),
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            color: SAColors.accent,
            backgroundColor: SAColors.card,
            onRefresh: () async => ref.invalidate(_clinicConsultationsProvider((widget.clinicId, _consultationSearch))),
            child: consultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: SAColors.accent)),
              error: (e, _) => Center(child: Text('Error: ${ErrorFormatter.format(e)}', style: const TextStyle(color: SAColors.error))),
              data: (resultList) {
                final consults = resultList.items;
                if (consults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.medical_information_outlined, color: SAColors.textHint, size: 40),
                        const SizedBox(height: 8),
                        Text('No consultations logged', style: TextStyle(color: SAColors.textHint)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: consults.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final c = consults[i];
                    final dateStr = c.getStringValue('created');
                    final dt = DateTime.tryParse(dateStr);
                    final complaints = c.getStringValue('chief_complaint').isNotEmpty
                        ? c.getStringValue('chief_complaint')
                        : c.getStringValue('chief_complaints');
                    final diagnosis = c.getStringValue('acupuncture_diagnosis').isNotEmpty
                        ? c.getStringValue('acupuncture_diagnosis')
                        : c.getStringValue('diagnosis');

                    final patientName = _getExpandedName(c, 'patient', 'Patient');
                    final doctorName = _getExpandedName(c, 'doctor', 'Doctor');

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SAColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: SAColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Dr. $doctorName', style: const TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(patientName, style: const TextStyle(color: SAColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              if (dt != null)
                                Text(DateFormat('dd MMM yyyy · hh:mm a').format(dt), style: const TextStyle(color: SAColors.textHint, fontSize: 11)),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: SAColors.error, size: 16),
                                onPressed: () => _deleteConsultation(c),
                                tooltip: 'Delete Consultation',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (complaints.isNotEmpty)
                            Text('Complaints: $complaints', style: const TextStyle(color: SAColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (diagnosis.isNotEmpty)
                            Text('Diagnosis: $diagnosis', style: const TextStyle(color: SAColors.accentLight, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 4: Treatment Plans & Sessions (Read & Write)
  // ══════════════════════════════════════════════════════════════
  Widget _buildTreatmentSessionsTab() {
    final plansAsync = ref.watch(_clinicPlansProvider(widget.clinicId));
    final sessionsAsync = ref.watch(_clinicSessionsProvider(widget.clinicId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Treatment Plans
          Text('Treatment Plans', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 8),
          plansAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: SAColors.accent))),
            error: (e, _) => Text('Error loading plans: ${ErrorFormatter.format(e)}', style: const TextStyle(color: SAColors.error, fontSize: 12)),
            data: (plansResult) {
              final plans = plansResult.items;
              if (plans.isEmpty) return const Text('No treatment plans created', style: TextStyle(color: SAColors.textHint, fontSize: 12));

              return Column(
                children: plans.map((p) {
                  final patientName = _getExpandedName(p, 'patient', 'Patient');
                  final doctorName = _getExpandedName(p, 'doctor', 'Doctor');
                  final planType = p.getStringValue('treatment_type').isNotEmpty
                      ? p.getStringValue('treatment_type')
                      : (p.getStringValue('diagnosis').isNotEmpty ? p.getStringValue('diagnosis') : 'Treatment Plan');
                  final totalSessions = p.getIntValue('total_sessions', 0);
                  final completedSessions = p.getIntValue('completed_sessions', 0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SAColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SAColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.playlist_add_check_circle_rounded, color: Color(0xFFEC4899), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$patientName (Dr. $doctorName)', style: const TextStyle(color: SAColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(planType, style: const TextStyle(color: SAColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: SAColors.surface, borderRadius: BorderRadius.circular(6)),
                          child: Text('$completedSessions / $totalSessions Sessions', style: const TextStyle(color: SAColors.accentLight, fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // Section: Sessions
          Text('All Treatment Sessions', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 8),
          sessionsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: SAColors.accent))),
            error: (e, _) => Text('Error loading sessions: ${ErrorFormatter.format(e)}', style: const TextStyle(color: SAColors.error, fontSize: 12)),
            data: (sessionsResult) {
              final sessions = sessionsResult.items;
              if (sessions.isEmpty) return const Text('No treatment sessions logged', style: TextStyle(color: SAColors.textHint, fontSize: 12));

              return Column(
                children: sessions.map((s) {
                  final sNum = s.getIntValue('session_number', 0);
                  final sDate = s.getStringValue('scheduled_date');
                  final sTime = s.getStringValue('scheduled_time');
                  final status = s.getStringValue('status');
                  final patientName = _getExpandedName(s, 'patient', 'Patient');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SAColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SAColors.border),
                    ),
                    child: Row(
                      children: [
                        Text('Session #$sNum', style: const TextStyle(color: SAColors.accentLight, fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(patientName, style: const TextStyle(color: SAColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('$sDate ${sTime.isNotEmpty ? '· $sTime' : ''}', style: const TextStyle(color: SAColors.textHint, fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (status == 'completed' ? SAColors.success : SAColors.warning).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'completed' ? SAColors.success : SAColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: SAColors.error, size: 16),
                          onPressed: () => _deleteSession(s),
                          tooltip: 'Delete Session',
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 5: Staff (Doctors & Receptionists)
  // ══════════════════════════════════════════════════════════════
  Widget _buildStaffTab(List<RecordModel> doctors, List<RecordModel> receptionists) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Doctors (${doctors.length})', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 8),
          if (doctors.isEmpty)
            const Text('No doctor accounts registered', style: TextStyle(color: SAColors.textHint, fontSize: 12))
          else
            ...doctors.map((d) => _staffCard(d, 'doctor')),
          const SizedBox(height: 24),
          Text('Receptionists (${receptionists.length})', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 8),
          if (receptionists.isEmpty)
            const Text('No receptionist accounts registered', style: TextStyle(color: SAColors.textHint, fontSize: 12))
          else
            ...receptionists.map((r) => _staffCard(r, 'receptionist')),
        ],
      ),
    );
  }

  Widget _staffCard(RecordModel staff, String role) {
    final name = staff.getStringValue('name');
    final email = staff.getStringValue('email');
    final phone = staff.getStringValue('phone');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SAColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SAColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (role == 'doctor' ? const Color(0xFF06B6D4) : SAColors.success).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              role == 'doctor' ? Icons.medical_services_rounded : Icons.person_rounded,
              color: role == 'doctor' ? const Color(0xFF06B6D4) : SAColors.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Unnamed $role' : name, style: const TextStyle(color: SAColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Text([if (email.isNotEmpty) email, if (phone.isNotEmpty) phone].join(' · '), style: const TextStyle(color: SAColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.lock_reset_rounded, size: 15, color: SAColors.accentLight),
            label: const Text('Reset PW', style: TextStyle(color: SAColors.accentLight, fontSize: 11)),
            onPressed: () => _resetPassword(role, staff.id, name),
          ),
        ],
      ),
    );
  }

  // ── Common Dark UI Helpers ──────────────────────────────────
  Widget _darkTextField(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false, bool isNumber = false}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: SAColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SAColors.border),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: SAColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: SAColors.textHint, fontSize: 13),
          prefixIcon: Icon(icon, color: SAColors.textHint, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
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
    return AlertDialog(
      backgroundColor: SAColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: context.textStyles.h4.copyWith(color: SAColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty) ...[
            Text(subtitle, style: context.textStyles.bodyMedium.copyWith(color: SAColors.textSecondary)),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Cancel', style: TextStyle(color: SAColors.textHint))),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}


