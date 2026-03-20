import 'package:art_kubus/widgets/map_overlay_blocker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MapOverlayBlocker blocks taps and pointer signals', (tester) async {
    var backgroundTapCount = 0;
    var backgroundScrollCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (_) => backgroundScrollCount += 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => backgroundTapCount += 1,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned.fill(
                child: MapOverlayBlocker(
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(120, 120));
    await tester.pump();

    await tester.sendEventToBinding(
      const PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: Offset(120, 120),
        scrollDelta: Offset(0, -48),
      ),
    );
    await tester.pump();

    expect(backgroundTapCount, 0);
    expect(backgroundScrollCount, 0);
  });

  testWidgets('MapOverlayBlocker can be disabled', (tester) async {
    var backgroundTapCount = 0;
    var backgroundScrollCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (_) => backgroundScrollCount += 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => backgroundTapCount += 1,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned.fill(
                child: MapOverlayBlocker(
                  enabled: false,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(120, 120));
    await tester.pump();

    await tester.sendEventToBinding(
      const PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: Offset(120, 120),
        scrollDelta: Offset(0, -48),
      ),
    );
    await tester.pump();

    expect(backgroundTapCount, 1);
    expect(backgroundScrollCount, 1);
  });
}
