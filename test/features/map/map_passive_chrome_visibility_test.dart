import 'package:art_kubus/features/map/shared/map_marker_chrome_occlusion_plan.dart';
import 'package:art_kubus/features/map/shared/map_passive_chrome_visibility.dart';
import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'occluded chrome is transparent, inert, and excluded from semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final plans = ValueNotifier<MapMarkerChromeOcclusionPlan>(
      MapMarkerChromeOcclusionPlan.visible(revision: 1),
    );
    addTearDown(plans.dispose);
    final measurementKey = GlobalKey();
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MapPassiveChromeVisibility(
          planListenable: plans,
          isOccluded: (plan) => plan.searchOccluded,
          measurementKey: measurementKey,
          duration: Duration.zero,
          curve: Curves.linear,
          child: Semantics(
            label: 'Map search',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps += 1,
              child: const SizedBox(width: 120, height: 48),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(measurementKey));
    expect(taps, 1);
    final visibleSize = tester.getSize(find.byKey(measurementKey));
    expect(
      tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.getSemanticsData().label)
          .join(' '),
      contains('Map search'),
    );

    plans.value = MapMarkerChromeOcclusionPlan.resolve(
      revision: 2,
      cardRect: const Rect.fromLTWH(0, 0, 100, 100),
      searchRect: const Rect.fromLTWH(50, 50, 100, 48),
    );
    await tester.pump();

    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byKey(measurementKey),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.opacity, 0);
    await tester.tap(find.byKey(measurementKey), warnIfMissed: false);
    expect(taps, 1);
    expect(
      tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.getSemanticsData().label)
          .join(' '),
      isNot(contains('Map search')),
    );
    expect(tester.getSize(find.byKey(measurementKey)), visibleSize);
    semantics.dispose();
  });

  testWidgets('restored chrome becomes visible and interactive again',
      (tester) async {
    final plans = ValueNotifier<MapMarkerChromeOcclusionPlan>(
      MapMarkerChromeOcclusionPlan.resolve(
        revision: 1,
        cardRect: const Rect.fromLTWH(0, 0, 100, 100),
        controlsRect: const Rect.fromLTWH(20, 20, 44, 44),
      ),
    );
    addTearDown(plans.dispose);
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MapPassiveChromeVisibility(
          planListenable: plans,
          isOccluded: (plan) => plan.controlsOccluded,
          measurementKey: GlobalKey(),
          duration: Duration.zero,
          curve: Curves.linear,
          child: IconButton(
            tooltip: 'Map tools',
            onPressed: () => taps += 1,
            icon: const Icon(Icons.tune),
          ),
        ),
      ),
    );

    plans.value = MapMarkerChromeOcclusionPlan.visible(revision: 2);
    await tester.pump();
    await tester.tap(find.byTooltip('Map tools'));
    expect(taps, 1);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
  });

  testWidgets('occlusion removes and restores platform backdrop regions',
      (tester) async {
    final plans = ValueNotifier<MapMarkerChromeOcclusionPlan>(
      MapMarkerChromeOcclusionPlan.visible(revision: 1),
    );
    final controller = KubusMapBackdropHostController();
    addTearDown(plans.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: KubusMapBackdropScope(
          controller: controller,
          child: MapPassiveChromeVisibility(
            planListenable: plans,
            isOccluded: (plan) => plan.discoveryOccluded,
            measurementKey: GlobalKey(),
            duration: Duration.zero,
            curve: Curves.linear,
            child: KubusMapBackdropRegionTracker(
              id: 'discovery',
              enabled: true,
              borderRadius: BorderRadius.zero,
              blurSigma: 12,
              child: const SizedBox(width: 160, height: 56),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.regionCount, 1);

    plans.value = MapMarkerChromeOcclusionPlan.resolve(
      revision: 2,
      cardRect: const Rect.fromLTWH(0, 0, 200, 200),
      discoveryRect: const Rect.fromLTWH(20, 20, 160, 56),
    );
    await tester.pump();
    await tester.pump();
    expect(controller.regionCount, 0);

    plans.value = MapMarkerChromeOcclusionPlan.visible(revision: 3);
    await tester.pump();
    await tester.pump();
    expect(controller.regionCount, 1);
  });
}
