import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/features/analytics/analytics_view_models.dart';
import 'package:art_kubus/features/analytics/widgets/analytics_overview_grid.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/analytics_filters_provider.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/screens/art/artwork_edit_screen.dart';
import 'package:art_kubus/screens/community/profile_screen.dart'
    as mobile_profile;
import 'package:art_kubus/screens/desktop/community/desktop_profile_screen.dart'
    as desktop_profile;
import 'package:art_kubus/screens/community/messages_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_home_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_artist_studio_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_governance_hub_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_institution_hub_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_marketplace_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_wallet_screen.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/screens/web3/achievements/achievements_page.dart';
import 'package:art_kubus/screens/web3/artist/artist_analytics.dart';
import 'package:art_kubus/screens/web3/artist/artist_studio.dart';
import 'package:art_kubus/screens/web3/dao/governance_hub.dart';
import 'package:art_kubus/screens/web3/institution/institution_hub.dart';
import 'package:art_kubus/screens/web3/marketplace/marketplace.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_home.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_action_tile.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:art_kubus/widgets/wallet/kubus_token_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/product_v5_qa_fixtures.dart';
import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';
import '../support/qa_font_loader.dart';

/// Wave 5A-S semantic visual-system matrix: BEFORE (merged 5A-R dev) and
/// AFTER, rendered from the same local fixtures with real Sofia Sans and
/// Space Mono.
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_semantic_visual_matrix_test.dart
/// ```
///
/// `QA_ONLY=home,profile` limits the run to scenes whose name starts with
/// one of the prefixes (the output directory is then not wiped).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
    test('visual QA matrix is opt-in', () {},
        skip: 'Set KUBUS_RUN_VISUAL_QA=1 to generate screenshot evidence.');
    return;
  }

  final label = Platform.environment['QA_LABEL'] ?? 'after';
  final only = (Platform.environment['QA_ONLY'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final outputDir = Directory('output/qa/product-v5-semantic/$label');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    if (only.isEmpty && outputDir.existsSync()) {
      outputDir.deleteSync(recursive: true);
    }
    outputDir.createSync(recursive: true);
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
        'Artist Studio_onboarding_completed': true,
        'Institution Hub_onboarding_completed': true,
        'DAO_onboarding_completed': true,
        'Marketplace_onboarding_completed': true,
      }));

  tearDownAll(() {
    File('${outputDir.path}/report-${only.isEmpty ? 'all' : only.join('-')}.json')
        .writeAsStringSync(
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

  Future<void> settleAndCapture(
    WidgetTester tester,
    String name,
    Size size,
    Brightness brightness,
    Locale locale,
    double textScale,
    List<String> errors,
  ) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final bytes = await _captureRoot(tester);
    File('${outputDir.path}/$name.png').writeAsBytesSync(bytes);
    // Fake time only: outlasts the socket connect timeout (20 s) and the
    // secure-storage reads so no timer survives the scene.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    captures.add(<String, Object?>{
      'name': name,
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
    Brightness brightness = Brightness.dark,
    Locale locale = const Locale('en'),
    double textScale = 1,
    UserProfile? signedIn,
    Future<void> Function(WidgetTester tester)? interact,
    List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
  }) async {
    final prior = FlutterError.onError;
    final errors = await pumpProductSurface(
      tester,
      child: Builder(
        builder: (context) => ColoredBox(
          color: KubusColorRoles.of(context).ground,
          child: build(),
        ),
      ),
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
    await tester.runAsync(() => precacheImage(
          const AssetImage(KubusTokenIdentity.kub8LogoAsset),
          tester.element(find.byType(ColoredBox).first),
        ));
    await settleAndCapture(
        tester, name, size, brightness, locale, textScale, errors);
    FlutterError.onError = prior;
  }

  Future<void> publicProfile(
    WidgetTester tester,
    String name,
    ProfileSurface kind, {
    required Size size,
    Brightness brightness = Brightness.dark,
    Locale locale = const Locale('en'),
    double textScale = 1,
    bool isArtist = false,
    bool isVerified = false,
  }) async {
    await pumpProfileSurface(
      tester,
      surface: kind,
      user: ProfileFixtures.user(isArtist: isArtist, isVerified: isVerified),
      size: size,
      brightness: brightness,
      locale: locale,
      textScale: textScale,
      paintGround: true,
    );
    await settleAndCapture(
      tester,
      name,
      size,
      brightness,
      locale,
      textScale,
      unexpectedRenderErrors.map((e) => e.exceptionAsString()).toList(),
    );
  }

  void scene(String name, WidgetTesterCallback body) {
    if (only.isNotEmpty && !only.any(name.startsWith)) return;
    testWidgets(name, (tester) async {
      await body(tester);
      // Public profiles open the realtime socket; close it (and let its
      // connect timeout lapse in fake time) so no timer outlives the scene.
      SocketService().disconnect();
      await tester.pump(const Duration(seconds: 25));
    }, timeout: const Timeout(Duration(seconds: 150)));
  }

  final owner = qaOwner();
  final artist = qaOwner(isArtist: true);
  final institution = qaOwner(isInstitution: true);
  const desktop = Size(1440, 1000);
  const visited = <String>[
    'map',
    'community',
    'marketplace',
    'achievements',
    'dao_hub',
    'studio',
    'institution_hub',
  ];

  // COMPONENTS — the shared semantic primitives in isolation.
  for (final b in Brightness.values) {
    for (final scale in const [1.0, 2.0]) {
      scene('components-${b.name}-x${scale.toInt()}', (tester) async {
        await surface(
            tester,
            'components-sheet-1440-${b.name}-en-x${scale.toInt()}',
            () => const _ComponentSheet(),
            size: Size(1440, scale > 1 ? 1700 : 1000),
            brightness: b,
            textScale: scale,
            signedIn: owner);
      });
    }
  }
  scene('components-320', (tester) async {
    await surface(
        tester, 'components-sheet-320-dark-sl', () => const _ComponentSheet(),
        size: const Size(320, 1700),
        locale: const Locale('sl'),
        signedIn: owner);
  });

  // HOME — discovery-first, persona-aware.
  for (final b in Brightness.values) {
    scene('home-mobile-390-${b.name}', (tester) async {
      await surface(
          tester, 'home-mobile-390-${b.name}-en', () => const HomeScreen(),
          size: const Size(390, 1500), brightness: b, signedIn: owner);
    });
    scene('home-desktop-quickactions-${b.name}', (tester) async {
      await surface(tester, 'home-desktop-quickactions-1440-${b.name}-en',
          () => qaShellHost(const DesktopHomeScreen()),
          size: const Size(1440, 1300),
          brightness: b,
          signedIn: owner,
          extraProviders: [qaNavigationWithVisits(visited)]);
    });
  }
  scene('home-desktop-artist', (tester) async {
    await surface(tester, 'home-desktop-1440-dark-en-artist',
        () => qaShellHost(const DesktopHomeScreen()),
        size: const Size(1440, 1300), signedIn: artist);
  });
  scene('home-desktop-quickactions-text200', (tester) async {
    await surface(tester, 'home-desktop-quickactions-1440-dark-sl-text200',
        () => qaShellHost(const DesktopHomeScreen()),
        size: const Size(1440, 3200),
        locale: const Locale('sl'),
        textScale: 2,
        signedIn: owner,
        extraProviders: [qaNavigationWithVisits(visited)]);
  });
  scene('home-mobile-320', (tester) async {
    await surface(tester, 'home-mobile-320-dark-sl', () => const HomeScreen(),
        size: const Size(320, 1400),
        locale: const Locale('sl'),
        signedIn: owner);
  });
  scene('home-mobile-guest', (tester) async {
    await surface(
        tester, 'home-mobile-390-light-sl-guest', () => const HomeScreen(),
        size: const Size(390, 1500),
        brightness: Brightness.light,
        locale: const Locale('sl'));
  });

  // PROFILE — owner and other-user, artist/institution/account.
  for (final b in Brightness.values) {
    scene('profile-desktop-1440-${b.name}', (tester) async {
      await surface(tester, 'profile-desktop-1440-${b.name}-en-artist',
          () => qaShellHost(const desktop_profile.ProfileScreen()),
          size: const Size(1440, 1500), brightness: b, signedIn: artist);
    });
    scene('profile-mobile-390-${b.name}', (tester) async {
      await surface(tester, 'profile-mobile-390-${b.name}-en-artist',
          () => const mobile_profile.ProfileScreen(),
          size: const Size(390, 1500), brightness: b, signedIn: artist);
    });
  }
  scene('profile-desktop-institution', (tester) async {
    await surface(tester, 'profile-desktop-1440-dark-en-institution',
        () => qaShellHost(const desktop_profile.ProfileScreen()),
        size: const Size(1440, 1500), signedIn: institution);
  });
  scene('profile-mobile-account', (tester) async {
    await surface(tester, 'profile-mobile-390-dark-sl-account',
        () => const mobile_profile.ProfileScreen(),
        size: const Size(390, 1500),
        locale: const Locale('sl'),
        signedIn: owner);
  });
  scene('profile-desktop-text200', (tester) async {
    await surface(tester, 'profile-desktop-1280-dark-en-text200',
        () => qaShellHost(const desktop_profile.ProfileScreen()),
        size: const Size(1280, 2000), textScale: 2, signedIn: artist);
  });
  scene('profile-other-desktop-artist', (tester) async {
    await publicProfile(tester, 'profile-other-desktop-1440-dark-en-artist',
        ProfileSurface.desktopPublic,
        size: const Size(1440, 1400), isArtist: true, isVerified: true);
  });
  scene('profile-other-desktop-account', (tester) async {
    await publicProfile(tester, 'profile-other-desktop-1440-light-en-account',
        ProfileSurface.desktopPublic,
        size: const Size(1440, 1400), brightness: Brightness.light);
  });
  scene('profile-other-mobile-artist', (tester) async {
    await publicProfile(tester, 'profile-other-mobile-390-dark-sl-artist',
        ProfileSurface.mobilePublic,
        size: const Size(390, 1400),
        locale: const Locale('sl'),
        isArtist: true,
        isVerified: true);
  });
  scene('profile-other-mobile-320', (tester) async {
    await publicProfile(tester, 'profile-other-mobile-320-light-en-artist',
        ProfileSurface.mobilePublic,
        size: const Size(320, 1400),
        brightness: Brightness.light,
        isArtist: true);
  });

  // STUDIO / INSTITUTION.
  scene('studio-desktop', (tester) async {
    await surface(tester, 'studio-desktop-1440-dark-en',
        () => const DesktopArtistStudioScreen(),
        size: desktop, signedIn: artist);
  });
  scene('studio-mobile', (tester) async {
    await surface(
        tester, 'studio-mobile-390-light-sl', () => const ArtistStudio(),
        size: const Size(390, 1300),
        brightness: Brightness.light,
        locale: const Locale('sl'),
        signedIn: artist);
  });
  scene('institution-desktop', (tester) async {
    await surface(tester, 'institution-desktop-1440-light-en',
        () => const DesktopInstitutionHubScreen(),
        size: desktop, brightness: Brightness.light, signedIn: institution);
  });
  scene('institution-mobile', (tester) async {
    await surface(
        tester, 'institution-mobile-390-dark-en', () => const InstitutionHub(),
        size: const Size(390, 1300), signedIn: institution);
  });

  // ANALYTICS — the lead/support hierarchy in isolation and in its screen.
  for (final b in Brightness.values) {
    scene('analytics-overview-${b.name}', (tester) async {
      await surface(tester, 'analytics-overview-1440-${b.name}-en',
          () => const _AnalyticsSheet(),
          size: const Size(1440, 700), brightness: b, signedIn: artist);
    });
  }
  scene('analytics-overview-390', (tester) async {
    await surface(
        tester, 'analytics-overview-390-dark-sl', () => const _AnalyticsSheet(),
        size: const Size(390, 1100),
        locale: const Locale('sl'),
        signedIn: artist);
  });
  scene('analytics-overview-text200', (tester) async {
    await surface(tester, 'analytics-overview-390-light-en-text200',
        () => const _AnalyticsSheet(),
        size: const Size(390, 2200),
        brightness: Brightness.light,
        textScale: 2,
        signedIn: artist);
  });
  scene('analytics-overview-320-text200', (tester) async {
    await surface(tester, 'analytics-overview-320-dark-sl-text200',
        () => const _AnalyticsSheet(),
        size: const Size(320, 2400),
        locale: const Locale('sl'),
        textScale: 2,
        signedIn: artist);
  });
  scene('analytics-overview-text130', (tester) async {
    await surface(tester, 'analytics-overview-390-light-en-text130',
        () => const _AnalyticsSheet(),
        size: const Size(390, 1400),
        brightness: Brightness.light,
        textScale: 1.3,
        signedIn: artist);
  });
  scene('analytics-overview-desktop-text200', (tester) async {
    await surface(tester, 'analytics-overview-1440-dark-en-text200',
        () => const _AnalyticsSheet(),
        size: const Size(1440, 900), textScale: 2, signedIn: artist);
  });
  scene('analytics-screen-desktop', (tester) async {
    await surface(tester, 'analytics-screen-1440-dark-en-artist',
        () => const ArtistAnalytics(embedded: false),
        size: desktop,
        signedIn: artist,
        extraProviders: [
          ChangeNotifierProvider<AnalyticsFiltersProvider>(
              create: (_) => AnalyticsFiltersProvider()),
        ]);
  });

  // CREATOR.
  scene('creator-editor-desktop', (tester) async {
    final artworks = ArtworkProvider()..addOrUpdateArtwork(qaArtwork());
    await surface(
      tester,
      'creator-editor-desktop-1440-dark-en',
      () => qaShellHost(const ArtworkEditScreen(
          artworkId: 'art-a', chrome: ArtworkEditChrome.workspace)),
      size: desktop,
      signedIn: artist,
      extraProviders: [
        ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
        ChangeNotifierProvider<CollabProvider>(
          create: (_) => CollabProvider(api: QaFixtureCollabApi()),
        ),
      ],
    );
  });

  // WALLET.
  for (final b in Brightness.values) {
    scene('wallet-desktop-${b.name}', (tester) async {
      await surface(tester, 'wallet-desktop-1440-${b.name}-en',
          () => const DesktopWalletScreen(),
          size: desktop,
          brightness: b,
          signedIn: owner,
          extraProviders: [qaWalletProvider()]);
    });
  }
  scene('wallet-mobile', (tester) async {
    await surface(tester, 'wallet-mobile-390-dark-en', () => const WalletHome(),
        size: const Size(390, 1100),
        signedIn: owner,
        extraProviders: [qaWalletProvider()]);
  });
  scene('wallet-mobile-320', (tester) async {
    await surface(
        tester, 'wallet-mobile-320-light-sl', () => const WalletHome(),
        size: const Size(320, 900),
        brightness: Brightness.light,
        locale: const Locale('sl'),
        signedIn: owner,
        extraProviders: [qaWalletProvider()]);
  });

  // UTILITY — settings, messages and onboarding stay neutral.
  scene('utility-settings-desktop', (tester) async {
    await surface(tester, 'utility-settings-desktop-1440-dark-en',
        () => qaShellHost(const DesktopSettingsScreen(embeddedInShell: true)),
        size: desktop, signedIn: owner, extraProviders: [qaEmailPreferences()]);
  });
  scene('utility-settings-mobile', (tester) async {
    await surface(tester, 'utility-settings-mobile-390-light-sl',
        () => const SettingsScreen(),
        size: const Size(390, 1400),
        brightness: Brightness.light,
        locale: const Locale('sl'),
        signedIn: owner,
        extraProviders: [qaEmailPreferences()]);
  });
  scene('utility-messages-mobile', (tester) async {
    await surface(tester, 'utility-messages-mobile-390-dark-en',
        () => const MessagesScreen(),
        size: const Size(390, 1000), signedIn: owner);
  });
  scene('utility-onboarding-dao', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await surface(tester, 'utility-onboarding-dao-1440-light-en',
        () => const DesktopGovernanceHubScreen(),
        size: desktop, brightness: Brightness.light, signedIn: owner);
  });

  // ADVANCED — marketplace, DAO, achievements.
  scene('marketplace-desktop', (tester) async {
    await surface(tester, 'marketplace-desktop-1440-dark-en',
        () => const DesktopMarketplaceScreen(),
        size: desktop, signedIn: owner);
  });
  scene('marketplace-mobile', (tester) async {
    await surface(
        tester, 'marketplace-mobile-390-light-en', () => const Marketplace(),
        size: const Size(390, 1100),
        brightness: Brightness.light,
        signedIn: owner);
  });
  scene('dao-desktop', (tester) async {
    await surface(tester, 'dao-desktop-1440-light-en',
        () => const DesktopGovernanceHubScreen(),
        size: desktop, brightness: Brightness.light, signedIn: owner);
  });
  scene('dao-mobile', (tester) async {
    await surface(tester, 'dao-mobile-390-dark-sl', () => const GovernanceHub(),
        size: const Size(390, 1300),
        locale: const Locale('sl'),
        signedIn: owner);
  });
  scene('achievements-mobile', (tester) async {
    await surface(tester, 'achievements-mobile-390-dark-en',
        () => const AchievementsPage(),
        size: const Size(390, 1100), signedIn: owner);
  });
  scene('achievements-mobile-light', (tester) async {
    await surface(tester, 'achievements-mobile-390-light-sl',
        () => const AchievementsPage(),
        size: const Size(390, 1100),
        brightness: Brightness.light,
        locale: const Locale('sl'),
        signedIn: owner);
  });
}

