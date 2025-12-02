import 'dart:async';
import 'package:art_kubus/widgets/app_loading.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
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
import 'core/app_initializer.dart';
import 'main_app.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/art/ar_screen.dart';
import 'screens/web3/wallet/connectwallet_screen.dart';
// user_service initialization moved to profile and wallet flows.
import 'services/push_notification_service.dart';
import 'services/solana_wallet_service.dart';

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
    _init();
  }

  Future<void> _init() async {
    const initTimeout = Duration(seconds: 6); // safe fallback for web reload stalls
      try {
        // Previously we initialized the user store on app startup; we now move
        // initialization to wallet registration/profile creation flows to avoid
        // unnecessarily initializing persisted caches for anonymous users.
        // Keep a small comment here to avoid losing historical context.
      // Initialize push notification service and request permission so the
      // permission state is persisted early and notifications can be shown
      // immediately when events arrive.
      try {
        await PushNotificationService().initialize();
        // Request permission (may prompt user). It's safe to await; service
        // will persist the result and future calls will be no-ops if denied.
        await PushNotificationService().requestPermission();
        debugPrint('AppLauncher: PushNotificationService initialized and permission requested.');
      } catch (e) {
        debugPrint('AppLauncher: PushNotificationService init/requestPermission failed: $e');
      }
    } on TimeoutException catch (e) {
      debugPrint('AppLauncher: UserService.initialize timed out after ${initTimeout.inSeconds}s: $e');
    } catch (e, st) {
      debugPrint('AppLauncher: UserService.initialize failed: $e\n$st');
    } finally {
      // Ensure the app proceeds even if initialization failed or timed out.
      if (mounted) setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create a single ThemeProvider instance and make it available for the
    // entire app lifecycle (splash + main) to avoid `ProviderNotFound` risks
    // and to keep the theme consistent across both app states.
    final topTheme = ThemeProvider();
    if (!_initialized) {
      debugPrint('AppLauncher: Initialization not complete, showing splash screen.');
      debugPrint('AppLauncher: Temporary ThemeProvider created with: \\\${topTheme.lightTheme}, dark theme: \\\${topTheme.darkTheme}, mode: \\\${topTheme.themeMode}.');
      return ChangeNotifierProvider<ThemeProvider>.value(
        value: topTheme,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: topTheme.lightTheme,
          darkTheme: topTheme.darkTheme,
          themeMode: topTheme.themeMode,
          home: Scaffold(
            body: const AppLoading(),
          ),
        ),
      );
    }
    
    // Ensure ThemeProvider is present at the top of the tree for consumers.
    // Provide ThemeProvider here (created once) to be consistent across splash and main UI.
    return ChangeNotifierProvider<ThemeProvider>.value(
      value: topTheme,
      child: MultiProvider(
      providers: [
        Provider<SolanaWalletService>(
          create: (_) => SolanaWalletService(),
        ),
        ChangeNotifierProvider(create: (context) => AppRefreshProvider()),
        ChangeNotifierProvider(create: (context) => ConfigProvider()),
        ChangeNotifierProvider(create: (context) => PlatformProvider()),
        ChangeNotifierProvider(create: (context) => ConnectionProvider()),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => SavedItemsProvider()),
        ChangeNotifierProvider(create: (context) => ChatProvider()),
        ChangeNotifierProvider(create: (context) => NotificationProvider()),
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
        // ThemeProvider is provided above; no duplicate provider here.
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => TaskProvider()),
        ChangeNotifierProvider(create: (context) => CacheProvider()),
        ChangeNotifierProvider(create: (context) => CommunityHubProvider()),
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
        // Provide TileProviders so tiles + grid overlay are centralized and
        // respond to ThemeProvider updates. Dispose manually when the provider
        // tree is torn down.
        Provider<TileProviders>(
          create: (context) => TileProviders(context.read<ThemeProvider>()),
          dispose: (context, value) => value.dispose(),
        ),
      ],
      child: const ArtKubus(),
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
    // Cache already initialized at startup (blocking call in main)
    WidgetsBinding.instance.addObserver(this);
    // Ensure ChatProvider initializes sockets and subscriptions as soon as
    // the widget tree is available so incoming socket events (unread
    // counts, read receipts) are processed immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final cp = Provider.of<ChatProvider>(context, listen: false);
        await cp.initialize();
        if (!mounted) return;
        debugPrint('ArtKubus: ChatProvider.initialize called from ArtKubus.initState');
        try {
          // Bind NotificationProvider to AppRefreshProvider so screens can trigger
          // notification refreshes centrally (home/community auto-refresh).
          final appRefresh = Provider.of<AppRefreshProvider>(context, listen: false);
          final notif = Provider.of<NotificationProvider>(context, listen: false);
          final profile = Provider.of<ProfileProvider>(context, listen: false);
          final wallet = profile.currentUser?.walletAddress;
          await notif.initialize(walletOverride: wallet);
          notif.bindToRefresh(appRefresh);
          cp.bindToRefresh(appRefresh);
          debugPrint('ArtKubus: NotificationProvider + ChatProvider bound to AppRefreshProvider');
        } catch (e) {
          debugPrint('ArtKubus: failed to bind NotificationProvider to AppRefreshProvider: $e');
        }
      } catch (e) {
        debugPrint('ArtKubus.initState: ChatProvider.initialize failed: $e');
      }
    });
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      walletProvider.markInactive();
    } else if (state == AppLifecycleState.resumed) {
      walletProvider.markActive();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'art.kubus',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AppInitializer(),
          routes: {
            '/main': (context) => const MainApp(),
            '/ar': (context) => const ARScreen(),
            '/wallet_connect': (context) => const ConnectWallet(),
            '/connect_wallet': (context) => const ConnectWallet(),
            '/connect-wallet': (context) => const ConnectWallet(),
            '/sign-in': (context) => const SignInScreen(),
            '/register': (context) => const RegisterScreen(),
            '/web3': (context) => const Scaffold(
              body: Center(child: Text('Web3 Dashboard - Coming Soon')),
            ),
          },
        );
      },
    );
  }
}
