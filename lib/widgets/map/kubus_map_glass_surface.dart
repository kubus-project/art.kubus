import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../providers/glass_capabilities_provider.dart';
import '../../services/webgl_context_helper.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';
import 'glass/kubus_map_native_backdrop_channel.dart';
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

  /// Strict policy for overlays that REQUIRE real blur of the live map.
  ///
  /// Unlike [forceMapChromeWhenCapable] (which only widens the web platform
  /// host), this also drives the mobile real-blur path: Android resolves to a
  /// real [BackdropFilter] over the Virtual-Display map texture, iOS resolves to
  /// the native backdrop host when available. If neither real-blur strategy is
  /// available the decision is still a fallback, but it is flagged via
  /// [KubusMapBlurDecision.realBlurUnavailable] so callers can log it loudly
  /// instead of silently shipping a flat tint.
  forceRealBlur,
  disabled,
}

enum KubusMapBackdropStrategy {
  /// Flutter [BackdropFilter] samples the scene below it (real GPU blur). Works
  /// on desktop, web (non-platform-view), and Android where the map is a
  /// Virtual-Display texture that Flutter composites.
  flutterBackdropFilter,

  /// Flat tinted material fallback (no real blur). Enriched with a static sheen
  /// by [buildKubusMapGlassSurface] so it still reads as glass.
  platformViewSafeTintFallback,

  /// Web DOM/CSS backdrop host renders the blur behind a registered region.
  platformViewBackdropHost,

  /// Native (iOS) backdrop host renders a real blur view beneath a registered
  /// region, above the MapLibre platform view and behind Flutter overlay
  /// content. Region lifecycle is shared with [platformViewBackdropHost] via
  /// [KubusMapBackdropRegionTracker]/[KubusMapBackdropHostController].
  nativeBackdropHost,
}

/// Whether the current target renders the map as a native platform view
/// (Android/iOS MapLibre) rather than a Flutter-composited surface (desktop) or
/// a web DOM canvas.
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

/// Whether Flutter's [BackdropFilter] can actually sample the live map's pixels
/// on this mobile platform.
///
/// **Android:** `maplibre_gl` runs in Virtual-Display mode (the plugin default,
/// `MapLibreMap.useHybridComposition == false`), so the map is composited into a
/// Flutter texture that [BackdropFilter] *can* sample — real blur works. This is
/// the path that was wrongly disabled by the `mobile-platform-view-safe-tint-
/// fallback` regression, which assumed Hybrid Composition.
///
/// **iOS:** `maplibre_gl` renders a `UiKitView` (a true platform view) whose
/// pixels are not in the Flutter raster, so [BackdropFilter] cannot sample it —
/// iOS needs the [KubusMapBackdropStrategy.nativeBackdropHost] instead.
bool mobileMapBackdropFilterCanSample({bool web = kIsWeb}) {
  if (web) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return true;
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return false;
  }
}

/// Capability gate for the native (iOS) map backdrop blur host.
///
/// Backed by a runtime handshake with the platform side
/// ([KubusMapNativeBackdropChannel]): support starts `false`, the first query
/// fires a one-shot probe, and any channel failure demotes back to the
/// enriched tint sheen. This keeps the gate honest — a build without the
/// native handler behaves exactly like the pre-host fallback.
class KubusMapNativeBackdropHost {
  const KubusMapNativeBackdropHost._();

  /// Whether a native backdrop host responded to the capability probe.
  static bool get isSupported {
    if (kIsWeb) return false;
    return KubusMapNativeBackdropChannel.isSupported;
  }
}

