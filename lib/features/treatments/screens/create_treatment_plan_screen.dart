import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/features/appointments/providers/appointment_provider.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/features/auth/models/doctor_model.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/features/treatments/providers/treatment_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';


class CreateTreatmentPlanScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String patientName;
  final String doctorId;
  final String? consultationId;
  final String? appointmentId;

  // Maintenance-mode params
  final bool isMaintenance;
  final String? parentPlanId;
  final String? defaultTreatmentType;
  final double? defaultFee;

  const CreateTreatmentPlanScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    this.consultationId,
    this.appointmentId,
    this.isMaintenance = false,
    this.parentPlanId,
    this.defaultTreatmentType,
    this.defaultFee,
  });

  @override
  ConsumerState<CreateTreatmentPlanScreen> createState() =>
      _CreateTreatmentPlanScreenState();
}

class _CreateTreatmentPlanScreenState
    extends ConsumerState<CreateTreatmentPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  TreatmentConfig? _selectedTreatment;
  DateTime _startDate = DateTime.now();
  String _preferredTimeStr = '10:00';
  bool _firstSessionCompletedToday = true;
  List<WorkingSchedule> _doctorSchedules = [];
  int get _slotDurationMinutes => _selectedTreatment?.durationMinutes ?? 30;

  final _sessionsCtrl = TextEditingController(text: '5');
  final _intervalCtrl = TextEditingController(text: '1');
  final _feeCtrl = TextEditingController();

  // Maintenance-specific
  String _intervalUnit = 'days'; // 'days', 'months', 'years'

  List<TreatmentConfig> _doctorTreatments = [];
  List<int> _doctorWorkingDays = [];
  bool _isLoadingTreatments = true;

  // Doctor selector for clinic accounts
  bool _isClinicAccount = false;
  List<DoctorModel> _clinicDoctors = [];
  DoctorModel? _selectedDoctor;
  bool _isLoadingDoctors = true;

  /// The effective doctor ID — either from the dropdown or the widget param.
  String get _effectiveDoctorId => _selectedDoctor?.id ?? widget.doctorId;

  bool _formSubmitted = false;

  String get _draftKey =>
      'treatment_plan_draft_${widget.appointmentId ?? widget.consultationId ?? "new"}';

  @override
  void initState() {
    super.initState();

    // Pre-fill fee from parent plan if in maintenance mode
    if (widget.isMaintenance && widget.defaultFee != null) {
      _feeCtrl.text = widget.defaultFee!.toStringAsFixed(
          widget.defaultFee! % 1 == 0 ? 0 : 2);
    }

    _checkAccountTypeAndLoadDoctors();
    _loadTreatments();

    // Listen for changes to update session preview dynamically
    _sessionsCtrl.addListener(_onPreviewFieldChanged);
    _intervalCtrl.addListener(_onPreviewFieldChanged);

    if (widget.appointmentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final service = ref.read(appointmentServiceProvider);
          await service.markTreatmentPlanPartial(widget.appointmentId!);
        } catch (_) {}
        await _loadDraft();
      });
    }
  }

  void _onPreviewFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null || !mounted) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _sessionsCtrl.text = data['sessions'] ?? '5';
        _intervalCtrl.text = data['interval'] ?? '1';
        _feeCtrl.text = data['fee'] ?? '';
        _firstSessionCompletedToday = data['firstToday'] ?? true;
        if (data['startDate'] != null) {
          _startDate = DateTime.tryParse(data['startDate']) ?? _startDate;
        }
        if (data['preferredTime'] != null) {
          _preferredTimeStr = data['preferredTime'];
        }
        if (data['intervalUnit'] != null) {
          _intervalUnit = data['intervalUnit'];
        }
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    if (widget.appointmentId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'sessions': _sessionsCtrl.text,
        'interval': _intervalCtrl.text,
        'fee': _feeCtrl.text,
        'firstToday': _firstSessionCompletedToday,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
        'preferredTime': _preferredTimeStr,
        'intervalUnit': _intervalUnit,
      };
      await prefs.setString(_draftKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    if (widget.appointmentId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  /// Check if the logged-in user is a clinic account and load clinic doctors.
  Future<void> _checkAccountTypeAndLoadDoctors() async {
    final auth = ref.read(authProvider);
    if (auth.role == UserRole.clinic && auth.clinicId != null) {
      setState(() {
        _isClinicAccount = true;
        _isLoadingDoctors = true;
      });
      try {
        final pb = ref.read(pocketbaseProvider);
        final result = await pb.collection('doctors').getList(
          filter: 'clinic = "${auth.clinicId}"',
          perPage: 50,
        );
        final doctors = result.items.map((r) => DoctorModel.fromRecord(r)).toList();
        if (mounted) {
          setState(() {
            _clinicDoctors = doctors;
            _isLoadingDoctors = false;
            // Auto-select the doctor matching widget.doctorId
            try {
              _selectedDoctor = doctors.firstWhere((d) => d.id == widget.doctorId);
            } catch (_) {
              if (doctors.isNotEmpty) _selectedDoctor = doctors.first;
            }
          });
          // Reload treatments for the selected doctor
          if (_selectedDoctor != null) _loadTreatmentsForDoctor(_selectedDoctor!);
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingDoctors = false);
      }
    } else {
      setState(() {
        _isClinicAccount = false;
        _isLoadingDoctors = false;
      });
    }
  }

  /// Load treatments from the doctor record identified by widget.doctorId.
  Future<void> _loadTreatments() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final record = await pb.collection('doctors').getOne(widget.doctorId);
      final doc = DoctorModel.fromRecord(record);
      if (mounted) {
        setState(() {
          _doctorTreatments = doc.treatments;
          _doctorWorkingDays = doc.workingDays;
          _doctorSchedules = doc.workingSchedule;
          _isLoadingTreatments = false;

          // Auto-select the default treatment type in maintenance mode
          if (widget.isMaintenance && widget.defaultTreatmentType != null) {
            _selectedTreatment = _doctorTreatments.firstWhere(
              (t) => t.type == widget.defaultTreatmentType,
              orElse: () => _doctorTreatments.isNotEmpty
                  ? _doctorTreatments.first
                  : TreatmentConfig(
                      type: widget.defaultTreatmentType!,
                      durationMinutes: 30,
                      fee: widget.defaultFee ?? 0),
            );
            // Auto-fill fee from the matched treatment config
            _feeCtrl.text = _selectedTreatment!.fee.toStringAsFixed(
                _selectedTreatment!.fee % 1 == 0 ? 0 : 2);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTreatments = false);
      }
    }
  }

  /// Load treatments for a specific doctor (used when clinic switches doctor dropdown).
  void _loadTreatmentsForDoctor(DoctorModel doctor) {
    setState(() {
      _doctorTreatments = doctor.treatments;
      _doctorWorkingDays = doctor.workingDays;
      _doctorSchedules = doctor.workingSchedule;
      _isLoadingTreatments = false;

      // Auto-select the default treatment type in maintenance mode if available
      if (widget.isMaintenance && widget.defaultTreatmentType != null) {
        try {
          _selectedTreatment = _doctorTreatments.firstWhere(
            (t) => t.type == widget.defaultTreatmentType,
          );
          _feeCtrl.text = _selectedTreatment!.fee.toStringAsFixed(
              _selectedTreatment!.fee % 1 == 0 ? 0 : 2);
        } catch (_) {
          _selectedTreatment = null;
          _feeCtrl.clear();
        }
      } else {
        _selectedTreatment = null; // Reset treatment selection
        _feeCtrl.clear();
      }
    });
  }

  @override
  void dispose() {
    if (!_formSubmitted && widget.appointmentId != null) {
      _saveDraft();
    }
    _sessionsCtrl.removeListener(_onPreviewFieldChanged);
    _intervalCtrl.removeListener(_onPreviewFieldChanged);
    _sessionsCtrl.dispose();
    _intervalCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 50));
    final d = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      selectableDayPredicate: (day) {
        if (_doctorWorkingDays.isEmpty) return true;
        return _doctorWorkingDays.contains(day.weekday);
      },
    );
    if (d != null) setState(() => _startDate = d);
  }

  List<String> _generateSlots() {
    if (_doctorSchedules.isEmpty) return [];

    const dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'];
    final selectedDayName = dayNames[_startDate.weekday];

    WorkingSchedule? daySchedule;
    for (final s in _doctorSchedules) {
      if (s.day == selectedDayName) { daySchedule = s; break; }
    }
    daySchedule ??= _doctorSchedules.first;

    final duration = _selectedTreatment?.durationMinutes ?? _slotDurationMinutes;
    final slots = <String>[];

    TimeOfDay parseTime(String t) {
      final parts = t.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    var current = parseTime(daySchedule.startTime);
    final end = parseTime(daySchedule.endTime);

    // Build break ranges from the new 'breaks' list format
    final breakRanges = daySchedule.breaks.map((b) {
      return (parseTime(b['start']!), parseTime(b['end']!));
    }).toList();

    int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    while (toMinutes(current) + duration <= toMinutes(end)) {
      final cMin = toMinutes(current);
      final isDuringBreak = breakRanges.any(
        (r) => cMin >= toMinutes(r.$1) && cMin < toMinutes(r.$2),
      );

      if (!isDuringBreak) slots.add(fmt(current));

      final nextMin = cMin + duration;
      current = TimeOfDay(hour: nextMin ~/ 60, minute: nextMin % 60);
    }
    return slots;
  }

  void _showSlotPicker() {
    FocusScope.of(context).unfocus();
    final slots = _generateSlots();

    if (slots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No slots available — ensure a treatment is selected and doctor has a schedule'),
          backgroundColor: context.colors.warning,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SlotPickerSheet(
        slots: slots,
        selectedSlot: _preferredTimeStr,
        onSelected: (slot) {
          setState(() => _preferredTimeStr = slot);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture navigator before async gap — fixes Vivo/iQOO devices
    final navigator = Navigator.of(context);

    if (_selectedTreatment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a treatment type'), backgroundColor: context.colors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(treatmentServiceProvider);
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final numSessions = int.tryParse(_sessionsCtrl.text.trim()) ?? 5;
      final intervalVal = int.tryParse(_intervalCtrl.text.trim()) ?? 1;
      final feeStr = _feeCtrl.text.trim();
      final fee = feeStr.isEmpty ? 0.0 : (double.tryParse(feeStr) ?? 0.0);

      if (widget.isMaintenance) {
        await service.createMaintenancePlan(
          patientId: widget.patientId,
          doctorId: _effectiveDoctorId,
          consultationId: widget.consultationId,
          parentPlanId: widget.parentPlanId!,
          treatmentType: _selectedTreatment!.type,
          startDate: startDateStr,
          preferredTime: _preferredTimeStr,
          totalSessions: numSessions,
          intervalValue: intervalVal,
          intervalUnit: _intervalUnit,
          sessionFee: fee,
        );
      } else {
        final plan = await service.createSmartTreatmentPlan(
          patientId: widget.patientId,
          doctorId: _effectiveDoctorId,
          consultationId: widget.consultationId,
          treatmentType: _selectedTreatment!.type,
          startDate: startDateStr,
          preferredTime: _preferredTimeStr,
          totalSessions: numSessions,
          intervalDays: intervalVal,
          sessionFee: fee,
          firstSessionCompletedToday: _firstSessionCompletedToday,
        );

        if (widget.appointmentId != null) {
          try {
            final aptService = ref.read(appointmentServiceProvider);
            await aptService.markLinkedPlan(widget.appointmentId!, plan.id);
          } catch (_) {}
        }
      }

      _formSubmitted = true;
      await _clearDraft();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isMaintenance
                ? 'Maintenance Plan & Sessions Scheduled!'
                : 'Treatment Plan & Sessions Auto-Scheduled!'),
            backgroundColor: context.colors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        navigator.pop({
          'success': true,
          'firstSessionToday': !widget.isMaintenance && _firstSessionCompletedToday,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to schedule plan: $e'), backgroundColor: context.colors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMaintenance = widget.isMaintenance;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                final doctorField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assign Doctor', style: context.textStyles.label),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: _isLoadingDoctors
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Loading doctors...'),
                                ],
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<DoctorModel>(
                                isExpanded: true,
                                value: _selectedDoctor,
                                hint: Text(
                                  'Select Doctor',
                                  style: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint),
                                ),
                                items: _clinicDoctors.map((doc) {
                                  return DropdownMenuItem(
                                    value: doc,
                                    child: Row(
                                      children: [
                                        Icon(
                                          doc.isPrimary ? Icons.star_rounded : Icons.person_rounded,
                                          size: 16,
                                          color: doc.isPrimary ? context.colors.warning : context.colors.textHint,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Dr. ${doc.name}', style: context.textStyles.bodyMedium),
                                        if (doc.isPrimary) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: context.colors.warning.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('Primary',
                                                style: context.textStyles.caption.copyWith(
                                                    fontSize: 9, color: context.colors.warning, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedDoctor = val);
                                    _loadTreatmentsForDoctor(val);
                                  }
                                },
                              ),
                            ),
                    ),
                  ],
                );

                final treatmentField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Treatment Type', style: context.textStyles.label),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TreatmentConfig>(
                          isExpanded: true,
                          value: _selectedTreatment,
                          hint: Text(
                            _isLoadingTreatments ? 'Loading treatments...' : 'Select Treatment',
                            style: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint),
                          ),
                          items: _doctorTreatments.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(t.type, style: context.textStyles.bodyMedium),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedTreatment = val;
                              if (val != null) {
                                _feeCtrl.text = val.fee.toStringAsFixed(
                                    val.fee % 1 == 0 ? 0 : 2);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                );

                final sessionsField = AppTextField(
                  controller: _sessionsCtrl,
                  label: isMaintenance ? 'Total Maintenance Sessions' : 'Total Sessions',
                  hint: '10',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n < 1) return 'Min 1';
                    if (n > 99) return 'Max 99';
                    return null;
                  },
                );

                final intervalField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Interval', style: context.textStyles.label),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _intervalCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 2,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: context.textStyles.bodyMedium,
                            decoration: InputDecoration(
                              hintText: '1',
                              hintStyle: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint),
                              filled: true,
                              fillColor: context.colors.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.colors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: context.colors.border),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Required';
                              final n = int.tryParse(v);
                              if (n == null || n < 1) return 'Min 1';
                              if (n > 99) return 'Max 99';
                              return null;
                            },
                          ),
                        ),
                        if (isMaintenance) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.colors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _intervalUnit,
                                  isExpanded: true,
                                  style: context.textStyles.bodyMedium,
                                  items: const [
                                    DropdownMenuItem(value: 'days',   child: Text('Days')),
                                    DropdownMenuItem(value: 'months', child: Text('Months')),
                                    DropdownMenuItem(value: 'years',  child: Text('Years')),
                                  ],
                                  onChanged: (v) => setState(() => _intervalUnit = v!),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.colors.border),
                            ),
                            child: Text('Days', style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary)),
                          ),
                        ],
                      ],
                    ),
                  ],
                );

                final feeField = AppTextField(
                  controller: _feeCtrl,
                  label: isMaintenance ? 'Maintenance Session Fee (₹)' : 'Session Fee (₹)',
                  hint: '500',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18, color: context.colors.success),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                );

                final schedulingPreferencesWidget = Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: (_firstSessionCompletedToday && !isMaintenance) ? null : _pickStartDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (_firstSessionCompletedToday && !isMaintenance)
                                ? context.colors.border.withValues(alpha: 0.15)
                                : context.colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_firstSessionCompletedToday && !isMaintenance)
                                  ? context.colors.border.withValues(alpha: 0.5)
                                  : context.colors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date', style: context.textStyles.caption),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 18,
                                    color: (_firstSessionCompletedToday && !isMaintenance)
                                        ? context.colors.textHint
                                        : context.colors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      (_firstSessionCompletedToday && !isMaintenance)
                                          ? 'Today (Auto)'
                                          : DateFormat('MMM d, yyyy').format(_startDate),
                                      style: context.textStyles.bodyMedium.copyWith(
                                        color: (_firstSessionCompletedToday && !isMaintenance)
                                            ? context.colors.textHint
                                            : context.colors.textPrimary,
                                        fontWeight: (_firstSessionCompletedToday && !isMaintenance)
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showSlotPicker,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _preferredTimeStr.isNotEmpty
                                  ? context.colors.primary.withValues(alpha: 0.5)
                                  : context.colors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Preferred Slot', style: context.textStyles.caption),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 18, color: context.colors.primary),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _preferredTimeStr.isEmpty ? 'Pick a slot' : _formatSlot(_preferredTimeStr),
                                      style: context.textStyles.bodyMedium.copyWith(
                                        color: _preferredTimeStr.isEmpty
                                            ? context.colors.textHint
                                            : context.colors.textPrimary,
                                        fontWeight: _preferredTimeStr.isEmpty
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                final firstSessionTodayWidget = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: context.colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start the 1st session today itself?',
                                style: context.textStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                                'Creates Session 1 today and schedules the remaining sessions',
                                style: context.textStyles.caption),
                          ],
                        ),
                      ),
                      Switch(
                        value: _firstSessionCompletedToday,
                        activeColor: context.colors.primary,
                        onChanged: (val) => setState(() => _firstSessionCompletedToday = val),
                      ),
                    ],
                  ),
                );

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
                                Text(
                                  isMaintenance ? 'Maintenance Planning' : 'Session Planning',
                                  style: context.textStyles.h2,
                                ),
                                Text('For ${widget.patientName}', style: context.textStyles.caption),
                              ],
                            ),
                          ),
                          if (isMaintenance)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.colors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.autorenew_rounded, size: 14, color: context.colors.success),
                                  const SizedBox(width: 4),
                                  Text('Maintenance',
                                      style: context.textStyles.caption.copyWith(
                                          color: context.colors.success, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      if (isDesktop && _isClinicAccount) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: doctorField),
                            const SizedBox(width: 16),
                            Expanded(child: treatmentField),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        if (_isClinicAccount) ...[
                          doctorField,
                          const SizedBox(height: 24),
                        ],
                        treatmentField,
                        const SizedBox(height: 24),
                      ],

                      if (isDesktop) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: sessionsField),
                            const SizedBox(width: 16),
                            Expanded(child: intervalField),
                            const SizedBox(width: 16),
                            Expanded(child: feeField),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(child: sessionsField),
                            const SizedBox(width: 16),
                            Expanded(child: intervalField),
                          ],
                        ),
                        const SizedBox(height: 24),
                        feeField,
                        const SizedBox(height: 32),
                      ],

                      Text('Scheduling Preferences', style: context.textStyles.label),
                      const SizedBox(height: 8),
                      schedulingPreferencesWidget,
                      const SizedBox(height: 16),

                      if (!isMaintenance) ...[
                        firstSessionTodayWidget,
                        const SizedBox(height: 16),
                      ],

                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          '💡 Note: The smart scheduling engine will book sessions sequentially. '
                          'If a time slot is fully occupied (all beds taken), it will find the closest next available slot.',
                          style: TextStyle(color: context.colors.textHint, fontSize: 13, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _SessionDatePreview(
                        startDate: _startDate,
                        numSessions: int.tryParse(_sessionsCtrl.text.trim()) ?? 0,
                        interval: int.tryParse(_intervalCtrl.text.trim()) ?? 0,
                        intervalUnit: isMaintenance ? _intervalUnit : 'days',
                        firstSessionToday: !isMaintenance && _firstSessionCompletedToday,
                        doctorWorkingDays: _doctorWorkingDays,
                      ),
                      const SizedBox(height: 36),

                      Center(
                        child: SizedBox(
                          width: isDesktop ? 320 : double.infinity,
                          child: AppButton(
                            label: isMaintenance ? 'Generate Maintenance Plan' : 'Generate Treatment Plan',
                            isLoading: _isSubmitting,
                            icon: isMaintenance ? Icons.autorenew_rounded : Icons.auto_awesome_mosaic_rounded,
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
          if (_isSubmitting)
            Container(
              color: context.colors.shadowColor.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.shadowColor.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          color: context.colors.primary,
                          backgroundColor: context.colors.primary.withValues(alpha: 0.15),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Sessions are being scheduled...',
                        style: context.textStyles.h4,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait while we create\nyour treatment plan.',
                        style: context.textStyles.caption.copyWith(
                          color: context.colors.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatSlot(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }
}

// ── Slot Picker Bottom Sheet ────────────────────────────────────────────────
class _SlotPickerSheet extends StatelessWidget {
  final List<String> slots;
  final String selectedSlot;
  final void Function(String) onSelected;

  const _SlotPickerSheet({
    required this.slots,
    required this.selectedSlot,
    required this.onSelected,
  });

  String _fmt(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            width: 40, height: 4,
            decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Text('Choose a Preferred Slot', style: context.textStyles.h3),
          const SizedBox(height: 4),
          Text(
            'Based on doctor\'s schedule & treatment duration',
            style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: slots.length,
            itemBuilder: (context, i) {
              final s = slots[i];
              final isSelected = s == selectedSlot;
              return GestureDetector(
                onTap: () => onSelected(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected ? context.colors.primary : context.colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? context.colors.primary : context.colors.border,
                      width: isSelected ? 0 : 0.8,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: context.colors.primary.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _fmt(s),
                    style: TextStyle(
                      color: isSelected ? Colors.white : context.colors.textPrimary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Session Date Preview ────────────────────────────────────────────────────
class _SessionDatePreview extends StatelessWidget {
  final DateTime startDate;
  final int numSessions;
  final int interval;
  final String intervalUnit;
  final bool firstSessionToday;
  /// Doctor's working weekdays (1=Mon..7=Sun). Empty = no restriction.
  final List<int> doctorWorkingDays;

  const _SessionDatePreview({
    required this.startDate,
    required this.numSessions,
    required this.interval,
    required this.intervalUnit,
    required this.firstSessionToday,
    this.doctorWorkingDays = const [],
  });

  List<DateTime> _computeDates() {
    if (numSessions <= 0 || interval <= 0) return [];
    final dates = <DateTime>[];
    final maxPreview = numSessions > 12 ? 12 : numSessions;
    DateTime current = startDate;

    for (int i = 0; i < maxPreview; i++) {
      if (i == 0 && firstSessionToday) {
        // First session is today regardless of schedule
        dates.add(DateTime(current.year, current.month, current.day));
        current = _advanceByInterval(current);
        continue;
      }

      // Advance to the next valid working day
      current = _skipToWorkingDay(current);
      dates.add(DateTime(current.year, current.month, current.day));
      current = _advanceByInterval(current);
    }
    return dates;
  }

  /// Advance current date by the configured interval.
  DateTime _advanceByInterval(DateTime d) {
    switch (intervalUnit) {
      case 'months':
        return DateTime(d.year, d.month + interval, d.day);
      case 'years':
        return DateTime(d.year + interval, d.month, d.day);
      default: // days
        return d.add(Duration(days: interval));
    }
  }

  /// Skip forward from [d] until we land on a doctor's working day.
  /// If doctorWorkingDays is empty, returns [d] unchanged.
  DateTime _skipToWorkingDay(DateTime d) {
    if (doctorWorkingDays.isEmpty) return d;
    int safety = 0;
    while (!doctorWorkingDays.contains(d.weekday) && safety < 14) {
      d = d.add(const Duration(days: 1));
      safety++;
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final dates = _computeDates();
    if (dates.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.date_range_rounded, size: 16, color: context.colors.primary),
            const SizedBox(width: 6),
            Text('Session Schedule Preview', style: context.textStyles.label.copyWith(fontSize: 12)),
            const Spacer(),
            Text('$numSessions sessions', style: context.textStyles.caption.copyWith(color: context.colors.primary)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: dates.asMap().entries.map((e) {
              final idx = e.key;
              final d = e.value;
              final isToday = DateUtils.isSameDay(d, DateTime.now());
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isToday
                      ? context.colors.primary.withValues(alpha: 0.12)
                      : context.colors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isToday
                        ? context.colors.primary.withValues(alpha: 0.4)
                        : context.colors.border,
                  ),
                ),
                child: Text(
                  '#${idx + 1}  ${DateFormat('MMM d').format(d)}',
                  style: context.textStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday ? context.colors.primary : context.colors.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
          if (numSessions > 12) ...[
            const SizedBox(height: 6),
            Text('... and ${numSessions - 12} more sessions',
                style: context.textStyles.caption.copyWith(color: context.colors.textHint, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}
