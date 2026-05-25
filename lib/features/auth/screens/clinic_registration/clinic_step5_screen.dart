import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../providers/auth_provider.dart';
import '../../providers/registration_cache_provider.dart';
import '../../screens/otp_verification_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';


/// Clinic Registration — Step 5 of 5: Receptionist Account.
class ClinicStep5Screen extends ConsumerStatefulWidget {
  final Map<String, dynamic> clinicData;
  const ClinicStep5Screen({super.key, required this.clinicData});

  @override
  ConsumerState<ClinicStep5Screen> createState() => _ClinicStep5ScreenState();
}

class _ClinicStep5ScreenState extends ConsumerState<ClinicStep5Screen> {
  bool _enableReceptionist = false;
  final _recNameCtrl = TextEditingController();
  final _recUsernameCtrl = TextEditingController();
  final _recPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false; // Local guard against double-tap

  Timer? _debounce;
  bool _isCheckingUsername = false;
  String? _usernameError;

  late final RegistrationCacheNotifier _cacheNotifier;

  @override
  void initState() {
    super.initState();
    _cacheNotifier = ref.read(registrationCacheProvider.notifier);
    final cache = ref.read(registrationCacheProvider);
    // Restore receptionist fields
    _enableReceptionist = cache.enableReceptionist;
    if (cache.recName.isNotEmpty) _recNameCtrl.text = cache.recName;
    if (cache.recUsername.isNotEmpty) _recUsernameCtrl.text = cache.recUsername;
    if (cache.recPassword.isNotEmpty) _recPasswordCtrl.text = cache.recPassword;

    _recUsernameCtrl.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() {
    if (!_enableReceptionist) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final value = _recUsernameCtrl.text;

    if (value.length < 3) {
      if (mounted) setState(() => _usernameError = null);
      return;
    }

    if (mounted) setState(() => _isCheckingUsername = true);

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final authService = ref.read(authProvider.notifier).authService;
      final exists = await authService.checkUsernameExists(value);
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _usernameError = exists ? 'Username is already taken' : null;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Save receptionist state so it survives going back and forward
    _cacheNotifier.saveReceptionist(
      enabled: _enableReceptionist,
      name: _recNameCtrl.text,
      username: _recUsernameCtrl.text,
      password: _recPasswordCtrl.text,
    );
    _recNameCtrl.dispose();
    _recUsernameCtrl.dispose();
    _recPasswordCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: context.colors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submit() async {
    if (_isSubmitting) return; // Prevent double-tap
    FocusScope.of(context).unfocus();

    // Validate receptionist if enabled
    Map<String, dynamic>? receptionistData;
    if (_enableReceptionist) {
      final username = _recUsernameCtrl.text.trim();
      if (_recNameCtrl.text.trim().isEmpty) { _showSnack('Receptionist name is required'); return; }
      if (username.isEmpty) { _showSnack('Receptionist username is required'); return; }
      
      // Check against clinic username
      if (username == widget.clinicData['username']) {
        _showSnack('Username "$username" is already assigned to the clinic'); return;
      }
      
      // Check against additional doctors
      final rawAdditional = widget.clinicData['additional_doctors'] as List<dynamic>?;
      if (rawAdditional != null) {
        for (final d in rawAdditional) {
          if (username == d['username']) {
            _showSnack('Username "$username" is already assigned to a working doctor'); return;
          }
        }
      }

      if (_usernameError != null) { _showSnack(_usernameError!); return; }
      if (_recPasswordCtrl.text.trim().length < 8) { _showSnack('Password must be at least 8 characters'); return; }
      receptionistData = {
        'name': _recNameCtrl.text.trim(),
        'username': username,
        'password': _recPasswordCtrl.text.trim(),
      };
    }

    // Extract primary doctor data
    final primaryDoctorMap = widget.clinicData['primary_doctor'] as Map<String, dynamic>;
    final photoPath = primaryDoctorMap['photo_path'] as String?;

    final primaryDoctorData = {
      'name': primaryDoctorMap['name'],
      'date_of_birth': primaryDoctorMap['date_of_birth'],
      'working_schedule': primaryDoctorMap['working_schedule'],
      'treatments': primaryDoctorMap['treatments'],
    };

    // Extract additional doctors
    final rawAdditional = widget.clinicData['additional_doctors'] as List<dynamic>?;
    List<Map<String, dynamic>>? additionalDoctors;
    if (rawAdditional != null && rawAdditional.isNotEmpty) {
      additionalDoctors = rawAdditional.map((d) => Map<String, dynamic>.from(d as Map)).toList();
    }

    // Build the full clinic payload to hold in provider state while waiting for OTP
    final clinicPayload = <String, dynamic>{
      'clinic_name': widget.clinicData['clinic_name'],
      'username': widget.clinicData['username'],
      'password': widget.clinicData['password'],
      'bed_count': widget.clinicData['bed_count'],
      'city': widget.clinicData['city'],
      'area': widget.clinicData['area'],
      'state': widget.clinicData['state'],
      'pincode': widget.clinicData['pincode'],
      'primary_doctor_data': primaryDoctorData,
      if (photoPath != null) 'doctor_photo_path': photoPath,
      if (additionalDoctors != null) 'additional_doctors': additionalDoctors,
      if (receptionistData != null) 'receptionist_data': receptionistData,
    };
    setState(() => _isSubmitting = true);
    await ref.read(authProvider.notifier).completeClinicRegistration(
      clinicName: widget.clinicData['clinic_name'],
      username: widget.clinicData['username'],
      password: widget.clinicData['password'],
      bedCount: widget.clinicData['bed_count'],
      primaryDoctorData: primaryDoctorData,
      doctorPhotoFile: photoPath != null ? File(photoPath) : null,
      additionalDoctors: additionalDoctors,
      receptionistData: receptionistData,
      city: widget.clinicData['city'],
      area: widget.clinicData['area'],
      stateField: widget.clinicData['state'],
      pincode: widget.clinicData['pincode'],
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      final finalState = ref.read(authProvider);
      if (finalState.error != null) {
        _showSnack(finalState.error!);
      } else if (finalState.isAuthenticated) {
        ref.read(registrationCacheProvider.notifier).clear();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
            onPressed: () { FocusScope.of(context).unfocus(); Navigator.of(context).pop(); },
          ),
          title: Text('Clinic Registration', style: context.textStyles.h4),
          centerTitle: true,
        ),
        body: LoadingOverlay(
          isLoading: authState.isLoading,
          message: 'Creating your clinic...',
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildStepIndicator(5, 5),
                  const SizedBox(height: 24),

                  // Header
                  Text('Almost Done!', style: context.textStyles.h2),
                  const SizedBox(height: 6),
                  Text('Optionally set up a receptionist account for your clinic.',
                    style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary)),
                  const SizedBox(height: 32),

                  // Summary card
                  _buildSummaryCard(),
                  const SizedBox(height: 28),

                  // Receptionist toggle card
                  _buildReceptionistCard(),
                  const SizedBox(height: 32),

                  AppButton(
                    label: 'Create Clinic',
                    onPressed: (_isSubmitting || authState.isLoading) ? null : _submit,
                    isLoading: _isSubmitting || authState.isLoading,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  if (!_enableReceptionist)
                    Center(child: Text(
                      'You can add a receptionist later from Settings.',
                      style: context.textStyles.caption.copyWith(color: context.colors.textHint),
                      textAlign: TextAlign.center,
                    )),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final primaryDoc = widget.clinicData['primary_doctor'] as Map<String, dynamic>;
    final additionalRaw = widget.clinicData['additional_doctors'] as List<dynamic>?;
    final additionalCount = additionalRaw?.length ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.colors.primary.withValues(alpha: 0.07), context.colors.accent.withValues(alpha: 0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.check_circle_rounded, color: context.colors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Registration Summary', style: context.textStyles.label.copyWith(fontSize: 15)),
        ]),
        const SizedBox(height: 16),
        _summaryRow(Icons.local_hospital_rounded, 'Clinic', widget.clinicData['clinic_name'] ?? ''),
        const SizedBox(height: 10),
        _summaryRow(Icons.person_rounded, 'Primary Doctor', primaryDoc['name'] ?? ''),
        if (additionalCount > 0) ...[
          const SizedBox(height: 10),
          _summaryRow(Icons.group_rounded, 'Working Doctors', '$additionalCount doctor${additionalCount > 1 ? 's' : ''} added'),
        ],
      ]),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: context.colors.textHint),
      const SizedBox(width: 8),
      Text('$label: ', style: context.textStyles.caption.copyWith(color: context.colors.textHint)),
      Expanded(child: Text(value, style: context.textStyles.caption.copyWith(color: context.colors.textPrimary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _buildReceptionistCard() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _enableReceptionist ? context.colors.info.withValues(alpha: 0.04) : context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _enableReceptionist ? context.colors.info.withValues(alpha: 0.3) : context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Toggle row
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: context.colors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.support_agent_rounded, color: context.colors.info, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Receptionist Account', style: context.textStyles.label.copyWith(fontSize: 15)),
            const SizedBox(height: 3),
            Text('Enable to add a receptionist login',
              style: context.textStyles.caption.copyWith(color: context.colors.textHint, fontSize: 11)),
          ])),
          Switch.adaptive(
            value: _enableReceptionist,
            onChanged: (v) => setState(() => _enableReceptionist = v),
            activeColor: context.colors.info,
          ),
        ]),

        if (_enableReceptionist) ...[
          SizedBox(height: 20),
          Divider(color: context.colors.border.withValues(alpha: 0.5), height: 1),
          SizedBox(height: 20),

          AppTextField(
            label: 'Receptionist Name',
            hint: 'e.g. Priya',
            controller: _recNameCtrl,
            prefixIcon: Icon(Icons.person_outline_rounded, color: context.colors.textHint),
          ),
          SizedBox(height: 14),

          Stack(
            alignment: Alignment.centerRight,
            children: [
              AppTextField(
                label: 'Username',
                hint: 'Login username for receptionist',
                controller: _recUsernameCtrl,
                errorText: _usernameError,
                prefixIcon: Icon(Icons.alternate_email_rounded, color: context.colors.textHint),
              ),
              if (_isCheckingUsername)
                Positioned(
                  right: 16,
                  top: 40,
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14),

          AppTextField(
            label: 'Password',
            hint: 'Min 8 characters',
            controller: _recPasswordCtrl,
            prefixIcon: Icon(Icons.lock_outline_rounded, color: context.colors.textHint),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: context.colors.textHint, size: 20),
            ),
          ),

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.info.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.shield_outlined, color: context.colors.info, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Receptionists can manage appointments and patients, but cannot access medical records or consultations.',
                style: context.textStyles.caption.copyWith(color: context.colors.info, fontSize: 11),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final step = i + 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: step < total ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: step <= current ? context.colors.primary : context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}