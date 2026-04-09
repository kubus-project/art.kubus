import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

/// Design system spacing constants for detail screens.
class DetailSpacing {
  const DetailSpacing._();

  static const double xs = KubusSpacing.xs;
  static const double sm = KubusSpacing.sm;
  static const double md = KubusSpacing.sm + KubusSpacing.xs;
  static const double lg = KubusSpacing.md;
  static const double xl = KubusSpacing.lg;
  static const double xxl = KubusSpacing.xl;

  static const EdgeInsets contentPaddingMobile = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: lg,
  );

  static const EdgeInsets contentPaddingDesktop = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: xl,
  );

  static const double sectionGap = xl;
}

/// Design system typography styles for detail surfaces.
class DetailTypography {
  const DetailTypography._();

  static TextStyle screenTitle(BuildContext context) =>
      KubusTextStyles.screenTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle sectionTitle(BuildContext context) =>
      KubusTextStyles.sectionTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle cardTitle(BuildContext context) =>
      KubusTextStyles.detailCardTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle body(BuildContext context) =>
      KubusTextStyles.detailBody.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
      );

  static TextStyle caption(BuildContext context) =>
      KubusTextStyles.sectionSubtitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      );

  static TextStyle label(BuildContext context) =>
      KubusTextStyles.detailLabel.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      );

  static TextStyle button(BuildContext context) => KubusTextStyles.detailButton;
}

/// Standard border radius values used by detail surfaces.
class DetailRadius {
  const DetailRadius._();

  static const double xs = KubusRadius.xs + KubusSpacing.xxs;
  static const double sm = KubusRadius.sm;
  static const double md = KubusRadius.md;
  static const double lg = KubusRadius.lg;
  static const double xl = KubusRadius.lg + KubusSpacing.xs;
}
