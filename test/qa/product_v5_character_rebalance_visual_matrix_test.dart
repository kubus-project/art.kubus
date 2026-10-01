import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/screens/art/artwork_edit_screen.dart';
import 'package:art_kubus/screens/desktop/community/desktop_profile_screen.dart'
    as desktop_profile;
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_artist_studio_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_institution_hub_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_wallet_screen.dart';
import 'package:art_kubus/screens/settings_screen.dart';
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

/// Wave 5A PRODUCT character-rebalance visual matrix (captures A–J of the
/// brief), against local fixtures only. The scenes exist unchanged on
/// dev@4dc26a17, so the same file renders BEFORE from that checkout.
///
/// The one deliberate difference between the two runs is
/// [_profileAsPushedByShell]: it mirrors exactly what each commit's
/// `DesktopShell._showProfileMenu` pushes (BEFORE wraps the profile in a
/// `DesktopSubScreen`; AFTER pushes the profile, which owns its header).
///
/// ```
/// KUBUS_RUN_VISUAL_QA=1 QA_LABEL=after flutter test test/qa/product_v5_character_rebalance_visual_matrix_test.dart
/// ```
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['KUBUS_RUN_VISUAL_QA'] != '1') {
    test('visual QA matrix is opt-in', () {},
        skip: 'Set KUBUS_RUN_VISUAL_QA=1 to generate screenshot evidence.');
    return;
  }

  final label = Platform.environment['QA_LABEL'] ?? 'after';
  final outputDir =
      Directory('output/qa/product-v5-character-rebalance/$label');
  final captures = <Map<String, Object?>>[];

  setUpAll(() async {
    await QaFontLoader.ensureLoaded();
    if (outputDir.existsSync()) outputDir.deleteSync(recursive: true);
    outputDir.createSync(recursive: true);
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
        'Artist Studio_onboarding_completed': true,
        'Institution Hub_onboarding_completed': true,
      }));

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
    // Asset images decode on real async IO; without this the first capture
    // of a run shows the KUB8 mark as an empty tile.
    await tester.runAsync(() => precacheImage(
          const AssetImage(KubusTokenIdentity.kub8LogoAsset),
          tester.element(find.byType(ColoredBox).first),
        ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
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
    FlutterError.onError = prior;
  }

  final owner = qaOwner();

  // A — desktop owner profile, stats + badges + performance.
  qaCase('A profile desktop 1440 dark', (tester) async {
    await surface(tester, 'A-profile-desktop-1440-dark-en',
        () => qaShellHost(_profileAsPushedByShell()),
        size: const Size(1440, 1700), signedIn: owner);
  });

  // B — profile header ownership across the desktop widths.
  for (final width in <double>[900, 1024, 1280, 1440, 1920]) {
    qaCase('B profile header ${width.toInt()}', (tester) async {
      await surface(tester, 'B-profile-header-${width.toInt()}-dark-en',
          () => qaShellHost(_profileAsPushedByShell()),
          size: Size(width, 560), signedIn: owner);
    });
  }

  // C — desktop settings, notification / email preferences.
  qaCase('C settings desktop notifications', (tester) async {
    await surface(
      tester,
      'C-settings-desktop-notifications-dark-en',
      () => qaShellHost(const DesktopSettingsScreen(embeddedInShell: true)),
      size: const Size(1440, 2000),
      signedIn: owner,
      extraProviders: [qaEmailPreferences()],
      interact: (tester) async {
        await tester
            .tap(find.byKey(const ValueKey('desktop_settings_sidebar_item_2')));
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });

  // D — mobile settings, account management / email preferences dialog.
  qaCase('D settings mobile email preferences', (tester) async {
    await surface(
      tester,
      'D-settings-mobile-email-dark-en',
      () => const SettingsScreen(),
      size: const Size(390, 1400),
      signedIn: owner,
      extraProviders: [qaEmailPreferences()],
      interact: (tester) async {
        final tile = find.byKey(const Key('settings_tile_account_management'));
        await tester.scrollUntilVisible(tile, 300,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(tile);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
      },
    );
  });

  // E — artwork editor / management rail.
  qaCase('E artwork editor desktop', (tester) async {
    final artworks = ArtworkProvider()..addOrUpdateArtwork(qaArtwork());
    await surface(
      tester,
      'E-artwork-editor-desktop-dark-en',
      () => qaShellHost(
          const ArtworkEditScreen(artworkId: 'art-a', embedded: true)),
      size: const Size(1440, 1000),
      signedIn: qaOwner(isArtist: true),
      extraProviders: [
        ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
        ChangeNotifierProvider<CollabProvider>(
          create: (_) => CollabProvider(api: QaFixtureCollabApi()),
        ),
      ],
    );
  });

  // F / G — Artist Studio and Institution Hub.
  qaCase('F artist studio desktop', (tester) async {
    await surface(tester, 'F-artist-studio-desktop-dark-en',
        () => const DesktopArtistStudioScreen(),
        size: const Size(1440, 900), signedIn: qaOwner(isArtist: true));
  });
  qaCase('G institution hub desktop', (tester) async {
    await surface(tester, 'G-institution-hub-desktop-dark-en',
        () => const DesktopInstitutionHubScreen(),
        size: const Size(1440, 900), signedIn: qaOwner(isInstitution: true));
  });

  // H / I — wallet KUB8 identity.
  qaCase('H wallet desktop', (tester) async {
    await surface(
        tester, 'H-wallet-desktop-dark-en', () => const DesktopWalletScreen(),
        size: const Size(1440, 900),
        signedIn: owner,
        extraProviders: [qaWalletProvider()]);
  });
  qaCase('I wallet mobile', (tester) async {
    await surface(tester, 'I-wallet-mobile-dark-en', () => const WalletHome(),
        signedIn: owner, extraProviders: [qaWalletProvider()]);
  });
  qaCase('I wallet mobile light', (tester) async {
    await surface(tester, 'I-wallet-mobile-light-sl', () => const WalletHome(),
        brightness: Brightness.light,
        locale: const Locale('sl'),
        signedIn: owner,
        extraProviders: [qaWalletProvider()]);
  });

  // J — light-theme representatives.
  qaCase('J profile desktop light', (tester) async {
    await surface(tester, 'J-profile-desktop-1440-light-en',
        () => qaShellHost(_profileAsPushedByShell()),
        size: const Size(1440, 1700),
        brightness: Brightness.light,
        signedIn: owner);
  });
  qaCase('J settings desktop light', (tester) async {
    await surface(
      tester,
      'J-settings-desktop-notifications-light-sl',
      () => qaShellHost(const DesktopSettingsScreen(embeddedInShell: true)),
      size: const Size(1440, 2000),
      brightness: Brightness.light,
      locale: const Locale('sl'),
      signedIn: owner,
      extraProviders: [qaEmailPreferences()],
      interact: (tester) async {
        await tester
            .tap(find.byKey(const ValueKey('desktop_settings_sidebar_item_2')));
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });

  // Large text: profile stats column and mobile preference groups.
  qaCase('large text profile 1280', (tester) async {
    await surface(tester, 'X-profile-desktop-1280-dark-en-text200',
        () => qaShellHost(_profileAsPushedByShell()),
        size: const Size(1280, 1800), textScale: 2, signedIn: owner);
  });
  // AFTER-only large-text scenes (the BEFORE matrix has no counterpart):
  // settings groups, wallet token identity and the management rail.
  qaCase('large text settings mobile', (tester) async {
    await surface(
      tester,
      'X-settings-mobile-email-dark-en-text200',
      () => const SettingsScreen(),
      size: const Size(390, 2400),
      textScale: 2,
      signedIn: owner,
      extraProviders: [qaEmailPreferences()],
      interact: (tester) async {
        final tile = find.byKey(const Key('settings_tile_account_management'));
        await tester.scrollUntilVisible(tile, 300,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(tile);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
      },
    );
  });
  qaCase('large text wallet mobile', (tester) async {
    await surface(
        tester, 'X-wallet-mobile-390-dark-en-text200', () => const WalletHome(),
        size: const Size(390, 1400),
        textScale: 2,
        signedIn: owner,
        extraProviders: [qaWalletProvider()]);
  });
  qaCase('large text artwork editor', (tester) async {
    final artworks = ArtworkProvider()..addOrUpdateArtwork(qaArtwork());
    await surface(
      tester,
      'X-artwork-editor-desktop-dark-en-text200',
      () => qaShellHost(
          const ArtworkEditScreen(artworkId: 'art-a', embedded: true)),
      size: const Size(1440, 1400),
      textScale: 2,
      signedIn: qaOwner(isArtist: true),
      extraProviders: [
        ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
        ChangeNotifierProvider<CollabProvider>(
          create: (_) => CollabProvider(api: QaFixtureCollabApi()),
        ),
      ],
    );
  });

  qaCase('narrow wallet 320', (tester) async {
    await surface(
        tester, 'X-wallet-mobile-320-dark-sl', () => const WalletHome(),
        size: const Size(320, 700),
        locale: const Locale('sl'),
        signedIn: owner,
        extraProviders: [qaWalletProvider()]);
  });
}

/// What `DesktopShell._showProfileMenu` pushes on this commit. AFTER: the
/// profile owns its single header, so it is pushed directly.
Widget _profileAsPushedByShell() => const desktop_profile.ProfileScreen();

void qaCase(String description, WidgetTesterCallback callback) => testWidgets(
      description,
      callback,
      timeout: const Timeout(Duration(seconds: 120)),
    );

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
