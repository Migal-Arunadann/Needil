import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionLockedScreen extends ConsumerWidget {
  const SubscriptionLockedScreen({super.key});

  Future<void> _launchWebDashboard() async {
    final url = Uri.parse('https://needil.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final clinic = authState.clinic;
    final isStaff = authState.role == UserRole.doctor || authState.role == UserRole.receptionist;

    final status = clinic?.subscriptionStatus ?? 'Expired';
    final endDate = clinic?.subscriptionEndDate;
    final formattedDate = endDate != null ? DateFormat('dd MMMM yyyy').format(endDate) : 'Unknown';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: context.colors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_clock_rounded,
                      size: 38,
                      color: context.colors.error,
                    ),
                  ),
                  Text(
                    isStaff ? 'Clinic Subscription Expired' : 'Subscription Expired',
                    style: context.textStyles.h2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isStaff
                        ? 'Clinic subscription has expired. Please contact your clinic administrator to renew.'
                        : 'Your Needil subscription has ended. To continue using all clinical features, please renew your subscription.',
                    style: context.textStyles.bodyMedium.copyWith(
                      color: context.colors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.colors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        if (clinic?.name != null && clinic!.name.isNotEmpty) ...[
                          _buildInfoRow(context, 'Clinic', clinic.name, context.colors.textPrimary),
                          const Divider(height: 20),
                        ],
                        _buildInfoRow(
                          context,
                          'Status',
                          status.toUpperCase(),
                          context.colors.error,
                        ),
                        const Divider(height: 20),
                        _buildInfoRow(context, 'Expiry Date', formattedDate, context.colors.textSecondary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!isStaff) ...[
                    if (kIsWeb)
                      ElevatedButton(
                        onPressed: () => context.push('/billing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Manage & Renew Subscription', style: TextStyle(fontWeight: FontWeight.w700)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Please open your account on the Needil web dashboard at needil.com to manage your subscription and renew access.',
                              style: context.textStyles.caption.copyWith(color: context.colors.textPrimary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(const ClipboardData(text: 'https://needil.com'));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('URL copied to clipboard')),
                                    );
                                  },
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copy URL'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _launchWebDashboard,
                                  icon: const Icon(Icons.open_in_browser, size: 16),
                                  label: const Text('Open Web'),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: context.colors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Only clinic administrators can renew subscriptions and extend access.',
                              style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, Color? valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: context.textStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: context.textStyles.bodyMedium.copyWith(
            color: valueColor ?? context.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

