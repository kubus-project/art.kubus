import 'package:art_kubus/widgets/map/panels/kubus_detail_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KubusDetailPanel renders provided sections for each kind',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
}
