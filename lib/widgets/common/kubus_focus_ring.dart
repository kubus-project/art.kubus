import 'package:flutter/material.dart';

import '../../utils/kubus_color_roles.dart';

/// Keyboard focus indicator shared by PRODUCT controls.
///
/// Draws a [ringWidth] px ring in [KubusColorRoles.focus], set [gap] px outside
/// the control's own edge, with a [haloWidth] px [KubusColorRoles.ground] halo
/// outside the ring. The ring is therefore measured against the surface that
/// sits behind the control (and the halo keeps it separable over imagery),
/// never against the control's own fill, which is what made the earlier
/// translucent focus fills invisible on primary and dark controls.
///
/// The ring is painted outside the child, so it is not clipped by the
/// control, and it is shown only for keyboard traversal
/// ([FocusHighlightMode.traditional]) on an enabled control. Pointer focus,
/// hover, pressed, selected and disabled states keep their own treatments
/// and never draw this ring.
///
/// The wrapper takes no focus of its own ([canRequestFocus] is false) and
/// ignores pointer input, so traversal and hit testing are unchanged.
class KubusFocusRing extends StatefulWidget {
  const KubusFocusRing({
    super.key,
    required this.child,
    required this.borderRadius,
    this.enabled = true,
  });

  final Widget child;

  /// Corner radius of the control; the ring follows the same corners.
  final BorderRadius borderRadius;

  /// Disabled controls never show a focus ring.
  final bool enabled;

  /// Ring stroke width. WCAG 2.4.13 asks for a perimeter of at least 2 px.
  static const double ringWidth = 2;

  /// Halo stroke width outside the ring (separates the ring from imagery).
  static const double haloWidth = 1;

  /// Clear space between the control edge and the ring.
  static const double gap = 2;

  /// Total outset painted beyond the control edge on every side.
  static const double outset = gap + ringWidth + haloWidth;

  @override
  State<KubusFocusRing> createState() => _KubusFocusRingState();
}

class _KubusFocusRingState extends State<KubusFocusRing> {
  bool _hasFocus = false;
  bool _keyboard = false;

  @override
  void initState() {
    super.initState();
    _keyboard =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    super.dispose();
  }

  void _handleHighlightMode(FocusHighlightMode mode) {
    final keyboard = mode == FocusHighlightMode.traditional;
    if (keyboard != _keyboard && mounted) {
      setState(() => _keyboard = keyboard);
    }
  }

  void _handleFocusChange(bool hasFocus) {
    if (hasFocus != _hasFocus && mounted) {
      setState(() => _hasFocus = hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.enabled && _hasFocus && _keyboard;
    final roles = KubusColorRoles.of(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _handleFocusChange,
      // passthrough keeps the parent's tight constraints (full-width CTAs,
      // Expanded nav slots) instead of loosening them for the child.
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (show)
            Positioned(
              left: -KubusFocusRing.outset,
              top: -KubusFocusRing.outset,
              right: -KubusFocusRing.outset,
              bottom: -KubusFocusRing.outset,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _KubusFocusRingPainter(
                    ring: roles.focus,
                    halo: roles.ground,
                    radius: widget.borderRadius.topLeft.x,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KubusFocusRingPainter extends CustomPainter {
  const _KubusFocusRingPainter({
    required this.ring,
    required this.halo,
    required this.radius,
  });

  final Color ring;
  final Color halo;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final outset = KubusFocusRing.outset;
    final control = Rect.fromLTWH(
      outset,
      outset,
      size.width - outset * 2,
      size.height - outset * 2,
    );
    _strokeOutside(
      canvas,
      control,
      inflate: KubusFocusRing.gap + KubusFocusRing.ringWidth / 2,
      strokeWidth: KubusFocusRing.ringWidth,
      color: ring,
    );
    _strokeOutside(
      canvas,
      control,
      inflate: KubusFocusRing.gap +
          KubusFocusRing.ringWidth +
          KubusFocusRing.haloWidth / 2,
      strokeWidth: KubusFocusRing.haloWidth,
      color: halo,
    );
  }

  void _strokeOutside(
    Canvas canvas,
    Rect control, {
    required double inflate,
    required double strokeWidth,
    required Color color,
  }) {
    final rect = control.inflate(inflate);
    final r = (radius + inflate).clamp(0.0, rect.shortestSide / 2).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_KubusFocusRingPainter oldDelegate) =>
      oldDelegate.ring != ring ||
      oldDelegate.halo != halo ||
      oldDelegate.radius != radius;
}
