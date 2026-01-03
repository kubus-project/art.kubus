import 'dart:async';
import 'package:art_kubus/widgets/app_loading.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'config/config.dart';
import 'providers/connection_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/web3provider.dart';
import 'providers/themeprovider.dart';
import 'providers/tile_providers.dart';
import 'providers/navigation_provider.dart';
import 'providers/artwork_provider.dart';
import 'providers/institution_provider.dart';
import 'providers/dao_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/recent_activity_provider.dart';
import 'providers/task_provider.dart';
import 'providers/collectibles_provider.dart';
import 'providers/platform_provider.dart';
import 'providers/config_provider.dart';
import 'providers/app_refresh_provider.dart';
import 'providers/cache_provider.dart';
import 'providers/saved_items_provider.dart';
import 'providers/community_hub_provider.dart';
import 'providers/community_comments_provider.dart';
import 'providers/community_subject_provider.dart';
import 'providers/presence_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/events_provider.dart';
import 'providers/exhibitions_provider.dart';
import 'providers/collab_provider.dart';
import 'providers/collections_provider.dart';
import 'providers/portfolio_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/analytics_filters_provider.dart';
import 'providers/desktop_dashboard_state_provider.dart';
import 'providers/marker_management_provider.dart';
import 'providers/auth_session_provider.dart';
import 'providers/deep_link_provider.dart';
import 'core/app_initializer.dart';
import 'core/app_navigator.dart';
import 'core/deep_link_bootstrap_screen.dart';
import 'main_app.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/art/ar_screen.dart';
import 'screens/art/art_detail_screen.dart';
import 'screens/web3/wallet/connectwallet_screen.dart';
// user_service initialization moved to profile and wallet flows.
import 'services/push_notification_service.dart';
import 'services/notification_handler.dart';
import 'services/solana_wallet_service.dart';
import 'services/socket_service.dart';
import 'services/backend_api_service.dart';

import 'screens/collab/invites_inbox_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/events/exhibition_detail_screen.dart';
import 'services/share/share_deep_link_parser.dart';

void main() {
  // We'll initialize the bindings inside the runZonedGuarded callback so the
  // WidgetsBinding is created in the same zone as the rest of the app and
  // prevents 'Zone mismatch' warnings when the zone-global error handler
  // or other zone-specific configuration is used.

  // Fallback UI for build-time errors so UI doesn't crash with a null-check exception
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Keep message minimal and safe for web debugging
    final message = 'An unexpected error occurred';
    debugPrint('ErrorWidget caught: ${details.exception}\n${details.stack}');
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16.0),
          ),
        ),
      ),
    );
  };
  
  runZonedGuarded<Future<void>>(
    () async {
      var logger = Logger();

      try {
        // Initialize Flutter bindings in the guarded zone.
        WidgetsFlutterBinding.ensureInitialized();

        // Now forward Flutter framework errors to this zone so the runZonedGuarded
        // error handler receives them.
        FlutterError.onError = (FlutterErrorDetails details) {
          try {
            FlutterError.presentError(details);
          } catch (e) {
            debugPrint('FlutterError.presentError failed: $e');
          }
          try {
            Zone.current.handleUncaughtError(details.exception, details.stack ?? StackTrace.current);
          } catch (e, st) {
            debugPrint('Failed to forward FlutterError to zone: $e\n$st');
          }
        };
        // Camera initialization moved to AR screen to avoid early permission requests
      } catch (e) {
        logger.e('App initialization failed: $e');
      }

      // Run app immediately and show splash while initializing the cached user store
      runApp(const AppLauncher());
    },
    (error, stack) {
      try {
        debugPrint('Unhandled zone error: $error\n$stack');
        // Optionally report to analytics/logging service here.
      } catch (e) {
        debugPrint('Error while handling zone error: $e');
      }
    },
  );
}

class AppLauncher extends StatefulWidget {
  const AppLauncher({super.key});

  @override
  State<AppLauncher> createState() => _AppLauncherState();
}

