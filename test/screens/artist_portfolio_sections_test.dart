import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/portfolio_entry.dart';
import 'package:art_kubus/providers/portfolio_provider.dart';
import 'package:art_kubus/screens/web3/artist/artist_portfolio_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _createdAt = '2026-03-17T10:00:00.000Z';

/// Wallet-managed artwork record, as `/api/artworks?wallet=` returns it.
Map<String, Object?> _record(String id, String title,
        {bool isPublic = true, bool isActive = true}) =>
    <String, Object?>{
      'id': id,
      'title': title,
      'artist': 'Ana',
      'description': 'Description',
      'latitude': 46.05,
      'longitude': 14.5,
      'rewards': 5,
      'createdAt': _createdAt,
      'isPublic': isPublic,
      'isActive': isActive,
    };

/// One scoped row, as `/api/profiles/:wallet/artworks` returns it.
Map<String, Object?> _scoped(String id, String title,
        {String artistName = 'Ana'}) =>
    <String, Object?>{
      'id': id,
      'title': title,
      'artistName': artistName,
      'createdAt': _createdAt,
    };

/// A public-art marker the signed-in owner created, as `/api/art-markers/mine`
/// returns it.
Map<String, Object?> _marker(String id, String name,
        {String? artworkId, String? ownerWallet = 'wallet-1'}) =>
    <String, Object?>{
      'id': id,
      'name': name,
      'latitude': 46.05,
      'longitude': 14.5,
      'markerType': 'streetArt',
      'artworkId': artworkId,
      'ownerWalletAddress': ownerWallet,
      'createdBy': ownerWallet,
      'isActive': true,
      'createdAt': _createdAt,
    };

class _Account {
  const _Account({
    this.authored = const <Map<String, Object?>>[],
    this.documented = const <Map<String, Object?>>[],
    this.records = const <Map<String, Object?>>[],
    this.markers = const <Map<String, Object?>>[],
    this.collections = const <Map<String, Object?>>[],
  });

  final List<Map<String, Object?>> authored;
  final List<Map<String, Object?>> documented;
  final List<Map<String, Object?>> records;
  final List<Map<String, Object?>> markers;
  final List<Map<String, Object?>> collections;
}

/// A fake backend that answers the studio's reads per account.
class _Backend {
  _Backend({this.accounts = const <String, _Account>{}, this.honour = true});

  final Map<String, _Account> accounts;

  /// When false the backend ignores `relationship` and answers with the legacy
  /// mixed list, as an older deployment does.
  final bool honour;

  /// The signed-in account, which `/api/art-markers/mine` answers for.
  String signedIn = 'wallet-1';

  /// Holds the profile-scoped responses of one wallet until completed.
  final Map<String, Completer<void>> gates = <String, Completer<void>>{};

  final List<http.Request> requests = <http.Request>[];

  _Account _account(String wallet) => accounts[wallet] ?? const _Account();

  http.Response _json(Object? body) => http.Response(
        jsonEncode(body),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );

  http.Client client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        final query = request.url.queryParameters;

        if (path == '/api/artworks') {
          final rows = _account(query['wallet'] ?? '').records;
          return _json(<String, Object?>{'success': true, 'data': rows});
        }

        final profile =
            RegExp(r'^/api/profiles/([^/]+)/artworks$').firstMatch(path);
        if (profile != null) {
          final wallet = profile.group(1)!;
          final gate = gates[wallet];
          if (gate != null) await gate.future;
          final account = _account(wallet);
          if (!honour) {
            return _json(<String, Object?>{
              'success': true,
              'data': <Map<String, Object?>>[
                ...account.authored,
                ...account.documented,
              ],
              'pagination': <String, Object?>{
                'limit': 24,
                'offset': 0,
                'total': account.authored.length + account.documented.length,
              },
            });
          }
          final relationship = query['relationship'];
          final rows = relationship == 'authored'
              ? account.authored
              : relationship == 'documented'
                  ? account.documented
                  : const <Map<String, Object?>>[];
          final offset = int.tryParse(query['offset'] ?? '') ?? 0;
          final limit = int.tryParse(query['limit'] ?? '') ?? 20;
          return _json(<String, Object?>{
            'success': true,
            'relationship': relationship,
            'data': rows.skip(offset).take(limit).toList(growable: false),
            'pagination': <String, Object?>{
              'limit': limit,
              'offset': offset,
              'total': rows.length,
            },
          });
        }

