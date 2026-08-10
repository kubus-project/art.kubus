import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_brand_colors.dart';
import '../../utils/kubus_color_roles.dart';

/// Which mark is drawn inside a [KubusTokenAvatar].
enum KubusTokenGlyph {
  /// The kubus cube — the house token (KUB8).
  kubusCube,

  /// The Solana three-bar mark.
  solana,

  /// Up to two letters from the symbol.
  initials,
}

/// Avatar sizes for token marks. Kept as an enum so rows, chips, and heroes
/// can only pick from the tokenized set.
enum KubusTokenAvatarSize { xs, sm, md, lg }

extension on KubusTokenAvatarSize {
  double get box {
    switch (this) {
      case KubusTokenAvatarSize.xs:
        return KubusSizes.tokenAvatarXs;
      case KubusTokenAvatarSize.sm:
        return KubusSizes.tokenAvatarSm;
      case KubusTokenAvatarSize.md:
        return KubusSizes.tokenAvatarMd;
      case KubusTokenAvatarSize.lg:
        return KubusSizes.tokenAvatarLg;
    }
  }

  double get radius {
    switch (this) {
      case KubusTokenAvatarSize.xs:
        return KubusRadius.xs;
      case KubusTokenAvatarSize.sm:
        return KubusRadius.sm;
      case KubusTokenAvatarSize.md:
      case KubusTokenAvatarSize.lg:
        return KubusRadius.md;
    }
  }
}

/// The resolved visual identity of a wallet asset.
@immutable
class KubusTokenVisual {
  const KubusTokenVisual({
    required this.symbol,
    required this.accent,
    required this.secondaryAccent,
    required this.glyph,
  });

  /// Uppercased ticker (`KUB8`, `SOL`, …).
  final String symbol;

  /// Primary identity color — use for text, amounts, and borders.
  final Color accent;

  /// Second gradient stop for the avatar fill.
  final Color secondaryAccent;

  final KubusTokenGlyph glyph;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[accent, secondaryAccent],
      );

  /// Two-letter fallback shown when no mark exists for the symbol.
  String get initials {
    if (symbol.isEmpty) return '?';
    final compact = symbol.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.isEmpty) return symbol.substring(0, 1);
    return compact.length == 1 ? compact : compact.substring(0, 2);
  }
}

/// Single source of truth for how a wallet asset looks.
///
/// KUB8 and SOL carry real marks and fixed brand colors — a token is an
/// identity, so it must not shift with the theme. Everything else gets a
/// stable, symbol-derived accent from the role palette so unknown SPL assets
/// still read as distinct rows rather than identical grey tiles.
class KubusTokenIdentity {
  const KubusTokenIdentity._();

  static const String kub8Symbol = 'KUB8';
  static const String solSymbol = 'SOL';

  static KubusTokenVisual resolve(BuildContext context, String symbol) {
    final normalized = symbol.trim().toUpperCase();
    switch (normalized) {
      case kub8Symbol:
        return const KubusTokenVisual(
          symbol: kub8Symbol,
          accent: KubusColors.primaryVariantDark,
          secondaryAccent: KubusColors.accentTealDark,
          glyph: KubusTokenGlyph.kubusCube,
        );
      case solSymbol:
        return const KubusTokenVisual(
          symbol: solSymbol,
          accent: KubusBrandColors.solanaPurple,
          secondaryAccent: KubusBrandColors.solanaGreen,
          glyph: KubusTokenGlyph.solana,
        );
    }

    final roles = KubusColorRoles.of(context);
    final palette = <Color>[
      roles.statBlue,
      roles.statAmber,
      roles.statPurple,
      roles.statTeal,
      roles.positiveAction,
    ];
    final accent = palette[_stableIndex(normalized, palette.length)];
    return KubusTokenVisual(
      symbol: normalized,
      accent: accent,
      secondaryAccent: accent.withValues(alpha: 0.62),
      glyph: KubusTokenGlyph.initials,
    );
  }

  static int _stableIndex(String value, int length) {
    if (value.isEmpty) return 0;
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % length;
  }
}

/// The canonical asset mark: a rounded tile carrying the token's glyph.
///
/// [filled] paints the full identity gradient (for heroes and on-accent
/// surfaces); the default is a tinted tile that sits calmly in list rows.
class KubusTokenAvatar extends StatelessWidget {
  const KubusTokenAvatar({
    super.key,
    required this.symbol,
    this.size = KubusTokenAvatarSize.md,
    this.filled = false,
    this.ringColor,
  });

  final String symbol;
  final KubusTokenAvatarSize size;
  final bool filled;

