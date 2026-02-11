import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/map/cards/kubus_discovery_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KubusDiscoveryCard renders task rows and toggle chip callbacks',
      (tester) async {
    var toggleChanged = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: KubusDiscoveryCard(
            overallProgress: 0.5,
            expanded: true,
            taskRows: const [
              Text('Task A'),
            ],
            onToggleExpanded: () {},
            titleStyle: const TextStyle(fontSize: 14),
            percentStyle: const TextStyle(fontSize: 12),
            toggleConfigs: [
              KubusDiscoveryToggleConfig(
                label: 'Travel',
                icon: Icons.travel_explore,
                value: false,
                onChanged: (value) => toggleChanged = value,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Task A'), findsOneWidget);
    await tester.tap(find.text('Travel'));
    await tester.pump();
    expect(toggleChanged, isTrue);
  });

  testWidgets('KubusDiscoveryCard expand button triggers callback',
      (tester) async {
    var expandTapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: KubusDiscoveryCard(
            overallProgress: 0.2,
            expanded: false,
            taskRows: const [],
            onToggleExpanded: () => expandTapped += 1,
            titleStyle: const TextStyle(fontSize: 14),
            percentStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(expandTapped, 1);
  });
}
