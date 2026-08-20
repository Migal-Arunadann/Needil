import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/services/session_timer_service.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/features/treatments/providers/treatment_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/core/services/idle_reminder_service.dart';
import 'package:pms_app/core/services/photo_quota_service.dart';
import 'package:pms_app/core/widgets/photo_limit_dialog.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';
import '../../../core/services/auth_service.dart' show UserRole;
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/features/appointments/screens/patient_info_screen.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';

class AcupointUsage {
  String point;
  String side;
  String depth;
  String angle;
  String method;

  AcupointUsage({
    required this.point,
    this.side = 'Bilateral',
    this.depth = '1.0 cun',
    this.angle = 'Perpendicular',
    this.method = 'Manual',
  });

  Map<String, dynamic> toJson() => {
    'point': point,
    'side': side,
    'depth': depth,
    'angle': angle,
    'method': method,
  };

  factory AcupointUsage.fromJson(Map<String, dynamic> json) => AcupointUsage(
    point: json['point'] ?? '',
    side: json['side'] ?? 'Bilateral',
    depth: json['depth'] ?? '1.0 cun',
    angle: json['angle'] ?? 'Perpendicular',
    method: json['method'] ?? 'Manual',
  );
}

const List<Map<String, String>> _acupointsLibrary = [
  {'point': 'LU7', 'name': 'Lieque', 'meridian': 'Lung'},
  {'point': 'LU9', 'name': 'Taiyuan', 'meridian': 'Lung'},
  {'point': 'LI4', 'name': 'Hegu', 'meridian': 'Large Intestine'},
  {'point': 'LI11', 'name': 'Quchi', 'meridian': 'Large Intestine'},
  {'point': 'ST25', 'name': 'Tianshu', 'meridian': 'Stomach'},
  {'point': 'ST36', 'name': 'Zusanli', 'meridian': 'Stomach'},
  {'point': 'ST44', 'name': 'Neiting', 'meridian': 'Stomach'},
  {'point': 'SP6', 'name': 'Sanyinjiao', 'meridian': 'Spleen'},
  {'point': 'SP9', 'name': 'Yinlingquan', 'meridian': 'Spleen'},
  {'point': 'SP10', 'name': 'Xuehai', 'meridian': 'Spleen'},
  {'point': 'HT7', 'name': 'Shenmen', 'meridian': 'Heart'},
  {'point': 'SI3', 'name': 'Houxi', 'meridian': 'Small Intestine'},
  {'point': 'BL23', 'name': 'Shenshu', 'meridian': 'Bladder'},
  {'point': 'BL60', 'name': 'Kunlun', 'meridian': 'Bladder'},
  {'point': 'BL62', 'name': 'Shenmai', 'meridian': 'Bladder'},
  {'point': 'KI3', 'name': 'Taixi', 'meridian': 'Kidney'},
  {'point': 'KI6', 'name': 'Zhaohai', 'meridian': 'Kidney'},
  {'point': 'PC6', 'name': 'Neiguan', 'meridian': 'Pericardium'},
  {'point': 'TE5', 'name': 'Waiguan', 'meridian': 'Triple Energizer'},
  {'point': 'GB20', 'name': 'Fengchi', 'meridian': 'Gallbladder'},
  {'point': 'GB30', 'name': 'Huantiao', 'meridian': 'Gallbladder'},
  {'point': 'GB34', 'name': 'Yanglingquan', 'meridian': 'Gallbladder'},
  {'point': 'LR3', 'name': 'Taichong', 'meridian': 'Liver'},
  {'point': 'LR14', 'name': 'Qimen', 'meridian': 'Liver'},
  {'point': 'GV14', 'name': 'Dazhui', 'meridian': 'Du Mai'},
  {'point': 'GV20', 'name': 'Baihui', 'meridian': 'Du Mai'},
  {'point': 'CV4', 'name': 'Guanyuan', 'meridian': 'Ren Mai'},
  {'point': 'CV6', 'name': 'Qihai', 'meridian': 'Ren Mai'},
  {'point': 'CV12', 'name': 'Zhongwan', 'meridian': 'Ren Mai'},
];

// ── Treatment types supported by the app ──
const List<String> _treatmentTypes = [
  'Acupuncture',
  'Acupressure',
  'Cupping Therapy',
  'Physiotherapy',
  'Foot Reflexology',
];

// ── Cupping Therapy data model ──
class CuppingData {
  String cupType;                // 'Dry', 'Wet', 'Fire'
  List<String> placementZones;   // 'Upper Back', 'Lower Back', etc.
  int numberOfCups;
  int durationMinutes;

  CuppingData({
    this.cupType = 'Dry',
    List<String>? placementZones,
    this.numberOfCups = 4,
    this.durationMinutes = 10,
  }) : placementZones = placementZones ?? [];

  Map<String, dynamic> toJson() => {
    'cupType': cupType,
    'placementZones': placementZones,
    'numberOfCups': numberOfCups,
    'durationMinutes': durationMinutes,
  };

  factory CuppingData.fromJson(Map<String, dynamic> json) => CuppingData(
    cupType: json['cupType'] ?? 'Dry',
    placementZones: (json['placementZones'] as List?)?.cast<String>() ?? [],
    numberOfCups: json['numberOfCups'] ?? 4,
    durationMinutes: json['durationMinutes'] ?? 10,
  );

  String toHumanReadable() {
    final zones = placementZones.isNotEmpty ? placementZones.join(', ') : 'None';
    return '• Type: $cupType\n• Zones: $zones\n• Cups: $numberOfCups\n• Duration: $durationMinutes min';
  }
}

const List<String> _cuppingZones = [
  'Upper Back', 'Lower Back', 'Shoulder', 'Neck',
  'Abdomen', 'Thigh', 'Calf', 'Other',
];

// ── Physiotherapy data model ──
class PhysioExercise {
  String name;
  int sets;
  int reps;
  String resistance;   // 'None', 'Light', 'Medium', 'Heavy'
  String? romDegrees;   // optional range of motion

  PhysioExercise({
    required this.name,
    this.sets = 3,
    this.reps = 10,
    this.resistance = 'None',
    this.romDegrees,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'sets': sets,
    'reps': reps,
    'resistance': resistance,
    if (romDegrees != null && romDegrees!.isNotEmpty) 'romDegrees': romDegrees,
  };

  factory PhysioExercise.fromJson(Map<String, dynamic> json) => PhysioExercise(
    name: json['name'] ?? '',
    sets: json['sets'] ?? 3,
    reps: json['reps'] ?? 10,
    resistance: json['resistance'] ?? 'None',
    romDegrees: json['romDegrees'],
  );
}

class PhysioData {
  List<PhysioExercise> exercises;

  PhysioData({List<PhysioExercise>? exercises}) : exercises = exercises ?? [];

  Map<String, dynamic> toJson() => {
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory PhysioData.fromJson(Map<String, dynamic> json) => PhysioData(
    exercises: (json['exercises'] as List?)
        ?.map((e) => PhysioExercise.fromJson(e))
        .toList() ?? [],
  );

  String toHumanReadable() {
    if (exercises.isEmpty) return '• No exercises recorded';
    return exercises.map((e) {
      final rom = (e.romDegrees != null && e.romDegrees!.isNotEmpty) ? ', ROM: ${e.romDegrees}°' : '';
      return '• ${e.name}: ${e.sets}×${e.reps} (${e.resistance}$rom)';
    }).join('\n');
  }
}

// ── Foot Reflexology data model ──
class ReflexologyData {
  String footSelection;          // 'Left', 'Right', 'Both'
  List<String> pressureZones;    // 'Toes', 'Ball', 'Arch', etc.
  String technique;              // 'Thumb Walk', 'Finger Walk', etc.
  int durationMinutes;

  ReflexologyData({
    this.footSelection = 'Both',
    List<String>? pressureZones,
    this.technique = 'Thumb Walk',
    this.durationMinutes = 15,
  }) : pressureZones = pressureZones ?? [];

  Map<String, dynamic> toJson() => {
    'footSelection': footSelection,
    'pressureZones': pressureZones,
    'technique': technique,
    'durationMinutes': durationMinutes,
  };

  factory ReflexologyData.fromJson(Map<String, dynamic> json) => ReflexologyData(
    footSelection: json['footSelection'] ?? 'Both',
    pressureZones: (json['pressureZones'] as List?)?.cast<String>() ?? [],
    technique: json['technique'] ?? 'Thumb Walk',
    durationMinutes: json['durationMinutes'] ?? 15,
  );

  String toHumanReadable() {
    final zones = pressureZones.isNotEmpty ? pressureZones.join(', ') : 'None';
    return '• Foot: $footSelection\n• Zones: $zones\n• Technique: $technique\n• Duration: $durationMinutes min';
  }
}

const List<String> _reflexologyZones = [
  'Toes', 'Ball', 'Arch', 'Heel', 'Inner Edge', 'Outer Edge',
];

class RecordSessionScreen extends ConsumerStatefulWidget {
  final SessionModel session;
  final String? patientName;

  const RecordSessionScreen({super.key, required this.session, this.patientName});

  @override
  ConsumerState<RecordSessionScreen> createState() => _RecordSessionScreenState();
}

class _RecordSessionScreenState extends ConsumerState<RecordSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isLoadingSession = true;

