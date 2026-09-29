import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/app_mode_provider.dart';
import 'package:art_kubus/providers/app_refresh_provider.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/attestation_provider.dart';
import 'package:art_kubus/providers/cache_provider.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/collab_provider.dart';
import 'package:art_kubus/providers/collectibles_provider.dart';
import 'package:art_kubus/providers/collections_provider.dart';
import 'package:art_kubus/providers/community_comments_provider.dart';
import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:art_kubus/providers/community_interactions_provider.dart';
import 'package:art_kubus/providers/community_subject_provider.dart';
import 'package:art_kubus/providers/config_provider.dart';
import 'package:art_kubus/providers/dao_provider.dart';
import 'package:art_kubus/providers/desktop_dashboard_state_provider.dart';
import 'package:art_kubus/providers/events_provider.dart';
import 'package:art_kubus/providers/exhibitions_provider.dart';
import 'package:art_kubus/providers/glass_capabilities_provider.dart';
import 'package:art_kubus/providers/institution_provider.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/main_tab_provider.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/pending_action_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/promotion_provider.dart';
import 'package:art_kubus/providers/recent_activity_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/stats_provider.dart';
import 'package:art_kubus/providers/task_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Renders any real PRODUCT surface inside the app's provider set for the
/// visual-QA matrices.
///
/// Providers are constructed with their production default constructors;
/// there is no network in `flutter test`, so remote loads settle into the
/// screens' own offline/empty/error states. An optional signed-in profile is
/// installed through the ordinary `ProfileProvider.setCurrentUser` API. No
/// authentication check is disabled. Render errors are collected and returned
/// so the capture report can record them instead of hiding them.
Future<List<String>> pumpProductSurface(
  WidgetTester tester, {
  required Widget child,
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  UserProfile? signedInProfile,
  List<SingleChildWidget> extraProviders = const <SingleChildWidget>[],
  Duration settle = const Duration(seconds: 2),
}) async {
  final errors = <String>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final summary = details.exceptionAsString().split('\n').first;
    // Keep the creator location so layout errors point at the source line.
    final location = RegExp(r'lib/[\w/]+\.dart:\d+:\d+')
        .firstMatch(details.toString())
        ?.group(0);
    errors.add(location == null ? summary : '$summary @ $location');
  };
  addTearDown(() => FlutterError.onError = previousOnError);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final themeProvider = ThemeProvider();
  final profileProvider = ProfileProvider();
  if (signedInProfile != null) {
    profileProvider.setCurrentUser(signedInProfile);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<GlassCapabilitiesProvider>(
          create: (_) => GlassCapabilitiesProvider(),
        ),
        ChangeNotifierProvider<AppModeProvider>(
            create: (_) => AppModeProvider()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<MainTabProvider>(
            create: (_) => MainTabProvider()),
        ChangeNotifierProvider<NavigationProvider>(
            create: (_) => NavigationProvider()),
        ChangeNotifierProvider<PendingActionProvider>(
            create: (_) => PendingActionProvider()),
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
        ChangeNotifierProvider<CollectionsProvider>(
            create: (_) => CollectionsProvider()),
        ChangeNotifierProvider<CommunityInteractionsProvider>(
            create: (_) => CommunityInteractionsProvider()),
        ChangeNotifierProvider<CommunityHubProvider>(
            create: (_) => CommunityHubProvider()),
        ChangeNotifierProvider<CommunitySubjectProvider>(
            create: (_) => CommunitySubjectProvider()),
        ChangeNotifierProvider<CommunityCommentsProvider>(
            create: (_) => CommunityCommentsProvider()),
        ChangeNotifierProvider<RecentActivityProvider>(
            create: (_) => RecentActivityProvider()),
        ChangeNotifierProvider<AppRefreshProvider>(
            create: (_) => AppRefreshProvider()),
        ChangeNotifierProvider<AttestationProvider>(
            create: (_) => AttestationProvider()),
        ChangeNotifierProvider<CollectiblesProvider>(
            create: (_) => CollectiblesProvider()),
        ChangeNotifierProvider<ConfigProvider>(create: (_) => ConfigProvider()),
        ChangeNotifierProvider<InstitutionProvider>(
            create: (_) => InstitutionProvider()),
        ChangeNotifierProvider<EventsProvider>(create: (_) => EventsProvider()),
        ChangeNotifierProvider<ExhibitionsProvider>(
            create: (_) => ExhibitionsProvider()),
        ChangeNotifierProvider<NotificationProvider>(
            create: (_) => NotificationProvider()),
        ChangeNotifierProvider<PromotionProvider>(
            create: (_) => PromotionProvider()),
        ChangeNotifierProvider<CacheProvider>(create: (_) => CacheProvider()),
        ChangeNotifierProvider<CollabProvider>(create: (_) => CollabProvider()),
        ChangeNotifierProvider<DesktopDashboardStateProvider>(
            create: (_) => DesktopDashboardStateProvider()),
        ...extraProviders,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themeProvider.lightTheme,
        darkTheme: themeProvider.darkTheme,
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(settle);
  return errors;
}
