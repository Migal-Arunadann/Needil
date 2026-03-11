import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../treatments/providers/treatment_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;

  const ConsultationScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _charged = false;

  final _notesCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _chargeCtrl = TextEditingController();

  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _notesCtrl.dispose();
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
      final auth = ref.read(authProvider);
      final service = ref.read(treatmentServiceProvider);

      final consultation = await service.createConsultation(
        patientId: widget.patientId,
        doctorId: auth.userId!,
        notes: _notesCtrl.text.trim(),
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

                // Notes
                Text('Consultation Notes', style: AppTextStyles.label),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _notesCtrl,
                  label: '',
                  hint: 'Symptoms, observations, diagnosis...',
                  maxLines: 5,
                ),
                const SizedBox(height: 20),

                // Vitals
                Text('Vitals', style: AppTextStyles.label),
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

                // Photos
                Text('Photos', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._photos.asMap().entries.map((e) => _photoThumb(e.key)),
                    _addPhotoBtn(Icons.camera_alt_rounded, 'Camera', _pickPhoto),
                    _addPhotoBtn(
                        Icons.photo_library_rounded, 'Gallery', _pickFromGallery),
                  ],
                ),
                const SizedBox(height: 20),

                // Charge
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
