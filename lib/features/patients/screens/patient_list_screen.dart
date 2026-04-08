import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/patient_model.dart';
import '../providers/patient_provider.dart';
import 'patient_profile_screen.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PatientModel> _filtered(List<PatientModel> all) {
    if (_searchQuery.isEmpty) return all;
    final q = _searchQuery.toLowerCase();
    return all.where((p) => 
      p.fullName.toLowerCase().contains(q) || 
      p.phone.contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientListProvider);
    final filtered = _filtered(state.patients);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patients', style: AppTextStyles.h1),
                        const SizedBox(height: 4),
                        Text(
                          '${state.patients.length} total registered',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search_rounded, size: 20, color: AppColors.textHint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: AppTextStyles.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone...',
                          hintStyle: AppTextStyles.caption.copyWith(fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // List
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3))
                  : state.error != null
                      ? _errorView(state.error!)
                      : filtered.isEmpty
                          ? _emptyView()
                          : RefreshIndicator(
                              color: AppColors.primary,
                              onRefresh: () => ref.read(patientListProvider.notifier).loadPatients(),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100), // padding for FAB
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  return _AnimatedCard(
                                    index: index,
                                    child: _patientCard(filtered[index]),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientCard(PatientModel patient) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PatientProfileScreen(patient: patient)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar Initials
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : '?',
                    style: AppTextStyles.h2.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: AppTextStyles.h3.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_rounded, size: 12, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            patient.phone,
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Phone Call Button
                if (patient.phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded, color: AppColors.success),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.success.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse('tel:${patient.phone}');
                      try {
                        await launchUrl(uri);
                      } catch (e) {
                        debugPrint('Could not launch dialer: $e');
                      }
                    },
                  ),
                const SizedBox(width: 4),
                // Forward Icon
                const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Bottom Info Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_turned_in_rounded, size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(
                      patient.consentGiven ? 'Consent Signed' : 'Pending Consent',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: patient.consentGiven ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Added: ${patient.created != null ? DateFormat('MMM d, yyyy').format(patient.created!) : 'Unknown'}',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
   );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: AppColors.textHint.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No matches found' : 'No patients registered yet',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.read(patientListProvider.notifier).loadPatients(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Staggered slide-in animation wrapper for list cards.
class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedCard({required this.child, required this.index});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: widget.child));
  }
}