const Size _mobile = Size(390, 844);

/// Stacked and inline destination tiles plus expressive and dense stat
/// tiles, so the primitives are reviewed without a screen around them.
class _ComponentSheet extends StatelessWidget {
  const _ComponentSheet();

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final tiles = <(String, IconData, Color)>[
      ('Map', Icons.map_outlined, roles.statTeal),
      ('Artist Studio', Icons.palette_outlined, roles.web3ArtistStudioAccent),
      (
        'Institution Hub',
        Icons.account_balance_outlined,
        roles.web3InstitutionAccent
      ),
      ('Governance', Icons.how_to_vote_outlined, roles.web3DaoAccent),
      (
        'Marketplace and collectible editions',
        Icons.storefront_outlined,
        roles.web3MarketplaceAccent
      ),
    ];
    Widget stacked((String, IconData, Color) t) =>
        KubusActionTile(title: t.$1, icon: t.$2, accent: t.$3, onTap: () {});
    Widget inline((String, IconData, Color) t) => KubusActionTile(
        title: t.$1,
        icon: t.$2,
        accent: t.$3,
        layout: KubusActionTileLayout.inline,
        onTap: () {});
    final stats = <(String, String, IconData, Color)>[
      ('Followers', '1,284', Icons.people_outline, roles.statBlue),
      ('Artworks', '42', Icons.image_outlined, roles.statTeal),
      ('Votes cast', '17', Icons.how_to_vote_outlined, roles.web3DaoAccent),
      (
        'Achievements unlocked',
        '9',
        Icons.emoji_events_outlined,
        roles.statAmber
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: narrow ? 2 : 5,
            mainAxisSpacing: KubusSpacing.sm,
            crossAxisSpacing: KubusSpacing.sm,
            childAspectRatio: narrow ? 1.1 : 1.6,
            children: [for (final t in tiles) stacked(t)],
          ),
          const SizedBox(height: KubusSpacing.lg),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in tiles) ...[
                  inline(t),
                  const SizedBox(width: KubusSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          Builder(builder: (context) {
            final extent = KubusStatCard.centeredExtent(context);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: narrow ? 2 : 4,
              mainAxisSpacing: KubusSpacing.sm,
              crossAxisSpacing: KubusSpacing.sm,
              childAspectRatio: 1,
              children: [
                for (final s in stats)
                  SizedBox(
                    height: extent,
                    child: KubusStatCard(
                      title: s.$1,
                      value: s.$2,
                      icon: s.$3,
                      accent: s.$4,
                      layout: KubusStatCardLayout.centered,
                      titleMaxLines: 2,
                      onTap: () {},
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: KubusSpacing.lg),
          for (final s in stats.take(2)) ...[
            KubusStatCard(title: s.$1, value: s.$2, icon: s.$3, accent: s.$4),
            const SizedBox(height: KubusSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsSheet extends StatefulWidget {
  const _AnalyticsSheet();

  @override
  State<_AnalyticsSheet> createState() => _AnalyticsSheetState();
}

class _AnalyticsSheetState extends State<_AnalyticsSheet> {
  String _selected = 'viewsReceived';

  static const _cards = <AnalyticsOverviewCardData>[
    AnalyticsOverviewCardData(
      metricId: 'viewsReceived',
      title: 'Artwork views',
      value: '12,480',
      icon: Icons.visibility_outlined,
      subtitle: 'Last 30 days',
      changeLabel: '+18%',
      isPositive: true,
    ),
    AnalyticsOverviewCardData(
      metricId: 'followers',
      title: 'Followers',
      value: '1,284',
      icon: Icons.people_outline,
      changeLabel: '+4%',
      isPositive: true,
    ),
    AnalyticsOverviewCardData(
      metricId: 'likesReceived',
      title: 'Likes received',
      value: '3,912',
      icon: Icons.favorite_border,
      changeLabel: '-2%',
      isPositive: false,
    ),
    AnalyticsOverviewCardData(
      metricId: 'artworks',
      title: 'Published artworks',
      value: '42',
      icon: Icons.image_outlined,
    ),
    AnalyticsOverviewCardData(
      metricId: 'arSessions',
      title: 'AR sessions',
      value: '608',
      icon: Icons.view_in_ar_outlined,
      changeLabel: '+31%',
      isPositive: true,
    ),
    AnalyticsOverviewCardData(
      metricId: 'saves',
      title: 'Saves',
      value: '274',
      icon: Icons.bookmark_border,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      child: AnalyticsOverviewGrid(
        cards: _cards,
        isLoading: false,
        selectedMetricId: _selected,
        onMetricSelected: (id) => setState(() => _selected = id),
      ),
    );
  }
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
