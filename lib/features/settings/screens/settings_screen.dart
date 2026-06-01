import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import 'edit_profile_screen.dart';
import 'edit_doctor_details_screen.dart';
import 'notifications_screen.dart';
import 'privacy_security_screen.dart';
import 'about_screen.dart';
import 'manage_doctors_screen.dart';
import 'manage_receptionist_screen.dart';
import 'manage_photos_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/responsive_wrapper.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }



  // _showError is intentionally removed — validation errors are now shown
  // directly via ScaffoldMessenger.of(ctx) inside the bottom sheet to avoid
  // cross-context widget scope issues.

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: context.colors.success,
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
          backgroundColor: context.colors.primary,
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
      'Phone Number': clinic?.phone?.isNotEmpty ?? false,
      'Address': clinic?.address?.isNotEmpty ?? false,
      'Area': clinic?.area?.isNotEmpty ?? false,
      'City': clinic?.city?.isNotEmpty ?? false,
      'State': clinic?.state?.isNotEmpty ?? false,
      'PIN Code': clinic?.pin?.isNotEmpty ?? false,
      'Clinic GMap Link': clinic?.location?.isNotEmpty ?? false,
      'Logo': clinic?.logoUrl?.isNotEmpty ?? false,
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
      'Phone Number': doctor?.phone?.isNotEmpty ?? false,
      'Date of Birth': doctor?.dateOfBirth?.isNotEmpty ?? false,
      'Photo': doctor?.photoUrl?.isNotEmpty ?? false,
    };
  }

  double _profileCompletion(Map<String, bool> fields) {
    if (fields.isEmpty) return 0;
    final completed = fields.values.where((v) => v).length;
    return completed / fields.length;
  }

  Widget _buildSettingsRightColumn(BuildContext context, AuthState auth, bool isClinic) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isClinic) ...[
          // CLINIC ACCOUNT SECTIONS

          _sectionHeader('Clinic Details', Icons.business_rounded),
          const SizedBox(height: 10),
          _buildClinicDetailsCard(),
          const SizedBox(height: 10),

          // ── Manage Photos tile ──
          _buildManagePhotosTile(),
          const SizedBox(height: 24),

          _sectionHeader('Staff Management', Icons.manage_accounts_rounded),
          const SizedBox(height: 10),

          // ── Manage Doctors button ──
          _staffManagementTile(
            icon: Icons.medical_services_rounded,
            iconColor: context.colors.primary,
            title: 'Manage Doctors',
            subtitle: 'View schedules, set restrictions, reset passwords',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageDoctorsScreen()),
            ),
          ),
          const SizedBox(height: 10),

          // ── Manage Receptionist button ──
          _staffManagementTile(
            icon: Icons.support_agent_rounded,
            iconColor: context.colors.info,
            title: 'Manage Receptionist',
            subtitle: 'Edit details, toggle access, reset passwords',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageReceptionistScreen()),
            ),
          ),
          const SizedBox(height: 24),

        ] else if (auth.role == UserRole.doctor) ...[
          // DOCTOR ACCOUNT SECTIONS

          _sectionHeader('Personal Details', Icons.person_outline_rounded),
          const SizedBox(height: 10),
          _buildDoctorDetailsCard(),
          const SizedBox(height: 24),

          // Read-only clinic info
          _sectionHeader('My Clinic', Icons.business_rounded),
          const SizedBox(height: 10),
          _buildDoctorClinicInfo(),
          const SizedBox(height: 24),
        ] else if (auth.role == UserRole.receptionist) ...[
          // RECEPTIONIST ACCOUNT SECTIONS

          _sectionHeader('Staff Details', Icons.support_agent_rounded),
          const SizedBox(height: 10),
          _buildReceptionistDetailsCard(),
          const SizedBox(height: 24),
        ],

        // ── General Settings ──
        _sectionHeader('Settings', Icons.tune_rounded),
        const SizedBox(height: 10),
        _settingsTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage notification preferences',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        const SizedBox(height: 8),
        _settingsTile(
          icon: Icons.palette_outlined,
          title: 'Theme',
          subtitle: 'Choose system default, light or dark mode',
          onTap: () => _showThemePicker(context),
        ),
        const SizedBox(height: 8),
        _settingsTile(
          icon: Icons.lock_outline_rounded,
          title: 'Privacy & Security',
          subtitle: 'Update password and security settings',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
          ),
        ),
        const SizedBox(height: 8),
        _settingsTile(
          icon: Icons.info_outline_rounded,
          title: 'About',
          subtitle: 'App version and legal information',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isClinic = auth.role == UserRole.clinic;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: ResponsiveWrapper(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    const SizedBox(width: 14),
                    Text('Profile', style: context.textStyles.h2),
                  ],
                ),
                const SizedBox(height: 24),

                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Profile Card + Completion
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileHero(isClinic),
                            const SizedBox(height: 24),
                            _buildProfileCompletion(isClinic),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Settings Sections
                      Expanded(
                        flex: 3,
                        child: _buildSettingsRightColumn(context, auth, isClinic),
                      ),
                    ],
                  )
                else ...[
                  // Mobile: Stacks Vertically
                  _buildProfileHero(isClinic),
                  const SizedBox(height: 24),
                  _buildProfileCompletion(isClinic),
                  const SizedBox(height: 24),
                  _buildSettingsRightColumn(context, auth, isClinic),
                ],
              ],
            ),
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
    final isReceptionist = auth.role == UserRole.receptionist;
    final name = isClinic
        ? (auth.clinic?.name ?? 'Clinic')
        : isReceptionist
            ? (auth.receptionist?.name ?? 'Receptionist')
            : (auth.doctor?.name ?? 'Doctor');
    final username = isClinic
        ? (auth.clinic?.username ?? '')
        : isReceptionist
            ? (auth.receptionist?.username ?? '')
            : (auth.doctor?.username ?? '');
    final email = isClinic ? (auth.clinic?.email ?? '') : (auth.doctor?.email ?? '');
    final role = isClinic
        ? 'Clinic Account'
        : isReceptionist
            ? 'Staff Account'
            : 'Doctor Account';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: context.colors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.3),
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
              image: (isClinic ? auth.clinic?.logoUrl : auth.doctor?.photoUrl) != null
                  ? DecorationImage(
                      image: NetworkImage(isClinic ? auth.clinic!.logoUrl! : auth.doctor!.photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (isClinic ? auth.clinic?.logoUrl : auth.doctor?.photoUrl) == null
                ? Icon(
                    isClinic ? Icons.business_rounded : Icons.medical_services_rounded,
                    color: Colors.white,
                    size: 32,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: context.textStyles.h3.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: context.textStyles.caption.copyWith(
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
                          style: context.textStyles.caption.copyWith(
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
                                ? context.colors.success.withValues(alpha: 0.2)
                                : context.colors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false))
                                  ? context.colors.success.withValues(alpha: 0.5)
                                  : context.colors.warning.withValues(alpha: 0.5),
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
                                    ? context.colors.success : context.colors.warning,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                (isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false))
                                    ? 'Verified' : 'Verify Email',
                                style: context.textStyles.caption.copyWith(
                                  fontSize: 9,
                                  color: (isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false))
                                      ? context.colors.success : context.colors.warning,
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
                    style: context.textStyles.caption.copyWith(
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
              if (mounted) setState(() {});
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
      _infoRow('Plan', (clinic?.subscriptionTier ?? 'base').toUpperCase()),
    ]);
  }

  // ════════════════════════════════════════════════════════════
  //  CLINIC ACCOUNT: Manage Photos Tile
  // ════════════════════════════════════════════════════════════

  Widget _buildManagePhotosTile() {
    final clinic = ref.read(authProvider).clinic;
    final used = clinic?.photosUsed ?? 0;
    final limit = clinic?.photoLimit ?? 2000;
    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final progressColor = progress > 0.9
        ? context.colors.error
        : progress > 0.75
            ? context.colors.warning
            : context.colors.success;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManagePhotosScreen()),
        );
        if (mounted) setState(() {}); // Refresh quota display
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: progressColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.photo_library_rounded, color: progressColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manage Photos', style: context.textStyles.label.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: context.colors.border,
                            valueColor: AlwaysStoppedAnimation(progressColor),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$used / $limit',
                        style: context.textStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: progressColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }


  // ════════════════════════════════════════════════════════════
  //  CLINIC ACCOUNT: Staff Management Nav Tile
  // ════════════════════════════════════════════════════════════

  Widget _staffManagementTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
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
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  DOCTOR ACCOUNT: Personal Details Card
  // ════════════════════════════════════════════════════════════

  Widget _buildDoctorDetailsCard() {
    final doctor = ref.read(authProvider).doctor;
    return Column(
      children: [
        _infoCard([
          _infoRow('Name', doctor?.name ?? '—'),
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
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.schedule_rounded, size: 20, color: context.colors.primary),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Schedule & Treatments', style: context.textStyles.label.copyWith(fontSize: 14)),
                      Text(
                        'Availability, session timings, fees',
                        style: context.textStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: context.colors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  DOCTOR ACCOUNT: My Clinic (read-only)
  // ════════════════════════════════════════════════════════════

  Widget _buildDoctorClinicInfo() {
    final doctor = ref.read(authProvider).doctor;
    final isInClinic = doctor?.clinicId != null && doctor!.clinicId!.isNotEmpty;

    if (!isInClinic) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: context.colors.textHint, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your account is managed by a clinic. Contact your clinic administrator for details.',
                style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.check_circle_rounded, color: context.colors.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Associated with a clinic', style: context.textStyles.label.copyWith(color: context.colors.success)),
                const SizedBox(height: 2),
                Text(
                  'Your account is managed by the clinic owner.',
                  style: context.textStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  RECEPTIONIST ACCOUNT: Details Card
  // ════════════════════════════════════════════════════════════

  Widget _buildReceptionistDetailsCard() {
    final receptionist = ref.read(authProvider).receptionist;
    return _infoCard([
      _infoRow('Name', receptionist?.name ?? '—'),
      _infoRow('Username', receptionist?.username ?? '—'),
      _infoRow('Staff ID', receptionist?.receptionistId ?? '—'),
      _infoRow('Role', 'Receptionist'),
    ]);
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
          backgroundColor: context.colors.primary,
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
            backgroundColor: context.colors.success,
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
            backgroundColor: context.colors.error,
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
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: context.colors.error, size: 22),
            const SizedBox(width: 10),
            Text('Sign Out'),
          ],
        ),
        content: Text(
            'Are you sure you want to sign out? You will need to log in again to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: context.colors.error.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sign Out', style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref.read(authProvider.notifier).logout();
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

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
        if (mounted) setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: pct >= 1.0
            ? LinearGradient(colors: [
                context.colors.success.withValues(alpha: 0.08),
                context.colors.success.withValues(alpha: 0.02),
              ])
            : LinearGradient(colors: [
                context.colors.primary.withValues(alpha: 0.08),
                context.colors.accent.withValues(alpha: 0.04),
              ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pct >= 1.0
              ? context.colors.success.withValues(alpha: 0.2)
              : context.colors.primary.withValues(alpha: 0.15),
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
                      backgroundColor: context.colors.border,
                      color: pct >= 1.0 ? context.colors.success : context.colors.primary,
                    ),
                    Text(
                      '$pctInt%',
                      style: context.textStyles.label.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: pct >= 1.0 ? context.colors.success : context.colors.primary,
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
                      style: context.textStyles.label.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pct >= 1.0
                          ? 'All required information is filled in.'
                          : '${missing.length} field${missing.length > 1 ? "s" : ""} remaining',
                      style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
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
                backgroundColor: context.colors.border,
                color: context.colors.primary,
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
                          color: context.colors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          e.key,
                          style: context.textStyles.caption.copyWith(color: context.colors.warning, fontSize: 11),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    ));
  }

  // ════════════════════════════════════════════════════════════
  //  THEME PICKER
  // ════════════════════════════════════════════════════════════

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Theme', style: context.textStyles.h3),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final currentTheme = ref.watch(themeProvider);
                return Column(
                  children: [
                    _themeOptionTile(context, ref, ThemeMode.system, 'System Default', Icons.brightness_auto_rounded, currentTheme),
                    _themeOptionTile(context, ref, ThemeMode.light, 'Light', Icons.light_mode_rounded, currentTheme),
                    _themeOptionTile(context, ref, ThemeMode.dark, 'Dark', Icons.dark_mode_rounded, currentTheme),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOptionTile(BuildContext context, WidgetRef ref, ThemeMode mode, String label, IconData icon, ThemeMode currentTheme) {
    final isSelected = mode == currentTheme;
    return ListTile(
      leading: Icon(icon, color: isSelected ? context.colors.primary : context.colors.textHint),
      title: Text(label, style: context.textStyles.bodyMedium.copyWith(
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
        color: isSelected ? context.colors.primary : context.colors.textPrimary,
      )),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: context.colors.primary) : null,
      onTap: () {
        ref.read(themeProvider.notifier).setTheme(mode);
        Navigator.pop(context);
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.primary),
        const SizedBox(width: 6),
        Text(title, style: context.textStyles.h3.copyWith(color: context.colors.primary)),
      ],
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
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
            child: Text(label, style: context.textStyles.caption),
          ),
          Expanded(
            child: Text(value,
                style: context.textStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSuccess('Copied: $value');
              },
              child: Icon(Icons.copy_rounded, size: 16, color: context.colors.textHint),
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
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: context.colors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.label.copyWith(fontSize: 14)),
                  Text(subtitle, style: context.textStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }
}