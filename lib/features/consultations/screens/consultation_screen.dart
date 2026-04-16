import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../appointments/providers/appointment_provider.dart';
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
  final String? appointmentId; // If set, mark appointment's consultation_form_saved on submit

  const ConsultationScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    this.consultationId,
    this.isViewMode = false,
    this.appointmentId, // pass to mark form saved
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
  
  // Lifestyle dropdowns
  String? _selectedDiet;
  String? _selectedSleepDuration;
  String? _selectedSleepQuality;
  String? _selectedExercise;
  String? _selectedStress;

  // Addictions Radios
  String _smoking = 'No';
  String _alcohol = 'No';
  String _tobacco = 'No';
  String _drugs = 'No';

  final List<String> _dietOptions = [
    'Standard Indian Non-Veg',
    'Lacto-Vegetarian',
    'Ovo-Vegetarian',
    'Lacto-Ovo-Vegetarian',
    'Diabetic Diet',
    'Ketogenic Diet'
  ];

  final List<String> _sleepDurationOptions = [
    'Very Short - Less than 4 hours',
    'Short - 4 to 5 hours',
    'Adequate - 6 to 7 hours',
    'Optimal - 7 to 9 hours',
    'Long - 9 to 10 hours',
    'Excessive - More than 10 hours'
  ];

  final List<String> _sleepQualityOptions = [
    'Excellent - Refreshing, uninterrupted',
    'Good - Satisfactory, minor disruptions',
    'Fair - Moderately restful, noticeable issues',
    'Poor - Frequently disrupted, non-restorative',
    'Very Poor - Chronically disturbed'
  ];

  final List<String> _exerciseOptions = [
    'Sedentary - Little to no intentional exercise',
    'Lightly Active - Light activity most days',
    'Moderately Active - 2–3 days/wk or 5k-7.5k steps',
    'Active - 3–5 days/wk moderate or 2-3 vigorous',
    'Very Active - 5–7 days/wk structured exercise',
    'Extremely Active / Athlete - High-volume training'
  ];

  final List<String> _stressOptions = [
    'None / Minimal Stress',
    'Mild Stress',
    'Moderate Stress',
    'Severe Stress',
    'Extreme / Overwhelming Stress',
    'Variable'
  ];
  
  // Consent & Gender
  String _pregnancyStatus = 'No';
  String? _patientGender;
  bool _consentGiven = false;

  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _chargeCtrl = TextEditingController();

  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoadingView = false;
  bool _draftLoaded = false;   // true once we attempted to restore draft
  bool _formSubmitted = false; // true on successful submit — prevents draft save on dispose
  RecordModel? _existingRecord;
  ConsultationModel? _existingConsultation;
  List<SessionModel> _existingSessions = [];

  late bool _isViewing;
  bool _isExpanded = false;

  /// SharedPreferences key for draft caching.
  String get _draftKey => 'consultation_draft_${widget.appointmentId ?? widget.consultationId ?? "new"}';

  @override
  void initState() {
    super.initState();
    _isViewing = widget.isViewMode;
    if (widget.consultationId == null) {
      _charged = true;
    }
    _fetchPatientGender();
    if (widget.consultationId != null) {
      _loadExistingData();
    } else if (widget.appointmentId != null) {
      // New consultation from appointment — try restoring a saved draft
      _loadDraft();
    }
  }

  /// Load a previously saved draft into the form fields.
  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || !mounted) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _notesCtrl.text              = data['notes']              ?? '';
        _medicalHistoryCtrl.text     = data['medicalHistory']     ?? '';
        _pastIllnessesCtrl.text      = data['pastIllnesses']      ?? '';
        _currentMedicationsCtrl.text = data['currentMedications'] ?? '';
        _allergiesCtrl.text          = data['allergies']          ?? '';
        _chronicDiseasesCtrl.text    = data['chronicDiseases']    ?? '';
        _bpCtrl.text                 = data['bp']                 ?? '';
        _pulseCtrl.text              = data['pulse']              ?? '';
        _chargeCtrl.text             = data['charge']             ?? '';
        _selectedDiet          = data['diet']          as String?;
        _selectedSleepDuration = data['sleepDuration'] as String?;
        _selectedSleepQuality  = data['sleepQuality']  as String?;
        _selectedExercise      = data['exercise']      as String?;
        _selectedStress        = data['stress']        as String?;
        _smoking  = data['smoking']  ?? 'No';
        _alcohol  = data['alcohol']  ?? 'No';
        _tobacco  = data['tobacco']  ?? 'No';
        _drugs    = data['drugs']    ?? 'No';
        _pregnancyStatus = data['pregnancy'] ?? 'No';
        _consentGiven    = data['consent']   ?? false;
        _charged         = data['charged']   ?? true;
        _draftLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _draftLoaded = true);
    }
  }

  /// Save current form state as a draft.
  Future<void> _saveDraft() async {
    if (widget.appointmentId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'notes':              _notesCtrl.text,
        'medicalHistory':     _medicalHistoryCtrl.text,
        'pastIllnesses':      _pastIllnessesCtrl.text,
        'currentMedications': _currentMedicationsCtrl.text,
        'allergies':          _allergiesCtrl.text,
        'chronicDiseases':    _chronicDiseasesCtrl.text,
        'bp':                 _bpCtrl.text,
        'pulse':              _pulseCtrl.text,
        'charge':             _chargeCtrl.text,
        'diet':          _selectedDiet,
        'sleepDuration': _selectedSleepDuration,
        'sleepQuality':  _selectedSleepQuality,
        'exercise':      _selectedExercise,
        'stress':        _selectedStress,
        'smoking':   _smoking,
        'alcohol':   _alcohol,
        'tobacco':   _tobacco,
        'drugs':     _drugs,
        'pregnancy': _pregnancyStatus,
        'consent':   _consentGiven,
        'charged':   _charged,
      };
      await prefs.setString(_draftKey, jsonEncode(data));
    } catch (_) {}
  }

  /// Delete the draft from SharedPreferences.
  Future<void> _clearDraft() async {
    if (widget.appointmentId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _fetchPatientGender() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final patRec = await pb.collection(PBCollections.patients).getOne(widget.patientId);
      if (mounted) {
        setState(() => _patientGender = patRec.getStringValue('gender'));
      }
    } catch (_) {}
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
      _selectedDiet = _dietOptions.contains(_existingConsultation?.dietPattern) ? _existingConsultation!.dietPattern : null;
      _selectedSleepDuration = _sleepDurationOptions.contains(_existingConsultation?.sleepQuality) ? _existingConsultation!.sleepQuality : null;
      if (_selectedSleepDuration == null && _sleepQualityOptions.contains(_existingConsultation?.sleepQuality)) {
        _selectedSleepQuality = _existingConsultation!.sleepQuality;
      }
      _selectedExercise = _exerciseOptions.contains(_existingConsultation?.exerciseLevel) ? _existingConsultation!.exerciseLevel : null;
      _selectedStress = _stressOptions.contains(_existingConsultation?.stressLevel) ? _existingConsultation!.stressLevel : null;
      
      if (_existingConsultation?.addictions != null) {
        final addStr = _existingConsultation!.addictions!;
        _smoking = addStr.contains('Smoking: Yes') ? 'Yes' : 'No';
        _alcohol = addStr.contains('Alcohol: Yes') ? 'Yes' : 'No';
        _tobacco = addStr.contains('Tobacco Chewing: Yes') ? 'Yes' : 'No';
        _drugs = addStr.contains('Recreational Drugs: Yes') ? 'Yes' : 'No';
      }
      
      _pregnancyStatus = (_existingConsultation?.pregnancyStatus?.isNotEmpty == true && _existingConsultation?.pregnancyStatus != 'No') ? 'Yes' : 'No';
      _bpCtrl.text = _existingConsultation?.bpLevel ?? '';
      _pulseCtrl.text = _existingConsultation?.pulse?.toString() ?? '';
      _chargeCtrl.text = _existingConsultation?.chargeAmount?.toString() ?? '';
      _charged = _existingConsultation?.charged ?? false;
      _consentGiven = _existingConsultation?.consentGiven ?? false;

      // Load associated sessions via treatment_plans
      // (sessions don't have a direct 'consultation' field — they're linked via treatment_plan)
      final List<SessionModel> allSessions = [];
      try {
        final plansRes = await pb.collection(PBCollections.treatmentPlans).getList(
          filter: 'consultation = "${widget.consultationId}"',
          perPage: 20,
        );
        for (final plan in plansRes.items) {
          final sessRes = await pb.collection(PBCollections.sessions).getList(
            filter: 'treatment_plan = "${plan.id}"',
            sort: 'session_number',
            perPage: 200,
          );
          allSessions.addAll(sessRes.items.map((e) => SessionModel.fromRecord(e)));
        }
      } catch (_) {}
      _existingSessions = allSessions;

    } catch (e) {
      debugPrint('Error loading view mode data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingView = false);
    }
  }

  @override
  void dispose() {
    // Save draft if the form was opened for a new consultation but not submitted
    if (!_formSubmitted && widget.appointmentId != null && !_isViewing) {
      _saveDraft(); // fire-and-forget is fine here
    }
    _notesCtrl.dispose();
    _medicalHistoryCtrl.dispose();
    _pastIllnessesCtrl.dispose();
    _currentMedicationsCtrl.dispose();
    _allergiesCtrl.dispose();
    _chronicDiseasesCtrl.dispose();
    _bpCtrl.dispose();
    _pulseCtrl.dispose();
    _chargeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (img != null && mounted) setState(() => _photos.add(img));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final imgs = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (imgs.isNotEmpty && mounted) setState(() => _photos.addAll(imgs));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmEndConsultation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.stop_circle_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('End Consultation?')),
          ],
        ),
        content: const Text(
          'This will:\n'
          '• Cancel all remaining upcoming sessions\n'
          '• Remove them from the appointment schedule\n'
          '• Mark this consultation as completed\n\n'
          'Already completed sessions will be preserved. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Consultation'),
          ),
        ],
      ),
    );

    if (confirm == true && widget.consultationId != null && mounted) {
      try {
        final service = ref.read(treatmentServiceProvider);
        await service.endConsultation(widget.consultationId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Consultation ended. All future sessions cancelled.'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to end consultation: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_notesCtrl.text.trim().isEmpty ||
        _medicalHistoryCtrl.text.trim().isEmpty ||
        _pastIllnessesCtrl.text.trim().isEmpty ||
        _currentMedicationsCtrl.text.trim().isEmpty ||
        _allergiesCtrl.text.trim().isEmpty ||
        _chronicDiseasesCtrl.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all consulting conversations fields.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (!_consentGiven) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consent must be given to proceed.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(treatmentServiceProvider);

      ConsultationModel consultation;
      String resolvedId = widget.consultationId ?? '';

      // If no ID was passed (shouldn't happen, but safety net): look up ongoing first
      if (resolvedId.isEmpty) {
        final pb = ref.read(pocketbaseProvider);
        final existing = await pb.collection(PBCollections.consultations).getList(
          filter: 'patient = "${widget.patientId}" && doctor = "${widget.doctorId}" && status = "ongoing"',
          perPage: 1,
          sort: '-created',
        );
        if (existing.items.isNotEmpty) {
          resolvedId = existing.items.first.id;
        }
      }

      if (resolvedId.isNotEmpty) {
        // Always UPDATE the existing consultation — never create a duplicate
        consultation = await service.updateConsultation(
          consultationId: resolvedId,
          notes: _notesCtrl.text.trim(),
          chiefComplaint: _notesCtrl.text.trim(),
          medicalHistory: _medicalHistoryCtrl.text.trim(),
          pastIllnesses: _pastIllnessesCtrl.text.trim(),
          currentMedications: _currentMedicationsCtrl.text.trim(),
          allergies: _allergiesCtrl.text.trim(),
          chronicDiseases: _chronicDiseasesCtrl.text.trim(),
          dietPattern: _selectedDiet ?? '',
          sleepQuality: [if (_selectedSleepDuration != null) _selectedSleepDuration, if (_selectedSleepQuality != null) _selectedSleepQuality].join(' | '),
          exerciseLevel: _selectedExercise ?? '',
          addictions: 'Smoking: $_smoking, Alcohol: $_alcohol, Tobacco Chewing: $_tobacco, Recreational Drugs: $_drugs',
          stressLevel: _selectedStress ?? '',
          pregnancyStatus: _pregnancyStatus,
          consentGiven: _consentGiven,
          bpLevel: _bpCtrl.text.trim(),
          pulse: _pulseCtrl.text.isNotEmpty ? int.tryParse(_pulseCtrl.text.trim()) : null,
          charged: _charged,
          chargeAmount: _charged && _chargeCtrl.text.isNotEmpty ? double.tryParse(_chargeCtrl.text.trim()) : null,
          newPhotoPaths: _photos.map((p) => p.path).toList(),
        );
      } else {
        // No consultation ID and no ongoing consultation found —
        // this shouldn't happen with the current flow (we always pre-create before opening this screen).
        throw Exception('No consultation record found. Please go back and start the consultation again.');
      }


      // Mark form saved + record consultation_end_time on the appointment
      if (widget.appointmentId != null) {
        try {
          final aptService = ref.read(appointmentServiceProvider);
          await aptService.markConsultationEndTime(widget.appointmentId!);
        } catch (_) {}
      }

      // Clear the draft now that the form is fully submitted
      _formSubmitted = true;
      await _clearDraft();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Consultation recorded!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Future<void> _rescheduleSession(SessionModel session) async {
    final dt = DateTime.tryParse(session.scheduledDate) ?? DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: dt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (newDate == null || !mounted) return;

    // Parse existing time or default
    TimeOfDay initialTime = const TimeOfDay(hour: 10, minute: 0);
    if (session.scheduledTime != null && session.scheduledTime!.contains(':')) {
      final parts = session.scheduledTime!.split(':');
      initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    
    final newTime = await showTimePicker(context: context, initialTime: initialTime);
    if (newTime == null || !mounted) return;

    final newDateStr = '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
    final newTimeStr = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';

    try {
      final service = ref.read(treatmentServiceProvider);
      await service.rescheduleSession(
        sessionId: session.id,
        newDate: newDateStr,
        newTime: newTimeStr,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session ${session.sessionNumber} rescheduled to ${DateFormat('MMM d, yyyy').format(newDate)} at ${newTime.format(context)}'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadExistingData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reschedule: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _cancelSingleSession(SessionModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Session #${session.sessionNumber}?'),
        content: const Text('This will cancel this session and remove it from the appointment schedule.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Session'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        final service = ref.read(treatmentServiceProvider);
        await service.cancelSession(session.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Session ${session.sessionNumber} cancelled.'), backgroundColor: AppColors.success),
          );
          _loadExistingData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
          );
        }
      }
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
                    if (_isViewing && _existingConsultation?.status != ConsultationStatus.completed) ...[ 
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                        onPressed: () => setState(() {
                          _isViewing = false;
                          _isExpanded = true;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop_circle_rounded, color: AppColors.warning),
                        tooltip: 'End Consultation',
                        onPressed: _confirmEndConsultation,
                      ),
                    ] else if (_isViewing) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                        onPressed: () => setState(() {
                          _isViewing = false;
                          _isExpanded = true;
                        }),
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
        
        _buildDropdown('Diet Pattern', 'Select your usual diet', _selectedDiet, _dietOptions, (v) => setState(() => _selectedDiet = v)),
        const SizedBox(height: 16),
        _buildDropdown('Sleep Duration', 'Hours of sleep per night', _selectedSleepDuration, _sleepDurationOptions, (v) => setState(() => _selectedSleepDuration = v)),
        const SizedBox(height: 16),
        _buildDropdown('Sleep Quality', 'How well do you sleep?', _selectedSleepQuality, _sleepQualityOptions, (v) => setState(() => _selectedSleepQuality = v)),
        const SizedBox(height: 16),
        _buildDropdown('Exercise / Physical Activity', 'Level of activity', _selectedExercise, _exerciseOptions, (v) => setState(() => _selectedExercise = v)),
        const SizedBox(height: 32),

        Text('Substance Use', style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildRadioGroup('Smoking', _smoking, (v) => setState(() => _smoking = v!)),
        _buildRadioGroup('Alcohol', _alcohol, (v) => setState(() => _alcohol = v!)),
        _buildRadioGroup('Tobacco Chewing', _tobacco, (v) => setState(() => _tobacco = v!)),
        _buildRadioGroup('Recreational Drugs', _drugs, (v) => setState(() => _drugs = v!)),
        const SizedBox(height: 16),

        _buildDropdown('Stress / Mental Health Notes', 'Current stress level', _selectedStress, _stressOptions, (v) => setState(() => _selectedStress = v)),
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
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                ],
                prefixIcon: const Icon(Icons.favorite_outline_rounded,
                    color: AppColors.error, size: 18),
                readOnly: _isViewing,
                onChanged: (val) {
                  if (_isViewing) return;
                  // Auto insert slash after 2 or 3 digits
                  String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                  if (clean.length >= 3 && !val.contains('/')) {
                    if (clean.length == 3) {
                      _bpCtrl.text = '$clean/';
                    } else if (clean.length > 3) {
                      _bpCtrl.text = '${clean.substring(0, 3)}/${clean.substring(3)}';
                    }
                    _bpCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _bpCtrl.text.length));
                  }
                },
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
        if (_patientGender != 'Male') ...[
          Text('Pregnancy Status', style: AppTextStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildRadioGroup('Are you currently pregnant?', _pregnancyStatus, (v) => setState(() => _pregnancyStatus = v!)),
          const SizedBox(height: 16),
        ],
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
            child: kIsWeb 
                ? Image.network(
                    _photos[index].path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: AppColors.textHint),
                  )
                : Image.file(
                    File(_photos[index].path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded, color: AppColors.textHint),
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
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String hint, String? value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _isViewing ? AppColors.divider : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text(hint, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
              items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: AppTextStyles.bodyMedium))).toList(),
              onChanged: _isViewing ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioGroup(String label, String groupValue, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _isViewing ? null : () => onChanged('Yes'),
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'Yes',
                      groupValue: groupValue,
                      onChanged: _isViewing ? null : onChanged,
                      activeColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    const Text('Yes'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _isViewing ? null : () => onChanged('No'),
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'No',
                      groupValue: groupValue,
                      onChanged: _isViewing ? null : onChanged,
                      activeColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    const Text('No'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
