import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_map_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_glass_icon_button.dart';
import 'package:art_kubus/widgets/glass/glass_surface.dart';
import 'package:art_kubus/widgets/map/cards/kubus_discovery_card.dart';
import 'package:art_kubus/widgets/map/discovery/kubus_discovery_path_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapCard({
  required bool expanded,
  KubusDiscoveryExpansionDirection direction =
      KubusDiscoveryExpansionDirection.downward,
  List<Widget> taskRows = const [Text('Task A')],
  VoidCallback? onToggleExpanded,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: KubusDiscoveryCard(
        overallProgress: 0.5,
        expanded: expanded,
        taskRows: taskRows,
        expansionDirection: direction,
        onToggleExpanded: onToggleExpanded ?? () {},
        titleStyle: const TextStyle(fontSize: 14),
        percentStyle: const TextStyle(fontSize: 12),
      ),
    ),
  );
}

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

  testWidgets('downward chevron points down when collapsed, up when expanded',
      (tester) async {
    await tester.pumpWidget(_wrapCard(expanded: false));
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);

    await tester.pumpWidget(_wrapCard(expanded: true));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('upward chevron points up when collapsed, down when expanded',
      (tester) async {
    await tester.pumpWidget(
      _wrapCard(
        expanded: false,
        direction: KubusDiscoveryExpansionDirection.upward,
      ),
    );
    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

    await tester.pumpWidget(
      _wrapCard(
        expanded: true,
        direction: KubusDiscoveryExpansionDirection.upward,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
  });

  testWidgets('collapsed card keeps a stable header and hides task rows',
      (tester) async {
    await tester.pumpWidget(
      _wrapCard(expanded: false, taskRows: const [Text('Hidden task')]),
    );
    await tester.pumpAndSettle();

    // Header card is always present.
    expect(find.byType(KubusDiscoveryPathCard), findsOneWidget);
    // The collapsed task area is sized to zero, so task rows are not shown.
    expect(find.text('Hidden task'), findsNothing);
  });

  testWidgets('expanded task rows show without layout exceptions',
      (tester) async {
    await tester.pumpWidget(
      _wrapCard(
        expanded: true,
        taskRows: const [Text('Task A'), Text('Task B')],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Task B'), findsOneWidget);
    expect(tester.getSize(find.text('Task A')).height, greaterThan(0));
  });

  testWidgets('responsive surface radius reaches the shared path card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: KubusDiscoveryCard(
            overallProgress: 0.5,
            expanded: false,
            taskRows: const <Widget>[],
            onToggleExpanded: () {},
            titleStyle: const TextStyle(fontSize: 14),
            percentStyle: const TextStyle(fontSize: 12),
            surfaceRadius: KubusRadius.md,
          ),
        ),
      ),
    );

    final pathCard = tester.widget<KubusDiscoveryPathCard>(
      find.byType(KubusDiscoveryPathCard),
    );
    expect(pathCard.surfaceRadius, KubusRadius.md);
    expect(pathCard.glassPadding, const EdgeInsets.all(KubusSpacing.md));
  });

  testWidgets('mobile map header radius paints a rectangular glass surface',
      (tester) async {
    // Regression guard: the collapsed discovery module previously used a
    // hardcoded 18 and then KubusRadius.md (12), both of which read as a
    // capsule under the map search field. It now shares the search field's
    // header token.
    expect(KubusMapMetrics.headerSurfaceRadius, KubusRadius.sm);
    expect(KubusRadius.sm, 8.0);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: KubusDiscoveryCard(
              overallProgress: 0.5,
              expanded: false,
              compactWhenCollapsed: true,
              compactProgressLabel: '0/52',
              taskRows: const <Widget>[Text('Task A')],
              onToggleExpanded: () {},
              titleStyle: const TextStyle(fontSize: 14),
              percentStyle: const TextStyle(fontSize: 12),
              expandButtonSize: KubusHeaderMetrics.actionHitArea,
              glassPadding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.md,
                vertical: KubusSpacing.xs,
              ),
              surfaceRadius: KubusMapMetrics.headerSurfaceRadius,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.widget<GlassSurface>(
      find
          .descendant(
            of: find.byType(KubusDiscoveryPathCard),
            matching: find.byType(GlassSurface),
          )
          .first,
    );
    expect(surface.borderRadius, BorderRadius.circular(KubusRadius.sm));

    // Wide, short bar — never a capsule — and the toggle keeps its 44px target.
    final size = tester.getSize(find.byType(KubusDiscoveryPathCard));
    expect(size.height, lessThan(size.width));
    expect(size.height, lessThan(KubusHeaderMetrics.actionHitArea * 1.5));
    expect(
      tester.getSize(find.byType(KubusGlassIconButton)).height,
      KubusHeaderMetrics.actionHitArea,
    );
  });

  testWidgets('compact Slovenian discovery header remains overflow-safe',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: KubusDiscoveryCard(
              overallProgress: 0.73,
              expanded: false,
              compactWhenCollapsed: true,
              compactProgressLabel: '11/15',
              taskRows: const <Widget>[],
              onToggleExpanded: () {},
              titleStyle: const TextStyle(fontSize: 14),
              percentStyle: const TextStyle(fontSize: 12),
              surfaceRadius: KubusRadius.md,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(KubusDiscoveryPathCard), findsOneWidget);
  });
}
