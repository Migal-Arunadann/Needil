import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:pms_app/features/auth/theme/needil_auth_theme.dart';

/// Primary call-to-action button for Needil auth screens.
///
/// Renders full-width with a solid primary fill, 48 px height, and pill-shaped
/// corners. Shows a [CircularProgressIndicator] during [isLoading],
/// and reduces opacity when disabled or hovered.
class AuthButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  State<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<AuthButton> {
  bool _hovering = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final primaryColor = NeedilAuthTheme.primary(context);
    final hoverColor = NeedilAuthTheme.primaryHover(context);

    return MouseRegion(
      cursor:
          _enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _enabled
            ? (_hovering ? 0.9 : 1.0)
            : 0.5,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _enabled ? widget.onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hovering && _enabled ? hoverColor : primaryColor,
              disabledBackgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.text,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
