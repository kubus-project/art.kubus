import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/conversation.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/community_comments_provider.dart';
import 'package:art_kubus/screens/activity/saved_items_screen.dart';
import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:art_kubus/screens/community/conversation_screen.dart';
import 'package:art_kubus/screens/community/messages_screen.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_artist_studio_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_governance_hub_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_marketplace_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_wallet_screen.dart';
import 'package:art_kubus/screens/web3/achievements/achievements_page.dart';
import 'package:art_kubus/screens/web3/artist/artist_studio.dart';
import 'package:art_kubus/screens/web3/dao/governance_hub.dart';
import 'package:art_kubus/screens/web3/institution/institution_hub.dart';
import 'package:art_kubus/screens/web3/marketplace/marketplace.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_home.dart';
import 'package:art_kubus/services/search_service.dart';
import 'package:art_kubus/widgets/search/kubus_general_search.dart';
import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_controller.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/profile_fixtures.dart';
import '../support/qa_font_loader.dart';

/// Wave 4B PRODUCT v5 visual matrix.
///
/// Renders the real 4B surfaces (search, profiles, saved, post detail,
/// messages, auth, studio, institution tools, wallet, marketplace,
/// achievements, DAO) against deterministic fixtures with the bundled Sofia
/// Sans / Space Mono fonts and writes PNGs plus `report.json` to
/// `output/qa/product-v5-wave4b/<QA_LABEL>/`. There is no network in
/// `flutter test`; remote loads settle into each screen's own offline or empty
/// state, which is part of what this matrix reviews. Render errors are
/// recorded per capture instead of aborting the run.
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_wave4b_visual_matrix_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
    test('visual QA matrix is opt-in', () {},
        skip: 'Set KUBUS_RUN_VISUAL_QA=1 to generate screenshot evidence.');
    return;
  }

  final label = Platform.environment['QA_LABEL'] ?? 'after';
  final outputDir = Directory('output/qa/product-v5-wave4b/$label');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    outputDir.createSync(recursive: true);
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  tearDownAll(() {
    File('${outputDir.path}/report.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'label': label,
        'commit': _git(['rev-parse', 'HEAD']),
        'treeDirty': _git(['status', '--porcelain']).isNotEmpty,
        'fontFamiliesLoaded': QaFontLoader.loadedFamilies,
        'captureCount': captures.length,
        'captures': captures,
      }),
    );
  });

  Future<void> record(
    WidgetTester tester,
    String name, {
    required Size size,
    required Brightness brightness,
    required Locale locale,
    required List<String> errors,
    double textScale = 1,
  }) async {
    final bytes = await _captureRoot(tester);
    File('${outputDir.path}/$name.png').writeAsBytesSync(bytes);
    captures.add(<String, Object?>{
      'name': name,
      'file': '$name.png',
      'width': size.width,
      'height': size.height,
      'locale': locale.languageCode,
      'brightness': brightness.name,
      'textScale': textScale,
      'renderErrors': errors.toSet().toList(),
    });
  }

  Future<void> surface(
    WidgetTester tester,
    String name,
    Widget Function() build, {
    Size size = _mobile,
    Brightness brightness = Brightness.light,
    Locale locale = const Locale('en'),
    double textScale = 1,
    UserProfile? signedIn,
    Future<void> Function(WidgetTester tester)? interact,
    List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
  }) async {
    final errors = await pumpProductSurface(
      tester,
      child: build(),
      extraProviders: extraProviders,
      size: size,
      brightness: brightness,
      locale: locale,
      textScale: textScale,
      signedInProfile: signedIn,
    );
    if (interact != null) {
      try {
        await interact(tester);
      } catch (error) {
        errors.add('interaction: $error');
      }
    }
    await record(tester, name,
        size: size,
        brightness: brightness,
        locale: locale,
        errors: errors,
        textScale: textScale);
  }

  // ---------------------------------------------------------------- search
  group('search', () {
    for (final v in _variants) {
      qaCase('search results ${v.name}', (tester) async {
        final controller = KubusSearchController(
          config: const KubusSearchConfig(
            scope: KubusSearchScope.home,
            debounceDuration: Duration.zero,
          ),
          searchService: _FixtureSearchService(_searchFixtures),
        );
        addTearDown(controller.dispose);
        await surface(
          tester,
          'search-results-${v.name}',
          () => _SearchPage(controller: controller),
          size: v.size,
          brightness: v.brightness,
          locale: v.locale,
          interact: (tester) async {
            await tester.tap(find.byType(TextField));
            await tester.pump();
            await tester.enterText(find.byType(TextField), 'mural');
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
          },
        );
      });
    }
    qaCase('search zero results', (tester) async {
      final controller = KubusSearchController(
        config: const KubusSearchConfig(
          scope: KubusSearchScope.home,
          debounceDuration: Duration.zero,
        ),
        searchService: _FixtureSearchService(const <KubusSearchResult>[]),
      );
      addTearDown(controller.dispose);
      await surface(
        tester,
        'search-empty-mobile-light-en',
        () => _SearchPage(controller: controller),
        interact: (tester) async {
          await tester.tap(find.byType(TextField));
          await tester.pump();
          await tester.enterText(find.byType(TextField), 'zzzz');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        },
      );
    });
  });

  // Profiles are captured by test/qa/profile_visual_matrix_test.dart, which
  // owns the profile fixtures and harness.

  // --------------------------------------------------------- personal/social
  final owner = UserProfile(
    id: ProfileFixtures.wallet,
    userId: ProfileFixtures.wallet,
    walletAddress: ProfileFixtures.wallet,
    username: 'ana_kovac',
    displayName: 'Ana Kovač',
    bio: 'Street muralist.',
    avatar: '',
    isArtist: true,
    createdAt: ProfileFixtures.fetchedAt,
    updatedAt: ProfileFixtures.fetchedAt,
  );

  final social = <String, Widget Function()>{
    'saved': () => const SavedItemsScreen(),
    'post-detail': () => PostDetailScreen(post: _postFixture()),
    'messages': () => const MessagesScreen(),
    'conversation': () => ConversationScreen(conversation: _conversation()),
  };
  for (final entry in social.entries) {
    for (final v in <_Variant>[_variants[0], _variants[1]]) {
      qaCase('${entry.key} ${v.name}', (tester) async {
        await surface(tester, '${entry.key}-${v.name}', entry.value,
            size: v.size,
            brightness: v.brightness,
            locale: v.locale,
            signedIn: owner,
            extraProviders: entry.key == 'post-detail'
                ? <SingleChildWidget>[
                    ChangeNotifierProvider<CommunityCommentsProvider>(
                      create: (_) => _FixtureCommentsProvider(
                        _postFixture().comments,
                      ),
                    ),
                  ]
                : const <SingleChildWidget>[]);
      });
    }
  }

  // ------------------------------------------------------------------ auth
  for (final v in <_Variant>[_variants[0], _variants[1], _variants[2]]) {
    qaCase('sign-in ${v.name}', (tester) async {
      await surface(tester, 'sign-in-${v.name}', () => const SignInScreen(),
          size: v.size, brightness: v.brightness, locale: v.locale);
    });
  }

  // -------------------------------------------------------------- advanced
  final advanced = <String, (Widget Function(), Widget Function())>{
    'artist-studio': (
      () => const ArtistStudio(),
      () => const DesktopArtistStudioScreen()
    ),
    'institution-hub': (
      () => const InstitutionHub(),
      () => const InstitutionHub()
    ),
    'wallet': (() => const WalletHome(), () => const DesktopWalletScreen()),
    'marketplace': (
      () => const Marketplace(),
      () => const DesktopMarketplaceScreen()
    ),
    'achievements': (
      () => const AchievementsPage(),
      () => const AchievementsPage()
    ),
    'dao': (
      () => const GovernanceHub(),
      () => const DesktopGovernanceHubScreen()
    ),
  };
  for (final entry in advanced.entries) {
    qaCase('${entry.key} mobile', (tester) async {
      await surface(tester, '${entry.key}-mobile-light-en', entry.value.$1,
          signedIn: owner);
    });
    qaCase('${entry.key} mobile dark', (tester) async {
      await surface(tester, '${entry.key}-mobile-dark-en', entry.value.$1,
          brightness: Brightness.dark, signedIn: owner);
    });
    qaCase('${entry.key} desktop', (tester) async {
      await surface(tester, '${entry.key}-desktop-light-en', entry.value.$2,
          size: _desktop, signedIn: owner);
    });
  }
}

