// NOTE: use_build_context_synchronously lint handled per-instance; avoid file-level ignore
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../providers/config_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/artwork_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/web3provider.dart';
import '../providers/cache_provider.dart';
import '../services/backend_api_service.dart';
import '../onboarding/onboarding_screen.dart';
import '../main_app.dart';
import '../widgets/app_loading.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  String? initializationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Load JWT token for backend authentication
    await BackendApiService().loadAuthToken();
    if (!mounted) return;
    
    // Initialize ConfigProvider first
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    await configProvider.initialize();
    if (!mounted) return;

    // Ensure cache provider is hydrated before any screen depends on it.
    final cacheProvider = Provider.of<CacheProvider>(context, listen: false);
    await cacheProvider.initialize();
    if (!mounted) return;
    
    // Initialize WalletProvider early to restore cached wallet
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    // WalletProvider already calls _init() in constructor, but let's ensure it's complete
    await Future.delayed(const Duration(milliseconds: 500)); // Give it time to complete async loading
    final walletAddress = walletProvider.currentWalletAddress;
    debugPrint('🔐 WalletProvider initialization complete. Has wallet: ${walletAddress != null}');
    if (!mounted) return;
    // Capture chatProvider early to avoid BuildContext use after async gaps
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    // Sync Web3Provider with WalletProvider if wallet was restored
    if (walletAddress != null) {
      final web3Provider = Provider.of<Web3Provider>(context, listen: false);
      try {
        await web3Provider.connectExistingWallet(walletAddress);
        debugPrint('✅ Web3Provider synced with restored wallet: $walletAddress');
      } catch (e) {
        debugPrint('⚠️ Web3Provider sync failed: $e');
      }
    }
    if (!mounted) return;
    
    // Initialize ProfileProvider and load profile if wallet exists
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    await profileProvider.initialize();
    if (walletAddress != null && walletAddress.isNotEmpty) {
      try {
        await profileProvider.loadProfile(walletAddress);
        debugPrint('✅ ProfileProvider loaded for wallet: $walletAddress');
      } catch (e) {
        debugPrint('⚠️ ProfileProvider load failed: $e');
      }
    }
    if (!mounted) return;
    // Initialize ChatProvider after WalletProvider and ProfileProvider are ready so wallet can be resolved
    try {
      // Use captured chatProvider instance
      // Ensure auth is initialized (attempt single issuance if wallet restored)
      try {
        await BackendApiService().ensureAuthLoaded(walletAddress: walletAddress);
        debugPrint('✅ BackendApiService.ensureAuthLoaded completed in AppInitializer');
      } catch (e) {
        debugPrint('⚠️ BackendApiService.ensureAuthLoaded failed in AppInitializer: $e');
      }
      if (!mounted) return;
      await chatProvider.initialize(initialWallet: walletAddress);
      if (!mounted) return;
      debugPrint('✅ ChatProvider initialized from AppInitializer');
    } catch (e) { debugPrint('⚠️ ChatProvider initialize from AppInitializer failed: $e'); }
    
    // Initialize SavedItemsProvider
    final savedItemsProvider = Provider.of<SavedItemsProvider>(context, listen: false);
    await savedItemsProvider.initialize();
    if (!mounted) return;
    
    // Initialize ArtworkProvider (no mock data needed)
    final artworkProvider = Provider.of<ArtworkProvider>(context, listen: false);
    artworkProvider.setUseMockData(false); // Always use backend data
    
    // ProfileProvider always uses backend data (no setUseMockData method)
    
    final prefs = await SharedPreferences.getInstance();
    
    // Check user state using standardized preference keys
    final isFirstTime = prefs.getBool('first_time') ?? true;
    final hasSeenWelcome = prefs.getBool(PreferenceKeys.hasSeenWelcome) ?? false;
    final isFirstLaunch = prefs.getBool(PreferenceKeys.isFirstLaunch) ?? true;
    
    // Check user preference for skipping onboarding (defaults to config setting)
    final userSkipOnboarding = prefs.getBool('skipOnboardingForReturningUsers') ?? AppConfig.skipOnboardingForReturningUsers;
    
    // Check wallet connection status
    final hasWallet = prefs.getBool('has_wallet') ?? false;
    final hasCompletedOnboarding = prefs.getBool('completed_onboarding') ?? false;
    
    // DEBUG: Print all flags
    debugPrint('🔍 AppInitializer DEBUG:');
    debugPrint('  isFirstTime: $isFirstTime');
    debugPrint('  hasSeenWelcome: $hasSeenWelcome');
    debugPrint('  isFirstLaunch: $isFirstLaunch');
    debugPrint('  userSkipOnboarding: $userSkipOnboarding');
    debugPrint('  hasWallet: $hasWallet');
    debugPrint('  hasCompletedOnboarding: $hasCompletedOnboarding');
    debugPrint('  showWelcomeScreen: ${AppConfig.showWelcomeScreen}');
    debugPrint('  enforceWalletOnboarding: ${AppConfig.enforceWalletOnboarding}');
    
    if (!mounted) return;
    
    // Navigate based on user state and configuration
    final shouldSkipOnboarding = userSkipOnboarding &&
      hasCompletedOnboarding &&
      (!isFirstTime || hasSeenWelcome || !isFirstLaunch);
    
    debugPrint('  shouldSkipOnboarding: $shouldSkipOnboarding');
    
    if (shouldSkipOnboarding) {
      // Returning user - skip onboarding and go directly to main app
      debugPrint('📍 Route: Skipping onboarding → MainApp');
      // Mark as no longer first time if not already set
      if (isFirstTime) {
        await prefs.setBool('first_time', false);
        await prefs.setBool(PreferenceKeys.hasSeenWelcome, true);
        await prefs.setBool(PreferenceKeys.isFirstLaunch, false);
      }
      
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainApp()),
      );
    } else if (!hasCompletedOnboarding) {
      // First-time user - show onboarding (no wallet required)
      debugPrint('📍 Route: First-time user → OnboardingScreen (wallet optional, setup when needed)');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      // Returning user who completed onboarding - go to main app (wallet optional)
      debugPrint('📍 Route: Returning user → MainApp (wallet optional)');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainApp()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const AppLoading(),
    );
  }
}

