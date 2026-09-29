import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

/// Size steps for [KubusContextIcon]. Pick one; never hand-roll geometry.
enum KubusContextIconSize {
  /// 30 box / 16 glyph: metric tiles, dense rows, chips.
  compact,

  /// 38 box / 20 glyph: section headers, settings categories.
  regular,

  /// 52 box / 26 glyph: page identity, empty states.
  hero,
}

/// Geometry of each [KubusContextIconSize] step, for layouts that reserve
/// room for a tile.
extension KubusContextIconMetrics on KubusContextIconSize {
  double get box => switch (this) {
        KubusContextIconSize.compact => 30,
        KubusContextIconSize.regular => 38,
        KubusContextIconSize.hero => 52,
      };

  double get glyph => switch (this) {
        KubusContextIconSize.compact => 16,
        KubusContextIconSize.regular => 20,
        KubusContextIconSize.hero => 26,
      };

  double get radius => switch (this) {
        KubusContextIconSize.compact => KubusRadius.sm,
        KubusContextIconSize.regular => KubusRadius.sm,
        KubusContextIconSize.hero => KubusRadius.md,
      };
}

/// PRODUCT v5 contextual icon tile: the one place a surface carries its
/// orientation colour.
///
/// A flat rounded square with a restrained accent wash, an accent hairline and
/// a full-strength glyph. No glass, no glow, no shadow. Use it for section
/// identity, metric category, primary utility, asset identity and status —
/// not for chevrons, back arrows, overflow menus or every row icon.
///
/// The tile is decorative by default ([semanticLabel] null) because it sits
/// beside the text that names it; pass a label only when the icon carries
/// meaning nothing else states.
class KubusContextIcon extends StatelessWidget {
  const KubusContextIcon({
    super.key,
    required this.icon,
    required this.accent,
    this.size = KubusContextIconSize.regular,
    this.selected = false,
    this.semanticLabel,
  });

  final IconData icon;

  /// Contextual accent from [KubusColorRoles] (never a raw literal).
  final Color accent;
  final KubusContextIconSize size;

  /// Selected tiles take a stronger wash and a solid keyline.
  final bool selected;
  final String? semanticLabel;

  /// Accent wash alphas; the contract the character-rebalance doc records.
  static const double fillAlpha = 0.12;
  static const double selectedFillAlpha = 0.20;
  static const double borderAlpha = 0.38;

  @override
  Widget build(BuildContext context) {
    final box = size.box;
    final tile = Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: selected ? selectedFillAlpha : fillAlpha,
        ),
        borderRadius: BorderRadius.circular(size.radius),
        border: Border.all(
          color: selected ? accent : accent.withValues(alpha: borderAlpha),
          width: KubusSizes.hairline,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size.glyph, color: accent),
    );

    if (semanticLabel == null) {
      return ExcludeSemantics(child: tile);
    }
    return Semantics(label: semanticLabel, image: true, child: tile);
  }
}