/// Each capture gets a bounded budget: a surface that never settles is a
/// finding to record, not a reason to stall the whole matrix.
void qaCase(String description, WidgetTesterCallback callback) => testWidgets(
      description,
      callback,
      timeout: const Timeout(Duration(seconds: 120)),
    );

const Size _mobile = Size(390, 844);
const Size _desktop = Size(1440, 900);

class _Variant {
  const _Variant(this.name, this.size, this.brightness, this.locale);
  final String name;
  final Size size;
  final Brightness brightness;
  final Locale locale;
}

const List<_Variant> _variants = <_Variant>[
  _Variant('mobile-light-en', _mobile, Brightness.light, Locale('en')),
  _Variant('mobile-dark-sl', _mobile, Brightness.dark, Locale('sl')),
  _Variant('desktop-light-en', _desktop, Brightness.light, Locale('en')),
  _Variant('narrow-light-sl', Size(320, 700), Brightness.light, Locale('sl')),
];

class _FixtureSearchService extends SearchService {
  _FixtureSearchService(this.results);
  final List<KubusSearchResult> results;

  @override
  Future<List<KubusSearchResult>> fetchResults({
    required SearchContextSnapshot snapshot,
    required String query,
    required KubusSearchConfig config,
  }) async =>
      results;
}

