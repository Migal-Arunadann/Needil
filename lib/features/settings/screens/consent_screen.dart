import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _hasConsented = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConsentStatus();
  }

  Future<void> _loadConsentStatus() async {
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);
      final userId = auth.userId;

      if (userId != null) {
        final result = await pb.collection('consent_records').getList(
          filter: 'user_id = "$userId" && withdrawn = false',
          sort: '-created',
          perPage: 1,
        );
        setState(() {
          _hasConsented = result.items.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _giveConsent() async {
    setState(() => _isSaving = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);

      await pb.collection('consent_records').create(body: {
        'user_id': auth.userId,
        'consent_type': 'data_processing',
        'purpose': 'Healthcare CRM data collection and processing as per DPDP Act 2023',
        'withdrawn': false,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      setState(() {
        _hasConsented = true;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Consent recorded'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _withdrawConsent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Withdraw Consent?'),
        content: const Text(
          'Per DPDP Act 2023, you have the right to withdraw consent at any time. '
          'This may limit the app\'s functionality, and some data may need to be deleted as per regulations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        final pb = ref.read(pocketbaseProvider);
        final auth = ref.read(authProvider);

        // Mark existing consent as withdrawn
        final existing = await pb.collection('consent_records').getList(
          filter: 'user_id = "${auth.userId}" && withdrawn = false',
        );
        for (final record in existing.items) {
          await pb.collection('consent_records').update(
            record.id,
            body: {'withdrawn': true},
          );
        }

        // Create withdrawal record
        await pb.collection('consent_records').create(body: {
          'user_id': auth.userId,
          'consent_type': 'withdrawal',
          'purpose': 'User withdrew data processing consent',
          'withdrawn': true,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        });

        setState(() {
          _hasConsented = false;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Consent withdrawn'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        setState(() => _isSaving = false);
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
                        Text('Data Privacy', style: AppTextStyles.h2),
                        Text('DPDP Act 2023 Compliance',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 3))
              else ...[
                // Status card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasConsented
                        ? AppColors.success.withValues(alpha: 0.06)
                        : AppColors.warning.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (_hasConsented ? AppColors.success : AppColors.warning)
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (_hasConsented
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _hasConsented
                              ? Icons.verified_user_rounded
                              : Icons.shield_outlined,
                          color: _hasConsented
                              ? AppColors.success
                              : AppColors.warning,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasConsented
                                  ? 'Consent Active'
                                  : 'No Active Consent',
                              style: AppTextStyles.label.copyWith(
                                color: _hasConsented
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                            Text(
                              _hasConsented
                                  ? 'Your data is being processed with your consent'
                                  : 'Data processing requires your explicit consent',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Privacy notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Data Processing Notice',
                              style: AppTextStyles.label.copyWith(
                                  color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _noticeItem('We collect and process your health data solely for treatment purposes'),
                      _noticeItem('Your data is stored securely and encrypted'),
                      _noticeItem('You have the right to access, correct, and delete your data'),
                      _noticeItem('You can withdraw consent at any time'),
                      _noticeItem('Data is shared only with your explicit permission'),
                      _noticeItem('We comply with the Digital Personal Data Protection Act, 2023'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Your rights
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.gavel_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text('Your Rights Under DPDP Act',
                              style: AppTextStyles.label.copyWith(
                                  color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _rightItem('Right to Access', 'View all data collected about you'),
                      _rightItem('Right to Correction', 'Request corrections to inaccurate data'),
                      _rightItem('Right to Erasure', 'Request deletion of your personal data'),
                      _rightItem('Right to Withdraw', 'Withdraw consent at any time'),
                      _rightItem('Right to Grievance', 'File a complaint with the Data Protection Board'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                if (!_hasConsented) ...[
                  AppButton(
                    label: 'I Consent to Data Processing',
                    isLoading: _isSaving,
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: _giveConsent,
                  ),
                ] else ...[
                  AppButton(
                    label: 'Withdraw Consent',
                    isOutlined: true,
                    isLoading: _isSaving,
                    icon: Icons.cancel_outlined,
                    onPressed: _withdrawConsent,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _noticeItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.check_rounded,
                size: 14, color: AppColors.success),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppTextStyles.caption.copyWith(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _rightItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.label.copyWith(fontSize: 12)),
                Text(description,
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
