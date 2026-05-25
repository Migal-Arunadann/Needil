import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/whatsapp_helper.dart';
import '../models/patient_model.dart';
import '../providers/patient_provider.dart';
import 'patient_profile_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';


class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  String _searchQuery = '';
  String _sortMode = 'recent'; // 'recent', 'a-z', 'phone'
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PatientModel> _filtered(List<PatientModel> all) {
    List<PatientModel> result = all;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (p) => p.fullName.toLowerCase().contains(q) || p.phone.contains(q),
          )
          .toList();
    }
    switch (_sortMode) {
      case 'a-z':
        result = List.of(result)..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        break;
      case 'phone':
        result = List.of(result)..sort((a, b) => a.phone.compareTo(b.phone));
        break;
      default: // 'recent'
        result = List.of(result)..sort((a, b) => (b.created ?? DateTime(2000)).compareTo(a.created ?? DateTime(2000)));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientListProvider);
    final filtered = _filtered(state.patients);

    return Scaffold(
      backgroundColor: context.colors.background,
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
                        Text('Patients', style: context.textStyles.h1),
                        const SizedBox(height: 4),
                        Text(
                          '${state.patients.length} total registered',
                          style: context.textStyles.bodyMedium.copyWith(
                            color: context.colors.textSecondary,
                          ),
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
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: context.colors.textHint,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: context.textStyles.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone...',
                          hintStyle: context.textStyles.caption.copyWith(
                            fontSize: 14,
                          ),
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
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: context.colors.textHint,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),

            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _filterChip('Recent', 'recent', Icons.schedule_rounded),
                  const SizedBox(width: 8),
                  _filterChip('A–Z', 'a-z', Icons.sort_by_alpha_rounded),
                  const SizedBox(width: 8),
                  _filterChip('Phone', 'phone', Icons.phone_rounded),
                ],
              ),
            ),
            SizedBox(height: 12),

            // List
            Expanded(
              child: state.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.colors.primary,
                        strokeWidth: 3,
                      ),
                    )
                  : state.error != null
                  ? _errorView(state.error!)
                  : filtered.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      color: context.colors.primary,
                      onRefresh: () =>
                          ref.read(patientListProvider.notifier).loadPatients(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          8,
                          24,
                          100,
                        ), // padding for FAB
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
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
          MaterialPageRoute(
            builder: (_) => PatientProfileScreen(patient: patient),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Initials
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: context.colors.heroGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  patient.fullName.isNotEmpty
                      ? patient.fullName[0].toUpperCase()
                      : '?',
                  style: context.textStyles.h2.copyWith(color: Colors.white),
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
                      style: context.textStyles.h3.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          size: 12,
                          color: context.colors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          patient.phone,
                          style: context.textStyles.caption.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // WhatsApp Button — simple redirect to chat
              if (patient.phone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                  tooltip: 'WhatsApp',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => WhatsAppHelper.openChat(patient.phone),
                ),
              // Phone Call Button
              if (patient.phone.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.phone_rounded,
                    color: context.colors.success,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: context.colors.success.withValues(
                      alpha: 0.1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
              SizedBox(width: 4),
              // Forward Icon
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String mode, IconData icon) {
    final isActive = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? context.colors.primary.withValues(alpha: 0.12)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? context.colors.primary.withValues(alpha: 0.5)
                : context.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? context.colors.primary : context.colors.textHint,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.textStyles.caption.copyWith(
                color: isActive ? context.colors.primary : context.colors.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
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
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: context.colors.textHint.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matches found'
                : 'No patients registered yet',
            style: context.textStyles.bodyMedium.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: context.colors.error,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(patientListProvider.notifier).loadPatients(),
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

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

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
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}