const List<KubusSearchResult> _searchFixtures = <KubusSearchResult>[
  KubusSearchResult(
    label: 'Riverside mural',
    kind: KubusSearchResultKind.artwork,
    id: 'art-1',
    detail: 'Ana Kovač · Ljubljana',
  ),
  KubusSearchResult(
    label: 'Mural of the Metelkova courtyard walls',
    kind: KubusSearchResultKind.artwork,
    id: 'art-2',
    detail: 'Unknown artist · Metelkova, Ljubljana',
  ),
  KubusSearchResult(
    label: 'Ana Kovač',
    kind: KubusSearchResultKind.profile,
    id: 'user-1',
    detail: '@luminousmonoprint_a4f2',
  ),
  KubusSearchResult(
    label: 'Muzej sodobne umetnosti Metelkova',
    kind: KubusSearchResultKind.institution,
    id: 'inst-1',
    detail: 'Ljubljana',
  ),
  KubusSearchResult(
    label: 'Mural walk: Rog and Metelkova',
    kind: KubusSearchResultKind.event,
    id: 'event-1',
    detail: '12 Oct 2026',
  ),
  KubusSearchResult(
    label: 'Walls that speak',
    kind: KubusSearchResultKind.exhibition,
    id: 'exh-1',
    detail: 'Galerija Škuc',
  ),
  KubusSearchResult(
    label: 'New mural on Trubarjeva',
    kind: KubusSearchResultKind.post,
    id: 'post-1',
    detail: '@maja_walks',
  ),
];

class _SearchPage extends StatelessWidget {
  const _SearchPage({required this.controller});
  final KubusSearchController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Real screens host the overlay in a full-height stack.
            const SizedBox.expand(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: KubusGeneralSearch(
                controller: controller,
                hintText: 'Search artworks, artists, institutions…',
                semanticsLabel: 'qa_search_input',
              ),
            ),
            KubusSearchResultsOverlay(
              controller: controller,
              minCharsHint: 'Type at least 2 characters',
              noResultsText: 'No results for this search',
              onResultTap: (_) {},
              maxHeight: 700,
            ),
          ],
        ),
      ),
    );
  }
}

CommunityPost _postFixture() {
  return CommunityPost(
    id: 'post-qa-1',
    authorName: 'Maja Novak',
    authorUsername: 'maja_walks',
    authorWallet: ProfileFixtures.walletFallbackId,
    content:
        'Found this new mural on Trubarjeva today — the colours change with the light through the afternoon.',
    timestamp: DateTime.utc(2026, 9, 20, 15),
    likeCount: 24,
    commentCount: 3,
    shareCount: 2,
    tags: const <String>['mural', 'ljubljana'],
    comments: <Comment>[
      Comment(
        id: 'c1',
        authorName: 'Ana Kovač',
        authorId: ProfileFixtures.wallet,
        content: 'Thank you! It took three weekends.',
        timestamp: DateTime.utc(2026, 9, 20, 16),
        replies: <Comment>[
          Comment(
            id: 'c1r1',
            parentCommentId: 'c1',
            authorName: 'Maja Novak',
            authorId: ProfileFixtures.walletFallbackId,
            content: 'Worth every weekend.',
            timestamp: DateTime.utc(2026, 9, 20, 16, 30),
          ),
        ],
      ),
      Comment(
        id: 'c2',
        authorName: 'Luka',
        authorId: 'luka',
        content: 'Is it on the map yet?',
        timestamp: DateTime.utc(2026, 9, 20, 17),
      ),
    ],
  );
}

Conversation _conversation() {
  return Conversation(
    id: 'conv-qa-1',
    title: 'Maja Novak',
    lastMessageAt: DateTime.utc(2026, 9, 20, 18),
  );
}

Future<List<int>> _captureRoot(WidgetTester tester) async {
  final boundary = tester.binding.rootElement!.renderObject!;
  final layer = boundary.debugLayer! as OffsetLayer;
  late final List<int> bytes;
  await tester.runAsync(() async {
    final image = await layer.toImage(boundary.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

String _git(List<String> args) {
  try {
    final result = Process.runSync('git', args);
    return (result.stdout as String).trim();
  } catch (_) {
    return '';
  }
}

/// Serves the fixture thread without touching the backend.
class _FixtureCommentsProvider extends CommunityCommentsProvider {
  _FixtureCommentsProvider(this._fixture);

  final List<Comment> _fixture;

  int _count(List<Comment> list) =>
      list.fold(0, (sum, c) => sum + 1 + _count(c.replies));

  @override
  Future<void> loadComments(
    String postId, {
    bool force = false,
    int page = 1,
    int limit = 200,
  }) async {}

  @override
  bool hasLoadedComments(String postId) => true;

  @override
  bool isLoading(String postId) => false;

  @override
  List<Comment> commentsForPost(String postId) => List.unmodifiable(_fixture);

  @override
  int totalCountForPost(String postId) => _count(_fixture);
}
