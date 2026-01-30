import 'dart:async';
import 'package:art_kubus/screens/events/event_detail_screen.dart';
import 'package:art_kubus/screens/events/exhibition_detail_screen.dart';
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
  import 'providers/security_gate_provider.dart';
import 'providers/email_preferences_provider.dart';
import 'providers/auth_deep_link_provider.dart';
  import 'providers/deep_link_provider.dart';
  import 'providers/platform_deep_link_listener_provider.dart';
import 'providers/main_tab_provider.dart';
import 'providers/map_deep_link_provider.dart';
import 'providers/deferred_onboarding_provider.dart';
import 'core/app_initializer.dart';
import 'core/app_navigator.dart';
import 'core/shell_entry_screen.dart';
import 'core/url_strategy.dart';
import 'core/deep_link_bootstrap_screen.dart';
import 'core/maplibre_web_registration.dart';
import 'main_app.dart';
  import 'screens/auth/sign_in_screen.dart';
  import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/email_verification_success_screen.dart';
import 'screens/art/ar_screen.dart';
import 'screens/art/art_detail_screen.dart';
import 'screens/desktop/art/desktop_artwork_detail_screen.dart';
import 'screens/desktop/desktop_shell.dart';
import 'screens/web3/wallet/connectwallet_screen.dart';
// user_service initialization moved to profile and wallet flows.
import 'services/push_notification_service.dart';
import 'services/notification_handler.dart';
import 'services/solana_wallet_service.dart';
import 'services/socket_service.dart';
import 'services/backend_api_service.dart';
import 'services/telemetry/telemetry_route_observer.dart';
import 'services/telemetry/telemetry_service.dart';

import 'widgets/glass_components.dart';
import 'widgets/security_gate_overlay.dart';

