import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../providers/glass_capabilities_provider.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';

enum KubusMapGlassSurfaceKind {
  panel,
  card,
  button,
}

/// Shared blur policy for map chrome.
///
/// Mobile web still uses the opaque fallback because backdrop blur over the
/// embedded web map is less reliable there. Desktop-class web and native
/// platforms can use real blur when the global glass policy allows it.
bool kubusMapBlurEnabled(BuildContext context) {
  final allowBlur = GlassCapabilitiesProvider.watchAllowBlurEnabled(context);
  if (!allowBlur) return false;
  if (!kIsWeb) return true;

  final width = MediaQuery.maybeOf(context)?.size.width ?? 0;
  return width >= 900;
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

  final resolvedBlur = useBlur && kubusMapBlurEnabled(context);
  final borderColor = scheme.outlineVariant.withValues(
    alpha: switch (kind) {
      KubusMapGlassSurfaceKind.panel =>
        KubusGlassEffects.glassBorderOpacityStrong,
      KubusMapGlassSurfaceKind.card =>
        KubusGlassEffects.glassBorderOpacityMedium,
      KubusMapGlassSurfaceKind.button =>
        KubusGlassEffects.glassBorderOpacitySubtle,
    },
  );

  final shadowColor = scheme.shadow.withValues(
    alpha: switch (kind) {
      KubusMapGlassSurfaceKind.panel => isDark
          ? KubusGlassEffects.shadowOpacityDark
          : KubusGlassEffects.shadowOpacityLight,
      KubusMapGlassSurfaceKind.card => isDark
          ? KubusGlassEffects.shadowOpacityDark * 0.8
          : KubusGlassEffects.shadowOpacityLight * 0.8,
      KubusMapGlassSurfaceKind.button => isDark
          ? KubusGlassEffects.shadowOpacityDark * 0.7
          : KubusGlassEffects.shadowOpacityLight * 0.7,
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

  Widget surface = GlassSurface(
    borderRadius: effectiveRadius,
    blurSigma: preset.style.blurSigma,
    tintColor: preset.style.tintColor,
    fallbackMinOpacity: preset.style.fallbackMinOpacity,
    showBorder: showBorder,
    border: effectiveBorder,
    enableBlur: preset.useBlur,
    child: Padding(
      padding: effectivePadding,
      child: child,
    ),
  );

  final effectiveShadow = boxShadow ??
      (preset.useBlur
          ? const <BoxShadow>[]
          : <BoxShadow>[
              BoxShadow(
                color: preset.shadowColor,
                blurRadius: preset.shadowBlurRadius,
                offset: preset.shadowOffset,
              ),
            ]);

  if (effectiveShadow.isNotEmpty) {
    surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: effectiveShadow,
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
