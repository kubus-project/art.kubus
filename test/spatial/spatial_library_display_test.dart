import 'dart:io';

import 'package:art_kubus/features/spatial/spatial_marker_directory.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/providers/spatial_library_provider.dart';
import 'package:art_kubus/screens/spatial/spatial_library_screen.dart';
import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/spatial_library_store.dart';
import 'package:flutter/material.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spatial_test_fixtures.dart';

/// Every card must name the artwork *its own record* points at.
///
/// The failure mode this guards is subtle and was reported from a real
/// device: a list that resolves titles through one shared piece of state
/// renders correctly the first time and then relabels every card the moment
/// that state moves.
void main() {
  late Directory root;
  late SpatialLibraryStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    root = await Directory.systemTemp.createTemp('kubus_spatial_display_');
    store = SpatialLibraryStore(root: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// Seeds the on-disk library and loads it into a provider.
  ///
  /// Wrapped in [WidgetTester.runAsync] because `testWidgets` runs on a fake
  /// clock: real filesystem futures never complete inside the pump loop, and
  /// awaiting one there hangs the test rather than failing it.
  Future<SpatialLibraryProvider> seededLibrary(
    WidgetTester tester,
    List<SpatialLibraryRecord> records,
  ) async {
    final library = SpatialLibraryProvider(
      store: store,
      legacyCaptureRoot: root,
      pollInterval: Duration.zero,
    );
    await tester.runAsync(() async {
      for (final record in records) {
        await store.save(record);
      }
      await library.reload();
    });
    return library;
  }

  Future<void> pumpLibrary(
    WidgetTester tester, {
    required ArtworkProvider artworks,
    required SpatialLibraryProvider library,
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
          ChangeNotifierProvider<SpatialLibraryProvider>.value(value: library),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<KubusNodeProvider>(
            create: (_) => KubusNodeProvider(
              service: KubusNodeService(isWeb: false),
            ),
          ),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: SpatialLibraryScreen(
              markerDirectory: SpatialMarkerDirectory(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('three records name their own three artworks', (tester) async {
    final artworks = ArtworkProvider()
      ..seedArtworksForTesting(<dynamic>[
        artworkFixture('artwork-a', title: 'Untitled Wall', artist: 'Maja'),
        artworkFixture('artwork-b', title: 'Bridge Piece', artist: 'Nina'),
        artworkFixture('artwork-c', title: 'Tunnel Mural', artist: 'Ana'),
      ].cast());
    final library = await seededLibrary(tester, <SpatialLibraryRecord>[
      recordFixture(localSpatialId: 'rec-a', artworkId: 'artwork-a'),
      recordFixture(localSpatialId: 'rec-b', artworkId: 'artwork-b'),
      recordFixture(localSpatialId: 'rec-c', artworkId: 'artwork-c'),
    ]);

    await pumpLibrary(tester, artworks: artworks, library: library);

    expect(find.text('Untitled Wall'), findsOneWidget);
    expect(find.text('Bridge Piece'), findsOneWidget);
    expect(find.text('Tunnel Mural'), findsOneWidget);
    expect(find.text('Maja'), findsOneWidget);
    expect(find.text('Nina'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('reordering the artwork provider relabels nothing',
      (tester) async {
    final artworks = ArtworkProvider()
      ..seedArtworksForTesting(<dynamic>[
        artworkFixture('artwork-a', title: 'Untitled Wall'),
        artworkFixture('artwork-b', title: 'Bridge Piece'),
        artworkFixture('artwork-c', title: 'Tunnel Mural'),
      ].cast());
    final library = await seededLibrary(tester, <SpatialLibraryRecord>[
      recordFixture(localSpatialId: 'rec-a', artworkId: 'artwork-a'),
      recordFixture(localSpatialId: 'rec-b', artworkId: 'artwork-b'),
      recordFixture(localSpatialId: 'rec-c', artworkId: 'artwork-c'),
    ]);

    await pumpLibrary(tester, artworks: artworks, library: library);

    // The churn a shared resolver is sensitive to: a newly uploaded artwork
    // lands at the front and the order changes underneath the list.
    artworks.seedArtworksForTesting(<dynamic>[
      artworkFixture('artwork-d', title: 'Just Uploaded'),
      artworkFixture('artwork-c', title: 'Tunnel Mural'),
      artworkFixture('artwork-b', title: 'Bridge Piece'),
      artworkFixture('artwork-a', title: 'Untitled Wall'),
    ].cast());
    await tester.pump();

    expect(find.text('Untitled Wall'), findsOneWidget);
    expect(find.text('Bridge Piece'), findsOneWidget);
    expect(find.text('Tunnel Mural'), findsOneWidget);
    expect(
      find.text('Just Uploaded'),
      findsNothing,
      reason: 'no record points at the new artwork, so no card may show it',
    );
  });

  testWidgets('a user-chosen name replaces the title without changing identity',
      (tester) async {
    final artworks = ArtworkProvider()
      ..seedArtworksForTesting(<dynamic>[
        artworkFixture('artwork-a', title: 'Untitled Wall', artist: 'Maja'),
      ].cast());
    final library = await seededLibrary(tester, <SpatialLibraryRecord>[
      recordFixture(
        localSpatialId: 'rec-a',
        artworkId: 'artwork-a',
        displayName: 'North facade, evening capture',
      ),
    ]);

    await pumpLibrary(tester, artworks: artworks, library: library);

    expect(find.text('North facade, evening capture'), findsOneWidget);
    // The artist still comes from the linked artwork.
    expect(find.text('Maja'), findsOneWidget);
  });

  testWidgets('an unresolvable artwork says so instead of showing an id',
      (tester) async {
    final artworks = ArtworkProvider()
      ..seedArtworksForTesting(<dynamic>[].cast());
    final library = await seededLibrary(tester, <SpatialLibraryRecord>[
      recordFixture(localSpatialId: 'rec-a', artworkId: 'artwork-gone'),
    ]);

    await pumpLibrary(tester, artworks: artworks, library: library);

    expect(find.text('Artwork unavailable'), findsOneWidget);
    expect(
      find.text('artwork-gone'),
      findsNothing,
      reason: 'a raw id is not a label a reader can use',
    );
  });

  testWidgets('an offline device falls back to the stored snapshot',
      (tester) async {
    final artworks = ArtworkProvider()
      ..seedArtworksForTesting(<dynamic>[].cast());
    final library = await seededLibrary(tester, <SpatialLibraryRecord>[
      recordFixture(
        localSpatialId: 'rec-a',
        artworkId: 'artwork-a',
        artworkTitleSnapshot: 'Untitled Wall',
        artistNameSnapshot: 'Maja',
      ),
    ]);

    await pumpLibrary(tester, artworks: artworks, library: library);

    expect(find.text('Untitled Wall'), findsOneWidget);
    expect(find.text('Maja'), findsOneWidget);
  });

  testWidgets('an unresolvable marker is reported, never silently dropped',
      (tester) async {
    final artworks = ArtworkProvider()
      ..seedArtworksForTesting(<dynamic>[
        artworkFixture('artwork-a', title: 'Untitled Wall'),
      ].cast());
    final library = await seededLibrary(tester, <SpatialLibraryRecord>[
      recordFixture(
        localSpatialId: 'rec-a',
        artworkId: 'artwork-a',
        markerId: 'marker-gone',
      ),
    ]);

    await pumpLibrary(tester, artworks: artworks, library: library);

    expect(find.text('Marker unavailable'), findsOneWidget);
  });

  group('the library survives every phone size and text scale', () {
    const sizes = <Size>[
      Size(320, 640),
      Size(360, 640),
      Size(390, 844),
      Size(412, 915),
      Size(480, 960),
    ];
    const scales = <double>[1.0, 1.3, 1.5, 2.0];

    for (final size in sizes) {
      for (final scale in scales) {
        testWidgets(
          'no overflow at ${size.width.toInt()}px, text scale $scale',
          (tester) async {
            final artworks = ArtworkProvider()
              ..seedArtworksForTesting(<dynamic>[
                artworkFixture(
                  'artwork-a',
                  title: 'A deliberately long artwork title for wrapping',
                  artist: 'An unusually long artist name as well',
                ),
              ].cast());
            final library = await seededLibrary(tester, <SpatialLibraryRecord>[
              recordFixture(
                localSpatialId: 'rec-a',
                artworkId: 'artwork-a',
                markerLabelSnapshot: 'Metelkova, marker 7',
                markerId: 'marker-7',
                coverage: 0.82,
              ),
              recordFixture(
                localSpatialId: 'rec-b',
                artworkId: 'artwork-a',
                processingState: SpatialLibraryProcessingState.failedRetryable,
              ),
            ]);

            await pumpLibrary(
              tester,
              artworks: artworks,
              library: library,
              size: size,
              textScale: scale,
            );

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
