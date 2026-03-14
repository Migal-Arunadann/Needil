import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'edit_doctor_details_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isJoining = false;
  bool _isSaving = false;
  final _clinicIdCtrl = TextEditingController();

  // Data sharing preferences (doctor only)
  late bool _sharePast;
  late bool _shareFuture;

  // Managed doctors list (clinic only)
  List<Map<String, dynamic>> _managedDoctors = [];
  bool _loadingDoctors = false;

  @override
  void initState() {
    super.initState();
    final doctor = ref.read(authProvider).doctor;
    _sharePast = doctor?.sharePastPatients ?? false;
    _shareFuture = doctor?.shareFuturePatients ?? false;

    final auth = ref.read(authProvider);
    if (auth.role == UserRole.clinic) {
      _loadManagedDoctors();
    }
  }

  @override
  void dispose() {
    _clinicIdCtrl.dispose();
    super.dispose();
  }

  // ── Load doctors managed by this clinic ─────────────────────
  Future<void> _loadManagedDoctors() async {
    setState(() => _loadingDoctors = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);
      final result = await pb.collection(PBCollections.doctors).getList(
        filter: 'clinic = "${auth.userId}"',
        sort: '-is_primary,name',
      );
      setState(() {
        _managedDoctors = result.items.map((r) => {
          'id': r.id,
          'name': r.getStringValue('name'),
          'username': r.getStringValue('username'),
          'email': r.getStringValue('email'),
          'age': r.getIntValue('age'),
          'is_primary': r.getBoolValue('is_primary'),
        }).toList();
        _loadingDoctors = false;
      });
    } catch (e) {
      setState(() => _loadingDoctors = false);
    }
  }

  // ── Doctor-only: Join Clinic ────────────────────────────────
  Future<void> _joinClinic() async {
    final clinicCode = _clinicIdCtrl.text.trim();
    if (clinicCode.isEmpty) {
      _showError('Please enter a Clinic ID');
      return;
    }

    setState(() => _isJoining = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);

      final clinics = await pb.collection(PBCollections.clinics).getList(
        filter: 'clinic_id = "$clinicCode"',
      );
      if (clinics.items.isEmpty) {
        _showError('No clinic found with ID: $clinicCode');
        setState(() => _isJoining = false);
        return;
      }
      final clinicRecord = clinics.items.first;
      await pb.collection(PBCollections.doctors).update(
        auth.userId!,
        body: {'clinic': clinicRecord.id},
      );

      if (mounted) {
        _showSuccess('Joined ${clinicRecord.getStringValue('name')}!');
        _clinicIdCtrl.clear();
        ref.read(authProvider.notifier).restoreSession();
      }
    } catch (e) {
      _showError('Failed to join clinic: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _leaveClinic() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Clinic?'),
        content: const Text(
            'You will no longer be associated with this clinic. Your patient data sharing settings will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final pb = ref.read(pocketbaseProvider);
        final auth = ref.read(authProvider);
        await pb.collection(PBCollections.doctors).update(auth.userId!, body: {'clinic': ''});
        if (mounted) {
          _showSuccess('Left clinic');
          ref.read(authProvider.notifier).restoreSession();
        }
      } catch (e) {
        _showError('Failed: $e');
      }
    }
  }

  Future<void> _saveSharingPrefs() async {
    setState(() => _isSaving = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);
      await pb.collection(PBCollections.doctors).update(auth.userId!, body: {
        'share_past_patients': _sharePast,
        'share_future_patients': _shareFuture,
      });
      if (mounted) {
        _showSuccess('Sharing preferences saved');
        ref.read(authProvider.notifier).restoreSession();
      }
    } catch (e) {
      _showError('Failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showComingSoon(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Profile completion ──────────────────────────────────────
  Map<String, bool> _clinicProfileFields() {
    final clinic = ref.read(authProvider).clinic;
    return {
      'Clinic Name': clinic?.name.isNotEmpty ?? false,
      'Username': clinic?.username.isNotEmpty ?? false,
      'Email': clinic?.email?.isNotEmpty ?? false,
      'Bed Count': (clinic?.bedCount ?? 0) > 0,
      'Clinic ID': clinic?.clinicId.isNotEmpty ?? false,
    };
  }

  Map<String, bool> _doctorProfileFields() {
    final doctor = ref.read(authProvider).doctor;
    return {
      'Name': doctor?.name.isNotEmpty ?? false,
      'Username': doctor?.username.isNotEmpty ?? false,
      'Email': doctor?.email?.isNotEmpty ?? false,
      'Age': (doctor?.age ?? 0) > 0,
      'Clinic Association': doctor?.clinicId?.isNotEmpty ?? false,
    };
  }

  double _profileCompletion(Map<String, bool> fields) {
    if (fields.isEmpty) return 0;
    final completed = fields.values.where((v) => v).length;
    return completed / fields.length;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isClinic = auth.role == UserRole.clinic;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  const SizedBox(width: 14),
                  Text('Profile', style: AppTextStyles.h2),
                ],
              ),
              const SizedBox(height: 24),

              // ── Profile Card (Hero) ──
              _buildProfileHero(isClinic),
              const SizedBox(height: 24),

              // ── Profile Completion ──
              _buildProfileCompletion(isClinic),
              const SizedBox(height: 24),

              if (isClinic) ...[
                // ═══════════════════════════════════════════
                //  CLINIC ACCOUNT SECTIONS
                // ═══════════════════════════════════════════

                // ── Clinic Details ──
                _sectionHeader('Clinic Details', Icons.business_rounded),
                const SizedBox(height: 10),
                _buildClinicDetailsCard(),
                const SizedBox(height: 24),

                // ── Primary Doctor ──
                _sectionHeader('Primary Doctor (Owner)', Icons.admin_panel_settings_rounded),
                const SizedBox(height: 10),
                _buildPrimaryDoctorCard(),
                const SizedBox(height: 24),

                // ── Managed Doctors ──
                _sectionHeader('Managed Doctors', Icons.group_rounded),
                const SizedBox(height: 6),
                Text(
                  'Doctors who have joined your clinic. You can view and manage their details.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 10),
                _buildManagedDoctorsList(),
                const SizedBox(height: 24),
              ] else ...[
                // ═══════════════════════════════════════════
                //  DOCTOR ACCOUNT SECTIONS
                // ═══════════════════════════════════════════

                // ── Personal Details ──
                _sectionHeader('Personal Details', Icons.person_outline_rounded),
                const SizedBox(height: 10),
                _buildDoctorDetailsCard(),
                const SizedBox(height: 24),

                // ── Clinic Association ──
                _sectionHeader('Clinic', Icons.business_rounded),
                const SizedBox(height: 10),
                _buildClinicAssociation(),
                const SizedBox(height: 24),

                // ── Data Sharing (doctor in clinic only) ──
                if (auth.doctor?.clinicId != null &&
                    auth.doctor!.clinicId!.isNotEmpty) ...[
                  _sectionHeader('Data Sharing', Icons.share_rounded),
                  const SizedBox(height: 6),
                  Text(
                    'Control what patient data the clinic can access.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 10),
                  _buildDataSharing(),
                  const SizedBox(height: 24),
                ],
              ],

              // ── General Settings ──
              _sectionHeader('Settings', Icons.tune_rounded),
              const SizedBox(height: 10),
              _settingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Manage notification preferences',
                onTap: () => _showComingSoon('Notifications settings coming soon!'),
              ),
              const SizedBox(height: 8),
              _settingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Privacy & Security',
                subtitle: 'Update password and security settings',
                onTap: () => _showComingSoon('Privacy settings coming soon!'),
              ),
              const SizedBox(height: 8),
              _settingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                subtitle: 'App version and legal information',
                onTap: () => _showComingSoon('About section coming soon!'),
              ),
              const SizedBox(height: 24),

              // ── Account / Sign Out ──
              _sectionHeader('Account', Icons.shield_rounded),
              const SizedBox(height: 10),
              AppButton(
                label: 'Sign Out',
                isOutlined: true,
                icon: Icons.logout_rounded,
                onPressed: _confirmSignOut,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HERO PROFILE CARD
  // ════════════════════════════════════════════════════════════

  Widget _buildProfileHero(bool isClinic) {
    final auth = ref.read(authProvider);
    final name = isClinic ? (auth.clinic?.name ?? 'Clinic') : ('Dr. ${auth.doctor?.name ?? 'Doctor'}');
    final username = isClinic ? (auth.clinic?.username ?? '') : (auth.doctor?.username ?? '');
    final email = isClinic ? (auth.clinic?.email ?? '') : (auth.doctor?.email ?? '');
    final role = isClinic ? 'Clinic Account' : 'Doctor Account';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isClinic ? Icons.business_rounded : Icons.medical_services_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.h3.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 12, color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          email,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // VERIFICATION BADGE/BUTTON
                      GestureDetector(
                        onTap: () {
                          final isVerified = isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false);
                          if (!isVerified) _requestVerification();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false))
                                ? AppColors.success.withValues(alpha: 0.2)
                                : AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false))
                                  ? AppColors.success.withValues(alpha: 0.5)
                                  : AppColors.warning.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false))
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                size: 10,
                                color: (isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false))
                                    ? AppColors.success : AppColors.warning,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                (isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false))
                                    ? 'Verified' : 'Verify Email',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 9,
                                  color: (isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false))
                                      ? AppColors.success : AppColors.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
              // Refresh after edit
              if (mounted) {
                setState(() {});
                if (ref.read(authProvider).role == UserRole.clinic) {
                  _loadManagedDoctors();
                }
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  CLINIC ACCOUNT: Clinic Details Card
  // ════════════════════════════════════════════════════════════

  Widget _buildClinicDetailsCard() {
    final clinic = ref.read(authProvider).clinic;
    return _infoCard([
      _infoRow('Clinic Name', clinic?.name ?? '—'),
      _infoRow('Username', clinic?.username ?? '—'),
      _infoRow('Email', clinic?.email?.isNotEmpty == true ? clinic!.email! : 'Not set'),
      _infoRow('Clinic ID', clinic?.clinicId ?? '—', copyable: true),
      _infoRow('Bed Count', '${clinic?.bedCount ?? 0}'),
    ]);
  }

  // ════════════════════════════════════════════════════════════
  //  CLINIC ACCOUNT: Primary Doctor Card
  // ════════════════════════════════════════════════════════════

  Widget _buildPrimaryDoctorCard() {
    // The primary doctor is the one with is_primary = true
    final primaryDoc = _managedDoctors.where((d) => d['is_primary'] == true).toList();

    if (_loadingDoctors) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    if (primaryDoc.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No primary doctor found. The clinic owner should be registered as the primary doctor.',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning),
              ),
            ),
          ],
        ),
      );
    }

    final doc = primaryDoc.first;
    return _doctorDetailCard(doc, isPrimary: true);
  }

  // ════════════════════════════════════════════════════════════
  //  CLINIC ACCOUNT: Managed Doctors List
  // ════════════════════════════════════════════════════════════

  Widget _buildManagedDoctorsList() {
    if (_loadingDoctors) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    final joinedDoctors = _managedDoctors.where((d) => d['is_primary'] != true).toList();

    if (joinedDoctors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.group_add_rounded, size: 40, color: AppColors.textHint),
            const SizedBox(height: 10),
            Text(
              'No doctors have joined yet',
              style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Share your Clinic ID with doctors so they can request to join.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _clinicIdShareChip(),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...joinedDoctors.map((doc) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _doctorDetailCard(doc, isPrimary: false),
        )),
        const SizedBox(height: 4),
        _clinicIdShareChip(),
      ],
    );
  }

  Widget _clinicIdShareChip() {
    final clinicId = ref.read(authProvider).clinic?.clinicId ?? '';
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: clinicId));
        _showSuccess('Clinic ID copied: $clinicId');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.share_rounded, size: 14, color: AppColors.info),
            const SizedBox(width: 6),
            Text(
              'Clinic ID: $clinicId',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.copy_rounded, size: 13, color: AppColors.info),
          ],
        ),
      ),
    );
  }

  // ── Doctor Detail Card (used by both primary and managed) ──

  Widget _doctorDetailCard(Map<String, dynamic> doc, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: isPrimary ? AppColors.heroGradient : null,
                  color: isPrimary ? null : AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPrimary ? Icons.star_rounded : Icons.person_rounded,
                  color: isPrimary ? Colors.white : AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Dr. ${doc['name'] ?? 'Unknown'}',
                            style: AppTextStyles.label.copyWith(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrimary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'OWNER',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '@${doc['username'] ?? ''}',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _openDoctorEditScreen(doc),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniInfoChip(Icons.cake_outlined, 'Age: ${doc['age'] ?? '—'}'),
              const SizedBox(width: 10),
              Expanded(
                child: _miniInfoChip(
                  Icons.email_outlined,
                  (doc['email'] ?? '').toString().isNotEmpty ? doc['email'] : 'No email',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Clinic: Navigate to full doctor edit screen ─────────────

  Future<void> _openDoctorEditScreen(Map<String, dynamic> doc) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditDoctorDetailsScreen(doctorId: doc['id'] as String),
      ),
    );
    if (refreshed == true && mounted) {
      _loadManagedDoctors();
      ref.read(authProvider.notifier).restoreSession();
    }
  }

  // ════════════════════════════════════════════════════════════
  //  DOCTOR ACCOUNT: Personal Details Card
  // ════════════════════════════════════════════════════════════

  Widget _buildDoctorDetailsCard() {
    final doctor = ref.read(authProvider).doctor;
    return Column(
      children: [
        _infoCard([
          _infoRow('Name', 'Dr. ${doctor?.name ?? '—'}'),
          _infoRow('Username', doctor?.username ?? '—'),
          if (doctor?.email != null && doctor!.email!.isNotEmpty)
            _infoRow('Email', doctor.email!),
          _infoRow('Age', '${doctor?.age ?? '—'}'),
        ]),
        const SizedBox(height: 10),
        // Full details edit — schedule, treatments
        GestureDetector(
          onTap: () async {
            final doctorId = ref.read(authProvider).userId;
            if (doctorId == null) return;
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => EditDoctorDetailsScreen(doctorId: doctorId),
              ),
            );
            if (mounted) setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule_rounded, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Schedule & Treatments', style: AppTextStyles.label.copyWith(fontSize: 14)),
                      Text(
                        'Availability, session timings, fees',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  DOCTOR ACCOUNT: Clinic Association
  // ════════════════════════════════════════════════════════════

  Widget _buildClinicAssociation() {
    final doctor = ref.read(authProvider).doctor;
    final isInClinic = doctor?.clinicId != null && doctor!.clinicId!.isNotEmpty;

    if (isInClinic) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Part of a clinic', style: AppTextStyles.label.copyWith(color: AppColors.success)),
                  Text('Clinic ID: ${doctor.clinicId}', style: AppTextStyles.caption),
                ],
              ),
            ),
            GestureDetector(
              onTap: _leaveClinic,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Leave', style: AppTextStyles.caption.copyWith(color: AppColors.error)),
              ),
            ),
          ],
        ),
      );
    }

    // Not in a clinic — show Join form
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Join a Clinic', style: AppTextStyles.label.copyWith(color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('Enter the Clinic ID provided by your clinic administrator.', style: AppTextStyles.caption),
          const SizedBox(height: 12),
          AppTextField(
            controller: _clinicIdCtrl,
            label: 'Clinic ID',
            hint: 'e.g. CL-XXXXXX',
            prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Join Clinic',
            isLoading: _isJoining,
            icon: Icons.link_rounded,
            onPressed: _joinClinic,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  DOCTOR ACCOUNT: Data Sharing
  // ════════════════════════════════════════════════════════════

  Widget _buildDataSharing() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _sharingToggle(
                title: 'Share Past Patients',
                subtitle: 'Allow clinic to view patients you treated before joining',
                value: _sharePast,
                icon: Icons.history_rounded,
                onChanged: (v) => setState(() => _sharePast = v),
              ),
              Divider(height: 1, color: AppColors.border),
              _sharingToggle(
                title: 'Share Future Patients',
                subtitle: 'Allow clinic to view patients you treat after joining',
                value: _shareFuture,
                icon: Icons.upcoming_rounded,
                onChanged: (v) => setState(() => _shareFuture = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'Save Sharing Preferences',
          isLoading: _isSaving,
          icon: Icons.save_rounded,
          onPressed: _saveSharingPrefs,
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  VERIFY EMAIL
  // ════════════════════════════════════════════════════════════

  Future<void> _requestVerification() async {
    final auth = ref.read(authProvider);
    final email = auth.role == UserRole.clinic ? auth.clinic?.email : auth.doctor?.email;
    
    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email configured to verify.')));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sending verification email...'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 1),
        ),
      );
    }

    try {
      final pb = ref.read(pocketbaseProvider);
      final collection = auth.role == UserRole.clinic ? PBCollections.clinics : PBCollections.doctors;
      await pb.collection(collection).requestVerification(email);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent to $email! Please check your inbox.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════
  //  SIGN OUT
  // ════════════════════════════════════════════════════════════

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            const SizedBox(width: 10),
            const Text('Sign Out'),
          ],
        ),
        content: const Text(
            'Are you sure you want to sign out? You will need to log in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref.read(authProvider.notifier).logout();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  PROFILE COMPLETION BADGE
  // ════════════════════════════════════════════════════════════

  Widget _buildProfileCompletion(bool isClinic) {
    final fields = isClinic ? _clinicProfileFields() : _doctorProfileFields();
    final pct = _profileCompletion(fields);
    final pctInt = (pct * 100).round();
    final missing = fields.entries.where((e) => !e.value).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: pct >= 1.0
            ? LinearGradient(colors: [
                AppColors.success.withValues(alpha: 0.08),
                AppColors.success.withValues(alpha: 0.02),
              ])
            : LinearGradient(colors: [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.accent.withValues(alpha: 0.04),
              ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pct >= 1.0
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 5,
                      backgroundColor: AppColors.border,
                      color: pct >= 1.0 ? AppColors.success : AppColors.primary,
                    ),
                    Text(
                      '$pctInt%',
                      style: AppTextStyles.label.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: pct >= 1.0 ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pct >= 1.0 ? 'Profile Complete! 🎉' : 'Complete Your Profile',
                      style: AppTextStyles.label.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pct >= 1.0
                          ? 'All required information is filled in.'
                          : '${missing.length} field${missing.length > 1 ? "s" : ""} remaining',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing
                  .map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          e.key,
                          style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontSize: 11),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(title, style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
      ],
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSuccess('Copied: $value');
              },
              child: Icon(Icons.copy_rounded, size: 16, color: AppColors.textHint),
            ),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.label.copyWith(fontSize: 14)),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _sharingToggle({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label.copyWith(fontSize: 13)),
                Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
