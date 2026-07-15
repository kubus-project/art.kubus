import 'dart:ui' as ui;

import 'package:art_kubus/features/map/filters/map_filter_state.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/widgets/map/filters/kubus_map_filter_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders semantic groups and gates travel scope', (tester) async {
    await tester.pumpWidget(
      const _FilterHarness(initialState: null),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scope'), findsOneWidget);
    expect(find.text('Discovery status'), findsOneWidget);
    expect(find.text('Attributes'), findsOneWidget);
    expect(find.text('Content layers'), findsOneWidget);
    expect(find.text('Current viewport'), findsOneWidget);
    expect(find.text('Near me'), findsOneWidget);
    expect(find.text('Travel'), findsNothing);
    expect(find.text('Active filters: 0'), findsOneWidget);

    await tester.pumpWidget(
      const _FilterHarness(
        initialState: null,
        travelScopeEnabled: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Travel'), findsOneWidget);
  });

  testWidgets('scope and discovery choices update exclusively and immediately',
      (tester) async {
    KubusMapFilterState? latest;
    await tester.pumpWidget(
      _FilterHarness(
        initialState: KubusMapFilterState.defaults(),
        travelScopeEnabled: true,
        onStateChanged: (value) => latest = value,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Near me'));
    await tester.pump();

    expect(latest?.scope, KubusMapScope.nearMe);
    expect(find.byKey(const ValueKey<String>('map_filter_radius_slider')),
        findsOneWidget);

    await tester.tap(find.text('Discovered'));
    await tester.pump();

    expect(latest?.scope, KubusMapScope.nearMe);
    expect(
      latest?.discoveryStatus,
      KubusMapDiscoveryStatus.discovered,
    );

    final allSemantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('map_filter_discovery_all')),
    );
    final discoveredSemantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('map_filter_discovery_discovered')),
    );
    expect(
      allSemantics.flagsCollection.isSelected,
      isNot(ui.Tristate.isTrue),
    );
    expect(
      discoveredSemantics.flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
  });

  testWidgets('attributes are independent live toggles', (tester) async {
    KubusMapFilterState? latest;
    await tester.pumpWidget(
      _FilterHarness(
        initialState: KubusMapFilterState.defaults(),
        onStateChanged: (value) => latest = value,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('map_filter_ar')));
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey<String>('map_filter_favorites')));
    await tester.pump();

    expect(latest?.arOnly, isTrue);
    expect(latest?.favoritesOnly, isTrue);
    expect(latest?.activeFilterCount, 2);
    expect(find.text('Active filters: 2'), findsOneWidget);

    final arSemantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('map_filter_ar')),
    );
    expect(
      arSemantics.flagsCollection.isToggled,
      ui.Tristate.isTrue,
    );
  });

  testWidgets('near-me radius is contextual, constrained, and live',
      (tester) async {
    KubusMapFilterState? latest;
    await tester.pumpWidget(
      _FilterHarness(
        initialState: KubusMapFilterState(
          scope: KubusMapScope.nearMe,
          nearMeRadiusKm: 5,
        ),
        minNearMeRadiusKm: 2,
        maxNearMeRadiusKm: 20,
        onStateChanged: (value) => latest = value,
      ),
    );
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('map_filter_radius_slider')),
    );
    expect(slider.min, 2);
    expect(slider.max, 20);
    slider.onChanged!(12.5);
    await tester.pump();

    expect(latest?.nearMeRadiusKm, 12.5);
    expect(find.text('Radius: 12.5 km'), findsOneWidget);

    await tester.tap(find.text('Current viewport'));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('map_filter_radius_slider')),
        findsNothing);
  });

  testWidgets('disabled radius preserves context but cannot update',
      (tester) async {
    await tester.pumpWidget(
      _FilterHarness(
        initialState: KubusMapFilterState(scope: KubusMapScope.nearMe),
        nearMeRadiusEnabled: false,
      ),
    );
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('map_filter_radius_slider')),
    );
    expect(slider.onChanged, isNull);
  });

  testWidgets('content layers report count and preserve one visible layer',
      (tester) async {
    var callbackCount = 0;
    KubusMapFilterState? latest;
    await tester.pumpWidget(
      _FilterHarness(
        initialState: KubusMapFilterState(
          visibleContentLayers: const <ArtMarkerType>{ArtMarkerType.artwork},
        ),
        onStateChanged: (value) {
          callbackCount += 1;
          latest = value;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 9 visible'), findsOneWidget);
    final artworkLayer = find.text('Artworks');
    await tester.ensureVisible(artworkLayer);
    await tester.pump();
    await tester.tap(artworkLayer);
    await tester.pump();

    expect(callbackCount, 0);
    expect(latest, isNull);
    expect(find.text('1 of 9 visible'), findsOneWidget);
  });

  testWidgets('layer changes and reset update count without an Apply action',
      (tester) async {
    KubusMapFilterState? latest;
    await tester.pumpWidget(
      _FilterHarness(
        initialState: KubusMapFilterState.defaults(),
        onStateChanged: (value) => latest = value,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9 of 9 visible'), findsOneWidget);
    expect(find.text('Apply'), findsNothing);

    final eventLayer = find.text('Events');
    await tester.ensureVisible(eventLayer);
    await tester.pump();
    await tester.tap(eventLayer);
    await tester.pump();
    expect(latest?.visibleContentLayers.length, 8);
    expect(find.text('8 of 9 visible'), findsOneWidget);
    expect(find.text('Active filters: 1'), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('map_filter_reset')), findsOneWidget);

    final reset = find.byKey(const ValueKey<String>('map_filter_reset'));
    await tester.ensureVisible(reset);
    await tester.pump();
    await tester.tap(reset);
    await tester.pump();
    expect(latest?.isDefault, isTrue);
    expect(find.text('9 of 9 visible'), findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('map_filter_reset')), findsNothing);
  });

  testWidgets('360px layout scrolls without horizontal overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const _FilterHarness(
        initialState: null,
        travelScopeEnabled: true,
        width: 360,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Content layers'), findsOneWidget);
    final lastLayer = find.text('Misc');
    await tester.ensureVisible(lastLayer);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(lastLayer, findsOneWidget);
  });
}

class _FilterHarness extends StatefulWidget {
  const _FilterHarness({
    required this.initialState,
    this.onStateChanged,
    this.travelScopeEnabled = false,
    this.nearMeRadiusEnabled = true,
    this.minNearMeRadiusKm = KubusMapFilterState.minNearMeRadiusKm,
    this.maxNearMeRadiusKm = KubusMapFilterState.maxNearMeRadiusKm,
    this.width,
  });

  final KubusMapFilterState? initialState;
  final ValueChanged<KubusMapFilterState>? onStateChanged;
  final bool travelScopeEnabled;
  final bool nearMeRadiusEnabled;
  final double minNearMeRadiusKm;
  final double maxNearMeRadiusKm;
  final double? width;

  @override
  State<_FilterHarness> createState() => _FilterHarnessState();
}

class _FilterHarnessState extends State<_FilterHarness> {
  late KubusMapFilterState state;

  @override
  void initState() {
    super.initState();
    state = widget.initialState ?? KubusMapFilterState.defaults();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SizedBox(
          width: widget.width,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: KubusMapFilterContent(
                state: state,
                travelScopeEnabled: widget.travelScopeEnabled,
                nearMeRadiusEnabled: widget.nearMeRadiusEnabled,
                minNearMeRadiusKm: widget.minNearMeRadiusKm,
                maxNearMeRadiusKm: widget.maxNearMeRadiusKm,
                onChanged: (value) {
                  setState(() => state = value);
                  widget.onStateChanged?.call(value);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
