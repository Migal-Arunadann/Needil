import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';

import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/services/clinic_deletion_service.dart';
import 'package:pms_app/features/settings/screens/edit_profile_screen.dart';
import 'package:pms_app/features/settings/screens/edit_doctor_details_screen.dart';
import 'package:pms_app/features/settings/screens/notifications_screen.dart';
import 'package:pms_app/features/settings/screens/privacy_security_screen.dart';
import 'package:pms_app/features/settings/screens/about_screen.dart';
import 'package:pms_app/features/settings/screens/manage_doctors_screen.dart';
import 'package:pms_app/features/settings/screens/manage_receptionist_screen.dart';
import 'package:pms_app/features/settings/screens/manage_photos_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/theme/theme_provider.dart';
import 'package:pms_app/core/widgets/responsive_wrapper.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

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
    final secGap  = d ? 40.0 : 24.0;
    final itemGap = d ? 12.0 : 10.0;
    final smGap   = d ? 8.0  : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isClinic) ...[
          _sectionHeader('Clinic Details', Icons.business_rounded),
          SizedBox(height: itemGap),
          _buildClinicDetailsCard(),
          SizedBox(height: itemGap),
          _buildManagePhotosTile(),
          SizedBox(height: secGap),

          _sectionHeader('Staff Management', Icons.manage_accounts_rounded),
          SizedBox(height: itemGap),
          _settingsNavTile(
            icon: Icons.medical_services_rounded,
            iconColor: context.colors.primary,
            title: 'Manage Doctors',
            subtitle: 'View schedules, set restrictions, reset passwords',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageDoctorsScreen())),
          ),
          SizedBox(height: smGap),
          _settingsNavTile(
            icon: Icons.support_agent_rounded,
            iconColor: context.colors.info,
            title: 'Manage Receptionist',
            subtitle: 'Edit details, toggle access, reset passwords',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageReceptionistScreen())),
          ),
          SizedBox(height: secGap),

        ] else if (auth.role == UserRole.doctor) ...[
          _sectionHeader('Personal Details', Icons.person_outline_rounded),
          SizedBox(height: itemGap),
          _buildDoctorDetailsCard(),
          SizedBox(height: secGap),

          _sectionHeader('My Clinic', Icons.business_rounded),
          SizedBox(height: itemGap),
          _buildDoctorClinicInfo(),
          SizedBox(height: secGap),
        ] else if (auth.role == UserRole.receptionist) ...[
          _sectionHeader('Staff Details', Icons.support_agent_rounded),
          SizedBox(height: itemGap),
          _buildReceptionistDetailsCard(),
          SizedBox(height: secGap),
        ],

        _sectionHeader('Settings', Icons.tune_rounded),
        SizedBox(height: itemGap),
        _settingsNavTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Manage notification preferences',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        ),
        SizedBox(height: smGap),
        if (!kIsWeb) ...[
          _settingsNavTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: 'Choose system default, light or dark mode',
            onTap: () => _showThemePicker(context),
          ),
          SizedBox(height: smGap),
        ],
        _settingsNavTile(
          icon: Icons.lock_outline_rounded,
          title: 'Privacy & Security',
          subtitle: 'Update password and security settings',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen())),
        ),
        SizedBox(height: smGap),
        _settingsNavTile(
          icon: Icons.info_outline_rounded,
          title: 'About',
          subtitle: 'App version and legal information',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
        ),
        SizedBox(height: secGap),

        if (auth.role == UserRole.clinic) ...[
          _sectionHeader('Account Management', Icons.manage_accounts_rounded),
          SizedBox(height: itemGap),
          _dangerTile(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Clinic Account',
            subtitle: 'Begin the 30-day deletion process for this clinic account.',
            onTap: _showDeleteClinicDialog,
          ),
          SizedBox(height: secGap),
        ],

        _sectionHeader('Session', Icons.shield_rounded),
        SizedBox(height: itemGap),
        _dangerTile(
          icon: Icons.logout_rounded,
          title: 'Sign Out',
          subtitle: 'You will need to log in again to access your account.',
          onTap: _confirmSignOut,
        ),
        SizedBox(height: d ? 80 : 40),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ══════════════════════════════════════════════════════════
    //  MOBILE LAYOUT
    // ══════════════════════════════════════════════════════════
    if (!isDesktop) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: ResponsiveWrapper(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Page title ──
                  Text('Profile', style: context.textStyles.h2),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your account and settings',
                    style: context.textStyles.caption,
                  ),
                  const SizedBox(height: 28),

                  // ── Mobile Hero ──
                  _buildMobileHero(isClinic, auth),
                  const SizedBox(height: 16),

                  // ── Completion bar ──
                  _buildCompletionBar(isClinic),
                  const SizedBox(height: 28),

                  // ── Settings ──
                  _buildSettingsRightColumn(context, auth, isClinic),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ══════════════════════════════════════════════════════════
    //  DESKTOP LAYOUT — Premium 2-column with ambient bg
    // ══════════════════════════════════════════════════════════
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // ── Ambient orbs (only in dark mode) ──
          if (isDark) ...[
            Positioned(
              top: -200,
              right: -120,
              child: _ambientOrb(
                size: 600,
                color: context.colors.primary.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              bottom: -260,
              left: -160,
              child: _ambientOrb(
                size: 700,
                color: context.colors.primaryDark.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              top: screenH * 0.35,
              left: screenW * 0.40,
              child: _ambientOrb(
                size: 450,
                color: context.colors.accent.withValues(alpha: 0.03),
              ),
            ),
          ],

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
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Profile', style: context.textStyles.h1),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Manage your account and clinic settings',
                                    style: context.textStyles.bodyMedium.copyWith(
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // ── 2-column layout ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── LEFT: Profile sidebar (sticky feel, 340px) ──
                            SizedBox(
                              width: 340,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildWebHeroCard(isClinic, auth, isDark),
                                  const SizedBox(height: 16),
                                  _buildCompletionBar(isClinic),
                                  const SizedBox(height: 16),
                                  _buildWebAccountMeta(isClinic, auth),
                                ],
                              ),
                            ),
                            const SizedBox(width: 36),

                            // ── RIGHT: Settings sections ──
                            Expanded(
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
  //  WEB HERO CARD — Banner + Avatar overlap (Linear-style)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildWebHeroCard(bool isClinic, AuthState auth, bool isDark) {
    final name = _nameFor(isClinic, auth);
    final username = _usernameFor(isClinic, auth);
    final email = isClinic ? (auth.clinic?.email ?? '') : (auth.doctor?.email ?? '');
    final role = _roleFor(isClinic, auth);
    final isVerified = isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false);
    final imageUrl = isClinic ? auth.clinic?.logoUrl : auth.doctor?.photoUrl;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner Solid Background ──
          Container(
            height: 88,
            color: context.colors.cardBackgroundAlt,
          ),

          // ── Avatar + edit row (avatar overlaps banner) ──
          Transform.translate(
            offset: const Offset(0, -36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Avatar with crisp flat border
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: context.colors.border,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.shadowColor.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        image: imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(ImageHelper.getSecureUrl(imageUrl)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageUrl == null
                          ? Icon(
                              isClinic ? Icons.business_rounded : Icons.medical_services_rounded,
                              color: context.colors.textSecondary,
                              size: 32,
                            )
                          : null,
                    ),
                  ),
                  // Edit button — sits at bottom of the avatar row
                  _HoverButton(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                      if (mounted) setState(() {});
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: context.colors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          'Edit',
                          style: context.textStyles.labelSmall.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Name, username, email — offset upward to fill avatar gap ──
          Transform.translate(
            offset: const Offset(0, -24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: context.textStyles.h3,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        '@$username',
                        style: context.textStyles.caption,
                      ),
                      const SizedBox(width: 8),
                      _VerifiedChip(
                        isVerified: isVerified,
                        onTap: isVerified ? null : _requestVerification,
                      ),
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, size: 12, color: context.colors.textHint),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            email,
                            style: context.textStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Role chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.colors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.colors.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  WEB ACCOUNT META — Plan and bed count below hero
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildWebAccountMeta(bool isClinic, AuthState auth) {
    if (!isClinic) return const SizedBox.shrink();
    final clinic = auth.clinic;
    final plan = (clinic?.subscriptionTier ?? 'base').toUpperCase();
    final beds = clinic?.bedCount ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetaStat(
              icon: Icons.workspace_premium_rounded,
              label: 'Plan',
              value: plan,
              color: plan == 'FREE'
                  ? context.colors.textSecondary
                  : context.colors.accent,
            ),
          ),
          Container(
            width: 1,
            height: 32,
            color: context.colors.divider,
          ),
          Expanded(
            child: _MetaStat(
              icon: Icons.bed_rounded,
              label: 'Beds',
              value: '$beds',
              color: context.colors.info,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MOBILE HERO CARD — Centered identity card
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildMobileHero(bool isClinic, AuthState auth) {
    final name = _nameFor(isClinic, auth);
    final username = _usernameFor(isClinic, auth);
    final email = isClinic ? (auth.clinic?.email ?? '') : (auth.doctor?.email ?? '');
    final role = _roleFor(isClinic, auth);
    final isVerified = isClinic ? (auth.clinic?.verified ?? false) : (auth.doctor?.verified ?? false);
    final imageUrl = isClinic ? auth.clinic?.logoUrl : auth.doctor?.photoUrl;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Banner
          Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.primary,
                  context.colors.primaryLight,
                  context.colors.accentLight.withValues(alpha: 0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          // Content below banner
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                // Avatar overlapping banner
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.colors.cardBackground,
                            width: 3,
                          ),
                          image: imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(ImageHelper.getSecureUrl(imageUrl)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: imageUrl == null
                            ? Icon(
                                isClinic ? Icons.business_rounded : Icons.medical_services_rounded,
                                color: context.colors.textSecondary,
                                size: 26,
                              )
                            : null,
                      ),
                      const Spacer(),
                      // Edit button
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                          if (mounted) setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined, size: 13, color: context.colors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Name / username / email row (pull up to fill avatar gap)
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: context.textStyles.h3,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _VerifiedChip(
                            isVerified: isVerified,
                            onTap: isVerified ? null : _requestVerification,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('@$username', style: context.textStyles.caption),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.email_outlined, size: 12, color: context.colors.textHint),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                email,
                                style: context.textStyles.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.colors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.colors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PROFILE COMPLETION BAR — Linear progress (replaces circular dial)
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildCompletionBar(bool isClinic) {
    final fields = isClinic ? _clinicProfileFields() : _doctorProfileFields();
    final pct = _profileCompletion(fields);
    final completed = fields.values.where((v) => v).length;
    final total = fields.length;
    final missing = fields.entries.where((e) => !e.value).toList();
    final isComplete = pct >= 1.0;
    final barColor = isComplete
        ? context.colors.success
        : pct > 0.6
            ? context.colors.primary
            : context.colors.warning;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
        if (mounted) setState(() {});
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isComplete
                  ? context.colors.success.withValues(alpha: 0.25)
                  : context.colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isComplete ? 'Profile Complete' : 'Complete Your Profile',
                      style: context.textStyles.label,
                    ),
                  ),
                  Text(
                    '$completed / $total',
                    style: context.textStyles.labelSmall.copyWith(color: barColor),
                  ),
                  if (isComplete) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle_rounded, size: 14, color: context.colors.success),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: context.colors.border,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
              // Missing fields chips
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: missing
                      .take(4)
                      .map((e) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: context.colors.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.colors.warning.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              e.key,
                              style: context.textStyles.caption.copyWith(
                                color: context.colors.warning,
                                fontSize: 10,
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
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CLINIC DETAILS CARD
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildClinicDetailsCard() {
    final clinic = ref.read(authProvider).clinic;
    return _infoCard([
      _infoRow('Clinic Name', clinic?.name ?? '—'),
      _infoRow('Username',    clinic?.username ?? '—'),
      _infoRow('Email',       clinic?.email?.isNotEmpty == true ? clinic!.email! : 'Not set'),
      _infoRow('Clinic ID',   clinic?.clinicId ?? '—', copyable: true),
      _infoRow('Bed Count',   '${clinic?.bedCount ?? 0}'),
      _infoRow('Plan',        (clinic?.subscriptionTier ?? 'base').toUpperCase()),
    ]);
  }

  // ════════════════════════════════════════════════════════════════════════
  //  MANAGE PHOTOS TILE
  // ════════════════════════════════════════════════════════════════════════

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

    return _settingsNavTile(
      icon: Icons.photo_library_rounded,
      iconColor: progressColor,
      title: 'Manage Photos',
      subtitle: '$used / $limit photos used',
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePhotosScreen()));
        if (mounted) setState(() {});
      },
      trailing: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          width: 60,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: context.colors.border,
            valueColor: AlwaysStoppedAnimation(progressColor),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DOCTOR: Personal Details
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildDoctorDetailsCard() {
    final doctor = ref.read(authProvider).doctor;
    return Column(
      children: [
        _infoCard([
          _infoRow('Name',     doctor?.name ?? '—'),
          _infoRow('Username', doctor?.username ?? '—'),
          if (doctor?.email != null && doctor!.email!.isNotEmpty)
            _infoRow('Email', doctor.email!),
          _infoRow('Age', '${doctor?.age ?? '—'}'),
        ]),
        const SizedBox(height: 10),
        _settingsNavTile(
          icon: Icons.schedule_rounded,
          iconColor: context.colors.primary,
          title: 'Edit Schedule & Treatments',
          subtitle: 'Availability, session timings, fees',
          onTap: () async {
            final doctorId = ref.read(authProvider).userId;
            if (doctorId == null) return;
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => EditDoctorDetailsScreen(doctorId: doctorId)),
            );
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DOCTOR: My Clinic (read-only)
  // ════════════════════════════════════════════════════════════════════════

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
            Icon(Icons.info_outline_rounded, color: context.colors.textHint, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your account is managed by a clinic. Contact your clinic administrator for details.',
                style: context.textStyles.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: context.colors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Associated with a clinic',
                  style: context.textStyles.label.copyWith(color: context.colors.success),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your account is managed by the clinic owner.',
                  style: context.textStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  RECEPTIONIST: Details Card
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildReceptionistDetailsCard() {
    final receptionist = ref.read(authProvider).receptionist;
    return _infoCard([
      _infoRow('Name',     receptionist?.name ?? '—'),
      _infoRow('Username', receptionist?.username ?? '—'),
      _infoRow('Staff ID', receptionist?.receptionistId ?? '—'),
      _infoRow('Role',     'Receptionist'),
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
  //  DELETE CLINIC DIALOG
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _showDeleteClinicDialog() async {
    final auth = ref.read(authProvider);
    final clinic = auth.clinic;
    if (clinic == null) return;

    if (clinic.isPendingDeletion) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: context.colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Already Scheduled For Deletion',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 16)),
          content: Text(
            'Your clinic is already scheduled for deletion on '
            '${clinic.purgeAt?.toLocal().toString().substring(0, 10) ?? 'soon'}. '
            'Use "Request Reactivation" from the banner to cancel.',
            style: TextStyle(color: context.colors.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: context.colors.textSecondary)),
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
          backgroundColor: context.colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.delete_forever_rounded, color: context.colors.error, size: 22),
            const SizedBox(width: 10),
            Text('Delete Clinic Account',
                style: TextStyle(color: context.colors.error, fontSize: 16)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Deleting your clinic account will disable all access to Needil '
                    'and begin a 30-day deletion period.\n\n'
                    'After 30 days, all patient records, consultations, sessions, '
                    'treatment plans, staff accounts, and clinic data will be '
                    'permanently deleted.\n\n'
                    'This action cannot be reversed after the 30-day period ends.',
                    style: TextStyle(
                        color: context.colors.textSecondary, fontSize: 12, height: 1.6),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Confirm your password',
                    style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: TextStyle(color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Current password',
                    hintStyle: TextStyle(color: context.colors.textMuted),
                    filled: true,
                    fillColor: context.colors.border.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.colors.error),
                    ),
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: context.colors.textMuted, size: 18),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Type DELETE MY CLINIC to confirm',
                    style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmTextCtrl,
                  style: TextStyle(color: context.colors.textPrimary, letterSpacing: 1.2),
                  decoration: InputDecoration(
                    hintText: 'DELETE MY CLINIC',
                    hintStyle: TextStyle(color: context.colors.textMuted),
                    filled: true,
                    fillColor: context.colors.border.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: context.colors.error),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Checkbox(
                    value: checkboxChecked,
                    activeColor: context.colors.error,
                    onChanged: (v) =>
                        setDialogState(() => checkboxChecked = v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I understand my clinic data will be permanently deleted after 30 days.',
                        style: TextStyle(
                            color: context.colors.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ),
                  ),
                ]),
                if (errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.colors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(errorMsg!,
                        style: TextStyle(color: context.colors.error, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.colors.textMuted)),
            ),
            ElevatedButton(
              onPressed: (isSubmitting ||
                      confirmTextCtrl.text != 'DELETE MY CLINIC' ||
                      !checkboxChecked)
                  ? null
                  : () async {
                      if (passwordCtrl.text.trim().isEmpty) {
                        setDialogState(() => errorMsg = 'Please enter your password.');
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorMsg = null;
                      });
                      final pb = ref.read(pocketbaseProvider);
                      final svc = ClinicDeletionService(pb);
                      final messenger = ScaffoldMessenger.of(context);
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
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text(
                                '⚠ Clinic deletion scheduled. '
                                'You have 30 days to request reactivation.'),
                            backgroundColor: context.colors.warning,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 6),
                          ),
                        );
                        ref.read(authProvider.notifier).logout();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: Colors.white,
                disabledBackgroundColor: context.colors.error.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.colors.textOnPrimary))
                  : const Text('Delete My Clinic'),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SIGN OUT
  // ════════════════════════════════════════════════════════════════════════

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
            Text('Sign Out', style: TextStyle(color: context.colors.textPrimary)),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out? You will need to log in again to access your account.',
          style: TextStyle(color: context.colors.textSecondary, height: 1.5),
        ),
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
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
  //  SHARED WIDGET BUILDERS
  // ════════════════════════════════════════════════════════════════════════

  Widget _sectionHeader(String title, IconData icon) {
    if (_isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: context.colors.textMuted),
            const SizedBox(width: 7),
            Text(
              title.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(height: 1, color: context.colors.divider),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.primary),
        const SizedBox(width: 6),
        Text(title, style: context.textStyles.h4.copyWith(color: context.colors.primary)),
      ],
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value, {bool copyable = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _isDesktop ? 120 : 90,
            child: Text(
              label,
              style: context.textStyles.caption,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textStyles.bodySmall.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
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
                  decoration: BoxDecoration(
                    color: context.colors.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(Icons.copy_rounded, size: 13, color: context.colors.textHint),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Unified nav tile (replaces _staffManagementTile + _settingsTile)
  Widget _settingsNavTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    final color = iconColor ?? context.colors.primary;

    if (_isDesktop) {
      return _HoverTile(
        onTap: onTap,
        child: Row(
          children: [
            // Icon — no circle bg, just tinted icon
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.label),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.textStyles.caption),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing,
            ],
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textMuted),
          ],
        ),
      );
    }

    // Mobile
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: context.colors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.label),
                  const SizedBox(height: 1),
                  Text(subtitle, style: context.textStyles.caption),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _dangerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    if (_isDesktop) {
      return _HoverTile(
        onTap: onTap,
        hoverBorderColor: context.colors.error.withValues(alpha: 0.25),
        child: Row(
          children: [
            Icon(icon, color: context.colors.error, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.label.copyWith(color: context.colors.error)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.textStyles.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.error.withValues(alpha: 0.5)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: context.colors.error, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.label.copyWith(color: context.colors.error)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: context.textStyles.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.error.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──
  String _nameFor(bool isClinic, AuthState auth) {
    if (isClinic) return auth.clinic?.name ?? 'Clinic';
    if (auth.role == UserRole.receptionist) return auth.receptionist?.name ?? 'Receptionist';
    return auth.doctor?.name ?? 'Doctor';
  }

  String _usernameFor(bool isClinic, AuthState auth) {
    if (isClinic) return auth.clinic?.username ?? '';
    if (auth.role == UserRole.receptionist) return auth.receptionist?.username ?? '';
    return auth.doctor?.username ?? '';
  }

  String _roleFor(bool isClinic, AuthState auth) {
    if (isClinic) return 'Clinic Account';
    if (auth.role == UserRole.receptionist) return 'Staff Account';
    return 'Doctor Account';
  }

  Widget _ambientOrb({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HOVER TILE — Web interactive row with smooth hover state
// ════════════════════════════════════════════════════════════════════════════

class _HoverTile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? hoverBorderColor;

  const _HoverTile({
    required this.child,
    this.onTap,
    this.hoverBorderColor,
  });

  @override
  State<_HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<_HoverTile> {
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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: _hovered
                ? context.colors.cardBackgroundAlt
                : context.colors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered
                  ? (widget.hoverBorderColor ?? context.colors.primary.withValues(alpha: 0.2))
                  : context.colors.border,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HOVER BUTTON — small inline button
// ════════════════════════════════════════════════════════════════════════════

class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _HoverButton({required this.child, this.onTap});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? context.colors.cardBackgroundAlt
                : context.colors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.border),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  VERIFIED CHIP — inline verified / verify-email badge
// ════════════════════════════════════════════════════════════════════════════

class _VerifiedChip extends StatelessWidget {
  final bool isVerified;
  final VoidCallback? onTap;

  const _VerifiedChip({required this.isVerified, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isVerified ? context.colors.success : context.colors.warning;
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVerified ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 11,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                isVerified ? 'Verified' : 'Verify',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final pulse = isDark
            ? 0.15 + (_ctrl.value * 0.10)  // subtler in dark
            : 0.08 + (_ctrl.value * 0.06); // very subtle in light
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius + 4),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: pulse),
                blurRadius: 20 + (_ctrl.value * 6),
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
//  META STAT — small stat display in web account meta card
// ════════════════════════════════════════════════════════════════════════════

class _MetaStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetaStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.textStyles.caption),
              Text(value,
                  style: context.textStyles.label.copyWith(color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