import 'screens/collab/invites_inbox_screen.dart';
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

        // Canonical share URLs (e.g. https://app.kubus.site/marker/<id>) rely on
        // path-based routing on Flutter web. Without this, Flutter defaults to a
        // hash-based strategy and a direct visit to /marker/<id> is treated as
        // route '/' (Home).
        configureUrlStrategy();

        // Web hardening: ensure MapLibre's web implementation is registered.
        // Without this, some release deployments can end up using the
        // method-channel implementation and throw "TargetPlatform.windows...".
        ensureMapLibreWebRegistration();

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
              builder: (context, child) {
                // Safety net: if any route uses transparency and forgets to
                // paint its own backdrop, we'd otherwise see the host page's
                // HTML background.
                return AnimatedGradientBackground(
                  animate: false,
                  intensity: 0.22,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: Scaffold(body: const AppLoading()),
            );
          }

          return MultiProvider(
            providers: [
              Provider<SolanaWalletService>(
                create: (_) => SolanaWalletService(),
              ),
              // Main mobile shell tab state (also used by deep-link flows).
              ChangeNotifierProvider(create: (context) => MainTabProvider()),
              // Marker deep links open inside the already-mounted MapScreen.
              ChangeNotifierProvider(create: (context) => MapDeepLinkProvider()),
              // Session-scoped onboarding deferral for deep-link cold starts.
              ChangeNotifierProvider(create: (context) => DeferredOnboardingProvider()),
              ChangeNotifierProvider(create: (context) => AppRefreshProvider()),
              ChangeNotifierProvider(create: (context) => ConfigProvider()),
              ProxyProvider<ConfigProvider, TelemetryService>(
                create: (_) => TelemetryService(),
                update: (context, configProvider, telemetry) {
                  final service = telemetry ?? TelemetryService();
                  service.setAnalyticsPreferenceEnabled(configProvider.enableAnalytics);
                  return service;
                },
              ),
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
              ChangeNotifierProvider(create: (context) => AuthDeepLinkProvider()),
              ChangeNotifierProxyProvider2<DeepLinkProvider, AuthDeepLinkProvider, PlatformDeepLinkListenerProvider>(
                create: (context) => PlatformDeepLinkListenerProvider(),
                update: (context, deepLinkProvider, authDeepLinkProvider, listenerProvider) {
                  final provider = listenerProvider ?? PlatformDeepLinkListenerProvider();
                  provider.bindProviders(
                    deepLinkProvider: deepLinkProvider,
                    authDeepLinkProvider: authDeepLinkProvider,
                  );
                  return provider;
                },
              ),
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
              ChangeNotifierProxyProvider<ArtworkProvider, PortfolioProvider>(
                create: (context) => PortfolioProvider(),
                update: (context, artworkProvider, portfolioProvider) {
                  final provider = portfolioProvider ?? PortfolioProvider();
                  provider.bindArtworkProvider(artworkProvider);
                  return provider;
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
              ChangeNotifierProxyProvider3<AppRefreshProvider, ProfileProvider, WalletProvider, ChatProvider>(
                create: (context) => ChatProvider(),
                update: (context, appRefreshProvider, profileProvider, walletProvider, chatProvider) {
                  final provider = chatProvider ?? ChatProvider();
                  provider.bindToRefresh(appRefreshProvider);
                  provider.bindAuthContext(
                    profileProvider: profileProvider,
                    walletAddress: walletProvider.currentWalletAddress,
                    isSignedIn: profileProvider.isSignedIn,
                  );
                  return provider;
                },
              ),
              ChangeNotifierProxyProvider3<ProfileProvider, WalletProvider, NotificationProvider, SecurityGateProvider>(
                lazy: false,
                create: (context) => SecurityGateProvider(),
                update: (context, profileProvider, walletProvider, notificationProvider, securityGateProvider) {
                  final provider = securityGateProvider ?? SecurityGateProvider();
                  provider.bindDependencies(
                    profileProvider: profileProvider,
                    walletProvider: walletProvider,
                    notificationProvider: notificationProvider,
                  );
                  BackendApiService().bindAuthCoordinator(provider);
                  unawaited(provider.initialize());
                  return provider;
                },
              ),
              ChangeNotifierProxyProvider<SecurityGateProvider, EmailPreferencesProvider>(
                create: (context) => EmailPreferencesProvider(),
                update: (context, securityGateProvider, emailPreferencesProvider) {
                  final provider = emailPreferencesProvider ?? EmailPreferencesProvider();
                  final tokenPresent = (BackendApiService().getAuthToken() ?? '').trim().isNotEmpty;
                  provider.bindSession(hasSession: tokenPresent || securityGateProvider.hasLocalAccount);
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
  final TelemetryRouteObserver _telemetryObserver = TelemetryRouteObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotificationRouting();
    unawaited(TelemetryService().ensureInitialized());
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
    TelemetryService().onAppLifecycleChanged(state);
    final ctx = context;
    if (!mounted) return;
    final securityGate = Provider.of<SecurityGateProvider>(ctx, listen: false);
    final refreshProvider = Provider.of<AppRefreshProvider>(ctx, listen: false);
    final presenceProvider = Provider.of<PresenceProvider>(ctx, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(ctx, listen: false);
    final isForeground =
        state != AppLifecycleState.paused && state != AppLifecycleState.inactive;
    refreshProvider.setAppForeground(isForeground);
    notificationProvider.handleAppForegroundChanged(isForeground);
    presenceProvider.handleAppForegroundChanged(isForeground);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      securityGate.onAppLifecycleChanged(state);
    } else if (state == AppLifecycleState.resumed) {
      securityGate.onAppLifecycleChanged(state);
      // Refresh core surfaces after returning to foreground (no manual reload needed).
      refreshProvider.triggerForegroundRefresh();
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
          navigatorObservers: [_telemetryObserver],
          locale: localeProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          onGenerateTitle: (context) => AppLocalizations.of(context)?.appTitle ?? 'art.kubus',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
           builder: (context, child) {
             return AnimatedGradientBackground(
               animate: false,
               intensity: 0.22,
               child: SecurityGateOverlay(child: child ?? const SizedBox.shrink()),
             );
           },
           onGenerateRoute: (settings) {
             final name = (settings.name ?? '').trim();
             if (name.isEmpty) {
               return MaterialPageRoute(builder: (_) => const AppInitializer(), settings: settings);
             }
 
             final uri = Uri.tryParse(name) ?? Uri(path: name);

             if (uri.path == '/verify-email') {
               final token = (uri.queryParameters['token'] ?? '').trim();
               final email = (uri.queryParameters['email'] ?? '').trim();
               if (token.isNotEmpty) {
                 return MaterialPageRoute(
                   builder: (_) => EmailVerificationSuccessScreen(token: token),
                   settings: RouteSettings(
                     name: '/verify-email',
                     arguments: {
                       'token': token,
                       if (email.isNotEmpty) 'email': email,
                     },
                   ),
                 );
               }
             }

             if (uri.path == '/reset-password') {
               final token = (uri.queryParameters['token'] ?? '').trim();
               if (token.isNotEmpty) {
                 return MaterialPageRoute(
                   builder: (_) => ResetPasswordScreen(token: token),
                   settings: RouteSettings(
                     name: '/reset-password',
                     arguments: {'token': token},
                   ),
                 );
               }
             }

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
            // Alias for telemetry/URL semantics: marker deep links land here so
            // the browser URL becomes /map (not /main), while still rendering
            // the full shell.
            '/map': (context) => const ShellEntryScreen.map(),
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
              final isDesktop = DesktopBreakpoints.isDesktop(context);
              return isDesktop
                  ? DesktopArtworkDetailScreen(artworkId: artworkId, showAppBar: true)
                  : ArtDetailScreen(artworkId: artworkId);
            },
            '/wallet_connect': (context) => const ConnectWallet(),
            '/connect_wallet': (context) => const ConnectWallet(),
            '/sign-in': (context) {
              final args = ModalRoute.of(context)?.settings.arguments;
              if (args is Map) {
                final redirectRoute = args['redirectRoute']?.toString();
                final redirectArguments = args['redirectArguments'];
                final email = args['email']?.toString();
                return SignInScreen(
                  redirectRoute: redirectRoute,
                  redirectArguments: redirectArguments,
                  initialEmail: email,
                );
              }
              return const SignInScreen();
            },
             '/register': (context) => const RegisterScreen(),
             '/verify-email': (context) {
               final args = ModalRoute.of(context)?.settings.arguments;
               String? token;
               String? email;
               if (args is Map) {
                 token = args['token']?.toString();
                 email = args['email']?.toString();
               }
               return VerifyEmailScreen(
                 email: email?.trim().isNotEmpty == true ? email!.trim() : null,
                 token: token?.trim().isNotEmpty == true ? token!.trim() : null,
               );
             },
             '/forgot-password': (context) {
               final args = ModalRoute.of(context)?.settings.arguments;
               String? email;
               if (args is Map) {
                 email = args['email']?.toString();
               }
               return ForgotPasswordScreen(initialEmail: email);
             },
             '/reset-password': (context) {
               final args = ModalRoute.of(context)?.settings.arguments;
               String? token;
               if (args is Map) {
                 token = args['token']?.toString();
               }
               return ResetPasswordScreen(token: token);
             },
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