// Explore-only mode for users without wallets
class ExploreOnlyApp extends StatelessWidget {
  const ExploreOnlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('art.kubus - Explore'),
        actions: [
          TextButton(
            onPressed: () => _showWalletPrompt(context),
            child: const Text('Connect Wallet'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Text(
              'You\'re in explore-only mode. Connect a wallet to access all features.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover Art',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    context,
                    'Browse Collections',
                    'Explore amazing art collections from around the world',
                    Icons.collections,
                    () => _showWalletPrompt(context),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    context,
                    'AR Experience',
                    'View artworks in augmented reality',
                    Icons.view_in_ar,
                    () => _showWalletPrompt(context),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    context,
                    'Community',
                    'Join the art community discussions',
                    Icons.people,
                    () => _showWalletPrompt(context),
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureCard(
                    context,
                    'Marketplace',
                    'Discover and trade NFT artworks',
                    Icons.store,
                    () => _showWalletPrompt(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWalletPrompt(context),
        icon: const Icon(Icons.account_balance_wallet),
        label: const Text('Connect Wallet'),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.lock_outline),
        onTap: onTap,
      ),
    );
  }

  void _showWalletPrompt(BuildContext context) {
    debugPrint('DEBUG: Wallet prompt triggered'); // Debug print
    showDialog(
      context: context,
      builder: (context) => const WalletPromptScreen(),
    );
  }
}

// Wallet connection prompt dialog
class WalletPromptScreen extends StatelessWidget {
  const WalletPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            Icons.account_balance_wallet,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          const Text('Connect Wallet'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.security,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'To access this feature, you need to connect a Web3 wallet.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Set up your secure wallet to unlock:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Features list
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('• Buy and sell NFTs'),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('• Create your own artworks'),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('• Community interactions'),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            debugPrint('DEBUG: Set Up Wallet button pressed'); // Debug print
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          },
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Set Up Wallet'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// Utility functions for managing user onboarding state
class OnboardingManager {
  /// Mark user as a returning user to skip onboarding screens
  static Future<void> markAsReturningUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time', false);
    await prefs.setBool(PreferenceKeys.hasSeenWelcome, true);
    await prefs.setBool(PreferenceKeys.isFirstLaunch, false);
  }
  
  /// Reset user state to trigger onboarding again (useful for testing)
  static Future<void> resetOnboardingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time', true);
    await prefs.setBool(PreferenceKeys.hasSeenWelcome, false);
    await prefs.setBool(PreferenceKeys.isFirstLaunch, true);
    await prefs.remove('has_wallet');
    await prefs.remove('completed_onboarding');
    
    // Reset all Web3 feature onboarding
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.endsWith('_onboarding_completed')) {
        await prefs.remove(key);
      }
    }
  }
  
  /// Check if user should skip onboarding
  static Future<bool> shouldSkipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check user preference (defaults to config setting)
    final userSkipOnboarding = prefs.getBool('skipOnboardingForReturningUsers') ?? AppConfig.skipOnboardingForReturningUsers;
    if (!userSkipOnboarding) return false;
    
    final isFirstTime = prefs.getBool('first_time') ?? true;
    final hasSeenWelcome = prefs.getBool(PreferenceKeys.hasSeenWelcome) ?? false;
    final isFirstLaunch = prefs.getBool(PreferenceKeys.isFirstLaunch) ?? true;
    
    return (!isFirstTime || hasSeenWelcome || !isFirstLaunch);
  }
}

