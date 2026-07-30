import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Attempt to read the clinic object and its properties safely
    // Depending on your actual auth state model, you might need to adjust these accessors.
    final clinic = authState.clinic;
    
    final status = clinic?.subscriptionStatus ?? 'Expired';
    final endDate = clinic?.subscriptionEndDate;
    final formattedDate = endDate != null 
        ? endDate.toString().split(' ')[0] 
        : 'Unknown';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Subscription Expired',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Needil subscription has ended. To continue using all features, please renew your subscription from the web dashboard.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            context, 
                            'Status', 
                            status.toString().toUpperCase(), 
                            Theme.of(context).colorScheme.error,
                          ),
                          const Divider(height: 16),
                          _buildInfoRow(context, 'End Date', formattedDate, null),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (kIsWeb)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/billing');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Manage Subscription'),
                    )
                  else
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Please open your account on the Needil web dashboard at needil.com to manage your subscription and payments.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
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
                                  icon: const Icon(Icons.copy, size: 18),
                                  label: const Text('Copy URL'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _launchWebDashboard,
                                  icon: const Icon(Icons.open_in_browser, size: 18),
                                  label: const Text('Open'),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 48),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.bold : null,
              ),
        ),
      ],
    );
  }
}
