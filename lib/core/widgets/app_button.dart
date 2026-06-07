import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'package:pms_app/core/theme/app_theme.dart';


/// A styled primary button with gradient background and hover micro-interactions.
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isButtonEnabled = widget.onPressed != null && !widget.isLoading;

    if (widget.isOutlined) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered && isButtonEnabled ? 1.015 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: widget.width ?? double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isButtonEnabled
                      ? (_isHovered
                          ? context.colors.primary.withValues(alpha: 0.8)
                          : context.colors.primary.withValues(alpha: 0.6))
                      : context.colors.divider,
                  width: 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _buildChild(context, isButtonEnabled ? context.colors.primary : context.colors.textHint),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered && isButtonEnabled ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: widget.width ?? double.infinity,
          height: 52,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isButtonEnabled
                  ? LinearGradient(
                      colors: _isHovered
                          ? [const Color(0xFF4F46E5), const Color(0xFF3B82F6)]
                          : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: !isButtonEnabled ? const Color(0xFF1E293B).withValues(alpha: 0.5) : null,
              borderRadius: BorderRadius.circular(14),
              border: isButtonEnabled
                  ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8)
                  : Border.all(color: Colors.white.withValues(alpha: 0.03), width: 0.8),
              boxShadow: isButtonEnabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: _isHovered ? 0.35 : 0.2),
                        blurRadius: _isHovered ? 16 : 12,
                        spreadRadius: _isHovered ? 1 : 0,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _buildChild(context, isButtonEnabled ? Colors.white : context.colors.textHint),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(BuildContext context, Color color) {
    if (widget.isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(widget.label, style: context.textStyles.buttonLarge.copyWith(color: color)),
        ],
      );
    }

    return Text(widget.label, style: context.textStyles.buttonLarge.copyWith(color: color));
  }
}