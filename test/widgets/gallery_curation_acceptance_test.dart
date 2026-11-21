import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/gallery_presentation.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/detail/gallery_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _host = '11111111-1111-4111-8111-111111111111';
const _a = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _b = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _c = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _titles = {
  _a: 'Work A with an intentionally long title for a narrow phone screen',
  _b: 'Work B',
  _c: 'Work C',
};
// Newest first is the host's automatic order: A, B, C.
const _created = {
  _a: '2026-03-01T10:00:00.000Z',
  _b: '2026-02-01T10:00:00.000Z',
  _c: '2026-01-01T10:00:00.000Z',
};
const _token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

http.Response _json(Map<String, Object?> data, [int status = 200]) =>
    http.Response(jsonEncode(data), status, headers: {
      'content-type': 'application/json',
      'cache-control': 'private, no-store',
    });

GalleryLayout _layout(List<String> order,
        {GalleryMode mode = GalleryMode.wall}) =>
    GalleryLayout(
      mode: mode,
      artworkOrder: order,
      artworkSizes: const {},
      leadArtworkId: null,
      sectionOrder: const ['identity', 'stats', 'work', 'publicArt'],
      hiddenSections: const [],
    );

/// A stateful stand-in for the gallery routes of one profile host.
class _Server {
  _Server({this.canPublish = true});

  // The draft and the publication both carry the custom order C, A, B.
  GalleryLayout? draftLayout = _layout(const [_c, _a, _b]);
  List<String> items = [_c, _a, _b];
  bool canPublish;
  final bool publishedCustom = true;
  int revision = 4;
  int publishedRevision = 3;
  bool failPublic = false;
  bool failDraft = false;
  int saves = 0;
  int publishes = 0;

