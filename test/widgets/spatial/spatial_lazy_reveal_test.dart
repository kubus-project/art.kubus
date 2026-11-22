import 'package:art_kubus/widgets/spatial/spatial_lazy_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _page({required double spacer, required ScrollController controller}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: controller,
          child: Column(
            children: <Widget>[
              SizedBox(height: spacer),
              const SpatialLazyReveal(
                height: 300,
                placeholder: Text('placeholder'),
                child: Text('viewer'),
              ),
              const SizedBox(height: 1500),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('a viewer already in view is created at once', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(spacer: 100, controller: controller));
    await tester.pump();
    await tester.pump();
    expect(find.text('viewer'), findsOneWidget);
    expect(find.text('placeholder'), findsNothing);
  });

  testWidgets('a viewer below the fold is created only when scrolled to',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_page(spacer: 1200, controller: controller));
    await tester.pump();
    await tester.pump();
    expect(find.text('viewer', skipOffstage: false), findsNothing);
    expect(find.text('placeholder', skipOffstage: false), findsOneWidget);

    controller.jumpTo(700);
    await tester.pump();
    await tester.pump();
    expect(find.text('viewer'), findsOneWidget);

    // Once revealed it stays: scrolling away does not tear the viewer down.
    controller.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(find.text('viewer', skipOffstage: false), findsOneWidget);
  });
}
