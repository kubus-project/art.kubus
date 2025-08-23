import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../providers/config_provider.dart';
import '../providers/profile_provider.dart';
import '../screens/welcome_intro_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../main_app.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize ConfigProvider first
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    await configProvider.initialize();
    
    // Initialize ProfileProvider
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    await profileProvider.initialize();
    
    // Connect ProfileProvider to ConfigProvider for mock data sync
    profileProvider.setUseMockData(configProvider.useMockData);
    
    final prefs = await SharedPreferences.getInstance();
    
    // Check if it's the first time opening the app
    final isFirstTime = prefs.getBool('first_time') ?? true;
    
    // Check wallet connection status
    final hasWallet = prefs.getBool('has_wallet') ?? false;
    final hasCompletedOnboarding = prefs.getBool('completed_onboarding') ?? false;
    
    if (!mounted) return;
    
    // Navigate based on user state
    if (isFirstTime) {
      // First time user - show welcome screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WelcomeIntroScreen()),
      );
    } else if (!hasWallet || !hasCompletedOnboarding) {
      // User needs wallet setup or onboarding
      if (AppConfig.enforceWalletOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      } else {
        // Show explore-only mode
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ExploreOnlyApp()),
        );
      }
    } else {
      // Existing user with wallet - go to main app
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainApp()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const Center(
        child: CircularProgressIndicator(),
      ),
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
            color: Theme.of(context).primaryColor.withOpacity(0.1),
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
    print('DEBUG: Wallet prompt triggered'); // Debug print
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
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
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
            print('DEBUG: Set Up Wallet button pressed'); // Debug print
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
