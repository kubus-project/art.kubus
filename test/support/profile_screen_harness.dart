import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/app_refresh_provider.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/attestation_provider.dart';
import 'package:art_kubus/providers/collectibles_provider.dart';
import 'package:art_kubus/providers/config_provider.dart';
import 'package:art_kubus/providers/institution_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/promotion_provider.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/community_interactions_provider.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/screens/community/profile_screen.dart'
    as mobile_owner;
import 'package:art_kubus/screens/community/user_profile_screen.dart'
    as mobile_public;
import 'package:art_kubus/screens/desktop/community/desktop_profile_screen.dart'
    as desktop_owner;
import 'package:art_kubus/screens/desktop/community/desktop_user_profile_screen.dart'
    as desktop_public;
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/utils/user_profile_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'profile_fixtures.dart';

/// Which real profile surface a test or QA capture should render.
enum ProfileSurface {
  mobilePublic,
  desktopPublic,
  communityOverlay,
  mobileOwner,
  desktopOwner,

  /// The owner profile as the desktop shell pushes it: inside a poppable
  /// [DesktopShellScope], where it owns the single sub-screen header.
  desktopOwnerInShell,
}

/// Renders the **actual** profile screens against deterministic fixtures.
///
/// Data reaches the screens only through their existing constructor test seams
/// (`initialCriticalPackage` / `initialExtendedPackageFuture`) and through
/// `ProfileProvider.setCurrentUser`, both of which are ordinary production
/// APIs. No authentication check is disabled, stubbed, or bypassed.
///
/// Every layout/render error fails the test. The former allow-list for the
/// shared stat tile is gone: Wave 5A sizes stat grids from the measured tile
/// extent, so a stat-card overflow is a regression again.
final List<FlutterErrorDetails> unexpectedRenderErrors =
    <FlutterErrorDetails>[];

Future<void> pumpProfileSurface(
  WidgetTester tester, {
  required ProfileSurface surface,
  User? user,
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  bool canonicalPublicEntry = false,

  /// Injected DAO state (for example an approved role review); a fresh
  /// [DAOProvider] otherwise.
  DAOProvider? daoProvider,

  /// Paint the theme ground under the screen, as the app shell does, so a
  /// screenshot of a transparent screen is not composited on white.
  bool paintGround = false,
}) async {
  final resolvedUser = user ?? ProfileFixtures.user();

  unexpectedRenderErrors.clear();
  final previousOnError = FlutterError.onError;
  FlutterError.onError = unexpectedRenderErrors.add;
  addTearDown(() {
    FlutterError.onError = previousOnError;
    // Re-assert after the widget tree is finalized so dispose-time errors can
    // never be silently swallowed by the capture hook above.
    expectNoUnexpectedRenderErrors();
  });

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final themeProvider = ThemeProvider();
  final profileProvider = ProfileProvider();
  if (surface == ProfileSurface.mobileOwner ||
      surface == ProfileSurface.desktopOwner ||
      surface == ProfileSurface.desktopOwnerInShell) {
    profileProvider.setCurrentUser(_ownerProfileFrom(resolvedUser));
  }

  final child = _surfaceWidget(
    surface,
    resolvedUser,
    canonicalPublicEntry: canonicalPublicEntry,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        if (daoProvider != null)
          ChangeNotifierProvider<DAOProvider>.value(value: daoProvider)
        else
          ChangeNotifierProvider<DAOProvider>(create: (_) => DAOProvider()),
        ChangeNotifierProvider<StatsProvider>(create: (_) => StatsProvider()),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ChangeNotifierProvider<WalletProvider>(create: (_) => WalletProvider()),
        ChangeNotifierProvider<Web3Provider>(create: (_) => Web3Provider()),
        ChangeNotifierProvider<TaskProvider>(create: (_) => TaskProvider()),
        ChangeNotifierProvider<ArtworkProvider>(
            create: (_) => ArtworkProvider()),
        ChangeNotifierProvider<SavedItemsProvider>(
            create: (_) => SavedItemsProvider()),
        ChangeNotifierProvider<CommunityInteractionsProvider>(
            create: (_) => CommunityInteractionsProvider()),
        ChangeNotifierProvider<AppRefreshProvider>(
            create: (_) => AppRefreshProvider()),
        ChangeNotifierProvider<AttestationProvider>(
            create: (_) => AttestationProvider()),
        ChangeNotifierProvider<CollectiblesProvider>(
            create: (_) => CollectiblesProvider()),
        ChangeNotifierProvider<ConfigProvider>(create: (_) => ConfigProvider()),
        ChangeNotifierProvider<InstitutionProvider>(
            create: (_) => InstitutionProvider()),
        ChangeNotifierProvider<NotificationProvider>(
            create: (_) => NotificationProvider()),
        ChangeNotifierProvider<PromotionProvider>(
            create: (_) => PromotionProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: brightness == Brightness.dark
            ? themeProvider.darkTheme
            : themeProvider.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: paintGround
              ? Builder(
                  builder: (context) => ColoredBox(
                    color: KubusColorRoles.of(context).ground,
                    child: child,
                  ),
                )
              : child,
        ),
      ),
    ),
  );

  // Two pumps let the injected critical package apply and the entry animation
  // settle without ever waiting on a network future.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // The profile screens open a socket connection in `initState`, which schedules
  // an 800 ms auth-token timer. Drain it here so the fake-async zone does not
  // report a pending timer for unrelated production behaviour.
  await tester.pump(const Duration(seconds: 1));

  // Hand error reporting back to the test framework before the caller's
  // assertions run: a failing expect under the capture hook hangs the test
  // instead of failing it. Later render errors then fail the test directly.
  FlutterError.onError = previousOnError;
}