class _AppLauncherState extends State<AppLauncher> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _bootstrap() {
    // Never block the entire app on push notification initialization. On web this
    // can be delayed by service worker/permission constraints; on mobile it may
    // involve platform channels. The app should always reach AppInitializer.
    if (mounted) {
      setState(() => _initialized = true);
    }
    unawaited(_initPushNotifications());
  }

  Future<void> _initPushNotifications() async {
    const initTimeout = Duration(seconds: 6);
    try {
      // Initialize push notification service and (optionally) request permission
      // early so the preference is persisted for subsequent launches.
      final service = PushNotificationService();
      await service.initialize().timeout(initTimeout);
      // On web, requesting Notification permission must be triggered by a user
      // gesture. Asking during startup produces a browser warning and is ignored.
      if (!kIsWeb) {
        await service.requestPermission().timeout(initTimeout);
      }
      AppConfig.debugPrint('AppLauncher: PushNotificationService initialized.');
    } on TimeoutException catch (e) {
      AppConfig.debugPrint(
        'AppLauncher: PushNotificationService init timed out after ${initTimeout.inSeconds}s: $e',
      );
    } catch (e, st) {
      AppConfig.debugPrint('AppLauncher: PushNotificationService init failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create ThemeProvider once at the top of the widget tree so theme and
    // accent state stays stable across splash + main UI.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          if (!_initialized) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: appNavigatorKey,
              locale: localeProvider.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              onGenerateTitle: (context) => AppLocalizations.of(context)?.appTitle ?? 'art.kubus',
              theme: themeProvider.lightTheme,
              darkTheme: themeProvider.darkTheme,
              themeMode: themeProvider.themeMode,
              home: Scaffold(body: const AppLoading()),
            );
          }

          return MultiProvider(
            providers: [
              Provider<SolanaWalletService>(
                create: (_) => SolanaWalletService(),
              ),
              ChangeNotifierProvider(create: (context) => AppRefreshProvider()),
              ChangeNotifierProvider(create: (context) => ConfigProvider()),
              ChangeNotifierProvider(create: (context) => PlatformProvider()),
              ChangeNotifierProvider(create: (context) => ConnectionProvider()),
              ChangeNotifierProvider(create: (context) => ProfileProvider()),
              ChangeNotifierProxyProvider2<AppRefreshProvider, ConfigProvider, StatsProvider>(
                create: (context) => StatsProvider(),
                update: (context, appRefreshProvider, configProvider, statsProvider) {
                  final provider = statsProvider ?? StatsProvider();
                  provider.bindToRefresh(appRefreshProvider);
                  provider.bindConfigProvider(configProvider);
                  return provider;
                },
              ),
              ChangeNotifierProxyProvider2<AppRefreshProvider, ProfileProvider, PresenceProvider>(
                create: (context) => PresenceProvider(),
                update: (context, appRefreshProvider, profileProvider, presenceProvider) {
                  final provider = presenceProvider ?? PresenceProvider();
                  provider.bindToRefresh(appRefreshProvider);
                  provider.bindProfileProvider(profileProvider);
                  return provider;
                },
              ),
              ChangeNotifierProvider(create: (context) => SavedItemsProvider()),
              ChangeNotifierProvider(create: (context) => CommunitySubjectProvider()),
              ChangeNotifierProxyProvider<AppRefreshProvider, ChatProvider>(
                create: (context) => ChatProvider(),
                update: (context, appRefreshProvider, chatProvider) {
                  final provider = chatProvider ?? ChatProvider();
                  provider.bindToRefresh(appRefreshProvider);
                  return provider;
                },
              ),
              ChangeNotifierProxyProvider<AppRefreshProvider, NotificationProvider>(
                create: (context) => NotificationProvider(),
                update: (context, appRefreshProvider, notificationProvider) {
                  final provider = notificationProvider ?? NotificationProvider();
                  provider.bindToRefresh(appRefreshProvider);
                  return provider;
                },
              ),
              ChangeNotifierProxyProvider<NotificationProvider, RecentActivityProvider>(
                create: (context) => RecentActivityProvider(),
                update: (context, notificationProvider, recentActivityProvider) {
                  final provider = recentActivityProvider ?? RecentActivityProvider();
                  provider.bindNotificationProvider(notificationProvider);
                  if (!provider.initialized && !provider.isLoading) {
                    unawaited(provider.initialize());
                  }
                  return provider;
                },
              ),
              ChangeNotifierProvider(
                create: (context) => Web3Provider(
                  solanaWalletService: context.read<SolanaWalletService>(),
                ),
              ),
              ChangeNotifierProvider(create: (context) => DesktopDashboardStateProvider()),
              ChangeNotifierProvider(create: (context) => AnalyticsFiltersProvider()),
              ChangeNotifierProvider(create: (context) => NavigationProvider()),
              ChangeNotifierProvider(create: (context) => TaskProvider()),
              ChangeNotifierProvider(create: (context) => CacheProvider()),
              ChangeNotifierProxyProvider<CommunitySubjectProvider, CommunityHubProvider>(
                create: (context) => CommunityHubProvider(),
                update: (context, subjectProvider, hubProvider) {
                  final provider = hubProvider ?? CommunityHubProvider();
                  provider.bindSubjectProvider(subjectProvider);
                  return provider;
                },
              ),
              ChangeNotifierProvider(create: (context) => CommunityCommentsProvider()),
              ChangeNotifierProvider(create: (context) => DeepLinkProvider()),
              ChangeNotifierProvider(create: (context) => EventsProvider()),
              ChangeNotifierProvider(create: (context) => ExhibitionsProvider()),
              ChangeNotifierProxyProvider2<AppRefreshProvider, ProfileProvider, CollabProvider>(
                create: (context) => CollabProvider(),
                update: (context, appRefreshProvider, profileProvider, collabProvider) {
                  final provider = collabProvider ?? CollabProvider();
                  provider.bindToRefresh(appRefreshProvider);
                  provider.bindProfileProvider(profileProvider);
                  return provider;
                },
              ),
              ChangeNotifierProvider(create: (context) => CollectionsProvider()),
              ChangeNotifierProvider(create: (context) => PortfolioProvider()),
              ChangeNotifierProxyProvider<TaskProvider, ArtworkProvider>(
                create: (context) {
                  final artworkProvider = ArtworkProvider();
                  artworkProvider.setTaskProvider(context.read<TaskProvider>());
                  return artworkProvider;
                },
                update: (context, taskProvider, artworkProvider) {
                  artworkProvider?.setTaskProvider(taskProvider);
                  return artworkProvider ?? ArtworkProvider()..setTaskProvider(taskProvider);
                },
              ),
              ChangeNotifierProvider(create: (context) => CollectiblesProvider()),
              ChangeNotifierProvider(create: (context) => InstitutionProvider()),
              ChangeNotifierProvider(
                create: (context) => DAOProvider(
                  solanaWalletService: context.read<SolanaWalletService>(),
                ),
              ),
              ChangeNotifierProvider(
                create: (context) => WalletProvider(
                  solanaWalletService: context.read<SolanaWalletService>(),
                ),
              ),
              ChangeNotifierProxyProvider2<ProfileProvider, WalletProvider, AuthSessionProvider>(
                create: (context) => AuthSessionProvider(),
                update: (context, profileProvider, walletProvider, authSessionProvider) {
                  final provider = authSessionProvider ?? AuthSessionProvider();
                  provider.bindOnSessionRestored(() async {
                    final walletAddress = profileProvider.currentUser?.walletAddress ?? walletProvider.currentWalletAddress;
                    if (walletAddress == null || walletAddress.isEmpty) return;
                    await profileProvider.loadProfile(walletAddress);
                  });
                  BackendApiService().bindAuthCoordinator(provider);
                  return provider;
                },
              ),
              ChangeNotifierProxyProvider2<ProfileProvider, WalletProvider, MarkerManagementProvider>(
                create: (context) => MarkerManagementProvider(),
                update: (context, profileProvider, walletProvider, markerManagementProvider) {
                  final provider = markerManagementProvider ?? MarkerManagementProvider();
                  provider.bindWallet(profileProvider.currentUser?.walletAddress ?? walletProvider.currentWalletAddress);
                  if (!provider.initialized && !provider.isLoading) {
                    unawaited(provider.initialize());
                  }
                  return provider;
                },
              ),
              Provider<TileProviders>(
                create: (context) => TileProviders(context.read<ThemeProvider>()),
                dispose: (context, value) => value.dispose(),
              ),
            ],
            child: const ArtKubus(),
          );
        },
      ),
    );
  }
}
 
 

