import 'package:art_kubus/core/shell_routes.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/core/mobile_shell_registry.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/screens/activity/advanced_analytics_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_settings_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/web3/achievements/achievements_page.dart';
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
  Map<String, WidgetBuilder>? routes,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NavigationProvider>.value(
        value: navigationProvider,
      ),
      if (tabProvider != null)
        ChangeNotifierProvider<MainTabProvider>.value(value: tabProvider),
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('mobile tab quick actions select the real shell tabs',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      for (final entry in <String, int>{
        'map': 0,
        'community': 2,
        'ar': 1,
        'profile': 4,
      }.entries) {
        final navigationProvider = NavigationProvider();
        final tabProvider = MainTabProvider()..setIndex(3);
        bool? result;

        await tester.pumpWidget(
          _localizedApp(
            navigationProvider: navigationProvider,
            tabProvider: tabProvider,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await HomeQuickActionExecutor.execute(
                      context,
                      entry.key,
                      source: HomeQuickActionSurface.mobileHome,
                    );
                  },
                  child: Text('run ${entry.key}'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('run ${entry.key}'));
        await tester.pump();

        expect(result, isTrue);
        expect(tabProvider.index, entry.value);
        expect(navigationProvider.visitCounts[entry.key], 1);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'mobile tab fallback uses the mounted shell registry when the local '
      'context cannot see MainTabProvider', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      for (final entry in <String, int>{
        'ar': 1,
        'profile': 4,
      }.entries) {
        final navigationProvider = NavigationProvider();
        final tabProvider = MainTabProvider()..setIndex(3);
        BuildContext? shellContext;
        bool? result;

        await tester.pumpWidget(
          _localizedApp(
            navigationProvider: navigationProvider,
            home: Scaffold(
              body: Column(
                children: [
                  ChangeNotifierProvider<MainTabProvider>.value(
                    value: tabProvider,
                    child: Builder(
                      builder: (context) {
                        shellContext = context;
                        MobileShellRegistry.instance.register(context);
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        result = await HomeQuickActionExecutor.execute(
                          context,
                          entry.key,
                          source: HomeQuickActionSurface.mobileHome,
                        );
                      },
                      child: Text('fallback ${entry.key}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.tap(find.text('fallback ${entry.key}'));
        await tester.pump();

        expect(result, isTrue);
        expect(tabProvider.index, entry.value);
        expect(navigationProvider.visitCounts[entry.key], 1);

        if (shellContext != null) {
          MobileShellRegistry.instance.unregister(shellContext!);
        }
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('desktop settings and stats use shell subscreens',
      (tester) async {
    final navigationProvider = NavigationProvider();
    final pushedScreens = <Widget>[];

    await tester.pumpWidget(
      _localizedApp(
        navigationProvider: navigationProvider,
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

  testWidgets('desktop achievements quick action opens the real page',
      (tester) async {
    final navigationProvider = NavigationProvider();
    final pushedScreens = <Widget>[];
    bool? result;

    await tester.pumpWidget(
      _localizedApp(
        navigationProvider: navigationProvider,
        home: ChangeNotifierProvider<TaskProvider>(
          create: (_) => TaskProvider(),
          child: DesktopShellScope(
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
                    'achievements',
                    source: HomeQuickActionSurface.desktopHome,
                  );
                },
                child: const Text('achievements'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('achievements'));
    await tester.pump();

    expect(result, isTrue);
    expect(pushedScreens, hasLength(1));
    expect(pushedScreens.single, isA<AchievementsPage>());
    expect(navigationProvider.visitCounts['achievements'], 1);
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
