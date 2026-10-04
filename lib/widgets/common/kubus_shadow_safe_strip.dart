import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

/// A horizontally scrolling strip of [KubusActionTile]s whose hover shadow is
/// neither clipped nor allowed to wander.
///
/// The hovered tile's accent shadow reaches past its own box (an 18 px blur,
/// -5 px spread, 8 px down, under a tile that has itself lifted 2 px: about
/// 7 px above, 21 px below and 13 px to each side). A plain horizontal
/// scroll view clips that hard at its viewport edge. Padding the strip would
/// buy the room but push the first tile out of line with the section title.
///
/// So the room is bought three ways, none of which moves the first tile:
/// - the vertical room is padding inside the viewport (the strip reserves it,
///   so the shadow never lands on the neighbouring section);
/// - the sideways room is an outer clip inflated by [sideBleed], which is no
///   more than the page gutter, so a shadow can finish its fade but never
///   reaches the screen edge;
/// - the trailing room is padding after the last tile, so a tile scrolled to
///   the end has its whole shadow.
class KubusShadowSafeStrip extends StatelessWidget {
  const KubusShadowSafeStrip({
    super.key,
    required this.children,
    this.gap = KubusSpacing.sm,
    this.equalHeight = false,
    this.controller,
  });

  final List<Widget> children;

  /// Space between neighbouring tiles.
  final double gap;

  /// Stretch every tile to the tallest one.
  final bool equalHeight;

  final ScrollController? controller;

  /// Sideways reach of the hover shadow, and the width of the outer clip's
  /// inflation on each side.
  static const double sideBleed = 14;

  /// Vertical room above and below the tiles.
  static const double topRoom = KubusSpacing.sm;
  static const double bottomRoom = KubusSpacing.lg;

  @override
  Widget build(BuildContext context) {
    Widget row = Row(
      crossAxisAlignment:
          equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          children[i],
        ],
      ],
    );
    if (equalHeight) row = IntrinsicHeight(child: row);

    return ClipRect(
      clipper: const _SideBleedClipper(sideBleed),
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(
          top: topRoom,
          bottom: bottomRoom,
          right: sideBleed,
        ),
        child: row,
      ),
    );
  }
}

class _SideBleedClipper extends CustomClipper<Rect> {
  const _SideBleedClipper(this.bleed);

  final double bleed;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-bleed, 0, size.width + bleed, size.height);

  @override
  bool shouldReclip(_SideBleedClipper oldClipper) => oldClipper.bleed != bleed;
}
