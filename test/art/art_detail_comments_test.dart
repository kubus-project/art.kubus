import 'dart:convert';
import 'dart:io';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/art/art_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestApiServer {
  _TestApiServer();

  HttpServer? _server;
  final Map<String, List<Map<String, dynamic>>> _commentsByArtwork = {};
  int _nextCommentId = 1;
  int _views = 0;

  Future<void> start() async {
    _server ??= await HttpServer.bind(
      InternetAddress.loopbackIPv6,
      3000,
      v6Only: false,
    );
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void reset() {
    _commentsByArtwork.clear();
    _nextCommentId = 1;
    _views = 0;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final segments = request.uri.pathSegments;

    try {
      if (path == '/api/profiles/issue-token' && request.method == 'POST') {
        return _json(request, 200, {'success': true, 'token': 'test-token'});
      }

      if (segments.length >= 4 &&
          segments[0] == 'api' &&
          segments[1] == 'artworks' &&
          segments[3] == 'view' &&
          request.method == 'POST') {
        _views += 1;
        return _json(request, 200, {'success': true, 'data': {'viewsCount': _views}});
      }

      if (segments.length >= 4 &&
          segments[0] == 'api' &&
          segments[1] == 'artworks' &&
          segments[3] == 'comments') {
        final artworkId = segments[2];

        if (request.method == 'GET') {
          final list = _commentsByArtwork[artworkId] ?? <Map<String, dynamic>>[];
          return _json(request, 200, {'success': true, 'count': list.length, 'data': list});
        }

        if (request.method == 'POST') {
          final auth = request.headers.value('authorization') ?? '';
          if (auth.trim().isEmpty) {
            return _json(request, 401, {'success': false, 'error': 'Unauthorized'});
          }

          final body = await utf8.decoder.bind(request).join();
          final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body) as Map<String, dynamic>;
          final content = (decoded['content'] ?? '').toString().trim();
          if (content.isEmpty) {
            return _json(request, 400, {'success': false, 'error': 'Content is required'});
          }

          final now = DateTime.now().toUtc();
          final comment = <String, dynamic>{
            'id': 'comment_${_nextCommentId++}',
            'artworkId': artworkId,
            'userId': 'test_user',
            'userName': 'Test User',
            'userAvatarUrl': 'placeholder://test_user',
            'content': content,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
            'likesCount': 0,
            'isLikedByCurrentUser': false,
            'isEdited': false,
            'parentCommentId': null,
            'replies': <dynamic>[],
          };

          final existing = _commentsByArtwork[artworkId] ?? <Map<String, dynamic>>[];
          _commentsByArtwork[artworkId] = [...existing, comment];
          return _json(request, 201, {'success': true, 'data': comment});
        }
      }

      if (segments.length >= 5 &&
          segments[0] == 'api' &&
          segments[1] == 'collab' &&
          segments[2] == 'artwork' &&
          segments[4] == 'members' &&
          request.method == 'GET') {
        return _json(request, 200, {'success': true, 'data': {'members': []}});
      }
    } catch (_) {
      // fall through to 500
    }

    return _json(request, 404, {'success': false, 'error': 'Not found'});
  }

  Future<void> _json(HttpRequest request, int status, Map<String, dynamic> payload) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final server = _TestApiServer();

  setUpAll(() async {
    await server.start();
  });

  tearDownAll(() async {
    await server.stop();
  });

  setUp(() async {
    server.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    required ArtworkProvider artworkProvider,
    required ProfileProvider profileProvider,
    required WalletProvider walletProvider,
    required CollabProvider collabProvider,
    required String artworkId,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: artworkProvider),
          ChangeNotifierProvider.value(value: profileProvider),
          ChangeNotifierProvider.value(value: walletProvider),
          ChangeNotifierProvider.value(value: collabProvider),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ArtDetailScreen(artworkId: artworkId),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    final scrollView = find.byType(CustomScrollView);
    for (var i = 0; i < 30 && scrollView.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(scrollView, findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
  }

  String describeFinder(Finder finder) {
    try {
      // `Finder.description` is deprecated; use describeMatch for clearer output.
      final base = finder as FinderBase;
      final count = finder.evaluate().length;
      final plurality = switch (count) {
        0 => Plurality.zero,
        1 => Plurality.one,
        _ => Plurality.many,
      };
      return base.describeMatch(plurality);
    } catch (_) {
      return finder.toString();
    }
  }

  Future<void> scrollDownUntilFound(WidgetTester tester, Finder finder) async {
    final scrollView = find
        .descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
        .first;
    var scrollPixels = tester.state<ScrollableState>(scrollView).position.pixels;
    var maxScrollExtent = tester.state<ScrollableState>(scrollView).position.maxScrollExtent;
    for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
      await tester.drag(scrollView, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 350));
      scrollPixels = tester.state<ScrollableState>(scrollView).position.pixels;
      maxScrollExtent = tester.state<ScrollableState>(scrollView).position.maxScrollExtent;
    }
    if (finder.evaluate().isNotEmpty) {
      expect(finder, findsOneWidget);
      return;
    }

    final sampleTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .take(35)
        .toList();

    throw TestFailure(
      'Could not find ${describeFinder(finder)} after scrolling (pixels=$scrollPixels, max=$maxScrollExtent). '
      'Sample texts: ${sampleTexts.join(' | ')}',
    );
  }

  testWidgets('Guest sees sign-in prompt and no comment FAB', (tester) async {
    final artworkProvider = ArtworkProvider();
    const artworkId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
    artworkProvider.addOrUpdateArtwork(
      Artwork(
        id: artworkId,
        title: 'Test Artwork',
        artist: 'Artist',
        description: 'Desc',
        position: const LatLng(0, 0),
        rarity: ArtworkRarity.common,
        rewards: 0,
        createdAt: DateTime.now(),
      ),
    );

    final profileProvider = ProfileProvider(); // default isSignedIn=false
    final walletProvider = WalletProvider(deferInit: true);
    final collabProvider = CollabProvider();

    await pumpDetail(
      tester,
      artworkProvider: artworkProvider,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
      collabProvider: collabProvider,
      artworkId: artworkId,
    );

    final commentsToggle = find.byIcon(Icons.comment_outlined);
    await scrollDownUntilFound(tester, commentsToggle);
    await tester.tap(commentsToggle);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    await scrollDownUntilFound(tester, find.text('Sign in to comment'));
    expect(find.text('Sign in to comment'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Signed-in user can add an artwork comment and see it rendered', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': 'test-token',
      'wallet_address': 'wallet_test',
    });

    final artworkProvider = ArtworkProvider();
    const artworkId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    artworkProvider.addOrUpdateArtwork(
      Artwork(
        id: artworkId,
        title: 'Test Artwork',
        artist: 'Artist',
        description: 'Desc',
        position: const LatLng(0, 0),
        rarity: ArtworkRarity.common,
        rewards: 0,
        createdAt: DateTime.now(),
      ),
    );

    final profileProvider = ProfileProvider()..initializeSampleData();
    final walletProvider = WalletProvider(deferInit: true)
      ..setCurrentWalletAddressForTesting(profileProvider.currentUser?.walletAddress);
    final collabProvider = CollabProvider();

    await pumpDetail(
      tester,
      artworkProvider: artworkProvider,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
      collabProvider: collabProvider,
      artworkId: artworkId,
    );

    final commentsToggle = find.byIcon(Icons.comment_outlined);
  await scrollDownUntilFound(tester, commentsToggle);
    await tester.tap(commentsToggle);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

  await scrollDownUntilFound(tester, find.text('Comments (0)'));
    expect(find.text('Comments (0)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Comment'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    final commentField = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
    expect(commentField, findsOneWidget);
    await tester.enterText(commentField, 'Hello from test');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Post Comment'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Comments (1)'), findsOneWidget);
    expect(find.text('Hello from test'), findsOneWidget);
  });
}
