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
}