  /// Separates the mark from whatever sits behind it — used when the avatar
  /// overlaps another icon as a corner badge.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final visual = KubusTokenIdentity.resolve(context, symbol);
    final box = size.box;
    final glyphSize = box * KubusSizes.tokenGlyphRatio;
    final glyphColor = filled ? KubusColors.textPrimaryDark : visual.accent;

    final Border? border = ringColor != null
        ? Border.all(color: ringColor!, width: KubusSizes.hairline)
        : (filled ? null : KubusBorders.accentTint(visual.accent));

    return Semantics(
      label: visual.symbol,
      child: Container(
        width: box,
        height: box,
        decoration: BoxDecoration(
          gradient: filled ? visual.gradient : null,
          color: filled ? null : visual.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(size.radius),
          border: border,
        ),
        child: Center(
          child: _TokenGlyph(
            visual: visual,
            size: glyphSize,
            color: glyphColor,
          ),
        ),
      ),
    );
  }
}

class _TokenGlyph extends StatelessWidget {
  const _TokenGlyph({
    required this.visual,
    required this.size,
    required this.color,
  });

  final KubusTokenVisual visual;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (visual.glyph) {
      case KubusTokenGlyph.kubusCube:
        return CustomPaint(
          size: Size.square(size),
          painter: _KubusCubePainter(color: color),
        );
      case KubusTokenGlyph.solana:
        return CustomPaint(
          size: Size.square(size),
          painter: _SolanaMarkPainter(color: color),
        );
      case KubusTokenGlyph.initials:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xxs),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              visual.initials,
              style: KubusTypography.inter(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ),
        );
    }
  }
}

/// The kubus mark: an isometric cube drawn as three faces.
class _KubusCubePainter extends CustomPainter {
  const _KubusCubePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Isometric cube corners on a unit box, inset so the stroke stays inside.
    final top = Offset(w * 0.5, h * 0.08);
    final right = Offset(w * 0.94, h * 0.30);
    final bottomRight = Offset(w * 0.94, h * 0.72);
    final bottom = Offset(w * 0.5, h * 0.94);
    final bottomLeft = Offset(w * 0.06, h * 0.72);
    final left = Offset(w * 0.06, h * 0.30);
    final center = Offset(w * 0.5, h * 0.51);

    final outline = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    // Top face reads as the lit plane; the two side faces stay as edges.
    final topFace = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(center.dx, center.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    canvas.drawPath(topFace, Paint()..color = color.withValues(alpha: 0.9));

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(outline, stroke);
    canvas.drawLine(center, bottom, stroke);
  }

  @override
  bool shouldRepaint(_KubusCubePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The Solana mark: three slanted bars.
class _SolanaMarkPainter extends CustomPainter {
  const _SolanaMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final barHeight = h * 0.19;
    final skew = w * 0.18;
    final paint = Paint()..color = color;

    // Top and bottom bars lean right, the middle bar leans left.
    void bar(double top, bool leansRight) {
      final path = Path();
      if (leansRight) {
        path
          ..moveTo(skew, top)
          ..lineTo(w, top)
          ..lineTo(w - skew, top + barHeight)
          ..lineTo(0, top + barHeight);
      } else {
        path
          ..moveTo(0, top)
          ..lineTo(w - skew, top)
          ..lineTo(w, top + barHeight)
          ..lineTo(skew, top + barHeight);
      }
      canvas.drawPath(path..close(), paint);
    }

    bar(h * 0.10, true);
    bar(h * 0.405, false);
    bar(h * 0.71, true);
  }

  @override
  bool shouldRepaint(_SolanaMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Compact `mark + symbol` badge for meta rows and hero chips.
///
/// [value] renders as the emphasized line under the symbol when provided,
/// which is how balance heroes show a per-asset amount.
class KubusTokenBadge extends StatelessWidget {
  const KubusTokenBadge({
    super.key,
    required this.symbol,
    this.value,
    this.label,
    this.onDark = false,
  });

  final String symbol;
  final String? value;
  final String? label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = KubusTokenIdentity.resolve(context, symbol);
    final onSurface =
        onDark ? KubusColors.textPrimaryDark : scheme.onSurface;

    return Container(
      constraints: const BoxConstraints(minHeight: KubusSizes.chipMinHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm,
        vertical: KubusSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: visual.accent.withValues(alpha: onDark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: KubusBorders.accentTint(visual.accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KubusTokenAvatar(
            symbol: symbol,
            size: KubusTokenAvatarSize.sm,
            filled: true,
          ),
          const SizedBox(width: KubusSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label ?? visual.symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KubusTextStyles.navMetaLabel.copyWith(
                  color: onSurface.withValues(alpha: 0.70),
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.navLabel.copyWith(
                    color: onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
