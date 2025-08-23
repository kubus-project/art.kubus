import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'providers/connection_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/web3provider.dart';
import 'providers/themeprovider.dart';
import 'providers/navigation_provider.dart';
import 'providers/artwork_provider.dart';
import 'providers/mockup_data_provider.dart';
import 'providers/institution_provider.dart';
import 'providers/dao_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/task_provider.dart';
import 'providers/collectibles_provider.dart';
import 'providers/platform_provider.dart';
import 'providers/config_provider.dart';
import 'core/app_initializer.dart';
import 'main_app.dart';
import 'ar/ar.dart';

void main() async {
  var logger = Logger();

  try {
    WidgetsFlutterBinding.ensureInitialized();
    // Camera initialization moved to AR screen to avoid early permission requests
  } catch (e) {
    logger.e('App initialization failed: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ConfigProvider()),
        ChangeNotifierProvider(create: (context) => PlatformProvider()),
        ChangeNotifierProvider(create: (context) => ConnectionProvider()),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => Web3Provider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => MockupDataProvider()),
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
        ChangeNotifierProxyProvider<MockupDataProvider, InstitutionProvider>(
          create: (context) => InstitutionProvider(context.read<MockupDataProvider>()),
          update: (context, mockupProvider, institutionProvider) =>
              institutionProvider ?? InstitutionProvider(mockupProvider),
        ),
        ChangeNotifierProxyProvider<MockupDataProvider, DAOProvider>(
          create: (context) => DAOProvider(context.read<MockupDataProvider>()),
          update: (context, mockupProvider, daoProvider) =>
              daoProvider ?? DAOProvider(mockupProvider),
        ),
        ChangeNotifierProxyProvider<MockupDataProvider, WalletProvider>(
          create: (context) => WalletProvider(context.read<MockupDataProvider>()),
          update: (context, mockupProvider, walletProvider) =>
              walletProvider ?? WalletProvider(mockupProvider),
        ),
      ],
      child: const ArtKubus(),
    ),
  );
}

class ArtKubus extends StatelessWidget {
  const ArtKubus({super.key});

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
            '/ar': (context) => const Augmented(),
            '/web3': (context) => const Scaffold(
              body: Center(child: Text('Web3 Dashboard - Coming Soon')),
            ),
          },
        );
      },
    );
  }
}
