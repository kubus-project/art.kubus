import 'package:art_kubus/features/map/filters/map_constraints.dart';
import 'package:art_kubus/features/map/filters/map_filter_state.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/widgets/map/filters/kubus_map_constraint_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<KubusMapConstraint> constraints,
  required ValueChanged<KubusMapConstraint> onClear,
  required VoidCallback onResetAll,
  Locale locale = const Locale('en'),
  double width = 390,
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: KubusMapConstraintStrip(
              constraints: constraints,
              onClear: onClear,
              onResetAll: onResetAll,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const searchAndFilter = <KubusMapConstraint>[
    KubusMapConstraint.viewport(),
    KubusMapConstraint.query('mural'),
    KubusMapConstraint.arOnly(),
  ];

  testWidgets('shows nothing at all when no constraint is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        constraints: const <KubusMapConstraint>[],
        onClear: (_) {},
        onResetAll: () {},
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('map_constraint_strip')),
      findsNothing,
    );
    expect(find.text('Reset all'), findsNothing);
  });

  testWidgets('lists each restriction as its own chip with reset all', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        constraints: searchAndFilter,
        onClear: (_) {},
        onResetAll: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Map area'), findsOneWidget);
    expect(find.text('Search: mural'), findsOneWidget);
    expect(find.text('AR ready'), findsOneWidget);
    expect(find.text('Reset all'), findsOneWidget);
  });

  testWidgets('tapping a chip clears exactly that restriction', (tester) async {
    final cleared = <KubusMapConstraintKind>[];
    await tester.pumpWidget(
      _harness(
        constraints: searchAndFilter,
        onClear: (c) => cleared.add(c.kind),
        onResetAll: () {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search: mural'));
    await tester.pump();
    await tester.tap(find.text('AR ready'));
    await tester.pump();

    expect(cleared, <KubusMapConstraintKind>[
      KubusMapConstraintKind.query,
      KubusMapConstraintKind.arOnly,
    ]);
  });

  testWidgets('the baseline map area is information, not a button', (
    tester,
  ) async {
    final cleared = <KubusMapConstraintKind>[];
    await tester.pumpWidget(
      _harness(
        constraints: searchAndFilter,
        onClear: (c) => cleared.add(c.kind),
        onResetAll: () {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Map area'));
    await tester.pump();
    expect(cleared, isEmpty);
  });

  testWidgets('reset all is one callback', (tester) async {
    var resets = 0;
    await tester.pumpWidget(
      _harness(
        constraints: searchAndFilter,
        onClear: (_) {},
        onResetAll: () => resets += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey<String>('map_constraint_reset_all')));
    expect(resets, 1);
  });

  testWidgets('the strip disappears once the constraints are gone', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        constraints: searchAndFilter,
        onClear: (_) {},
        onResetAll: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search: mural'), findsOneWidget);

    await tester.pumpWidget(
      _harness(
        constraints: const <KubusMapConstraint>[],
        onClear: (_) {},
        onResetAll: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search: mural'), findsNothing);
    expect(find.text('Reset all'), findsNothing);
  });

  testWidgets('Slovene copy is localised, not English', (tester) async {
    await tester.pumpWidget(
      _harness(
        locale: const Locale('sl'),
        constraints: const <KubusMapConstraint>[
          KubusMapConstraint.radius(radiusKm: 5, locationPending: true),
          KubusMapConstraint.query('mural'),
          KubusMapConstraint.hiddenLayers(<ArtMarkerType>[
            ArtMarkerType.event,
          ]),
        ],
        onClear: (_) {},
        onResetAll: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Znotraj 5 km od vas, potrebna lokacija'), findsOneWidget);
    expect(find.text('Iskanje: mural'), findsOneWidget);
    expect(find.text('Skriti tipi: 1'), findsOneWidget);
    expect(find.text('Ponastavi vse'), findsOneWidget);
  });

  testWidgets('a radius without a location is worded as not-yet-narrowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        constraints: const <KubusMapConstraint>[
          KubusMapConstraint.radius(radiusKm: 5, locationPending: true),
        ],
        onClear: (_) {},
        onResetAll: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Within 5 km of you, location needed'), findsOneWidget);
  });

  group('layout', () {
    for (final (width, scale) in const <(double, double)>[
      (320.0, 1.0),
      (320.0, 2.0),
      (390.0, 2.0),
      (1440.0, 1.0),
    ]) {
      testWidgets('does not overflow at ${width.toInt()}px, text x$scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          _harness(
            width: width,
            textScale: scale,
            constraints: const <KubusMapConstraint>[
              KubusMapConstraint.viewport(),
              KubusMapConstraint.query('a rather long search phrase'),
              KubusMapConstraint.discovery(
                  KubusMapDiscoveryStatus.undiscovered),
              KubusMapConstraint.arOnly(),
              KubusMapConstraint.favoritesOnly(),
              KubusMapConstraint.hiddenLayers(<ArtMarkerType>[
                ArtMarkerType.event,
                ArtMarkerType.institution,
              ]),
            ],
            onClear: (_) {},
            onResetAll: () {},
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Reset all'), findsOneWidget);
        final stripBox = tester.getRect(
          find.byKey(const ValueKey<String>('map_constraint_strip')),
        );
        expect(stripBox.right, lessThanOrEqualTo(width + 0.5));
      });
    }
  });
}
