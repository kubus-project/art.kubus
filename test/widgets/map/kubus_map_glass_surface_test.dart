import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass/glass_surface.dart';
import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('map blur policy allows compact web-sized chrome when capable',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 720)),
          child: Builder(
            builder: (context) {
              decision = resolveKubusMapBlurDecision(
                context,
                policy: KubusMapBlurPolicy.allowCompactWeb,
                overMapPlatformView: false,
                isWebOverride: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(decision.width, 390);
    expect(decision.strategy, KubusMapBackdropStrategy.flutterBackdropFilter);
    expect(decision.reason, 'flutter-backdrop-filter');
  });

  testWidgets(
      'desktop native capable map chrome resolves to Flutter backdrop strategy',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decision = resolveKubusMapBlurDecision(
              context,
              policy: KubusMapBlurPolicy.forceMapChromeWhenCapable,
              isWebOverride: false,
              mobileNativeOverride: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(decision.strategy, KubusMapBackdropStrategy.flutterBackdropFilter);
    expect(decision.reason, 'flutter-backdrop-filter');
  });

  testWidgets(
      'Android over MapLibre resolves to real BackdropFilter (Virtual Display)',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decision = resolveKubusMapBlurDecision(
              context,
              policy: KubusMapBlurPolicy.forceRealBlur,
              overMapPlatformView: true,
              isWebOverride: false,
              mobileNativeOverride: true,
              // Android renders MapLibre as a Virtual-Display texture that
              // Flutter's BackdropFilter CAN sample.
              mobileBackdropSampleableOverride: true,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(decision.strategy, KubusMapBackdropStrategy.flutterBackdropFilter);
    expect(decision.reason, 'android-virtual-display-backdrop-filter');
    expect(decision.requireRealBlur, isTrue);
    expect(decision.realBlurUnavailable, isFalse);
  });

  testWidgets(
      'iOS forceRealBlur with no native host falls back AND flags realBlurUnavailable',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decision = resolveKubusMapBlurDecision(
              context,
              policy: KubusMapBlurPolicy.forceRealBlur,
              overMapPlatformView: true,
              isWebOverride: false,
              mobileNativeOverride: true,
              // iOS UiKitView is not sampleable by BackdropFilter...
              mobileBackdropSampleableOverride: false,
              // ...and the native host is not available/verified yet.
              nativeBlurHostAvailableOverride: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decision.enabled, isFalse);
    expect(
      decision.strategy,
      KubusMapBackdropStrategy.platformViewSafeTintFallback,
    );
    expect(decision.reason, 'mobile-real-blur-unavailable-fallback');
    expect(decision.requireRealBlur, isTrue);
    expect(decision.realBlurUnavailable, isTrue);
  });

  testWidgets(
      'iOS forceRealBlur with native host available uses the native backdrop host',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decision = resolveKubusMapBlurDecision(
              context,
              policy: KubusMapBlurPolicy.forceRealBlur,
              overMapPlatformView: true,
              isWebOverride: false,
              mobileNativeOverride: true,
              mobileBackdropSampleableOverride: false,
              nativeBlurHostAvailableOverride: true,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(decision.strategy, KubusMapBackdropStrategy.nativeBackdropHost);
    expect(decision.reason, 'mobile-native-backdrop-host');
    expect(
      decision.strategy ==
          KubusMapBackdropStrategy.platformViewSafeTintFallback,
      isFalse,
    );
  });

  testWidgets('mobile native NOT over the map platform view keeps real blur',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decision = resolveKubusMapBlurDecision(
              context,
              policy: KubusMapBlurPolicy.automatic,
              overMapPlatformView: false,
              isWebOverride: false,
              mobileNativeOverride: true,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(decision.strategy, KubusMapBackdropStrategy.flutterBackdropFilter);
    expect(decision.reason, 'flutter-backdrop-filter');
  });

  testWidgets('web over MapLibre uses sharp foreground tint fallback',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 720)),
          child: Builder(
            builder: (context) {
              decision = resolveKubusMapBlurDecision(
                context,
                policy: KubusMapBlurPolicy.allowCompactWeb,
                overMapPlatformView: true,
                isWebOverride: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(decision.enabled, isFalse);
    expect(
      decision.strategy,
      KubusMapBackdropStrategy.platformViewSafeTintFallback,
    );
    expect(decision.reason, 'compact-web-platform-view-safe-tint-fallback');
    expect(decision.overMapPlatformView, isTrue);
    expect(decision.platformBackdropHostAvailable, isFalse);
  });

  testWidgets('compact web automatic policy uses the DOM host over MapLibre',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 720)),
          child: Builder(
            builder: (context) {
              decision = resolveKubusMapBlurDecision(
                context,
                policy: KubusMapBlurPolicy.automatic,
                overMapPlatformView: true,
                isWebOverride: true,
                platformBackdropHostAvailableOverride: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(
      decision.strategy,
      KubusMapBackdropStrategy.platformViewBackdropHost,
    );
    expect(decision.reason, 'platform-view-backdrop-host');
  });

  testWidgets(
      'compact web over MapLibre uses the DOM host when it is available',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 720)),
          child: Builder(
            builder: (context) {
              decision = resolveKubusMapBlurDecision(
                context,
                policy: KubusMapBlurPolicy.allowCompactWeb,
                overMapPlatformView: true,
                isWebOverride: true,
                platformBackdropHostAvailableOverride: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(
      decision.strategy,
      KubusMapBackdropStrategy.platformViewBackdropHost,
    );
    expect(decision.reason, 'platform-view-backdrop-host');
    expect(decision.platformBackdropHostAvailable, isTrue);
  });

  testWidgets(
      'desktop explicit map chrome policy uses platform host when available',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 900)),
          child: Builder(
            builder: (context) {
              decision = resolveKubusMapBlurDecision(
                context,
                policy: KubusMapBlurPolicy.forceMapChromeWhenCapable,
                overMapPlatformView: true,
                isWebOverride: true,
                platformBackdropHostAvailableOverride: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(
      decision.strategy,
      KubusMapBackdropStrategy.platformViewBackdropHost,
    );
    expect(decision.reason, 'platform-view-backdrop-host');
  });

  testWidgets(
      'compact web forced map chrome engages the DOM blur host',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          // Narrow/compact web is no longer excluded: the host div isolates its
          // stacking (z-index 0 + isolation) so its blur layers can never
          // composite above Flutter's overlay canvas (search dropdown stays
          // sharp) — see kubus_map_platform_backdrop_dom_web.dart.
          data: const MediaQueryData(size: Size(390, 800)),
          child: Builder(
            builder: (context) {
              decision = resolveKubusMapBlurDecision(
                context,
                policy: KubusMapBlurPolicy.forceMapChromeWhenCapable,
                overMapPlatformView: true,
                isWebOverride: true,
                platformBackdropHostAvailableOverride: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(decision.enabled, isTrue);
    expect(
      decision.strategy,
      KubusMapBackdropStrategy.platformViewBackdropHost,
    );
    expect(decision.reason, 'platform-view-backdrop-host');
  });

  testWidgets('web unhealthy WebGL resolves to documented fallback',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decision = resolveKubusMapBlurDecision(
              context,
              policy: KubusMapBlurPolicy.allowCompactWeb,
              overMapPlatformView: false,
              isWebOverride: true,
              webGlHealthyOverride: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decision.enabled, isFalse);
    expect(
      decision.strategy,
      KubusMapBackdropStrategy.platformViewSafeTintFallback,
    );
    expect(decision.reason, 'webgl-unhealthy');
  });

  testWidgets('reduce effects provider fallback reports actual reason',
      (tester) async {
    final provider = GlassCapabilitiesProvider();
    await provider.setReduceEffects(true);
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      ChangeNotifierProvider<GlassCapabilitiesProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              decision = resolveKubusMapBlurDecision(
                context,
                policy: KubusMapBlurPolicy.allowCompactWeb,
                overMapPlatformView: false,
                isWebOverride: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(decision.enabled, isFalse);
    expect(decision.reason, 'glass-provider-fallback');
    expect(decision.reduceEffects, isTrue);
    provider.dispose();
  });

  testWidgets('map blur policy reports explicit disabled fallback',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decision = resolveKubusMapBlurDecision(
              context,
              policy: KubusMapBlurPolicy.disabled,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(decision.enabled, isFalse);
    expect(decision.reason, 'policy-disabled');
    expect(
      decision.strategy,
      KubusMapBackdropStrategy.platformViewSafeTintFallback,
    );
  });

  testWidgets('map glass surface uses pure GlassSurface blur structure',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => buildKubusMapGlassSurface(
              context: context,
              kind: KubusMapGlassSurfaceKind.card,
              overMapPlatformView: false,
              child: const SizedBox(width: 80, height: 40),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(GlassSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(HtmlElementView), findsNothing);
  });

  testWidgets(
      'map glass surface host mode registers region without platform view',
      (tester) async {
    final controller = KubusMapBackdropHostController();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: KubusMapBackdropScope(
            controller: controller,
            child: Builder(
              builder: (context) => buildKubusMapGlassSurface(
                context: context,
                kind: KubusMapGlassSurfaceKind.card,
                overMapPlatformView: true,
                backdropRegionId: 'card',
                isWebOverride: true,
                platformBackdropHostAvailableOverride: true,
                blurPolicy: KubusMapBlurPolicy.forceMapChromeWhenCapable,
                child: const SizedBox(width: 80, height: 40),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(GlassSurface), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(KubusMapBackdropRegionTracker), findsOneWidget);
    expect(find.byType(HtmlElementView), findsNothing);
    expect(controller.regionCount, 1);
    expect(controller.regions.single.id, 'card');
  });

  testWidgets(
      'map glass surface uses the same opaque fallback when blur is forced off',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => buildKubusMapGlassSurface(
              context: context,
              kind: KubusMapGlassSurfaceKind.button,
              useBlur: false,
              tintBase: Colors.teal,
              child: const SizedBox(width: 80, height: 40),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);

    final clipFinder = find.byType(ClipRRect).first;
    final decoratedFinder = find
        .descendant(
          of: clipFinder,
          matching: find.byType(DecoratedBox),
        )
        .first;
    final decoratedBox = tester.widget<DecoratedBox>(decoratedFinder);
    final decoration = decoratedBox.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;

    expect(
      gradient.colors.first.a,
      closeTo(KubusGlassEffects.fallbackOpaqueOpacity, 0.001),
    );
  });

  testWidgets(
      'Android map glass surface keeps real BackdropFilter (no sheen fallback)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => buildKubusMapGlassSurface(
              context: context,
              kind: KubusMapGlassSurfaceKind.panel,
              overlayName: 'test-panel',
              overMapPlatformView: true,
              isWebOverride: false,
              mobileNativeOverride: true,
              // Android Virtual-Display map is sampleable.
              mobileBackdropSampleableOverride: true,
              child: const SizedBox(width: 120, height: 60),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(KubusMapGlassMaterialSheen), findsNothing);
  });

  testWidgets(
      'iOS map glass surface drops BackdropFilter and adds the sheen overlay',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => buildKubusMapGlassSurface(
              context: context,
              kind: KubusMapGlassSurfaceKind.panel,
              overlayName: 'test-panel',
              overMapPlatformView: true,
              isWebOverride: false,
              mobileNativeOverride: true,
              // iOS UiKitView is not sampleable and no native host yet.
              mobileBackdropSampleableOverride: false,
              nativeBlurHostAvailableOverride: false,
              child: const SizedBox(width: 120, height: 60),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(KubusMapGlassMaterialSheen), findsOneWidget);
  });

  testWidgets(
      'fallback (sheen) surface fills a tight-width parent like the blur path',
      (tester) async {
    // Regression: the sheen fallback used a loose Stack, so inside an Expanded
    // action-button cell the glass surface + icon shrank to intrinsic width and
    // left-aligned while the sheen rim spanned the whole cell.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) => buildKubusMapGlassSurface(
                    context: context,
                    kind: KubusMapGlassSurfaceKind.button,
                    overlayName: 'test-action-button',
                    overMapPlatformView: true,
                    isWebOverride: false,
                    mobileNativeOverride: true,
                    // Force the no-real-blur sheen fallback path.
                    mobileBackdropSampleableOverride: false,
                    nativeBlurHostAvailableOverride: false,
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: const [Icon(Icons.share_outlined, size: 14)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(KubusMapGlassMaterialSheen), findsOneWidget);

    final surfaceWidth = tester.getSize(find.byType(GlassSurface)).width;
    final rowWidth = tester.getSize(find.byType(Scaffold)).width;
    expect(surfaceWidth, rowWidth);
  });

  test('oversized map backdrop regions are rejected', () {
    final validation = validateKubusMapBackdropRegionForMap(
      mapRect: const Rect.fromLTWH(0, 0, 390, 720),
      region: KubusMapBackdropRegion(
        id: 'oversized-sheet',
        rect: const Rect.fromLTWH(0, 0, 390, 700),
        borderRadius: BorderRadius.circular(16),
        blurSigma: 18,
      ),
    );

    expect(validation.disposition, KubusMapBackdropRegionDisposition.rejected);
    expect(validation.reason, 'region-area-too-large');
    expect(validation.resolvedRegion, isNull);
  });

  test('small map backdrop regions are still accepted', () {
    final validation = validateKubusMapBackdropRegionForMap(
      mapRect: const Rect.fromLTWH(0, 0, 390, 720),
      region: KubusMapBackdropRegion(
        id: 'small-control',
        rect: const Rect.fromLTWH(318, 420, 56, 56),
        borderRadius: BorderRadius.circular(14),
        blurSigma: 12,
      ),
    );

    expect(validation.disposition, KubusMapBackdropRegionDisposition.accepted);
    expect(validation.resolvedRegion?.id, 'small-control');
  });

  test('partially outside map backdrop regions are clamped', () {
    final validation = validateKubusMapBackdropRegionForMap(
      mapRect: const Rect.fromLTWH(0, 0, 390, 720),
      region: KubusMapBackdropRegion(
        id: 'edge-control',
        rect: const Rect.fromLTWH(360, 700, 48, 48),
        borderRadius: BorderRadius.circular(14),
        blurSigma: 12,
      ),
    );

    expect(validation.disposition, KubusMapBackdropRegionDisposition.clamped);
    expect(validation.reason, 'clamped-to-map-bounds');
    expect(
      validation.resolvedRegion?.rect,
      const Rect.fromLTWH(360, 700, 30, 20),
    );
  });
}
