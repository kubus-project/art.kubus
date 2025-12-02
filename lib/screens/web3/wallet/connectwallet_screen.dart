import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../services/event_bus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../providers/web3provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/app_refresh_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/recent_activity_provider.dart';
import '../../../services/solana_walletconnect_service.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/user_service.dart';
import '../../../models/user.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/gradient_icon_card.dart';
import '../../auth/sign_in_screen.dart';
import '../../auth/register_screen.dart';

class ConnectWallet extends StatefulWidget {
  final int initialStep;
  const ConnectWallet({super.key, this.initialStep = 0});

  @override
  State<ConnectWallet> createState() => _ConnectWalletState();
}

class _ConnectWalletState extends State<ConnectWallet> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final TextEditingController _mnemonicController = TextEditingController();
  
  bool _isLoading = false;
  late int _currentStep; // 0: Choose option, 1: Connect existing (mnemonic), 2: Create new (generate mnemonic), 3: WalletConnect
  final TextEditingController _wcUriController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep < 0
        ? 0
        : (widget.initialStep > 3 ? 3 : widget.initialStep);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mnemonicController.dispose();
    _wcUriController.dispose();
    super.dispose();
  }

  Future<void> _runPostWalletConnectRefresh(String walletAddress) async {
    if (!mounted) return;
    final appRefresh = Provider.of<AppRefreshProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    final activityProvider = Provider.of<RecentActivityProvider>(context, listen: false);

    try {
      await BackendApiService().ensureAuthLoaded(walletAddress: walletAddress);
    } catch (e) {
      debugPrint('connectwallet: ensureAuthLoaded after wallet connect failed: $e');
    }

    try {
      await chatProvider.initialize(initialWallet: walletAddress);
      await chatProvider.setCurrentWallet(walletAddress);
      await chatProvider.refreshConversations();
    } catch (e) {
      debugPrint('connectwallet: chat refresh after wallet connect failed: $e');
    }

    try {
      await notificationProvider.initialize(walletOverride: walletAddress, force: true);
    } catch (e) {
      debugPrint('connectwallet: NotificationProvider.initialize failed after wallet connect: $e');
    }

    try {
      await activityProvider.refresh(force: true);
    } catch (e) {
      debugPrint('connectwallet: RecentActivityProvider.refresh failed after wallet connect: $e');
    }

    try {
      appRefresh.triggerAll();
      appRefresh.triggerCommunity();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0 
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => setState(() => _currentStep--),
            )
          : IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
        title: Text(
          _getStepTitle(),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: Consumer<Web3Provider>(
        builder: (context, web3Provider, child) {
          if (web3Provider.isConnected) {
            return _buildConnectedView(web3Provider);
          } else {
            return _buildStepContent(web3Provider);
          }
        },
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Sign in to art.kubus';
      case 1:
        return 'Secure wallet access';
      case 2:
        return 'Secure wallet access';
      case 3:
        return 'Secure wallet access';
      default:
        return 'Sign in to art.kubus';
    }
  }

  

  Widget _buildStepContent(Web3Provider web3Provider) {
    switch (_currentStep) {
      case 0:
        return _buildChooseOptionView();
      case 1:
        return _buildConnectWithMnemonicView(web3Provider);
      case 2:
        return _buildCreateNewWalletView(web3Provider);
      case 3:
        return _buildWalletConnectView(web3Provider);
      default:
        return _buildChooseOptionView();
    }
  }

  Widget _buildChooseOptionView() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 360;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05,
              vertical: isSmallScreen ? 16 : 24,
            ),
            child: Column(
              children: [
                SizedBox(height: isSmallScreen ? 16 : 32),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      GradientIconCard(
                        start: Color.fromARGB(255, 9, 149, 20),
                        end: Color(0xFF3B82F6),
                        icon: Icons.account_balance_wallet_outlined,
                        iconSize: isSmallScreen ? 44 : 52,
                        width: isSmallScreen ? 84 : 100,
                        height: isSmallScreen ? 84 : 100,
                        radius: 16,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sign in securely',
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 22 : 24,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep your keys on-device and choose what suits you: connect a wallet, sign in with email/Google, or register. No seed phrases are stored.',
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 13 : 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 24),
                _buildActionButton(
                  icon: Icons.qr_code_scanner,
                  label: 'WalletConnect',
                  description: 'Connect with Phantom, Solflare, or other wallets (no gas fee)',
                  onTap: () => setState(() => _currentStep = 3),
                  isSmallScreen: isSmallScreen,
                ),
                _buildActionButton(
                  icon: Icons.login,
                  label: 'Sign in',
                  description: 'Use email/Google or existing wallet account',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                  isSmallScreen: isSmallScreen,
                ),
                _buildActionButton(
                  icon: Icons.person_add_alt,
                  label: 'Register',
                  description: 'Create a new account (keeps your keys self-custodied)',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  isSmallScreen: isSmallScreen,
                ),
                SizedBox(height: isSmallScreen ? 16 : 24),
                GestureDetector(
                  onTap: () => _showWeb3Guide(),
                  child: Text(
                    'How does this hybrid wallet work?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
    required bool isSmallScreen,
  }) {
    final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = icon == Icons.qr_code_scanner
        ? colorScheme.secondary
        : icon == Icons.login
            ? colorScheme.primary
            : icon == Icons.person_add_alt
                ? colorScheme.tertiary
                : accent;
    return _buildOptionCard(
      label,
      description,
      icon,
      iconColor,
      onTap,
      isSubdued: false,
    );
  }

  Widget _buildOptionCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isSubdued = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    Color startColor;
    Color endColor;
    if (icon == Icons.qr_code_scanner) {
      startColor = Color(0xFF06B6D4);
      endColor = Color(0xFF3B82F6);
    } else if (icon == Icons.login) {
      startColor = Color.fromARGB(255, 3, 115, 185);
      endColor = Color.fromARGB(255, 13, 228, 49);
    } else {
      startColor = Color(0xFFF59E0B);
      endColor = Color(0xFFEF4444);
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 14),
        padding: EdgeInsets.all(isSmallScreen ? 16 : 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: startColor.withValues(alpha: isSubdued ? 0.2 : 0.3),
            width: 1.5,
          ),
          boxShadow: isSubdued
              ? []
              : [
                  BoxShadow(
                    color: startColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: isSmallScreen ? 48 : 58,
              height: isSmallScreen ? 48 : 58,
              child: GradientIconCard(
                start: startColor,
                end: endColor,
                icon: icon,
                iconSize: isSmallScreen ? 24 : 28,
                width: isSmallScreen ? 48 : 58,
                height: isSmallScreen ? 48 : 58,
                radius: isSmallScreen ? 14 : 16,
              ),
            ),
            SizedBox(width: isSmallScreen ? 14 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 15 : 17,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: isSmallScreen ? 16 : 18,
            ),
          ],
        ),
      ),
    );
  }

  /* // Mock wallet connection method - REMOVED (use settings toggle instead)
  Future<void> _connectMockWallet() async {
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));
      await web3Provider.connectWallet(isRealConnection: false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mock wallet connected successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  */ // End of removed mock wallet connection

  // Connect wallet with mnemonic phrase view
  Widget _buildConnectWithMnemonicView(Web3Provider web3Provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: isSmallScreen ? 16 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 12 : 16),
              Center(
                child: Column(
                  children: [
                    GradientIconCard(
                      start: Color(0xFF0EA5E9),
                      end: Color(0xFF06B6D4),
                      icon: Icons.vpn_key_rounded,
                      iconSize: isSmallScreen ? 44 : 52,
                      width: isSmallScreen ? 88 : 100,
                      height: isSmallScreen ? 88 : 100,
                      radius: 20,
                    ),
                    SizedBox(height: isSmallScreen ? 14 : 18),
                    Text(
                      'Import Wallet',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 22 : 26,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'Enter your 12-word recovery phrase to import your Solana wallet',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 14 : 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
            
              // Mnemonic Input Field
              TextField(
                controller: _mnemonicController,
                maxLines: isSmallScreen ? 3 : 4,
                decoration: InputDecoration(
                  hintText: 'Enter your 12-word recovery phrase separated by spaces',
                  hintStyle: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 12 : 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 12 : 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 14),
            
              // Warning Box
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: isSmallScreen ? 20 : 22),
                    SizedBox(width: isSmallScreen ? 10 : 12),
                    Expanded(
                      child: Text(
                        'Never share your recovery phrase with anyone. art.kubus will never ask for it.',
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              
              // Connect Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _importWalletFromMnemonic(web3Provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0EA5E9),
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                    disabledBackgroundColor: Colors.blue.withValues(alpha: 0.5),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Import Wallet',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 16 : 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importWalletFromMnemonic(Web3Provider web3Provider) async {
    final mnemonic = _mnemonicController.text.trim();
    
    if (mnemonic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your recovery phrase'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // Validate mnemonic format (12 words)
    final words = mnemonic.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid recovery phrase. Expected 12 words, got ${words.length}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final address = await walletProvider.importWalletFromMnemonic(mnemonic);

      // Import the wallet in Web3Provider as well
      await web3Provider.importWallet(mnemonic);
      
        // Load or create user profile linked to wallet
          if (mounted) {
          final backendApiService = BackendApiService();

          // Prefer cache-first lookup via UserService to avoid unnecessary network calls
          bool profileExistsOnBackend = false;
          try {
            // Force a fresh lookup during wallet import
            final freshUser = await UserService.getUserById(address, forceRefresh: true);
            if (freshUser != null) {
              profileExistsOnBackend = true;
              debugPrint('Profile found (fresh) for wallet: $address');
            } else {
              try {
                await backendApiService.getProfileByWallet(address);
                profileExistsOnBackend = true;
                debugPrint('Profile exists on backend for wallet: $address');
              } catch (e) {
                debugPrint('Profile not found on backend, will create new: $e');
              }
            }
          } catch (e) {
            debugPrint('Profile lookup failed: $e');
          }

          // Load profile (will create default if doesn't exist)
          await profileProvider.loadProfile(address);

          // Only register on backend if profile doesn't exist there yet
            if (!profileExistsOnBackend && profileProvider.currentUser != null) {
            debugPrint('Registering wallet on backend for wallet: $address');
            await UserService.initialize();
            try {
              final reg = await BackendApiService().registerWallet(
                walletAddress: address,
                username: profileProvider.currentUser!.username.replaceFirst(RegExp(r'^@+'), ''),
              );
              debugPrint('registerWallet response: $reg');
              // Reload profile after registration
              await profileProvider.loadProfile(address);
            } catch (e) {
              debugPrint('Backend registration failed: $e');
            }
              // Update ChatProvider cache so messages/conversations show correct avatar/name immediately
              try {
                final updated = profileProvider.currentUser;
                if (updated != null) {
                  final user = User(
                    id: updated.walletAddress,
                    name: updated.displayName,
                    username: updated.username,
                    bio: updated.bio,
                    profileImageUrl: updated.avatar,
                    followersCount: updated.stats?.followersCount ?? 0,
                    followingCount: updated.stats?.followingCount ?? 0,
                    postsCount: updated.stats?.artworksCreated ?? 0,
                    isFollowing: false,
                    isVerified: false,
                    joinedDate: updated.createdAt.toIso8601String(),
                    achievementProgress: [],
                  );
                  try { EventBus().emitProfileUpdated(user); } catch (_) {}
                }
              } catch (_) {}
          }

          // After profile is loaded/created, inform ChatProvider so chats and unread badges refresh
          try {
            await chatProvider.setCurrentWallet(address);
          } catch (e) {
            debugPrint('connectwallet: failed to set chat provider wallet after import: $e');
          }
          try {
            await _runPostWalletConnectRefresh(address);
          } catch (_) {}
        }
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Wallet imported successfully!\nAddress: ${address.substring(0, 8)}...'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import wallet: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  // Create new wallet view - generates mnemonic
  Widget _buildCreateNewWalletView(Web3Provider web3Provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360 || screenHeight < 700;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: isSmallScreen ? 16 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 12 : 16),
              Center(
                child: Column(
                  children: [
                    GradientIconCard(
                      start: Color(0xFF10B981),
                      end: Color(0xFF059669),
                      icon: Icons.add_circle_outline_rounded,
                      iconSize: isSmallScreen ? 44 : 52,
                      width: isSmallScreen ? 88 : 100,
                      height: isSmallScreen ? 88 : 100,
                      radius: 20,
                    ),
                    SizedBox(height: isSmallScreen ? 14 : 18),
                    Text(
                      'Create New Wallet',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 22 : 26,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'Generate a new Solana wallet with a 12-word recovery phrase',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 14 : 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              
              // Info Box
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green, size: isSmallScreen ? 20 : 22),
                        SizedBox(width: isSmallScreen ? 10 : 12),
                        Text(
                          'What you\'ll receive:',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 14 : 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10 : 12),
                    Text(
                      '• A new Solana wallet address\n• A 12-word recovery phrase\n• Full ownership and control\n\nYou\'ll need to write down and confirm your recovery phrase before proceeding.',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              
              // Warning Box
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: isSmallScreen ? 20 : 22),
                    SizedBox(width: isSmallScreen ? 10 : 12),
                    Expanded(
                      child: Text(
                        'Keep your recovery phrase safe! It\'s the only way to recover your wallet. Never share it with anyone.',
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              
              // Generate Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _generateNewWallet(web3Provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF10B981),
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                    disabledBackgroundColor: Colors.green.withValues(alpha: 0.5),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Generate Wallet',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 16 : 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Already have a wallet? ',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentStep = 1),
                    child: Text(
                      'Import it here',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
            ],
          ),
        ),
      ),
    );
  }

  // WalletConnect view - scan QR or paste URI
  Widget _buildWalletConnectView(Web3Provider web3Provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360 || screenHeight < 700;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: isSmallScreen ? 16 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 12 : 16),
              Center(
                child: Column(
                  children: [
                    GradientIconCard(
                      start: Color(0xFF06B6D4),
                      end: Color(0xFF3B82F6),
                      icon: Icons.qr_code_scanner_rounded,
                      iconSize: isSmallScreen ? 44 : 52,
                      width: isSmallScreen ? 88 : 100,
                      height: isSmallScreen ? 88 : 100,
                      radius: 20,
                    ),
                    SizedBox(height: isSmallScreen ? 14 : 18),
                    Text(
                      'Connect with WalletConnect',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 22 : 26,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'Connect your existing Solana wallet like Phantom or Solflare using WalletConnect',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 14 : 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
            
              // Supported Wallets
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.blue, size: isSmallScreen ? 20 : 22),
                        SizedBox(width: isSmallScreen ? 10 : 12),
                        Text(
                          'Supported Wallets:',
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 14 : 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 10 : 12),
                    Text(
                      '• Phantom Wallet\n• Solflare\n• Backpack\n• Any WalletConnect-compatible Solana wallet',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
            
              // Instructions
              Text(
                'How to connect:',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: isSmallScreen ? 10 : 12),
              _buildInstructionStep('1', 'Open your Solana wallet app'),
              _buildInstructionStep('2', 'Tap on WalletConnect or scan QR code'),
              _buildInstructionStep('3', 'Scan the QR code or paste the connection URI below'),
              SizedBox(height: isSmallScreen ? 16 : 20),
            
              // Quick connect without typing
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _quickWalletConnect(web3Provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                  label: Text(
                    _isLoading ? 'Connecting...' : 'Quick connect (paste/scan)',
                    style: GoogleFonts.inter(
                      fontSize: isSmallScreen ? 15 : 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 14),
              
              // URI Input Field
              TextField(
                controller: _wcUriController,
                maxLines: isSmallScreen ? 2 : 3,
                decoration: InputDecoration(
                  hintText: 'Paste WalletConnect URI here\n(e.g., wc:abc123...)',
                  hintStyle: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.paste, size: isSmallScreen ? 18 : 20),
                    onPressed: () async {
                      final clipboardData = await Clipboard.getData('text/plain');
                      if (clipboardData?.text != null) {
                        setState(() {
                          _wcUriController.text = clipboardData!.text!;
                        });
                      }
                    },
                  ),
                ),
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 14),
            
              // Info Box
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: isSmallScreen ? 18 : 20),
                    SizedBox(width: isSmallScreen ? 10 : 12),
                    Expanded(
                      child: Text(
                        'Your wallet remains secure on your device. We never have access to your private keys.',
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 24),
              
              // Connect Buttons
              isSmallScreen
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _scanQRCode(web3Provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Colors.blue.withValues(alpha: 0.5),
                            ),
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                            label: Text(
                              'Scan QR',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _connectWithWalletConnect(web3Provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Colors.blue.withValues(alpha: 0.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: InlineLoading(shape: BoxShape.circle, tileSize: 4.0, color: Colors.white),
                                  )
                                : Text(
                                    'Connect',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _scanQRCode(web3Provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Colors.blue.withValues(alpha: 0.5),
                            ),
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                            label: Text(
                              'Scan QR',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _connectWithWalletConnect(web3Provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Colors.blue.withValues(alpha: 0.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: InlineLoading(shape: BoxShape.circle, tileSize: 4.0, color: Colors.white),
                                  )
                                : Text(
                                    'Connect',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
              SizedBox(height: isSmallScreen ? 16 : 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Don\'t have a wallet? ',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentStep = 2),
                    child: Text(
                      'Create one here',
                      style: GoogleFonts.inter(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Colors.green,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 20 : 22,
            height: isSmallScreen ? 20 : 22,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 11),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 11 : 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 12 : 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQRCode(Web3Provider web3Provider) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              'Scan WalletConnect QR Code',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.black,
          ),
          body: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null && barcode.rawValue!.startsWith('wc:')) {
                      Navigator.pop(context, barcode.rawValue);
                      break;
                    }
                  }
                },
              ),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Position QR code within frame',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _wcUriController.text = result;
      });
      await _connectWithWalletConnect(web3Provider);
    }
  }

  Future<void> _quickWalletConnect(Web3Provider web3Provider) async {
    // Try clipboard first
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      final text = clipboardData?.text?.trim();
      if (text != null && text.startsWith('wc:')) {
        setState(() {
          _wcUriController.text = text;
        });
        await _connectWithWalletConnect(web3Provider);
        return;
      }
    } catch (_) {}

    // If no URI in clipboard, fall back to scanner (mobile) or prompt
    if (!mounted) return;
    await _scanQRCode(web3Provider);
  }

  Future<void> _connectWithWalletConnect(Web3Provider web3Provider) async {
    final uri = _wcUriController.text.trim();
    
    if (uri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a WalletConnect URI'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (!uri.startsWith('wc:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invalid WalletConnect URI format'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final walletAddress = walletProvider.currentWalletAddress;
      if (walletAddress == null || walletAddress.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Create or import a wallet before using WalletConnect'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      final wcService = SolanaWalletConnectService.instance;
      wcService.updateActiveWalletAddress(walletAddress);
      
      // Initialize if not already done
      if (!wcService.isConnected) {
        await wcService.initialize();
      }
      
      // Do not capture BuildContext-dependent objects here — capture inside the callback after verifying mounted

      // Set up callbacks
      wcService.onConnected = (address) async {
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Connected to $address'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Update wallet provider and web3 provider
          debugPrint('connectwallet: calling web3Provider.connectExistingWallet for $address');
          await web3Provider.connectExistingWallet(address);
          debugPrint('connectwallet: web3Provider.connectExistingWallet completed for $address');

          // Load or create profile for this wallet, similar to import flow
          try {
            // use captured profileProvider
            debugPrint('connectwallet: calling profileProvider.loadProfile for $address');
            final backendApiService = BackendApiService();
            bool profileExistsOnBackend = false;
            try {
              final freshUser = await UserService.getUserById(address, forceRefresh: true);
              if (freshUser != null) {
                profileExistsOnBackend = true;
              } else {
                try {
                  await backendApiService.getProfileByWallet(address);
                  profileExistsOnBackend = true;
                } catch (_) {}
              }
            } catch (_) {}

            await profileProvider.loadProfile(address);
            debugPrint('connectwallet: profileProvider.loadProfile completed for $address');
            if (!profileExistsOnBackend && profileProvider.currentUser != null) {
              try {
                final reg = await BackendApiService().registerWallet(
                  walletAddress: address,
                  username: profileProvider.currentUser!.username.replaceFirst(RegExp(r'^@+'), ''),
                );
                debugPrint('connectwallet (onConnected): registerWallet response: $reg');
                await profileProvider.loadProfile(address);
                // Update ChatProvider cache to immediately reflect profile changes in messages UI
                try {
                  final u = profileProvider.currentUser;
                  if (u != null) {
                    final user = User(
                      id: u.walletAddress,
                      name: u.displayName,
                      username: u.username,
                      bio: u.bio,
                      profileImageUrl: u.avatar,
                      followersCount: u.stats?.followersCount ?? 0,
                      followingCount: u.stats?.followingCount ?? 0,
                      postsCount: u.stats?.artworksCreated ?? 0,
                      isFollowing: false,
                      isVerified: false,
                      joinedDate: u.createdAt.toIso8601String(),
                      achievementProgress: [],
                    );
                    try { EventBus().emitProfileUpdated(user); } catch (_) {}
                  }
                } catch (_) {}
              } catch (e) {
                debugPrint('connectwallet (onConnected): backend registration failed: $e');
              }
            }
          } catch (e, st) {
            debugPrint('connectwallet: profile load/create failed after walletconnect: $e\n$st');
          }

          // Inform ChatProvider so it can subscribe and refresh conversations/unread
          try {
            debugPrint('connectwallet: calling ChatProvider.setCurrentWallet for $address');
            await chatProvider.setCurrentWallet(address);
            debugPrint('connectwallet: ChatProvider.setCurrentWallet completed for $address');
          } catch (e, st) {
            debugPrint('connectwallet: failed to set chat provider wallet after walletconnect: $e\n$st');
          }
          try {
            await _runPostWalletConnectRefresh(address);
          } catch (_) {}
          navigator.pop();
        }
      };
      
      wcService.onError = (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection error: $error'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      };
      
      // Pair with the URI
      await wcService.pair(uri);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Waiting for wallet approval...'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _generateNewWallet(Web3Provider web3Provider) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      // Capture providers and UI state before any awaits to avoid use_build_context_synchronously
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      final result = await walletProvider.createWallet();
      
      // Show the mnemonic to the user
      if (mounted) {
        await _showMnemonicDialog(result['mnemonic']!, result['address']!);
        
        // Import the wallet in Web3Provider using the generated mnemonic
        await web3Provider.importWallet(result['mnemonic']!);
        // Notify ChatProvider about the new wallet so conversations and sockets refresh
        try {
          await chatProvider.setCurrentWallet(result['address']!);
        } catch (e) {
          debugPrint('connectwallet: failed to set chat provider wallet after create: $e');
        }
        
        // Create user profile linked to wallet
        if (mounted) {
          // profileProvider captured earlier
          final backendApiService = BackendApiService();
          final address = result['address']!;
          
          // Prefer cache-first lookup via UserService to avoid unnecessary network calls
          bool profileExistsOnBackend = false;
          try {
            // Force fresh lookup during wallet creation
            final freshUser = await UserService.getUserById(address, forceRefresh: true);
            if (freshUser != null) {
              profileExistsOnBackend = true;
              debugPrint('Profile found (fresh) for wallet: $address');
            } else {
              try {
                await backendApiService.getProfileByWallet(address);
                profileExistsOnBackend = true;
                debugPrint('Profile exists on backend for wallet: $address');
              } catch (e) {
                debugPrint('Profile not found on backend, will create new: $e');
              }
            }
          } catch (e) {
            debugPrint('Profile lookup failed: $e');
          }
          
          // Only create profile if it doesn't exist on backend
          if (!profileExistsOnBackend) {
            debugPrint('Creating new profile for wallet: $address');
            final created = await profileProvider.createProfileFromWallet(
              walletAddress: address,
            );
            if (created) {
              // Load the newly created profile to update local state
              debugPrint('Profile created, now loading it...');
              await profileProvider.loadProfile(address);
            }
          } else {
            debugPrint('Profile already exists, loading it');
            await profileProvider.loadProfile(address);
          }
        }
        
        if (mounted) {
          try {
            await _runPostWalletConnectRefresh(result['address']!);
          } catch (_) {}
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Wallet created and profile set up successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          navigator.pop();
        }
      }
    } catch (e) {
        if (mounted) {
          setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create wallet: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showMnemonicDialog(String mnemonic, String address) async {
    final TextEditingController confirmController = TextEditingController();
    bool confirmed = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Save Your Recovery Phrase',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Write this down and keep it safe!',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  child: SelectableText(
                    mnemonic,
                    style: GoogleFonts.robotoMono(
                      fontSize: 14,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirm by typing your recovery phrase:',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Paste or type your recovery phrase',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      confirmed = value.trim() == mnemonic;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Your wallet address: ${address.substring(0, 8)}...${address.substring(address.length - 6)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: confirmed
                  ? () {
                      confirmController.dispose();
                      Navigator.pop(context);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
              ),
              child: Text(
                'I\'ve Saved It',
                style: GoogleFonts.inter(
                  color: confirmed ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedView(Web3Provider web3Provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.06,
          vertical: isSmallScreen ? 16 : 24,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GradientIconCard(
              start: Color(0xFF10B981),
              end: Color(0xFF059669),
              icon: Icons.check_circle_rounded,
              iconSize: isSmallScreen ? 56 : 68,
              width: isSmallScreen ? 100 : 120,
              height: isSmallScreen ? 100 : 120,
              radius: 28,
            ),
            SizedBox(height: isSmallScreen ? 28 : 32),
            Text(
              'Wallet Connected!',
              style: GoogleFonts.inter(
                fontSize: isSmallScreen ? 26 : 30,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 12 : 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Your wallet is now connected to art.kubus. You can now explore AR art, trade NFTs, and participate in the ecosystem.',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 14 : 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: isSmallScreen ? 32 : 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF10B981),
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 16 : 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Start Exploring',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 17 : 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 14),
            TextButton(
              onPressed: () {
                web3Provider.disconnectWallet();
                Provider.of<WalletProvider>(context, listen: false).disconnectWallet();
              },
              child: Text(
                'Disconnect Wallet',
                style: GoogleFonts.inter(
                  fontSize: isSmallScreen ? 14 : 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }








  void _showWeb3Guide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'What is a Web3 Wallet?',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A Web3 wallet is your gateway to the decentralized internet:',
                style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 16),
              _buildFeaturePoint(Icons.lock, 'Secure', 'Your keys, your crypto'),
              _buildFeaturePoint(Icons.palette, 'NFTs', 'Store and trade digital art'),
              _buildFeaturePoint(Icons.how_to_vote, 'Governance', 'Vote on platform decisions'),
              _buildFeaturePoint(Icons.account_balance_wallet, 'DeFi', 'Access decentralized finance'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'Got it!',
              style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePoint(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon, 
            size: 24,
            color: Provider.of<ThemeProvider>(context).accentColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

