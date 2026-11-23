import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/artwork_comment.dart';
import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/attendance_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/map_deep_link_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/art/art_detail_screen.dart';
import 'package:art_kubus/screens/desktop/art/desktop_artwork_detail_screen.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/collaboration_panel.dart';
import 'package:art_kubus/widgets/detail/artwork_engagement_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/account_session_fixture.dart';
import '../../support/forced_sign_out_fixture.dart';
import '../../support/product_v5_qa_fixtures.dart';
import 'identity_test_wallets.dart';

const _artworkId = 'ownership-fixture';

/// An artwork whose owner is [wallet]; AR is set up halfway so the owner has
/// a "finish setup" action that nobody else gets.
Artwork _artwork(String wallet) => Artwork(
      id: _artworkId,
      title: 'Ownership mural',
      artist: 'Held artist',
      description: 'A mural on a wall.',
      position: const LatLng(46.0569, 14.5058),
      rewards: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      walletAddress: wallet,
      arEnabled: true,
      arStatus: ArtworkArStatus.draft,
      isPublic: true,
    );

/// A comment written by [wallet]; only its author may edit or delete it.
ArtworkComment _comment(String wallet) => ArtworkComment(
      id: 'comment-1',
      artworkId: _artworkId,
      userId: wallet,
      userName: 'Comment author',
      content: 'Hello from the wall',
      createdAt: DateTime(2024),
    );

class _QuietArtworkProvider extends ArtworkProvider {
  _QuietArtworkProvider(this._commentAuthor);

  final String _commentAuthor;

  @override
  Future<void> loadComments(String artworkId, {bool force = false}) async {}

  @override
  Future<void> incrementViewCount(String artworkId) async {}

  @override
  Future<Artwork?> refreshArtworkDetailMetadata(String artworkId) async =>
      getArtworkById(artworkId);

  @override
  List<ArtworkComment> getComments(String artworkId) =>
      <ArtworkComment>[_comment(_commentAuthor)];
}

/// Saved status is read from secure storage, which does not complete under the
/// test binding; the screens only need the hydrate call to return.
class _NoStorageSavedItems extends SavedItemsProvider {
  @override
  Future<void> hydrateSavedStatus({
    required SavedItemType type,
    required Iterable<String> ids,
  }) async {}
}

/// The viewer's side: either a live account session over a profile, or the
/// state a forced sign-out leaves, a held profile and a surviving wallet.
class _Viewer {
  _Viewer(this.profile, this.wallet);
  final ProfileProvider profile;
  final String wallet;
}

final List<CollabProvider> _collabs = <CollabProvider>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizationsEn();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(AccountSessionFixture.end);

  /// A real CollabProvider polls on a periodic timer; it must be stopped
  /// before the test body ends or the binding reports a pending timer.
  Future<void> finish(WidgetTester tester) async {
    for (final collab in _collabs) {
      collab.stopInvitePolling();
    }
    _collabs.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<_Viewer> liveViewer() async {
    final owner = qaOwner(isArtist: true);
    AccountSessionFixture.start(
      accountId: owner.userId!,
      wallet: owner.walletAddress,
    );
    final profile = ProfileProvider()..setCurrentUser(owner);
    return _Viewer(profile, owner.walletAddress);
  }

  Future<_Viewer> forcedSignOutViewer(WidgetTester tester) async =>
      _Viewer(await loadForcedSignOutProfile(tester), forcedSignOutWallet);

  Future<_Viewer> viewer(WidgetTester tester, {required bool live}) =>
      live ? liveViewer() : forcedSignOutViewer(tester);

  Widget app(_Viewer viewer, Widget home) {
    final artworks = _QuietArtworkProvider(viewer.wallet)
      ..seedArtworksForTesting([_artwork(viewer.wallet)]);
    final collab = CollabProvider();
    _collabs.add(collab);
    final wallet = HeldWallet(viewer.wallet);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ArtworkProvider>.value(value: artworks),
        ChangeNotifierProvider<ProfileProvider>.value(value: viewer.profile),
        ChangeNotifierProvider<WalletProvider>.value(value: wallet),
        ChangeNotifierProvider<CollabProvider>.value(value: collab),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<SavedItemsProvider>(
          create: (_) => _NoStorageSavedItems(),
        ),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => MainTabProvider()),
        ChangeNotifierProvider(create: (_) => MapDeepLinkProvider()),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [KubusColorRoles.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The collaboration panel's invite row overflows under the test font, which
  /// is unrelated to who may see it. Other errors still fail the test.
  void ignoreOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  void surface(WidgetTester tester, Size size) {
    ignoreOverflow();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final live in const [true, false]) {
    final state = live ? 'live session' : 'forced sign-out';

    testWidgets('L16 collaboration card owner role, $state', (tester) async {
      surface(tester, const Size(1200, 1600));
      final v = await viewer(tester, live: live);
      await tester.pumpWidget(app(
        v,
        ArtworkCollaboratorsExpandableCard(
          artwork: _artwork(v.wallet),
          initiallyExpanded: true,
        ),
      ));
      await settle(tester);
      final panel =
          tester.widget<CollaborationPanel>(find.byType(CollaborationPanel));
      expect(panel.myRole, live ? 'owner' : isNull);
      await finish(tester);
    });

    testWidgets('L15 engagement card comment menu, $state', (tester) async {
      surface(tester, const Size(1200, 1600));
      final v = await viewer(tester, live: live);
      await tester.pumpWidget(app(
        v,
        SingleChildScrollView(
          child: ArtworkCommentsExpandableCard(
            artwork: _artwork(v.wallet),
            isSignedIn: v.profile.isSignedIn,
          ),
        ),
      ));
      await settle(tester);
      expect(find.text('Hello from the wall'), findsOneWidget);
      expect(
          find.byTooltip(l10n.commonMore), live ? findsWidgets : findsNothing);
      await finish(tester);
    });

    testWidgets('L13/L14 mobile artwork detail, $state', (tester) async {
      surface(tester, const Size(390, 2400));
      final v = await viewer(tester, live: live);
      await tester.pumpWidget(app(v, ArtDetailScreen(artworkId: _artworkId)));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
      await settle(tester);
      expect(find.text('Ownership mural'), findsWidgets);
      expect(
        find.text(l10n.artDetailFinishArSetupAction),
        live ? findsOneWidget : findsNothing,
        reason: 'L13 owner-only AR setup action',
      );
      expect(
        find.byTooltip(l10n.commonMore),
        live ? findsWidgets : findsNothing,
        reason: 'L14 comment edit/delete menu',
      );
      await finish(tester);
    });

    testWidgets('L17 desktop artwork detail AR manager button, $state',
        (tester) async {
      surface(tester, const Size(1440, 1800));
      final v = await viewer(tester, live: live);
      await tester.pumpWidget(
        app(v, const DesktopArtworkDetailScreen(artworkId: _artworkId)),
      );
      await settle(tester);
      expect(find.text('Ownership mural'), findsWidgets);
      expect(
        find.widgetWithIcon(OutlinedButton, Icons.qr_code_2),
        live ? findsOneWidget : findsNothing,
      );
      await finish(tester);
    });
  }
}
