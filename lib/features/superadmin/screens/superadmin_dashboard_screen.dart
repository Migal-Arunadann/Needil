import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/superadmin_service.dart';
import 'superadmin_shell.dart';
import 'superadmin_clinics_screen.dart';

final _dashStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchPlatformStats();
});

final _recentClinicsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchRecentClinics(limit: 8);
});

class SuperadminDashboardScreen extends ConsumerWidget {
  const SuperadminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_dashStatsProvider);
    final recentAsync = ref.watch(_recentClinicsProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: SAColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: SAColors.gradient),
        child: SafeArea(
          child: RefreshIndicator(
            color: SAColors.accent,
            backgroundColor: SAColors.card,
            onRefresh: () async {
              ref.invalidate(_dashStatsProvider);
              ref.invalidate(_recentClinicsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          gradient: SAColors.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Superadmin', style: AppTextStyles.h4.copyWith(color: SAColors.textPrimary)),
                          Text(DateFormat('EEEE, d MMM y').format(now),
                            style: AppTextStyles.caption.copyWith(color: SAColors.textHint)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Stats row
                  Text('Platform Overview',
                    style: AppTextStyles.label.copyWith(color: SAColors.textSecondary, fontSize: 12, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  statsAsync.when(
                    loading: () => _statsPlaceholder(),
                    error: (e, _) => _errorCard('Failed to load stats: $e'),
                    data: (stats) => Column(
                      children: [
                        Row(children: [
                          Expanded(child: _statCard(
                            Icons.business_rounded,
                            '${stats['total_clinics']}',
                            'Clinics',
                            SAColors.accent,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _statCard(
                            Icons.medical_services_rounded,
                            '${stats['total_doctors']}',
                            'Doctors',
                            const Color(0xFF06B6D4),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _statCard(
                            Icons.person_rounded,
                            '${stats['total_receptionists']}',
                            'Staff',
                            SAColors.success,
                          )),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Recent clinics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Registrations',
                        style: AppTextStyles.label.copyWith(color: SAColors.textSecondary, fontSize: 12, letterSpacing: 1)),
                      GestureDetector(
                        onTap: () {},
                        child: Text('View All',
                          style: AppTextStyles.caption.copyWith(color: SAColors.accent, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  recentAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: SAColors.accent),
                      ),
                    ),
                    error: (e, _) => _errorCard('Failed to load clinics: $e'),
                    data: (clinics) => clinics.isEmpty
                        ? _emptyCard('No clinics registered yet')
                        : Column(
                            children: clinics.map((c) => _clinicTile(context, c)).toList(),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: SAColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value, style: AppTextStyles.h3.copyWith(color: SAColors.textPrimary, fontSize: 22)),
          Text(label, style: AppTextStyles.caption.copyWith(color: SAColors.textHint, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _clinicTile(BuildContext context, dynamic clinic) {
    final name = clinic.getStringValue('name');
    final city = clinic.getStringValue('city');
    final state = clinic.getStringValue('state');
    final verified = clinic.getBoolValue('verified');
    final created = DateTime.tryParse(clinic.getStringValue('created'));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: SAColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SAColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: SAColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.business_rounded, color: SAColors.accent, size: 20),
        ),
        title: Text(name.isEmpty ? '(Unnamed)' : name,
          style: AppTextStyles.label.copyWith(color: SAColors.textPrimary)),
        subtitle: Text(
          [if (city.isNotEmpty) city, if (state.isNotEmpty) state].join(', ').isNotEmpty
              ? [if (city.isNotEmpty) city, if (state.isNotEmpty) state].join(', ')
              : 'No location',
          style: AppTextStyles.caption.copyWith(color: SAColors.textHint),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: verified
                    ? SAColors.success.withValues(alpha: 0.15)
                    : SAColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(verified ? 'Verified' : 'Unverified',
                style: AppTextStyles.caption.copyWith(
                  color: verified ? SAColors.success : SAColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                )),
            ),
            const SizedBox(height: 4),
            if (created != null)
              Text(DateFormat('d MMM y').format(created),
                style: AppTextStyles.caption.copyWith(color: SAColors.textHint, fontSize: 10)),
          ],
        ),
        onTap: () => Navigator.of(context).pushNamed('/superadmin/clinic', arguments: clinic.id),
      ),
    );
  }

  Widget _statsPlaceholder() {
    return Row(children: List.generate(3, (i) => Expanded(
      child: Container(
        height: 100,
        margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
        decoration: BoxDecoration(
          color: SAColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    )));
  }

  Widget _errorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SAColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SAColors.error.withValues(alpha: 0.3)),
      ),
      child: Text(msg, style: AppTextStyles.caption.copyWith(color: SAColors.error)),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SAColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SAColors.border),
      ),
      child: Text(msg, style: AppTextStyles.bodyMedium.copyWith(color: SAColors.textHint)),
    );
  }
}
