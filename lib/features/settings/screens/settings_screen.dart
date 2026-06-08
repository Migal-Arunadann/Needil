import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/clinic_deletion_service.dart';
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
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS v2 — Premium Futuristic SaaS (Linear / Vercel / Stripe)
// ════════════════════════════════════════════════════════════════════════════

// Background
const _kBg            = Color(0xFF04060F);     // deeper navy
const _kBgSurface     = Color(0xFF080D1C);     // elevated surface

// Card surfaces
const _kCardBg        = Color(0xFF0A1022);     // default card
const _kCardBgHover   = Color(0xFF0E1730);     // hover state
const _kCardBgElevated = Color(0xFF0C1428);    // elevated card

// Glass borders
const _kGlassBorder   = Color(0x0AFFFFFF);     // white ~4%
const _kGlassBorderH  = Color(0x18FFFFFF);     // white ~9%
const _kGlassBorderL  = Color(0x06FFFFFF);     // white ~2% — subtle

// Typography
const _kTx            = Color(0xFFE8ECF4);     // primary text — slightly brighter
const _kTxDim         = Color(0xFF8B9AB8);     // secondary text — softer blue
const _kTxMute        = Color(0xFF576580);     // hint text

// Accent palette
const _kAccent        = Color(0xFF3B82F6);     // blue
const _kAccentSoft    = Color(0xFF60A5FA);     // softer blue for highlights
const _kSuccess       = Color(0xFF10B981);
const _kWarning       = Color(0xFFF59E0B);
const _kError         = Color(0xFFEF4444);