  /// Live session loaded fresh from PocketBase — never stale.
  late SessionModel _liveSession;

  final _notesCtrl   = TextEditingController();
  final _bpCtrl      = TextEditingController();
  final _pulseCtrl   = TextEditingController();
  final _remarksCtrl = TextEditingController();

  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  /// Read-only mode for completed/missed sessions.
  bool _isViewMode = false;
  Timer? _autoSaveTimer;

  // Acupoint state variables
  final List<AcupointUsage> _selectedPoints = [];
  final _searchCtrl = TextEditingController();
  List<Map<String, String>> _searchSuggestions = [];

  // ── Treatment type & type-specific data ──
  String _selectedTreatmentType = '';
  CuppingData _cuppingData = CuppingData();
  PhysioData _physioData = PhysioData();
  ReflexologyData _reflexologyData = ReflexologyData();

  // ── Doctor & Clinic Services ──
  List<DoctorModel> _clinicDoctors = [];
  String? _selectedDoctorId;
  DoctorModel? _selectedDoctor;

  // ── Deferred Patient Details Gate ──
  // Set to true when the source appointment had patientDetailsSkipped=true (retroactive consultation skip)
  bool _requiresPatientDetailsFill = false;
  String? _linkedAppointmentId;     // appointment that triggered the gate
  String? _linkedPatientId;         // patient to update

  @override
  void initState() {
    super.initState();
    _liveSession = widget.session; // Initial snapshot; replaced after load
    _selectedDoctorId = widget.session.doctorId;
    _isViewMode = widget.session.status == SessionStatus.completed ||
                  widget.session.status == SessionStatus.missed ||
                  widget.session.status == SessionStatus.cancelled;
    // overdue sessions open in edit mode — they are being retroactively recorded
    _loadFreshSession();
  }

  void _parseSessionNotesAndPoints(String? rawNotes) {
    _selectedPoints.clear();
    _cuppingData = CuppingData();
    _physioData = PhysioData();
    _reflexologyData = ReflexologyData();
    if (rawNotes == null || rawNotes.trim().isEmpty) return;
    
    String cleanNotes = rawNotes;
    
    // 1. Parse [Acupoints: ...] JSON block
    final acuMatch = RegExp(r'\[Acupoints:\s*(.*?)\]$').firstMatch(cleanNotes.trim());
    if (acuMatch != null) {
      try {
        final List<dynamic> decoded = jsonDecode(acuMatch.group(1)!);
        _selectedPoints.addAll(decoded.map((item) => AcupointUsage.fromJson(item)));
      } catch (e) {
        debugPrint('Error parsing acupoints: $e');
      }
      cleanNotes = cleanNotes.replaceAll(RegExp(r'\n\n\[Acupoints:\s*(.*?)\]$'), '');
    }
    
    // 2. Parse [CuppingData: ...] JSON block
    final cupMatch = RegExp(r'\[CuppingData:\s*(\{.*?\})\]').firstMatch(cleanNotes.trim());
    if (cupMatch != null) {
      try {
        _cuppingData = CuppingData.fromJson(jsonDecode(cupMatch.group(1)!));
      } catch (e) {
        debugPrint('Error parsing cupping data: $e');
      }
      cleanNotes = cleanNotes.replaceAll(RegExp(r'\n\n\[CuppingData:\s*\{.*?\}\]'), '');
    }
    
    // 3. Parse [PhysioData: ...] JSON block
    final physioMatch = RegExp(r'\[PhysioData:\s*(\{.*?\})\]').firstMatch(cleanNotes.trim());
    if (physioMatch != null) {
      try {
        _physioData = PhysioData.fromJson(jsonDecode(physioMatch.group(1)!));
      } catch (e) {
        debugPrint('Error parsing physio data: $e');
      }
      cleanNotes = cleanNotes.replaceAll(RegExp(r'\n\n\[PhysioData:\s*\{.*?\}\]'), '');
    }
    
    // 4. Parse [ReflexologyData: ...] JSON block
    final reflexMatch = RegExp(r'\[ReflexologyData:\s*(\{.*?\})\]').firstMatch(cleanNotes.trim());
    if (reflexMatch != null) {
      try {
        _reflexologyData = ReflexologyData.fromJson(jsonDecode(reflexMatch.group(1)!));
      } catch (e) {
        debugPrint('Error parsing reflexology data: $e');
      }
      cleanNotes = cleanNotes.replaceAll(RegExp(r'\n\n\[ReflexologyData:\s*\{.*?\}\]'), '');
    }
    
    // 5. Strip human-readable summary blocks
    cleanNotes = cleanNotes.replaceAll(RegExp(r'\n\n=== Acupuncture Treatment ===\n[\s\S]*$'), '');
    cleanNotes = cleanNotes.replaceAll(RegExp(r'\n\n=== Cupping Therapy ===\n[\s\S]*$'), '');
    cleanNotes = cleanNotes.replaceAll(RegExp(r'\n\n=== Physiotherapy ===\n[\s\S]*$'), '');
    cleanNotes = cleanNotes.replaceAll(RegExp(r'\n\n=== Foot Reflexology ===\n[\s\S]*$'), '');
    
    if (_notesCtrl.text.isEmpty && cleanNotes.trim().isNotEmpty) {
      _notesCtrl.text = cleanNotes.trim();
    }
  }

  String _buildFullNotes() {
    String fullNotes = _notesCtrl.text.trim();
    
    // Acupuncture / Acupressure points
    if (_selectedPoints.isNotEmpty &&
        (_selectedTreatmentType == 'Acupuncture' || _selectedTreatmentType == 'Acupressure')) {
      final humanSummary = _selectedPoints.map((p) => '• ${p.point} (${p.side}, ${p.depth}, ${p.angle}, ${p.method})').join('\n');
      final jsonStr = jsonEncode(_selectedPoints.map((p) => p.toJson()).toList());
      fullNotes += '\n\n=== Acupuncture Treatment ===\n$humanSummary\n\n[Acupoints: $jsonStr]';
    }
    
    // Cupping Therapy
    if (_selectedTreatmentType == 'Cupping Therapy' && _cuppingData.placementZones.isNotEmpty) {
      final jsonStr = jsonEncode(_cuppingData.toJson());
      fullNotes += '\n\n=== Cupping Therapy ===\n${_cuppingData.toHumanReadable()}\n\n[CuppingData: $jsonStr]';
    }
    
    // Physiotherapy
    if (_selectedTreatmentType == 'Physiotherapy' && _physioData.exercises.isNotEmpty) {
      final jsonStr = jsonEncode(_physioData.toJson());
      fullNotes += '\n\n=== Physiotherapy ===\n${_physioData.toHumanReadable()}\n\n[PhysioData: $jsonStr]';
    }
    
    // Foot Reflexology
    if (_selectedTreatmentType == 'Foot Reflexology' && _reflexologyData.pressureZones.isNotEmpty) {
      final jsonStr = jsonEncode(_reflexologyData.toJson());
      fullNotes += '\n\n=== Foot Reflexology ===\n${_reflexologyData.toHumanReadable()}\n\n[ReflexologyData: $jsonStr]';
    }
    
    return fullNotes;
  }

  void _onAcupointsChanged() {
    setState(() {});
    _onFieldChanged();
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }
    final lowercaseQuery = query.toLowerCase();
    final results = _acupointsLibrary.where((item) {
      final code = item['point']!.toLowerCase();
      final name = item['name']!.toLowerCase();
      final meridian = item['meridian']!.toLowerCase();
      return code.contains(lowercaseQuery) ||
             name.contains(lowercaseQuery) ||
             meridian.contains(lowercaseQuery);
    }).toList();
    
    final hasExactMatch = _acupointsLibrary.any((item) => item['point']!.toLowerCase() == query.trim().toLowerCase());
    if (!hasExactMatch && query.trim().isNotEmpty) {
      results.add({
        'point': query.trim(),
        'name': 'Custom Point',
        'meridian': 'User Defined',
      });
    }
    
    setState(() => _searchSuggestions = results);
  }

  /// Load the session fresh from PocketBase so we always have up-to-date
  /// status + saved notes (fixes stale widget.session snapshot issue).
  Future<void> _loadFreshSession() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final rec = await pb.collection(PBCollections.sessions).getOne(widget.session.id);
      if (!mounted) return;
      final fresh = SessionModel.fromRecord(rec);
      setState(() {
        _liveSession = fresh;
        _isViewMode = fresh.status == SessionStatus.completed ||
                      fresh.status == SessionStatus.missed ||
                      fresh.status == SessionStatus.cancelled;
        // overdue → always open in edit mode (retroactive recording)
        _parseSessionNotesAndPoints(fresh.notes);
        if (_bpCtrl.text.isEmpty && fresh.bpLevel?.isNotEmpty == true)
          _bpCtrl.text = fresh.bpLevel!;
        if (_pulseCtrl.text.isEmpty && fresh.pulse != null && fresh.pulse! > 0)
          _pulseCtrl.text = fresh.pulse.toString();
        if (_remarksCtrl.text.isEmpty && fresh.remarks?.isNotEmpty == true) {
          _remarksCtrl.text = fresh.remarks!.replaceAll('\n[Recorded Late]', '').replaceAll('[Recorded Late]', '');
        }
        if (fresh.treatmentModality.isNotEmpty) {
          _selectedTreatmentType = fresh.treatmentModality;
        }
        _selectedDoctorId = fresh.doctorId.isNotEmpty ? fresh.doctorId : widget.session.doctorId;
        _isLoadingSession = false;
      });
      // If session doesn't have a treatment modality, load from its plan
      if (_selectedTreatmentType.isEmpty) {
        _loadTreatmentTypeFromPlan(fresh.treatmentPlanId);
      }
      await _loadClinicDoctors();

