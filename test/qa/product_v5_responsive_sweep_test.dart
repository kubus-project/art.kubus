import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/screens/art/artwork_edit_screen.dart';
import 'package:art_kubus/screens/community/profile_screen.dart'
    as mobile_profile;
import 'package:art_kubus/screens/desktop/community/desktop_profile_screen.dart'
    as desktop_profile;
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_wallet_screen.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/screens/settings_screen.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/product_v5_qa_fixtures.dart';
import '../support/qa_font_loader.dart';

/// Wave 5A responsive sweep: the rebalanced surfaces render without a single
/// layout error across the phone-to-wide-desktop range, and at 200 % text
/// (Flutter text scaling, not browser zoom). Mobile screens below the 900 px
/// desktop breakpoint, desktop screens from it.
void main() {
  const widths = <double>[
    320, 360, 390, 430, 768, 899, 900, 1024, 1200, 1280, 1440, 1920, //
  ];

  // Real Sofia Sans / Space Mono metrics: the placeholder test font would
  // report overflows the product never draws.
  setUpAll(QaFontLoader.ensureLoaded);
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> expectClean(
    WidgetTester tester,
    Widget Function() build, {
    required Size size,
    double textScale = 1,
    List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
    bool artist = false,
    String? onlyFrom,
  }) async {
    final prior = FlutterError.onError;
    final errors = await pumpProductSurface(
      tester,
      child: build(),
      size: size,
      textScale: textScale,
      signedInProfile: qaOwner(isArtist: artist),
      extraProviders: extraProviders,
    );
    // Settle, and drain the 800 ms auth-token read timer the screens start.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    // Hand errors back to the framework before asserting: a failing expect
    // under the harness hook would hang instead of failing.
    FlutterError.onError = prior;
    final relevant = errors
        .where((e) => onlyFrom == null || e.contains(onlyFrom))
        .toSet()
        .toList();
    expect(relevant, isEmpty);
    // Background session restores chain further 800 ms token-read timers;
    // unmount and let them run out so none outlives the test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  for (final width in widths) {
    final desktop = width >= 900;
    final w = width.toInt();

    testWidgets('profile @ $w', (tester) async {
      await expectClean(
        tester,
        () => desktop
            ? qaShellHost(const desktop_profile.ProfileScreen())
            : const mobile_profile.ProfileScreen(),
        size: Size(width, 1600),
      );
    });

    testWidgets('settings @ $w', (tester) async {
      await expectClean(
        tester,
        () => desktop
            ? qaShellHost(const DesktopSettingsScreen(embeddedInShell: true))
            : const SettingsScreen(),
        size: Size(width, 1600),
        extraProviders: [qaEmailPreferences()],
      );
    });

    testWidgets('wallet @ $w', (tester) async {
      await expectClean(
        tester,
        () => desktop ? const DesktopWalletScreen() : const WalletHome(),
        size: Size(width, 1400),
        extraProviders: [qaWalletProvider()],
      );
    });

    if (desktop) {
      testWidgets('artwork editor rail @ $w', (tester) async {
        final artworks = ArtworkProvider()..addOrUpdateArtwork(qaArtwork());
        final collab = CollabProvider(api: QaFixtureCollabApi());
        addTearDown(collab.stopInvitePolling);
        await expectClean(
          tester,
          () => qaShellHost(
              const ArtworkEditScreen(artworkId: 'art-a', embedded: true)),
          size: Size(width, 1200),
          artist: true,
          extraProviders: [
            ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
            ChangeNotifierProvider<CollabProvider>.value(value: collab),
          ],
        );
      });
    }
  }

  // Home activity stats use the measured centred extent (Codex P2 on #199).
  // Only the stat tiles are asserted: the Home app bar, quick actions, Web3
  // row and activity header carry pre-existing overflows outside Wave 5A.
  for (final scale in const [1.0, 2.0]) {
    for (final width in const [320.0, 390.0]) {
      testWidgets('home stats @ ${width.toInt()} ${scale}x', (tester) async {
        await expectClean(
          tester,
          () => const HomeScreen(),
          size: Size(width, 2400),
          textScale: scale,
          onlyFrom: 'kubus_stat_card.dart',
        );
      });
    }
  }

  group('200 % text', () {
    testWidgets('profile stats, desktop 1280', (tester) async {
      await expectClean(
        tester,
        () => qaShellHost(const desktop_profile.ProfileScreen()),
        size: const Size(1280, 2400),
        textScale: 2,
      );
    });
    testWidgets('profile stats, mobile 390', (tester) async {
      await expectClean(
        tester,
        () => const mobile_profile.ProfileScreen(),
        size: const Size(390, 2400),
        textScale: 2,
      );
    });
    testWidgets('settings groups, desktop 1440', (tester) async {
      await expectClean(
        tester,
        () => qaShellHost(const DesktopSettingsScreen(embeddedInShell: true)),
        size: const Size(1440, 2400),
        textScale: 2,
        extraProviders: [qaEmailPreferences()],
      );
    });
    testWidgets('wallet token identity, mobile 390', (tester) async {
      await expectClean(
        tester,
        () => const WalletHome(),
        size: const Size(390, 1800),
        textScale: 2,
        extraProviders: [qaWalletProvider()],
      );
    });
    testWidgets('management rail, desktop 1440', (tester) async {
      final artworks = ArtworkProvider()..addOrUpdateArtwork(qaArtwork());
      final collab = CollabProvider(api: QaFixtureCollabApi());
      addTearDown(collab.stopInvitePolling);
      await expectClean(
        tester,
        () => qaShellHost(
            const ArtworkEditScreen(artworkId: 'art-a', embedded: true)),
        size: const Size(1440, 1600),
        textScale: 2,
        artist: true,
        extraProviders: [
          ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
          ChangeNotifierProvider<CollabProvider>.value(value: collab),
        ],
      );
    });
  });
}
