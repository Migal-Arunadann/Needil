import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A Flutter translation of the React AnimatedList component.
///
/// Each [items] widget animates in (scale 0.7 â†’ 1, opacity 0 â†’ 1) when it
/// enters the viewport, and animates back out when it leaves.
/// Top and bottom gradient overlays fade in/out based on scroll position,
/// exactly matching the React behaviour.
///
/// This is intended for **desktop web only**. On mobile, simply wrap
/// children in a [SingleChildScrollView] instead.
class AnimatedFormList extends StatefulWidget {
  /// The list of widgets to display. Each will be individually animated.
  final List<Widget> items;

  /// Horizontal padding applied to every item.
  final double horizontalPadding;

  /// Max width of the content column (centred on screen).
  final double maxWidth;

  /// Whether to show top/bottom gradient fade overlays.
  final bool showGradients;

  /// Colour used for the gradient overlay (should match the page background).
  final Color gradientColor;

  const AnimatedFormList({
    super.key,
    required this.items,
    this.horizontalPadding = 0,
    this.maxWidth = 520,
    this.showGradients = true,
    this.gradientColor = Colors.white,
  });

  @override
  State<AnimatedFormList> createState() => _AnimatedFormListState();
}

class _AnimatedFormListState extends State<AnimatedFormList> {
  final ScrollController _scrollController = ScrollController();

  double _topGradientOpacity = 0;
  double _bottomGradientOpacity = 1;

  /// Tracks which items are currently visible (fraction â‰¥ 0.25).
  final Map<int, bool> _visible = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Pre-mark all items invisible so they animate in on first render.
    for (int i = 0; i < widget.items.length; i++) {
      _visible[i] = false;
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final scrollTop = pos.pixels;
    final maxScroll = pos.maxScrollExtent;

    setState(() {
      _topGradientOpacity = (scrollTop / 50).clamp(0.0, 1.0);
      final bottomDistance = maxScroll - scrollTop;
      _bottomGradientOpacity =
          maxScroll <= 0 ? 0 : (bottomDistance / 50).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          // â”€â”€ Scrollable content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: widget.horizontalPadding,
              vertical: 8,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(widget.items.length, (index) {
                    return _AnimatedItem(
                      key: ValueKey('afl_item_$index'),
                      index: index,
                      isVisible: _visible[index] ?? false,
                      onVisibilityChanged: (visible) {
                        if ((_visible[index] ?? false) != visible) {
                          setState(() => _visible[index] = visible);
                        }
                      },
                      child: widget.items[index],
                    );
                  }),
                ),
              ),
            ),
          ),

          // â”€â”€ Top gradient â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (widget.showGradients)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _topGradientOpacity,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.gradientColor,
                        widget.gradientColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // â”€â”€ Bottom gradient â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (widget.showGradients)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _bottomGradientOpacity,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          widget.gradientColor,
                          widget.gradientColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// A single animated item in the list.
/// Mirrors the React `AnimatedItem` component.
class _AnimatedItem extends StatelessWidget {
  final int index;
  final bool isVisible;
  final ValueChanged<bool> onVisibilityChanged;
  final Widget child;

  const _AnimatedItem({
    super.key,
    required this.index,
    required this.isVisible,
    required this.onVisibilityChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('afl_vis_$index'),
      onVisibilityChanged: (info) {
        onVisibilityChanged(info.visibleFraction >= 0.25);
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: isVisible ? 0.0 : 1.0, end: isVisible ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        builder: (context, t, _) {
          // t: 0 = hidden (scale 0.7, opacity 0), 1 = visible (scale 1, opacity 1)
          final scale = 0.7 + 0.3 * t;
          final opacity = t.clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

