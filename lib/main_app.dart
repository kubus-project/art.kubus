import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/themeprovider.dart';
import 'providers/wallet_provider.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/ar_screen.dart';
import 'screens/community_screen.dart';
import 'screens/profile_screen.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0; // Start with map (index 0)
  
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      const MapScreen(),
      const ARScreen(),
      const CommunityScreen(),
      const HomeScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
        ),

        // Lock overlay: shows above everything when wallet is locked
        if (walletProvider.isLocked)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'App locked',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Authenticate to unlock access to the wallet features.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          // Ensure mounted and capture provider before async ops to avoid using BuildContext across awaits
                          if (!mounted) return;
                          final localWallet = Provider.of<WalletProvider>(context, listen: false);
                          final messenger = ScaffoldMessenger.of(context);
                          final dialogContext = context;
                          // Try biometric unlock first
                          final ok = await localWallet.authenticateForAppUnlock();
                          if (ok) {
                            if (!mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('App unlocked')));
                            return;
                          }

                          // Biometric not available or failed — prompt for PIN
                          final pinController = TextEditingController();
                          if (!mounted) return;
                          final entered = await showDialog<String?>(
                            context: dialogContext,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Enter PIN to unlock'),
                              content: TextField(
                                controller: pinController,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'PIN'),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(ctx).pop(pinController.text.trim()),
                                  child: const Text('Unlock'),
                                ),
                              ],
                            ),
                          );

                          if (entered == null || entered.isEmpty) return;
                          final ok2 = await localWallet.authenticateForAppUnlock(pin: entered);
                          if (ok2) {
                            if (!mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('App unlocked')));
                          } else {
                            if (!mounted) return;
                            messenger.showSnackBar(const SnackBar(content: Text('Authentication failed')));
                          }
                        },
                        child: const Text('Unlock'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 375;
        
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 4 : 8, 
                vertical: isSmallScreen ? 2 : 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.explore, isSmallScreen),
                  _buildNavItem(1, Icons.view_in_ar, isSmallScreen),
                  _buildNavItem(2, Icons.people, isSmallScreen),
                  _buildNavItem(3, Icons.home, isSmallScreen),
                  _buildNavItem(4, Icons.person, isSmallScreen),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, bool isSmallScreen) {
    final isSelected = _currentIndex == index;
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 4 : 8, 
            vertical: isSmallScreen ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: isSelected 
                ? themeProvider.accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? themeProvider.accentColor
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: isSmallScreen ? 24 : 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
