import 'package:flutter/material.dart';

import '../utils/app_animations.dart';

/// Reusable helper that applies a fade + slide animation with simple staggering.
class StaggeredFadeSlide extends StatelessWidget {
  const StaggeredFadeSlide({
    super.key,
    required this.animation,
    required this.position,
    required this.child,
    this.axis = Axis.vertical,
    this.offset = 0.04,
    this.intervalExtent,
  });

  /// Parent animation (usually an [AnimationController]).
  final Animation<double> animation;

  /// The position of this section in the staggered sequence.
  final int position;

  /// Child widget to animate into view.
  final Widget child;

  /// Direction of the slide offset.
  final Axis axis;

  /// Offset applied before animating back to zero.
  final double offset;

  /// Optional custom interval size. When null an automatic spacing is used.
  final double? intervalExtent;

  static const double _defaultExtent = 0.12;

  @override
  Widget build(BuildContext context) {
    final animationTheme = context.animationTheme;
    final intervalSize = intervalExtent ?? _defaultExtent;
    final start = (position * intervalSize).clamp(0.0, 1.0 - intervalSize);
    final end = (start + intervalSize).clamp(start, 1.0);

    final fade = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: animationTheme.fadeCurve),
    );
    final slide = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: animationTheme.defaultCurve),
    );

    final slideTween = Tween<Offset>(
      begin: axis == Axis.horizontal ? Offset(offset, 0) : Offset(0, offset),
      end: Offset.zero,
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slideTween.animate(slide),
        child: child,
      ),
    );
  }
}
