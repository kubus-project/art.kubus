import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../providers/glass_capabilities_provider.dart';
import '../../services/webgl_context_helper.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';
import 'glass/kubus_map_platform_backdrop_host.dart';

enum KubusMapGlassSurfaceKind {
  panel,
  card,
  button,
}

final Set<String> _loggedMapGlassFallbackKeys = <String>{};
final Set<String> _loggedMapGlassRegionKeys = <String>{};
int _mapGlassRegionIdSequence = 0;

enum KubusMapBlurPolicy {
  automatic,
  allowCompactWeb,
  forceMapChromeWhenCapable,
  disabled,
}

enum KubusMapBackdropStrategy {
  flutterBackdropFilter,
  platformViewSafeTintFallback,
  platformViewBackdropHost,
}

/// Whether the current target renders the map as a native platform view that
/// Flutter's [BackdropFilter] cannot sample (Android/iOS MapLibre).
///
/// Desktop (windows/macOS/linux) keeps real blur because its map chrome
/// composites with Flutter; web is handled separately via its own DOM-backed
/// backdrop host and safe-tint paths.
bool isMobileNativeMapPlatform({bool web = kIsWeb}) {
  if (web) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return false;
  }
}

@immutable
class KubusMapBlurDecision {
  const KubusMapBlurDecision({
    required this.enabled,
    required this.reason,
    required this.strategy,
    required this.providerAllowsBlur,
    required this.width,
    required this.policy,
    required this.web,
    required this.overMapPlatformView,
    required this.platformBackdropHostAvailable,
    required this.webGlHealthy,
    required this.reduceEffects,
    required this.reduceEffectsUserTouched,
    required this.heuristicTriggered,
    required this.autoReduceEffectsApplied,
  });

