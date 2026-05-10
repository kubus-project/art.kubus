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

  testWidgets('native capable map chrome resolves to Flutter backdrop strategy',
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
        home: Builder(
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
    );

    expect(decision.enabled, isFalse);
    expect(
      decision.strategy,
      KubusMapBackdropStrategy.platformViewSafeTintFallback,
    );
    expect(decision.reason, 'platform-view-safe-tint-fallback');
    expect(decision.overMapPlatformView, isTrue);
    expect(decision.platformBackdropHostAvailable, isFalse);
  });

  testWidgets('web over MapLibre uses platform host when available',
      (tester) async {
    late KubusMapBlurDecision decision;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
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
    );

    expect(decision.enabled, isTrue);
    expect(
        decision.strategy, KubusMapBackdropStrategy.platformViewBackdropHost);
    expect(decision.reason, 'platform-view-backdrop-host');
    expect(decision.platformBackdropHostAvailable, isTrue);
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
}
