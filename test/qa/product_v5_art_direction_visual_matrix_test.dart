import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/screens/art/artwork_edit_screen.dart';
import 'package:art_kubus/screens/community/profile_screen.dart'
    as mobile_profile;
import 'package:art_kubus/screens/desktop/community/desktop_profile_screen.dart'
    as desktop_profile;
import 'package:art_kubus/screens/desktop/desktop_home_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_artist_studio_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_governance_hub_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_institution_hub_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_marketplace_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_wallet_screen.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/screens/web3/achievements/achievements_page.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_home.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/wallet/kubus_token_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/product_v5_qa_fixtures.dart';
import '../support/qa_font_loader.dart';

/// Wave 5A-R art-direction restoration matrix: BEFORE (dev), the master
/// visual reference, and AFTER, rendered from the same local fixtures.
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_art_direction_visual_matrix_test.dart
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
  final outputDir = Directory('output/qa/product-v5-art-direction/$label');
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final bytes = await _captureRoot(tester);
    File('${outputDir.path}/$name.png').writeAsBytesSync(bytes);
    // Let in-flight offline loads (e.g. DAOProvider's sequential backend
    // chain and its secure-storage read timeouts) settle in fake time, so
    // no timer outlives the tree.
    for (var i = 0; i < 10; i++) {
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
    FlutterError.onError = prior;
  }

  void scene(String name, WidgetTesterCallback body) {
    if (only.isNotEmpty && !only.any(name.startsWith)) return;
    testWidgets(name, body, timeout: const Timeout(Duration(seconds: 150)));
  }

  final owner = qaOwner();
  final artist = qaOwner(isArtist: true);
  final institution = qaOwner(isInstitution: true);
  const desktop = Size(1440, 1000);

  // HOME — discovery-first, persona-aware.
  for (final b in Brightness.values) {
    scene('home-mobile-390-${b.name}', (tester) async {
      await surface(
          tester, 'home-mobile-390-${b.name}-en', () => const HomeScreen(),
          size: const Size(390, 1500), brightness: b, signedIn: owner);
    });
    scene('home-desktop-1440-${b.name}', (tester) async {
      await surface(tester, 'home-desktop-1440-${b.name}-en',
          () => qaShellHost(const DesktopHomeScreen()),
          size: const Size(1440, 1300), brightness: b, signedIn: owner);
    });
  }
  scene('home-desktop-1440-artist', (tester) async {
    await surface(tester, 'home-desktop-1440-dark-en-artist',
        () => qaShellHost(const DesktopHomeScreen()),
        size: const Size(1440, 1300), signedIn: artist);
  });
  // Returning user: recorded quick actions in the horizontal strip.
  const visited = <String>[
    'map',
    'community',
    'marketplace',
    'achievements',
    'dao_hub',
    'studio',
    'institution_hub',
  ];
  for (final b in Brightness.values) {
    scene('home-desktop-quickactions-${b.name}', (tester) async {
      await surface(tester, 'home-desktop-quickactions-1440-${b.name}-en',
          () => qaShellHost(const DesktopHomeScreen()),
          size: const Size(1440, 1300),
          brightness: b,
          signedIn: owner,
          extraProviders: [qaNavigationWithVisits(visited)]);
    });
  }
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

  // PROFILE — owner, artist, institution; 200 % text.
  for (final b in Brightness.values) {
    scene('profile-desktop-1440-${b.name}', (tester) async {
      await surface(tester, 'profile-desktop-1440-${b.name}-en',
          () => qaShellHost(const desktop_profile.ProfileScreen()),
          size: const Size(1440, 1500), brightness: b, signedIn: artist);
    });
    scene('profile-mobile-390-${b.name}', (tester) async {
      await surface(tester, 'profile-mobile-390-${b.name}-en',
          () => const mobile_profile.ProfileScreen(),
          size: const Size(390, 1500), brightness: b, signedIn: artist);
    });
  }
  // Image-less owner cover with the role resolved from an approved DAO
  // review while currentUser's role flags are still false.
  for (final role in const ['artist', 'institution']) {
    for (final b in Brightness.values) {
      scene('profile-mobile-resolved-$role-${b.name}', (tester) async {
        await surface(tester, 'profile-mobile-390-${b.name}-en-resolved-$role',
            () => const mobile_profile.ProfileScreen(),
            size: const Size(390, 1100),
            brightness: b,
            signedIn: owner,
            extraProviders: [
              ChangeNotifierProvider<DAOProvider>(
                  create: (_) => QaApprovedRoleDAOProvider(role)),
            ]);
      });
    }
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
  scene('profile-mobile-320', (tester) async {
    await surface(tester, 'profile-mobile-320-dark-sl',
        () => const mobile_profile.ProfileScreen(),
        size: const Size(320, 1400),
        locale: const Locale('sl'),
        signedIn: artist);
  });

  // SETTINGS — utility, should stay calm.
  scene('settings-desktop', (tester) async {
    await surface(tester, 'settings-desktop-1440-dark-en',
        () => qaShellHost(const DesktopSettingsScreen(embeddedInShell: true)),
        size: desktop, signedIn: owner, extraProviders: [qaEmailPreferences()]);
  });
  scene('settings-mobile', (tester) async {
    await surface(
        tester, 'settings-mobile-390-light-en', () => const SettingsScreen(),
        size: const Size(390, 1200),
        brightness: Brightness.light,
        signedIn: owner,
        extraProviders: [qaEmailPreferences()]);
  });

  // CREATOR / MANAGEMENT.
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
  scene('creator-studio-desktop', (tester) async {
    await surface(tester, 'creator-studio-desktop-1440-dark-en',
        () => const DesktopArtistStudioScreen(),
        size: desktop, signedIn: artist);
  });
  scene('creator-institution-desktop', (tester) async {
    await surface(tester, 'creator-institution-desktop-1440-light-en',
        () => const DesktopInstitutionHubScreen(),
        size: desktop, brightness: Brightness.light, signedIn: institution);
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
    scene('wallet-mobile-${b.name}', (tester) async {
      await surface(
          tester, 'wallet-mobile-390-${b.name}-en', () => const WalletHome(),
          size: const Size(390, 1100),
          brightness: b,
          signedIn: owner,
          extraProviders: [qaWalletProvider()]);
    });
  }
  scene('wallet-mobile-320', (tester) async {
    await surface(tester, 'wallet-mobile-320-dark-sl', () => const WalletHome(),
        size: const Size(320, 900),
        locale: const Locale('sl'),
        signedIn: owner,
        extraProviders: [qaWalletProvider()]);
  });

  // ADVANCED — marketplace, DAO, achievements.
  scene('advanced-marketplace-desktop', (tester) async {
    await surface(tester, 'advanced-marketplace-desktop-1440-dark-en',
        () => const DesktopMarketplaceScreen(),
        size: desktop, signedIn: owner);
  });
  scene('advanced-dao-desktop', (tester) async {
    await surface(tester, 'advanced-dao-desktop-1440-light-en',
        () => const DesktopGovernanceHubScreen(),
        size: desktop, brightness: Brightness.light, signedIn: owner);
  });
  scene('advanced-achievements-mobile', (tester) async {
    await surface(tester, 'advanced-achievements-mobile-390-dark-en',
        () => const AchievementsPage(),
        size: const Size(390, 1100), signedIn: owner);
  });
}

const Size _mobile = Size(390, 844);

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
