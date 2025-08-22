import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
import '../onboarding/onboarding_screen.dart';
import '../main_app.dart';

/// App initializer that determines whether to show onboarding or main app
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _showOnboarding = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if user has completed onboarding
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
      final hasWallet = prefs.getBool('has_wallet') ?? false;

      // Wait for theme provider to initialize
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      while (!themeProvider.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      setState(() {
        _showOnboarding = !hasCompletedOnboarding || !hasWallet;
        _isLoading = false;
      });

      // If user has wallet, try to auto-connect
      if (hasWallet && !_showOnboarding) {
        final web3Provider = Provider.of<Web3Provider>(context, listen: false);
        try {
          await web3Provider.connectWallet();
        } catch (e) {
          // Auto-connect failed, user can manually connect later
          debugPrint('Auto-connect failed: $e');
        }
      }
    } catch (e) {
      debugPrint('App initialization error: $e');
      setState(() {
        _isLoading = false;
        _showOnboarding = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen();
    }

    if (_showOnboarding) {
      return const OnboardingScreen();
    }

    return const MainApp();
  }
}

/// Loading screen shown during app initialization
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode 
          ? const Color(0xFF0A0A0A) 
          : const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeProvider.accentColor,
                    themeProvider.accentColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(themeProvider.accentColor),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Initializing art.kubus...',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
