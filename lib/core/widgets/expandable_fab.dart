import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class ExpandableFab extends StatefulWidget {
  final bool isExtended;
  final VoidCallback onCallBy;
  final VoidCallback onWalkIn;
  final CrossAxisAlignment alignment;

  const ExpandableFab({
    super.key,
    required this.isExtended,
    required this.onCallBy,
    required this.onWalkIn,
    this.alignment = CrossAxisAlignment.end,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _expandAnimation = CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _handleAction(VoidCallback action) {
    if (_isOpen) _toggle();
    action();
  }

  @override
  void didUpdateWidget(covariant ExpandableFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExtended != widget.isExtended && _isOpen) {
      _toggle();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMiniFab(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: AppTextStyles.label.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: widget.isExtended ? 20 : 16),
        decoration: BoxDecoration(
          color: _isOpen ? AppColors.surface : AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (_isOpen ? AppColors.textPrimary : AppColors.primary)
                  .withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: child.key == const ValueKey('close')
                    ? Tween<double>(begin: -0.25, end: 0.0).animate(anim)
                    : Tween<double>(begin: 0.25, end: 0.0).animate(anim),
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Icon(
                _isOpen ? Icons.close_rounded : Icons.add_rounded,
                key: ValueKey(_isOpen ? 'close' : 'add'),
                color: _isOpen ? AppColors.textPrimary : Colors.white,
                size: 24,
              ),
            ),
            if (widget.isExtended) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'New Appointment',
                  overflow: TextOverflow.visible,
                  maxLines: 1,
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: _isOpen ? AppColors.textPrimary : Colors.white,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildOptions() {
    if (widget.isExtended) {
      return IgnorePointer(
        ignoring: !_isOpen,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isOpen ? 1.0 : 0.0,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(_expandAnimation),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniFab('Call-By', Icons.phone_rounded,
                      () => _handleAction(widget.onCallBy)),
                  const SizedBox(height: 12),
                  _buildMiniFab('Walk-In', Icons.directions_walk_rounded,
                      () => _handleAction(widget.onWalkIn)),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return IgnorePointer(
        ignoring: !_isOpen,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isOpen ? 1.0 : 0.0,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.2, 0),
              end: Offset.zero,
            ).animate(_expandAnimation),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildMiniFab('Walk-In', Icons.directions_walk_rounded,
                      () => _handleAction(widget.onWalkIn)),
                  const SizedBox(width: 12),
                  _buildMiniFab('Call-By', Icons.phone_rounded,
                      () => _handleAction(widget.onCallBy)),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isExtended) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildOptions(),
          _buildMainButton(),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildOptions(),
          _buildMainButton(),
        ],
      );
    }
  }
}
