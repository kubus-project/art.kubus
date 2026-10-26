import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/portfolio_entry.dart';
import 'package:art_kubus/screens/web3/artist/artist_portfolio_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:art_kubus/providers/portfolio_provider.dart';

Artwork _buildArtwork({
  required String id,
  required String title,
  required bool isPublic,
  required bool isActive,
}) {
  return Artwork(
    id: id,
    title: title,
    artist: 'Artist',
    description: 'Description',
    position: const LatLng(46.05, 14.5),
    rewards: 5,
    createdAt: DateTime.utc(2026, 3, 17),
    isPublic: isPublic,
    isActive: isActive,
  );
}

/// Records the studio cards the screen asks to open instead of navigating.
typedef _OpenEntrySpy = List<PortfolioEntry> Function();

Future<_OpenEntrySpy> _pumpScreen(
  WidgetTester tester, {
  required List<Artwork> artworks,
  Size size = const Size(390, 844),
}) async {
  final api = BackendApiService();
  api.setAuthTokenForTesting('test-token');
  api.setHttpClient(
    MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/artworks') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': artworks
                .map((artwork) => <String, Object?>{
                      'id': artwork.id,
                      'title': artwork.title,
                      'artist': artwork.artist,
                      'description': artwork.description,
                      'latitude': artwork.position.latitude,
                      'longitude': artwork.position.longitude,
                      'rewards': artwork.rewards,
                      'createdAt': artwork.createdAt.toIso8601String(),
                      'isPublic': artwork.isPublic,
                      'isActive': artwork.isActive,
                    })
                .toList(growable: false),
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (path == '/api/profiles/wallet-1/artworks') {
        // The owner's authored scope: active records only, drafts included
        // because the request is authenticated. Documented is empty here.
        final relationship = request.url.queryParameters['relationship'];
        final rows = relationship == 'authored'
            ? artworks
                .where((artwork) => artwork.isActive)
                .map((artwork) => <String, Object?>{
                      'id': artwork.id,
                      'title': artwork.title,
                      'artistName': artwork.artist,
                      'createdAt': artwork.createdAt.toIso8601String(),
                    })
                .toList(growable: false)
            : const <Object?>[];
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'relationship': relationship,
            'data': rows,
            'pagination': <String, Object?>{
              'limit': 24,
              'offset': 0,
              'total': rows.length,
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (path == '/api/art-markers/mine') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': const <Object?>[],
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (path == '/api/collections') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': const <Object?>[],
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      if (path == '/api/exhibitions') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'exhibitions': const <Object?>[],
            },
          }),
          200,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    }),
  );
  final provider = PortfolioProvider(api: api);
  provider.setWalletAddress('wallet-1');

  final opened = <PortfolioEntry>[];

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<PortfolioProvider>.value(
      value: provider,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: ArtistPortfolioScreen(
              walletAddress: 'wallet-1',
              // Card taps are observed here rather than navigated, so these
              // tests stay about the studio contract.
              onOpenEntry: (context, entry) async => opened.add(entry),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return () => opened;
}

/// How many columns the gallery actually laid out.
int _galleryColumns(WidgetTester tester) {
  final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
  final delegate =
      grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  return delegate.crossAxisCount;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('public active artworks expose promote actions', (tester) async {
    final opened = await _pumpScreen(
      tester,
      artworks: <Artwork>[
        _buildArtwork(
          id: 'art-1',
          title: 'Public Artwork',
          isPublic: true,
          isActive: true,
        ),
      ],
    );

    final context = tester.element(find.byType(ArtistPortfolioScreen));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.text(l10n.commonActions));
    await tester.pumpAndSettle();
    expect(find.text(l10n.eventDetailPromoteLabel), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // A card tap opens the artwork, never the actions sheet.
    await tester.tap(find.text('Public Artwork'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.eventDetailPromoteLabel), findsNothing);
    expect(opened(), hasLength(1));
    expect(opened().single.id, 'art-1');
  });

  testWidgets('draft and inactive artworks do not expose promote actions',
      (tester) async {
    final opened = await _pumpScreen(
      tester,
      artworks: <Artwork>[
        _buildArtwork(
          id: 'art-2',
          title: 'Draft Artwork',
          isPublic: false,
          isActive: true,
        ),
        _buildArtwork(
          id: 'art-3',
          title: 'Inactive Artwork',
          isPublic: true,
          isActive: false,
        ),
      ],
    );

    expect(find.text('Draft Artwork'), findsOneWidget);
    expect(find.text('Inactive Artwork'), findsNothing);

    final context = tester.element(find.byType(ArtistPortfolioScreen));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.text(l10n.commonActions).first);
    await tester.pumpAndSettle();
    expect(find.text(l10n.eventDetailPromoteLabel), findsNothing);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Draft Artwork'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.eventDetailPromoteLabel), findsNothing);
    expect(opened().map((entry) => entry.id), <String>['art-2']);
  });

  group('the gallery is a responsive, image-led workspace', () {
    final artworks = <Artwork>[
      for (var i = 0; i < 8; i++)
        _buildArtwork(
          id: 'art-$i',
          title: 'Work $i',
          isPublic: true,
          isActive: true,
        ),
    ];

    // A phone stays an image-led list; a wide window gains columns at a
    // consistent rhythm instead of stranding one narrow column in the middle
    // of it. The old gallery was a single list at every width.
    for (final expectation in const <(double, int)>[
      (390, 1),
      (768, 2),
      (1440, 4),
      (1920, 5),
    ]) {
      testWidgets(
          '${expectation.$1.toInt()} px lays out '
          '${expectation.$2} column(s)', (tester) async {
        await _pumpScreen(
          tester,
          artworks: artworks,
          size: Size(expectation.$1, 1000),
        );
        expect(_galleryColumns(tester), expectation.$2);
      });
    }

    testWidgets(
        'every card carries its publication state and one actions control',
        (tester) async {
      await _pumpScreen(
        tester,
        artworks: <Artwork>[
          _buildArtwork(
            id: 'art-pub',
            title: 'Published',
            isPublic: true,
            isActive: true,
          ),
          _buildArtwork(
            id: 'art-draft',
            title: 'Draft one',
            isPublic: false,
            isActive: true,
          ),
        ],
        size: const Size(1440, 1000),
      );
      final context = tester.element(find.byType(ArtistPortfolioScreen));
      final l10n = AppLocalizations.of(context)!;

      // Publication state is information, so it is always visible — touch
      // never hovers — and the management control is exactly one per card.
      expect(
        find.text(l10n.artistGalleryFilterActive.toUpperCase()),
        findsOneWidget,
      );
      expect(
        find.text(l10n.artistGalleryFilterDraft.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text(l10n.commonActions), findsNWidgets(2));
    });
  });
}
