import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/glass_capabilities_provider.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';

enum KubusMapGlassSurfaceKind {
  panel,
  card,
  button,
}

@immutable
class KubusMapGlassSurfacePreset {
  const KubusMapGlassSurfacePreset({
    required this.style,
    required this.borderRadius,
    required this.borderColor,
    required this.shadowColor,
    required this.shadowBlurRadius,
    required this.shadowOffset,
    required this.useBlur,
  });

  final KubusGlassStyle style;
  final BorderRadius borderRadius;
  final Color borderColor;
  final Color shadowColor;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final bool useBlur;
}

KubusMapGlassSurfacePreset resolveKubusMapGlassSurfacePreset(
  BuildContext context, {
  required KubusMapGlassSurfaceKind kind,
  Color? tintBase,
  bool useBlur = true,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  final surfaceType = switch (kind) {
    KubusMapGlassSurfaceKind.panel => KubusGlassSurfaceType.panelBackground,
    KubusMapGlassSurfaceKind.card => KubusGlassSurfaceType.card,
    KubusMapGlassSurfaceKind.button => KubusGlassSurfaceType.button,
  };

  final style = KubusGlassStyle.resolve(
    context,
    surfaceType: surfaceType,
    tintBase: tintBase,
  );

  final resolvedBlur = useBlur ? _resolveBlurEnabled(context) : false;
  final borderColor = scheme.outlineVariant.withValues(
    alpha: switch (kind) {
      KubusMapGlassSurfaceKind.panel => isDark ? 0.30 : 0.24,
      KubusMapGlassSurfaceKind.card => isDark ? 0.26 : 0.20,
      KubusMapGlassSurfaceKind.button => isDark ? 0.24 : 0.18,
    },
  );

  final shadowColor = scheme.shadow.withValues(
    alpha: switch (kind) {
      KubusMapGlassSurfaceKind.panel => isDark ? 0.16 : 0.10,
      KubusMapGlassSurfaceKind.card => isDark ? 0.12 : 0.08,
      KubusMapGlassSurfaceKind.button => isDark ? 0.10 : 0.06,
    },
  );

  return KubusMapGlassSurfacePreset(
    style: style,
    borderRadius: switch (kind) {
      KubusMapGlassSurfaceKind.panel => BorderRadius.circular(KubusRadius.lg),
      KubusMapGlassSurfaceKind.card => BorderRadius.circular(KubusRadius.md),
      KubusMapGlassSurfaceKind.button => BorderRadius.circular(KubusRadius.md),
    },
    borderColor: borderColor,
    shadowColor: shadowColor,
    shadowBlurRadius: switch (kind) {
      KubusMapGlassSurfaceKind.panel => 18,
      KubusMapGlassSurfaceKind.card => 12,
      KubusMapGlassSurfaceKind.button => 10,
    },
    shadowOffset: switch (kind) {
      KubusMapGlassSurfaceKind.panel => const Offset(0, 4),
      KubusMapGlassSurfaceKind.card => const Offset(0, 3),
      KubusMapGlassSurfaceKind.button => const Offset(0, 2),
    },
    useBlur: resolvedBlur,
  );
}

Widget buildKubusMapGlassSurface({
  required BuildContext context,
  required KubusMapGlassSurfaceKind kind,
  required Widget child,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  EdgeInsetsGeometry margin = EdgeInsets.zero,
  BorderRadius? borderRadius,
  Color? tintBase,
  bool useBlur = true,
  bool showBorder = true,
  BoxBorder? border,
  List<BoxShadow>? boxShadow,
  VoidCallback? onTap,
}) {
  final preset = resolveKubusMapGlassSurfacePreset(
    context,
    kind: kind,
    tintBase: tintBase,
    useBlur: useBlur,
  );
  final effectiveRadius = borderRadius ?? preset.borderRadius;
  final effectivePadding = padding;
  final effectiveBorder = border ??
      (showBorder
          ? Border.all(
              color: preset.borderColor,
              width: KubusSizes.hairline,
            )
          : null);

  Widget surface;
  if (preset.useBlur) {
    surface = GlassSurface(
      borderRadius: effectiveRadius,
      blurSigma: preset.style.blurSigma,
      tintColor: preset.style.tintColor,
      fallbackMinOpacity: preset.style.fallbackMinOpacity,
      showBorder: showBorder,
      border: effectiveBorder,
      child: Padding(
        padding: effectivePadding,
        child: child,
      ),
    );
  } else {
    final tint = preset.style.tintColor.withValues(
      alpha: preset.style.tintColor.a < preset.style.fallbackMinOpacity
          ? preset.style.fallbackMinOpacity
          : preset.style.tintColor.a,
    );
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        colors: [
          tint,
          tint.withValues(alpha: tint.a * 0.86),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: effectiveRadius,
      border: effectiveBorder,
      boxShadow: boxShadow ??
          [
            BoxShadow(
              color: preset.shadowColor,
              blurRadius: preset.shadowBlurRadius,
              offset: preset.shadowOffset,
            ),
          ],
    );

    surface = DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }

  if (preset.useBlur && boxShadow != null && boxShadow.isNotEmpty) {
    surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: boxShadow,
      ),
      child: surface,
    );
  }

  surface = Container(
    margin: margin,
    child: surface,
  );

  if (onTap != null) {
    surface = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        child: surface,
      ),
    );
  }

  return surface;
}

bool _resolveBlurEnabled(BuildContext context) {
  try {
    return context.watch<GlassCapabilitiesProvider>().allowBlur;
  } catch (_) {
    return true;
  }
}
