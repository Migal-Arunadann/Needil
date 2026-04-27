import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/services/superadmin_service.dart';
import 'superadmin_shell.dart';

// Provider for the full clinics list with optional search
final _clinicsSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final _allClinicsProvider = FutureProvider.autoDispose<List<RecordModel>>((ref) {
  final search = ref.watch(_clinicsSearchProvider);
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).fetchAllClinics(search: search);
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

    return Scaffold(
      backgroundColor: SAColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: SAColors.gradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clinics', style: AppTextStyles.h3.copyWith(color: SAColors.textPrimary)),
                    Text('Manage all registered clinics',
                      style: AppTextStyles.caption.copyWith(color: SAColors.textHint)),
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
                        style: AppTextStyles.bodyMedium.copyWith(color: SAColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search by name, city or clinic ID…',
                          hintStyle: AppTextStyles.caption.copyWith(color: SAColors.textHint),
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
                      child: Text('Error: $e', style: AppTextStyles.bodyMedium.copyWith(color: SAColors.error)),
                    ),
                    data: (clinics) => clinics.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: Column(children: [
                                  const Icon(Icons.business_outlined, color: SAColors.textHint, size: 48),
                                  const SizedBox(height: 12),
                                  Text('No clinics found', style: AppTextStyles.bodyMedium.copyWith(color: SAColors.textHint)),
                                ]),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            itemCount: clinics.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) => _ClinicListCard(
                              record: clinics[i],
                              onTap: () => Navigator.of(context)
                                  .pushNamed('/superadmin/clinic', arguments: clinics[i].id)
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
    final bedCount = record.getIntValue('bed_count');
    final created = DateTime.tryParse(record.getStringValue('created'));

    final location = [if (city.isNotEmpty) city, if (state.isNotEmpty) state].join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SAColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SAColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: SAColors.accentGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? '(Incomplete)' : name,
                        style: AppTextStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(clinicCode.isEmpty ? 'No ID' : 'ID: $clinicCode',
                        style: AppTextStyles.caption.copyWith(color: SAColors.textHint)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: verified
                        ? SAColors.success.withValues(alpha: 0.15)
                        : SAColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(verified ? '✓ Verified' : '⚠ Pending',
                    style: AppTextStyles.caption.copyWith(
                      color: verified ? SAColors.success : SAColors.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip(Icons.location_on_outlined, location.isEmpty ? 'No location' : location),
                const SizedBox(width: 8),
                _infoChip(Icons.bed_outlined, '$bedCount beds'),
                const Spacer(),
                if (created != null)
                  Text(DateFormat('d MMM y').format(created),
                    style: AppTextStyles.caption.copyWith(color: SAColors.textHint, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: SAColors.textHint),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption.copyWith(color: SAColors.textHint, fontSize: 11)),
      ],
    );
  }
}