  GalleryLayout get _default => _layout(const []);

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/gallery/draft') && request.method == 'GET') {
      if (failDraft) return _json({'success': false}, 503);
      return _json({
        'success': true,
        'data': {
          'revision': revision,
          'publishedRevision': publishedRevision,
          'draft': draftLayout?.toJson(),
          'defaultLayout': _default.toJson(),
          'canPublish': canPublish,
          'items': [
            for (final id in items) {'type': 'artwork', 'id': id}
          ],
          'unavailableArtworkIds': <String>[],
        },
      });
    }
    if (path.endsWith('/gallery/draft') && request.method == 'PUT') {
      saves++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final layout = body['layout'] as Map<String, dynamic>?;
      draftLayout = layout == null ? null : GalleryLayout.fromJson(layout);
      items = draftLayout == null
          ? [_a, _b, _c]
          : draftLayout!.artworkOrder.where(items.contains).toList();
      revision++;
      return _json({
        'success': true,
        'data': {'revision': revision},
      });
    }
    if (path.endsWith('/gallery/publish')) {
      publishes++;
      revision++;
      publishedRevision = revision;
      return _json({
        'success': true,
        'data': {'revision': revision},
      });
    }
    if (path.endsWith('/gallery')) {
      if (failPublic) return _json({'success': false}, 429);
      final layout = publishedCustom ? _layout([_c, _a, _b]) : _default;
      return _json({
        'success': true,
        'data': {
          'source': 'postgresql',
          'publishedRevision': publishedRevision,
          'automatic': !publishedCustom,
          'layout': layout.toJson(),
          'items': [
            for (final id in publishedCustom ? [_c, _a, _b] : [_a, _b, _c])
              {'type': 'artwork', 'id': id}
          ],
        },
      });
    }
    final id = request.url.pathSegments.last;
    if (_titles.containsKey(id)) {
      return _json({
        'success': true,
        'source': 'postgresql',
        'mode': 'current-media',
        'current': true,
        'publicMediaAllowed': true,
        'data': {
          'id': id,
          'title': _titles[id],
          'artist': 'Synthetic artist',
          'description': 'Documentation.',
          'createdAt': _created[id],
          'latitude': 46.0,
          'longitude': 14.0,
        },
      });
    }
    return _json({'success': false}, 404);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;

  setUp(() {
    api = BackendApiService();
    SharedPreferences.setMockInitialValues({});
    api.setAuthTokenForTesting(_token);
  });
  tearDown(() {
    api.setAuthTokenForTesting(null);
    api.setHttpClient(http.Client());
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    _Server server, {
    Size size = const Size(412, 2600),
    double textScale = 1,
    Locale locale = const Locale('en'),
  }) async {
    api.setHttpClient(MockClient(server.handle));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<WalletProvider>(
        create: (_) => WalletProvider(deferInit: true),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GalleryHostScope(
                type: GalleryHostType.profile,
                hostId: _host,
                builder: (_) =>
                    const GalleryPanel(fallback: Text('Legacy work')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(
        locale.languageCode == 'sl' ? 'Uredi galerijo' : 'Curate gallery'));
    await tester.pumpAndSettle();
  }

  IconButton moveButton(WidgetTester tester, String tooltip, int index) =>
      tester.widget<IconButton>(find.ancestor(
        of: find.byTooltip(tooltip).at(index),
        matching: find.byType(IconButton),
      ));

  // The artwork-order rows, in order, by the first words of their title.
  List<String> artworkRowTitles(WidgetTester tester) {
    final list = find.byType(ReorderableListView).first;
    final titles = <MapEntry<double, String>>[];
    for (final entry in {'Work A': 'A', 'Work B': 'B', 'Work C': 'C'}.entries) {
      final match = find.descendant(
        of: list,
        matching: find.textContaining(entry.key),
      );
      if (match.evaluate().isNotEmpty) {
        titles.add(MapEntry(tester.getTopLeft(match.first).dy, entry.value));
      }
    }
    titles.sort((x, y) => x.key.compareTo(y.key));
    return titles.map((entry) => entry.value).toList();
  }

  group('D1 publish control for a role that cannot publish', () {
    testWidgets('explains instead of showing a dead Publish button',
        (tester) async {
      await pumpEditor(tester, _Server(canPublish: false));
      expect(find.text('Publish gallery'), findsNothing);
      expect(find.text('You can edit this gallery but not publish it.'),
          findsOneWidget);
      expect(find.text('Save draft'), findsOneWidget);
    });

    testWidgets('a publisher keeps the button and no explanation',
        (tester) async {
      await pumpEditor(tester, _Server());
      expect(find.text('Publish gallery'), findsOneWidget);
      expect(find.text('You can edit this gallery but not publish it.'),
          findsNothing);
    });

    testWidgets('the explanation is localized', (tester) async {
      await pumpEditor(tester, _Server(canPublish: false),
          locale: const Locale('sl'));
      expect(find.text('Galerijo lahko urejate, vendar je ne morete objaviti.'),
          findsOneWidget);
    });
  });

  group('D2 a failed refresh after a saved write', () {
    testWidgets('keeps the saved draft and offers a soft retry',
        (tester) async {
      final server = _Server();
      await pumpEditor(tester, server);
      await tester.tap(find.byTooltip('Move later').first);
      await tester.pumpAndSettle();
      // The public read starts failing right after the write is accepted.
      server.failPublic = true;
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      expect(server.saves, 1);
      expect(find.text('Gallery unavailable.'), findsNothing);
      expect(
        find.text('Your change was saved, but the gallery could not be '
            'refreshed.'),
        findsOneWidget,
      );
      // The saved order is still on screen.
      expect(artworkRowTitles(tester), ['A', 'C', 'B']);

      server.failPublic = false;
      await tester.tap(find.text('Reload gallery'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your change was saved, but the gallery could not be '
            'refreshed.'),
        findsNothing,
      );
      expect(find.text('Unpublished draft'), findsOneWidget);
      expect(artworkRowTitles(tester), ['A', 'C', 'B']);
    });

    testWidgets('a failed draft read holds the controls until it is retried',
        (tester) async {
      final server = _Server();
      await pumpEditor(tester, server);
      await tester.tap(find.byTooltip('Move later').first);
      await tester.pumpAndSettle();
      server.failDraft = true;
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      expect(find.text('Gallery unavailable.'), findsNothing);
      expect(find.textContaining('could not be refreshed'), findsOneWidget);
      // The revision on screen is behind the server's: no edit may start.
      expect(moveButton(tester, 'Move later', 0).onPressed, isNull);
      expect(artworkRowTitles(tester), ['A', 'C', 'B']);

      server.failDraft = false;
      await tester.tap(find.text('Reload gallery'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be refreshed'), findsNothing);
      expect(moveButton(tester, 'Move later', 0).onPressed, isNotNull);
    });
  });

  group('D3 reorder rows stay on one line', () {
    final cases = [
      (const Size(320, 2600), 1.0),
      (const Size(393, 2600), 1.0),
      (const Size(412, 2600), 1.0),
      (const Size(320, 3600), 2.0),
      (const Size(393, 3600), 2.0),
      (const Size(412, 3600), 2.0),
    ];
    for (final (size, scale) in cases) {
      testWidgets('${size.width.toInt()} px at text scale $scale',
          (tester) async {
        await pumpEditor(tester, _Server(), size: size, textScale: scale);
        final first = tester.takeException();
        expect(first, isNull, reason: '$first');

        // Every artwork row: earlier, later and the overflow menu share a line.
        final earlier = find.byTooltip('Move earlier');
        final later = find.byTooltip('Move later');
        final menu = find.byTooltip('Artwork size and placement');
        expect(menu, findsNWidgets(3));
        for (var row = 0; row < 3; row++) {
          final y = tester.getCenter(earlier.at(row)).dy;
          expect(tester.getCenter(later.at(row)).dy, y, reason: 'row $row');
          expect(tester.getCenter(menu.at(row)).dy, y, reason: 'row $row');
          // The controls stay inside the dialog.
          expect(tester.getRect(menu.at(row)).right,
              lessThanOrEqualTo(size.width));
        }
        // Section rows (identity is fixed, the rest are movable): the move
        // controls of one row share a line, and the checkbox row too.
        final sectionBase = 3;
        for (var row = 1; row < 4; row++) {
          expect(
            tester.getCenter(earlier.at(sectionBase + row)).dy,
            tester.getCenter(later.at(sectionBase + row)).dy,
            reason: 'section row $row',
          );
        }
        final checkboxes = find.byType(Checkbox);
        for (var row = 0; row < checkboxes.evaluate().length; row++) {
          final box = tester.getCenter(checkboxes.at(row)).dy;
          final owner =
              find.ancestor(of: checkboxes.at(row), matching: find.byType(Row));
          expect(
            tester
                .getCenter(find.descendant(
                    of: owner.first, matching: find.byIcon(Icons.drag_handle)))
                .dy,
            box,
            reason: 'checkbox $row',
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('D5 keyboard move keeps focus and announces the position', () {
    testWidgets('Move later twice, then focus falls to Move earlier',
        (tester) async {
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        (message) async {
          if (message is Map && message['type'] == 'announce') {
            announced.add((message['data'] as Map)['message'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility, null));

      await pumpEditor(tester, _Server());
      // Order on screen is C, A, B. Focus Move later on the first row.
      moveButton(tester, 'Move later', 0).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(artworkRowTitles(tester), ['A', 'C', 'B']);
      expect(announced.last, 'Moved to position 2 of 3');
      // Focus is on the same control of the moved row (now second), not body.
      expect(moveButton(tester, 'Move later', 1).focusNode!.hasPrimaryFocus,
          isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(artworkRowTitles(tester), ['A', 'B', 'C']);
      expect(announced.last, 'Moved to position 3 of 3');
      // The row is last, so Move later is disabled: focus goes to the other
      // move control of the same row instead of dropping to the body.
      expect(moveButton(tester, 'Move later', 2).onPressed, isNull);
      expect(moveButton(tester, 'Move earlier', 2).focusNode!.hasPrimaryFocus,
          isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(announced.last, 'Moved to position 2 of 3');
      expect(moveButton(tester, 'Move earlier', 1).focusNode!.hasPrimaryFocus,
          isTrue);
    });
  });

  group('D5 focus is re-asserted on the rebuilt control', () {
    // A move rebuilds the row's semantics node. On the web the browser drops
    // DOM focus when that node is re-parented, and the engine only restores it
    // when the node's focused flag changes. So the flag has to go false and
    // then true again after a move; a no-op requestFocus on a control that
    // already has focus leaves the browser's focus on <body>.
    testWidgets('focus leaves and returns so the semantics flag changes',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(tester, _Server());
      final later = moveButton(tester, 'Move later', 0).focusNode!;
      later.requestFocus();
      await tester.pump();

      final seen = <bool>[];
      void record() => seen.add(later.hasPrimaryFocus);
      later.addListener(record);
      addTearDown(() => later.removeListener(record));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(artworkRowTitles(tester), ['A', 'C', 'B']);
      // Out, then back in, across separate frames.
      expect(seen, containsAllInOrder([false, true]), reason: '$seen');
      expect(later.hasPrimaryFocus, isTrue);

      // The moved row's control reports focus in the semantics tree.
      final node = tester.getSemantics(find.byTooltip('Move later').at(1));
      expect(node.flagsCollection.isFocused, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets(
        'every keyboard move ends with focus on a move control of the '
        'moved row', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(tester, _Server());
      moveButton(tester, 'Move later', 0).focusNode!.requestFocus();
      await tester.pump();
      for (var step = 0; step < 4; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        final focused = FocusManager.instance.primaryFocus;
        expect(focused, isNotNull);
        expect(focused!.debugLabel, startsWith('gallery move'),
            reason: 'step $step left focus on ${focused.debugLabel}');
      }
      handle.dispose();
    });
  });

  group('D6 reset to automatic', () {
    testWidgets('shows the automatic order at once and sends nothing',
        (tester) async {
      final server = _Server();
      await pumpEditor(tester, server);
      expect(artworkRowTitles(tester), ['C', 'A', 'B']);

      await tester.tap(find.text('Reset to automatic'));
      await tester.pumpAndSettle();

      // Newest first: A, B, C. The preview grid follows the same order.
      expect(artworkRowTitles(tester), ['A', 'B', 'C']);
      final grid = find.byType(Wrap);
      expect(grid, findsWidgets);
      expect(find.text('Unsaved changes'), findsOneWidget);
      // Nothing is saved or published by the reset itself.
      expect(server.saves, 0);
      expect(server.publishes, 0);
      expect(server.draftLayout, isNotNull);
      expect(
          tester
              .widget<OutlinedButton>(find.ancestor(
                of: find.text('Save draft'),
                matching: find.byType(OutlinedButton),
              ))
              .onPressed,
          isNotNull);
      expect(
          tester
              .widget<FilledButton>(find.ancestor(
                of: find.text('Publish gallery'),
                matching: find.byType(FilledButton),
              ))
              .onPressed,
          isNull);

      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(server.saves, 1);
      expect(server.draftLayout, isNull);
      expect(artworkRowTitles(tester), ['A', 'B', 'C']);
    });
  });
}