  final bool enabled;
  final String reason;
  final KubusMapBackdropStrategy strategy;
  final bool providerAllowsBlur;
  final double width;
  final KubusMapBlurPolicy policy;
  final bool web;
  final bool overMapPlatformView;
  final bool platformBackdropHostAvailable;
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
  bool overMapPlatformView = true,
  bool? isWebOverride,
  bool? webGlHealthyOverride,
  bool? platformBackdropHostAvailableOverride,
  bool? mobileNativeOverride,
}) {
  final width = MediaQuery.maybeOf(context)?.size.width ?? 0;
  final allowBlur = GlassCapabilitiesProvider.watchAllowBlurEnabled(context);
  final web = isWebOverride ?? kIsWeb;
  final mobileNative =
      mobileNativeOverride ?? isMobileNativeMapPlatform(web: web);
  final webGlHealthy = webGlHealthyOverride ?? webGLContextHealthy.value;
  final platformBackdropHostAvailable = platformBackdropHostAvailableOverride ??
      (web &&
          AppConfig.isFeatureEnabled('mapCssBlurHost') &&
          KubusMapPlatformBackdropHost.isSupported);
  GlassCapabilitiesProvider? provider;
  try {
    provider = context.read<GlassCapabilitiesProvider>();
  } catch (_) {}
  final reduceEffects = provider?.reduceEffects ?? false;
  final reduceEffectsUserTouched = provider?.reduceEffectsUserTouched ?? false;
  final heuristicTriggered = provider?.heuristicTriggered ?? false;
  final autoReduceEffectsApplied = provider?.autoReduceEffectsApplied ?? false;
  final compactWeb = web && width > 0 && width < 700;
  if (policy == KubusMapBlurPolicy.disabled) {
    return KubusMapBlurDecision(
      enabled: false,
      reason: 'policy-disabled',
      strategy: KubusMapBackdropStrategy.platformViewSafeTintFallback,
      providerAllowsBlur: allowBlur,
      width: width,
      policy: policy,
      web: web,
      overMapPlatformView: overMapPlatformView,
      platformBackdropHostAvailable: platformBackdropHostAvailable,
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
      strategy: KubusMapBackdropStrategy.platformViewSafeTintFallback,
      providerAllowsBlur: allowBlur,
      width: width,
      policy: policy,
      web: web,
      overMapPlatformView: overMapPlatformView,
      platformBackdropHostAvailable: platformBackdropHostAvailable,
      webGlHealthy: webGlHealthy,
      reduceEffects: reduceEffects,
      reduceEffectsUserTouched: reduceEffectsUserTouched,
      heuristicTriggered: heuristicTriggered,
      autoReduceEffectsApplied: autoReduceEffectsApplied,
    );
  }
  if (web && !webGlHealthy) {
    return KubusMapBlurDecision(
      enabled: false,
      reason: 'webgl-unhealthy',
      strategy: KubusMapBackdropStrategy.platformViewSafeTintFallback,
      providerAllowsBlur: allowBlur,
      width: width,
      policy: policy,
      web: web,
      overMapPlatformView: overMapPlatformView,
      platformBackdropHostAvailable: platformBackdropHostAvailable,
      webGlHealthy: webGlHealthy,
      reduceEffects: reduceEffects,
      reduceEffectsUserTouched: reduceEffectsUserTouched,
      heuristicTriggered: heuristicTriggered,
      autoReduceEffectsApplied: autoReduceEffectsApplied,
    );
  }

  final platformHostAllowed = policy ==
          KubusMapBlurPolicy.forceMapChromeWhenCapable ||
      (!compactWeb &&
          (policy == KubusMapBlurPolicy.allowCompactWeb ||
              policy == KubusMapBlurPolicy.automatic));

  if (web &&
      overMapPlatformView &&
      platformBackdropHostAvailable &&
      platformHostAllowed) {
    return KubusMapBlurDecision(
      enabled: true,
      reason: 'platform-view-backdrop-host',
      strategy: KubusMapBackdropStrategy.platformViewBackdropHost,
      providerAllowsBlur: allowBlur,
      width: width,
      policy: policy,
      web: web,
      overMapPlatformView: overMapPlatformView,
      platformBackdropHostAvailable: platformBackdropHostAvailable,
      webGlHealthy: webGlHealthy,
      reduceEffects: reduceEffects,
      reduceEffectsUserTouched: reduceEffectsUserTouched,
      heuristicTriggered: heuristicTriggered,
      autoReduceEffectsApplied: autoReduceEffectsApplied,
    );
  }

  if (web && overMapPlatformView) {
    return KubusMapBlurDecision(
      enabled: false,
      reason: compactWeb
          ? 'compact-web-platform-view-safe-tint-fallback'
          : 'platform-view-safe-tint-fallback',
      strategy: KubusMapBackdropStrategy.platformViewSafeTintFallback,
      providerAllowsBlur: allowBlur,
      width: width,
      policy: policy,
      web: web,
      overMapPlatformView: overMapPlatformView,
      platformBackdropHostAvailable: platformBackdropHostAvailable,
      webGlHealthy: webGlHealthy,
      reduceEffects: reduceEffects,
      reduceEffectsUserTouched: reduceEffectsUserTouched,
      heuristicTriggered: heuristicTriggered,
      autoReduceEffectsApplied: autoReduceEffectsApplied,
    );
  }

  // Mobile native (Android/iOS) renders MapLibre as a native platform view.
  // Flutter's BackdropFilter cannot sample those pixels, so real blur degrades
  // to a flat translucent panel. Force the material safe-tint fallback for any
  // overlay that sits over the live map. This is independent of policy because
  // there is no platform backdrop host on mobile (that path is web-only DOM).
  if (!web && overMapPlatformView && mobileNative) {
    return KubusMapBlurDecision(
      enabled: false,
      reason: 'mobile-platform-view-safe-tint-fallback',
      strategy: KubusMapBackdropStrategy.platformViewSafeTintFallback,
      providerAllowsBlur: allowBlur,
      width: width,
      policy: policy,
      web: web,
      overMapPlatformView: overMapPlatformView,
      platformBackdropHostAvailable: platformBackdropHostAvailable,
      webGlHealthy: webGlHealthy,
      reduceEffects: reduceEffects,
      reduceEffectsUserTouched: reduceEffectsUserTouched,
      heuristicTriggered: heuristicTriggered,
      autoReduceEffectsApplied: autoReduceEffectsApplied,
    );
  }

  return KubusMapBlurDecision(
    enabled: true,
    reason: 'flutter-backdrop-filter',
    strategy: KubusMapBackdropStrategy.flutterBackdropFilter,
    providerAllowsBlur: allowBlur,
    width: width,
    policy: policy,
    web: web,
    overMapPlatformView: overMapPlatformView,
    platformBackdropHostAvailable: platformBackdropHostAvailable,
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
  bool overMapPlatformView = true,
}) {
  final decision = resolveKubusMapBlurDecision(
    context,
    policy: policy,
    overMapPlatformView: overMapPlatformView,
  );
  return decision.enabled &&
      decision.strategy == KubusMapBackdropStrategy.flutterBackdropFilter;
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
    required this.usePlatformBackdropHost,
    required this.blurSigma,
    required this.blurReason,
    required this.backdropStrategy,
  });

  final KubusGlassStyle style;
  final BorderRadius borderRadius;
  final Color borderColor;
  final Color shadowColor;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final bool useBlur;
  final bool usePlatformBackdropHost;
  final double blurSigma;
  final String blurReason;
  final KubusMapBackdropStrategy backdropStrategy;
}

