import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/core/theme/app_theme.dart';

/// A styled label for forms
class AppLabel extends StatelessWidget {
  final String text;
  final bool isRequired;
  final TextStyle? style;

  const AppLabel({super.key, required this.text, this.isRequired = false, this.style});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return RichText(
      text: TextSpan(
        text: text,
        style: style ?? context.textStyles.label,
        children: [
          if (isRequired)
            TextSpan(
              text: ' *',
              style: (style ?? context.textStyles.label).copyWith(color: Colors.red, fontWeight: FontWeight.bold),
            )
          else
            TextSpan(
              text: ' (optional)',
              style: (style ?? context.textStyles.label).copyWith(color: context.colors.textHint, fontSize: 12, fontWeight: FontWeight.normal),
            ),
        ],
      ),
    );
  }
}

/// A styled text field with consistent theming and high-performance native interactions.
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool isRequired;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
    this.errorText,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      return _WebTextField(
        label: label,
        hint: hint,
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        maxLines: maxLines,
        minLines: minLines,
        enabled: enabled,
        onChanged: onChanged,
        focusNode: focusNode,
        textInputAction: textInputAction,
        readOnly: readOnly,
        onTap: onTap,
        inputFormatters: inputFormatters,
        errorText: errorText,
        isRequired: isRequired,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          RichText(
            text: TextSpan(
              text: label,
              style: context.textStyles.label,
              children: [
                if (isRequired)
                  TextSpan(
                    text: ' *',
                    style: context.textStyles.label.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
                  )
                else
                  TextSpan(
                    text: ' (optional)',
                    style: context.textStyles.label.copyWith(color: context.colors.textHint, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          minLines: minLines,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          focusNode: focusNode,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          style: context.textStyles.bodyLarge.copyWith(color: context.colors.textPrimary),
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hint,
            hintStyle: context.textStyles.bodyMedium.copyWith(
              color: context.colors.textHint,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: WidgetStateColor.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return context.colors.divider;
              }
              if (states.contains(WidgetState.focused)) {
                return context.colors.primary.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.hovered)) {
                return context.colors.border.withValues(alpha: 0.4);
              }
              return context.colors.divider;
            }),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.colors.border.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: WidgetStateColor.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return context.colors.border.withValues(alpha: 0.5);
                  }
                  return context.colors.border.withValues(alpha: 0.5);
                }),
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.colors.primary,
                width: 1.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.error, width: 0.8),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.colors.error,
                width: 1.0,
              ),
            ),
            errorStyle: context.textStyles.caption.copyWith(color: context.colors.error),
          ),
        ),
      ],
    );
  }
}

class _WebTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool isRequired;

  const _WebTextField({
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
    this.errorText,
    this.isRequired = false,
  });

  @override
  State<_WebTextField> createState() => _WebTextFieldState();
}

class _WebTextFieldState extends State<_WebTextField> {
  late final FocusNode _effectiveFocusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    } else {
      _effectiveFocusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF0F5D4F);
    final border = const Color(0xFFE8E6E2);
    final textDark = const Color(0xFF161616);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          RichText(
            text: TextSpan(
              text: widget.label,
              style: context.textStyles.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textDark,
              ),
              children: [
                if (widget.isRequired)
                  TextSpan(
                    text: ' *',
                    style: context.textStyles.label.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
                  )
                else
                  TextSpan(
                    text: ' (optional)',
                    style: context.textStyles.label.copyWith(color: context.colors.textHint, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: (widget.maxLines != null && widget.maxLines! > 1) ? null : 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? primary : border,
              width: _isFocused ? 1.5 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.08),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _effectiveFocusNode,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            onChanged: widget.onChanged,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            style: context.textStyles.bodyLarge.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: textDark,
            ),
            decoration: InputDecoration(
              errorText: widget.errorText,
              hintText: widget.hint,
              hintStyle: context.textStyles.bodyLarge.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFA0A0A0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 15,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? IconTheme(
                      data: const IconThemeData(
                        size: 20,
                        color: Color(0xFF999999),
                      ),
                      child: widget.prefixIcon!,
                    )
                  : null,
              suffixIcon: widget.suffixIcon != null
                  ? IconTheme(
                      data: const IconThemeData(
                        size: 20,
                        color: Color(0xFF999999),
                      ),
                      child: widget.suffixIcon!,
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}