        if (path == '/api/art-markers/mine') {
          return _json(<String, Object?>{
            'success': true,
            'data': _account(signedIn).markers,
          });
        }
        if (path == '/api/collections') {
          return _json(<String, Object?>{
            'success': true,
            'data': _account(query['walletAddress'] ?? '').collections,
          });
        }
        if (path == '/api/exhibitions') {
          return _json(<String, Object?>{
            'success': true,
            'data': <String, Object?>{'exhibitions': const <Object?>[]},
          });
        }
        throw StateError(
            'Unexpected request: ${request.method} ${request.url}');
      });
}

_Account get _owner => _Account(
      authored: <Map<String, Object?>>[
        _scoped('a1', 'Own work'),
        _scoped('a2', 'Draft work'),
      ],
      documented: <Map<String, Object?>>[
        _scoped('d1', 'Found mural', artistName: 'Bor'),
        _scoped('d2', 'Stencil by Cene', artistName: 'Cene'),
      ],
      records: <Map<String, Object?>>[
        _record('a1', 'Own work'),
        _record('a2', 'Draft work', isPublic: false),
        _record('d1', 'Found mural'),
      ],
      markers: <Map<String, Object?>>[
        _marker('m1', 'Corner stencil'),
        _marker('m2', 'Linked piece', artworkId: 'a1'),
      ],
    );

