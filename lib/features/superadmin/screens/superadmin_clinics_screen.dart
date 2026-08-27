import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/utils/error_formatter.dart';
import 'package:pms_app/core/services/superadmin_service.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_shell.dart';
import 'package:pms_app/core/theme/app_theme.dart';


// Providers for search and status filter
final _clinicsSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _clinicsFilterProvider = StateProvider.autoDispose<String>((ref) => 'all'); // 'all', 'active', 'grace', 'expiring', 'expired', 'deactivated'

final _allClinicsProvider = FutureProvider.autoDispose<List<RecordModel>>((ref) {
  final search = ref.watch(_clinicsSearchProvider);
  final filter = ref.watch(_clinicsFilterProvider);
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchAllClinics(search: search).then((clinics) {
    if (filter == 'all') return clinics;
    final now = DateTime.now();
    final in7Days = now.add(const Duration(days: 7));
    return clinics.where((c) {
      final isDeactivated = c.getBoolValue('is_deactivated');
      final status = c.getStringValue('status');
      final subStatus = c.getStringValue('subscription_status');
      final endDate = DateTime.tryParse(c.getStringValue('subscription_end_date'));

      if (filter == 'deactivated') {
        return isDeactivated || status == 'pending_deletion';
      }

      if (filter == 'expired') {
        if (isDeactivated) return false;
        if (subStatus == 'canceled' || subStatus == 'expired') return true;
        if (endDate == null) return false;
        return now.isAfter(endDate.add(const Duration(days: 3)));
      }

      if (filter == 'grace') {
        if (endDate == null || isDeactivated) return false;
        final graceEnd = endDate.add(const Duration(days: 3));
        return now.isAfter(endDate) && now.isBefore(graceEnd);
      }

      if (filter == 'expiring') {
        if (endDate == null || isDeactivated) return false;
        return endDate.isAfter(now) && endDate.isBefore(in7Days);
      }

      if (filter == 'active') {
        if (isDeactivated || status == 'pending_deletion' || subStatus == 'canceled' || subStatus == 'expired') {
          return false;
        }
        if (endDate == null) return true;
        return now.isBefore(endDate.add(const Duration(days: 3)));
      }

      return true;
    }).toList();
  });
});

class SuperadminClinicsScreen extends ConsumerStatefulWidget {
  const SuperadminClinicsScreen({super.key});

  @override
  ConsumerState<SuperadminClinicsScreen> createState() => _SuperadminClinicsScreenState();
}