/// Fails when the surface produced any layout/render error.
void expectNoUnexpectedRenderErrors() {
  expect(
    unexpectedRenderErrors.map((e) => e.exceptionAsString()).toList(),
    isEmpty,
  );
}

Widget _surfaceWidget(
  ProfileSurface surface,
  User user, {
  bool canonicalPublicEntry = false,
}) {
  final critical = ProfileFixtures.critical(user: user);
  final extended = Future<ProfileExtendedPackage?>.value(
    ProfileFixtures.extended(),
  );

  switch (surface) {
    case ProfileSurface.mobilePublic:
      return mobile_public.UserProfileScreen(
        userId: user.id,
        initialCriticalPackage: critical,
        initialExtendedPackageFuture: extended,
      );
    case ProfileSurface.desktopPublic:
      {
        final screen = desktop_public.UserProfileScreen(
          userId: user.id,
          initialCriticalPackage: critical,
          initialExtendedPackageFuture: extended,
        );
        final publicEntryScreen = canonicalPublicEntry
            ? DesktopShellScope(
                pushScreen: (_) {},
                popScreen: () {},
                navigateToRoute: (_) {},
                openNotifications: () {},
                openFunctionsPanel: (_, {content}) {},
                setFunctionsPanelContent: (_) {},
                closeFunctionsPanel: () {},
                canPop: false,
                isCanonicalPublicEntry: true,
                child: screen,
              )
            : screen;
        return DesktopProfilePresentationScope(
          presentation: DesktopProfilePresentation.shellSubScreen,
          child: publicEntryScreen,
        );
      }
    case ProfileSurface.communityOverlay:
      return DesktopProfilePresentationScope(
        presentation: DesktopProfilePresentation.communityOverlay,
        child: desktop_public.UserProfileScreen(
          userId: user.id,
          initialCriticalPackage: critical,
          initialExtendedPackageFuture: extended,
        ),
      );
    case ProfileSurface.mobileOwner:
      return const mobile_owner.ProfileScreen();
    case ProfileSurface.desktopOwner:
      return const desktop_owner.ProfileScreen();
    case ProfileSurface.desktopOwnerInShell:
      return DesktopShellScope(
        pushScreen: (_) {},
        popScreen: () {},
        navigateToRoute: (_) {},
        openNotifications: () {},
        openFunctionsPanel: (_, {content}) {},
        setFunctionsPanelContent: (_) {},
        closeFunctionsPanel: () {},
        canPop: true,
        child: const Material(
          type: MaterialType.transparency,
          child: desktop_owner.ProfileScreen(),
        ),
      );
  }
}

UserProfile _ownerProfileFrom(User user) {
  return UserProfile(
    id: user.id,
    userId: user.id,
    walletAddress: user.id,
    username: user.username,
    displayName: user.name,
    bio: user.bio,
    avatar: user.profileImageUrl ?? '',
    coverImage: user.coverImageUrl,
    isArtist: user.isArtist,
    isInstitution: user.isInstitution,
    createdAt: ProfileFixtures.fetchedAt,
    updatedAt: ProfileFixtures.fetchedAt,
  );
}
