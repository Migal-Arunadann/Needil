import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/utils/error_formatter.dart';
import 'package:pms_app/core/services/superadmin_service.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_shell.dart';
import 'package:pms_app/core/theme/app_theme.dart';


final _dashStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchPlatformStats();
});

final _recentClinicsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchRecentClinics(limit: 8);
});

final _reactivationRequestsProvider =
    FutureProvider.autoDispose<List<RecordModel>>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchReactivationRequests();
});

class SuperadminDashboardScreen extends ConsumerStatefulWidget {
  const SuperadminDashboardScreen({super.key});

  @override
  ConsumerState<SuperadminDashboardScreen> createState() =>
      _SuperadminDashboardScreenState();
}

class _SuperadminDashboardScreenState
    extends ConsumerState<SuperadminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Run purge check silently on dashboard load.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final pb = ref.read(pocketbaseProvider);
        final purged = await SuperadminService(pb).runPurgeCheck();
        if (purged > 0) {
          ref.invalidate(_dashStatsProvider);
          ref.invalidate(_recentClinicsProvider);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(_dashStatsProvider);
    final recentAsync = ref.watch(_recentClinicsProvider);
    final reactivationAsync = ref.watch(_reactivationRequestsProvider);
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
              ref.invalidate(_reactivationRequestsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
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
                            child: Icon(Icons.admin_panel_settings_rounded, color: context.colors.textPrimary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Superadmin', style: context.textStyles.h4.copyWith(color: SAColors.textPrimary)),
                              Text(DateFormat('EEEE, d MMM y').format(now),
                                style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Stats row
                      Text('Platform Overview',
                        style: context.textStyles.label.copyWith(color: SAColors.textSecondary, fontSize: 12, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      statsAsync.when(
                        loading: () => _statsPlaceholder(),
                        error: (e, _) => _errorCard(context, 'Failed to load stats: ${ErrorFormatter.format(e)}'),
                        data: (stats) => Column(
                          children: [
                            Row(children: [
                              Expanded(child: _statCard(context,
                                Icons.business_rounded,
                                '${stats['total_clinics']}',
                                'Clinics',
                                SAColors.accent,
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard(context,
                                Icons.medical_services_rounded,
                                '${stats['total_doctors']}',
                                'Doctors',
                                const Color(0xFF06B6D4),
                              )),
                              const SizedBox(width: 12),
                              Expanded(child: _statCard(context,
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

                      // ── Reactivation Requests ───────────────────────────────
                      reactivationAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (requests) => requests.isEmpty
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: SAColors.warning.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('${requests.length}',
                                          style: const TextStyle(
                                              color: SAColors.warning,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Reactivation Requests',
                                        style: context.textStyles.label.copyWith(
                                            color: SAColors.textSecondary,
                                            fontSize: 12,
                                            letterSpacing: 1)),
                                  ]),
                                  const SizedBox(height: 12),
                                  ...requests.map((r) => _reactivationCard(
                                        context,
                                        ref,
                                        r,
                                      )),
                                  const SizedBox(height: 24),
                                ],
                              ),
                      ),

                      // Recent clinics
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recent Registrations',
                            style: context.textStyles.label.copyWith(color: SAColors.textSecondary, fontSize: 12, letterSpacing: 1)),
                          GestureDetector(
                            onTap: () {},
                            child: Text('View All',
                              style: context.textStyles.caption.copyWith(color: SAColors.accent, fontWeight: FontWeight.w700)),
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
                        error: (e, _) => _errorCard(context, 'Failed to load clinics: ${ErrorFormatter.format(e)}'),
                        data: (clinics) => clinics.isEmpty
                            ? _emptyCard(context, 'No clinics registered yet')
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
        ),
      ),
    );
  }

  Widget _reactivationCard(
      BuildContext context, WidgetRef ref, RecordModel request) {
    final clinicName = request.getStringValue('clinic_name');
    final clinicId = request.getStringValue('clinic_id');
    final reason = request.getStringValue('reason');
    final requestedAt = request.getStringValue('requested_at');
    final dateStr = requestedAt.isNotEmpty
        ? requestedAt.substring(0, 10)
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SAColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: SAColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.restore_rounded,
                color: SAColors.warning, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                clinicName.isNotEmpty ? clinicName : clinicId,
                style: context.textStyles.label.copyWith(
                    color: SAColors.textPrimary, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(dateStr,
                style: context.textStyles.caption
                    .copyWith(color: SAColors.textHint, fontSize: 11)),
          ]),
          if (reason.isNotEmpty) ...
            [
              const SizedBox(height: 6),
              Text('Reason: $reason',
                  style: context.textStyles.caption
                      .copyWith(color: SAColors.textSecondary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  try {
                    final pb = ref.read(pocketbaseProvider);
                    await SuperadminService(pb).rejectReactivation(
                        request.id, clinicId);
                    ref.invalidate(_reactivationRequestsProvider);
                    if (context.mounted) {
                      AppToast.show('Request rejected');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppToast.show('Error: $e', type: ToastType.error);
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: SAColors.error,
                  side: const BorderSide(color: SAColors.error, width: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Reject', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    final pb = ref.read(pocketbaseProvider);
                    await SuperadminService(pb).approveReactivation(
                        request.id, clinicId);
                    ref.invalidate(_reactivationRequestsProvider);
                    ref.invalidate(_recentClinicsProvider);
                    if (context.mounted) {
                      AppToast.show('✓ Clinic reactivated successfully', type: ToastType.success);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppToast.show('Error: $e', type: ToastType.error);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: SAColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Approve',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, IconData icon, String value, String label, Color color) {
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
          Text(value, style: context.textStyles.h3.copyWith(color: SAColors.textPrimary, fontSize: 22)),
          Text(label, style: context.textStyles.caption.copyWith(color: SAColors.textHint, fontSize: 11)),
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
          style: context.textStyles.label.copyWith(color: SAColors.textPrimary)),
        subtitle: Text(
          [if (city.isNotEmpty) city, if (state.isNotEmpty) state].join(', ').isNotEmpty
              ? [if (city.isNotEmpty) city, if (state.isNotEmpty) state].join(', ')
              : 'No location',
          style: context.textStyles.caption.copyWith(color: SAColors.textHint),
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
                style: context.textStyles.caption.copyWith(
                  color: verified ? SAColors.success : SAColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                )),
            ),
            const SizedBox(height: 4),
            if (created != null)
              Text(DateFormat('d MMM y').format(created),
                style: context.textStyles.caption.copyWith(color: SAColors.textHint, fontSize: 10)),
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

  Widget _errorCard(BuildContext context, String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SAColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SAColors.error.withValues(alpha: 0.3)),
      ),
      child: Text(msg, style: context.textStyles.caption.copyWith(color: SAColors.error)),
    );
  }

  Widget _emptyCard(BuildContext context, String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SAColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SAColors.border),
      ),
      child: Text(msg, style: context.textStyles.bodyMedium.copyWith(color: SAColors.textHint)),
    );
  }
}
