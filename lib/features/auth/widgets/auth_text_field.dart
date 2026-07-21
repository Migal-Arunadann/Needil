import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pms_app/features/auth/theme/needil_auth_theme.dart';

/// A clean text input field styled for the Needil auth flow.
///
/// Supports password visibility toggling, form validation, and adapts its
/// colours automatically between light and dark modes via [NeedilAuthTheme].
class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onTogglePassword;
  final String? Function(String?)? validator;
  final bool isLast;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onTogglePassword,
    this.validator,
    this.isLast = false,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final fillColor = NeedilAuthTheme.inputFill(context);
    final borderColor = NeedilAuthTheme.border(context);
    final primaryColor = NeedilAuthTheme.primary(context);
    final secondaryColor = NeedilAuthTheme.textSecondary(context);
    final textColor = NeedilAuthTheme.text(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label ───────────────────────────────────────────────────────
        Text(
          widget.label,
          style: NeedilAuthTheme.label(context),
        ),
        const SizedBox(height: 8),

        // ── Input ───────────────────────────────────────────────────────
        Focus(
          onFocusChange: (focused) => setState(() => _hasFocus = focused),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasFocus ? primaryColor : borderColor,
                width: _hasFocus ? 1.5 : 1.0,
              ),
            ),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              validator: widget.validator,
              textInputAction:
                  widget.isLast ? TextInputAction.done : TextInputAction.next,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: secondaryColor.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: fillColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                // Remove borders — the outer AnimatedContainer handles them
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
                errorStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.red,
                ),

                // Prefix icon
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: _hasFocus ? primaryColor : secondaryColor,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),

                // Suffix — password toggle
                suffixIcon: widget.isPassword
                    ? GestureDetector(
                        onTap: widget.onTogglePassword,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Icon(
                            widget.obscureText
                                ? LucideIcons.eye
                                : LucideIcons.eyeOff,
                            size: 18,
                            color: secondaryColor,
                          ),
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
