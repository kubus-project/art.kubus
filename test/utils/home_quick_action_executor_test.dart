import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/core/shell_routes.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/screens/activity/advanced_analytics_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/utils/home/home_quick_action_executor.dart';
import 'package:art_kubus/utils/home/home_quick_action_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _localizedApp({
  required Widget home,
  required NavigationProvider navigationProvider,
  MainTabProvider? tabProvider,
  ProfileProvider? profileProvider,
  WalletProvider? walletProvider,
  Map<String, WidgetBuilder>? routes,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NavigationProvider>.value(
        value: navigationProvider,
      ),
      if (tabProvider != null)
        ChangeNotifierProvider<MainTabProvider>.value(value: tabProvider),
      if (profileProvider != null)
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
      if (walletProvider != null)
        ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routes: routes ?? const <String, WidgetBuilder>{},
      home: home,
    ),
  );
}

UserProfile _testUserProfile() {
  return UserProfile(
    id: 'user-1',
    walletAddress: 'wallet-1',
    username: 'artist',
    displayName: 'Artist',
    bio: '',
    avatar: '',
    createdAt: DateTime.utc(2026, 4, 19),
    updatedAt: DateTime.utc(2026, 4, 19),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('mobile tab quick action selects tab and tracks visit',
      (tester) async {
    final navigationProvider = NavigationProvider();
    final tabProvider = MainTabProvider()..setIndex(3);
    bool? result;

    await tester.pumpWidget(
      _localizedApp(
        navigationProvider: navigationProvider,
        tabProvider: tabProvider,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await HomeQuickActionExecutor.execute(
                context,
                'map',
                source: HomeQuickActionSurface.mobileHome,
              );
            },
            child: const Text('run'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pump();

    expect(result, isTrue);
    expect(tabProvider.index, 0);
    expect(navigationProvider.visitCounts['map'], 1);
  });

  testWidgets('desktop settings and stats use shell subscreens',
      (tester) async {
    final navigationProvider = NavigationProvider();
    final walletProvider = WalletProvider(deferInit: true)
      ..setCurrentWalletAddressForTesting('wallet-1');
    final pushedScreens = <Widget>[];

    await tester.pumpWidget(
      _localizedApp(
        navigationProvider: navigationProvider,
        walletProvider: walletProvider,
        home: DesktopShellScope(
          pushScreen: pushedScreens.add,
          popScreen: () {},
          navigateToRoute: (_) {},
          openNotifications: () {},
          openFunctionsPanel: (_, {content}) {},
          setFunctionsPanelContent: (_) {},
          closeFunctionsPanel: () {},
          canPop: false,
          child: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () async {
                    await HomeQuickActionExecutor.execute(
                      context,
                      'settings',
                      source: HomeQuickActionSurface.desktopHome,
                    );
                  },
                  child: const Text('settings'),
                ),
                TextButton(
                  onPressed: () async {
                    await HomeQuickActionExecutor.execute(
                      context,
                      'stats',
                      source: HomeQuickActionSurface.desktopHome,
                    );
                  },
                  child: const Text('stats'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('settings'));
    await tester.pump();
    await tester.tap(find.text('stats'));
    await tester.pump();

    expect(pushedScreens, hasLength(2));
    expect(pushedScreens[0], isA<DesktopSubScreen>());
    expect((pushedScreens[0] as DesktopSubScreen).child,
        isA<DesktopSettingsScreen>());
    expect(pushedScreens[1], isA<DesktopSubScreen>());
    expect((pushedScreens[1] as DesktopSubScreen).child,
        isA<AdvancedAnalyticsScreen>());
    expect(navigationProvider.visitCounts['settings'], 1);
    expect(navigationProvider.visitCounts['stats'], 1);
  });

  testWidgets('unsupported AR action is explicit and not visit-tracked',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final navigationProvider = NavigationProvider();
      bool? result;

      await tester.pumpWidget(
        _localizedApp(
          navigationProvider: navigationProvider,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await HomeQuickActionExecutor.execute(
                  context,
                  'ar',
                  source: HomeQuickActionSurface.mobileHome,
                );
              },
              child: const Text('ar'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ar'));
      await tester.pump();

      expect(result, isFalse);
      expect(find.text('AR experience'), findsOneWidget);
      expect(navigationProvider.visitCounts.containsKey('ar'), isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('signed-in capability blocks profile when unmet', (tester) async {
    final navigationProvider = NavigationProvider();
    final profileProvider = ProfileProvider();
    bool? result;

    await tester.pumpWidget(
      _localizedApp(
        navigationProvider: navigationProvider,
        profileProvider: profileProvider,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await HomeQuickActionExecutor.execute(
                  context,
                  'profile',
                  source: HomeQuickActionSurface.desktopHome,
                );
              },
              child: const Text('profile'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('profile'));
    await tester.pump();

    expect(result, isFalse);
    expect(find.text('Sign in to continue.'), findsOneWidget);
    expect(navigationProvider.visitCounts.containsKey('profile'), isFalse);
  });

  testWidgets('wallet capability blocks analytics when unmet', (tester) async {
    final navigationProvider = NavigationProvider();
    final walletProvider = WalletProvider(deferInit: true);
    bool? result;

    await tester.pumpWidget(
      _localizedApp(
        navigationProvider: navigationProvider,
        walletProvider: walletProvider,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await HomeQuickActionExecutor.execute(
                  context,
                  'analytics',
                  source: HomeQuickActionSurface.desktopHome,
                );
              },
              child: const Text('analytics'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('analytics'));
    await tester.pump();

    expect(result, isFalse);
    expect(find.text('Connect your wallet to continue.'), findsOneWidget);
    expect(navigationProvider.visitCounts.containsKey('analytics'), isFalse);
  });

  testWidgets('satisfied signed-in capability tracks successful action',
      (tester) async {
    final navigationProvider = NavigationProvider();
    final profileProvider = ProfileProvider()
      ..setCurrentUser(_testUserProfile());
    final pushedScreens = <Widget>[];
    bool? result;

    await tester.pumpWidget(
      _localizedApp(
        navigationProvider: navigationProvider,
        profileProvider: profileProvider,
        home: DesktopShellScope(
          pushScreen: pushedScreens.add,
          popScreen: () {},
          navigateToRoute: (_) {},
          openNotifications: () {},
          openFunctionsPanel: (_, {content}) {},
          setFunctionsPanelContent: (_) {},
          closeFunctionsPanel: () {},
          canPop: false,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await HomeQuickActionExecutor.execute(
                  context,
                  'profile',
                  source: HomeQuickActionSurface.desktopHome,
                );
              },
              child: const Text('profile success'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('profile success'));
    await tester.pump();

    expect(result, isTrue);
    expect(pushedScreens, hasLength(1));
    expect(navigationProvider.visitCounts['profile'], 1);
  });

  for (final entry in <String, String>{
    'map': ShellRoutes.map,
    'community': ShellRoutes.community,
  }.entries) {
    testWidgets(
      'legacy wrapper routes ${entry.key} tab action through shell alias '
      'without a local MainTabProvider',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final navigationProvider = NavigationProvider();
        bool? result;

        await tester.pumpWidget(
          _localizedApp(
            navigationProvider: navigationProvider,
            routes: <String, WidgetBuilder>{
              entry.value: (_) => Scaffold(body: Text('${entry.key} shell')),
            },
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  // ignore: deprecated_member_use_from_same_package
                  result = await navigationProvider.navigateToScreen(
                    context,
                    entry.key,
                  );
                },
                child: Text('run ${entry.key}'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('run ${entry.key}'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
        expect(find.text('${entry.key} shell'), findsOneWidget);
        expect(navigationProvider.visitCounts[entry.key], 1);
      },
    );
  }
}
