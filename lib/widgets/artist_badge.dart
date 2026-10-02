import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';

/// Small pill badge to mark DAO-approved artists.
class ArtistBadge extends StatelessWidget {
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool useOnPrimary;
  final bool iconOnly;

  const ArtistBadge({
    super.key,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(
      horizontal: KubusSpacing.xs + KubusSpacing.xxs,
      vertical: KubusSpacing.xxs,
    ),
    this.useOnPrimary = false,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = KubusColorRoles.of(context).artistBadgeAccent;
    final textColor =
        useOnPrimary ? colorScheme.onPrimary : colorScheme.onSurface;

    final label = AppLocalizations.of(context)!.badgeArtistLabel;

    // Icon-only mode (dense headers): the glyph is the role's only
    // expression, so it carries the role name for screen readers.
    if (iconOnly) {
      return Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Icon(Icons.brush_rounded, size: fontSize + 4, color: accent),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      // The role word and its colour are the badge; a glyph beside the word
      // would only say the role twice.
      child: Text(
        label.toUpperCase(),
        style: KubusTextStyles.compactBadge.copyWith(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
