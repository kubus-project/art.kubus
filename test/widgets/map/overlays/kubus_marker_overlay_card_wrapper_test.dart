import 'package:art_kubus/widgets/map/overlays/kubus_marker_overlay_card_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KubusMarkerOverlayCardWrapper uses centered mode',
      (tester) async {
    final anchor = ValueNotifier<Offset?>(null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: KubusMarkerOverlayCardWrapper(
              anchorListenable: anchor,
              placementStrategy: KubusMarkerOverlayPlacementStrategy.centered,
              cardBuilder: (context, layout) => SizedBox(
                width: layout.cardWidth,
                height: layout.cardHeight,
                child: const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('kubus_marker_overlay_centered')),
      findsOneWidget,
    );
  });

  testWidgets('KubusMarkerOverlayCardWrapper uses anchored mode',
      (tester) async {
    final anchor = ValueNotifier<Offset?>(const Offset(180, 220));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: KubusMarkerOverlayCardWrapper(
              anchorListenable: anchor,
              placementStrategy: KubusMarkerOverlayPlacementStrategy.anchored,
              cardBuilder: (context, layout) => SizedBox(
                width: layout.cardWidth,
                height: layout.cardHeight,
                child: const ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('kubus_marker_overlay_anchored')),
      findsOneWidget,
    );
  });

  testWidgets('KubusMarkerOverlayCardWrapper clamps anchored card in safe area',
      (tester) async {
    final anchor = ValueNotifier<Offset?>(const Offset(8, 18));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 400),
            padding: EdgeInsets.only(top: 24, bottom: 16),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: KubusMarkerOverlayCardWrapper(
                anchorListenable: anchor,
                placementStrategy: KubusMarkerOverlayPlacementStrategy.anchored,
                widthResolver: (_, __) => 160,
                maxHeightResolver: (_, __) => 220,
                heightResolver: (_, __, ___) => 180,
                horizontalPadding: 20,
                topPadding: 12,
                bottomPadding: 18,
                markerOffset: 24,
                cardBuilder: (context, layout) => SizedBox(
                  key: const ValueKey<String>('test_card'),
                  width: layout.cardWidth,
                  height: layout.cardHeight,
                  child: const ColoredBox(color: Colors.green),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final rect =
        tester.getRect(find.byKey(const ValueKey<String>('test_card')));
    expect(rect.left, greaterThanOrEqualTo(20));
    expect(rect.top, greaterThanOrEqualTo(36));
    expect(rect.right, lessThanOrEqualTo(380));
    expect(rect.bottom, lessThanOrEqualTo(382));
  });

  testWidgets('anchored preview yields to reserved desktop top chrome',
      (tester) async {
    final anchor = ValueNotifier<Offset?>(const Offset(200, 40));
    addTearDown(anchor.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 500,
            child: KubusMarkerOverlayCardWrapper(
              anchorListenable: anchor,
              placementStrategy: KubusMarkerOverlayPlacementStrategy.anchored,
              widthResolver: (_, __) => 180,
              maxHeightResolver: (_, __) => 240,
              heightResolver: (_, __, ___) => 200,
              topPadding: 80,
              cardBuilder: (_, layout) => SizedBox(
                key: const ValueKey<String>('desktop_chrome_safe_card'),
                width: layout.cardWidth,
                height: layout.cardHeight,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('desktop_chrome_safe_card')),
          )
          .dy,
      greaterThanOrEqualTo(80),
    );
  });

  testWidgets('KubusMarkerOverlayCardWrapper clamps lower-right anchored card',
      (tester) async {
    final anchor = ValueNotifier<Offset?>(const Offset(396, 396));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: KubusMarkerOverlayCardWrapper(
              anchorListenable: anchor,
              placementStrategy: KubusMarkerOverlayPlacementStrategy.anchored,
              widthResolver: (_, __) => 180,
              maxHeightResolver: (_, __) => 240,
              heightResolver: (_, __, ___) => 200,
              horizontalPadding: 16,
              topPadding: 12,
              bottomPadding: 20,
              markerOffset: 24,
              cardBuilder: (context, layout) => SizedBox(
                key: const ValueKey<String>('test_card'),
                width: layout.cardWidth,
                height: layout.cardHeight,
                child: const ColoredBox(color: Colors.green),
              ),
            ),
          ),
        ),
      ),
    );

    final rect =
        tester.getRect(find.byKey(const ValueKey<String>('test_card')));
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(rect.right, lessThanOrEqualTo(384));
    expect(rect.bottom, lessThanOrEqualTo(380));
  });

  testWidgets('anchored preview interpolates when its map anchor moves',
      (tester) async {
    final anchor = ValueNotifier<Offset?>(const Offset(100, 260));
    addTearDown(anchor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: KubusMarkerOverlayCardWrapper(
              anchorListenable: anchor,
              widthResolver: (_, __) => 160,
              maxHeightResolver: (_, __) => 160,
              heightResolver: (_, __, ___) => 120,
              animation: const KubusMarkerOverlayAnimationConfig(
                duration: Duration(milliseconds: 200),
                curve: Curves.linear,
              ),
              cardBuilder: (_, layout) => SizedBox(
                key: const ValueKey<String>('moving_card'),
                width: layout.cardWidth,
                height: layout.cardHeight,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final start = tester.getTopLeft(
      find.byKey(const ValueKey<String>('moving_card')),
    );

    anchor.value = const Offset(300, 260);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.getTopLeft(
      find.byKey(const ValueKey<String>('moving_card')),
    );
    expect(midway.dx, greaterThan(start.dx));
    expect(midway.dx, lessThan(220));

    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('moving_card'))).dx,
      closeTo(220, 0.01),
    );
  });

  testWidgets('reduced motion repositions anchored preview immediately',
      (tester) async {
    final anchor = ValueNotifier<Offset?>(const Offset(100, 260));
    addTearDown(anchor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: KubusMarkerOverlayCardWrapper(
              anchorListenable: anchor,
              widthResolver: (_, __) => 160,
              maxHeightResolver: (_, __) => 160,
              heightResolver: (_, __, ___) => 120,
              animation: const KubusMarkerOverlayAnimationConfig(
                duration: Duration.zero,
                curve: Curves.linear,
                allowsSpatialTransform: false,
              ),
              cardBuilder: (_, layout) => SizedBox(
                key: const ValueKey<String>('reduced_card'),
                width: layout.cardWidth,
                height: layout.cardHeight,
              ),
            ),
          ),
        ),
      ),
    );

    anchor.value = const Offset(300, 260);
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('reduced_card'))).dx,
      closeTo(220, 0.01),
    );
  });

  for (final viewport in <Size>[const Size(360, 640), const Size(390, 844)]) {
    testWidgets(
      'bottom-docked preview respects ${viewport.width.toInt()}px safe bounds',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final anchor = ValueNotifier<Offset?>(const Offset(24, 24));
        addTearDown(anchor.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: viewport,
                padding: const EdgeInsets.only(top: 24, bottom: 20),
              ),
              child: Scaffold(
                body: SizedBox.fromSize(
                  size: viewport,
                  child: KubusMarkerOverlayCardWrapper(
                    anchorListenable: anchor,
                    placementStrategy:
                        KubusMarkerOverlayPlacementStrategy.bottomDocked,
                    widthResolver: (constraints, _) =>
                        constraints.maxWidth - 24,
                    maxHeightResolver: (_, __) => 208,
                    heightResolver: (_, __, ___) => 208,
                    horizontalPadding: 12,
                    bottomPadding: 96,
                    cardBuilder: (context, layout) => SizedBox(
                      key: const ValueKey<String>('bottom_docked_card'),
                      width: layout.cardWidth,
                      height: 180,
                      child: const ColoredBox(color: Colors.teal),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final rect = tester.getRect(
          find.byKey(const ValueKey<String>('bottom_docked_card')),
        );
        expect(rect.left, greaterThanOrEqualTo(12));
        expect(rect.right, lessThanOrEqualTo(viewport.width - 12));
        expect(rect.bottom, viewport.height - 96);
        expect(
          find.byKey(
            const ValueKey<String>('kubus_marker_overlay_bottom_docked'),
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('bottom-docked preview does not follow map anchor updates',
      (tester) async {
    final anchor = ValueNotifier<Offset?>(const Offset(24, 24));
    addTearDown(anchor.dispose);
    var buildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: KubusMarkerOverlayCardWrapper(
              anchorListenable: anchor,
              placementStrategy:
                  KubusMarkerOverlayPlacementStrategy.bottomDocked,
              widthResolver: (_, __) => 320,
              maxHeightResolver: (_, __) => 208,
              heightResolver: (_, __, ___) => 208,
              bottomPadding: 76,
              cardBuilder: (context, layout) {
                buildCount += 1;
                return const SizedBox(width: 320, height: 180);
              },
            ),
          ),
        ),
      ),
    );
    final initialBuildCount = buildCount;

    anchor.value = const Offset(300, 500);
    await tester.pump();

    expect(buildCount, initialBuildCount);
  });
}
