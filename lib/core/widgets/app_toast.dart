import 'package:flutter/material.dart';
import 'package:pms_app/app.dart';
import 'package:pms_app/core/utils/error_formatter.dart';

enum ToastType { success, error, warning, info }

class AppToast {
  static void show(
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    Color bgColor;
    switch (type) {
      case ToastType.success:
        bgColor = const Color(0xFF10B981); // emerald-500
        break;
      case ToastType.error:
        bgColor = const Color(0xFFEF4444); // red-500
        break;
      case ToastType.warning:
        bgColor = const Color(0xFFF59E0B); // amber-500
        break;
      case ToastType.info:
      default:
        bgColor = const Color(0xFF3B82F6); // blue-500
        break;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ErrorFormatter.format(message),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: duration,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void dismiss([BuildContext? context]) {
    final ctx = context ?? appNavigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.clearSnackBars();
  }
}
