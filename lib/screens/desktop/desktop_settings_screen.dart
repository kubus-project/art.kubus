import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/web3provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/platform_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../utils/app_animations.dart';
import 'components/desktop_widgets.dart';
import 'community/desktop_profile_edit_screen.dart';
import '../web3/wallet/wallet_home.dart';
import '../web3/wallet/mnemonic_reveal_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../../../config/config.dart';


/// Desktop profile and settings screen
/// Clean dashboard layout with account info and settings
class DesktopSettingsScreen extends StatefulWidget {
  const DesktopSettingsScreen({super.key});

  @override
  State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends State<DesktopSettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;

  int _selectedSettingsIndex = 0;

  // Profile settings state
  String _profileVisibility = 'Public';
  
  // Privacy settings state
  bool _dataCollection = true;
  bool _personalizedAds = true;
  bool _locationTracking = true;
  String _dataRetention = '1 Year';
  
  // Security settings state
  bool _twoFactorAuth = false;
  bool _sessionTimeout = true;
  String _autoLockTime = '5 minutes';
  bool _loginNotifications = true;
  bool _biometricAuth = false;
  bool _privacyMode = false;
  
  // Account settings state
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _marketingEmails = false;
  String _accountType = 'Standard';
  bool _publicProfile = true;
  
  // App settings state
  bool _analytics = true;
  bool _crashReporting = true;
  bool _skipOnboardingForReturningUsers = true;
  
  // Wallet settings state
  String _networkSelection = 'Mainnet';
  bool _autoBackup = true;
  
