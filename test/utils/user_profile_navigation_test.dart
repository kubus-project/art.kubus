import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/models/user.dart' as identity;
import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/public_entity_takeover_provider.dart';
import 'package:art_kubus/screens/community/user_profile_screen.dart'
    as visitor;
import 'package:art_kubus/screens/desktop/community/desktop_profile_screen.dart'
    as desktop_owner;
import 'package:art_kubus/screens/desktop/community/desktop_user_profile_screen.dart'
    as desktop_visitor;
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/share_deep_link_navigation.dart';
import 'package:art_kubus/utils/user_profile_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _accountId = '11111111-1111-4111-8111-111111111111';
const _wallet = 'ArtistWallet111111111111111111111111111111111';

void main() {
  testWidgets('username-only entry resolves the account before owner routing',
      (tester) async {
    final profileProvider = ProfileProvider()..setCurrentUser(_ownerProfile());
    final tabProvider = MainTabProvider()..setIndex(2);
    final resolved = ProfileCriticalPackage(
      user: const identity.User(
        id: _accountId,
        name: 'Current Artist',
        username: 'current_artist',
        bio: '',
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
        isFollowing: false,
        isVerified: false,
        joinedDate: '',
      ),
      achievementProgress: const [],
      achievementDefinitions: const [],
      publicStats: const {},
      fetchedAt: DateTime.utc(2026),
      isComplete: true,
    );
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<MainTabProvider>.value(value: tabProvider),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => UserProfileNavigation.openCommunityOverlay(
                context,
                userId: '',
                username: 'current_artist',
                initialCriticalPackageFuture: Future.value(resolved),
              ),
              child: const Text('Open resolved profile'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open resolved profile'));
    await tester.pump();
    expect(tabProvider.index, 4);
    expect(find.byType(visitor.UserProfileScreen), findsNothing);
  });

  testWidgets('current account wallet opens the mobile Profile tab',
      (tester) async {
    final profileProvider = ProfileProvider();
    profileProvider.setCurrentUser(_ownerProfile());
    final tabProvider = MainTabProvider()..setIndex(2);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ChangeNotifierProvider<MainTabProvider>.value(value: tabProvider),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => UserProfileNavigation.open(
                    context,
                    userId: _wallet,
                  ),
                  child: const Text('Open own profile'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open own profile'));
    await tester.pump();

    expect(tabProvider.index, 4);
    expect(find.byType(visitor.UserProfileScreen), findsNothing);
  });

  testWidgets('current account ID opens the desktop shell owner profile',
      (tester) async {
    final profileProvider = ProfileProvider();
    profileProvider.setCurrentUser(_ownerProfile());
    Widget? pushedScreen;

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>.value(
        value: profileProvider,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: DesktopShellScope(
              pushScreen: (screen) => pushedScreen = screen,
              popScreen: () {},
              navigateToRoute: (_) {},
              openNotifications: () {},
              openFunctionsPanel: (_, {content}) {},
              setFunctionsPanelContent: (_) {},
              closeFunctionsPanel: () {},
              canPop: false,
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => UserProfileNavigation.open(
                      context,
                      userId: _accountId,
                    ),
                    child: const Text('Open own profile'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open own profile'));
    await tester.pump();

    expect(pushedScreen, isA<desktop_owner.ProfileScreen>());
    expect(pushedScreen, isNot(isA<desktop_visitor.UserProfileScreen>()));
  });

  testWidgets('display name matching never grants owner navigation',
      (tester) async {
    final profileProvider = ProfileProvider();
    profileProvider.setCurrentUser(_ownerProfile());
    Widget? pushedScreen;

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>.value(
        value: profileProvider,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 800)),
            child: DesktopShellScope(
              pushScreen: (screen) => pushedScreen = screen,
              popScreen: () {},
              navigateToRoute: (_) {},
              openNotifications: () {},
              openFunctionsPanel: (_, {content}) {},
              setFunctionsPanelContent: (_) {},
              closeFunctionsPanel: () {},
              canPop: false,
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => UserProfileNavigation.open(
                      context,
                      userId: 'Current Artist',
                    ),
                    child: const Text('Open visitor profile'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open visitor profile'));
    await tester.pump();

    expect(pushedScreen, isA<desktop_visitor.UserProfileScreen>());
    expect(pushedScreen, isNot(isA<desktop_owner.ProfileScreen>()));
  });

  Future<Widget?> openSharedProfileOnDesktop(
    WidgetTester tester, {
    required PublicEntityTakeoverProvider takeover,
  }) async {
    final profileProvider = ProfileProvider()..setCurrentUser(_ownerProfile());
    Widget? pushedScreen;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ChangeNotifierProvider<PublicEntityTakeoverProvider>.value(
            value: takeover,
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: DesktopShellScope(
              pushScreen: (screen) => pushedScreen = screen,
              popScreen: () {},
              navigateToRoute: (_) {},
              openNotifications: () {},
              openFunctionsPanel: (_, {content}) {},
              setFunctionsPanelContent: (_) {},
              closeFunctionsPanel: () {},
              canPop: false,
              child: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => ShareDeepLinkNavigation.open(
                      context,
                      const ShareDeepLinkTarget(
                        type: ShareEntityType.profile,
                        id: _accountId,
                        localeCode: 'sl',
                      ),
                    ),
                    child: const Text('Open shared profile'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open shared profile'));
    await tester.pump();
    return pushedScreen;
  }

  testWidgets(
      'canonical public entry of the signed-in account opens the public profile',
      (tester) async {
    final takeover = PublicEntityTakeoverProvider()
      ..seed(
        initialUri: Uri.parse('/sl/profili/$_accountId'),
        target: const ShareDeepLinkTarget(
          type: ShareEntityType.profile,
          id: _accountId,
          localeCode: 'sl',
        ),
      );
    expect(takeover.target?.path, '/sl/profili/$_accountId');

    final pushedScreen =
        await openSharedProfileOnDesktop(tester, takeover: takeover);

    // Only the public screen wraps the loaded profile in
    // PublicEntityTakeoverReady, so only it can retire the SSR frame.
    expect(pushedScreen, isA<desktop_visitor.UserProfileScreen>());
    expect(
      (pushedScreen! as desktop_visitor.UserProfileScreen).userId,
      _accountId,
    );
  });

  testWidgets('shared own-profile link without a public entry keeps owner view',
      (tester) async {
    final pushedScreen = await openSharedProfileOnDesktop(
      tester,
      takeover: PublicEntityTakeoverProvider(),
    );

    expect(pushedScreen, isA<desktop_owner.ProfileScreen>());
  });

  testWidgets('an upper-case UUID still reaches the owner profile',
      (tester) async {
    const lowerId = 'abcdef12-3456-4abc-8def-0123456789ab';
    final owner = _ownerProfile(userId: lowerId);
    final screen = await _openDesktop(tester, owner, lowerId.toUpperCase());

    expect(screen, isA<desktop_owner.ProfileScreen>());
  });

  testWidgets('wallet addresses stay case-sensitive for ownership',
      (tester) async {
    final screen =
        await _openDesktop(tester, _ownerProfile(), _wallet.toLowerCase());

    expect(screen, isA<desktop_visitor.UserProfileScreen>());
  });
}

Future<Widget?> _openDesktop(
  WidgetTester tester,
  UserProfile owner,
  String targetId,
) async {
  final profileProvider = ProfileProvider()..setCurrentUser(owner);
  Widget? pushedScreen;
  await tester.pumpWidget(
    ChangeNotifierProvider<ProfileProvider>.value(
      value: profileProvider,
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1440, 900)),
          child: DesktopShellScope(
            pushScreen: (screen) => pushedScreen = screen,
            popScreen: () {},
            navigateToRoute: (_) {},
            openNotifications: () {},
            openFunctionsPanel: (_, {content}) {},
            setFunctionsPanelContent: (_) {},
            closeFunctionsPanel: () {},
            canPop: false,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      UserProfileNavigation.open(context, userId: targetId),
                  child: const Text('Open profile'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open profile'));
  await tester.pump();
  return pushedScreen;
}

UserProfile _ownerProfile({String userId = _accountId}) => UserProfile(
      id: _wallet,
      userId: userId,
      walletAddress: _wallet,
      publicActorId: 'public:$_wallet',
      username: 'current_artist',
      displayName: 'Current Artist',
      bio: '',
      avatar: '',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
