import 'package:art_kubus/core/shell_routes.dart';
import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/features/analytics/analytics_presets.dart';
import 'package:art_kubus/features/analytics/unified_analytics_screen.dart';
import 'package:art_kubus/features/analytics/widgets/analytics_header.dart';
import 'package:art_kubus/features/analytics/widgets/analytics_overview_grid.dart';
import 'package:art_kubus/screens/community/profile_screen.dart'
    as mobile_owner_profile;
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/analytics_filters_provider.dart';
import 'package:art_kubus/screens/activity/advanced_analytics_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/home_screen.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../../support/product_surface_harness.dart';
import '../../support/product_v5_qa_fixtures.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
  }
}

void main() {
  testWidgets('analytics back pops the desktop shell screen first', (
    tester,
  ) async {
    var shellPops = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopShellScope(
          pushScreen: (_) {},
          popScreen: () => shellPops++,
          navigateToRoute: (_) {},
          openNotifications: () {},
          openFunctionsPanel: (_, {content}) {},
          setFunctionsPanelContent: (_) {},
          closeFunctionsPanel: () {},
          canPop: true,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  handleAnalyticsBack(context, hasAuthSession: false),
              child: const Text('Back'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Back'));

    expect(shellPops, 1);
  });

  testWidgets('analytics back pops an existing Navigator route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (routeContext) => TextButton(
                    onPressed: () => handleAnalyticsBack(
                      routeContext,
                      hasAuthSession: false,
                    ),
                    child: const Text('Analytics back'),
                  ),
                ),
              ),
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analytics back'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  for (final (hasAuthSession, destination) in <(bool, String)>[
    (false, ShellRoutes.map),
    (true, ShellRoutes.main),
  ]) {
    testWidgets('root analytics back replaces with $destination', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  handleAnalyticsBack(context, hasAuthSession: hasAuthSession),
              child: const Text('Back'),
            ),
          ),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Text(settings.name ?? ''),
          ),
        ),
      );

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text(destination), findsOneWidget);
    });
  }

  testWidgets('standalone Android Back uses the root route fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => AnalyticsStandaloneBackScope(
            embedded: false,
            onBack: () => handleAnalyticsBack(context, hasAuthSession: false),
            child: const Text('Analytics'),
          ),
        ),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text(settings.name ?? ''),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(ShellRoutes.map), findsOneWidget);
  });

  testWidgets('actual denied analytics route falls back to public map', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final previousOnError = FlutterError.onError;
    await pumpProductSurface(
      tester,
      child: Navigator(
        onGenerateInitialRoutes: (_, __) => <Route<void>>[
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: ShellRoutes.analytics),
            builder: (_) => const AdvancedAnalyticsScreen(
              statType: 'views',
              walletAddress: 'profile-owner',
              initialContext: AnalyticsExperienceContext.profile,
            ),
          ),
        ],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Text('public-map-fallback'),
        ),
      ),
      extraProviders: [
        ChangeNotifierProvider<AnalyticsFiltersProvider>(
          create: (_) => AnalyticsFiltersProvider(),
        ),
      ],
    );
    FlutterError.onError = previousOnError;

    expect(find.byType(AdvancedAnalyticsScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('analytics_standalone_back')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('analytics_standalone_back')),
    );
    await tester.pumpAndSettle();

    expect(find.text('public-map-fallback'), findsOneWidget);
  });

  testWidgets('Home analytics push keeps its route name and returns to Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final previousOnError = FlutterError.onError;
    final observer = _RecordingNavigatorObserver();
    await pumpProductSurface(
      tester,
      child: Navigator(
        observers: <NavigatorObserver>[observer],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomeScreen(),
        ),
      ),
      size: const Size(390, 900),
      signedInProfile: qaOwner(isArtist: true),
      extraProviders: [
        ChangeNotifierProvider<AnalyticsFiltersProvider>(
          create: (_) => AnalyticsFiltersProvider(),
        ),
      ],
    );
    FlutterError.onError = previousOnError;

    final cards = find.byType(KubusStatCard);
    for (var i = 0; i < 12 && cards.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -650));
      await tester.pumpAndSettle();
    }
    expect(cards, findsWidgets);
    await tester.tap(cards.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    expect(observer.lastPushed?.settings.name, ShellRoutes.analytics);
    if (AppConfig.isFeatureEnabled('analytics')) {
      expect(find.byType(AnalyticsHeader), findsOneWidget);
      expect(find.byType(AnalyticsOverviewGrid), findsOneWidget);
    } else {
      expect(find.byType(AnalyticsHeader), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('analytics_standalone_back')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey<String>('analytics_standalone_back')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('analytics_standalone_back')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
    'Profile analytics push keeps its route name and returns to Profile',
    (tester) async {
      if (!AppConfig.isFeatureEnabled('analytics')) return;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final previousOnError = FlutterError.onError;
      final observer = _RecordingNavigatorObserver();
      await pumpProductSurface(
        tester,
        child: Navigator(
          observers: <NavigatorObserver>[observer],
          onGenerateInitialRoutes: (_, __) => <Route<void>>[
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/profile'),
              builder: (_) => const mobile_owner_profile.ProfileScreen(),
            ),
          ],
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Text('profile-return-fallback'),
          ),
        ),
        size: const Size(390, 1000),
        signedInProfile: qaOwner(isArtist: true),
        extraProviders: [
          ChangeNotifierProvider<AnalyticsFiltersProvider>(
            create: (_) => AnalyticsFiltersProvider(),
          ),
        ],
      );
      FlutterError.onError = previousOnError;

      final analyticsAction = find.byIcon(Icons.analytics_outlined);
      expect(analyticsAction, findsOneWidget);
      await tester.tap(analyticsAction);
      await tester.pumpAndSettle();

      expect(observer.lastPushed?.settings.name, ShellRoutes.analytics);
      expect(find.byType(AnalyticsHeader), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('analytics_standalone_back')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(mobile_owner_profile.ProfileScreen), findsOneWidget);
    },
  );

  testWidgets('embedded analytics leaves Android Back to its desktop shell', (
    tester,
  ) async {
    var backCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => AnalyticsStandaloneBackScope(
            embedded: true,
            onBack: () => backCalls++,
            child: const Text('Analytics'),
          ),
        ),
      ),
    );

    await tester.binding.handlePopRoute();

    expect(backCalls, 0);
  });

  for (final stateTitle in <String>['Access denied', 'No metrics']) {
    testWidgets('standalone $stateTitle state shows a visible Back action', (
      tester,
    ) async {
      var backCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AnalyticsStandaloneStatePage(
            onBack: () => backCalls++,
            child: Text(stateTitle),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('analytics_standalone_back')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('analytics_standalone_back')),
      );
      expect(backCalls, 1);
    });
  }

  testWidgets('analytics header exposes Back in loading and data composition', (
    tester,
  ) async {
    final profile = AnalyticsPresets.byKind(AnalyticsPresetKind.profile);
    var backCalls = 0;
    final themeProvider = ThemeProvider();
    await tester.pumpWidget(
      MaterialApp(
        theme: themeProvider.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnalyticsHeader(
          title: 'Profile analytics',
          subtitle: 'Activity over time',
          scopeLabel: 'Profile',
          icon: profile.icon,
          scopeBadge: 'Private',
          availablePresets: <AnalyticsPreset>[profile],
          activePreset: profile,
          onPresetSelected: (_) {},
          canExport: false,
          onExport: () {},
          onShare: () {},
          onBack: () => backCalls++,
        ),
      ),
    );

    final back = find.byKey(
      const ValueKey<String>('analytics_standalone_back'),
    );
    expect(back, findsOneWidget);
    await tester.tap(back);
    expect(backCalls, 1);
  });
}