Future<PortfolioProvider> _pump(
  WidgetTester tester, {
  required _Backend backend,
  String wallet = 'wallet-1',
  Size size = const Size(1440, 1000),
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  PortfolioProvider? provider,
  bool settle = true,
}) async {
  final api = BackendApiService();
  api.setAuthTokenForTesting('test-token');
  api.setHttpClient(backend.client());
  final portfolio = provider ?? PortfolioProvider(api: api);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<PortfolioProvider>.value(
      value: portfolio,
      child: MaterialApp(
        locale: locale,
        themeMode: themeMode,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ArtistPortfolioScreen(
            walletAddress: wallet,
            onOpenEntry: (context, entry) async => _opened.add(entry),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return portfolio;
}

/// Card taps the screen handed to the spy instead of navigating.
final List<PortfolioEntry> _opened = <PortfolioEntry>[];

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ArtistPortfolioScreen)))!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _opened.clear();
  });

  group('classification and attribution', () {
    testWidgets(
        'authored and documented lists stay separate, with the documenter '
        'credited only as contributor', (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _owner,
      });
      await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      // Authored: the owner's own works only.
      expect(find.text('Own work'), findsOneWidget);
      expect(find.text('Found mural'), findsNothing);

      // Added public art: documented artworks plus the owner's marker-only
      // contribution, and never the artwork-backed marker.
      await tester.tap(find.text(l10n.artistPortfolioSectionLabelWithCount(
        l10n.artistPortfolioSectionPublicArt,
        3,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Own work'), findsNothing);
      expect(find.text('Found mural'), findsOneWidget);
      expect(find.text('Stencil by Cene'), findsOneWidget);
      expect(find.text('Corner stencil'), findsOneWidget);
      expect(find.text('Linked piece'), findsNothing);
      // The artist is credited by name; the owner appears as the contributor.
      expect(find.text('By Bor'), findsOneWidget);
      expect(find.text('By Cene'), findsOneWidget);
      expect(find.text(l10n.artistPortfolioAddedByYou), findsNWidgets(3));
      // Documented art carries no management control, even where the owner's
      // full record is loaded.
      expect(find.text(l10n.commonActions), findsNothing);
    });

    testWidgets(
        'an unhonoured scope shows an explicit notice and never a mixed list',
        (tester) async {
      final backend = _Backend(
        honour: false,
        accounts: <String, _Account>{'wallet-1': _owner},
      );
      await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      expect(
          find.text(l10n.artistPortfolioAuthoredUnsupported), findsOneWidget);
      expect(find.text('Own work'), findsNothing);
      expect(find.text('Found mural'), findsNothing);
      // With no verified count the chip carries its label only.
      expect(find.text(l10n.artistPortfolioSectionAuthored), findsOneWidget);

      await tester.tap(find.text(l10n.artistPortfolioSectionPublicArt));
      await tester.pumpAndSettle();
      expect(
          find.text(l10n.artistPortfolioPublicArtUnsupported), findsOneWidget);
      expect(find.text('Found mural'), findsNothing);
      // The owner's own marker contributions do not depend on the scope.
      expect(find.text('Corner stencil'), findsOneWidget);
    });
  });

  group('counts and pagination', () {
    testWidgets('chips show backend totals and load more appends the next page',
        (tester) async {
      final authored = <Map<String, Object?>>[
        for (var i = 0; i < 30; i++) _scoped('p$i', 'Piece $i'),
      ];
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _Account(
          authored: authored,
          records: <Map<String, Object?>>[
            for (var i = 0; i < 30; i++) _record('p$i', 'Piece $i'),
          ],
        ),
      });
      final provider = await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      expect(
        find.text(l10n.artistPortfolioSectionLabelWithCount(
          l10n.artistPortfolioSectionAuthored,
          30,
        )),
        findsOneWidget,
      );
      expect(provider.entriesFor(PortfolioStudioSection.authoredArtworks),
          hasLength(24));

      final more = find.text(
        l10n.artistPortfolioLoadMore,
        skipOffstage: false,
      );
      // Scroll the studio's own list down to the footer, as a reader would.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();

      expect(provider.entriesFor(PortfolioStudioSection.authoredArtworks),
          hasLength(30));
      expect(find.text(l10n.artistPortfolioLoadMore), findsNothing);
      final scopedRequests = backend.requests
          .where((r) => r.url.queryParameters['relationship'] == 'authored')
          .map((r) => r.url.queryParameters['offset'])
          .toList();
      expect(scopedRequests, <String?>['0', '24']);
    });

    testWidgets(
        'a filter that hides every loaded row keeps load more and does not '
        'claim the section is empty while pages remain', (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _Account(
          authored: <Map<String, Object?>>[
            for (var i = 0; i < 30; i++) _scoped('p$i', 'Piece $i'),
          ],
          records: <Map<String, Object?>>[
            for (var i = 0; i < 30; i++) _record('p$i', 'Piece $i'),
          ],
        ),
      });
      final provider = await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      // The first page holds only published rows, so a draft filter hides
      // every loaded row while the remaining pages may still hold matches.
      provider.setStatusFilter(PortfolioPublishState.draft);
      await tester.pumpAndSettle();

      expect(find.text('Piece 0'), findsNothing);
      expect(find.text(l10n.artistPortfolioLoadMore), findsOneWidget);
      expect(find.text(l10n.artistGalleryEmptyTitle), findsNothing);
    });

    testWidgets(
        'a filter that hides every row of a fully loaded section shows the '
        'empty state without load more', (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _Account(
          authored: <Map<String, Object?>>[
            _scoped('p0', 'Piece 0'),
            _scoped('p1', 'Piece 1'),
            _scoped('p2', 'Piece 2'),
          ],
          records: <Map<String, Object?>>[
            _record('p0', 'Piece 0'),
            _record('p1', 'Piece 1'),
            _record('p2', 'Piece 2'),
          ],
        ),
      });
      final provider = await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      provider.setStatusFilter(PortfolioPublishState.draft);
      await tester.pumpAndSettle();

      expect(find.text(l10n.artistGalleryEmptyTitle), findsOneWidget);
      expect(find.text(l10n.artistPortfolioLoadMore), findsNothing);
    });

    testWidgets(
        'public art count is the documented total plus marker-only '
        'contributions', (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _owner,
      });
      await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      expect(
        find.text(l10n.artistPortfolioSectionLabelWithCount(
          l10n.artistPortfolioSectionPublicArt,
          3,
        )),
        findsOneWidget,
      );
    });
  });

  group('ownership and drafts', () {
    testWidgets('the owner sees a private draft, requested with the owner auth',
        (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _owner,
      });
      await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      expect(find.text('Draft work'), findsOneWidget);
      expect(find.text(l10n.artistGalleryFilterDraft.toUpperCase()),
          findsOneWidget);
      final authoredRequest = backend.requests.firstWhere(
        (r) => r.url.queryParameters['relationship'] == 'authored',
      );
      expect(authoredRequest.headers['authorization'], isNotNull);
    });

    testWidgets('an authored entry without the owner record gets no management',
        (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _Account(
          authored: <Map<String, Object?>>[
            _scoped('a1', 'Own work'),
            _scoped('x9', 'Orphan record'),
          ],
          records: <Map<String, Object?>>[_record('a1', 'Own work')],
        ),
      });
      await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      expect(find.text('Orphan record'), findsOneWidget);
      // One actions control, for the one record the owner's data confirms.
      expect(find.text(l10n.commonActions), findsOneWidget);
    });
  });

  group('navigation and actions', () {
    testWidgets(
        'a card tap opens its artwork once; the actions control does not',
        (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _owner,
      });
      await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.commonActions).first);
      await tester.pumpAndSettle();
      expect(_opened, isEmpty);
      expect(find.byType(KubusAlertDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Own work'));
      await tester.pumpAndSettle();
      expect(_opened.map((entry) => entry.id), <String>['a1']);
    });

    testWidgets('on a phone the actions open the unchanged bottom sheet',
        (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _owner,
      });
      await _pump(tester, backend: backend, size: const Size(390, 844));
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.commonActions).first);
      await tester.pumpAndSettle();

      expect(find.byType(KubusAlertDialog), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.text(l10n.commonEdit), findsOneWidget);
    });

    testWidgets(
        'on desktop the actions open a centered dialog that stays on '
        'the studio', (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _owner,
      });
      await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.commonActions).first);
      await tester.pumpAndSettle();

      expect(find.byType(KubusAlertDialog), findsOneWidget);
      expect(find.text(l10n.commonEdit), findsOneWidget);
      expect(find.text(l10n.commonDelete), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(KubusAlertDialog), findsNothing);
      expect(find.byType(ArtistPortfolioScreen), findsOneWidget);
    });

    testWidgets('the selected section survives the studio being rebuilt (Back)',
        (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _owner,
      });
      final provider = await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.artistPortfolioSectionLabelWithCount(
        l10n.artistPortfolioSectionPublicArt,
        3,
      )));
      await tester.pumpAndSettle();

      // Opening a detail on desktop replaces the studio; rebuilding it is the
      // Back path.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        ChangeNotifierProvider<PortfolioProvider>.value(
          value: provider,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ArtistPortfolioScreen(walletAddress: 'wallet-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.section, PortfolioStudioSection.publicArt);
      expect(find.text('Found mural'), findsOneWidget);
    });

    testWidgets('collections and exhibitions keep their cards and type filter',
        (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _Account(
          authored: <Map<String, Object?>>[_scoped('a1', 'Own work')],
          records: <Map<String, Object?>>[_record('a1', 'Own work')],
          collections: <Map<String, Object?>>[
            <String, Object?>{
              'id': 'c1',
              'name': 'Coll one',
              'walletAddress': 'wallet-1',
              'isPublic': true,
              'createdAt': _createdAt,
            },
          ],
        ),
      });
      await _pump(tester, backend: backend);
      final l10n = _l10n(tester);

      // The artwork section has only the status filter.
      expect(find.byWidgetPredicate((widget) => widget is DropdownButton),
          findsNWidgets(1));

      await tester.tap(find.text(l10n.artistPortfolioSectionLabelWithCount(
        l10n.artistPortfolioSectionCollections,
        1,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Coll one'), findsOneWidget);
      expect(find.text('Own work'), findsNothing);
      // The collections section adds the type filter alongside status.
      expect(find.byWidgetPredicate((widget) => widget is DropdownButton),
          findsNWidgets(2));
    });
  });

  group('account switching', () {
    testWidgets('a late response for the previous account is discarded',
        (tester) async {
      final backend = _Backend(
        accounts: <String, _Account>{
          'wallet-1': _Account(
            authored: <Map<String, Object?>>[_scoped('a1', 'Old account work')],
            records: <Map<String, Object?>>[_record('a1', 'Old account work')],
          ),
          'wallet-2': _Account(
            authored: <Map<String, Object?>>[_scoped('b1', 'New account work')],
            records: <Map<String, Object?>>[_record('b1', 'New account work')],
          ),
        },
      );
      final gate = Completer<void>();
      backend.gates['wallet-1'] = gate;

      // Wallet one's scoped reads stay in flight; do not wait for the settle.
      final provider = await _pump(tester, backend: backend, settle: false);
      backend.signedIn = 'wallet-2';
      provider.setWalletAddress('wallet-2');
      await tester.pumpAndSettle();

      expect(find.text('New account work'), findsOneWidget);
      expect(find.text('Old account work'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Old account work'), findsNothing);
      expect(find.text('New account work'), findsOneWidget);
    });
  });

  group('localization, theme and text scale', () {
    testWidgets('Slovene section labels render', (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _owner,
      });
      await _pump(tester, backend: backend, locale: const Locale('sl'));

      expect(find.textContaining('Avtorska dela'), findsOneWidget);
      expect(find.textContaining('Dodana javna umetnost'), findsOneWidget);
      expect(find.text('Dejanja'), findsWidgets);
    });

    testWidgets('dark theme and 150% text scale lay out without errors',
        (tester) async {
      final backend = _Backend(accounts: <String, _Account>{
        'wallet-1': _owner,
      });
      await _pump(
        tester,
        backend: backend,
        size: const Size(1280, 900),
        themeMode: ThemeMode.dark,
        textScale: 1.5,
      );
      final l10n = _l10n(tester);

      expect(find.text(l10n.commonActions), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
