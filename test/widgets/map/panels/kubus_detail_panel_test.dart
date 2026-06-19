import 'package:art_kubus/widgets/common/kubus_glass_icon_button.dart';
import 'package:art_kubus/widgets/map/panels/kubus_detail_panel.dart';
import 'package:art_kubus/widgets/map/glass/kubus_map_platform_backdrop_host.dart';
import 'package:art_kubus/widgets/map/kubus_map_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KubusDetailPanel renders provided sections for each kind',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 220,
                child: KubusDetailPanel(
                  kind: DetailPanelKind.artwork,
                  presentation: PanelPresentation.sidePanel,
                  header: DetailHeader(
                    accentColor: Colors.teal,
                    closeTooltip: 'Close',
                    onClose: () {},
                  ),
                  sections: const [
                    Text('Artwork section'),
                  ],
                ),
              ),
              SizedBox(
                height: 220,
                child: KubusDetailPanel(
                  kind: DetailPanelKind.exhibition,
                  presentation: PanelPresentation.sidePanel,
                  header: DetailHeader(
                    accentColor: Colors.orange,
                    closeTooltip: 'Close',
                    onClose: () {},
                  ),
                  sections: const [
                    Text('Exhibition section'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Artwork section'), findsOneWidget);
    expect(find.text('Exhibition section'), findsOneWidget);
  });

  testWidgets('DetailHeader close callback and action callback are triggered',
      (tester) async {
    var closeTapped = 0;
    var actionTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: SizedBox(
            height: 260,
            child: KubusDetailPanel(
              kind: DetailPanelKind.artwork,
              presentation: PanelPresentation.sidePanel,
              header: DetailHeader(
                accentColor: Colors.blue,
                closeTooltip: 'Close',
                onClose: () => closeTapped += 1,
              ),
              sections: [
                DetailActionRow(
                  children: [
                    TextButton(
                      onPressed: () => actionTapped += 1,
                      child: const Text('Action'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    await tester.tap(find.text('Action'));
    await tester.pump();

    expect(closeTapped, 1);
    expect(actionTapped, 1);
  });

  testWidgets('DetailHeader close button uses squared Kubus radius once',
      (tester) async {
    var closeTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: SizedBox(
            height: 260,
            child: KubusDetailPanel(
              kind: DetailPanelKind.artwork,
              presentation: PanelPresentation.sidePanel,
              header: DetailHeader(
                accentColor: Colors.blue,
                closeTooltip: 'Close',
                onClose: () => closeTapped += 1,
              ),
              sections: const [
                Text('Artwork section'),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final closeButtons = find.byWidgetPredicate(
      (widget) =>
          widget is KubusGlassIconButton &&
          widget.icon == Icons.close &&
          widget.tooltip == 'Close',
    );
    expect(closeButtons, findsOneWidget);

    final closeButton = tester.widget<KubusGlassIconButton>(closeButtons);
    expect(closeButton.borderRadius, 12);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(closeTapped, 1);
  });

  testWidgets('side panel detail registers stable map backdrop region',
      (tester) async {
    final controller = KubusMapBackdropHostController();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: KubusMapBackdropScope(
            controller: controller,
            child: SizedBox(
              width: 320,
              height: 260,
              child: KubusDetailPanel(
                kind: DetailPanelKind.artwork,
                presentation: PanelPresentation.sidePanel,
                blurPolicy: KubusMapBlurPolicy.forceMapChromeWhenCapable,
                backdropRegionId: 'desktop-map-marker-detail-panel',
                isWebOverride: true,
                platformBackdropHostAvailableOverride: true,
                header: DetailHeader(
                  accentColor: Colors.teal,
                  closeTooltip: 'Close',
                  onClose: () {},
                ),
                sections: const [
                  Text('Artwork section'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(KubusMapBackdropRegionTracker), findsOneWidget);
    expect(controller.regionCount, 1);
    expect(controller.regions.single.id, 'desktop-map-marker-detail-panel');
  });
}
