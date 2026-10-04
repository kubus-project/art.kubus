import 'package:art_kubus/features/analytics/analytics_view_models.dart';
import 'package:art_kubus/features/analytics/widgets/analytics_overview_grid.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/screens/art/artwork_edit_screen.dart';
import 'package:art_kubus/screens/desktop/community/desktop_profile_screen.dart'
    as desktop_profile;
import 'package:art_kubus/screens/desktop/components/desktop_widgets.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_governance_hub_screen.dart';
import 'package:art_kubus/screens/desktop/web3/desktop_wallet_screen.dart';
import 'package:art_kubus/screens/web3/artist/artist_studio.dart';
import 'package:art_kubus/screens/web3/institution/institution_hub.dart';
import 'package:art_kubus/screens/web3/wallet/wallet_home.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:art_kubus/widgets/artist_badge.dart';
import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:art_kubus/widgets/common/kubus_context_icon.dart';
import 'package:art_kubus/widgets/empty_state_card.dart';
import 'package:art_kubus/widgets/institution_badge.dart';
import 'package:art_kubus/widgets/wallet_custody_status_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/product_surface_harness.dart';
import '../support/product_v5_qa_fixtures.dart';

/// Wave 5A-S semantic contract: one semantic idea, one primary expression.
/// See docs/design/PRODUCT_V5_SEMANTIC_VISUAL_SYSTEM.md.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
        'Artist Studio_onboarding_completed': true,
        'Institution Hub_onboarding_completed': true,
        'DAO_onboarding_completed': true,
      }));

  group('analytics overview', () {
    const cards = <AnalyticsOverviewCardData>[
      AnalyticsOverviewCardData(
        metricId: 'viewsReceived',
        title: 'Artwork views received from the public map',
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
        title: 'Likes received on published artworks',
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
    ];

    Future<void> pumpGrid(WidgetTester tester, Size size, double scale) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AnalyticsOverviewGrid(
                cards: cards,
                isLoading: false,
                selectedMetricId: 'viewsReceived',
                onMetricSelected: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
    }

    for (final size in const [
      Size(320, 900),
      Size(390, 900),
      Size(1440, 900)
    ]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        testWidgets(
            'no overflow at ${size.width.toInt()} px, ${scale}x text, '
            'lead stays dominant', (tester) async {
          await pumpGrid(tester, size, scale);
          expect(tester.takeException(), isNull);

          // The lead value is the largest figure; supporting values smaller.
          final lead = tester.widget<Text>(find.text('12,480'));
          final support = tester.widget<Text>(find.text('1,284'));
          expect(lead.style!.fontSize!, greaterThan(support.style!.fontSize!));
          // Every value is fully on screen, never pushed out or clipped away.
          for (final value in const ['12,480', '1,284', '3,912', '42']) {
            final rect = tester.getRect(find.text(value));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(rect.width, greaterThan(0));
          }
        });
      }
    }

    testWidgets('one identity layer per metric, no icon tiles', (tester) async {
      await pumpGrid(tester, const Size(1440, 900), 1);
      expect(find.byType(KubusContextIcon), findsNothing);
      // The lead's glyph is its only icon; supporting metrics use a colour
      // key, not a second copy of their symbol.
      expect(find.byType(KubusGhostGlyph), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.people_outline), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('analytics_metric_key')),
        findsNWidgets(3),
      );
    });
  });

  group('role badges', () {
    Future<void> pumpBadge(WidgetTester tester, Widget badge) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: Center(child: badge)),
      ));
    }

    testWidgets('labelled pills say the role once, in words', (tester) async {
      await pumpBadge(tester, const ArtistBadge());
      expect(find.byType(Icon), findsNothing);
      expect(find.text('ARTIST'), findsOneWidget);
      await pumpBadge(tester, const InstitutionBadge());
      expect(find.byType(Icon), findsNothing);
      expect(find.text('INSTITUTION'), findsOneWidget);
    });

    testWidgets('icon-only badges still announce the role', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBadge(tester, const ArtistBadge(iconOnly: true));
      expect(find.bySemanticsLabel('Artist'), findsOneWidget);
      await pumpBadge(tester, const InstitutionBadge(iconOnly: true));
      expect(find.bySemanticsLabel('Institution'), findsOneWidget);
      handle.dispose();
    });
  });

  group('screen compositions', () {
    /// Lets the screens' storage/socket timers lapse in fake time.
    Future<void> drain(WidgetTester tester) async {
      SocketService().disconnect();
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    Future<AppLocalizations> pumpScreen(
      WidgetTester tester,
      Widget screen, {
      required Size size,
      UserProfile? signedIn,
      List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
    }) async {
      final prior = FlutterError.onError;
      await pumpProductSurface(
        tester,
        child: screen,
        size: size,
        signedInProfile: signedIn,
        extraProviders: extraProviders,
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      // A failing expect under the harness's error collector would hang.
      FlutterError.onError = prior;
      return AppLocalizations.of(tester.element(find.byType(Text).first))!;
    }

    int textCount(WidgetTester tester, String value) => tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => (t.data ?? '').toLowerCase() == value.toLowerCase())
        .length;

    testWidgets(
        'desktop wallet: one signing state, one Refresh, one custody panel',
        (tester) async {
      final l10n = await pumpScreen(tester, const DesktopWalletScreen(),
          size: const Size(1440, 1000),
          signedIn: qaOwner(),
          extraProviders: [qaWalletProvider()]);
      expect(textCount(tester, l10n.walletSessionSignerMissing), 1);
      expect(textCount(tester, l10n.commonRefresh), 1);
      expect(find.byType(WalletCustodyStatusPanel), findsOneWidget);
      await drain(tester);
    });

    testWidgets('mobile wallet: the balance hero does not list the tokens',
        (tester) async {
      await pumpScreen(tester, const WalletHome(),
          size: const Size(390, 2400),
          signedIn: qaOwner(),
          extraProviders: [qaWalletProvider()]);
      final tokens =
          find.byKey(const ValueKey<String>('wallet_tokens_section'));
      expect(tokens, findsOneWidget);
      // The impostor token appears once, in the inventory, not the hero.
      expect(find.text('Not kubit'), findsOneWidget);
      expect(
        find.descendant(of: tokens, matching: find.text('Not kubit')),
        findsOneWidget,
      );
      await drain(tester);
    });

    testWidgets('studio (mobile): one review CTA for the locked state',
        (tester) async {
      final l10n = await pumpScreen(tester, const ArtistStudio(),
          size: const Size(390, 1300), signedIn: qaOwner(isArtist: true));
      expect(textCount(tester, l10n.artistStudioCtaApplyForDaoReview), 1);
      expect(find.text(l10n.artistStudioLockedTitle), findsOneWidget);
      await drain(tester);
    });

    testWidgets('institution hub (mobile): one review CTA, lock is named',
        (tester) async {
      final l10n = await pumpScreen(tester, const InstitutionHub(),
          size: const Size(390, 1300), signedIn: qaOwner(isInstitution: true));
      expect(textCount(tester, l10n.institutionHubApplyForReviewAction), 1);
      expect(find.text(l10n.institutionHubLockedTitle), findsOneWidget);
      // The page title is said by the dashboard header, not again by the bar.
      expect(textCount(tester, l10n.navigationScreenInstitutionHub), 1);
      await drain(tester);
    });

    testWidgets('artwork editor: one explicit cover upload action',
        (tester) async {
      final artworks = ArtworkProvider()..addOrUpdateArtwork(qaArtwork());
      final l10n = await pumpScreen(
        tester,
        qaShellHost(const ArtworkEditScreen(
            artworkId: 'art-a', chrome: ArtworkEditChrome.workspace)),
        size: const Size(1440, 1000),
        signedIn: qaOwner(isArtist: true),
        extraProviders: [
          ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
          ChangeNotifierProvider<CollabProvider>(
            create: (_) => CollabProvider(api: QaFixtureCollabApi()),
          ),
        ],
      );
      expect(find.text(l10n.mapMarkerDialogUploadCover), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == l10n.commonEdit),
        findsNothing,
      );
      final collab = Provider.of<CollabProvider>(
        tester.element(find.byType(ArtworkEditScreen)),
        listen: false,
      );
      collab.stopInvitePolling();
      await drain(tester);
    });

    testWidgets('DAO onboarding: the flow title is not repeated three times',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final l10n = await pumpScreen(tester, const DesktopGovernanceHubScreen(),
          size: const Size(1440, 1000), signedIn: qaOwner());
      expect(textCount(tester, l10n.daoHubAppBarTitle), lessThanOrEqualTo(2));
      await drain(tester);
    });

    testWidgets('desktop profile: empty states are not cards inside cards',
        (tester) async {
      await pumpScreen(
        tester,
        qaShellHost(const desktop_profile.ProfileScreen()),
        size: const Size(1440, 1500),
        signedIn: qaOwner(isArtist: true),
      );
      expect(find.byType(EmptyStateCard), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(DesktopCard),
          matching: find.byType(EmptyStateCard),
        ),
        findsNothing,
      );
      await drain(tester);
    });
  });
}
