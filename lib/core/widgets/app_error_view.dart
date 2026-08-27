import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/error_formatter.dart';

/// Universal, theme-aware error view widget that cleanly displays network/server/app
/// errors with informative titles, humanized descriptions, and retry capabilities.
class AppErrorView extends StatelessWidget {
  final Object? error;
  final String? title;
  final String? description;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool isCompact;
  final IconData? icon;
  final bool showIcon;
  final EdgeInsetsGeometry? padding;

  const AppErrorView({
    super.key,
    this.error,
    this.title,
    this.description,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.isCompact = false,
    this.icon,
    this.showIcon = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isNetwork = ErrorFormatter.isNetworkError(error);
    final displayTitle = title ?? ErrorFormatter.getTitle(error);
    final displayDescription = description ?? ErrorFormatter.getDescription(error);

    final displayIcon = icon ??
        (isNetwork
            ? Icons.wifi_off_rounded
            : Icons.cloud_off_rounded);

    final iconBgColor = isNetwork
        ? context.colors.primary.withValues(alpha: 0.1)
        : context.colors.error.withValues(alpha: 0.1);

    final iconColor = isNetwork
        ? context.colors.primary
        : context.colors.error;

    if (isCompact) {
      return Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(displayIcon, size: 22, color: iconColor),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                displayTitle,
                textAlign: TextAlign.center,
                style: context.textStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayDescription,
                textAlign: TextAlign.center,
                style: context.textStyles.caption.copyWith(
                  color: context.colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onRetry!();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(retryLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.primary,
                    side: BorderSide(color: context.colors.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: padding ?? const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showIcon) ...[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  displayIcon,
                  size: 34,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: context.textStyles.h3.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                displayDescription,
                textAlign: TextAlign.center,
                style: context.textStyles.bodyMedium.copyWith(
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onRetry!();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                label: Text(
                  retryLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
