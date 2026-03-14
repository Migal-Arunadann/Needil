import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../treatments/providers/treatment_provider.dart';
import '../../treatments/models/session_model.dart';
import '../models/consultation_model.dart';
import 'package:pocketbase/pocketbase.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;
  final String? consultationId;
  final bool isViewMode;

  const ConsultationScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    this.consultationId,
    this.isViewMode = false,
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
  
  bool _isLoadingView = false;
  RecordModel? _existingRecord;
  ConsultationModel? _existingConsultation;
  List<SessionModel> _existingSessions = [];

  late bool _isViewing;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isViewing = widget.isViewMode;
    if (widget.consultationId != null) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoadingView = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final record = await pb.collection(PBCollections.consultations).getOne(widget.consultationId!);
      _existingRecord = record;
      _existingConsultation = ConsultationModel.fromRecord(record);

      // Pre-fill fields for reference (if wanted, though readOnly makes them uneditable)
      _notesCtrl.text = _existingConsultation?.chiefComplaint ?? _existingConsultation?.notes ?? '';
      _medicalHistoryCtrl.text = _existingConsultation?.medicalHistory ?? '';
      _pastIllnessesCtrl.text = _existingConsultation?.pastIllnesses ?? '';
      _currentMedicationsCtrl.text = _existingConsultation?.currentMedications ?? '';
      _allergiesCtrl.text = _existingConsultation?.allergies ?? '';
      _chronicDiseasesCtrl.text = _existingConsultation?.chronicDiseases ?? '';
      _dietPatternCtrl.text = _existingConsultation?.dietPattern ?? '';
      _sleepQualityCtrl.text = _existingConsultation?.sleepQuality ?? '';
      _exerciseLevelCtrl.text = _existingConsultation?.exerciseLevel ?? '';
      _addictionsCtrl.text = _existingConsultation?.addictions ?? '';
      _stressLevelCtrl.text = _existingConsultation?.stressLevel ?? '';
      _pregnancyStatusCtrl.text = _existingConsultation?.pregnancyStatus ?? '';
      _bpCtrl.text = _existingConsultation?.bpLevel ?? '';
      _pulseCtrl.text = _existingConsultation?.pulse?.toString() ?? '';
      _chargeCtrl.text = _existingConsultation?.chargeAmount?.toString() ?? '';
      _charged = _existingConsultation?.charged ?? false;
      _consentGiven = _existingConsultation?.consentGiven ?? false;

      // Load associated sessions
      final sessRes = await pb.collection(PBCollections.sessions).getList(
        filter: 'consultation = "${widget.consultationId}"',
        sort: 'scheduled_date',
      );
      _existingSessions = sessRes.items.map((e) => SessionModel.fromRecord(e)).toList();

    } catch (e) {
      debugPrint('Error loading view mode data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingView = false);
    }
  }

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

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Consultation?', style: TextStyle(color: AppColors.error)),
        content: const Text('Are you sure you want to permanently delete this consultation? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.consultationId != null && mounted) {
      try {
        final pb = ref.read(pocketbaseProvider);
        await pb.collection(PBCollections.consultations).delete(widget.consultationId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Consultation deleted.'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(treatmentServiceProvider);

      ConsultationModel consultation;
      if (widget.isViewMode && widget.consultationId != null) {
        consultation = await service.updateConsultation(
          consultationId: widget.consultationId!,
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
          pulse: _pulseCtrl.text.isNotEmpty ? int.tryParse(_pulseCtrl.text.trim()) : null,
          charged: _charged,
          chargeAmount: _charged && _chargeCtrl.text.isNotEmpty ? double.tryParse(_chargeCtrl.text.trim()) : null,
          newPhotoPaths: _photos.map((p) => p.path).toList(),
        );
      } else {
        consultation = await service.createConsultation(
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
      }

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
                          Text(_isViewing ? 'Consultation Details' : (widget.isViewMode ? 'Edit Consultation' : 'New Consultation'), style: AppTextStyles.h2),
                          Text(widget.patientName,
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    if (_isViewing) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                        onPressed: () => setState(() {
                          _isViewing = false;
                          _isExpanded = true;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        onPressed: _confirmDelete,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                if (_isViewing)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textHint.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isExpanded = !_isExpanded),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.assignment_ind_rounded, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Consultation Details', style: AppTextStyles.h4),
                                      const SizedBox(height: 2),
                                      Text('View full patient form & attached files', style: AppTextStyles.caption),
                                    ],
                                  ),
                                ),
                                AnimatedRotation(
                                  turns: _isExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 300),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textHint),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.fastOutSlowIn,
                          alignment: Alignment.topCenter,
                          child: !_isExpanded
                              ? const SizedBox(width: double.infinity, height: 0)
                              : Container(
                                  decoration: const BoxDecoration(
                                    border: Border(top: BorderSide(color: AppColors.border)),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: _buildFormContent(),
                                ),
                        ),
                      ],
                    ),
                  )
                else
                  _buildFormContent(),

                const SizedBox(height: 28),

                if (!_isViewing)
                  AppButton(
                    label: widget.isViewMode ? 'Update Consultation' : 'Save Consultation',
                    isLoading: _isSubmitting,
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _submit,
                  ),

                if (widget.consultationId != null) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Treatment Plan Sessions', Icons.healing_rounded),
                  if (_isLoadingView)
                    const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  else if (_existingSessions.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_note_rounded, size: 48, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          Text('No active treatment plan.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                          const SizedBox(height: 16),
                          AppButton(
                            label: 'Create Treatment Plan',
                            icon: Icons.add_rounded,
                            onPressed: () async {
                              await Navigator.pushNamed(
                                context,
                                '/treatment-plan/create',
                                arguments: {
                                  'patientId': widget.patientId,
                                  'patientName': widget.patientName,
                                  'doctorId': widget.doctorId,
                                  'consultationId': widget.consultationId,
                                },
                              );
                              _loadExistingData(); // Reload sessions after returning
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    ..._existingSessions.map((session) {
                      final dt = DateTime.tryParse(session.scheduledDate) ?? DateTime.now();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/session/record',
                              arguments: {
                                'sessionId': session.id,
                                'patientId': widget.patientId,
                                'doctorId': widget.doctorId,
                              },
                            ).then((_) => _loadExistingData());
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.healing_rounded, color: AppColors.success, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('MMM d, yyyy').format(dt),
                                        style: AppTextStyles.h4,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Status: ${session.status}',
                                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Conversational / Medical ───
        _buildSectionHeader('Consulting Conversations', Icons.chat_bubble_outline_rounded),
        
        AppTextField(
          controller: _notesCtrl,
          label: 'Chief Complaint / Main Problem',
          hint: 'As discussed with the client...',
          maxLines: 3,
          readOnly: _isViewing,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _medicalHistoryCtrl,
          label: 'Medical & Treatment History',
          hint: 'Previous treatments...',
          maxLines: 2,
          readOnly: _isViewing,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _pastIllnessesCtrl,
          label: 'Past Major Illnesses / Surgeries',
          hint: 'Hospitalizations, surgeries...',
          maxLines: 2,
          readOnly: _isViewing,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _currentMedicationsCtrl,
          label: 'Current Medications',
          hint: 'Allopathic, herbal, etc.',
          maxLines: 2,
          readOnly: _isViewing,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _allergiesCtrl,
          label: 'Known Allergies / Contraindications',
          hint: 'Skin reactions, drug allergies...',
          maxLines: 2,
          readOnly: _isViewing,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _chronicDiseasesCtrl,
          label: 'Chronic Diseases',
          hint: 'Diabetes, BP, Heart, Thyroid...',
          maxLines: 2,
          readOnly: _isViewing,
        ),
        const SizedBox(height: 32),

        // ─── Lifestyle & Habits ───
        _buildSectionHeader('Lifestyle & Habits', Icons.accessibility_new_rounded),
        
        AppTextField(controller: _dietPatternCtrl, label: 'Diet Pattern', hint: 'Vegetarian, timely meals...', readOnly: _isViewing),
        const SizedBox(height: 16),
        AppTextField(controller: _sleepQualityCtrl, label: 'Sleep Quality & Duration', hint: '7 hours, disturbed...', readOnly: _isViewing),
        const SizedBox(height: 16),
        AppTextField(controller: _exerciseLevelCtrl, label: 'Exercise / Physical Activity', hint: 'Sedentary, active...', readOnly: _isViewing),
        const SizedBox(height: 16),
        AppTextField(controller: _addictionsCtrl, label: 'Smoking / Alcohol / Tobacco', hint: 'Occasional, non-smoker...', readOnly: _isViewing),
        const SizedBox(height: 16),
        AppTextField(controller: _stressLevelCtrl, label: 'Stress / Mental Health Notes', hint: 'High stress, relaxed...', maxLines: 2, readOnly: _isViewing),
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
                readOnly: _isViewing,
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
                readOnly: _isViewing,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ─── Report Files & Media ───
        _buildSectionHeader('Report Files', Icons.science_outlined),
        Text('Upload X-Rays, MRI, Blood Test Reports', style: AppTextStyles.caption),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (_existingRecord != null && _existingConsultation != null)
              ..._existingConsultation!.photos.map((p) => _remotePhotoThumb(p)),
            if (!_isViewing) ...[
              ..._photos.asMap().entries.map((e) => _photoThumb(e.key)),
              _addPhotoBtn(Icons.camera_alt_rounded, 'Camera', _pickPhoto),
              _addPhotoBtn(Icons.photo_library_rounded, 'Gallery', _pickFromGallery),
            ],
          ],
        ),
        const SizedBox(height: 32),
        
        // ─── Consent & Safety ───
        _buildSectionHeader('Consent & Safety', Icons.verified_user_outlined),
        AppTextField(
          controller: _pregnancyStatusCtrl,
          label: 'Pregnancy Status (if applicable)',
          hint: 'Months, N/A...',
          readOnly: _isViewing,
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
                onChanged: (_isViewing) ? null : (v) => setState(() => _consentGiven = v),
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
                    onChanged: (_isViewing) ? null : (v) => setState(() => _charged = v),
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
                  readOnly: _isViewing,
                ),
              ],
            ],
          ),
        ),
      ],
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

  Widget _remotePhotoThumb(String filename) {
    if (_existingRecord == null) return const SizedBox();
    final pb = ref.read(pocketbaseProvider);
    final url = pb.files.getUrl(_existingRecord!, filename).toString();

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
                Positioned(
                  top: -16,
                  right: -16,
                  child: IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.close_rounded, color: Colors.black, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Container(
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
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: AppColors.textHint),
          ),
        ),
      ),
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
