import 'package:flutter/material.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';

/// Full-screen page shown when a phone number is already registered to one or
/// more patients. The staff selects the correct family member or chooses to
/// register a new one.
///
/// Returns a [FamilySelectionResult]:
///   - [FamilySelectionResult.existing] with a [PatientModel] if an existing
///     member was chosen.
///   - [FamilySelectionResult.addNew] if the user wants to register a new
///     family member under the same phone.
class FamilyMemberSelectionScreen extends StatelessWidget {
  final List<PatientModel> patients;
  final String phone;

  const FamilyMemberSelectionScreen({
    super.key,
    required this.patients,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 700;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : 20,
                      isDesktop ? 40 : 24,
                      isDesktop ? 40 : 20,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back button + title
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.colors.border),
                                ),
                                child: Icon(Icons.arrow_back_rounded,
                                    size: 20, color: context.colors.textPrimary),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Select Patient',
                                      style: context.textStyles.h2),
                                  Text(
                                    'Phone: $phone',
                                    style: context.textStyles.caption
                                        .copyWith(color: context.colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.colors.info.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.people_rounded,
                                  color: context.colors.info, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This phone number is registered to ${patients.length} '
                                  '${patients.length == 1 ? 'patient' : 'patients'}. '
                                  'Select the correct person or add a new family member.',
                                  style: context.textStyles.caption.copyWith(
                                      color: context.colors.info, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text('Registered Patients',
                            style: context.textStyles.h3),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                // Patient cards
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 20,
                  ),
                  sliver: isDesktop
                      ? SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _PatientCard(
                              patient: patients[i],
                              onTap: () => Navigator.pop(
                                context,
                                FamilySelectionResult.existing(patients[i]),
                              ),
                            ),
                            childCount: patients.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 320,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.3,
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PatientCard(
                                patient: patients[i],
                                onTap: () => Navigator.pop(
                                  context,
                                  FamilySelectionResult.existing(patients[i]),
                                ),
                              ),
                            ),
                            childCount: patients.length,
                          ),
                        ),
                ),

                // Add new family member button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 40 : 20,
                      20,
                      isDesktop ? 40 : 20,
                      32,
                    ),
                    child: _AddNewFamilyMemberButton(
                      onTap: () => Navigator.pop(
                        context,
                        FamilySelectionResult.addNew(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Result type ────────────────────────────────────────────────────────────

/// Result returned by [FamilyMemberSelectionScreen].
class FamilySelectionResult {
  final PatientModel? selected;
  final bool isNew;

  const FamilySelectionResult._({this.selected, required this.isNew});

  factory FamilySelectionResult.existing(PatientModel patient) =>
      FamilySelectionResult._(selected: patient, isNew: false);

  factory FamilySelectionResult.addNew() =>
      const FamilySelectionResult._(isNew: true);
}

// ─── Patient Card ────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final PatientModel patient;
  final VoidCallback onTap;

  const _PatientCard({required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final relation = patient.relationToPrimary ?? 'Self';
    final age = patient.age;
    final gender = patient.gender;

    Color relationColor = _relationColor(relation, context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: context.colors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: context.colors.textPrimary.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: context.colors.heroGradient,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      patient.fullName.isNotEmpty
                          ? patient.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.fullName,
                          style: context.textStyles.h4,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (patient.patientId != null &&
                            patient.patientId!.isNotEmpty)
                          Text(
                            patient.patientId!,
                            style: context.textStyles.caption.copyWith(
                              color: context.colors.textHint,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Relation + gender + age chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Chip(label: relation, color: relationColor),
                  if (gender != null && gender.isNotEmpty)
                    _Chip(
                        label: gender,
                        color: context.colors.primary.withValues(alpha: 0.15),
                        textColor: context.colors.primary),
                  if (age != null)
                    _Chip(
                        label: '$age yrs',
                        color: context.colors.surface,
                        textColor: context.colors.textSecondary),
                ],
              ),
              const Spacer(),
              // Select button
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: context.colors.heroGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Select',
                      style: context.textStyles.label.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _relationColor(String relation, BuildContext context) {
    switch (relation.toLowerCase()) {
      case 'self':
        return context.colors.primary.withValues(alpha: 0.15);
      case 'spouse':
        return const Color(0xFFEC4899).withValues(alpha: 0.15);
      case 'child':
        return const Color(0xFF10B981).withValues(alpha: 0.15);
      case 'parent':
        return const Color(0xFFF59E0B).withValues(alpha: 0.15);
      case 'sibling':
        return const Color(0xFF8B5CF6).withValues(alpha: 0.15);
      default:
        return context.colors.surface;
    }
  }
}

// ─── Add New Button ──────────────────────────────────────────────────────────

class _AddNewFamilyMemberButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddNewFamilyMemberButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.primary.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colors.primary.withValues(alpha: 0.3),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.person_add_rounded,
                  color: context.colors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Family Member',
                    style: context.textStyles.h4
                        .copyWith(color: context.colors.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Register a new patient under this phone number',
                    style: context.textStyles.caption
                        .copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: context.colors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Chip ────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const _Chip({required this.label, required this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: context.textStyles.caption.copyWith(
          color: textColor ??
              context.colors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
