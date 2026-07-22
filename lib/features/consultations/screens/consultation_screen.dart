import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/features/appointments/providers/appointment_provider.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/treatments/providers/treatment_provider.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/consultations/models/consultation_model.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/date_picker_helper.dart';
import 'package:pms_app/core/services/idle_reminder_service.dart';
import 'package:pms_app/core/services/photo_quota_service.dart';
import 'package:pms_app/core/widgets/photo_limit_dialog.dart';
import '../../auth/providers/auth_provider.dart' show authProvider;
import '../../../core/services/auth_service.dart' show UserRole;
import 'package:pms_app/core/providers/pocketbase_provider.dart';



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
  bool _bypassChiefComplaintCheck = false;

  final _notesCtrl = TextEditingController(); // Chief Complaint / Main Problem
  final _currentMedicationsCtrl = TextEditingController();
  
  // Previous Treatments
  List<String> _selectedPreviousTreatments = [];
  
  // Pain Areas
  List<String> _selectedPainAreas = [];
  final _painOtherCtrl = TextEditingController();

  // Past Major Illnesses
  List<String> _selectedPastIllnesses = [];
  final _illnessOtherCtrl = TextEditingController();

  // Past Major Surgeries
  List<String> _selectedPastSurgeries = [];
  final _surgeryOtherCtrl = TextEditingController();

  // Known Allergies
  bool _hasDrugAllergy = false;
  bool _hasEnvAllergy = false;
  bool _hasFoodAllergy = false;
  bool _hasOtherAllergy = false;
  final _drugAllergyCtrl = TextEditingController();
  final _envAllergyCtrl = TextEditingController();
  final _foodAllergyCtrl = TextEditingController();
  final _otherAllergyCtrl = TextEditingController();

  // Chronic Diseases
  List<String> _selectedChronicDiseases = [];
  final _chronicOtherCtrl = TextEditingController();
  
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
    'Lacto-Ovo-Vegetarian',
    'Vegan+',
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
  ];
  
  // Consent & Gender
  String _pregnancyStatus = 'No';
  int? _pregnancyMonths;
  String? _patientGender;
  bool _consentGiven = false;

  final _bpCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _sugarCtrl = TextEditingController();
  final _vitD3Ctrl = TextEditingController();
  final _vitB12Ctrl = TextEditingController();
  final _thyroidCtrl = TextEditingController();
  final _cholesterolCtrl = TextEditingController();
  
  final _chargeCtrl = TextEditingController();

  // Diagnosis fields
  final _acupunctureDiagnosisCtrl = TextEditingController();
  final _eyeDiagnosisCtrl = TextEditingController();
  final _pulseDiagnosisCtrl = TextEditingController();

  // Corona vaccination
  bool _coronaVaccinated = false;

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

  String? _consultationId;

  @override
  void initState() {
    super.initState();
    _isViewing = widget.isViewMode;
    _consultationId = widget.consultationId;
    if (_consultationId == null) {
      _charged = true;
    }
    
    _initData();
  }

  Future<void> _initData() async {
    _fetchPatientGender();
    if (_consultationId == null) {
      if (mounted) setState(() => _isLoadingView = true);
      try {
        final service = ref.read(appointmentServiceProvider);
        if (widget.appointmentId != null) {
          AppointmentModel? apt;
          try {
            apt = ref.read(appointmentListProvider).appointments.firstWhere((a) => a.id == widget.appointmentId);
          } catch (_) {}
          if (apt == null) {
            final record = await ref.read(pocketbaseProvider).collection(PBCollections.appointments).getOne(widget.appointmentId!);
            apt = AppointmentModel.fromRecord(record);
          }
          final (id, isNew) = await service.getOrCreateConsultationForAppointment(apt);
          _consultationId = id;
          if (isNew || apt.consultationStartTime == null) {
            await service.setConsultationStartTime(apt.id);
          }
        } else {
          final newC = await service.createConsultation(
            widget.patientId,
            widget.doctorId,
          );
          _consultationId = newC.id;
        }
      } catch (e) {
        debugPrint('Error getting/creating consultation: $e');
      }
    }

    if (_consultationId != null) {
      await _loadExistingData();
    } else {
      await _loadDraft();
    }

    // Start idle tracking for this consultation
    final trackingId = _consultationId ?? widget.appointmentId ?? 'consultation_${widget.patientId}';
    if (!_isViewing) {
      IdleReminderService.instance.startTracking(
        id: trackingId,
        type: 'consultation',
        displayName: widget.patientName,
      );
      _notesCtrl.addListener(_onInteraction);
      _currentMedicationsCtrl.addListener(_onInteraction);
      _painOtherCtrl.addListener(_onInteraction);
      _illnessOtherCtrl.addListener(_onInteraction);
      _surgeryOtherCtrl.addListener(_onInteraction);
      _drugAllergyCtrl.addListener(_onInteraction);
      _envAllergyCtrl.addListener(_onInteraction);
      _foodAllergyCtrl.addListener(_onInteraction);
      _chronicOtherCtrl.addListener(_onInteraction);
      _bpCtrl.addListener(_onInteraction);
      _pulseCtrl.addListener(_onInteraction);
      _sugarCtrl.addListener(_onInteraction);
      _vitD3Ctrl.addListener(_onInteraction);
      _vitB12Ctrl.addListener(_onInteraction);
      _thyroidCtrl.addListener(_onInteraction);
      _cholesterolCtrl.addListener(_onInteraction);
      _chargeCtrl.addListener(_onInteraction);
    }
  }

  void _onInteraction() {
    final trackingId = widget.consultationId ?? widget.appointmentId ?? 'consultation_${widget.patientId}';
    IdleReminderService.instance.recordInteraction(trackingId);
    if (_notesCtrl.text.trim().isNotEmpty && _bypassChiefComplaintCheck) {
      setState(() {
        _bypassChiefComplaintCheck = false;
      });
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
        _currentMedicationsCtrl.text = data['currentMedications'] ?? '';
        
        _selectedPreviousTreatments = List<String>.from(data['previousTreatments'] ?? []);
        _selectedPainAreas          = List<String>.from(data['painAreas'] ?? []);
        _painOtherCtrl.text         = data['painOther'] ?? '';
        
        _selectedPastIllnesses      = List<String>.from(data['pastIllnesses'] ?? []);
        _illnessOtherCtrl.text      = data['illnessOther'] ?? '';
        
        _selectedPastSurgeries      = List<String>.from(data['pastSurgeries'] ?? []);
        _surgeryOtherCtrl.text      = data['surgeryOther'] ?? '';
        
        _hasDrugAllergy             = data['hasDrugAllergy'] ?? false;
        _hasEnvAllergy              = data['hasEnvAllergy'] ?? false;
        _hasFoodAllergy             = data['hasFoodAllergy'] ?? false;
        _hasOtherAllergy            = data['hasOtherAllergy'] ?? false;
        _drugAllergyCtrl.text       = data['drugAllergy'] ?? '';
        _envAllergyCtrl.text        = data['envAllergy'] ?? '';
        _foodAllergyCtrl.text       = data['foodAllergy'] ?? '';
        _otherAllergyCtrl.text      = data['otherAllergy'] ?? '';
        
        _selectedChronicDiseases    = List<String>.from(data['chronicDiseases'] ?? []);
        _chronicOtherCtrl.text      = data['chronicOther'] ?? '';

        _bpCtrl.text                 = data['bp']                 ?? '';
        _pulseCtrl.text              = data['pulse']              ?? '';
        _sugarCtrl.text              = data['sugar']              ?? '';
        _vitD3Ctrl.text              = data['vitD3']              ?? '';
        _vitB12Ctrl.text             = data['vitB12']             ?? '';
        _thyroidCtrl.text            = data['thyroid']            ?? '';
        _cholesterolCtrl.text        = data['cholesterol']        ?? '';
        
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
        _pregnancyMonths = data['pregnancyMonths'] as int?;
        _consentGiven    = data['consent']   ?? false;
        _charged         = data['charged']   ?? true;
        _acupunctureDiagnosisCtrl.text = data['acupunctureDiagnosis'] ?? '';
        _eyeDiagnosisCtrl.text         = data['eyeDiagnosis']         ?? '';
        _pulseDiagnosisCtrl.text       = data['pulseDiagnosis']       ?? '';
        _coronaVaccinated              = data['coronaVaccinated']     ?? false;
        _draftLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _draftLoaded = true);
    }
  }

  /// Save current form state as a draft.
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'notes':              _notesCtrl.text,
        'currentMedications': _currentMedicationsCtrl.text,
        
        'previousTreatments': _selectedPreviousTreatments,
        'painAreas':          _selectedPainAreas,
        'painOther':          _painOtherCtrl.text,
        'pastIllnesses':      _selectedPastIllnesses,
        'illnessOther':       _illnessOtherCtrl.text,
        'pastSurgeries':      _selectedPastSurgeries,
        'surgeryOther':       _surgeryOtherCtrl.text,
        
        'hasDrugAllergy':     _hasDrugAllergy,
        'hasEnvAllergy':      _hasEnvAllergy,
        'hasFoodAllergy':     _hasFoodAllergy,
        'hasOtherAllergy':    _hasOtherAllergy,
        'drugAllergy':        _drugAllergyCtrl.text,
        'envAllergy':         _envAllergyCtrl.text,
        'foodAllergy':        _foodAllergyCtrl.text,
        'otherAllergy':       _otherAllergyCtrl.text,
        
        'chronicDiseases':    _selectedChronicDiseases,
        'chronicOther':       _chronicOtherCtrl.text,
        
        'bp':                 _bpCtrl.text,
        'pulse':              _pulseCtrl.text,
        'sugar':              _sugarCtrl.text,
        'vitD3':              _vitD3Ctrl.text,
        'vitB12':             _vitB12Ctrl.text,
        'thyroid':            _thyroidCtrl.text,
        'cholesterol':        _cholesterolCtrl.text,
        
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
        'pregnancyMonths': _pregnancyMonths,
        'consent':   _consentGiven,
        'charged':   _charged,
        'acupunctureDiagnosis': _acupunctureDiagnosisCtrl.text,
        'eyeDiagnosis':         _eyeDiagnosisCtrl.text,
        'pulseDiagnosis':       _pulseDiagnosisCtrl.text,
        'coronaVaccinated':     _coronaVaccinated,
      };
      await prefs.setString(_draftKey, jsonEncode(data));
    } catch (_) {}
  }

  /// Delete the draft from SharedPreferences.
  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  List<String> _parseJsonArray(String? val) {
    if (val == null || val.isEmpty) return [];
    try {
      final decoded = jsonDecode(val);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
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
      final record = await pb.collection(PBCollections.consultations).getOne(_consultationId!);
      _existingRecord = record;
      _existingConsultation = ConsultationModel.fromRecord(record);

      // Pre-fill fields for reference (if wanted, though readOnly makes them uneditable)
      _notesCtrl.text = _existingConsultation?.chiefComplaint ?? _existingConsultation?.notes ?? '';
      _currentMedicationsCtrl.text = _existingConsultation?.currentMedications ?? '';
      
      final c = _existingConsultation;
      if (c != null) {
        _selectedPreviousTreatments = _parseJsonArray(c.previousTreatments);
        _selectedPainAreas          = _parseJsonArray(c.painAreas);
        _selectedPastIllnesses      = _parseJsonArray(c.pastIllnesses);
        _selectedPastSurgeries      = _parseJsonArray(c.pastSurgeries);
        _selectedChronicDiseases    = _parseJsonArray(c.chronicDiseases);
        
        // Handle allergies json
        try {
           if (c.allergies != null && c.allergies!.isNotEmpty) {
             final Map<String, dynamic> algs = jsonDecode(c.allergies!);
             _hasDrugAllergy = algs['hasDrug'] ?? false;
             _hasEnvAllergy  = algs['hasEnv'] ?? false;
             _hasFoodAllergy = algs['hasFood'] ?? false;
             _hasOtherAllergy = algs['hasOther'] ?? false;
             _drugAllergyCtrl.text = algs['drugDesc'] ?? '';
             _envAllergyCtrl.text  = algs['envDesc'] ?? '';
             _foodAllergyCtrl.text = algs['foodDesc'] ?? '';
             _otherAllergyCtrl.text = algs['otherDesc'] ?? '';
           }
        } catch (_) {}

        _sugarCtrl.text      = c.sugarLevel ?? '';
        _vitD3Ctrl.text      = c.vitD3 ?? '';
        _vitB12Ctrl.text     = c.vitB12 ?? '';
        _thyroidCtrl.text    = c.thyroidLevel ?? '';
        _cholesterolCtrl.text = c.cholesterolLevel ?? '';
      }

      _selectedDiet = _dietOptions.contains(_existingConsultation?.dietPattern) ? _existingConsultation!.dietPattern : null;
      _selectedSleepDuration = _sleepDurationOptions.contains(_existingConsultation?.sleepQuality) ? _existingConsultation!.sleepQuality : null;
      if (_selectedSleepDuration == null && _sleepQualityOptions.contains(_existingConsultation?.sleepQuality)) {
        _selectedSleepQuality = _existingConsultation!.sleepQuality;
      }
      _selectedExercise = _exerciseOptions.contains(_existingConsultation?.exerciseLevel) ? _existingConsultation!.exerciseLevel : null;
      
      // Load stress - since we removed 'Variable' we just check if it's in the valid list
      // Note: we fetch stressLevel via record data since it's removed from model
      final stressVal = record.getStringValue('stress_level');
      _selectedStress = _stressOptions.contains(stressVal) ? stressVal : null;

      
      if (_existingConsultation?.addictions != null) {
        final addStr = _existingConsultation!.addictions!;
        _smoking = addStr.contains('Smoking: Yes') ? 'Yes' : 'No';
        _alcohol = addStr.contains('Alcohol: Yes') ? 'Yes' : 'No';
        _tobacco = addStr.contains('Tobacco Chewing: Yes') ? 'Yes' : 'No';
        _drugs = addStr.contains('Recreational Drugs: Yes') ? 'Yes' : 'No';
      }
      
      final rawPregnancy = _existingConsultation?.pregnancyStatus;
      _pregnancyStatus = (rawPregnancy?.isNotEmpty == true && rawPregnancy != 'No') ? 'Yes' : 'No';
      // Parse months from stored value like 'Yes (5 months)'
      final monthMatch = RegExp(r'Yes \((\d+) months\)').firstMatch(rawPregnancy ?? '');
      if (monthMatch != null) _pregnancyMonths = int.tryParse(monthMatch.group(1)!);
      _bpCtrl.text = _existingConsultation?.bpLevel ?? '';
      _pulseCtrl.text = _existingConsultation?.pulse?.toString() ?? '';
      _chargeCtrl.text = _existingConsultation?.chargeAmount?.toString() ?? '';
      _charged = _existingConsultation?.charged ?? false;
      _consentGiven = _existingConsultation?.consentGiven ?? false;
      _acupunctureDiagnosisCtrl.text = _existingConsultation?.acupunctureDiagnosis ?? '';
      _eyeDiagnosisCtrl.text = _existingConsultation?.eyeDiagnosis ?? '';
      _pulseDiagnosisCtrl.text = _existingConsultation?.pulseDiagnosis ?? '';
      _coronaVaccinated = _existingConsultation?.coronaVaccinated ?? false;

      // Load associated sessions via treatment_plans
      // (sessions don't have a direct 'consultation' field — they're linked via treatment_plan)
      final List<SessionModel> allSessions = [];
      try {
        final plansRes = await pb.collection(PBCollections.treatmentPlans).getList(
          filter: 'consultation = "$_consultationId"',
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
      if (!_isViewing) {
        // Restore any unsaved formulated draft changes on top
        await _loadDraft();
      }
    }
  }

  @override
  void dispose() {
    // Save draft if the form was opened for a consultation but not submitted
    if (!_formSubmitted && !_isViewing) {
      _saveDraft(); // fire-and-forget is fine here
    }
    _notesCtrl.dispose();
    _currentMedicationsCtrl.dispose();
    
    if (!_isViewing) {
      _notesCtrl.removeListener(_onInteraction);
      _currentMedicationsCtrl.removeListener(_onInteraction);
      _painOtherCtrl.removeListener(_onInteraction);
      _illnessOtherCtrl.removeListener(_onInteraction);
      _surgeryOtherCtrl.removeListener(_onInteraction);
      _drugAllergyCtrl.removeListener(_onInteraction);
      _envAllergyCtrl.removeListener(_onInteraction);
      _foodAllergyCtrl.removeListener(_onInteraction);
      _chronicOtherCtrl.removeListener(_onInteraction);
      _bpCtrl.removeListener(_onInteraction);
      _pulseCtrl.removeListener(_onInteraction);
      _sugarCtrl.removeListener(_onInteraction);
      _vitD3Ctrl.removeListener(_onInteraction);
      _vitB12Ctrl.removeListener(_onInteraction);
      _thyroidCtrl.removeListener(_onInteraction);
      _cholesterolCtrl.removeListener(_onInteraction);
      _chargeCtrl.removeListener(_onInteraction);
    }
    _painOtherCtrl.dispose();
    _illnessOtherCtrl.dispose();
    _surgeryOtherCtrl.dispose();
    
    _drugAllergyCtrl.dispose();
    _envAllergyCtrl.dispose();
    _foodAllergyCtrl.dispose();
    
    _chronicOtherCtrl.dispose();
    
    _bpCtrl.dispose();
    _pulseCtrl.dispose();
    _sugarCtrl.dispose();
    _vitD3Ctrl.dispose();
    _vitB12Ctrl.dispose();
    _thyroidCtrl.dispose();
    _cholesterolCtrl.dispose();
    
    _chargeCtrl.dispose();
    // Stop idle tracking
    final trackingId = widget.consultationId ?? widget.appointmentId ?? 'consultation_${widget.patientId}';
    IdleReminderService.instance.stopTracking(trackingId);
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    // ── Quota check ──
    final clinicId = ref.read(authProvider).clinicId;
    if (clinicId != null) {
      try {
        final quota = ref.read(photoQuotaServiceProvider);
        if (!await quota.canUpload(clinicId, 1)) {
          if (mounted) {
            final (used, limit) = await quota.getQuota(clinicId);
            showPhotoLimitDialog(context, used: used, limit: limit,
              isClinicAdmin: ref.read(authProvider).role == UserRole.clinic);
          }
          return;
        }
      } catch (_) {}
    }
    try {
      final img = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );
      if (img != null && mounted) {
        final compressed = await ImageHelper.compressToWebP(img);
        if (compressed != null && mounted) {
          setState(() => _photos.add(compressed));
          _onInteraction();
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Camera error: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    // ── Quota check ──
    final clinicId = ref.read(authProvider).clinicId;
    if (clinicId != null) {
      try {
        final quota = ref.read(photoQuotaServiceProvider);
        if (!await quota.canUpload(clinicId, 1)) {
          if (mounted) {
            final (used, limit) = await quota.getQuota(clinicId);
            showPhotoLimitDialog(context, used: used, limit: limit,
              isClinicAdmin: ref.read(authProvider).role == UserRole.clinic);
          }
          return;
        }
      } catch (_) {}
    }
    try {
      final imgs = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );
      if (imgs.isNotEmpty && mounted) {
        // Check quota for batch
        if (clinicId != null) {
          try {
            final quota = ref.read(photoQuotaServiceProvider);
            if (!await quota.canUpload(clinicId, imgs.length)) {
              final remaining = await quota.getRemainingQuota(clinicId);
              if (remaining <= 0) {
                final (used, limit) = await quota.getQuota(clinicId);
                if (mounted) showPhotoLimitDialog(context, used: used, limit: limit,
                  isClinicAdmin: ref.read(authProvider).role == UserRole.clinic);
                return;
              }
              if (mounted) {
                AppToast.show('Only $remaining photo(s) remaining in your quota. Selecting first $remaining.', type: ToastType.warning);
              }
              // Trim to remaining quota
              imgs.removeRange(remaining, imgs.length);
            }
          } catch (_) {}
        }
        final compressedList = <XFile>[];
        for (final file in imgs) {
          final comp = await ImageHelper.compressToWebP(file);
          if (comp != null) {
            compressedList.add(comp);
          }
        }
        if (compressedList.isNotEmpty && mounted) {
          setState(() => _photos.addAll(compressedList));
          _onInteraction();
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Gallery error: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _confirmEndConsultation() async {
    // Capture navigator before async gap — fixes Vivo/iQOO devices
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.stop_circle_rounded, color: context.colors.warning, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('End Treatment?')),
          ],
        ),
        content: const Text(
          'This will:\n'
          '• Cancel all remaining treatment & maintenance sessions\n'
          '• Remove them from the appointment schedule\n'
          '• Mark this consultation as completed\n\n'
          'Already completed sessions will be preserved. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.warning, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('End Treatment'),
          ),
        ],
      ),
    );

    if (confirm == true && _consultationId != null && mounted) {
      try {
        final service = ref.read(treatmentServiceProvider);
        await service.endTreatment(_consultationId!);
        if (mounted) {
          AppToast.show('Treatment ended. All pending sessions cancelled.', type: ToastType.success);
          navigator.pop();
        }
      } catch (e) {
        if (mounted) {
          AppToast.show('Failed to end treatment: $e', type: ToastType.error);
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture navigator before async gap — fixes Vivo/iQOO devices
    final navigator = Navigator.of(context);

    final isDesktop = MediaQuery.of(context).size.width >= 900;
    if (_notesCtrl.text.trim().isEmpty) {
      if (isDesktop) {
        if (!_bypassChiefComplaintCheck) {
          final proceed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _ChiefComplaintWarningDialog(),
          );
          if (proceed == true) {
            _bypassChiefComplaintCheck = true;
          } else {
            return;
          }
        }
      } else {
        if (mounted) {
          AppToast.show('Please fill out the Chief Complaint field.', type: ToastType.error);
        }
        return;
      }
    }

    if (!_consentGiven) {
      if (mounted) {
        AppToast.show('Consent must be given to proceed.', type: ToastType.error);
      }
      return;
    }

    // Validate charge amount
    if (_charged && _chargeCtrl.text.trim().isEmpty) {
      if (mounted) {
        AppToast.show('Please enter the consultation fee amount or toggle off charging.', type: ToastType.error);
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(treatmentServiceProvider);

      ConsultationModel consultation;
      String resolvedId = _consultationId ?? '';

      // If no ID was passed (shouldn't happen, but safety net): look up ongoing first
      if (resolvedId.isEmpty) {
        final pb = ref.read(pocketbaseProvider);
        final existing = await pb.collection(PBCollections.consultations).getList(
          filter: 'patient = "${widget.patientId}" && doctor = "${widget.doctorId}" && status = "ongoing"',
          perPage: 1,
        );
        if (existing.items.isNotEmpty) {
          resolvedId = existing.items.first.id;
        }
      }

      if (resolvedId.isNotEmpty) {
        // Build JSON strings for complex fields
        final allergiesJson = jsonEncode({
          'hasDrug': _hasDrugAllergy,
          'hasEnv': _hasEnvAllergy,
          'hasFood': _hasFoodAllergy,
          'hasOther': _hasOtherAllergy,
          'drugDesc': _drugAllergyCtrl.text.trim(),
          'envDesc': _envAllergyCtrl.text.trim(),
          'foodDesc': _foodAllergyCtrl.text.trim(),
          'otherDesc': _otherAllergyCtrl.text.trim(),
        });

        consultation = await service.updateConsultation(
          consultationId: resolvedId,
          status: 'completed',
          notes: _notesCtrl.text.trim(),
          chiefComplaint: _notesCtrl.text.trim(),
          currentMedications: _currentMedicationsCtrl.text.trim(),
          
          previousTreatments: jsonEncode(_selectedPreviousTreatments),
          painAreas: jsonEncode([..._selectedPainAreas, if (_painOtherCtrl.text.isNotEmpty) 'Other: ${_painOtherCtrl.text}']),
          pastIllnesses: jsonEncode([..._selectedPastIllnesses, if (_illnessOtherCtrl.text.isNotEmpty) 'Other: ${_illnessOtherCtrl.text}']),
          pastSurgeries: jsonEncode([..._selectedPastSurgeries, if (_surgeryOtherCtrl.text.isNotEmpty) 'Other: ${_surgeryOtherCtrl.text}']),
          chronicDiseases: jsonEncode([..._selectedChronicDiseases, if (_chronicOtherCtrl.text.isNotEmpty) 'Other: ${_chronicOtherCtrl.text}']),
          allergies: allergiesJson,
          
          dietPattern: _selectedDiet ?? '',
          sleepQuality: [if (_selectedSleepDuration != null) _selectedSleepDuration, if (_selectedSleepQuality != null) _selectedSleepQuality].join(' | '),
          exerciseLevel: _selectedExercise ?? '',
          addictions: 'Smoking: $_smoking, Alcohol: $_alcohol, Tobacco Chewing: $_tobacco, Recreational Drugs: $_drugs',
          
          pregnancyStatus: _pregnancyStatus == 'Yes' && _pregnancyMonths != null
              ? 'Yes ($_pregnancyMonths months)'
              : _pregnancyStatus,
          consentGiven: _consentGiven,
          
          bpLevel: _bpCtrl.text.trim(),
          pulse: _pulseCtrl.text.isNotEmpty ? int.tryParse(_pulseCtrl.text.trim()) : null,
          sugarLevel: _sugarCtrl.text.trim(),
          vitD3: _vitD3Ctrl.text.trim(),
          vitB12: _vitB12Ctrl.text.trim(),
          thyroidLevel: _thyroidCtrl.text.trim(),
          cholesterolLevel: _cholesterolCtrl.text.trim(),
          
          charged: _charged,
          chargeAmount: _charged && _chargeCtrl.text.isNotEmpty ? int.tryParse(_chargeCtrl.text.trim()) : null,
          acupunctureDiagnosis: _acupunctureDiagnosisCtrl.text.trim(),
          eyeDiagnosis: _eyeDiagnosisCtrl.text.trim(),
          pulseDiagnosis: _pulseDiagnosisCtrl.text.trim(),
          coronaVaccinated: _coronaVaccinated,
          newPhotos: _photos,
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

      // ── Increment photo quota ──
      if (_photos.isNotEmpty) {
        final clinicId = ref.read(authProvider).clinicId;
        if (clinicId != null) {
          try {
            await ref.read(photoQuotaServiceProvider).incrementUsage(clinicId, _photos.length);
          } catch (_) {}
        }
      }

      if (mounted) {
        AppToast.show('Consultation recorded!', type: ToastType.success);
        // Return the consultation so the caller can create a treatment plan
        navigator.pop(consultation);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Error: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _rescheduleSession(SessionModel session) async {
    final dt = DateTime.tryParse(session.scheduledDate) ?? DateTime.now();
    final newDate = await showAppDatePicker(
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
        AppToast.show('Session ${session.sessionNumber} rescheduled to ${DateFormat('MMM d, yyyy').format(newDate)} at ${newTime.format(context)}', type: ToastType.success);
        _loadExistingData();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to reschedule: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _cancelSingleSession(SessionModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Session #${session.sessionNumber}?'),
        content: const Text('This will cancel this session and remove it from the appointment schedule.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.error, foregroundColor: Colors.white),
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
          AppToast.show('Session ${session.sessionNumber} cancelled.', type: ToastType.success);
          _loadExistingData();
        }
      } catch (e) {
        if (mounted) {
          AppToast.show('Failed: $e', type: ToastType.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            if (_isLoadingView) {
              return Center(
                child: CircularProgressIndicator(
                  color: context.colors.primary,
                  strokeWidth: 3,
                ),
              );
            }

            final mainBody = Form(
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
                            Text(_isViewing ? 'Consultation Details' : (widget.isViewMode ? 'Edit Consultation' : 'New Consultation'), style: context.textStyles.h2),
                            Text(widget.patientName,
                                style: context.textStyles.caption),
                          ],
                        ),
                      ),
                      if (_isViewing && _existingConsultation?.status != ConsultationStatus.completed) ...[ 
                        IconButton(
                          icon: Icon(Icons.edit_rounded, color: context.colors.primary),
                          onPressed: () => setState(() {
                            _isViewing = false;
                            _isExpanded = true;
                          }),
                        ),
                        IconButton(
                          icon: Icon(Icons.stop_circle_rounded, color: context.colors.warning),
                          tooltip: 'End Treatment',
                          onPressed: _confirmEndConsultation,
                        ),
                      ] else if (_isViewing) ...[
                        IconButton(
                          icon: Icon(Icons.edit_rounded, color: context.colors.primary),
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
                      margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.textHint.withValues(alpha: 0.05),
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
                                      color: context.colors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.assignment_ind_rounded, color: context.colors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Consultation Details', style: context.textStyles.h4),
                                        const SizedBox(height: 2),
                                        Text('View full patient form & attached files', style: context.textStyles.caption),
                                      ],
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: _isExpanded ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textHint),
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
                                    decoration: BoxDecoration(
                                      border: Border(top: BorderSide(color: context.colors.border)),
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
                    Center(
                      child: SizedBox(
                        width: isDesktop ? 320 : double.infinity,
                        child: AppButton(
                          label: widget.isViewMode ? 'Update Consultation' : 'Save Consultation',
                          isLoading: _isSubmitting,
                          icon: Icons.check_circle_outline_rounded,
                          onPressed: _submit,
                        ),
                      ),
                    ),

                ],
              ),
            );

            if (isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadowColor.withValues(alpha: 0.2),
                            blurRadius: 32,
                            spreadRadius: 4,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: mainBody,
                    ),
                  ),
                ),
              );
            } else {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: mainBody,
              );
            }
          },
        ),
      ),
    );
  }


  Widget _buildMultiSelectGrid(List<String> options, List<String> selected, Function(String, bool) onChanged, {TextEditingController? otherCtrl}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: _isViewing ? null : (val) {
                onChanged(opt, val);
                _onInteraction();
              },
              selectedColor: context.colors.primary.withValues(alpha: 0.2),
              checkmarkColor: context.colors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            );
          }).toList(),
        ),
        if (otherCtrl != null && selected.contains('Other')) ...[
          const SizedBox(height: 12),
          AppTextField(
            controller: otherCtrl,
            label: 'Please specify',
            hint: 'Specify other...',
            readOnly: _isViewing,
          )
        ],
      ],
    );
  }

  Widget _buildAllergyCheckbox(String label, bool value, Function(bool) onChanged, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label, style: context.textStyles.bodyMedium),
            value: value,
            onChanged: _isViewing ? null : (v) {
              onChanged(v ?? false);
              _onInteraction();
            },
            activeColor: context.colors.primary,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        if (value)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 8),
            child: AppTextField(
              controller: ctrl,
              label: 'Details',
              hint: hint,
              readOnly: _isViewing,
            ),
          ),
      ],
    );
  }

  Widget _buildFormContent() {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Conversational / Medical ───
        _buildSectionHeader('Consulting Conversations', Icons.chat_bubble_outline_rounded),

        // Chief Complaint label
        if (!_isViewing)
          Text(
            'Chief Complaint / Main Problem',
            style: context.textStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        if (!_isViewing) const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _notesCtrl,
          builder: (context, value, child) {
            return AppTextField(
              controller: _notesCtrl,
              label: _isViewing ? 'Chief Complaint / Main Problem' : '',
              hint: 'As discussed with patient...',
              maxLines: 3,
              readOnly: _isViewing,
              suffixIcon: (!_isViewing && value.text.isNotEmpty)
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: context.colors.textSecondary, size: 20),
                      onPressed: () {
                        _notesCtrl.clear();
                      },
                    )
                  : null,
            );
          },
        ),
        const SizedBox(height: 16),
        Text('Previous Treatments', style: context.textStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildMultiSelectGrid(
          ['Acupuncture', 'Acupressure', 'Cupping', 'Physiotherapy', 'Foot Reflexology', 'Allopathy', 'Ayurveda', 'Siddha treatments', 'No previous treatments', 'Other'],
          _selectedPreviousTreatments,
          (val, selected) {
            setState(() {
              if (val == 'No previous treatments') {
                _selectedPreviousTreatments.clear();
                if (selected) _selectedPreviousTreatments.add(val);
              } else {
                _selectedPreviousTreatments.remove('No previous treatments');
                if (selected) _selectedPreviousTreatments.add(val);
                else _selectedPreviousTreatments.remove(val);
              }
            });
          },
        ),
        
        const SizedBox(height: 32),
        Text('Main Problem Pain Area', style: context.textStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildMultiSelectGrid(
          ['Head', 'Neck', 'Shoulder', 'Upper Back', 'Lower Back', 'Chest', 'Abdomen', 'Arms', 'Hands', 'Hips', 'Legs', 'Knees', 'Feet', 'Joints', 'Muscle', 'No Pain', 'Other'],
          _selectedPainAreas,
          (val, selected) {
            setState(() {
              if (val == 'No Pain') {
                _selectedPainAreas.clear();
                if (selected) _selectedPainAreas.add(val);
              } else {
                _selectedPainAreas.remove('No Pain');
                if (selected) _selectedPainAreas.add(val);
                else _selectedPainAreas.remove(val);
              }
            });
          },
        ),
        
        if (_selectedPainAreas.contains('Other')) ...[
          const SizedBox(height: 12),
          AppTextField(controller: _painOtherCtrl, label: 'Specify Pain Area', readOnly: _isViewing),
        ],

        const SizedBox(height: 32),
        Text('Past Major Illnesses', style: context.textStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildMultiSelectGrid(
          ['Heart diseases', 'Heart attack', 'TB', 'Stroke', 'Chronic kidney disease', 'Hep-B', 'HIV/AIDS', 'Cirrhosis', 'Pancreatitis', 'Cancer', 'No illness', 'Other'],
          _selectedPastIllnesses,
          (val, selected) {
            setState(() {
              if (selected) {
                 if (val == 'No illness') _selectedPastIllnesses.clear();
                 else _selectedPastIllnesses.remove('No illness');
                 _selectedPastIllnesses.add(val);
              } else {
                 _selectedPastIllnesses.remove(val);
              }
            });
          },
          otherCtrl: _illnessOtherCtrl,
        ),

        const SizedBox(height: 24),
        Text('Past Major Surgeries', style: context.textStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildMultiSelectGrid(
          ['Appendicitis', 'Gall bladder removal', 'Hernia repair', 'Knee/Hip replacement', 'Spinal procedures', 'Hysterectomy', 'C-section', 'Cancer surgeries', 'No surgeries', 'Other'],
          _selectedPastSurgeries,
          (val, selected) {
            setState(() {
              if (selected) {
                 if (val == 'No surgeries') _selectedPastSurgeries.clear();
                 else _selectedPastSurgeries.remove('No surgeries');
                 _selectedPastSurgeries.add(val);
              } else {
                 _selectedPastSurgeries.remove(val);
              }
            });
          },
          otherCtrl: _surgeryOtherCtrl,
        ),

        const SizedBox(height: 24),
        AppTextField(
          controller: _currentMedicationsCtrl,
          label: 'Current Medications',
          hint: 'Allopathic, herbal, etc.',
          maxLines: 2,
          readOnly: _isViewing,
        ),

        const SizedBox(height: 24),
        Text('Known Allergies', style: context.textStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _responsiveRow(
          _buildAllergyCheckbox('Drug / Medication Allergies', _hasDrugAllergy, (v) => setState(() => _hasDrugAllergy = v), _drugAllergyCtrl, 'Which drugs?'),
          _buildAllergyCheckbox('Environmental Allergies', _hasEnvAllergy, (v) => setState(() => _hasEnvAllergy = v), _envAllergyCtrl, 'Dust, pollen, etc.'),
          isDesktop,
        ),
        if (isDesktop) const SizedBox(height: 12),
        _responsiveRow(
          _buildAllergyCheckbox('Food Allergies', _hasFoodAllergy, (v) => setState(() => _hasFoodAllergy = v), _foodAllergyCtrl, 'Dairy, nuts, etc.'),
          _buildAllergyCheckbox('Other Allergies', _hasOtherAllergy, (v) => setState(() => _hasOtherAllergy = v), _otherAllergyCtrl, 'Please specify...'),
          isDesktop,
        ),

        const SizedBox(height: 24),
        Text('Chronic Diseases', style: context.textStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildMultiSelectGrid(
          ['None', 'Arthritis', 'Sinus', 'Asthma', 'Thyroid', 'Diabetes', 'BP', 'Heart problems', 'Other'],
          _selectedChronicDiseases,
          (val, selected) {
            setState(() {
              if (val == 'None') {
                // Selecting 'None' clears all others
                if (selected) {
                  _selectedChronicDiseases.clear();
                  _selectedChronicDiseases.add('None');
                  _chronicOtherCtrl.clear();
                } else {
                  _selectedChronicDiseases.remove('None');
                }
              } else {
                // Selecting any disease removes 'None'
                _selectedChronicDiseases.remove('None');
                if (selected) _selectedChronicDiseases.add(val);
                else _selectedChronicDiseases.remove(val);
              }
            });
          },
          otherCtrl: _chronicOtherCtrl,
        ),

        const SizedBox(height: 32),

        // ─── Lifestyle & Habits ───
        _buildSectionHeader('Lifestyle & Habits', Icons.accessibility_new_rounded),
        
        _responsiveRow(
          _buildDropdown('Diet Pattern', 'Select your usual diet', _selectedDiet, _dietOptions, (v) => setState(() => _selectedDiet = v)),
          _buildDropdown('Sleep Duration', 'Hours of sleep per night', _selectedSleepDuration, _sleepDurationOptions, (v) => setState(() => _selectedSleepDuration = v)),
          isDesktop,
        ),
        const SizedBox(height: 16),
        _responsiveRow(
          _buildDropdown('Sleep Quality', 'How well do you sleep?', _selectedSleepQuality, _sleepQualityOptions, (v) => setState(() => _selectedSleepQuality = v)),
          _buildDropdown('Exercise / Physical Activity', 'Level of activity', _selectedExercise, _exerciseOptions, (v) => setState(() => _selectedExercise = v)),
          isDesktop,
        ),
        const SizedBox(height: 16),
        _buildDropdown('Stress / Mental Health', 'Current stress level', _selectedStress, _stressOptions, (v) => setState(() => _selectedStress = v)),
        const SizedBox(height: 32),

        Text('Substance Use', style: context.textStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _responsiveRow(
          _buildRadioGroup('Smoking', _smoking, (v) => setState(() => _smoking = v!)),
          _buildRadioGroup('Alcohol', _alcohol, (v) => setState(() => _alcohol = v!)),
          isDesktop,
        ),
        const SizedBox(height: 16),
        _responsiveRow(
          _buildRadioGroup('Tobacco Chewing', _tobacco, (v) => setState(() => _tobacco = v!)),
          _buildRadioGroup('Recreational Drugs', _drugs, (v) => setState(() => _drugs = v!)),
          isDesktop,
        ),
        const SizedBox(height: 32),

        // ─── Vitals ───
        _buildSectionHeader('Vitals', Icons.monitor_heart_outlined),
        SizedBox(height: 8),
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
                prefixIcon: Icon(Icons.favorite_outline_rounded,
                    color: context.colors.error, size: 18),
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
            SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _pulseCtrl,
                label: 'Pulse (bpm)',
                hint: '72',
                keyboardType: TextInputType.number,
                prefixIcon: Icon(Icons.monitor_heart_outlined,
                    color: context.colors.warning, size: 18),
                readOnly: _isViewing,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _sugarCtrl,
                label: 'Blood Sugar (mg/dL)',
                hint: 'Fasting / Random',
                keyboardType: TextInputType.text,
                readOnly: _isViewing,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _cholesterolCtrl,
                label: 'Cholesterol',
                hint: 'Total / LDL',
                keyboardType: TextInputType.text,
                readOnly: _isViewing,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _vitD3Ctrl,
                label: 'Vitamin D3',
                hint: 'Level',
                keyboardType: TextInputType.text,
                readOnly: _isViewing,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _vitB12Ctrl,
                label: 'Vitamin B12',
                hint: 'Level',
                keyboardType: TextInputType.text,
                readOnly: _isViewing,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _thyroidCtrl,
          label: 'Thyroid (TSH, T3, T4)',
          hint: 'Results...',
          keyboardType: TextInputType.text,
          readOnly: _isViewing,
        ),
        const SizedBox(height: 32),

        // ─── Diagnosis ───
        _buildSectionHeader('Diagnosis', Icons.medical_information_outlined),
        _responsiveRow(
          AppTextField(
            controller: _acupunctureDiagnosisCtrl,
            label: 'Acupuncture Diagnosis',
            hint: 'Meridian findings, point sensitivity...',
            maxLines: 3,
            readOnly: _isViewing,
          ),
          AppTextField(
            controller: _eyeDiagnosisCtrl,
            label: 'Eye Diagnosis',
            hint: 'Iridology, sclera findings...',
            maxLines: 3,
            readOnly: _isViewing,
          ),
          isDesktop,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _pulseDiagnosisCtrl,
          label: 'Pulse Diagnosis',
          hint: 'Pulse characteristics, rhythm, strength...',
          maxLines: 3,
          readOnly: _isViewing,
        ),
        const SizedBox(height: 32),

        // ─── Corona Vaccination ───
        _buildSectionHeader('Vaccination', Icons.vaccines_outlined),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Corona Vaccinated?',
                    style: context.textStyles.bodyMedium),
              ),
              Switch(
                value: _coronaVaccinated,
                onChanged: (_isViewing) ? null : (v) {
                  setState(() => _coronaVaccinated = v);
                  _onInteraction();
                },
                activeColor: context.colors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // ─── Report Files & Media ───
        _buildSectionHeader('Report Files', Icons.science_outlined),
        Text('Upload X-Rays, MRI, Blood Test Reports', style: context.textStyles.caption),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (_existingRecord != null && _existingConsultation != null)
              ..._existingConsultation!.photos.map((p) => _remotePhotoThumb(p)),
            if (!_isViewing) ...[
              ..._photos.asMap().entries.map((e) => _photoThumb(e.key)),
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '⚠️ Report file uploads are only supported on the mobile app.',
                    style: context.textStyles.caption.copyWith(color: context.colors.warning),
                  ),
                )
              else ...[
                _addPhotoBtn(Icons.camera_alt_rounded, 'Camera', _pickPhoto),
                _addPhotoBtn(Icons.photo_library_rounded, 'Gallery', _pickFromGallery),
              ],
            ],
          ],
        ),
        const SizedBox(height: 32),
        
        // ─── Consent & Safety ───
        _buildSectionHeader('Consent & Safety', Icons.verified_user_outlined),
        if (_patientGender != 'Male') ...[
          Text('Pregnancy Status', style: context.textStyles.label.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildRadioGroup('Are you currently pregnant?', _pregnancyStatus, (v) {
            setState(() {
              _pregnancyStatus = v!;
              if (v == 'No') _pregnancyMonths = null;
            });
          }),
          if (_pregnancyStatus == 'Yes') ...[
            const SizedBox(height: 12),
            Text('How many months?', style: context.textStyles.label.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: List.generate(9, (i) {
              final month = i + 1;
              final isSelected = _pregnancyMonths == month;
              return GestureDetector(
                onTap: _isViewing ? null : () => setState(() => _pregnancyMonths = month),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: isSelected ? context.colors.primary : context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? context.colors.primary : context.colors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text('$month', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : context.colors.textPrimary,
                  )),
                ),
              );
            })),
          ],
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Informed consent obtained for touch-based treatments / exercises.',
                  style: context.textStyles.bodyMedium,
                ),
              ),
              Switch(
                value: _consentGiven,
                onChanged: (_isViewing) ? null : (v) {
                  setState(() => _consentGiven = v);
                  _onInteraction();
                },
                activeColor: context.colors.primary,
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
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Charge for consultation?',
                        style: context.textStyles.bodyMedium),
                  ),
                  Switch(
                    value: _charged,
                    onChanged: (_isViewing) ? null : (v) {
                      setState(() => _charged = v);
                      _onInteraction();
                    },
                    activeColor: context.colors.primary,
                  ),
                ],
              ),
              if (_charged) ...[
                SizedBox(height: 10),
                AppTextField(
                  controller: _chargeCtrl,
                  label: 'Amount (₹)',
                  hint: '500',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: Icon(
                      Icons.currency_rupee_rounded,
                      color: context.colors.success,
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

  Widget _responsiveRow(Widget left, Widget right, bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          const SizedBox(height: 16),
          right,
        ],
      );
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 8),
          Text(title, style: context.textStyles.h3),
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
            border: Border.all(color: context.colors.border),
            color: context.colors.surface,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: kIsWeb 
                ? Image.network(ImageHelper.getSecureUrl(_photos[index].path), 
                    fit: BoxFit.cover, 
                    errorBuilder: (_, __, ___) => Icon(Icons.image_rounded, color: context.colors.textHint), 
                  )
                : Image.file(
                    File(_photos[index].path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.image_rounded, color: context.colors.textHint),
                  ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: () {
              setState(() => _photos.removeAt(index));
              _onInteraction();
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: context.colors.error,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.close_rounded, size: 14, color: context.colors.textPrimary),
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
                  child: Image.network(ImageHelper.getSecureUrl(url),  fit: BoxFit.contain),
                ),
                Positioned(
                  top: -16,
                  right: -16,
                  child: IconButton(
                    icon: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.close_rounded, color: context.colors.shadowColor, size: 20),
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
          border: Border.all(color: context.colors.border),
          color: context.colors.surface,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(ImageHelper.getSecureUrl(url), 
            fit: BoxFit.cover, 
            errorBuilder: (_, __, ___) => Icon(Icons.image_rounded, color: context.colors.textHint), 
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
          border: Border.all(color: context.colors.primary, style: BorderStyle.solid),
          color: context.colors.primary.withValues(alpha: 0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: context.colors.primary),
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
        Text(label, style: context.textStyles.label),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _isViewing ? context.colors.divider : context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: Text(hint, style: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint)),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textSecondary),
              items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: context.textStyles.bodyMedium))).toList(),
              onChanged: _isViewing ? null : (v) {
                onChanged(v);
                _onInteraction();
              },
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
          Expanded(child: Text(label, style: context.textStyles.bodyMedium)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _isViewing ? null : () {
                  onChanged('Yes');
                  _onInteraction();
                },
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'Yes',
                      groupValue: groupValue,
                      onChanged: _isViewing ? null : (v) {
                        onChanged(v);
                        _onInteraction();
                      },
                      activeColor: context.colors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    const Text('Yes'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _isViewing ? null : () {
                  onChanged('No');
                  _onInteraction();
                },
                child: Row(
                  children: [
                    Radio<String>(
                      value: 'No',
                      groupValue: groupValue,
                      onChanged: _isViewing ? null : (v) {
                        onChanged(v);
                        _onInteraction();
                      },
                      activeColor: context.colors.primary,
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

class _ChiefComplaintWarningDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: AlertDialog(
        backgroundColor: context.colors.surface.withValues(alpha: 0.85),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: context.colors.border.withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: context.colors.warning,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Missing Chief Complaint',
                style: context.textStyles.h3,
              ),
            ),
          ],
        ),
        content: Text(
          'You are submitting the consultation without recording the patient\'s Chief Complaint or Main Problem. Would you like to go back and edit, or submit anyway?',
          style: context.textStyles.bodyMedium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Go Back',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Submit Anyway',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
