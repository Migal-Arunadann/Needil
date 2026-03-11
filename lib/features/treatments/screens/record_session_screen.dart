import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/session_model.dart';
import '../providers/treatment_provider.dart';

class RecordSessionScreen extends ConsumerStatefulWidget {
  final SessionModel session;

  const RecordSessionScreen({super.key, required this.session});

  @override
  ConsumerState<RecordSessionScreen> createState() =>
      _RecordSessionScreenState();
}

class _RecordSessionScreenState extends ConsumerState<RecordSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final _notesCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _notesCtrl.dispose();
    _bpCtrl.dispose();
    _pulseCtrl.dispose();
    _remarksCtrl.dispose();
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
    setState(() => _isSubmitting = true);

    final notifier = ref.read(sessionsProvider.notifier);
    final result = await notifier.recordSession(
      sessionId: widget.session.id,
      notes: _notesCtrl.text.trim(),
      bpLevel: _bpCtrl.text.trim(),
      pulse: _pulseCtrl.text.isNotEmpty
          ? int.tryParse(_pulseCtrl.text.trim())
          : null,
      remarks: _remarksCtrl.text.trim(),
      photoPaths: _photos.map((p) => p.path).toList(),
    );

    setState(() => _isSubmitting = false);

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Session ${widget.session.sessionNumber} recorded ✓'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _markMissed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Missed?'),
        content: Text(
          'Session ${widget.session.sessionNumber} will be marked as missed. This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Missed',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(sessionsProvider.notifier)
          .markMissed(widget.session.id);
      if (mounted) Navigator.pop(context);
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
                          Text(
                              'Session ${widget.session.sessionNumber}',
                              style: AppTextStyles.h2),
                          Text(
                            'Scheduled: ${widget.session.scheduledDate}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    // Mark missed
                    GestureDetector(
                      onTap: _markMissed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Mark Missed',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.error)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Notes
                AppTextField(
                  controller: _notesCtrl,
                  label: 'Session Notes',
                  hint: 'Observations, treatment applied...',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                // Vitals
                Text('Vitals (Optional)', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _bpCtrl,
                        label: 'BP Level',
                        hint: '120/80',
                        prefixIcon: const Icon(
                            Icons.favorite_outline_rounded,
                            color: AppColors.error,
                            size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: _pulseCtrl,
                        label: 'Pulse (bpm)',
                        hint: '72',
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(
                            Icons.monitor_heart_outlined,
                            color: AppColors.warning,
                            size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Photos
                Text('Photos', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._photos.asMap().entries.map((e) => _photoThumb(e.key)),
                    _addPhotoBtn(
                        Icons.camera_alt_rounded, 'Camera', _pickPhoto),
                    _addPhotoBtn(Icons.photo_library_rounded, 'Gallery',
                        _pickFromGallery),
                  ],
                ),
                const SizedBox(height: 16),

                // Remarks
                AppTextField(
                  controller: _remarksCtrl,
                  label: 'Remarks',
                  hint: 'Follow-up notes, patient feedback...',
                  maxLines: 2,
                ),
                const SizedBox(height: 28),

                // Submit
                AppButton(
                  label: 'Complete Session',
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
      clipBehavior: Clip.none,
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
            child: const Icon(Icons.image_rounded, color: AppColors.textHint),
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
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
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
          border: Border.all(color: AppColors.primary),
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