// Radii
const _kR             = 24.0;                  // card radius
const _kHR            = 28.0;                  // hero radius
const _kTileR         = 20.0;                  // tile radius


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool get _isDesktop => MediaQuery.of(context).size.width >= 900;

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

  // ════════════════════════════════════════════════════════════════════════
  //  RIGHT COLUMN BUILDER
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildSettingsRightColumn(BuildContext context, AuthState auth, bool isClinic) {
    final d = _isDesktop;
    final secGap  = d ? 48.0 : 24.0;   // ↑ from 40
    final itemGap = d ? 16.0 : 10.0;   // ↑ from 14
    final smGap   = d ? 12.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isClinic) ...[
          // CLINIC ACCOUNT SECTIONS
          _sectionHeader('Clinic Details', Icons.business_rounded),
          SizedBox(height: itemGap),
          _buildClinicDetailsCard(),
          SizedBox(height: itemGap),

          // ── Manage Photos tile ──
          _buildManagePhotosTile(),
          SizedBox(height: secGap),

          _sectionHeader('Staff Management', Icons.manage_accounts_rounded),
          SizedBox(height: itemGap),

          // ── Manage Doctors button ──
          _staffManagementTile(
            icon: Icons.medical_services_rounded,
            iconColor: d ? _kAccent : context.colors.primary,
            title: 'Manage Doctors',
            subtitle: 'View schedules, set restrictions, reset passwords',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageDoctorsScreen()),
            ),
          ),
          SizedBox(height: itemGap),

          // ── Manage Receptionist button ──
          _staffManagementTile(
            icon: Icons.support_agent_rounded,
            iconColor: d ? const Color(0xFF38BDF8) : context.colors.info,
            title: 'Manage Receptionist',
            subtitle: 'Edit details, toggle access, reset passwords',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageReceptionistScreen()),
            ),
          ),
          SizedBox(height: secGap),

        ] else if (auth.role == UserRole.doctor) ...[
          // DOCTOR ACCOUNT SECTIONS
          _sectionHeader('Personal Details', Icons.person_outline_rounded),
          SizedBox(height: itemGap),
          _buildDoctorDetailsCard(),
          SizedBox(height: secGap),

          // Read-only clinic info
          _sectionHeader('My Clinic', Icons.business_rounded),
          SizedBox(height: itemGap),
          _buildDoctorClinicInfo(),
          SizedBox(height: secGap),
        ] else if (auth.role == UserRole.receptionist) ...[
          // RECEPTIONIST ACCOUNT SECTIONS
          _sectionHeader('Staff Details', Icons.support_agent_rounded),
          SizedBox(height: itemGap),
          _buildReceptionistDetailsCard(),
          SizedBox(height: secGap),
        ],

        // ── General Settings ──
        _sectionHeader('Settings', Icons.tune_rounded),
        SizedBox(height: itemGap),
        _settingsTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage notification preferences',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        SizedBox(height: smGap),
        _settingsTile(
          icon: Icons.palette_outlined,
          title: 'Theme',
          subtitle: 'Choose system default, light or dark mode',
          onTap: () => _showThemePicker(context),
        ),
        SizedBox(height: smGap),
        _settingsTile(
          icon: Icons.lock_outline_rounded,
          title: 'Privacy & Security',
          subtitle: 'Update password and security settings',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
          ),
        ),
        SizedBox(height: smGap),
        _settingsTile(
          icon: Icons.info_outline_rounded,
          title: 'About',
          subtitle: 'App version and legal information',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
        ),
        SizedBox(height: secGap),

        // ── Account Management (Clinic only) ─────────────────────────────
        if (auth.role == UserRole.clinic) ...[
          SizedBox(height: secGap),
          _sectionHeader('Account Management', Icons.manage_accounts_rounded),
          SizedBox(height: itemGap),
          // Delete clinic account tile
          GestureDetector(
            onTap: _showDeleteClinicDialog,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_forever_rounded,
                      color: Color(0xFFEF4444), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delete Clinic Account',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      'Begin the 30-day deletion process for this clinic account.',
                      style: TextStyle(
                        color: const Color(0xFFEF4444).withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                )),
                Icon(Icons.chevron_right_rounded,
                    color: const Color(0xFFEF4444).withOpacity(0.5), size: 20),
              ]),
            ),
          ),
        ],

        // ── Account / Sign Out ────────────────────────────────────────────────
        SizedBox(height: secGap),
        _sectionHeader('Account', Icons.shield_rounded),
        SizedBox(height: itemGap),
        if (d)
          _WebHoverGlassCard(
            onTap: _confirmSignOut,
            accentColor: _kError,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: _kError.withValues(alpha: 0.8), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    color: _kError.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          )
        else
          AppButton(
            label: 'Sign Out',
            isOutlined: true,
            icon: Icons.logout_rounded,
            onPressed: _confirmSignOut,
          ),
        SizedBox(height: d ? 80 : 40),   // ↑ from 60 — more bottom breathing room
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isClinic = auth.role == UserRole.clinic;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // ── Mobile: unchanged original layout ──
    if (!isDesktop) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: ResponsiveWrapper(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 14),
                      Text('Profile', style: context.textStyles.h2),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildProfileHero(isClinic),
                  const SizedBox(height: 24),
                  _buildProfileCompletion(isClinic),
                  const SizedBox(height: 24),
                  _buildSettingsRightColumn(context, auth, isClinic),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ════════════════════════════════════════════════════════════════════
    //  DESKTOP: Premium futuristic ambient background
    // ════════════════════════════════════════════════════════════════════
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Ambient orb: top-right — large soft blue ──
          Positioned(
            top: -240,
            right: -160,
            child: Container(
              width: 700,
              height: 700,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E40AF).withValues(alpha: 0.06),
                    const Color(0xFF1E3A8A).withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // ── Ambient orb: bottom-left — deep indigo ──
          Positioned(
            bottom: -280,
            left: -180,
            child: Container(
              width: 800,
              height: 800,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0D47A1).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // ── Ambient orb: center — very subtle accent ──
          Positioned(
            top: screenH * 0.35,
            left: screenW * 0.38,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.025),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // ── Vertical glow streak 1 ──
          Positioned(
            top: 0,
            left: screenW * 0.16,
            child: Container(
              width: 1,
              height: screenH,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF1E40AF).withValues(alpha: 0.05),
                    const Color(0xFF3B82F6).withValues(alpha: 0.025),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.25, 0.65, 1.0],
                ),
              ),
            ),
          ),
          // ── Vertical glow streak 2 ──
          Positioned(
            top: 100,
            right: screenW * 0.22,
            child: Container(
              width: 1,
              height: screenH * 0.45,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF3B82F6).withValues(alpha: 0.035),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // ── Vertical glow streak 3 — very faint ──
          Positioned(
            top: 200,
            left: screenW * 0.52,
            child: Container(
              width: 1,
              height: screenH * 0.35,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF60A5FA).withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Page header ──
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profile',
                                style: TextStyle(
                                  color: _kTx,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Manage your account and clinic settings',
                                style: TextStyle(
                                  color: _kTxDim,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 48),

                        // ── Two-column layout ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left column: Profile Card + Completion
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildProfileHero(isClinic),
                                  const SizedBox(height: 32),
                                  _buildProfileCompletion(isClinic),
                                ],
                              ),
                            ),
                            const SizedBox(width: 40),
                            // Right column: Settings Sections
                            Expanded(
                              flex: 7,
                              child: _buildSettingsRightColumn(context, auth, isClinic),
                            ),
                          ],
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
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HERO PROFILE CARD
  // ════════════════════════════════════════════════════════════════════════

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
    final isVerified = isClinic
        ? (auth.clinic?.verified ?? false)
        : (auth.doctor?.verified ?? false);
    final hasImage = (isClinic ? auth.clinic?.logoUrl : auth.doctor?.photoUrl) != null;

    // ═══════════════════════════════════════════════════════
    //  Desktop: premium glassmorphism hero with inner glow
    // ═══════════════════════════════════════════════════════
    if (_isDesktop) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kHR),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0D1F3C).withValues(alpha: 0.82),
                  const Color(0xFF081428).withValues(alpha: 0.65),
                  const Color(0xFF060E1F).withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(_kHR),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.07),
              ),
              boxShadow: [
                // Outer glow — brand accent
                BoxShadow(
                  color: const Color(0xFF1E40AF).withValues(alpha: 0.08),
                  blurRadius: 64,
                  spreadRadius: -8,
                  offset: const Offset(0, 20),
                ),
                // Depth shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                // ── Inner top-left highlight (frosted glass feel) ──
                Positioned(
                  top: -40,
                  left: -40,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Content ──
                Column(
                  children: [
                    Row(
                      children: [
                        // ── Avatar with animated glow ring ──
                        _AvatarGlowRing(
                          size: 88,
                          borderRadius: 26,
                          glowColor: _kAccent,
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 2,
                              ),
                              image: hasImage
                                  ? DecorationImage(
                                      image: NetworkImage(ImageHelper.getSecureUrl(isClinic
                                          ? auth.clinic!.logoUrl!
                                          : auth.doctor!.photoUrl!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: !hasImage
                                ? Icon(
                                    isClinic
                                        ? Icons.business_rounded
                                        : Icons.medical_services_rounded,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 38,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 28),
                        // ── Name / username / email / badges ──
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: _kTx,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '@$username',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.38),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Icon(Icons.email_outlined,
                                        size: 14,
                                        color: Colors.white.withValues(alpha: 0.28)),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        email,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.48),
                                          fontSize: 13,
                                          letterSpacing: -0.1,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // ── Glass verified / verify badge ──
                                    _GlassPillBadge(
                                      color: isVerified ? _kSuccess : _kWarning,
                                      icon: isVerified
                                          ? Icons.check_circle_rounded
                                          : Icons.warning_amber_rounded,
                                      label: isVerified ? 'Verified' : 'Verify Email',
                                      onTap: isVerified ? null : _requestVerification,
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              // ── Glass role pill ──
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── Glass edit button ──
                        _WebHoverGlassButton(
                          onTap: () async {
                            await Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                            if (mounted) setState(() {});
                          },
                          child: Icon(Icons.edit_rounded,
                              color: Colors.white.withValues(alpha: 0.55),
                              size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Mobile: original unchanged ──
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
                      image: NetworkImage(ImageHelper.getSecureUrl(isClinic ? auth.clinic!.logoUrl! : auth.doctor!.photoUrl!)),
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
                          if (!isVerified) _requestVerification();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? context.colors.success.withValues(alpha: 0.2)
                                : context.colors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isVerified
                                  ? context.colors.success.withValues(alpha: 0.5)
                                  : context.colors.warning.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVerified
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                size: 10,
                                color: isVerified
                                    ? context.colors.success : context.colors.warning,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isVerified ? 'Verified' : 'Verify Email',
                                style: context.textStyles.caption.copyWith(
                                  fontSize: 9,
                                  color: isVerified
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

  // ════════════════════════════════════════════════════════════════════════
  //  CLINIC ACCOUNT: Clinic Details Card
  // ════════════════════════════════════════════════════════════════════════

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

  // ════════════════════════════════════════════════════════════════════════
  //  CLINIC ACCOUNT: Manage Photos Tile
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildManagePhotosTile() {
    final clinic = ref.read(authProvider).clinic;
    final used = clinic?.photosUsed ?? 0;
    final limit = clinic?.photoLimit ?? 2000;
    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final progressColor = progress > 0.9
        ? (_isDesktop ? _kError : context.colors.error)
        : progress > 0.75
            ? (_isDesktop ? _kWarning : context.colors.warning)
            : (_isDesktop ? _kSuccess : context.colors.success);

    final onTap = () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ManagePhotosScreen()),
      );
      if (mounted) setState(() {}); // Refresh quota display
    };

    // ── Desktop: glass hover card ──
    if (_isDesktop) {
      return _WebHoverGlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: progressColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: progressColor.withValues(alpha: 0.12)),
              ),
              child: Icon(Icons.photo_library_rounded, color: progressColor, size: 22),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manage Photos',
                      style: TextStyle(
                        color: _kTx,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            valueColor: AlwaysStoppedAnimation(progressColor),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$used / $limit',
                        style: TextStyle(
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
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _kTxMute),
          ],
        ),
      );
    }

    // ── Mobile: unchanged ──
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


  // ════════════════════════════════════════════════════════════════════════
  //  CLINIC ACCOUNT: Staff Management Nav Tile
  // ════════════════════════════════════════════════════════════════════════

  Widget _staffManagementTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    // ── Desktop: glass hover card ──
    if (_isDesktop) {
      return _WebHoverGlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: iconColor.withValues(alpha: 0.12)),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: _kTx,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                        color: _kTxDim,
                        fontSize: 12,
                        letterSpacing: -0.1,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _kTxMute),
          ],
        ),
      );
    }

    // ── Mobile: unchanged ──
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

  // ════════════════════════════════════════════════════════════════════════
  //  DOCTOR ACCOUNT: Personal Details Card
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildDoctorDetailsCard() {
    final doctor = ref.read(authProvider).doctor;
    final d = _isDesktop;
    return Column(
      children: [
        _infoCard([
          _infoRow('Name', doctor?.name ?? '—'),
          _infoRow('Username', doctor?.username ?? '—'),
          if (doctor?.email != null && doctor!.email!.isNotEmpty)
            _infoRow('Email', doctor.email!),
          _infoRow('Age', '${doctor?.age ?? '—'}'),
        ]),
        SizedBox(height: d ? 16 : 10),
        // Full details edit — schedule, treatments
        d
            ? _WebHoverGlassCard(
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
                accentColor: _kAccent,
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: _kAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: _kAccent.withValues(alpha: 0.12)),
                      ),
                      child: const Icon(Icons.schedule_rounded, size: 20, color: _kAccent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Edit Schedule & Treatments',
                              style: TextStyle(color: _kTx, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1)),
                          const SizedBox(height: 3),
                          const Text('Availability, session timings, fees',
                              style: TextStyle(color: _kTxDim, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: _kAccent.withValues(alpha: 0.7)),
                  ],
                ),
              )
            : GestureDetector(
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

  // ════════════════════════════════════════════════════════════════════════
  //  DOCTOR ACCOUNT: My Clinic (read-only)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildDoctorClinicInfo() {
    final doctor = ref.read(authProvider).doctor;
    final isInClinic = doctor?.clinicId != null && doctor!.clinicId!.isNotEmpty;
    final d = _isDesktop;

    if (!isInClinic) {
      return Container(
        padding: EdgeInsets.all(d ? 22 : 16),
        decoration: BoxDecoration(
          color: d ? _kCardBg : context.colors.surface,
          borderRadius: BorderRadius.circular(d ? _kR : 14),
          border: Border.all(color: d ? _kGlassBorder : context.colors.border),
          boxShadow: d
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: d ? _kTxMute : context.colors.textHint, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your account is managed by a clinic. Contact your clinic administrator for details.',
                style: d
                    ? const TextStyle(color: _kTxDim, fontSize: 13, letterSpacing: -0.1)
                    : context.textStyles.caption.copyWith(color: context.colors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final clr = d ? _kSuccess : context.colors.success;
    return Container(
      padding: EdgeInsets.all(d ? 22 : 14),
      decoration: BoxDecoration(
        color: clr.withValues(alpha: d ? 0.05 : 0.06),
        borderRadius: BorderRadius.circular(d ? _kR : 14),
        border: Border.all(color: clr.withValues(alpha: 0.12)),
        boxShadow: d
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: clr.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(d ? 14 : 10),
              border: d ? Border.all(color: clr.withValues(alpha: 0.12)) : null,
            ),
            child: Icon(Icons.check_circle_rounded, color: clr, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Associated with a clinic',
                  style: d
                      ? TextStyle(color: _kSuccess, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1)
                      : context.textStyles.label.copyWith(color: context.colors.success),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your account is managed by the clinic owner.',
                  style: d
                      ? const TextStyle(color: _kTxDim, fontSize: 12, letterSpacing: -0.1)
                      : context.textStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RECEPTIONIST ACCOUNT: Details Card
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildReceptionistDetailsCard() {
    final receptionist = ref.read(authProvider).receptionist;
    return _infoCard([
      _infoRow('Name', receptionist?.name ?? '—'),
      _infoRow('Username', receptionist?.username ?? '—'),
      _infoRow('Staff ID', receptionist?.receptionistId ?? '—'),
      _infoRow('Role', 'Receptionist'),
    ]);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  VERIFY EMAIL
  // ════════════════════════════════════════════════════════════════════════

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

  // ════════════════════════════════════════════════════════════════════════
  //  SIGN OUT
  // ════════════════════════════════════════════════════════════════════════

  // ────────────────────────────────────────────────────────────────────────
  //  DELETE CLINIC DIALOG
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _showDeleteClinicDialog() async {
    final auth = ref.read(authProvider);
    final clinic = auth.clinic;
    if (clinic == null) return;

    // Guard: if already pending deletion, show info instead
    if (clinic.isPendingDeletion) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Already Scheduled For Deletion',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Text(
            'Your clinic is already scheduled for deletion on '
            '${clinic.purgeAt?.toLocal().toString().substring(0, 10) ?? 'soon'}. '
            'Use "Request Reactivation" from the banner to cancel.',
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.white70)),
            )
          ],
        ),
      );
      return;
    }

    final passwordCtrl = TextEditingController();
    final confirmTextCtrl = TextEditingController();
    bool checkboxChecked = false;
    bool isSubmitting = false;
    String? errorMsg;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A0A0A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444),
                size: 22),
            SizedBox(width: 10),
            Text('Delete Clinic Account',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 16)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Warning box ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Deleting your clinic account will disable all access to Needil '
                    'and begin a 30-day deletion period.\n\n'
                    'After 30 days, all patient records, consultations, sessions, '
                    'treatment plans, staff accounts, and clinic data will be '
                    'permanently deleted.\n\n'
                    'This action cannot be reversed after the 30-day period ends.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.6),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Password confirmation ────────────────────────────
                const Text('Confirm your password',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Current password',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFFEF4444)),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline_rounded,
                        color: Colors.white38, size: 18),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Type DELETE MY CLINIC ────────────────────────────
                const Text('Type DELETE MY CLINIC to confirm',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmTextCtrl,
                  style: const TextStyle(
                      color: Colors.white, letterSpacing: 1.2),
                  decoration: InputDecoration(
                    hintText: 'DELETE MY CLINIC',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFFEF4444)),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),

                // ── Checkbox ─────────────────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Checkbox(
                    value: checkboxChecked,
                    activeColor: const Color(0xFFEF4444),
                    onChanged: (v) =>
                        setDialogState(() => checkboxChecked = v ?? false),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'I understand my clinic data will be permanently deleted after 30 days.',
                        style: TextStyle(
                            color: Colors.white60, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
                ]),

                // ── Error message ────────────────────────────────────
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(errorMsg!,
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: (isSubmitting ||
                      confirmTextCtrl.text != 'DELETE MY CLINIC' ||
                      !checkboxChecked)
                  ? null
                  : () async {
                      if (passwordCtrl.text.trim().isEmpty) {
                        setDialogState(() =>
                            errorMsg = 'Please enter your password.');
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorMsg = null;
                      });
                      final pb = ref.read(pocketbaseProvider);
                      final svc = ClinicDeletionService(pb);
                      final err = await svc.requestDeletion(
                        clinicId: clinic.id,
                        username: clinic.username,
                        password: passwordCtrl.text.trim(),
                      );
                      if (!mounted) return;
                      if (err != null) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorMsg = err;
                        });
                      } else {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                '⚠ Clinic deletion scheduled. '
                                'You have 30 days to request reactivation.'),
                            backgroundColor: Color(0xFFF59E0B),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 6),
                          ),
                        );
                        // Refresh auth state so banner appears
                        ref.read(authProvider.notifier).logout();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFFEF4444).withOpacity(0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Delete My Clinic'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    // Desktop: use a premium glassmorphic dialog
    if (_isDesktop) {
      final confirm = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (ctx) => Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0F1729).withValues(alpha: 0.95),
                      const Color(0xFF0A1020).withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _kError.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kError.withValues(alpha: 0.12)),
                        ),
                        child: Icon(Icons.logout_rounded, color: _kError.withValues(alpha: 0.8), size: 26),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Sign Out',
                        style: TextStyle(
                          color: _kTx,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Are you sure you want to sign out?\nYou will need to log in again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _kTxDim,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: _WebHoverGlassButton(
                              height: 44,
                              borderRadius: 14,
                              onTap: () => Navigator.pop(ctx, false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: _kTxDim,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(ctx, true),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _kError.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _kError.withValues(alpha: 0.2)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      color: _kError.withValues(alpha: 0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      if (confirm == true && mounted) {
        ref.read(authProvider.notifier).logout();
      }
      return;
    }

    // Mobile: unchanged
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

  // ════════════════════════════════════════════════════════════════════════
  //  PROFILE COMPLETION BADGE
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildProfileCompletion(bool isClinic) {
    final fields = isClinic ? _clinicProfileFields() : _doctorProfileFields();
    final pct = _profileCompletion(fields);
    final pctInt = (pct * 100).round();
    final missing = fields.entries.where((e) => !e.value).toList();

    final onTap = () async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
      if (mounted) setState(() {});
    };

    // ── Desktop: glassmorphism completion card ──
    if (_isDesktop) {
      final accentClr = pct >= 1.0 ? _kSuccess : _kAccent;
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kR),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentClr.withValues(alpha: 0.05),
                      _kCardBg.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(_kR),
                  border: Border.all(
                    color: accentClr.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Progress ring with glow
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accentClr.withValues(alpha: 0.15),
                                blurRadius: 20,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: pct,
                                  strokeWidth: 5,
                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                  color: accentClr,
                                  strokeCap: StrokeCap.round,
                                ),
                                Text(
                                  '$pctInt%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: accentClr,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pct >= 1.0 ? 'Profile Complete! 🎉' : 'Complete Your Profile',
                                style: TextStyle(
                                  color: _kTx,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                pct >= 1.0
                                    ? 'All required information is filled in.'
                                    : '${missing.length} field${missing.length > 1 ? "s" : ""} remaining',
                                style: const TextStyle(color: _kTxDim, fontSize: 13, letterSpacing: -0.1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (missing.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          color: _kAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: missing
                            .map((e) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _kWarning.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _kWarning.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Text(
                                    e.key,
                                    style: TextStyle(
                                      color: _kWarning.withValues(alpha: 0.85),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ── Mobile: unchanged ──
    return GestureDetector(
      onTap: onTap,
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

  // ════════════════════════════════════════════════════════════════════════
  //  THEME PICKER
  // ════════════════════════════════════════════════════════════════════════

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

  // ════════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, IconData icon) {
    // ── Desktop: premium header with accent line & glowing icon ──
    if (_isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Row(
          children: [
            // Glowing icon container
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _kAccent.withValues(alpha: 0.08)),
              ),
              child: Icon(
                icon,
                size: 16,
                color: _kAccentSoft,
                shadows: [
                  Shadow(
                    color: _kAccent.withValues(alpha: 0.5),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: _kTx,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 16),
            // Accent divider line
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _kAccent.withValues(alpha: 0.12),
                      _kAccent.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile: unchanged ──
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.primary),
        const SizedBox(width: 6),
        Text(title, style: context.textStyles.h3.copyWith(color: context.colors.primary)),
      ],
    );
  }

  Widget _infoCard(List<Widget> children) {
    // ── Desktop: glassmorphism info card with backdrop blur ──
    if (_isDesktop) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kR),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
            decoration: BoxDecoration(
              color: _kCardBg.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(_kR),
              border: Border.all(color: _kGlassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ),
      );
    }

    // ── Mobile: unchanged ──
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
    final d = _isDesktop;
    return Container(
      padding: EdgeInsets.symmetric(vertical: d ? 10 : 4, horizontal: d ? 4 : 0),
      decoration: d
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.03)),
              ),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: d ? 130 : 90,
            child: Text(
              label,
              style: d
                  ? const TextStyle(color: _kTxMute, fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: -0.1)
                  : context.textStyles.caption,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: d
                  ? const TextStyle(color: _kTx, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1)
                  : context.textStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                _showSuccess('Copied: $value');
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: d
                      ? BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                        )
                      : null,
                  child: Icon(Icons.copy_rounded, size: 14,
                      color: d ? _kTxMute : context.colors.textHint),
                ),
              ),
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
    // ── Desktop: glass hover card ──
    if (_isDesktop) {
      return _WebHoverGlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _kAccent.withValues(alpha: 0.1)),
              ),
              child: Icon(icon, color: _kAccentSoft, size: 20),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: _kTx,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      )),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                        color: _kTxDim,
                        fontSize: 12,
                        letterSpacing: -0.1,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: _kTxMute.withValues(alpha: 0.6)),
          ],
        ),
      );
    }

    // ── Mobile: unchanged ──
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