      // ── Deferred patient details gate: check if source appointment had details skipped ──
      await _checkDeferredPatientDetails(fresh.treatmentPlanId);
    } catch (_) {
      if (!mounted) return;
      // Fallback to the widget snapshot
      setState(() {
        _isViewMode = widget.session.status == SessionStatus.completed ||
                      widget.session.status == SessionStatus.missed ||
                      widget.session.status == SessionStatus.cancelled;
        // overdue → always open in edit mode (retroactive recording)
        _parseSessionNotesAndPoints(widget.session.notes);
        if (_bpCtrl.text.isEmpty && widget.session.bpLevel?.isNotEmpty == true)
          _bpCtrl.text = widget.session.bpLevel!;
        if (_pulseCtrl.text.isEmpty && widget.session.pulse != null && widget.session.pulse! > 0)
          _pulseCtrl.text = widget.session.pulse.toString();
        if (_remarksCtrl.text.isEmpty && widget.session.remarks?.isNotEmpty == true) {
          _remarksCtrl.text = widget.session.remarks!.replaceAll('\n[Recorded Late]', '').replaceAll('[Recorded Late]', '');
        }
        if (widget.session.treatmentModality.isNotEmpty) {
          _selectedTreatmentType = widget.session.treatmentModality;
        }
        _selectedDoctorId = widget.session.doctorId;
        _isLoadingSession = false;
      });
      if (_selectedTreatmentType.isEmpty) {
        _loadTreatmentTypeFromPlan(widget.session.treatmentPlanId);
      }
      await _loadClinicDoctors();
      await _checkDeferredPatientDetails(widget.session.treatmentPlanId);
    }

    _notesCtrl.addListener(_onFieldChanged);
    _bpCtrl.addListener(_onFieldChanged);
    _pulseCtrl.addListener(_onFieldChanged);
    _remarksCtrl.addListener(_onFieldChanged);

    // Start idle tracking for this session
    if (!_isViewMode) {
      IdleReminderService.instance.startTracking(
        id: _liveSession.id,
        type: 'session',
        displayName: widget.patientName ?? 'Patient',
      );
    }
  }

  /// Loads the treatment type from the parent plan if the session record
  /// doesn't have its own treatment_type set (backward compatibility).
  Future<void> _loadTreatmentTypeFromPlan(String planId) async {
    if (planId.isEmpty) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      final planRec = await pb.collection(PBCollections.treatmentPlans).getOne(planId);
      final planType = planRec.getStringValue('treatment_type');
      if (mounted && planType.isNotEmpty && _selectedTreatmentType.isEmpty) {
        setState(() => _selectedTreatmentType = planType);
      }
    } catch (_) {
      // Silently fail — treatment type will just be empty
    }
  }

  /// Check if the source consultation appointment had patient details skipped.
  /// Only applies to the first session — once details are filled the gate clears.
  Future<void> _checkDeferredPatientDetails(String treatmentPlanId) async {
    if (treatmentPlanId.isEmpty) return;
    try {
      final pb = ref.read(pocketbaseProvider);
      final apts = await pb.collection(PBCollections.appointments).getList(
        filter: 'linked_treatment_plan_id = "$treatmentPlanId" && patient_details_skipped = true',
        perPage: 1,
      );
      if (apts.items.isEmpty) return;
      final rec = apts.items.first;
      final patientId = rec.getStringValue('patient');
      if (patientId.isNotEmpty) {
        if (mounted) {
          setState(() {
            _requiresPatientDetailsFill = true;
            _linkedAppointmentId = rec.id;
            _linkedPatientId = patientId;
          });
        }
      }
    } catch (_) {
      // Silently ignore — gate only activates if data confirms it
    }
  }

  /// Clear the deferred patient details gate after staff fills them in.
  Future<void> _clearPatientDetailsGate() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      if (_linkedAppointmentId != null) {
        await pb.collection(PBCollections.appointments).update(_linkedAppointmentId!, body: {
          'patient_details_skipped': false,
        });
      }
      if (mounted) setState(() => _requiresPatientDetailsFill = false);
    } catch (_) {}
  }


  /// Load all doctors in the clinic to restrict treatment types to configured services
  Future<void> _loadClinicDoctors() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);
      final clinicId = auth.clinicId;

      List<DoctorModel> docs = [];
      if (clinicId != null && clinicId.isNotEmpty) {
        try {
          final records = await pb.collection('doctors').getFullList(
            filter: 'clinic = "$clinicId"',
          );
          docs = records.map((r) => DoctorModel.fromRecord(r)).toList();
        } catch (_) {}
      }

      // If no clinic docs found by clinic filter, try fetching doctor by assigned doctor ID
      if (docs.isEmpty && _selectedDoctorId != null && _selectedDoctorId!.isNotEmpty) {
        try {
          final rec = await pb.collection('doctors').getOne(_selectedDoctorId!);
          docs = [DoctorModel.fromRecord(rec)];
        } catch (_) {}
      }

      // If logged in as doctor and still empty, use auth.doctor
      if (docs.isEmpty && auth.doctor != null) {
        docs = [auth.doctor!];
      }

      // Final fallback: fetch all doctors in DB if still empty
      if (docs.isEmpty) {
        try {
          final records = await pb.collection('doctors').getFullList();
          docs = records.map((r) => DoctorModel.fromRecord(r)).toList();
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() {
        _clinicDoctors = docs;
        if (_selectedDoctorId == null || _selectedDoctorId!.isEmpty) {
          _selectedDoctorId = docs.isNotEmpty ? docs.first.id : auth.userId;
        }
        _selectedDoctor = docs.firstWhere(
          (d) => d.id == _selectedDoctorId,
          orElse: () => docs.isNotEmpty ? docs.first : (auth.doctor ?? DoctorModel(id: '', name: '', age: 0, username: '', workingSchedule: [], treatments: [])),
        );
      });
    } catch (_) {}
  }

  /// Gets the available treatment types based on the assigned doctor's configured services.
  List<String> get _availableTreatmentTypes {
    List<String> types = [];

    // 1. Assigned Doctor's configured services
    if (_selectedDoctor != null && _selectedDoctor!.treatments.isNotEmpty) {
      types = _selectedDoctor!.treatments.map((t) => t.type).toList();
    }

    // 2. Fallback to all clinic doctors' configured services
    if (types.isEmpty && _clinicDoctors.isNotEmpty) {
      final allSet = <String>{};
      for (final doc in _clinicDoctors) {
        for (final t in doc.treatments) {
          if (t.type.isNotEmpty) allSet.add(t.type);
        }
      }
      types = allSet.toList();
    }

    // 3. Fallback to standard treatment types if still empty
    if (types.isEmpty) {
      types = List.from(_treatmentTypes);
    }

    // 4. Ensure currently selected treatment modality is included
    if (_selectedTreatmentType.isNotEmpty && !types.contains(_selectedTreatmentType)) {
      types = [_selectedTreatmentType, ...types];
    }

    return types;
  }

  Future<void> _onDoctorChanged(String newDoctorId) async {
    if (_selectedDoctorId == newDoctorId) return;

    final matchedDoc = _clinicDoctors.firstWhere(
      (d) => d.id == newDoctorId,
      orElse: () => _clinicDoctors.first,
    );

    setState(() {
      _selectedDoctorId = newDoctorId;
      _selectedDoctor = matchedDoc;
      final newTypes = _availableTreatmentTypes;
      if (newTypes.isNotEmpty && !newTypes.contains(_selectedTreatmentType)) {
        _selectedTreatmentType = newTypes.first;
      }
    });

    try {
      final pb = ref.read(pocketbaseProvider);
      await pb.collection(PBCollections.sessions).update(_liveSession.id, body: {
        'doctor': newDoctorId,
      });
    } catch (_) {}
    _onFieldChanged();
  }

  /// Shows a confirmation dialog when the user switches treatment type mid-form.
  Future<void> _confirmTreatmentTypeSwitch(String newType) async {
    if (_selectedTreatmentType == newType) return;
    final hasData = _selectedPoints.isNotEmpty ||
        _cuppingData.placementZones.isNotEmpty ||
        _physioData.exercises.isNotEmpty ||
        _reflexologyData.pressureZones.isNotEmpty;

    if (hasData) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Switch Treatment Type?'),
          content: const Text(
            'Changing the treatment type will clear the current type-specific data (points, exercises, zones, etc.). Continue?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Switch', style: TextStyle(color: context.colors.error)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _selectedTreatmentType = newType;
      // Clear all type-specific data
      _selectedPoints.clear();
      _searchCtrl.clear();
      _searchSuggestions.clear();
      _cuppingData = CuppingData();
      _physioData = PhysioData();
      _reflexologyData = ReflexologyData();
    });
    _onFieldChanged();
  }

  void _onFieldChanged() {
    if (_isViewMode) return;
    // Record interaction for idle reminder
    IdleReminderService.instance.recordInteraction(_liveSession.id);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _autoSave);
  }

  Future<void> _autoSave() async {
    if (!mounted || _isLoadingSession) return;
    try {
      // Save directly via service so it persists even if sessionsProvider is empty
      final service = ref.read(treatmentServiceProvider);
      final sessionId = _liveSession.id;
      final saved = await service.recordSession(
        sessionId: sessionId,
        notes: _buildFullNotes(),
        bpLevel: _bpCtrl.text.trim(),
        pulse: _pulseCtrl.text.isNotEmpty ? int.tryParse(_pulseCtrl.text.trim()) : null,
        remarks: _remarksCtrl.text.trim(),
        photos: const [], // Do not auto-save photos
        isCompleted: false,
        treatmentModality: _selectedTreatmentType,
        doctorId: _selectedDoctorId,
      );
      if (mounted && saved.notes != null) {
        setState(() {
          _liveSession = saved;
        });
      }
    } catch (_) {
      // Auto-save failure is non-critical — silently ignore
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _notesCtrl.removeListener(_onFieldChanged);
    _bpCtrl.removeListener(_onFieldChanged);
    _pulseCtrl.removeListener(_onFieldChanged);
    _remarksCtrl.removeListener(_onFieldChanged);
    _notesCtrl.dispose();
    _bpCtrl.dispose();
    _pulseCtrl.dispose();
    _remarksCtrl.dispose();
    _searchCtrl.dispose();
    // Stop idle tracking
    IdleReminderService.instance.stopTracking(_liveSession.id);
    super.dispose();
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
        final validImgs = <XFile>[];
        for (final img in imgs) {
          final ext = img.name.split('.').last.toLowerCase();
          if (['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'].contains(ext) || img.mimeType?.startsWith('image/') == true) {
             validImgs.add(img);
          } else {
             AppToast.show('Only image files are supported (e.g., JPG, PNG). Skipped: ${img.name}', type: ToastType.error);
          }
        }
        if (validImgs.isEmpty) return;
        
        // Check quota for batch
        if (clinicId != null) {
          try {
            final quota = ref.read(photoQuotaServiceProvider);
            if (!await quota.canUpload(clinicId, validImgs.length)) {
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
              validImgs.removeRange(remaining, validImgs.length);
            }
          } catch (_) {}
        }
        final compressedList = <XFile>[];
        for (final file in validImgs) {
          final comp = await ImageHelper.compressToWebP(file);
          if (comp != null) {
            compressedList.add(comp);
          }
        }
        if (compressedList.isNotEmpty && mounted) {
          setState(() => _photos.addAll(compressedList));
          _onFieldChanged();
        }
      }
    } catch (_) {
      // Gallery access failed or user denied — silently ignore
    }
  }

  Future<void> _submit() async {
    // Capture navigator before async gap to safely pop after saving
    final navigator = Navigator.of(context);
    
    // NOTE: Do NOT end running timer here — timer should persist in background
    // even when saving session details. Only "End Session" on the card stops it.
    // Flush any pending auto-save first
    _autoSaveTimer?.cancel();
    setState(() => _isSubmitting = true);
    // A session that is 'overdue' or on a past date came from the Needs Attention / Overdue flow.
    // The doctor never pre-recorded it, so we auto-complete it here on save.
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isPastSession = _liveSession.scheduledDate.compareTo(todayStr) < 0;
    final isRetroactive = _liveSession.status == SessionStatus.overdue || (isPastSession && _liveSession.status != SessionStatus.completed);
    final isAlreadyCompleted = _liveSession.status == SessionStatus.completed;
    try {
      final service = ref.read(treatmentServiceProvider);
      
      String finalRemarks = _remarksCtrl.text.trim();
      if (isRetroactive) {
        finalRemarks = finalRemarks.isEmpty ? '[Filled Afterwards]' : '$finalRemarks\n[Filled Afterwards]';
      }

      final result = await service.recordSession(
        sessionId: _liveSession.id,
        notes: _buildFullNotes(),
        bpLevel: _bpCtrl.text.trim(),
        pulse: _pulseCtrl.text.isNotEmpty ? int.tryParse(_pulseCtrl.text.trim()) : null,
        remarks: finalRemarks,
        photos: _photos,
        // Retroactive sessions auto-complete on save (single point of completion).
        // Regular today's session Save button never completes — only End Session on the card does.
        isCompleted: isAlreadyCompleted || isRetroactive,
        treatmentModality: _selectedTreatmentType,
        doctorId: _selectedDoctorId,
        reconciliationReason: isRetroactive ? 'late_entry' : null,
      );

      // For retroactive sessions, fix completed_at to the original scheduled
      // date+time instead of DateTime.now() that recordSession() stamps.
      if (isRetroactive) {
        try {
          final pb = ref.read(pocketbaseProvider);
          final dateStr = _liveSession.scheduledDate; // "YYYY-MM-DD"
          final timeStr = _liveSession.scheduledTime ?? '10:00';
          final localDt = DateTime.tryParse('${dateStr}T$timeStr:00');
          final completedAt = localDt != null
              ? localDt.toUtc().toIso8601String()
              : DateTime.now().toUtc().toIso8601String();
          await pb.collection('sessions').update(_liveSession.id, body: {
            'completed_at': completedAt,
          });
        } catch (_) {}
      }

      setState(() {
        _isSubmitting = false;
        _liveSession = result;
        // ── Increment photo quota ──
        final photoCount = _photos.length;
        _photos.clear(); // Photos now in PB — avoid duplicates
        if (photoCount > 0) {
          final clinicId = ref.read(authProvider).clinicId;
          if (clinicId != null) {
            ref.read(photoQuotaServiceProvider).incrementUsage(clinicId, photoCount);
          }
        }
      });
      if (mounted) {
        final label = isRetroactive
            ? 'Session ${_liveSession.sessionNumber} details saved ✓'
            : 'Session ${_liveSession.sessionNumber} details saved ✓';
        AppToast.show(label, type: ToastType.success);
        navigator.pop(true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        AppToast.show('Failed to save: $e', type: ToastType.error);
      }
    }
  }

  String _fmtDateTime(String dateStr, String? timeStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final d = DateFormat('MMM d, yyyy').format(dt);
      return (timeStr != null && timeStr.isNotEmpty) ? '$d at $timeStr' : d;
    } catch (_) { return dateStr; }
  }

  Color _statusColor(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:   return context.colors.info;
      case SessionStatus.overdue:    return Colors.amber.shade700;
      case SessionStatus.waiting:    return context.colors.warning;
      case SessionStatus.inProgress: return const Color(0xFFF59E0B);
      case SessionStatus.completed:  return context.colors.success;
      case SessionStatus.missed:     return context.colors.warning;
      case SessionStatus.cancelled:  return context.colors.error;
      case SessionStatus.paused:     return context.colors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading spinner while fetching fresh session data
    if (_isLoadingSession) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: Center(child: CircularProgressIndicator(color: context.colors.primary)),
      );
    }

    // ── Deferred patient details gate ──────────────────────────────────────────
    // If the doctor skipped patient details during the retroactive consultation,
    // the first session must collect those details before proceeding.
    if (_requiresPatientDetailsFill && _linkedPatientId != null) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Icon(Icons.arrow_back_rounded, size: 20, color: context.colors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Patient Details Required', style: context.textStyles.h2),
                          Text('Please fill before starting this session', style: context.textStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Notice card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patient details were skipped during the initial consultation.',
                              style: context.textStyles.label.copyWith(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'The patient is present now. Please fill their details first before proceeding to the session.',
                              style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Expand to fill, load PatientInfoScreen embedded
              Expanded(
                child: Builder(builder: (ctx) {
                  // We push PatientInfoScreen content inline by navigating immediately.
                  // Use a post-frame callback to push the full screen.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_requiresPatientDetailsFill && mounted) {
                      final apt = AppointmentModel(
                        id: _linkedAppointmentId ?? '',
                        patientId: _linkedPatientId,
                        doctorId: _liveSession.doctorId,
                        type: AppointmentType.callBy,
                        date: _liveSession.scheduledDate,
                        time: _liveSession.scheduledTime ?? '00:00',
                        status: AppointmentStatus.inProgress,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientInfoScreen(appointment: apt),
                        ),
                      ).then((_) => _clearPatientDetailsGate());
                    }
                  });
                  return const SizedBox.shrink();
                }),
              ),
            ],
          ),
        ),
      );
    }
    final session = _liveSession;
    final sColor = _statusColor(session.status);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final mainBody = Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Icon(Icons.arrow_back_rounded, size: 20, color: context.colors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text('${session.isMaintenance ? "Maintenance" : "Session"} ${session.sessionNumber}', style: context.textStyles.h2),
                            ]),
                            Text('Scheduled: ${_fmtDateTime(session.scheduledDate, session.scheduledTime)}', style: context.textStyles.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Overdue Recording Banner ──
                  if (session.status == SessionStatus.overdue) ...[  
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade700.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded, size: 18, color: Colors.amber.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Recording overdue session for ${_fmtDateTime(session.scheduledDate, session.scheduledTime)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── VIEW MODE ──
                  if (_isViewMode) ...[
                    // Treatment type label
                    if (_selectedTreatmentType.isNotEmpty) ...[
                      _readOnlyCard(
                        _treatmentTypeIcon(_selectedTreatmentType),
                        'Treatment Type',
                        _selectedTreatmentType,
                        context.colors.primary,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Vitals row
                    if ((_bpCtrl.text.trim().isNotEmpty) || (_pulseCtrl.text.trim().isNotEmpty)) ...[
                      const AppLabel(text: 'Vitals'),
                      const SizedBox(height: 8),
                      Row(children: [
                        if (_bpCtrl.text.trim().isNotEmpty)
                          Expanded(child: _readOnlyCard(Icons.favorite_outline_rounded, 'BP Level', _bpCtrl.text, context.colors.error)),
                        if (_bpCtrl.text.trim().isNotEmpty && _pulseCtrl.text.trim().isNotEmpty)
                          const SizedBox(width: 10),
                        if (_pulseCtrl.text.trim().isNotEmpty)
                          Expanded(child: _readOnlyCard(Icons.monitor_heart_outlined, 'Pulse', '${_pulseCtrl.text} bpm', context.colors.warning)),
                      ]),
                      const SizedBox(height: 16),
                    ],
                    _readOnlyField('Session Notes', _notesCtrl.text),
                    // Acupuncture/Acupressure points (view)
                    if (_selectedPoints.isNotEmpty) ...[
                      Text(
                        _selectedTreatmentType == 'Acupressure' ? 'Acupressure Charting' : 'Acupuncture Charting',
                        style: context.textStyles.label,
                      ),
                      const SizedBox(height: 8),
                      _buildReadOnlyAcupointsList(),
                      const SizedBox(height: 16),
                    ],
                    // Cupping Therapy (view)
                    if (_cuppingData.placementZones.isNotEmpty) ...[
                      const AppLabel(text: 'Cupping Therapy Details'),
                      const SizedBox(height: 8),
                      _buildReadOnlyCuppingSection(),
                      const SizedBox(height: 16),
                    ],
                    // Physiotherapy (view)
                    if (_physioData.exercises.isNotEmpty) ...[
                      const AppLabel(text: 'Physiotherapy Details'),
                      const SizedBox(height: 8),
                      _buildReadOnlyPhysioSection(),
                      const SizedBox(height: 16),
                    ],
                    // Foot Reflexology (view)
                    if (_reflexologyData.pressureZones.isNotEmpty) ...[
                      const AppLabel(text: 'Foot Reflexology Details'),
                      const SizedBox(height: 8),
                      _buildReadOnlyReflexologySection(),
                      const SizedBox(height: 16),
                    ],
                    _readOnlyField('Remarks', _remarksCtrl.text),

                    // Photos from PocketBase
                    if (_liveSession.photos.isNotEmpty) ...[
                      const AppLabel(text: 'Photos'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _liveSession.photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) {
                            final photoUrl = '$pbBaseUrl/api/files/${PBCollections.sessions}/${_liveSession.id}/${_liveSession.photos[i]}';
                            return GestureDetector(
                              onTap: () => _showFullPhoto(photoUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(ImageHelper.getSecureUrl(photoUrl), 
                                  width: 100,  height: 100,  fit: BoxFit.cover, 
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 100, height: 100,
                                    decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(10)),
                                    child: Icon(Icons.broken_image_rounded, color: context.colors.textHint),
                                  ), 
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Timer log
                    _TimerLogRow(sessionId: session.id),
                    const SizedBox(height: 16),

                    // Status banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: sColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        Icon(session.status == SessionStatus.completed ? Icons.check_circle_rounded : Icons.warning_rounded, color: sColor, size: 22),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          session.status == SessionStatus.completed ? 'This session has been completed and recorded.' : 'This session was missed.',
                          style: context.textStyles.bodyMedium.copyWith(color: sColor, fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),
                    if (session.status == SessionStatus.completed) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: SizedBox(
                          width: isDesktop ? 320 : double.infinity,
                          child: AppButton(
                            label: 'Edit Session Details',
                            icon: Icons.edit_rounded,
                            onPressed: () => setState(() => _isViewMode = false),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // ── EDIT MODE ──
                  if (!_isViewMode) ...[
                    // ── Assigned Doctor Selector (Allows switching doctor to access other clinic services) ──
                    if (_clinicDoctors.isNotEmpty) ...[
                      const AppLabel(text: 'Assigned Doctor', isRequired: true),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDoctorId,
                            hint: Text('Select assigned doctor...', style: TextStyle(color: context.colors.textHint)),
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textSecondary),
                            items: _clinicDoctors.map((doc) => DropdownMenuItem(
                              value: doc.id,
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 18, color: context.colors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(doc.name, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) _onDoctorChanged(val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Treatment Type Selector ──
                    const AppLabel(text: 'Treatment Type', isRequired: true),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTreatmentType.isNotEmpty && _availableTreatmentTypes.contains(_selectedTreatmentType)
                              ? _selectedTreatmentType
                              : (_availableTreatmentTypes.isNotEmpty ? _availableTreatmentTypes.first : null),
                          hint: Text('Select treatment type...', style: TextStyle(color: context.colors.textHint)),
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textSecondary),
                          items: _availableTreatmentTypes.map((type) => DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(_treatmentTypeIcon(type), size: 18, color: context.colors.primary),
                                const SizedBox(width: 10),
                                Text(type),
                              ],
                            ),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) _confirmTreatmentTypeSwitch(val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Timer — visible for all active sessions ──
                    if (session.status != SessionStatus.overdue) ...[
                      _SessionTimerWidget(
                        sessionId: session.id,
                        patientName: widget.patientName ?? 'Patient',
                        routeArgs: {'session': session, 'patientName': widget.patientName ?? 'Patient'},
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Session Notes
                    Text(
                      'Session Notes',
                      style: context.textStyles.label,
                    ),
                    const SizedBox(height: 8),
                    AppTextField(controller: _notesCtrl, label: '', hint: 'Observations, treatment applied...', maxLines: null, minLines: 4),
                    const SizedBox(height: 16),

                    // ── Type-specific sections ──
                    if (_selectedTreatmentType == 'Acupuncture' || _selectedTreatmentType == 'Acupressure')
                      _buildEditableAcupointsSection(),
                    if (_selectedTreatmentType == 'Cupping Therapy')
                      _buildEditableCuppingSection(),
                    if (_selectedTreatmentType == 'Physiotherapy')
                      _buildEditablePhysioSection(),
                    if (_selectedTreatmentType == 'Foot Reflexology')
                      _buildEditableReflexologySection(),
                    const SizedBox(height: 16),
                    const AppLabel(text: 'Vitals'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: AppTextField(controller: _bpCtrl, label: 'BP Level', hint: '120/80',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'))],
                          prefixIcon: Icon(Icons.favorite_outline_rounded, color: context.colors.error, size: 18),
                          onChanged: (val) {
                            String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                            if (clean.length >= 3 && !val.contains('/')) {
                              if (clean.length == 3) {
                                _bpCtrl.text = '$clean/';
                              } else if (clean.length > 3) {
                                _bpCtrl.text = '${clean.substring(0, 3)}/${clean.substring(3)}';
                              }
                              _bpCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _bpCtrl.text.length));
                            }
                          })),
                      const SizedBox(width: 12),
                      Expanded(child: AppTextField(controller: _pulseCtrl, label: 'Pulse (bpm)', hint: '72',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icon(Icons.monitor_heart_outlined, color: context.colors.warning, size: 18))),
                    ]),
                    const SizedBox(height: 16),
                    const AppLabel(text: 'Photos'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      // Show existing PB photos first
                      ..._liveSession.photos.asMap().entries.map((e) {
                        final photoUrl = '$pbBaseUrl/api/files/${PBCollections.sessions}/${_liveSession.id}/${e.value}';
                        return GestureDetector(
                          onTap: () => _showFullPhoto(photoUrl),
                          child: Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: context.colors.border)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.network(ImageHelper.getSecureUrl(photoUrl),  fit: BoxFit.cover, 
                                errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, color: context.colors.textHint)),
                            ),
                          ),
                        );
                      }),
                      // Show newly picked photos
                      ..._photos.asMap().entries.map((e) => _photoThumb(e.key)),
                      _addPhotoBtn(Icons.file_upload_outlined, 'Upload File', _pickFromGallery),
                    ]),
                    const SizedBox(height: 16),
                    // Remarks
                    Text(
                      'Remarks',
                      style: context.textStyles.label,
                    ),
                    const SizedBox(height: 8),
                    AppTextField(controller: _remarksCtrl, label: '', hint: 'Follow-up notes...', maxLines: 2),
                    const SizedBox(height: 20),

                    // ── Timer usage summary log ──
                    if (session.status != SessionStatus.overdue) ...[
                      _TimerLogRow(sessionId: session.id),
                      const SizedBox(height: 20),
                    ],

                    Center(
                      child: SizedBox(
                        width: isDesktop ? 340 : double.infinity,
                        child: AppButton(
                          label: _liveSession.status == SessionStatus.completed
                              ? 'Save Edits'
                              : _liveSession.status == SessionStatus.overdue
                                  ? 'Complete Overdue Session'
                                  : 'Save Session Details',
                          isLoading: _isSubmitting,
                          icon: Icons.check_circle_outline_rounded,
                          onPressed: _submit,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );

            if (isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
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

  /// Read-only field for view mode.
  Widget _readOnlyField(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: context.textStyles.label.copyWith(fontSize: 12, color: context.colors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.colors.border)),
          child: Text(value, style: context.textStyles.bodyMedium),
        ),
      ]),
    );
  }

  /// Read-only vitals card with icon.
  Widget _readOnlyCard(IconData icon, String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.textStyles.caption.copyWith(fontSize: 10, color: context.colors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: context.textStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  /// Show a full-size photo in a dialog.
  void _showFullPhoto(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(ImageHelper.getSecureUrl(url),  fit: BoxFit.contain, 
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(14)),
                child: Center(child: Icon(Icons.broken_image_rounded, size: 48, color: context.colors.textHint)),
              )),
          ),
          Positioned(top: 8, right: 8, child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, color: context.colors.textPrimary, size: 18),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _photoThumb(int index) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: context.colors.border), color: context.colors.surface),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: kIsWeb
              ? Image.network(_photos[index].path, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.image_rounded, color: context.colors.textHint))
              : Image.file(File(_photos[index].path), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.image_rounded, color: context.colors.textHint)),
        ),
      ),
      Positioned(top: -4, right: -4, child: GestureDetector(
        onTap: () {
          setState(() => _photos.removeAt(index));
          _onFieldChanged();
        },
        child: Container(width: 22, height: 22, decoration: BoxDecoration(color: context.colors.error, shape: BoxShape.circle),
          child: Icon(Icons.close_rounded, size: 14, color: context.colors.textPrimary)),
      )),
    ]);
  }

  Widget _addPhotoBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72, height: 72,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: context.colors.primary), color: context.colors.primary.withValues(alpha: 0.05)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 22, color: context.colors.primary),
          const SizedBox(height: 2),
          Text(label, style: context.textStyles.caption.copyWith(color: context.colors.primary, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _buildReadOnlyAcupointsList() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedPoints.map((point) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.primary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.adjust_rounded, size: 14, color: context.colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    point.point,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      point.side,
                      style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${point.depth} · ${point.angle} · ${point.method}',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditableAcupointsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Acupuncture Points Applied',
              style: context.textStyles.label,
            ),
            if (_selectedPoints.isNotEmpty)
              Text(
                '${_selectedPoints.length} points active',
                style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Search Bar
        AppTextField(
          controller: _searchCtrl,
          label: '',
          hint: 'Search standard points (e.g. LI4, Hegu, Stomach)...',
          prefixIcon: Icon(Icons.search_rounded, color: context.colors.textSecondary),
          onChanged: _onSearchChanged,
        ),

        // Suggestions Box
        if (_searchSuggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListView.separated(
                shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchSuggestions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: context.colors.border),
              itemBuilder: (context, idx) {
                final item = _searchSuggestions[idx];
                final pointCode = item['point']!;
                final pointName = item['name']!;
                final meridian = item['meridian']!;
                final isCustom = pointName == 'Custom Point';
                
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isCustom ? Icons.add_circle_outline_rounded : Icons.adjust_rounded,
                    color: isCustom ? context.colors.accent : context.colors.primary,
                    size: 18,
                  ),
                  title: Text(
                    isCustom ? 'Add custom: "$pointCode"' : '$pointCode ($pointName)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    meridian,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                  ),
                  onTap: () {
                    final exists = _selectedPoints.any((p) => p.point.toLowerCase() == pointCode.toLowerCase());
                    if (exists) {
                      AppToast.show('Point $pointCode is already added.', type: ToastType.warning);
                    } else {
                      setState(() {
                        _selectedPoints.add(AcupointUsage(point: pointCode));
                        _searchCtrl.clear();
                        _searchSuggestions.clear();
                      });
                      _onAcupointsChanged();
                    }
                  },
                );
              },
            ),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Selected Points list
        if (_selectedPoints.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.healing_outlined, size: 28, color: context.colors.textSecondary),
                const SizedBox(height: 8),
                Text(
                  'No acupuncture points added to this session yet.',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          // Desktop view: Table
          MediaQuery.of(context).size.width >= 700
              ? _buildDesktopAcupointsTable()
              : _buildMobileAcupointsList(),
      ],
    );
  }

  Widget _buildDesktopAcupointsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2), // Point
            1: FlexColumnWidth(1.5), // Side
            2: FlexColumnWidth(1.5), // Depth
            3: FlexColumnWidth(1.8), // Angle
            4: FlexColumnWidth(1.8), // Method
            5: FixedColumnWidth(50), // Actions
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Table Header
            TableRow(
              decoration: BoxDecoration(
                color: context.colors.background,
                border: Border(bottom: BorderSide(color: context.colors.border)),
              ),
              children: [
                _tableHeaderCell('Point'),
                _tableHeaderCell('Side'),
                _tableHeaderCell('Depth'),
                _tableHeaderCell('Angle'),
                _tableHeaderCell('Method'),
                _tableHeaderCell(''),
              ],
            ),
            // Table Rows
            ..._selectedPoints.asMap().entries.map((entry) {
              final idx = entry.key;
              final point = entry.value;
              return TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.5))),
                ),
                children: [
                  // Point Code
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      point.point,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  // Side Dropdown
                  _buildDropdownCell(
                    value: point.side,
                    items: ['Bilateral', 'Left', 'Right'],
                    onChanged: (val) {
                      if (val != null) {
                        point.side = val;
                        _onAcupointsChanged();
                      }
                    },
                  ),
                  // Depth Dropdown
                  _buildDropdownCell(
                    value: point.depth,
                    items: ['0.3 cun', '0.5 cun', '0.8 cun', '1.0 cun', '1.2 cun', '1.5 cun', '2.0 cun', '3.0 cun'],
                    onChanged: (val) {
                      if (val != null) {
                        point.depth = val;
                        _onAcupointsChanged();
                      }
                    },
                  ),
                  // Angle Dropdown
                  _buildDropdownCell(
                    value: point.angle,
                    items: ['Perpendicular', 'Oblique', 'Transverse'],
                    onChanged: (val) {
                      if (val != null) {
                        point.angle = val;
                        _onAcupointsChanged();
                      }
                    },
                  ),
                  // Method Dropdown
                  _buildDropdownCell(
                    value: point.method,
                    items: ['Manual', 'Electro', 'Moxibustion', 'None'],
                    onChanged: (val) {
                      if (val != null) {
                        point.method = val;
                        _onAcupointsChanged();
                      }
                    },
                  ),
                  // Delete Button
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: context.colors.error, size: 20),
                    onPressed: () {
                      setState(() => _selectedPoints.removeAt(idx));
                      _onAcupointsChanged();
                    },
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _tableHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: context.colors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDropdownCell({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.border),
          color: Colors.white,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            items: items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
              ),
            )).toList(),
            onChanged: onChanged,
            isExpanded: true,
            icon: Icon(Icons.arrow_drop_down_rounded, color: context.colors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAcupointsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _selectedPoints.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final point = _selectedPoints[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.adjust_rounded, size: 16, color: context.colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        point.point,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: context.colors.error, size: 20),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() => _selectedPoints.removeAt(idx));
                      _onAcupointsChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Dropdowns Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildMobileFieldLabel('Side', _buildMobileDropdown(
                    value: point.side,
                    items: ['Bilateral', 'Left', 'Right'],
                    onChanged: (val) {
                      if (val != null) {
                        point.side = val;
                        _onAcupointsChanged();
                      }
                    },
                  )),
                  _buildMobileFieldLabel('Depth', _buildMobileDropdown(
                    value: point.depth,
                    items: ['0.3 cun', '0.5 cun', '0.8 cun', '1.0 cun', '1.2 cun', '1.5 cun', '2.0 cun', '3.0 cun'],
                    onChanged: (val) {
                      if (val != null) {
                        point.depth = val;
                        _onAcupointsChanged();
                      }
                    },
                  )),
                  _buildMobileFieldLabel('Angle', _buildMobileDropdown(
                    value: point.angle,
                    items: ['Perpendicular', 'Oblique', 'Transverse'],
                    onChanged: (val) {
                      if (val != null) {
                        point.angle = val;
                        _onAcupointsChanged();
                      }
                    },
                  )),
                  _buildMobileFieldLabel('Method', _buildMobileDropdown(
                    value: point.method,
                    items: ['Manual', 'Electro', 'Moxibustion', 'None'],
                    onChanged: (val) {
                      if (val != null) {
                        point.method = val;
                        _onAcupointsChanged();
                      }
                    },
                  )),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileFieldLabel(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildMobileDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(
              item,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 12),
            ),
          )).toList(),
          onChanged: onChanged,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down_rounded, color: context.colors.textSecondary),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Treatment Type Icon Helper
  // ═══════════════════════════════════════════════════════════════════════

  IconData _treatmentTypeIcon(String type) {
    switch (type) {
      case 'Acupuncture':
        return Icons.medical_information_outlined;
      case 'Acupressure':
        return Icons.touch_app_rounded;
      case 'Cupping Therapy':
        return Icons.spa_outlined;
      case 'Physiotherapy':
        return Icons.accessibility_new_rounded;
      case 'Foot Reflexology':
        return Icons.directions_walk_rounded;
      default:
        return Icons.healing_outlined;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Cupping Therapy — Editable Section
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEditableCuppingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLabel(text: 'Cupping Therapy Details'),
        const SizedBox(height: 12),
        // Cup Type
        Text('Cup Type', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: ['Dry', 'Wet', 'Fire'].map((type) {
          final selected = _cuppingData.cupType == type;
          return ChoiceChip(
            label: Text(type),
            selected: selected,
            selectedColor: context.colors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: selected ? context.colors.primary : context.colors.textPrimary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (_) {
              setState(() => _cuppingData.cupType = type);
              _onFieldChanged();
            },
          );
        }).toList()),
        const SizedBox(height: 16),
        // Placement Zones
        Text('Placement Zones', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: _cuppingZones.map((zone) {
          final selected = _cuppingData.placementZones.contains(zone);
          return FilterChip(
            label: Text(zone, style: const TextStyle(fontSize: 12)),
            selected: selected,
            selectedColor: context.colors.primary.withValues(alpha: 0.15),
            checkmarkColor: context.colors.primary,
            onSelected: (val) {
              setState(() {
                if (val) { _cuppingData.placementZones.add(zone); }
                else { _cuppingData.placementZones.remove(zone); }
              });
              _onFieldChanged();
            },
          );
        }).toList()),
        const SizedBox(height: 16),
        // Number of Cups + Duration
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Number of Cups', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              _counterBtn(Icons.remove_rounded, () { if (_cuppingData.numberOfCups > 1) { setState(() => _cuppingData.numberOfCups--); _onFieldChanged(); } }),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${_cuppingData.numberOfCups}', style: context.textStyles.h3)),
              _counterBtn(Icons.add_rounded, () { setState(() => _cuppingData.numberOfCups++); _onFieldChanged(); }),
            ]),
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Duration (min)', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              _counterBtn(Icons.remove_rounded, () { if (_cuppingData.durationMinutes > 1) { setState(() => _cuppingData.durationMinutes--); _onFieldChanged(); } }),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${_cuppingData.durationMinutes}', style: context.textStyles.h3)),
              _counterBtn(Icons.add_rounded, () { setState(() => _cuppingData.durationMinutes++); _onFieldChanged(); }),
            ]),
          ])),
        ]),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        child: Icon(icon, size: 18, color: context.colors.primary),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Cupping Therapy — Read-Only Section
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildReadOnlyCuppingSection() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _readOnlyRow('Cup Type', _cuppingData.cupType),
        const SizedBox(height: 8),
        Text('Placement Zones', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: _cuppingData.placementZones.map((z) => _chipBadge(z)).toList()),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _readOnlyRow('Cups', '${_cuppingData.numberOfCups}')),
          Expanded(child: _readOnlyRow('Duration', '${_cuppingData.durationMinutes} min')),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Physiotherapy — Editable Section
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEditablePhysioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const AppLabel(text: 'Physiotherapy Exercises'),
          if (_physioData.exercises.isNotEmpty)
            Text('${_physioData.exercises.length} exercise(s)',
              style: TextStyle(color: context.colors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        ..._physioData.exercises.asMap().entries.map((entry) {
          final idx = entry.key;
          final ex = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: AppTextField(label: 'Exercise Name', hint: 'e.g. Shoulder Flexion',
                  controller: TextEditingController(text: ex.name),
                  onChanged: (val) { ex.name = val; _onFieldChanged(); })),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () { setState(() => _physioData.exercises.removeAt(idx)); _onFieldChanged(); },
                  child: Icon(Icons.close_rounded, size: 20, color: context.colors.error),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _miniNumberField('Sets', ex.sets, (v) { ex.sets = v; _onFieldChanged(); })),
                const SizedBox(width: 8),
                Expanded(child: _miniNumberField('Reps', ex.reps, (v) { ex.reps = v; _onFieldChanged(); })),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Resistance', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 10)),
                  const SizedBox(height: 4),
                  _buildMobileDropdown(value: ex.resistance, items: ['None', 'Light', 'Medium', 'Heavy'],
                    onChanged: (val) { if (val != null) setState(() => ex.resistance = val); _onFieldChanged(); }),
                ])),
              ]),
              const SizedBox(height: 10),
              AppTextField(label: 'ROM (degrees, optional)', hint: 'e.g. 90',
                controller: TextEditingController(text: ex.romDegrees ?? ''),
                keyboardType: TextInputType.number,
                onChanged: (val) { ex.romDegrees = val; _onFieldChanged(); }),
            ]),
          );
        }),
        // Add Exercise button
        GestureDetector(
          onTap: () { setState(() => _physioData.exercises.add(PhysioExercise(name: ''))); _onFieldChanged(); },
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_rounded, size: 18, color: context.colors.primary),
              const SizedBox(width: 6),
              Text('Add Exercise', style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _miniNumberField(String label, int value, ValueChanged<int> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 10)),
      const SizedBox(height: 4),
      Row(children: [
        _counterBtn(Icons.remove_rounded, () { if (value > 1) { onChanged(value - 1); setState(() {}); } }),
        Expanded(child: Center(child: Text('$value', style: context.textStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)))),
        _counterBtn(Icons.add_rounded, () { onChanged(value + 1); setState(() {}); }),
      ]),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Physiotherapy — Read-Only Section
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildReadOnlyPhysioSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _physioData.exercises.map((ex) {
      final rom = (ex.romDegrees != null && ex.romDegrees!.isNotEmpty) ? ' · ROM: ${ex.romDegrees}°' : '';
      return Container(
        width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.primary.withValues(alpha: 0.12)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ex.name, style: context.textStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${ex.sets} sets × ${ex.reps} reps · ${ex.resistance}$rom',
            style: context.textStyles.caption.copyWith(color: context.colors.textSecondary)),
        ]),
      );
    }).toList());
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Foot Reflexology — Editable Section
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEditableReflexologySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AppLabel(text: 'Foot Reflexology Details'),
      const SizedBox(height: 12),
      // Foot Selection
      Text('Foot', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: ['Left', 'Right', 'Both'].map((foot) {
        final selected = _reflexologyData.footSelection == foot;
        return ChoiceChip(
          label: Text(foot), selected: selected,
          selectedColor: context.colors.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: selected ? context.colors.primary : context.colors.textPrimary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (_) { setState(() => _reflexologyData.footSelection = foot); _onFieldChanged(); },
        );
      }).toList()),
      const SizedBox(height: 16),
      // Pressure Zones
      Text('Pressure Zones', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 6, children: _reflexologyZones.map((zone) {
        final selected = _reflexologyData.pressureZones.contains(zone);
        return FilterChip(
          label: Text(zone, style: const TextStyle(fontSize: 12)),
          selected: selected,
          selectedColor: context.colors.primary.withValues(alpha: 0.15),
          checkmarkColor: context.colors.primary,
          onSelected: (val) {
            setState(() {
              if (val) { _reflexologyData.pressureZones.add(zone); }
              else { _reflexologyData.pressureZones.remove(zone); }
            });
            _onFieldChanged();
          },
        );
      }).toList()),
      const SizedBox(height: 16),
      // Technique
      Text('Technique', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: ['Thumb Walk', 'Finger Walk', 'Hook & Backup', 'Rotation'].map((tech) {
        final selected = _reflexologyData.technique == tech;
        return ChoiceChip(
          label: Text(tech, style: const TextStyle(fontSize: 12)), selected: selected,
          selectedColor: context.colors.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: selected ? context.colors.primary : context.colors.textPrimary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (_) { setState(() => _reflexologyData.technique = tech); _onFieldChanged(); },
        );
      }).toList()),
      const SizedBox(height: 16),
      // Duration
      Text('Duration (min)', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Row(children: [
        _counterBtn(Icons.remove_rounded, () { if (_reflexologyData.durationMinutes > 1) { setState(() => _reflexologyData.durationMinutes--); _onFieldChanged(); } }),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${_reflexologyData.durationMinutes}', style: context.textStyles.h3)),
        _counterBtn(Icons.add_rounded, () { setState(() => _reflexologyData.durationMinutes++); _onFieldChanged(); }),
      ]),
      const SizedBox(height: 8),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Foot Reflexology — Read-Only Section
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildReadOnlyReflexologySection() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _readOnlyRow('Foot', _reflexologyData.footSelection),
        const SizedBox(height: 8),
        Text('Pressure Zones', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: _reflexologyData.pressureZones.map((z) => _chipBadge(z)).toList()),
        const SizedBox(height: 8),
        _readOnlyRow('Technique', _reflexologyData.technique),
        const SizedBox(height: 8),
        _readOnlyRow('Duration', '${_reflexologyData.durationMinutes} min'),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Shared read-only helpers
  // ═══════════════════════════════════════════════════════════════════════

  Widget _readOnlyRow(String label, String value) {
    return Row(children: [
      Text('$label: ', style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
      Text(value, style: context.textStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _chipBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: context.colors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}



class _TimerLogRow extends StatefulWidget {
  final String sessionId;
  const _TimerLogRow({required this.sessionId});

  @override
  State<_TimerLogRow> createState() => _TimerLogRowState();
}

class _TimerLogRowState extends State<_TimerLogRow> {
  final _svc = SessionTimerService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(widget.sessionId, _rebuild);
  }

  @override
  void dispose() {
    _svc.removeListener(widget.sessionId, _rebuild);
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  String _fmt(int seconds) {
    if (seconds <= 0) return '—';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final entry = _svc.getEntry(widget.sessionId);
    if (entry == null) return const SizedBox.shrink(); // No timer yet

    final elapsed = entry.totalSeconds - entry.remainingSeconds;
    final statusLabel = entry.isFinished
        ? 'Finished'
        : entry.isPaused
            ? 'Paused'
            : entry.isRunning
                ? 'Running'
                : 'Set';

    final statusColor = entry.isFinished
        ? context.colors.error
        : entry.isRunning
            ? context.colors.primary
            : context.colors.textSecondary;

    int totalElapsedSeconds = 0;
    final List<Widget> historyRows = [];

    for (int i = 0; i < entry.timerHistory.length; i++) {
      final log = entry.timerHistory[i];
      int logElapsed = log.elapsedSeconds;
      
      // If it's the last one and currently running, compute live elapsed
      if (i == entry.timerHistory.length - 1 && log.outcome == 'running') {
        logElapsed = DateTime.now().difference(log.startedAt).inSeconds;
      }
      
      totalElapsedSeconds += logElapsed;

      String outcomeLabel = '';
      Color outcomeColor = context.colors.textSecondary;
      IconData? prefixIcon;

      switch (log.outcome) {
        case 'running':
          outcomeLabel = 'Running';
          outcomeColor = context.colors.primary;
          prefixIcon = Icons.play_arrow_rounded;
          break;
        case 'completed':
          outcomeLabel = 'Completed';
          outcomeColor = context.colors.success;
          prefixIcon = Icons.check_circle_outline_rounded;
          break;
        case 'paused':
          outcomeLabel = 'Paused';
          outcomeColor = context.colors.warning;
          prefixIcon = Icons.pause_rounded;
          break;
        case 'reset':
          outcomeLabel = 'Reset';
          outcomeColor = context.colors.textHint;
          prefixIcon = Icons.refresh_rounded;
          break;
        case 'cancelled':
          outcomeLabel = 'Cancelled';
          outcomeColor = context.colors.error;
          prefixIcon = Icons.cancel_outlined;
          break;
        default:
          outcomeLabel = log.outcome;
      }

      historyRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(prefixIcon, size: 14, color: outcomeColor),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  'Set for ${log.setForMinutes}m | Ran ${_fmt(logElapsed)}',
                  style: context.textStyles.bodyMedium.copyWith(fontSize: 12),
                ),
              ),
              Text(
                outcomeLabel,
                style: context.textStyles.caption.copyWith(
                  color: outcomeColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Fallback if no history records (should not happen for new timers)
    if (historyRows.isEmpty) {
      totalElapsedSeconds = elapsed;
      historyRows.add(
        Row(
          children: [
            Icon(entry.isRunning ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Set for ${entry.totalSeconds ~/ 60}m | Ran ${_fmt(elapsed)}',
                style: context.textStyles.bodyMedium.copyWith(fontSize: 12),
              ),
            ),
            Text(
              statusLabel,
              style: context.textStyles.caption.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.timer_outlined, size: 14, color: context.colors.textSecondary),
            const SizedBox(width: 6),
            Text('Timer History & Log', style: context.textStyles.caption.copyWith(
              color: context.colors.textSecondary, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel, style: context.textStyles.caption.copyWith(
                color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const Divider(height: 16),
          ...historyRows,
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Time Run:',
                style: context.textStyles.caption.copyWith(color: context.colors.textHint),
              ),
              Text(
                _fmt(totalElapsedSeconds),
                style: context.textStyles.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Session Timer Widget
// ═══════════════════════════════════════════════════════════════════════

class _SessionTimerWidget extends StatefulWidget {
  final String sessionId;
  final String patientName;
  final Map<String, dynamic> routeArgs;

  const _SessionTimerWidget({required this.sessionId, required this.patientName, required this.routeArgs});

  @override
  State<_SessionTimerWidget> createState() => _SessionTimerWidgetState();
}

class _SessionTimerWidgetState extends State<_SessionTimerWidget> {
  final _svc = SessionTimerService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(widget.sessionId, _rebuild);
  }

  @override
  void dispose() {
    _svc.removeListener(widget.sessionId, _rebuild);
    super.dispose();
  }

  void _rebuild() { if (mounted) setState(() {}); }

  void _showDurationPicker() {
    final options = [5, 10, 15, 20, 30, 45, 60];
    final customCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: context.colors.surface,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Set Timer Duration', style: context.textStyles.h2),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: options.map((m) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _svc.start(sessionId: widget.sessionId, patientName: widget.patientName, minutes: m, routeArgs: widget.routeArgs);
                HapticFeedback.lightImpact();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: context.colors.primary.withValues(alpha: 0.3))),
                child: Text('$m min', style: context.textStyles.label.copyWith(color: context.colors.primary, fontSize: 13)),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(
              controller: customCtrl, keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: 'Custom (minutes)', hintStyle: context.textStyles.caption, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            )),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
              onPressed: () {
                final m = int.tryParse(customCtrl.text.trim());
                if (m != null && m > 0) {
                  Navigator.pop(ctx);
                  _svc.start(sessionId: widget.sessionId, patientName: widget.patientName, minutes: m, routeArgs: widget.routeArgs);
                  HapticFeedback.lightImpact();
                }
              },
              child: const Text('Start'),
            ),
          ]),
        ]),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final entry = _svc.getEntry(widget.sessionId);
    final isActive = entry != null && (entry.isActive || entry.isFinished);
    final isRunning = entry?.isRunning ?? false;
    final isFinished = entry?.isFinished ?? false;
    final remaining = entry?.remainingSeconds ?? 0;
    final total = entry?.totalSeconds ?? 0;
    final progress = total > 0 ? (total - remaining) / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isFinished ? context.colors.error.withValues(alpha: 0.4) : isRunning ? context.colors.primary.withValues(alpha: 0.3) : context.colors.border),
        boxShadow: isRunning ? [BoxShadow(color: context.colors.primary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.timer_outlined, size: 18, color: isRunning ? context.colors.primary : context.colors.textSecondary),
          const SizedBox(width: 8),
          const AppLabel(text: 'Session Timer'),
          const Spacer(),
          if (!isActive)
            GestureDetector(
              onTap: _showDurationPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: context.colors.primary.withValues(alpha: 0.25))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_alarm_rounded, size: 14, color: context.colors.primary),
                  const SizedBox(width: 4),
                  Text('Set Timer', style: context.textStyles.caption.copyWith(color: context.colors.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
        ]),
        if (isActive) ...[
          const SizedBox(height: 20),
          Center(child: SizedBox(width: 140, height: 140, child: CustomPaint(
            painter: _CircleTimerPainter(progress: progress, isFinished: isFinished, isRunning: isRunning, primaryColor: context.colors.primary, errorColor: context.colors.error),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_formatTime(remaining), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: isFinished ? context.colors.error : context.colors.textPrimary, letterSpacing: -1)),
              if (isFinished) Text('Done!', style: TextStyle(fontSize: 12, color: context.colors.error, fontWeight: FontWeight.w700))
              else Text('${total ~/ 60} min', style: context.textStyles.caption),
            ])),
          ))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (!isFinished) ...[
              _ControlBtn(icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, label: isRunning ? 'Pause' : 'Resume', color: context.colors.primary,
                  onTap: isRunning ? () => _svc.pause(widget.sessionId) : () => _svc.resume(widget.sessionId)),
              const SizedBox(width: 12),
              _ControlBtn(icon: Icons.timer_off_rounded, label: 'End', color: context.colors.warning, onTap: () { _svc.endTimer(widget.sessionId); HapticFeedback.lightImpact(); }),
              const SizedBox(width: 12),
            ],
            _ControlBtn(icon: Icons.stop_rounded, label: 'Reset', color: context.colors.error, onTap: () { _svc.reset(widget.sessionId); HapticFeedback.lightImpact(); }),
            if (!isFinished) ...[
              const SizedBox(width: 12),
              _ControlBtn(icon: Icons.add_alarm_rounded, label: 'Change', color: context.colors.textSecondary, onTap: _showDurationPicker),
            ],
          ]),
        ] else ...[
          const SizedBox(height: 8),
          Text('Tap "Set Timer" to start a countdown for this session.', style: context.textStyles.caption),
        ],
      ]),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ControlBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Column(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Icon(icon, color: color, size: 22)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    ]));
  }
}

class _CircleTimerPainter extends CustomPainter {
  final double progress; final bool isFinished; final bool isRunning;
  final Color primaryColor; final Color errorColor;
  const _CircleTimerPainter({required this.progress, required this.isFinished, required this.isRunning, required this.primaryColor, required this.errorColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const startAngle = -1.5707963267948966;
    canvas.drawCircle(center, radius, Paint()..color = (isFinished ? errorColor : primaryColor).withValues(alpha: 0.08)..style = PaintingStyle.stroke..strokeWidth = 10);
    final sweepAngle = 2 * 3.141592653589793 * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false,
        Paint()..color = isFinished ? errorColor : primaryColor..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_CircleTimerPainter old) => old.progress != progress || old.isFinished != isFinished;
}
