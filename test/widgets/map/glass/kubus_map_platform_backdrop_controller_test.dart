import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller upserts updates and removes regions by id', () {
    final controller = KubusMapBackdropHostController();
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    const region = KubusMapBackdropRegion(
      id: 'panel',
      rect: Rect.fromLTWH(10, 20, 120, 80),
      borderRadius: BorderRadius.all(Radius.circular(12)),
      blurSigma: 18,
    );

    controller.upsertRegion(region);
    expect(controller.regionCount, 1);
    expect(controller.regions.single.rect, region.rect);
    expect(notifications, 1);

    controller.upsertRegion(region);
    expect(notifications, 1);

    controller.upsertRegion(
      const KubusMapBackdropRegion(
        id: 'panel',
        rect: Rect.fromLTWH(10, 24, 120, 80),
        borderRadius: BorderRadius.all(Radius.circular(12)),
        blurSigma: 18,
      ),
    );
    expect(controller.regionCount, 1);
    expect(controller.regions.single.rect.top, 24);
    expect(notifications, 2);

    controller.removeRegion('panel');
    expect(controller.regionCount, 0);
    expect(notifications, 3);
  });

  testWidgets('deferred region removal notifies after teardown frame',
      (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());

    final controller = KubusMapBackdropHostController();
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.upsertRegion(
      const KubusMapBackdropRegion(
        id: 'panel',
        rect: Rect.fromLTWH(10, 20, 120, 80),
        borderRadius: BorderRadius.all(Radius.circular(12)),
        blurSigma: 18,
      ),
    );
    expect(notifications, 1);

    controller.removeRegion('panel', deferNotify: true);
    expect(controller.regionCount, 0);
    expect(notifications, 1);

    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump();
    expect(notifications, 2);
  });

  testWidgets('region tracker reports layout changes and removes on dispose',
      (tester) async {
    final controller = KubusMapBackdropHostController();
    var wide = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: KubusMapBackdropScope(
          controller: controller,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () => setState(() => wide = true),
                    child: const Text('wide'),
                  ),
                  KubusMapBackdropRegionTracker(
                    id: 'tracked',
                    enabled: true,
                    borderRadius: BorderRadius.circular(10),
                    blurSigma: 16,
                    child: SizedBox(width: wide ? 160 : 80, height: 40),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(controller.regionCount, 1);
    expect(controller.regions.single.rect.width, 80);
    expect(find.byType(HtmlElementView), findsNothing);

    await tester.tap(find.text('wide'));
    await tester.pump();
    await tester.pump();
    expect(controller.regionCount, 1);
    expect(controller.regions.single.rect.width, 160);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(controller.regionCount, 0);
  });

  testWidgets('tracked detail region dispose does not notify during unmount',
      (tester) async {
    final controller = KubusMapBackdropHostController();
    final flutterErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = flutterErrors.add;
    addTearDown(() {
      FlutterError.onError = previousOnError;
      controller.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: KubusMapBackdropScope(
          controller: controller,
          child: const Center(
            child: KubusMapBackdropRegionTracker(
              id: 'tracked',
              enabled: true,
              borderRadius: BorderRadius.all(Radius.circular(10)),
              blurSigma: 16,
              child: SizedBox(width: 80, height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(controller.regionCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(controller.regionCount, 0);
    expect(flutterErrors, isEmpty);
  });
}
