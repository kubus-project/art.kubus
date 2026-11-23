import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_home_screen.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/widgets/artist_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/forced_sign_out_fixture.dart';
import '../../support/product_surface_harness.dart';
import '../../support/product_v5_qa_fixtures.dart';
import 'identity_test_wallets.dart';

/// Home shows the account (artist badge, wallet chip, "Your stats", the
/// artist-shaped layout) only while a session is live. After a forced sign-out
/// the stored wallet's profile is still held, and none of it may show.
///
/// Leaks L5-L11 of the identity map: badges, wallet chip, stats block and role
/// layout, on mobile and desktop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  // The chip prints a shortened copy of the address, so the copy button is the
  // stable marker for "the wallet address is shown as identity".
  final copyChip = find.byIcon(Icons.copy_rounded);

  Future<ProfileProvider?> pumpHome(
    WidgetTester tester, {
    required bool desktop,
    required bool signedIn,
    RecordingStatsProvider? stats,
  }) async {
    // pumpProductSurface collects render errors through FlutterError.onError; a
    // failing expect while it is installed hangs the test, so it is handed
    // back before the caller expects anything.
    final prior = FlutterError.onError;
    addTearDown(() => FlutterError.onError = prior);
    final size = desktop ? const Size(1440, 4000) : const Size(390, 2400);
    final child =
        desktop ? qaShellHost(const DesktopHomeScreen()) : const HomeScreen();
    if (signedIn) {
      await pumpProductSurface(
        tester,
        child: child,
        size: size,
        signedInProfile: qaOwner(isArtist: true),
        extraProviders: [
          ...heldWalletProviders(qaOwner().walletAddress),
          if (stats != null)
            ChangeNotifierProvider<StatsProvider>.value(value: stats),
        ],
      );
      FlutterError.onError = prior;
      return null;
    }
    final held = await loadForcedSignOutProfile(tester);
    await pumpProductSurface(
      tester,
      child: child,
      size: size,
      profileProvider: held,
      extraProviders: [
        ...heldWalletProviders(forcedSignOutWallet),
        if (stats != null)
          ChangeNotifierProvider<StatsProvider>.value(value: stats),
      ],
    );
    FlutterError.onError = prior;
    return held;
  }

  double dy(Finder finder) => finder.evaluate().isEmpty
      ? double.nan
      : (finder.evaluate().first.renderObject! as RenderBox)
          .localToGlobal(Offset.zero)
          .dy;

  for (final desktop in const [false, true]) {
    final name = desktop ? 'desktop home' : 'mobile home';
    final leak = desktop ? 'L7/L8/L10/L11b' : 'L5/L6/L9/L11a';

    group('$name ($leak)', () {
      final statsTitle =
          desktop ? l10n.desktopHomeYourActivityTitle : l10n.homeYourStatsTitle;

      testWidgets('with a live session shows the artist account',
          (tester) async {
        final stats = RecordingStatsProvider();
        await pumpHome(tester, desktop: desktop, signedIn: true, stats: stats);
        expect(find.byType(ArtistBadge), findsWidgets, reason: 'artist badge');
        expect(copyChip, findsWidgets, reason: 'wallet chip');
        expect(find.text(l10n.homeNoStatsAvailableTitle), findsNothing);
        expect(stats.requestedEntityIds, contains(qaOwner().walletAddress),
            reason: 'the signed-in wallet is queried for its stats');
        // Artists get the working dashboard before the quick actions.
        expect(
          dy(find.text(statsTitle)),
          lessThan(dy(find.text(l10n.homeQuickActionsTitle))),
          reason: 'dashboard-first layout for an artist',
        );
      });

      testWidgets('after a forced sign-out shows no artist badge',
          (tester) async {
        final held = await pumpHome(tester, desktop: desktop, signedIn: false);
        expect(held!.isSignedIn, isFalse);
        expect(find.byType(ArtistBadge), findsNothing);
      });

      testWidgets('after a forced sign-out shows no wallet address chip',
          (tester) async {
        await pumpHome(tester, desktop: desktop, signedIn: false);
        expect(copyChip, findsNothing);
      });

      testWidgets(
          'after a forced sign-out asks for no stats of the held wallet',
          (tester) async {
        final stats = RecordingStatsProvider();
        await pumpHome(tester, desktop: desktop, signedIn: false, stats: stats);
        expect(stats.requestedEntityIds, isNot(contains(forcedSignOutWallet)));
        if (!desktop) {
          expect(find.text(l10n.homeNoStatsAvailableTitle), findsOneWidget);
        }
      });

      testWidgets('after a forced sign-out keeps the guest layout order',
          (tester) async {
        await pumpHome(tester, desktop: desktop, signedIn: false);
        expect(
          dy(find.text(statsTitle)),
          greaterThan(dy(find.text(l10n.homeQuickActionsTitle))),
          reason: 'a role-shaped layout needs a live account',
        );
      });
    });
  }
}
