import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/time_slot_picker.dart';
import '../../auth/models/doctor_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/clinic_registration/clinic_step3_screen.dart' show BreakTime;
import '../../../core/services/auth_service.dart';

/// Full edit screen for a doctor's registration details —
/// working schedule, treatments (type / duration / fee), and basic info.
///
/// [doctorId] and [doctorModel] can be passed directly (clinic editing a managed
/// doctor), or omitted (doctor editing themselves).
class EditDoctorDetailsScreen extends ConsumerStatefulWidget {
  final String? doctorId;
  final Map<String, dynamic>? doctorRaw; // raw map from the managed-doctors list

  const EditDoctorDetailsScreen({
    super.key,
    this.doctorId,
    this.doctorRaw,
  });

  @override
  ConsumerState<EditDoctorDetailsScreen> createState() =>
      _EditDoctorDetailsScreenState();
}

class _EditDoctorDetailsScreenState
    extends ConsumerState<EditDoctorDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSaving = false;

  // ── Resolved doctor info ─────────────────────────────────────
  String get _resolvedDoctorId {
    if (widget.doctorId != null) return widget.doctorId!;
    return ref.read(authProvider).userId ?? '';
  }

  // ── Basic info ───────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  // Keep track of original values so we only patch what changed
  String? _originalName;
  String? _originalEmail;
  int? _originalAge;

  // ── Working schedule state ───────────────────────────────────
  static const List<String> _allDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  final Map<String, bool> _selectedDays = {for (var d in _allDays.toList()) d: false};
  final Map<String, TimeOfDay> _startTimes = {};
  final Map<String, TimeOfDay> _endTimes = {};

  /// Per-day breaks — list so we can support multiple breaks.
  final Map<String, List<BreakTime>> _dayBreaks = {};

  // ── Date of birth ────────────────────────────────────────────
  DateTime? _dateOfBirth;

  // ── Treatments state ─────────────────────────────────────────
  static const List<String> _treatmentTypes = [
    'Acupuncture',
    'Acupressure',
    'Cupping Therapy',
    'Physiotherapy',
    'Foot Reflexology',
  ];
  final Map<String, bool> _treatmentEnabled = {for (var t in _treatmentTypes) t: false};
  final Map<String, TextEditingController> _durationCtrls = {};
  final Map<String, TextEditingController> _feeCtrls = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    for (final t in _treatmentTypes) {
      _durationCtrls[t] = TextEditingController(text: '30');
      _feeCtrls[t] = TextEditingController(text: '');
    }

    _loadDoctorData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    for (final c in _durationCtrls.values) { c.dispose(); }
    for (final c in _feeCtrls.values) { c.dispose(); }
    super.dispose();
  }

  // ── Load doctor data ─────────────────────────────────────────
  Future<void> _loadDoctorData() async {
    setState(() => _isLoading = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final record = await pb.collection(PBCollections.doctors).getOne(_resolvedDoctorId);
      final doc = DoctorModel.fromRecord(record);

      // Basic info
      _originalName = doc.name;
      _originalEmail = doc.email ?? '';
      _originalAge = doc.age;

      _nameCtrl.text = _originalName!;
      _emailCtrl.text = _originalEmail!;
      _ageCtrl.text = _originalAge != null ? '$_originalAge' : '';

      // Date of birth
      if (doc.dateOfBirth != null && doc.dateOfBirth!.isNotEmpty) {
        _dateOfBirth = DateTime.tryParse(doc.dateOfBirth!);
      }

      // Working schedule
      for (final ws in doc.workingSchedule) {
        _selectedDays[ws.day] = true;
        _startTimes[ws.day] = _parseTime(ws.startTime);
        _endTimes[ws.day] = _parseTime(ws.endTime);
        // Load multiple breaks
        _dayBreaks[ws.day] = ws.breaks.map((b) => BreakTime(
          from: _parseTime(b['start']!),
          to: _parseTime(b['end']!),
        )).toList();
      }

      // Treatments
      for (final t in doc.treatments) {
        if (_treatmentEnabled.containsKey(t.type)) {
          _treatmentEnabled[t.type] = true;
          _durationCtrls[t.type]?.text = '${t.durationMinutes}';
          _feeCtrls[t.type]?.text = '${t.fee.toInt()}';
        }
      }
    } catch (e) {
      _showError('Failed to load doctor details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatTimeDisplay(TimeOfDay t) {
    final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final amPm = t.hour < 12 ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $amPm';
  }

  // ── Pick a time via TimeSlotPicker ───────────────────────────
  Future<void> _pickDayTime(String day, String type) async {
    final initial = type == 'start'
        ? (_startTimes[day] ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTimes[day] ?? const TimeOfDay(hour: 17, minute: 0));
    FocusScope.of(context).unfocus();
    final picked = await TimeSlotPicker.show(context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() {
        if (type == 'start') _startTimes[day] = picked;
        else _endTimes[day] = picked;
      });
    }
  }

  Future<void> _pickBreakTime(String day, int breakIndex, String type) async {
    final breaks = _dayBreaks[day] ?? [];
    if (breakIndex >= breaks.length) return;
    final b = breaks[breakIndex];
    final initial = type == 'from'
        ? (b.from ?? const TimeOfDay(hour: 13, minute: 0))
        : (b.to ?? const TimeOfDay(hour: 14, minute: 0));
    FocusScope.of(context).unfocus();
    final picked = await TimeSlotPicker.show(context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() {
        if (type == 'from') breaks[breakIndex].from = picked;
        else breaks[breakIndex].to = picked;
        _dayBreaks[day] = breaks;
      });
    }
  }


  // ── Validate & Save ──────────────────────────────────────────
  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    // Validate working schedule
    final activeDays = _selectedDays.entries.where((e) => e.value).toList();
    if (activeDays.isEmpty) {
      _showError('Please select at least one working day');
      _tabController.animateTo(1);
      return;
    }
    for (final entry in activeDays) {
      final d = entry.key;
      if (!_startTimes.containsKey(d) || !_endTimes.containsKey(d)) {
        _showError('Set start & end times for ${entry.key}');
        _tabController.animateTo(1);
        return;
      }
      final start = _startTimes[d]!;
      final end = _endTimes[d]!;
      if (start.hour * 60 + start.minute >= end.hour * 60 + end.minute) {
        _showError('For ${entry.key}: end time must be after start time');
        _tabController.animateTo(1);
        return;
      }
      // Validate break times
      final breaks = _dayBreaks[d] ?? [];
      for (int i = 0; i < breaks.length; i++) {
        final b = breaks[i];
        if (b.from == null || b.to == null) {
          _showError('For ${entry.key}: complete break ${i + 1} times');
          _tabController.animateTo(1);
          return;
        }
        if (b.from!.hour * 60 + b.from!.minute >= b.to!.hour * 60 + b.to!.minute) {
          _showError('For ${entry.key}: break ${i + 1} end must be after start');
          _tabController.animateTo(1);
          return;
        }
      }
    }

    // Validate treatments
    final activeTreatments = _treatmentEnabled.entries.where((e) => e.value).toList();
    if (activeTreatments.isEmpty) {
      _showError('Please enable at least one treatment');
      _tabController.animateTo(2);
      return;
    }

    for (final e in activeTreatments) {
      final t = e.key;
      final dur = _durationCtrls[t]?.text.trim() ?? '';
      final fee = _feeCtrls[t]?.text.trim() ?? '';
      if (dur.isEmpty || fee.isEmpty) {
        _showError('Please enter fee and duration for $t');
        _tabController.animateTo(2);
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final pb = ref.read(pocketbaseProvider);

      // Build working schedule list (array-format breaks)
      final schedule = activeDays.map((e) {
        final d = e.key;
        final breaks = (_dayBreaks[d] ?? [])
            .where((b) => b.from != null && b.to != null)
            .map((b) => {'start': _formatTime(b.from!), 'end': _formatTime(b.to!)})
            .toList();
        final m = <String, dynamic>{
          'day': d,
          'start': _formatTime(_startTimes[d]!),
          'end': _formatTime(_endTimes[d]!),
          if (breaks.isNotEmpty) 'breaks': breaks,
        };
        return m;
      }).toList();

      // Build treatments list
      final treatments = activeTreatments.map((e) {
        final t = e.key;
        return {
          'type': t,
          'duration_min': int.tryParse(_durationCtrls[t]?.text ?? '30') ?? 30,
          'fee': double.tryParse(_feeCtrls[t]?.text ?? '0') ?? 0,
        };
      }).toList();

      final body = <String, dynamic>{
        'working_schedule': schedule,
        'treatments': treatments,
      };
      final newName = _nameCtrl.text.trim();
      if (newName.isNotEmpty && newName != _originalName) body['name'] = newName;
      final newAge = int.tryParse(_ageCtrl.text.trim());
      if (newAge != null && newAge != _originalAge) body['age'] = newAge;
      if (_dateOfBirth != null) {
        body['dob'] = '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2,'0')}-${_dateOfBirth!.day.toString().padLeft(2,'0')}';
      }

      // Ensure we don't send the email in the main update request to avoid 400 validation_values_mismatch
      await pb.collection(PBCollections.doctors).update(_resolvedDoctorId, body: body);

      // Handle email change separately using the PocketBase email change flow
      final newEmail = _emailCtrl.text.trim();
      bool emailChangeRequested = false;
      if (newEmail.isNotEmpty && newEmail != _originalEmail) {
        await pb.collection(PBCollections.doctors).requestEmailChange(newEmail);
        emailChangeRequested = true;
      }

      // If editing own profile, refresh auth state
      final auth = ref.read(authProvider);
      if (auth.role == UserRole.doctor && auth.userId == _resolvedDoctorId) {
        await ref.read(authProvider.notifier).restoreSession();
      }

      if (mounted) {
        if (emailChangeRequested) {
          _showSuccess(
            'Saved! A confirmation link was sent to $newEmail to verify the new email address.',
          );
        } else {
          _showSuccess('Doctor details saved!');
        }
        Navigator.pop(context, true); // Signal caller to refresh
      }
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final doctorName = _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'Doctor';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            children: [
              Text('Edit Doctor Details', style: AppTextStyles.h4),
              if (_nameCtrl.text.isNotEmpty)
                Text(
                  doctorName,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: AppTextStyles.label.copyWith(fontSize: 14),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textHint,
            labelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.person_outline_rounded, size: 18), text: 'Basic Info'),
              Tab(icon: Icon(Icons.schedule_rounded, size: 18), text: 'Availability'),
              Tab(icon: Icon(Icons.medical_services_outlined, size: 18), text: 'Treatments'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInfoTab(),
                  _buildAvailabilityTab(),
                  _buildTreatmentsTab(),
                ],
              ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: Basic Info
  // ════════════════════════════════════════════════════════════

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Personal Information', Icons.badge_outlined),
          const SizedBox(height: 16),
          AppTextField(
            controller: _nameCtrl,
            label: 'Full Name',
            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email Address',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _ageCtrl,
            label: 'Age',
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          // DOB picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime(1990),
                firstDate: DateTime(1930),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) setState(() => _dateOfBirth = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _dateOfBirth != null ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 18, color: _dateOfBirth != null ? AppColors.primary : AppColors.textHint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dateOfBirth != null
                          ? '${_dateOfBirth!.day.toString().padLeft(2,'0')}/${_dateOfBirth!.month.toString().padLeft(2,'0')}/${_dateOfBirth!.year}'
                          : 'Date of Birth',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _dateOfBirth != null ? AppColors.textPrimary : AppColors.textHint,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textHint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'Save All Changes',
            isLoading: _isSaving,
            icon: Icons.save_rounded,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: Availability / Working Schedule
  // ════════════════════════════════════════════════════════════

  Widget _buildAvailabilityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Working Days & Hours', Icons.event_available_rounded),
          const SizedBox(height: 6),
          Text(
            'Select working days and configure start, end, and optional break times for each.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),

          // Day chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allDays.map((day) {
              final selected = _selectedDays[day]!;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedDays[day] = !selected;
                  if (!_selectedDays[day]!) {
                    _startTimes.remove(day);
                    _endTimes.remove(day);
                    _dayBreaks.remove(day);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.heroGradient : null,
                    color: selected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    day.substring(0, 3),
                    style: AppTextStyles.label.copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Per-day config
          ..._allDays.where((d) => _selectedDays[d]!).map((day) => _dayScheduleCard(day)),

          const SizedBox(height: 24),
          AppButton(
            label: 'Save All Changes',
            isLoading: _isSaving,
            icon: Icons.save_rounded,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _dayScheduleCard(String day) {
    final isHalfDay = day == 'Saturday' || day == 'Sunday';
    final breaks = _dayBreaks[day] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isHalfDay
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isHalfDay ? Icons.wb_sunny_outlined : Icons.work_outline_rounded,
                  size: 18,
                  color: isHalfDay ? AppColors.warning : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(day, style: AppTextStyles.label.copyWith(fontSize: 15))),
              if (isHalfDay)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Weekend',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Start & End times
          Row(
            children: [
              Expanded(child: _timePickerTile('From', _startTimes[day], () => _pickDayTime(day, 'start'), AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _timePickerTile('To', _endTimes[day], () => _pickDayTime(day, 'end'), AppColors.error)),
            ],
          ),
          const SizedBox(height: 12),

          // Break list
          ...List.generate(breaks.length, (i) {
            final b = breaks[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.coffee_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text('Break ${i + 1}:', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(child: _timePickerTile('From', b.from, () => _pickBreakTime(day, i, 'from'), AppColors.warning)),
                  const SizedBox(width: 6),
                  Expanded(child: _timePickerTile('To', b.to, () => _pickBreakTime(day, i, 'to'), AppColors.warning)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() {
                      breaks.removeAt(i);
                      _dayBreaks[day] = breaks;
                    }),
                    child: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppColors.error),
                  ),
                ],
              ),
            );
          }),

          // Add break button
          GestureDetector(
            onTap: () => setState(() {
              _dayBreaks[day] = [...breaks, BreakTime()];
            }),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.textHint),
                const SizedBox(width: 6),
                Text('Add break time', style: AppTextStyles.caption.copyWith(
                  color: AppColors.textHint, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _timePickerTile(
    String label,
    TimeOfDay? time,
    VoidCallback onTap,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: time != null
              ? accentColor.withValues(alpha: 0.06)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: time != null ? accentColor.withValues(alpha: 0.3) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10, color: accentColor)),
                  Text(
                    time != null ? _formatTimeDisplay(time) : 'Tap to set',
                    style: AppTextStyles.label.copyWith(
                      fontSize: 12,
                      color: time != null ? AppColors.textPrimary : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: Treatments
  // ════════════════════════════════════════════════════════════

  Widget _buildTreatmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Treatment Types & Fees', Icons.medical_services_outlined),
          const SizedBox(height: 6),
          Text(
            'Enable each treatment you offer and set session duration and consultation fee.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),

          ..._treatmentTypes.map((t) => _treatmentCard(t)),

          const SizedBox(height: 24),
          AppButton(
            label: 'Save All Changes',
            isLoading: _isSaving,
            icon: Icons.save_rounded,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _treatmentCard(String type) {
    final enabled = _treatmentEnabled[type]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
          width: enabled ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Header row — tap to toggle
          GestureDetector(
            onTap: () => setState(() => _treatmentEnabled[type] = !enabled),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _treatmentIcon(type),
                      color: enabled ? AppColors.primary : AppColors.textHint,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type, style: AppTextStyles.label.copyWith(fontSize: 14)),
                        if (enabled) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_durationCtrls[type]?.text ?? 30} min · ₹${_feeCtrls[type]?.text ?? 0}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (v) => setState(() => _treatmentEnabled[type] = v),
                    activeTrackColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),

          // Expanded form when enabled
          if (enabled) ...[
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _miniField(
                      ctrl: _durationCtrls[type]!,
                      label: 'Session (min)',
                      icon: Icons.timelapse_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _miniField(
                      ctrl: _feeCtrls[type]!,
                      label: 'Fee (₹)',
                      icon: Icons.currency_rupee_rounded,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.caption.copyWith(color: color, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: color.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════

  IconData _treatmentIcon(String type) {
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
        return Icons.science_outlined;
    }
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(title, style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
      ],
    );
  }
}