// ════════════════════════════════════════════════════════════════════════════
//  GLASS PILL BADGE — translucent status pill with icon
// ════════════════════════════════════════════════════════════════════════════

class _GlassPillBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _GlassPillBadge({
    required this.color,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color.withValues(alpha: 0.85)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  AVATAR GLOW RING — soft animated glow ring around avatar
// ════════════════════════════════════════════════════════════════════════════

class _AvatarGlowRing extends StatefulWidget {
  final double size;
  final double borderRadius;
  final Color glowColor;
  final Widget child;

  const _AvatarGlowRing({
    required this.size,
    required this.borderRadius,
    required this.glowColor,
    required this.child,
  });

  @override
  State<_AvatarGlowRing> createState() => _AvatarGlowRingState();
}

class _AvatarGlowRingState extends State<_AvatarGlowRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final pulse = 0.18 + (_ctrl.value * 0.12); // 0.18 → 0.30
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius + 4),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: pulse),
                blurRadius: 24 + (_ctrl.value * 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  WEB HOVER GLASS BUTTON — smaller interactive glass element
// ════════════════════════════════════════════════════════════════════════════

class _WebHoverGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final double? width;
  final double borderRadius;

  const _WebHoverGlassButton({
    required this.child,
    this.onTap,
    this.height,
    this.width,
    this.borderRadius = 14,
  });

  @override
  State<_WebHoverGlassButton> createState() => _WebHoverGlassButtonState();
}

