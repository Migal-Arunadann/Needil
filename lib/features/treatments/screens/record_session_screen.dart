import 'dart:async';
import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/services/session_timer_service.dart';
import '../../../core/services/appointment_service.dart';
import '../../appointments/providers/appointment_provider.dart';
import '../models/session_model.dart';
import '../providers/treatment_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/services/idle_reminder_service.dart';
import '../../../core/services/photo_quota_service.dart';
import '../../../core/widgets/photo_limit_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart' show UserRole;



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

  /// Timer visible for any active (not completed/missed) session.
  bool get _canUseTimer =>
      _liveSession.status == SessionStatus.inProgress ||
      _liveSession.status == SessionStatus.waiting;

  @override
  void initState() {
    super.initState();
    _liveSession = widget.session; // Initial snapshot; replaced after load
    _isViewMode = widget.session.status == SessionStatus.completed ||
                  widget.session.status == SessionStatus.missed ||
                  widget.session.status == SessionStatus.cancelled;
    _loadFreshSession();
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
        // Pre-fill from saved data (only if controllers are still empty)
        if (_notesCtrl.text.isEmpty && fresh.notes?.isNotEmpty == true)
          _notesCtrl.text = fresh.notes!;
        if (_bpCtrl.text.isEmpty && fresh.bpLevel?.isNotEmpty == true)
          _bpCtrl.text = fresh.bpLevel!;
        if (_pulseCtrl.text.isEmpty && fresh.pulse != null && fresh.pulse! > 0)
          _pulseCtrl.text = fresh.pulse.toString();
        if (_remarksCtrl.text.isEmpty && fresh.remarks?.isNotEmpty == true)
          _remarksCtrl.text = fresh.remarks!;
        _isLoadingSession = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Fallback to the widget snapshot
      setState(() {
        _isViewMode = widget.session.status == SessionStatus.completed ||
                      widget.session.status == SessionStatus.missed ||
                      widget.session.status == SessionStatus.cancelled;
        if (_notesCtrl.text.isEmpty && widget.session.notes?.isNotEmpty == true)
          _notesCtrl.text = widget.session.notes!;
        if (_bpCtrl.text.isEmpty && widget.session.bpLevel?.isNotEmpty == true)
          _bpCtrl.text = widget.session.bpLevel!;
        if (_pulseCtrl.text.isEmpty && widget.session.pulse != null && widget.session.pulse! > 0)
          _pulseCtrl.text = widget.session.pulse.toString();
        if (_remarksCtrl.text.isEmpty && widget.session.remarks?.isNotEmpty == true)
          _remarksCtrl.text = widget.session.remarks!;
        _isLoadingSession = false;
      });
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
      final photoPaths = List<String>.from(_photos.map((p) => p.path));
      final saved = await service.recordSession(
        sessionId: sessionId,
        notes: _notesCtrl.text.trim(),
        bpLevel: _bpCtrl.text.trim(),
        pulse: _pulseCtrl.text.isNotEmpty ? int.tryParse(_pulseCtrl.text.trim()) : null,
        remarks: _remarksCtrl.text.trim(),
        photoPaths: photoPaths,
        isCompleted: false,
      );
      if (mounted && saved.notes != null) {
        setState(() {
          _liveSession = saved;
          _photos.clear(); // Photos now in PB — avoid duplicates
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
    // Stop idle tracking
    IdleReminderService.instance.stopTracking(_liveSession.id);
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
          _onFieldChanged();
        }
      }
    } catch (_) {
      // Camera access failed or user denied — silently ignore
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Only $remaining photo(s) remaining in your quota. Selecting first $remaining.'),
                    backgroundColor: context.colors.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
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
          _onFieldChanged();
        }
      }
    } catch (_) {
      // Gallery access failed or user denied — silently ignore
    }
  }

  Future<void> _submit() async {
    // NOTE: Do NOT end running timer here — timer should persist in background
    // even when saving session details. Only "End Session" on the card stops it.
    // Flush any pending auto-save first
    _autoSaveTimer?.cancel();
    setState(() => _isSubmitting = true);
    final isAlreadyCompleted = _liveSession.status == SessionStatus.completed;
    try {
      final service = ref.read(treatmentServiceProvider);
      final result = await service.recordSession(
        sessionId: _liveSession.id,
        notes: _notesCtrl.text.trim(),
        bpLevel: _bpCtrl.text.trim(),
        pulse: _pulseCtrl.text.isNotEmpty ? int.tryParse(_pulseCtrl.text.trim()) : null,
        remarks: _remarksCtrl.text.trim(),
        photoPaths: _photos.map((p) => p.path).toList(),
        // Save button never completes the session — only End Session on the
        // schedule card does that. Preserve existing status.
        isCompleted: isAlreadyCompleted,
      );
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Session ${_liveSession.sessionNumber} details saved ✓'),
          backgroundColor: context.colors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        if (isAlreadyCompleted) {
          setState(() => _isViewMode = true);
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: context.colors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _markMissed() async {
    // Capture navigator before async gap — fixes Vivo/iQOO devices
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark as Missed?'),
        content: Text('Session ${_liveSession.sessionNumber} will be marked as missed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Mark Missed', style: TextStyle(color: context.colors.error))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(sessionsProvider.notifier).markMissed(_liveSession.id);
      if (mounted) navigator.pop();
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
      case SessionStatus.waiting:    return context.colors.warning;
      case SessionStatus.inProgress: return const Color(0xFFF59E0B);
      case SessionStatus.completed:  return context.colors.success;
      case SessionStatus.missed:     return context.colors.warning;
      case SessionStatus.cancelled:  return context.colors.error;
      case SessionStatus.paused:     return context.colors.info;
    }
  }

  String _statusLabel(SessionStatus s) {
    switch (s) {
      case SessionStatus.upcoming:   return 'Upcoming';
      case SessionStatus.waiting:    return 'Waiting';
      case SessionStatus.inProgress: return 'Ongoing';
      case SessionStatus.completed:  return 'Done';
      case SessionStatus.missed:     return 'Missed';
      case SessionStatus.cancelled:  return 'Cancelled';
      case SessionStatus.paused:     return 'Paused';
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
    final session = _liveSession;
    final sColor = _statusColor(session.status);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
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
                    if (!_isViewMode)
                      GestureDetector(
                        onTap: _markMissed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: context.colors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text('Mark Missed', style: context.textStyles.caption.copyWith(color: context.colors.error)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── VIEW MODE ──
                if (_isViewMode) ...[
                  // Vitals row
                  if ((_bpCtrl.text.trim().isNotEmpty) || (_pulseCtrl.text.trim().isNotEmpty)) ...[
                    Text('Vitals', style: context.textStyles.label),
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
                  _readOnlyField('Remarks', _remarksCtrl.text),

                  // Photos from PocketBase
                  if (_liveSession.photos.isNotEmpty) ...[
                    Text('Photos', style: context.textStyles.label),
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
                              child: Image.network(
                                photoUrl,
                                width: 100, height: 100, fit: BoxFit.cover,
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
                    AppButton(
                      label: 'Edit Session Details',
                      icon: Icons.edit_rounded,
                      onPressed: () => setState(() => _isViewMode = false),
                    ),
                  ],
                ],

                // ── EDIT MODE ──
                if (!_isViewMode) ...[
                  // ── Timer — visible for all active sessions ──
                  _SessionTimerWidget(
                    sessionId: session.id,
                    patientName: widget.patientName ?? 'Patient',
                    routeArgs: {'session': session, 'patientName': widget.patientName ?? 'Patient'},
                  ),
                  const SizedBox(height: 20),

                  // Session Notes
                  Text(
                    'Session Notes',
                    style: context.textStyles.label,
                  ),
                  const SizedBox(height: 8),
                  AppTextField(controller: _notesCtrl, label: '', hint: 'Observations, treatment applied...', maxLines: null, minLines: 4),
                  SizedBox(height: 16),
                  Text('Vitals (Optional)', style: context.textStyles.label),
                  SizedBox(height: 8),
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
                    SizedBox(width: 12),
                    Expanded(child: AppTextField(controller: _pulseCtrl, label: 'Pulse (bpm)', hint: '72',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icon(Icons.monitor_heart_outlined, color: context.colors.warning, size: 18))),
                  ]),
                  const SizedBox(height: 16),
                  Text('Photos', style: context.textStyles.label),
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
                            child: Image.network(photoUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, color: context.colors.textHint)),
                          ),
                        ),
                      );
                    }),
                    // Show newly picked photos
                    ..._photos.asMap().entries.map((e) => _photoThumb(e.key)),
                    if (kIsWeb)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          '⚠️ Photo uploads are only supported on the mobile app.',
                          style: context.textStyles.caption.copyWith(color: context.colors.warning),
                        ),
                      )
                    else ...[
                      if (!Platform.isWindows)
                        _addPhotoBtn(Icons.camera_alt_rounded, 'Camera', _pickPhoto),
                      _addPhotoBtn(Icons.photo_library_rounded, 'Gallery', _pickFromGallery),
                    ],
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
                  _TimerLogRow(sessionId: session.id),
                  const SizedBox(height: 20),

                  AppButton(
                    label: _liveSession.status == SessionStatus.completed ? 'Save Edits' : 'Save Session Details',
                    isLoading: _isSubmitting,
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _submit,
                  ),
                ],
              ],
            ),
          ),
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
            child: Image.network(url, fit: BoxFit.contain,
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
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
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
          child: Image.file(File(_photos[index].path), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(Icons.image_rounded, color: context.colors.textHint)),
        ),
      ),
      Positioned(top: -4, right: -4, child: GestureDetector(
        onTap: () {
          setState(() => _photos.removeAt(index));
          _onFieldChanged();
        },
        child: Container(width: 22, height: 22, decoration: BoxDecoration(color: context.colors.error, shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, size: 14, color: Colors.white)),
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
}

// ═══════════════════════════════════════════════════════════════════════
// Timer Log Row — compact usage info shown inside the form
// ═══════════════════════════════════════════════════════════════════════

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

class _LogCell extends StatelessWidget {
  final String label;
  final String value;
  final BuildContext context;
  const _LogCell({required this.label, required this.value, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.textStyles.caption.copyWith(
            color: context.colors.textHint, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: context.textStyles.label.copyWith(fontSize: 13)),
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
          Text('Session Timer', style: context.textStyles.label),
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
