import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../treatments/providers/treatment_provider.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;

  const ConsultationScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
  });

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _charged = false;

  final _notesCtrl = TextEditingController(); // Chief Complaint / Main Problem
  final _medicalHistoryCtrl = TextEditingController();
  final _pastIllnessesCtrl = TextEditingController();
  final _currentMedicationsCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _chronicDiseasesCtrl = TextEditingController();
  
  // Lifestyle
  final _dietPatternCtrl = TextEditingController();
  final _sleepQualityCtrl = TextEditingController();
  final _exerciseLevelCtrl = TextEditingController();
  final _addictionsCtrl = TextEditingController();
  final _stressLevelCtrl = TextEditingController();
  
  // Consent
  final _pregnancyStatusCtrl = TextEditingController();
  bool _consentGiven = false;

  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _chargeCtrl = TextEditingController();

  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _notesCtrl.dispose();
    _medicalHistoryCtrl.dispose();
    _pastIllnessesCtrl.dispose();
    _currentMedicationsCtrl.dispose();
    _allergiesCtrl.dispose();
    _chronicDiseasesCtrl.dispose();
    _dietPatternCtrl.dispose();
    _sleepQualityCtrl.dispose();
    _exerciseLevelCtrl.dispose();
    _addictionsCtrl.dispose();
    _stressLevelCtrl.dispose();
    _pregnancyStatusCtrl.dispose();
    _bpCtrl.dispose();
    _pulseCtrl.dispose();
    _chargeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final img = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (img != null) setState(() => _photos.add(img));
  }

  Future<void> _pickFromGallery() async {
    final imgs = await _picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (imgs.isNotEmpty) setState(() => _photos.addAll(imgs));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(treatmentServiceProvider);

      final consultation = await service.createConsultation(
        patientId: widget.patientId,
        doctorId: widget.doctorId,
        notes: _notesCtrl.text.trim(),
        chiefComplaint: _notesCtrl.text.trim(),
        medicalHistory: _medicalHistoryCtrl.text.trim(),
        pastIllnesses: _pastIllnessesCtrl.text.trim(),
        currentMedications: _currentMedicationsCtrl.text.trim(),
        allergies: _allergiesCtrl.text.trim(),
        chronicDiseases: _chronicDiseasesCtrl.text.trim(),
        dietPattern: _dietPatternCtrl.text.trim(),
        sleepQuality: _sleepQualityCtrl.text.trim(),
        exerciseLevel: _exerciseLevelCtrl.text.trim(),
        addictions: _addictionsCtrl.text.trim(),
        stressLevel: _stressLevelCtrl.text.trim(),
        pregnancyStatus: _pregnancyStatusCtrl.text.trim(),
        consentGiven: _consentGiven,
        bpLevel: _bpCtrl.text.trim(),
        pulse: _pulseCtrl.text.isNotEmpty
            ? int.tryParse(_pulseCtrl.text.trim())
            : null,
        charged: _charged,
        chargeAmount: _charged && _chargeCtrl.text.isNotEmpty
            ? double.tryParse(_chargeCtrl.text.trim())
            : null,
        photoPaths: _photos.map((p) => p.path).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Consultation recorded!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Return the consultation so the caller can create a treatment plan
        Navigator.pop(context, consultation);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            size: 20, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New Consultation', style: AppTextStyles.h2),
                          Text(widget.patientName,
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── Conversational / Medical ───
                _buildSectionHeader('Consulting Conversations', Icons.chat_bubble_outline_rounded),
                
                AppTextField(
                  controller: _notesCtrl,
                  label: 'Chief Complaint / Main Problem',
                  hint: 'As discussed with the client...',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _medicalHistoryCtrl,
                  label: 'Medical & Treatment History',
                  hint: 'Previous treatments...',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _pastIllnessesCtrl,
                  label: 'Past Major Illnesses / Surgeries',
                  hint: 'Hospitalizations, surgeries...',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _currentMedicationsCtrl,
                  label: 'Current Medications',
                  hint: 'Allopathic, herbal, etc.',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _allergiesCtrl,
                  label: 'Known Allergies / Contraindications',
                  hint: 'Skin reactions, drug allergies...',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _chronicDiseasesCtrl,
                  label: 'Chronic Diseases',
                  hint: 'Diabetes, BP, Heart, Thyroid...',
                  maxLines: 2,
                ),
                const SizedBox(height: 32),

                // ─── Lifestyle & Habits ───
                _buildSectionHeader('Lifestyle & Habits', Icons.accessibility_new_rounded),
                
                AppTextField(controller: _dietPatternCtrl, label: 'Diet Pattern', hint: 'Vegetarian, timely meals...'),
                const SizedBox(height: 16),
                AppTextField(controller: _sleepQualityCtrl, label: 'Sleep Quality & Duration', hint: '7 hours, disturbed...'),
                const SizedBox(height: 16),
                AppTextField(controller: _exerciseLevelCtrl, label: 'Exercise / Physical Activity', hint: 'Sedentary, active...'),
                const SizedBox(height: 16),
                AppTextField(controller: _addictionsCtrl, label: 'Smoking / Alcohol / Tobacco', hint: 'Occasional, non-smoker...'),
                const SizedBox(height: 16),
                AppTextField(controller: _stressLevelCtrl, label: 'Stress / Mental Health Notes', hint: 'High stress, relaxed...', maxLines: 2),
                const SizedBox(height: 32),

                // ─── Vitals ───
                _buildSectionHeader('Vitals', Icons.monitor_heart_outlined),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _bpCtrl,
                        label: 'BP Level',
                        hint: '120/80',
                        prefixIcon: const Icon(Icons.favorite_outline_rounded,
                            color: AppColors.error, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _pulseCtrl,
                        label: 'Pulse (bpm)',
                        hint: '72',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.monitor_heart_outlined,
                            color: AppColors.warning, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Investigations & Photos ───
                _buildSectionHeader('Recent Investigations', Icons.science_outlined),
                Text('Upload X-Rays, MRI, Blood Test Reports', style: AppTextStyles.caption),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ..._photos.asMap().entries.map((e) => _photoThumb(e.key)),
                    _addPhotoBtn(Icons.camera_alt_rounded, 'Camera', _pickPhoto),
                    _addPhotoBtn(Icons.photo_library_rounded, 'Gallery', _pickFromGallery),
                  ],
                ),
                const SizedBox(height: 32),
                
                // ─── Consent & Safety ───
                _buildSectionHeader('Consent & Safety', Icons.verified_user_outlined),
                AppTextField(
                  controller: _pregnancyStatusCtrl,
                  label: 'Pregnancy Status (if applicable)',
                  hint: 'Months, N/A...',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Informed consent obtained for touch-based treatments / exercises.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                      Switch(
                        value: _consentGiven,
                        onChanged: (v) => setState(() => _consentGiven = v),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ─── Charge ───
                _buildSectionHeader('Consultation Fee', Icons.payments_outlined),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Charge for consultation?',
                                style: AppTextStyles.bodyMedium),
                          ),
                          Switch(
                            value: _charged,
                            onChanged: (v) => setState(() => _charged = v),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                      if (_charged) ...[
                        const SizedBox(height: 10),
                        AppTextField(
                          controller: _chargeCtrl,
                          label: 'Amount (₹)',
                          hint: '500',
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(
                              Icons.currency_rupee_rounded,
                              color: AppColors.success,
                              size: 18),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Submit
                AppButton(
                  label: 'Save Consultation',
                  isLoading: _isSubmitting,
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.h3),
        ],
      ),
    );
  }

  Widget _photoThumb(int index) {
    return Stack(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            color: AppColors.surface,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.network(
              _photos[index].path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_rounded,
                  color: AppColors.textHint),
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () => setState(() => _photos.removeAt(index)),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addPhotoBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary, style: BorderStyle.solid),
          color: AppColors.primary.withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: AppColors.primary),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
