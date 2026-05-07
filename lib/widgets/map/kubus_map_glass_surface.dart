import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/glass_capabilities_provider.dart';
import '../../services/webgl_context_helper.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';

enum KubusMapGlassSurfaceKind {
  panel,
  card,
  button,
}

final Set<String> _loggedMapGlassFallbackKeys = <String>{};

enum KubusMapBlurPolicy {
  automatic,
  allowCompactWeb,
  forceMapChromeWhenCapable,
  disabled,
}

@immutable
class KubusMapBlurDecision {
  const KubusMapBlurDecision({
    required this.enabled,
    required this.reason,
    required this.providerAllowsBlur,
    required this.width,
    required this.policy,
    required this.web,
    required this.webGlHealthy,
    required this.reduceEffects,
    required this.reduceEffectsUserTouched,
    required this.heuristicTriggered,
    required this.autoReduceEffectsApplied,
  });

  final bool enabled;
  final String reason;
  final bool providerAllowsBlur;
  final double width;
  final KubusMapBlurPolicy policy;
  final bool web;
  final bool webGlHealthy;
  final bool reduceEffects;
  final bool reduceEffectsUserTouched;
  final bool heuristicTriggered;
  final bool autoReduceEffectsApplied;
}

/// Shared blur policy for map chrome.
KubusMapBlurDecision resolveKubusMapBlurDecision(
  BuildContext context, {
  KubusMapBlurPolicy policy = KubusMapBlurPolicy.automatic,
}) {
  final width = MediaQuery.maybeOf(context)?.size.width ?? 0;
  final allowBlur = GlassCapabilitiesProvider.watchAllowBlurEnabled(context);
  final webGlHealthy = webGLContextHealthy.value;
  GlassCapabilitiesProvider? provider;
  try {
    provider = context.read<GlassCapabilitiesProvider>();
  } catch (_) {}
  final reduceEffects = provider?.reduceEffects ?? false;
  final reduceEffectsUserTouched = provider?.reduceEffectsUserTouched ?? false;
  final heuristicTriggered = provider?.heuristicTriggered ?? false;
  final autoReduceEffectsApplied = provider?.autoReduceEffectsApplied ?? false;
  if (policy == KubusMapBlurPolicy.disabled) {
    return KubusMapBlurDecision(
      enabled: false,
      reason: 'policy-disabled',
      providerAllowsBlur: allowBlur,
      width: width,
      policy: policy,
      web: kIsWeb,
      webGlHealthy: webGlHealthy,
      reduceEffects: reduceEffects,
      reduceEffectsUserTouched: reduceEffectsUserTouched,
      heuristicTriggered: heuristicTriggered,
      autoReduceEffectsApplied: autoReduceEffectsApplied,
    );
  }
  if (!allowBlur) {
    return KubusMapBlurDecision(
      enabled: false,
      reason: 'glass-provider-fallback',
      providerAllowsBlur: allowBlur,
      width: width,
      policy: policy,
      web: kIsWeb,
      webGlHealthy: webGlHealthy,
      reduceEffects: reduceEffects,
      reduceEffectsUserTouched: reduceEffectsUserTouched,
      heuristicTriggered: heuristicTriggered,
      autoReduceEffectsApplied: autoReduceEffectsApplied,
    );
  }

  return KubusMapBlurDecision(
    enabled: true,
    reason: kIsWeb ? 'web-css-platform-shim' : 'flutter-backdrop-filter',
    providerAllowsBlur: allowBlur,
    width: width,
    policy: policy,
    web: kIsWeb,
    webGlHealthy: webGlHealthy,
    reduceEffects: reduceEffects,
    reduceEffectsUserTouched: reduceEffectsUserTouched,
    heuristicTriggered: heuristicTriggered,
    autoReduceEffectsApplied: autoReduceEffectsApplied,
  );
}

bool kubusMapBlurEnabled(
  BuildContext context, {
  KubusMapBlurPolicy policy = KubusMapBlurPolicy.automatic,
}) {
  return resolveKubusMapBlurDecision(context, policy: policy).enabled;
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
    required this.blurReason,
  });

  final KubusGlassStyle style;
  final BorderRadius borderRadius;
  final Color borderColor;
  final Color shadowColor;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final bool useBlur;
  final String blurReason;
}

KubusMapGlassSurfacePreset resolveKubusMapGlassSurfacePreset(
  BuildContext context, {
  required KubusMapGlassSurfaceKind kind,
  Color? tintBase,
  bool useBlur = true,
  KubusMapBlurPolicy blurPolicy = KubusMapBlurPolicy.automatic,
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

  final blurDecision = resolveKubusMapBlurDecision(context, policy: blurPolicy);
  final resolvedBlur = useBlur && blurDecision.enabled;
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
    blurReason: useBlur
        ? '${blurDecision.reason}; providerAllows=${blurDecision.providerAllowsBlur}; '
            'reduce=${blurDecision.reduceEffects}; touched=${blurDecision.reduceEffectsUserTouched}; '
            'webGlHealthy=${blurDecision.webGlHealthy}; heuristic=${blurDecision.heuristicTriggered}; '
            'autoReduce=${blurDecision.autoReduceEffectsApplied}; width=${blurDecision.width.toStringAsFixed(0)}; '
            'policy=${blurDecision.policy}'
        : 'caller-disabled',
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
  KubusMapBlurPolicy blurPolicy = KubusMapBlurPolicy.allowCompactWeb,
}) {
  final preset = resolveKubusMapGlassSurfacePreset(
    context,
    kind: kind,
    tintBase: tintBase,
    useBlur: useBlur,
    blurPolicy: blurPolicy,
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

  if (kDebugMode && !preset.useBlur) {
    final key = '$kind:${preset.blurReason}';
    if (_loggedMapGlassFallbackKeys.add(key)) {
      debugPrint(
        'KubusMapGlassSurface: fallback kind=$kind reason=${preset.blurReason}',
      );
    }
  }

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
