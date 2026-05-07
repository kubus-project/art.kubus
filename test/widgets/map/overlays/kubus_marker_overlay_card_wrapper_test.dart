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
}
