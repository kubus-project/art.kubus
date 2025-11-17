import 'dart:async';
import 'package:art_kubus/widgets/app_loading.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'providers/connection_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/web3provider.dart';
import 'providers/themeprovider.dart';
import 'providers/navigation_provider.dart';
import 'providers/artwork_provider.dart';
import 'providers/institution_provider.dart';
import 'providers/dao_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/task_provider.dart';
import 'providers/collectibles_provider.dart';
import 'providers/platform_provider.dart';
import 'providers/config_provider.dart';
import 'providers/saved_items_provider.dart';
import 'core/app_initializer.dart';
import 'main_app.dart';
import 'screens/ar_screen.dart';
import 'web3/connectwallet.dart';
import 'services/user_service.dart';
import 'services/push_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Safer Flutter error handler: guard against zone or stack nulls
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      // Always present the error in debug console (keeps Flutter's default behavior)
      FlutterError.presentError(details);
    } catch (e) {
      // If presenting the error fails, still log the details
      debugPrint('FlutterError.presentError failed: $e');
    }

    // Forward to zone handler if available; guard against any exceptions here
    try {
      final zone = Zone.current;
      if (zone != null) {
        zone.handleUncaughtError(details.exception, details.stack ?? StackTrace.current);
      } else {
        debugPrint('No active Zone to forward FlutterError');
      }
    } catch (e, st) {
      debugPrint('Failed to forward FlutterError to zone: $e\n$st');
    }
  };

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
      // Try to initialize user store but avoid hanging indefinitely on web reloads.
      await UserService.initialize().timeout(initTimeout);
      debugPrint('AppLauncher: UserService.initialize completed.');
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
    if (!_initialized) {
      debugPrint('AppLauncher: Initialization not complete, showing splash screen.');
      // Provide a temporary ThemeProvider so the splash can use the app's
      // theme colors (accent/background) before the real providers are created.
      final initTheme = ThemeProvider();
      debugPrint('AppLauncher: Temporary ThemeProvider created with: \\${initTheme.lightTheme}, dark theme: \\${initTheme.darkTheme}, mode: \\${initTheme.themeMode}.');
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: initTheme.lightTheme,
        darkTheme: initTheme.darkTheme,
        themeMode: initTheme.themeMode,
        home: Scaffold(
          body: const AppLoading(),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ConfigProvider()),
        ChangeNotifierProvider(create: (context) => PlatformProvider()),
        ChangeNotifierProvider(create: (context) => ConnectionProvider()),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => SavedItemsProvider()),
        ChangeNotifierProvider(create: (context) => ChatProvider()),
        ChangeNotifierProvider(create: (context) => Web3Provider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => TaskProvider()),
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
        ChangeNotifierProvider(create: (context) => DAOProvider()),
        ChangeNotifierProvider(create: (context) => WalletProvider()),
      ],
      child: const ArtKubus(),
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
        debugPrint('ArtKubus: ChatProvider.initialize called from ArtKubus.initState');
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
            '/web3': (context) => const Scaffold(
              body: Center(child: Text('Web3 Dashboard - Coming Soon')),
            ),
          },
        );
      },
    );
  }
}