KubusMapGlassSurfacePreset resolveKubusMapGlassSurfacePreset(
  BuildContext context, {
  required KubusMapGlassSurfaceKind kind,
  Color? tintBase,
  bool useBlur = true,
  KubusMapBlurPolicy blurPolicy = KubusMapBlurPolicy.automatic,
  bool overMapPlatformView = true,
  bool? isWebOverride,
  bool? platformBackdropHostAvailableOverride,
  bool? mobileNativeOverride,
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

  final blurDecision = resolveKubusMapBlurDecision(
    context,
    policy: blurPolicy,
    overMapPlatformView: overMapPlatformView,
    isWebOverride: isWebOverride,
    platformBackdropHostAvailableOverride:
        platformBackdropHostAvailableOverride,
    mobileNativeOverride: mobileNativeOverride,
  );
  final resolvedBlur = useBlur &&
      blurDecision.enabled &&
      (blurDecision.strategy ==
              KubusMapBackdropStrategy.flutterBackdropFilter ||
          blurDecision.strategy ==
              KubusMapBackdropStrategy.platformViewBackdropHost);
  final resolvedPlatformBackdrop = useBlur &&
      blurDecision.enabled &&
      blurDecision.strategy ==
          KubusMapBackdropStrategy.platformViewBackdropHost;
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
    usePlatformBackdropHost: resolvedPlatformBackdrop,
    blurSigma: style.blurSigma,
    blurReason: useBlur
        ? '${blurDecision.reason}; providerAllows=${blurDecision.providerAllowsBlur}; '
            'reduce=${blurDecision.reduceEffects}; touched=${blurDecision.reduceEffectsUserTouched}; '
            'webGlHealthy=${blurDecision.webGlHealthy}; heuristic=${blurDecision.heuristicTriggered}; '
            'autoReduce=${blurDecision.autoReduceEffectsApplied}; width=${blurDecision.width.toStringAsFixed(0)}; '
            'policy=${blurDecision.policy}; strategy=${blurDecision.strategy}; '
            'web=${blurDecision.web}; overMapPlatformView=${blurDecision.overMapPlatformView}; '
            'platformBackdropHostAvailable=${blurDecision.platformBackdropHostAvailable}'
        : 'caller-disabled',
    backdropStrategy: blurDecision.strategy,
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
  bool overMapPlatformView = true,
  String? backdropRegionId,
  bool enablePlatformBackdropRegion = true,
  bool? isWebOverride,
  bool? platformBackdropHostAvailableOverride,
  bool? mobileNativeOverride,
}) {
  final preset = resolveKubusMapGlassSurfacePreset(
    context,
    kind: kind,
    tintBase: tintBase,
    useBlur: useBlur,
    blurPolicy: blurPolicy,
    overMapPlatformView: overMapPlatformView,
    isWebOverride: isWebOverride,
    platformBackdropHostAvailableOverride:
        platformBackdropHostAvailableOverride,
    mobileNativeOverride: mobileNativeOverride,
  );
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
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

  // When real backdrop blur is unavailable (notably mobile native overlays
  // sitting over the MapLibre platform view), enrich the flat tinted fallback
  // with a cheap, static "liquid glass" treatment: a diagonal sheen, a soft
  // bottom-right falloff, and an inner highlight stroke. This is a single
  // IgnorePointer decoration with no animation, so it stays jank-free while the
  // map pans/zooms and reads as intentional glass rather than a flat panel.
  if (!preset.useBlur) {
    surface = Stack(
      children: <Widget>[
        surface,
        Positioned.fill(
          child: IgnorePointer(
            child: KubusMapGlassMaterialSheen(
              borderRadius: effectiveRadius,
              isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }

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

  if (preset.usePlatformBackdropHost && enablePlatformBackdropRegion) {
    if (kDebugMode) {
      final key = '$kind:${backdropRegionId ?? '<generated>'}';
      if (_loggedMapGlassRegionKeys.add(key)) {
        debugPrint(
          'KubusMapGlassSurface: platformBackdropRegion kind=$kind '
          'id=${backdropRegionId ?? '<generated>'} '
          'policy=$blurPolicy strategy=${preset.backdropStrategy}',
        );
      }
    }
    surface = _KubusMapGlassBackdropTrackedSurface(
      regionId: backdropRegionId,
      borderRadius: effectiveRadius,
      blurSigma: preset.blurSigma,
      child: surface,
    );
  }

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

/// Static "liquid glass" sheen drawn over the opaque tint fallback used when
/// real backdrop blur is unavailable (e.g. mobile overlays over the MapLibre
/// platform view).
///
/// Layers, from cheapest to richest:
/// - a diagonal gradient: bright top-left highlight, neutral middle (where most
///   text sits), and a faint bottom-right falloff for depth;
/// - a thin inner highlight stroke that reads as a glass rim.
///
/// All alphas are intentionally subtle and theme-aware so text/icons stay
/// readable (no black-on-black in dark, no washed-out white in light), and the
/// whole thing is wrapped in [IgnorePointer] by the caller so tap targets are
/// unaffected.
class KubusMapGlassMaterialSheen extends StatelessWidget {
  const KubusMapGlassMaterialSheen({
    super.key,
    required this.borderRadius,
    required this.isDark,
  });

  final BorderRadius borderRadius;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final highlight = Colors.white.withValues(alpha: isDark ? 0.07 : 0.30);
    final falloff = Colors.black.withValues(alpha: isDark ? 0.12 : 0.05);
    final rim = Colors.white.withValues(alpha: isDark ? 0.10 : 0.45);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            highlight,
            Colors.transparent,
            falloff,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ),
        border: Border.all(
          color: rim,
          width: KubusSizes.hairline,
        ),
      ),
    );
  }
}

class _KubusMapGlassBackdropTrackedSurface extends StatefulWidget {
  const _KubusMapGlassBackdropTrackedSurface({
    required this.regionId,
    required this.borderRadius,
    required this.blurSigma,
    required this.child,
  });

  final String? regionId;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Widget child;

  @override
  State<_KubusMapGlassBackdropTrackedSurface> createState() =>
      _KubusMapGlassBackdropTrackedSurfaceState();
}

class _KubusMapGlassBackdropTrackedSurfaceState
    extends State<_KubusMapGlassBackdropTrackedSurface> {
  late final String _generatedRegionId =
      'kubus-map-glass-${++_mapGlassRegionIdSequence}';

  @override
  Widget build(BuildContext context) {
    return KubusMapBackdropRegionTracker(
      id: widget.regionId ?? _generatedRegionId,
      enabled: true,
      borderRadius: widget.borderRadius,
      blurSigma: widget.blurSigma,
      child: widget.child,
    );
  }
}
