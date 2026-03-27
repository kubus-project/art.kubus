import 'package:art_kubus/utils/keyboard_inset_resolver.dart';
import 'package:flutter/material.dart';

class KeyboardInsetPadding extends StatelessWidget {
  const KeyboardInsetPadding({
    super.key,
    required this.child,
    this.extraBottom = 0,
    this.maxInset = double.infinity,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final double extraBottom;
  final double maxInset;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = KeyboardInsetResolver.effectiveBottomInset(
      context,
      maxInset: maxInset,
    );
    return AnimatedPadding(
      duration: duration,
      curve: curve,
      padding: EdgeInsets.only(bottom: keyboardInset + extraBottom),
      child: child,
    );
  }
}