/// Whether a native mobile backdrop blur host is usable in the current build.
///
/// Android does not use a native host (a sibling in-app view cannot capture the
/// map's GPU surface; Android uses [BackdropFilter] over the Virtual-Display
/// texture instead). iOS uses it when the feature flag is on, the platform host
/// is supported, and it is not running on web.
bool mobileNativeBlurHostAvailable({bool web = kIsWeb}) {
  if (web) return false;
  if (defaultTargetPlatform != TargetPlatform.iOS) return false;
  return AppConfig.isFeatureEnabled('mapNativeBlurHost') &&
      KubusMapNativeBackdropHost.isSupported;
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
    this.requireRealBlur = false,
    this.realBlurUnavailable = false,
  });

  final bool enabled;
  final String reason;
  final KubusMapBackdropStrategy strategy;

  /// Whether the caller demanded real blur ([KubusMapBlurPolicy.forceRealBlur]).
  final bool requireRealBlur;

  /// Whether real blur was required but no real-blur strategy was available on
  /// this platform (so the decision degraded to a tint fallback). Callers should
  /// surface this loudly in debug builds.
  final bool realBlurUnavailable;
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
  bool? mobileBackdropSampleableOverride,
  bool? nativeBlurHostAvailableOverride,
}) {
  final width = MediaQuery.maybeOf(context)?.size.width ?? 0;
  final allowBlur = GlassCapabilitiesProvider.watchAllowBlurEnabled(context);
  final web = isWebOverride ?? kIsWeb;
  final mobileNative =
      mobileNativeOverride ?? isMobileNativeMapPlatform(web: web);
  final mobileBackdropSampleable = mobileBackdropSampleableOverride ??
      mobileMapBackdropFilterCanSample(web: web);
  final nativeBlurHost =
      nativeBlurHostAvailableOverride ?? mobileNativeBlurHostAvailable(web: web);
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
  // Resolve the web DOM/CSS backdrop host up-front. It is browser-native and
  // cheap, so it should engage for over-map chrome even when the expensive Skia
  // [BackdropFilter] would be gated by the auto perf-heuristic or a transient
  // WebGL-health blip. Only an explicit user "reduce effects" opt-in (or the
  // `disabled` policy handled above) turns it off — this is what makes web map
  // blur behave like desktop instead of silently degrading to a flat tint.
  final reduceEffectsUser = provider?.reduceEffectsUserOverride ?? false;
  // The web CSS-blur host inserts `backdrop-filter` DOM elements over the map
  // platform view. It is available at every width: the historical compact-web
  // exclusion ("blur in front of content" over the search dropdown) was caused
  // by the host div's `z-index: 1` escaping into the page stacking context and
  // painting above Flutter's overlay canvas; the host now isolates itself at
  // `z-index: 0` (see kubus_map_platform_backdrop_dom_web.dart), so it always
  // composites above the map canvas but below Flutter-rendered content.
  final platformHostAllowed =
      policy == KubusMapBlurPolicy.forceMapChromeWhenCapable ||
          policy == KubusMapBlurPolicy.forceRealBlur ||
          policy == KubusMapBlurPolicy.allowCompactWeb ||
          policy == KubusMapBlurPolicy.automatic;

  if (web &&
      overMapPlatformView &&
      platformBackdropHostAvailable &&
      platformHostAllowed &&
      !reduceEffectsUser) {
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
  // The original regression assumed Flutter's BackdropFilter could never sample
  // those pixels and forced a flat tint for ALL mobile. That is only true for
  // Hybrid Composition. This app uses the maplibre_gl default
  // (useHybridComposition == false), so:
  //
  //  * Android renders the map as a Virtual-Display TEXTURE that Flutter
  //    composites — BackdropFilter CAN sample it, so real blur works.
  //  * iOS renders a UiKitView (a real platform view) whose pixels are not in
  //    the Flutter raster — BackdropFilter cannot sample it, so iOS needs the
  //    native backdrop host (or, until that is verified, an enriched fallback).
  if (!web && overMapPlatformView && mobileNative) {
    final requireRealBlur = policy == KubusMapBlurPolicy.forceRealBlur;

    if (mobileBackdropSampleable) {
      return KubusMapBlurDecision(
        enabled: true,
        reason: 'android-virtual-display-backdrop-filter',
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
        requireRealBlur: requireRealBlur,
      );
    }

    if (nativeBlurHost) {
      return KubusMapBlurDecision(
        enabled: true,
        reason: 'mobile-native-backdrop-host',
        strategy: KubusMapBackdropStrategy.nativeBackdropHost,
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
        requireRealBlur: requireRealBlur,
      );
    }

    // No real-blur strategy available on this mobile platform (e.g. iOS before
    // the native host is verified). Fall back to the enriched tint, but flag it
    // when the caller required real blur so it is logged loudly.
    return KubusMapBlurDecision(
      enabled: false,
      reason: requireRealBlur
          ? 'mobile-real-blur-unavailable-fallback'
          : 'mobile-platform-view-safe-tint-fallback',
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
      requireRealBlur: requireRealBlur,
      realBlurUnavailable: requireRealBlur,
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
    this.requireRealBlur = false,
    this.realBlurUnavailable = false,
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
  final bool requireRealBlur;
  final bool realBlurUnavailable;
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
  bool? mobileBackdropSampleableOverride,
  bool? nativeBlurHostAvailableOverride,
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
    mobileBackdropSampleableOverride: mobileBackdropSampleableOverride,
    nativeBlurHostAvailableOverride: nativeBlurHostAvailableOverride,
  );
  final resolvedBlur = useBlur &&
      blurDecision.enabled &&
      (blurDecision.strategy ==
              KubusMapBackdropStrategy.flutterBackdropFilter ||
          blurDecision.strategy ==
              KubusMapBackdropStrategy.platformViewBackdropHost ||
          blurDecision.strategy ==
              KubusMapBackdropStrategy.nativeBackdropHost);
  final resolvedPlatformBackdrop = useBlur &&
      blurDecision.enabled &&
      (blurDecision.strategy ==
              KubusMapBackdropStrategy.platformViewBackdropHost ||
          blurDecision.strategy ==
              KubusMapBackdropStrategy.nativeBackdropHost);
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
    requireRealBlur: blurDecision.requireRealBlur,
    realBlurUnavailable: useBlur && blurDecision.realBlurUnavailable,
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
  // Default to the strict real-blur policy so every map overlay that does not
  // explicitly opt out is routed through the real-blur path (Android
  // BackdropFilter over the Virtual-Display map; web/iOS host where available).
  KubusMapBlurPolicy blurPolicy = KubusMapBlurPolicy.forceRealBlur,
  bool overMapPlatformView = true,
  String? backdropRegionId,
  bool enablePlatformBackdropRegion = true,
  String? overlayName,
  bool? isWebOverride,
  bool? platformBackdropHostAvailableOverride,
  bool? mobileNativeOverride,
  bool? mobileBackdropSampleableOverride,
  bool? nativeBlurHostAvailableOverride,
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
    mobileBackdropSampleableOverride: mobileBackdropSampleableOverride,
    nativeBlurHostAvailableOverride: nativeBlurHostAvailableOverride,
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
    // StackFit.passthrough keeps the incoming constraints intact: inside a
    // tight parent (e.g. an Expanded action-button cell) the glass surface must
    // fill the cell exactly like the blur path does, instead of shrink-wrapping
    // to its intrinsic width and leaving the sheen to cover the remainder.
    surface = Stack(
      fit: StackFit.passthrough,
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

  // Loud, explicit diagnostic when an overlay that REQUIRED real blur did not
  // get it. This is the contract from the map-glass spec: a required-but-missing
  // real blur must never ship silently as a flat tint.
  if (preset.realBlurUnavailable) {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    debugPrint(
      'REAL MAP BLUR REQUESTED BUT FALLBACK USED: '
      '${overlayName ?? kind.name} reason=${preset.blurReason} '
      'platform=$platform regionId=${backdropRegionId ?? '<none>'}',
    );
  }

  if (kDebugMode) {
    final realBlurRequired =
        preset.requireRealBlur || blurPolicy == KubusMapBlurPolicy.forceRealBlur;
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final key = '$kind:${overlayName ?? ''}:${preset.backdropStrategy}:'
        '${preset.useBlur}:${preset.realBlurUnavailable}';
    if (_loggedMapGlassFallbackKeys.add(key)) {
      debugPrint(
        'KubusMapGlassSurface diag: overlay=${overlayName ?? kind.name} '
        'kind=${kind.name} platform=$platform '
        'realBlurRequired=$realBlurRequired strategy=${preset.backdropStrategy} '
        'realBlurUsed=${preset.useBlur} fallbackUsed=${!preset.useBlur} '
        'realBlurUnavailable=${preset.realBlurUnavailable} '
        'regionId=${backdropRegionId ?? '<none>'} reason=${preset.blurReason}',
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

/// Overlays the shared static [KubusMapGlassMaterialSheen] *behind* [child] so a
/// flat tinted [GlassSurface]/[LiquidGlassPanel] fallback reads as intentional
/// liquid glass when real backdrop blur is unavailable (notably mobile overlays
/// over the MapLibre platform view, or any reduced-transparency context).
///
/// This centralizes the sheen-wrapping that map chrome built on
/// [LiquidGlassPanel] (search bar, filter chips, icon buttons, the search
/// results dropdown) previously had to inline or, worse, omit. When [show] is
/// false the [child] is returned untouched so blur-capable contexts keep the
/// real frosted look with zero extra layers.
///
/// The caller is responsible for deciding [show] (typically
/// `!(enableBlur && providerAllowsBlur)`), keeping the platform/capability
/// decision in one place rather than scattering `defaultTargetPlatform` checks.
Widget wrapWithKubusMapGlassSheen({
  required Widget child,
  required BorderRadius borderRadius,
  required bool isDark,
  required bool show,
}) {
  if (!show) return child;
  // Passthrough keeps tight parent constraints on [child] so glass chrome fills
  // its cell exactly as it would without the sheen wrapper.
  return Stack(
    fit: StackFit.passthrough,
    children: <Widget>[
      // Painted first => sits behind [child] so text/icons stay crisp on top.
      Positioned.fill(
        child: IgnorePointer(
          child: KubusMapGlassMaterialSheen(
            borderRadius: borderRadius,
            isDark: isDark,
          ),
        ),
      ),
      child,
    ],
  );
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