  // Profile interaction settings
  bool _showAchievements = true;
  bool _showFriends = true;
  bool _allowMessages = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: 11, vsync: this);
    _animationController.forward();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final settings = await SettingsService.loadSettings(
      fallbackNetwork:
          web3Provider.currentNetwork.isNotEmpty ? web3Provider.currentNetwork : null,
    );
    if (!mounted) return;

    setState(() {
      _profileVisibility = settings.profileVisibility;
      _showAchievements = settings.showAchievements;
      _showFriends = settings.showFriends;
      _allowMessages = settings.allowMessages;

      _dataCollection = settings.dataCollection;
      _personalizedAds = settings.personalizedAds;
      _locationTracking = settings.locationTracking;
      _dataRetention = settings.dataRetention;

      _twoFactorAuth = settings.twoFactorAuth;
      _sessionTimeout = settings.sessionTimeout;
      _autoLockTime = settings.autoLockTime;
      _loginNotifications = settings.loginNotifications;
      _biometricAuth = settings.biometricAuth;
      _privacyMode = settings.privacyMode;

      _emailNotifications = settings.emailNotifications;
      _pushNotifications = settings.pushNotifications;
      _marketingEmails = settings.marketingEmails;
      _accountType = settings.accountType;
      _publicProfile = settings.publicProfile;

      _analytics = settings.analytics;
      _crashReporting = settings.crashReporting;
      _skipOnboardingForReturningUsers = settings.skipOnboarding;

      _networkSelection = settings.networkSelection;
      _autoBackup = settings.autoBackup;
    });
  }

  Future<void> _saveSettings() async {
    await SettingsService.saveSettings(_buildSettingsState());
  }

  SettingsState _buildSettingsState() {
    return SettingsState(
      pushNotifications: _pushNotifications,
      emailNotifications: _emailNotifications,
      marketingEmails: _marketingEmails,
      loginNotifications: _loginNotifications,
      dataCollection: _dataCollection,
      personalizedAds: _personalizedAds,
      locationTracking: _locationTracking,
      dataRetention: _dataRetention,
      twoFactorAuth: _twoFactorAuth,
      sessionTimeout: _sessionTimeout,
      autoLockTime: _autoLockTime,
      autoLockSeconds: _autoLockSecondsFromLabel(_autoLockTime),
      biometricAuth: _biometricAuth,
      privacyMode: _privacyMode,
      analytics: _analytics,
      crashReporting: _crashReporting,
      skipOnboarding: _skipOnboardingForReturningUsers,
      networkSelection: _networkSelection,
      autoBackup: _autoBackup,
      profileVisibility: _profileVisibility,
      showAchievements: _showAchievements,
      showFriends: _showFriends,
      allowMessages: _allowMessages,
      accountType: _accountType,
      publicProfile: _publicProfile,
    );
  }

  int _autoLockSecondsFromLabel(String label) {
    switch (label.toLowerCase()) {
      case '10 seconds':
        return 10;
      case '30 seconds':
        return 30;
      case '1 minute':
        return 60;
      case '5 minutes':
        return 5 * 60;
      case '15 minutes':
        return 15 * 60;
      case '30 minutes':
        return 30 * 60;
      case '1 hour':
        return 60 * 60;
      case '3 hours':
        return 3 * 60 * 60;
      case '6 hours':
        return 6 * 60 * 60;
      case '12 hours':
        return 12 * 60 * 60;
      case '1 day':
        return 24 * 60 * 60;
      case 'never':
        return 0;
      default:
        return 5 * 60;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final animationTheme = context.animationTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLarge = screenWidth >= 1200;

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF8F9FA),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: _animationController,
              curve: animationTheme.fadeCurve,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Settings sidebar
                if (isLarge)
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: _buildSettingsSidebar(themeProvider),
                  ),

                // Main content
                Expanded(
                  child: _buildMainContent(themeProvider, isLarge),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsSidebar(ThemeProvider themeProvider) {
    final settingsItems = [
      _SettingsItem('Profile', Icons.person_outline, 0),
      _SettingsItem('Wallet & Web3', Icons.account_balance_wallet_outlined, 1),
      _SettingsItem('Appearance', Icons.palette_outlined, 2),
      _SettingsItem('Notifications', Icons.notifications_outlined, 3),
      _SettingsItem('Privacy', Icons.lock_outline, 4),
      _SettingsItem('Security', Icons.security, 5),
      _SettingsItem('Achievements', Icons.emoji_events_outlined, 6),
      _SettingsItem('Platform', Icons.phone_android_outlined, 7),
      _SettingsItem('Help & Support', Icons.help_outline, 8),
      _SettingsItem('About', Icons.info_outline, 9),
      _SettingsItem('Danger Zone', Icons.warning_outlined, 10),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header with back button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: 'Back',
              ),
              const SizedBox(width: 8),
              Text(
                'Settings',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Settings items
        ...settingsItems.map((item) => _buildSettingsSidebarItem(item, themeProvider)),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // Logout button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    size: 22,
                    color: const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Log Out',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSidebarItem(_SettingsItem item, ThemeProvider themeProvider) {
    final isSelected = _selectedSettingsIndex == item.index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedSettingsIndex = item.index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? themeProvider.accentColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 22,
                color: isSelected
                    ? themeProvider.accentColor
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 16),
              Text(
                item.title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(ThemeProvider themeProvider, bool isLarge) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: _buildHeader(themeProvider),
        ),

        // Content based on selected setting
        SliverFillRemaining(
          child: _buildSelectedContent(themeProvider),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeProvider themeProvider) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        final user = profileProvider.currentUser;

        return Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile card
              DesktopCard(
                padding: EdgeInsets.zero,
                showBorder: false,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        themeProvider.accentColor,
                        themeProvider.accentColor.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(
                        avatarUrl: user?.avatar,
                        wallet: user?.walletAddress ?? '',
                        radius: 48,
                        allowFabricatedFallback: true,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'Anonymous User',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (user?.bio != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                user!.bio,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildProfileStat('Artworks', (user?.stats?.artworksCreated ?? 0).toString()),
                                const SizedBox(width: 24),
                                _buildProfileStat('Followers', (user?.stats?.followersCount ?? 0).toString()),
                                const SizedBox(width: 24),
                                _buildProfileStat('Following', (user?.stats?.followingCount ?? 0).toString()),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final web3Provider = Provider.of<Web3Provider>(context, listen: false);
                          final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
                          final result = await navigator.push(
                            MaterialPageRoute(
                              builder: (context) => const ProfileEditScreen(),
                            ),
                          );
                          // Reload profile if changes were saved
                          if (!mounted) return;
                          if (result == true && web3Provider.isConnected && web3Provider.walletAddress.isNotEmpty) {
                            await profileProvider.loadProfile(web3Provider.walletAddress);
                          }
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: themeProvider.accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedContent(ThemeProvider themeProvider) {
    switch (_selectedSettingsIndex) {
      case 0:
        return _buildProfileSettings(themeProvider);
      case 1:
        return _buildWalletSettings(themeProvider);
      case 2:
        return _buildAppearanceSettings(themeProvider);
      case 3:
        return _buildNotificationSettings(themeProvider);
      case 4:
        return _buildPrivacySettings(themeProvider);
      case 5:
        return _buildSecuritySettings(themeProvider);
      case 6:
        return _buildAchievementsSettings();
      case 7:
        return _buildPlatformCapabilitiesSection();
      case 8:
        return _buildHelpSettings();
      case 9:
        return _buildAboutSettings();
      case 10:
        return _buildDangerZoneSettings();
      default:
        return _buildProfileSettings(themeProvider);
    }
  }

  Widget _buildProfileSettings(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Information',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Update your profile information visible to other users',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          
          DesktopCard(
            child: Column(
              children: [
                _buildTextField('Display Name', 'Enter your name'),
                const SizedBox(height: 20),
                _buildTextField('Username', '@username'),
                const SizedBox(height: 20),
                _buildTextField('Bio', 'Tell us about yourself', maxLines: 3),
                const SizedBox(height: 20),
                _buildTextField('Website', 'https://'),
                const SizedBox(height: 20),
                _buildTextField('Location', 'City, Country'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).colorScheme.primaryContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Provider.of<ThemeProvider>(context).accentColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletSettings(ThemeProvider themeProvider) {
    final web3Provider = Provider.of<Web3Provider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet & Web3',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your wallet connection and Web3 settings',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            
            // Connection status
            DesktopCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (web3Provider.isConnected
                                  ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.secondary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          web3Provider.isConnected 
                              ? Icons.check_circle 
                              : Icons.warning,
                          color: web3Provider.isConnected
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              web3Provider.isConnected 
                                  ? 'Wallet Connected' 
                                  : 'No Wallet Connected',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (web3Provider.isConnected)
                              Text(
                                web3Provider.formatAddress(web3Provider.walletAddress),
                                style: GoogleFonts.robotoMono(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (web3Provider.isConnected)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WalletHome()),
                            );
                          },
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('View Wallet'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.accentColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Network selection
            DesktopCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Network',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ['Mainnet', 'Devnet', 'Testnet'].map((network) {
                      final isSelected = web3Provider.currentNetwork.toLowerCase() == network.toLowerCase();
                      return ChoiceChip(
                        label: Text(network),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            web3Provider.switchNetwork(network);
                            walletProvider.switchSolanaNetwork(network);
                          }
                        },
                        selectedColor: themeProvider.accentColor.withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.inter(
                          color: isSelected 
                              ? themeProvider.accentColor 
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Security options
            if (web3Provider.isConnected) ...[
              Text(
                'Security',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              
              DesktopCard(
                child: Column(
                  children: [
                    _buildSettingsRow(
                      'Export Recovery Phrase',
                      'Back up your wallet (sensitive)',
                      Icons.vpn_key,
                      onTap: () => _showRecoveryWarning(),
                    ),
                    const Divider(height: 32),
                    _buildSettingsRow(
                      'Disconnect Wallet',
                      'Sign out of Web3 features',
                      Icons.logout,
                      isDestructive: true,
                      onTap: () => _showDisconnectConfirmation(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRecoveryWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 12),
            Text('Security Warning', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your recovery phrase gives full access to your wallet. Never share it with anyone.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• Make sure you are in a private place\n• Never share your phrase with anyone\n• Store it securely offline',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MnemonicRevealScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showDisconnectConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Disconnect Wallet?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'You will be signed out of all Web3 features. You can reconnect anytime.',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<Web3Provider>(context, listen: false).disconnectWallet();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet disconnected')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  // Dialog Methods from Mobile Settings
  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('App Version', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('art.kubus', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('Version: ${AppInfo.version}', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
            Text('Build: ${AppInfo.buildNumber}', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            Text('© 2025 kubus', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            Text('All rights reserved.', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Terms of Service', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Text(
            'By using ART.KUBUS, you agree to these terms:\n\n'
            '1. You are responsible for maintaining the security of your wallet.\n'
            '2. We do not store your private keys or seed phrases.\n'
            '3. All transactions are final and irreversible.\n'
            '4. Use the app at your own risk.\n'
            '5. We reserve the right to update these terms.\n\n'
            'For the complete terms, visit our website.',
            style: GoogleFonts.inter(height: 1.5, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Privacy Policy', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Text(
            'Your privacy is important to us:\n\n'
            '• We do not collect personal data without consent\n'
            '• Your wallet data is stored locally on your device\n'
            '• We may collect anonymous usage statistics\n'
            '• We do not share your data with third parties\n'
            '• You can disable analytics in Privacy settings\n\n'
            'For our complete privacy policy, visit our website.',
            style: GoogleFonts.inter(height: 1.5, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Support', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Need help? Choose an option:', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor, foregroundColor: Colors.white),
              onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening FAQ...'))); },
              icon: const Icon(Icons.help_outline),
              label: const Text('View FAQ'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor, foregroundColor: Colors.white),
              onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening email client...'))); },
              icon: const Icon(Icons.email),
              label: const Text('Contact Support'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showLicensesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Open Source Licenses', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Text(
            'This app uses the following open source libraries:\n\n'
            '• Flutter & Dart SDK\n'
            '• OpenStreetMaps\n'
            '• Provider (State Management)\n'
            '• Solana Web3 (Blockchain)\n'
            '• Google Fonts\n'
            '• And many more...\n\n'
            'See LICENSE file for complete list.',
            style: GoogleFonts.inter(height: 1.5, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showRateAppDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Rate App', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Do you enjoy using art.kubus? Please leave a rating on the app store!', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening app store...'))); },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          'Change Password',
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(dialogContext).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeProvider.accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Reset App', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text('This will clear all app data and settings. Your wallet will be disconnected but not deleted.', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final walletProvider = Provider.of<WalletProvider>(context, listen: false);
              final notificationProvider =
                  Provider.of<NotificationProvider>(context, listen: false);
              final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
              await SettingsService.resetApp(
                walletProvider: walletProvider,
                backendApi: BackendApiService(),
                notificationProvider: notificationProvider,
                profileProvider: profileProvider,
              );
              navigator.pop();
              messenger.showSnackBar(const SnackBar(content: Text('App reset successfully. Please restart.'), duration: Duration(seconds: 3)));
              _restartToOnboarding();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Delete Account', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'We will remove your profile and community data from our servers. Your wallet remains yours and will stay functional.',
          style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final walletProvider = Provider.of<WalletProvider>(context, listen: false);
              final notificationProvider =
                  Provider.of<NotificationProvider>(context, listen: false);
              final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

              try {
                final wallet = walletProvider.currentWalletAddress ??
                    profileProvider.currentUser?.walletAddress;
                await BackendApiService().deleteMyAccountData(walletAddress: wallet);
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Backend deletion failed: $e')));
              }

              await SettingsService.resetApp(
                walletProvider: walletProvider,
                backendApi: BackendApiService(),
                notificationProvider: notificationProvider,
                profileProvider: profileProvider,
              );
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(const SnackBar(content: Text('Account deleted.')));
              _restartToOnboarding();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDataExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Export Data', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Your data will be exported as JSON and downloaded to your device.', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting data...')));
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Clear Cache', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text('This will free up storage space but may slow down app performance initially.', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor, foregroundColor: Colors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await SettingsService.clearNonCriticalCaches();
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(const SnackBar(content: Text('Cache cleared')));
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetPermissionFlagsDialog() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          'Reset Permissions',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This will reset all permission prompts so you can grant them again.',
          style: GoogleFonts.inter(color: Theme.of(dialogContext).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(dialogContext, listen: false).accentColor,
              foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _resetPermissionFlags();
              if (!mounted) return;
              messenger.showSnackBar(const SnackBar(content: Text('Permission flags reset')));
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPermissionFlags() async {
    try {
      await SettingsService.resetPermissionFlags();
    } catch (e) {
      debugPrint('Failed to reset permission flags: $e');
    }
  }

  Widget _buildPlatformCapabilitiesSection() {
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform Capabilities',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'View available device features',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                ...platformProvider.capabilities.entries.map((entry) {
                  final capability = entry.key;
                  final isAvailable = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Icon(
                          isAvailable ? Icons.check_circle : Icons.cancel,
                          color: isAvailable ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getCapabilityDisplayName(capability),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                isAvailable ? 'Available' : 'Not available',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: isAvailable ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getCapabilityDisplayName(PlatformCapability capability) {
    switch (capability) {
      case PlatformCapability.camera:
        return 'Camera Access (QR Scanner, AR)';
      case PlatformCapability.ar:
        return 'Augmented Reality Features';
      case PlatformCapability.nfc:
        return 'NFC Communication';
      case PlatformCapability.gps:
        return 'Location Services';
      case PlatformCapability.biometrics:
        return 'Biometric Authentication';
      case PlatformCapability.notifications:
        return 'Push Notifications';
      case PlatformCapability.fileSystem:
        return 'File System Access';
      case PlatformCapability.bluetooth:
        return 'Bluetooth Connectivity';
      case PlatformCapability.vibration:
        return 'Haptic Feedback';
      case PlatformCapability.orientation:
        return 'Device Orientation';
      case PlatformCapability.background:
        return 'Background Processing';
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    if (value) {
      final granted = await PushNotificationService().requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() => _pushNotifications = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable notifications in system settings to receive alerts.'),
            ),
          );
        }
        await _saveSettings();
        return;
      }
      await notificationProvider.initialize(force: true);
    } else {
      await PushNotificationService().cancelAllNotifications();
      notificationProvider.reset();
    }
    if (!mounted) return;
    setState(() => _pushNotifications = value);
    await _saveSettings();
  }

  Future<void> _toggleBiometric(bool value) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    if (value) {
      final canUse = await walletProvider.canUseBiometrics();
      if (!canUse) {
        if (mounted) {
          setState(() => _biometricAuth = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric unlock not available on this device.')),
          );
        }
        await _saveSettings();
        return;
      }
      final ok = await walletProvider.authenticateWithBiometrics();
      if (!ok) {
        if (mounted) {
          setState(() => _biometricAuth = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication failed.')),
          );
        }
        await _saveSettings();
        return;
      }
    }
    if (!mounted) return;
    setState(() => _biometricAuth = value);
    await _saveSettings();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          'Log Out',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Disconnect your wallet and clear your session on this device?',
          style: GoogleFonts.inter(color: Theme.of(dialogContext).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Theme.of(dialogContext).colorScheme.outline),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    await SettingsService.logout(
      walletProvider: walletProvider,
      backendApi: BackendApiService(),
      notificationProvider: notificationProvider,
      profileProvider: profileProvider,
    );

    if (!mounted) return;
    _restartToOnboarding();
  }

  void _restartToOnboarding() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  Widget _buildDangerZoneSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Danger Zone',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Irreversible actions that require caution',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSettingsRow(
              'Clear Cache',
              'Free up storage space',
              Icons.delete_outline,
              isDestructive: true,
              onTap: _showClearCacheDialog,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsRow(
              'Reset Permission Flags',
              'Clear saved permission prompts',
              Icons.location_off,
              isDestructive: true,
              onTap: _showResetPermissionFlagsDialog,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsRow(
              'Export Data',
              'Download your data as JSON',
              Icons.download,
              isDestructive: true,
              onTap: _showDataExportDialog,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsRow(
              'Reset App',
              'Clear all data and settings',
              Icons.refresh,
              isDestructive: true,
              onTap: _showResetDialog,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsRow(
              'Delete Account',
              'Permanently delete your account',
              Icons.delete_forever,
              isDestructive: true,
              onTap: _showDeleteAccountDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSettings(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize how the app looks and feels',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          
          // Theme mode
          DesktopCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Mode',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildThemeModeOption('Light', Icons.light_mode, !themeProvider.isDarkMode && !themeProvider.isSystemMode, () {
                      themeProvider.setThemeMode(ThemeMode.light);
                    }),
                    const SizedBox(width: 12),
                    _buildThemeModeOption('Dark', Icons.dark_mode, themeProvider.isDarkMode && !themeProvider.isSystemMode, () {
                      themeProvider.setThemeMode(ThemeMode.dark);
                    }),
                    const SizedBox(width: 12),
                    _buildThemeModeOption('System', Icons.settings_suggest, themeProvider.isSystemMode, () {
                      themeProvider.setThemeMode(ThemeMode.system);
                    }),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Accent color
          DesktopCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accent Color',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ThemeProvider.availableAccentColors.map((color) {
                    final isSelected = themeProvider.accentColor == color;
                    return GestureDetector(
                      onTap: () {
                        themeProvider.setAccentColor(color);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected
                  ? themeProvider.accentColor.withValues(alpha: 0.1)
                  : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? themeProvider.accentColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? themeProvider.accentColor
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSettings(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          
          DesktopCard(
            child: Column(
              children: [
                _buildToggleSetting(
                  'Push Notifications',
                  'Get notified about activity',
                  _pushNotifications,
                  saveAfterToggle: false,
                  onChanged: (value) {
                    setState(() => _pushNotifications = value);
                    _togglePushNotifications(value);
                  },
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Email Notifications',
                  'Receive email updates',
                  _emailNotifications,
                  onChanged: (value) => setState(() => _emailNotifications = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Promotions & Marketing',
                  'Occasional product news',
                  _marketingEmails,
                  onChanged: (value) => setState(() => _marketingEmails = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Login Alerts',
                  'Notifications for new sign-ins',
                  _loginNotifications,
                  onChanged: (value) => setState(() => _loginNotifications = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySettings(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          
          DesktopCard(
            child: Column(
              children: [
                _buildToggleSetting(
                  'Public Profile',
                  'Allow others to find your content',
                  _publicProfile,
                  onChanged: (value) => setState(() => _publicProfile = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Show Friends & Followers',
                  'Display social stats on your profile',
                  _showFriends,
                  onChanged: (value) => setState(() => _showFriends = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Show Achievements',
                  'Display unlocked badges on profile',
                  _showAchievements,
                  onChanged: (value) => setState(() => _showAchievements = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Allow Messages',
                  'Receive direct messages',
                  _allowMessages,
                  onChanged: (value) => setState(() => _allowMessages = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Analytics',
                  'Help improve the app',
                  _analytics,
                  onChanged: (value) => setState(() => _analytics = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Crash Reporting',
                  'Send crash reports automatically',
                  _crashReporting,
                  onChanged: (value) => setState(() => _crashReporting = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Skip Onboarding',
                  'Skip welcome screens for returning users',
                  _skipOnboardingForReturningUsers,
                  onChanged: (value) =>
                      setState(() => _skipOnboardingForReturningUsers = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          
          DesktopCard(
            child: Column(
              children: [
                _buildSettingsRow(
                  'Change Password',
                  'Update your account password',
                  Icons.lock_outline,
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Two-Factor Authentication',
                  'Add extra security to your account',
                  _twoFactorAuth,
                  onChanged: (value) => setState(() => _twoFactorAuth = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Biometric Authentication',
                  'Use fingerprint or face unlock',
                  _biometricAuth,
                  saveAfterToggle: false,
                  onChanged: (value) {
                    setState(() => _biometricAuth = value);
                    _toggleBiometric(value);
                  },
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Session Timeout',
                  'Automatically sign out when idle',
                  _sessionTimeout,
                  onChanged: (value) => setState(() => _sessionTimeout = value),
                ),
                const Divider(height: 32),
                _buildAutoLockDropdown(),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Login Alerts',
                  'Get notified of new sign-ins',
                  _loginNotifications,
                  onChanged: (value) => setState(() => _loginNotifications = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  'Privacy Mode',
                  'Hide sensitive information',
                  _privacyMode,
                  onChanged: (value) => setState(() => _privacyMode = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Achievements & Rewards',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your progress and earn KUB8 tokens',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          // Stats Overview
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.2),
                  Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem('Artworks Discovered', '12', Icons.image),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: _buildStatItem('AR Views', '28', Icons.view_in_ar),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: _buildStatItem('Events Attended', '5', Icons.event),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: _buildStatItem('KUB8 Earned', '150', Icons.token),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Achievements',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildAchievementCard(
            'First Discovery',
            'Discover your first AR artwork',
            Icons.explore,
            isUnlocked: true,
            reward: 10,
          ),
          const SizedBox(height: 12),
          _buildAchievementCard(
            'Art Collector',
            'View 10 AR artworks',
            Icons.collections,
            isUnlocked: true,
            reward: 25,
          ),
          const SizedBox(height: 12),
          _buildAchievementCard(
            'Community Member',
            'Join 3 community groups',
            Icons.groups,
            isUnlocked: false,
            progress: 2,
            total: 3,
            reward: 50,
          ),
          const SizedBox(height: 12),
          _buildAchievementCard(
            'Event Explorer',
            'Attend 5 art events',
            Icons.event_available,
            isUnlocked: false,
            progress: 5,
            total: 5,
            reward: 75,
          ),
          const SizedBox(height: 12),
          _buildAchievementCard(
            'NFT Creator',
            'Mint your first NFT',
            Icons.auto_awesome,
            isUnlocked: false,
            progress: 0,
            total: 1,
            reward: 100,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 28,
          color: Provider.of<ThemeProvider>(context).accentColor,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAchievementCard(
    String title,
    String description,
    IconData icon, {
    required bool isUnlocked,
    int? progress,
    int? total,
    required int reward,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? themeProvider.accentColor.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? themeProvider.accentColor.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isUnlocked
                  ? themeProvider.accentColor
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: themeProvider.accentColor,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (!isUnlocked && progress != null && total != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress / total,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(themeProvider.accentColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$progress / $total',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? themeProvider.accentColor.withValues(alpha: 0.2)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.token,
                  size: 16,
                  color: isUnlocked
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '+$reward',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? themeProvider.accentColor
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Help & Support',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get help and find answers to common questions',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          _buildSettingsRow(
            'FAQ',
            'Frequently asked questions',
            Icons.help_outline,
            onTap: _showSupportDialog,
          ),
          const SizedBox(height: 12),
          _buildSettingsRow(
            'Contact Support',
            'Get help from our team',
            Icons.email_outlined,
            onTap: _showSupportDialog,
          ),
          const SizedBox(height: 12),
          _buildSettingsRow(
            'Report a Bug',
            'Help us improve the app',
            Icons.bug_report_outlined,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening bug report form...')),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAboutSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About art.kubus',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AR Art Platform connecting artists and institutions',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          
          // Version Info
          _buildSettingsRow(
            'Version',
            AppInfo.version,
            Icons.app_registration,
            onTap: _showVersionDialog,
          ),
          const SizedBox(height: 12),
          
          // Features Section
          Text(
            'Features',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildFeatureItem(Icons.view_in_ar, 'AR Art Discovery', 'Experience artworks in augmented reality'),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.account_balance_wallet, 'Web3 Integration', 'Solana blockchain with KUB8 tokens'),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.auto_awesome, 'NFT Minting', 'Create and trade digital art collectibles'),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.groups, 'Community', 'Connect with artists and collectors'),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.museum, 'Institutions', 'Partner with galleries and museums'),
          
          const SizedBox(height: 32),
          
          // Legal Links
          Text(
            'Legal',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSettingsRow(
            'Terms of Service',
            'Read our terms',
            Icons.description,
            onTap: _showTermsDialog,
          ),
          const SizedBox(height: 12),
          
          _buildSettingsRow(
            'Privacy Policy',
            'Read our privacy policy',
            Icons.privacy_tip,
            onTap: _showPrivacyPolicyDialog,
          ),
          const SizedBox(height: 12),
          
          _buildSettingsRow(
            'Open Source Licenses',
            'View third-party licenses',
            Icons.code,
            onTap: _showLicensesDialog,
          ),
          
          const SizedBox(height: 32),
          
          // Support Section
          Text(
            'Support',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSettingsRow(
            'Support',
            'Get help or report issues',
            Icons.help,
            onTap: _showSupportDialog,
          ),
          const SizedBox(height: 12),
          
          _buildSettingsRow(
            'Rate App',
            'Rate us on the app store',
            Icons.star,
            onTap: _showRateAppDialog,
          ),
          
          const SizedBox(height: 32),
          
          // Copyright
          Center(
            child: Text(
              '© 2025 kubus • All rights reserved',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: Provider.of<ThemeProvider>(context).accentColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsRow(
    String title,
    String subtitle,
    IconData icon, {
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? const Color(0xFFEF4444)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? const Color(0xFFEF4444)
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSetting(
    String title,
    String subtitle,
    bool initialValue, {
    bool saveAfterToggle = true,
    ValueChanged<bool>? onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: initialValue,
          onChanged: (value) {
            onChanged?.call(value);
            if (saveAfterToggle) {
              _saveSettings();
            }
          },
          activeTrackColor: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.5),
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Provider.of<ThemeProvider>(context, listen: false).accentColor;
            }
            return null;
          }),
        ),
      ],
    );
  }

  Widget _buildAutoLockDropdown() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final options = <Map<String, dynamic>>[
      {'label': '10 seconds', 'seconds': 10},
      {'label': '30 seconds', 'seconds': 30},
      {'label': '1 minute', 'seconds': 60},
      {'label': '5 minutes', 'seconds': 5 * 60},
      {'label': '15 minutes', 'seconds': 15 * 60},
      {'label': '30 minutes', 'seconds': 30 * 60},
      {'label': '1 hour', 'seconds': 60 * 60},
      {'label': '3 hours', 'seconds': 3 * 60 * 60},
      {'label': '6 hours', 'seconds': 6 * 60 * 60},
      {'label': '12 hours', 'seconds': 12 * 60 * 60},
      {'label': '1 day', 'seconds': 24 * 60 * 60},
      {'label': 'Never', 'seconds': 0},
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        Icons.lock_clock,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        'Auto-lock time',
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        _autoLockTime,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: DropdownButton<String>(
        value: _autoLockTime,
        underline: const SizedBox.shrink(),
        dropdownColor: Theme.of(context).colorScheme.surface,
        items: options
            .map(
              (opt) => DropdownMenuItem<String>(
                value: opt['label'] as String,
                child: Text(opt['label'] as String),
              ),
            )
            .toList(),
        onChanged: (value) async {
          if (value == null) return;
          final seconds =
              options.firstWhere((opt) => opt['label'] == value)['seconds'] as int;
          setState(() {
            _autoLockTime = value;
          });
          try {
            await walletProvider.setLockTimeoutSeconds(seconds);
          } catch (_) {}
          await _saveSettings();
        },
      ),
    );
  }
}

class _SettingsItem {
  final String title;
  final IconData icon;
  final int index;

  _SettingsItem(this.title, this.icon, this.index);
}