class _WebHoverGlassButtonState extends State<_WebHoverGlassButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: widget.height,
          width: widget.width ?? widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _hovered
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
//  WEB HOVER GLASS CARD v2 — premium interactive card with micro-animations
//  Features: hover lift, glow transition, subtle scale, smooth animation
// ════════════════════════════════════════════════════════════════════════════

class _WebHoverGlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? accentColor;

  const _WebHoverGlassCard({
    required this.child,
    this.onTap,
    this.borderRadius = _kTileR,
    this.padding = const EdgeInsets.all(22),
    this.accentColor,
  });

  @override
  State<_WebHoverGlassCard> createState() => _WebHoverGlassCardState();
}

class _WebHoverGlassCardState extends State<_WebHoverGlassCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onEnter() {
    setState(() => _hovered = true);
    _animCtrl.forward();
  }

  void _onExit() {
    setState(() => _hovered = false);
    _animCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? _kAccent;
    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, child) {
            final t = _anim.value;
            return Transform.translate(
              offset: Offset(0, -2.0 * t),
              child: Transform.scale(
                scale: 1.0 + (0.005 * t), // very subtle scale
                child: Container(
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: Color.lerp(_kCardBg, _kCardBgHover, t),
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(
                      color: Color.lerp(_kGlassBorder, _kGlassBorderH, t)!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.lerp(
                          Colors.black.withValues(alpha: 0.18),
                          accent.withValues(alpha: 0.1),
                          t,
                        )!,
                        blurRadius: lerpDouble(16, 32, t) ?? 16,
                        offset: Offset(0, lerpDouble(4, 10, t) ?? 4),
                      ),
                      // Subtle accent glow on hover
                      if (t > 0)
                        BoxShadow(
                          color: accent.withValues(alpha: 0.04 * t),
                          blurRadius: 48,
                          spreadRadius: -4,
                        ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}