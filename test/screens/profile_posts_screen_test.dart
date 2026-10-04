import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/community_interactions_provider.dart';
import 'package:art_kubus/providers/community_subject_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/community/profile_posts_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

http.Response _json(Object payload) => http.Response(
      jsonEncode(payload),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );

Map<String, Object?> _postPayload(int index) => <String, Object?>{
      'id': '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
      'content': 'History post number $index',
      'createdAt': '2026-06-14T12:00:00.000Z',
      'author': <String, Object?>{
        'userId': '55555555-5555-4555-8555-555555555555',
        'walletAddress': ProfileFixtures.wallet,
        'displayName': 'Ana Kovac',
        'username': 'ana',
        'avatarUrl': null,
        'roles': <String, bool>{'artist': false, 'institution': false},
      },
      'stats': <String, int>{
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'views': 0,
      },
    };

/// Page 1 is a full page (so more are expected); [failSecondPage] makes page 2
/// fail with a server error.
void _mockHistory({bool failSecondPage = false, List<int>? pagesAsked}) {
  BackendApiService().setHttpClient(MockClient((request) async {
    if (request.url.path == '/api/community/posts') {
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      pagesAsked?.add(page);
      if (page == 1) {
        return _json(<String, Object?>{
          'data': List<Object?>.generate(20, (i) => _postPayload(i + 1)),
        });
      }
      if (failSecondPage) return http.Response('boom', 500);
      return _json(<String, Object?>{
        'data': <Object?>[_postPayload(21)],
      });
    }
    return http.Response('{}', 400);
  }));
}

Future<void> _pumpPostsScreen(
  WidgetTester tester, {
  required bool embedded,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final screen = ProfilePostsScreen(
    userId: ProfileFixtures.wallet,
    displayName: 'Ana Kovac',
    initialCriticalPackage: ProfileFixtures.critical(),
    embedded: embedded,
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SavedItemsProvider>(
            create: (_) => SavedItemsProvider()),
        ChangeNotifierProvider<CommunityInteractionsProvider>(
            create: (_) => CommunityInteractionsProvider()),
        ChangeNotifierProvider<CommunitySubjectProvider>(
            create: (_) => CommunitySubjectProvider()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ProfilePackageService.clearMemoryCacheForTesting();
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  testWidgets('a failed later page keeps the posts and offers Retry',
      (tester) async {
    final pages = <int>[];
    _mockHistory(failSecondPage: true, pagesAsked: pages);
    await _pumpPostsScreen(tester, embedded: false);

    expect(find.textContaining('History post number 1'), findsWidgets);

    // Scroll to the foot to trigger page 2.
    await tester.drag(find.byType(ListView), const Offset(0, -20000));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.drag(find.byType(ListView), const Offset(0, -20000));
    await tester.pump();

    expect(pages, contains(2));
    expect(find.text('Failed to load more posts.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // The posts that were already loaded stay on screen.
    expect(find.textContaining('History post number 20'), findsOneWidget);
    // This is the compact footer, not the full initial error state.
    expect(find.byIcon(Icons.cloud_off), findsNothing);

    // Retry asks for page 2 again (and only page 2), and succeeds.
    pages.clear();
    _mockHistory(pagesAsked: pages);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(pages, <int>[2]);
    expect(find.text('Failed to load more posts.'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -20000));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('History post number 21'), findsOneWidget);
  });

  testWidgets(
      'View all posts in the desktop shell: one title, one Back, shell pop',
      (tester) async {
    _mockHistory();
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.desktopPublicInShellStack,
      size: const Size(1440, 900),
      posts: ProfileFixtures.posts(),
    );

    final viewAll = find.text('View all posts');
    await tester.ensureVisible(viewAll);
    await tester.pump();
    await tester.tap(viewAll);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DesktopSubScreen), findsOneWidget);
    expect(find.byType(AppBar), findsNothing,
        reason: 'the list must not add a second app bar');
    expect(find.text('Posts'), findsOneWidget, reason: 'exactly one title');
    expect(find.byIcon(Icons.arrow_back), findsOneWidget,
        reason: 'exactly one Back affordance');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DesktopSubScreen), findsNothing);
    expect(find.text('View all posts'), findsOneWidget,
        reason: 'back on the profile, via the shell');
    expectNoUnexpectedRenderErrors();

    // The profile opens a socket in initState; stop it and let the auth and
    // reconnect timers run out so no timer outlives the test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 7));
    SocketService().disconnect();
    await tester.pump(const Duration(seconds: 21));

  });

  testWidgets('standalone screen keeps its own app bar', (tester) async {
    _mockHistory();
    await _pumpPostsScreen(tester, embedded: false);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