class _SuperadminClinicsScreenState extends ConsumerState<SuperadminClinicsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clinicsAsync = ref.watch(_allClinicsProvider);
    final activeFilter = ref.watch(_clinicsFilterProvider);

    return Scaffold(
      backgroundColor: SAColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: SAColors.gradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  // Header & Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clinics', style: context.textStyles.h3.copyWith(color: SAColors.textPrimary)),
                        Text('Manage all registered clinics, subscriptions, and patient data',
                          style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
                        const SizedBox(height: 16),
                        // Search bar
                        Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: SAColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: SAColors.border),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: context.textStyles.bodyMedium.copyWith(color: SAColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search by clinic name, city or code…',
                              hintStyle: context.textStyles.caption.copyWith(color: SAColors.textHint),
                              prefixIcon: const Icon(Icons.search_rounded, color: SAColors.textHint, size: 20),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, color: SAColors.textHint, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        ref.read(_clinicsSearchProvider.notifier).state = '';
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (v) => ref.read(_clinicsSearchProvider.notifier).state = v,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Filter Pills Bar
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterChip('all', 'All Clinics', activeFilter),
                              const SizedBox(width: 8),
                              _filterChip('active', 'Active', activeFilter, color: SAColors.success),
                              const SizedBox(width: 8),
                              _filterChip('grace', 'Grace Period', activeFilter, color: SAColors.warning),
                              const SizedBox(width: 8),
                              _filterChip('expiring', 'Expiring <7d', activeFilter, color: const Color(0xFFF97316)),
                              const SizedBox(width: 8),
                              _filterChip('expired', 'Expired', activeFilter, color: SAColors.error),
                              const SizedBox(width: 8),
                              _filterChip('deactivated', 'Deactivated', activeFilter, color: SAColors.textHint),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Clinics list
                  Expanded(
                    child: RefreshIndicator(
                      color: SAColors.accent,
                      backgroundColor: SAColors.card,
                      onRefresh: () async => ref.invalidate(_allClinicsProvider),
                      child: clinicsAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: SAColors.accent),
                        ),
                        error: (e, _) => Center(
                          child: Text('Error: ${ErrorFormatter.format(e)}',
                              style: const TextStyle(color: SAColors.error)),
                        ),
                        data: (clinics) => clinics.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: Column(children: [
                                      const Icon(Icons.business_outlined, color: SAColors.textHint, size: 48),
                                      const SizedBox(height: 12),
                                      Text('No clinics found', style: context.textStyles.bodyMedium.copyWith(color: SAColors.textHint)),
                                    ]),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                itemCount: clinics.length,
                                separatorBuilder: (ctx, index) => const SizedBox(height: 10),
                                itemBuilder: (ctx, i) => _ClinicListCard(
                                  record: clinics[i],
                                  onTap: () => context
                                      .push('/superadmin/clinic', extra: clinics[i].id)
                                      .then((_) => ref.invalidate(_allClinicsProvider)),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String id, String label, String activeId, {Color? color}) {
    final isActive = id == activeId;
    final chipColor = color ?? SAColors.accent;
    return GestureDetector(
      onTap: () => ref.read(_clinicsFilterProvider.notifier).state = id,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? chipColor.withValues(alpha: 0.2) : SAColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? chipColor : SAColors.border,
            width: isActive ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? (color != null ? chipColor : Colors.white) : SAColors.textSecondary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ClinicListCard extends StatelessWidget {
  final RecordModel record;
  final VoidCallback onTap;

  const _ClinicListCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = record.getStringValue('name');
    final city = record.getStringValue('city');
    final state = record.getStringValue('state');
    final clinicCode = record.getStringValue('clinic_id');
    final verified = record.getBoolValue('verified');
    final isDeactivated = record.getBoolValue('is_deactivated');
    final status = record.getStringValue('status');
    final isPendingDeletion = status == 'pending_deletion';
    final purgeAtStr = record.getStringValue('purge_at');
    final purgeAt = DateTime.tryParse(purgeAtStr);
    final daysLeft = purgeAt != null
        ? purgeAt.difference(DateTime.now()).inDays.clamp(0, 9999)
        : 30;
    final bedCount = record.getIntValue('bed_count');
    final created = DateTime.tryParse(record.getStringValue('created'));

    final tier = record.getStringValue('subscription_tier').isNotEmpty
        ? record.getStringValue('subscription_tier').toUpperCase()
        : 'BASE';
    final subStatus = record.getStringValue('subscription_status');
    final endDateStr = record.getStringValue('subscription_end_date');
    final endDate = DateTime.tryParse(endDateStr);
    final photoLimit = record.getIntValue('photo_limit', 2000);
    final photosUsed = record.getIntValue('photos_used', 0);

    final now = DateTime.now();
    final bool isExpired = !isDeactivated &&
        (subStatus == 'expired' ||
            subStatus == 'canceled' ||
            (endDate != null && now.isAfter(endDate.add(const Duration(days: 3)))));
    final bool isInGrace = !isDeactivated &&
        endDate != null &&
        now.isAfter(endDate) &&
        now.isBefore(endDate.add(const Duration(days: 3)));

    final location = [if (city.isNotEmpty) city, if (state.isNotEmpty) state].join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPendingDeletion
              ? const Color(0xFFEF4444).withValues(alpha: 0.06)
              : isDeactivated
                  ? SAColors.warning.withValues(alpha: 0.06)
                  : isExpired
                      ? const Color(0xFFEF4444).withValues(alpha: 0.05)
                      : SAColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPendingDeletion
                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                : isDeactivated
                    ? SAColors.warning.withValues(alpha: 0.4)
                    : isExpired
                        ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                        : SAColors.border,
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
                    gradient: SAColors.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.business_rounded, color: context.colors.textPrimary, size: 22),
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
                              name.isEmpty ? '(Incomplete Registration)' : name,
                              style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Plan Tier Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SAColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: SAColors.accent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              tier,
                              style: const TextStyle(
                                color: SAColors.accentLight,
                                fontWeight: FontWeight.w700,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clinicCode.isEmpty ? 'ID: Pending' : 'ID: $clinicCode',
                        style: context.textStyles.caption.copyWith(color: SAColors.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPendingDeletion
                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                        : isDeactivated
                            ? SAColors.warning.withValues(alpha: 0.15)
                            : isExpired
                                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                : isInGrace
                                    ? const Color(0xFFF97316).withValues(alpha: 0.15)
                                    : (verified ? SAColors.success.withValues(alpha: 0.15) : SAColors.warning.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPendingDeletion
                        ? '⏳ Purging in ${daysLeft}d'
                        : isDeactivated
                            ? '⊘ Deactivated'
                            : isExpired
                                ? '✕ Expired'
                                : isInGrace
                                    ? '⚠ Grace Period'
                                    : (verified ? '✓ Active' : '⚠ Pending Verification'),
                    style: context.textStyles.caption.copyWith(
                      color: isPendingDeletion
                          ? const Color(0xFFEF4444)
                          : isDeactivated
                              ? SAColors.warning
                              : isExpired
                                  ? const Color(0xFFEF4444)
                                  : isInGrace
                                      ? const Color(0xFFF97316)
                                      : (verified ? SAColors.success : SAColors.warning),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info Row: Location, Bed Count, Photos Quota, Expiry Date
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _infoChip(context, Icons.location_on_outlined, location.isEmpty ? 'No location' : location),
                _infoChip(context, Icons.bed_outlined, '$bedCount beds'),
                _infoChip(context, Icons.photo_library_outlined, '$photosUsed/$photoLimit photos'),
                if (endDate != null)
                  _infoChip(
                    context,
                    Icons.event_outlined,
                    'Expires: ${DateFormat('d MMM y').format(endDate)}',
                    color: isExpired
                        ? SAColors.error
                        : isInGrace
                            ? const Color(0xFFF97316)
                            : SAColors.textSecondary,
                  )
                else
                  _infoChip(context, Icons.all_inclusive_rounded, 'Lifetime access'),
                if (created != null)
                  Text(
                    'Reg: ${DateFormat('d MMM y').format(created)}',
                    style: context.textStyles.caption.copyWith(color: SAColors.textHint, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String label, {Color? color}) {
    final chipColor = color ?? SAColors.textHint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: chipColor),
        const SizedBox(width: 4),
        Text(label, style: context.textStyles.caption.copyWith(color: chipColor, fontSize: 11)),
      ],
    );
  }
}
