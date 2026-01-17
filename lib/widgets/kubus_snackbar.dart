import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'glass_components.dart';

enum KubusSnackBarTone { neutral, success, warning, error }

class KubusSnackBars {
  KubusSnackBars._();

  static Duration normalizeDuration(Duration duration) {
    const min = Duration(seconds: 3);
    const max = Duration(seconds: 4);
    if (duration < min) return min;
    if (duration > max) return max;
    return duration;
  }

  static KubusSnackBarTone toneFromSnackBar(
    BuildContext context,
    SnackBar snackBar,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final bg = snackBar.backgroundColor;
    if (bg == null) return KubusSnackBarTone.neutral;
    if (bg == scheme.error || bg == roles.negativeAction) {
      return KubusSnackBarTone.error;
    }
    if (bg == roles.warningAction) return KubusSnackBarTone.warning;
    if (bg == roles.positiveAction) return KubusSnackBarTone.success;
    return KubusSnackBarTone.neutral;
  }

  static Color accentForTone(BuildContext context, KubusSnackBarTone tone) {
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;
    switch (tone) {
      case KubusSnackBarTone.success:
        return roles.positiveAction;
      case KubusSnackBarTone.warning:
        return roles.warningAction;
      case KubusSnackBarTone.error:
        return roles.negativeAction;
      case KubusSnackBarTone.neutral:
        return scheme.primary;
    }
  }

  static IconData iconForTone(KubusSnackBarTone tone) {
    switch (tone) {
      case KubusSnackBarTone.success:
        return Icons.check_circle_outline;
      case KubusSnackBarTone.warning:
        return Icons.warning_amber_outlined;
      case KubusSnackBarTone.error:
        return Icons.error_outline;
      case KubusSnackBarTone.neutral:
        return Icons.info_outline;
    }
  }

  static SnackBar wrap(
    BuildContext context,
    SnackBar snackBar, {
    KubusSnackBarTone? tone,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final resolvedTone = tone ?? toneFromSnackBar(context, snackBar);
    final accent = accentForTone(context, resolvedTone);
    final icon = iconForTone(resolvedTone);

    final baseSurface = scheme.surface;
    final tint = (Color.lerp(baseSurface, accent, 0.12) ?? baseSurface)
        .withValues(alpha: isDark ? 0.22 : 0.14);

    final originalAction = snackBar.action;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accent, size: KubusSizes.sidebarActionIcon),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(
          child: DefaultTextStyle.merge(
            style:
                KubusTextStyles.actionTileTitle.copyWith(color: scheme.onSurface),
            child: snackBar.content,
          ),
        ),
        if (originalAction != null) ...[
          const SizedBox(width: KubusSpacing.sm),
          TextButton(
            onPressed: originalAction.onPressed,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              textStyle: KubusTextStyles.actionTileTitle,
            ),
            child: Text(originalAction.label),
          ),
        ],
      ],
    );

    return SnackBar(
      content: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.sm + KubusSpacing.xs,
        ),
        margin: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        blurSigma: KubusGlassEffects.blurSigmaLight,
        showBorder: true,
        backgroundColor: tint,
        child: content,
      ),
      action: null,
      duration: normalizeDuration(snackBar.duration),
      behavior: SnackBarBehavior.floating,
      margin: snackBar.margin ??
          const EdgeInsets.all(KubusSpacing.md),
      padding: EdgeInsets.zero,
      elevation: 0,
      backgroundColor: Colors.transparent,
      dismissDirection: snackBar.dismissDirection,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KubusRadius.lg),
      ),
      width: snackBar.width,
      onVisible: snackBar.onVisible,
      clipBehavior: Clip.hardEdge,
    );
  }
}

extension KubusScaffoldMessengerSnackBars on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showKubusSnackBar(
    SnackBar snackBar, {
    KubusSnackBarTone? tone,
    bool clearExisting = true,
  }) {
    if (clearExisting) {
      clearSnackBars();
      hideCurrentSnackBar();
    }
    return showSnackBar(KubusSnackBars.wrap(context, snackBar, tone: tone));
  }
}