class ArtKubus extends StatefulWidget {
  const ArtKubus({super.key});

  @override
  State<ArtKubus> createState() => _ArtKubusState();
}

class _ArtKubusState extends State<ArtKubus> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotificationRouting();
  }

  void _initNotificationRouting() {
    final handler = NotificationHandler();
    handler.onNavigate = (route, params) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;

      if (route == '/collab_invite') {
        final rawType = (params['entityType'] ?? '').toString();
        final rawId = (params['entityId'] ?? '').toString();

        final entityType = rawType.trim().toLowerCase();
        final entityId = rawId.trim();

        if (entityId.isEmpty) {
          navigator.push(MaterialPageRoute(builder: (_) => const InvitesInboxScreen()));
          return;
        }

        if (entityType == 'events' || entityType == 'event') {
          navigator.push(MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: entityId)));
          return;
        }

        if (entityType == 'exhibitions' || entityType == 'exhibition') {
          navigator.push(MaterialPageRoute(builder: (_) => ExhibitionDetailScreen(exhibitionId: entityId)));
          return;
        }

        navigator.push(MaterialPageRoute(builder: (_) => const InvitesInboxScreen()));
        return;
      }

      // Best-effort fallback to named routes.
      try {
        navigator.pushNamed(route, arguments: params);
      } catch (_) {
        // Ignore unknown routes.
      }
    };

    handler.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final ctx = context;
    if (!mounted) return;
    final walletProvider = Provider.of<WalletProvider>(ctx, listen: false);
    final refreshProvider = Provider.of<AppRefreshProvider>(ctx, listen: false);
    final presenceProvider = Provider.of<PresenceProvider>(ctx, listen: false);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      walletProvider.markInactive();
    } else if (state == AppLifecycleState.resumed) {
      walletProvider.markActive();
      // Refresh core surfaces after returning to foreground (no manual reload needed).
      refreshProvider.triggerAll();
      unawaited(presenceProvider.onAppResumed());
      unawaited(SocketService().connect());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp(
          title: 'art.kubus',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          locale: localeProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          onGenerateTitle: (context) => AppLocalizations.of(context)?.appTitle ?? 'art.kubus',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          onGenerateRoute: (settings) {
            final name = (settings.name ?? '').trim();
            if (name.isEmpty) {
              return MaterialPageRoute(builder: (_) => const AppInitializer(), settings: settings);
            }

            final uri = Uri.tryParse(name) ?? Uri(path: name);
            final target = const ShareDeepLinkParser().parse(uri);
            if (target != null) {
              return MaterialPageRoute(
                builder: (_) => DeepLinkBootstrapScreen(target: target),
                settings: settings,
              );
            }

            // Fall back to the main initializer for unknown named routes (e.g. browser refresh on /foo).
            return MaterialPageRoute(builder: (_) => const AppInitializer(), settings: settings);
          },
          home: const AppInitializer(),
          routes: {
            '/main': (context) => const MainApp(),
            '/ar': (context) => const ARScreen(),
            '/artwork': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              String? artworkId;
              if (args is Map) {
                final raw = args['artworkId'] ?? args['id'] ?? args['artwork_id'];
                if (raw != null) artworkId = raw.toString();
              } else if (args is String) {
                artworkId = args;
              }
              artworkId = artworkId?.trim();
              if (artworkId == null || artworkId.isEmpty) {
                final l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: Center(child: Text(l10n.artworkNotFound)),
                );
              }
              return ArtDetailScreen(artworkId: artworkId);
            },
            '/wallet_connect': (context) => const ConnectWallet(),
            '/connect_wallet': (context) => const ConnectWallet(),
            '/connect-wallet': (context) => const ConnectWallet(),
            '/sign-in': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is Map) {
                final redirectRoute = args['redirectRoute']?.toString();
                final redirectArguments = args['redirectArguments'];
                return SignInScreen(
                  redirectRoute: redirectRoute,
                  redirectArguments: redirectArguments,
                );
              }
              return const SignInScreen();
            },
            '/register': (context) => const RegisterScreen(),
            '/web3': (context) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: Center(child: Text(l10n.web3DashboardComingSoon)),
              );
            },
          },
        );
      },
    );
  }
}
