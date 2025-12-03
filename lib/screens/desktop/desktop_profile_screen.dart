import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/themeprovider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/web3provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../../utils/app_animations.dart';
import 'components/desktop_widgets.dart';
import '../community/profile_edit_screen.dart';
import '../web3/wallet/wallet_home.dart';
import '../web3/wallet/mnemonic_reveal_screen.dart';

/// Desktop profile and settings screen
/// Clean dashboard layout with account info and settings
class DesktopProfileScreen extends StatefulWidget {
  const DesktopProfileScreen({super.key});

  @override
  State<DesktopProfileScreen> createState() => _DesktopProfileScreenState();
}

class _DesktopProfileScreenState extends State<DesktopProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;

  final List<String> _tabs = ['Profile', 'Settings', 'Security', 'Preferences'];
  int _selectedSettingsIndex = 0;

  // Settings state (persisted to SharedPreferences)
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _marketingEmails = false;
  bool _twoFactorAuth = false;
  bool _biometricAuth = false;
  bool _privacyMode = false;
  bool _analytics = true;
  bool _crashReporting = true;
  String _autoLockTime = '5 minutes';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _tabController = TabController(length: _tabs.length, vsync: this);
    _animationController.forward();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailNotifications = prefs.getBool('email_notifications') ?? true;
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _marketingEmails = prefs.getBool('marketing_emails') ?? false;
      _twoFactorAuth = prefs.getBool('two_factor_auth') ?? false;
      _biometricAuth = prefs.getBool('biometric_auth') ?? false;
      _privacyMode = prefs.getBool('privacy_mode') ?? false;
      _analytics = prefs.getBool('analytics') ?? true;
      _crashReporting = prefs.getBool('crash_reporting') ?? true;
      _autoLockTime = prefs.getString('auto_lock_time') ?? '5 minutes';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('email_notifications', _emailNotifications);
    await prefs.setBool('push_notifications', _pushNotifications);
    await prefs.setBool('marketing_emails', _marketingEmails);
    await prefs.setBool('two_factor_auth', _twoFactorAuth);
    await prefs.setBool('biometric_auth', _biometricAuth);
    await prefs.setBool('privacy_mode', _privacyMode);
    await prefs.setBool('analytics', _analytics);
    await prefs.setBool('crash_reporting', _crashReporting);
    await prefs.setString('auto_lock_time', _autoLockTime);
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
      _SettingsItem('Help & Support', Icons.help_outline, 7),
      _SettingsItem('About', Icons.info_outline, 8),
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
            onTap: () {
              // Logout
            },
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
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileEditScreen(),
                            ),
                          );
                          // Reload profile if changes were saved
                          if (result == true && mounted) {
                            final web3Provider = Provider.of<Web3Provider>(context, listen: false);
                            if (web3Provider.isConnected && web3Provider.walletAddress.isNotEmpty) {
                              await profileProvider.loadProfile(web3Provider.walletAddress);
                            }
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
        return _buildHelpSettings();
      case 8:
        return _buildAboutSettings();
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
                              ? Colors.green 
                              : Colors.orange).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          web3Provider.isConnected 
                              ? Icons.check_circle 
                              : Icons.warning,
                          color: web3Provider.isConnected 
                              ? Colors.green 
                              : Colors.orange,
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
                    final isSelected = themeProvider.accentColor.toARGB32() == color.toARGB32();
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
                _buildToggleSetting('Push Notifications', 'Get notified about activity', true),
                const Divider(height: 32),
                _buildToggleSetting('Email Notifications', 'Receive email updates', true),
                const Divider(height: 32),
                _buildToggleSetting('New Followers', 'When someone follows you', true),
                const Divider(height: 32),
                _buildToggleSetting('Artwork Interactions', 'Likes, comments, shares', true),
                const Divider(height: 32),
                _buildToggleSetting('NFT Activity', 'Sales, offers, transfers', true),
                const Divider(height: 32),
                _buildToggleSetting('DAO Updates', 'Proposals and voting', false),
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
                _buildToggleSetting('Private Profile', 'Only followers can see your content', false),
                const Divider(height: 32),
                _buildToggleSetting('Show Activity Status', 'Let others see when you\'re online', true),
                const Divider(height: 32),
                _buildToggleSetting('Show Wallet Address', 'Display your wallet publicly', true),
                const Divider(height: 32),
                _buildToggleSetting('Allow Messages', 'Receive direct messages', true),
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
                  'Last changed 30 days ago',
                  Icons.lock_outline,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'Two-Factor Authentication',
                  'Not enabled',
                  Icons.security,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'Active Sessions',
                  '2 devices',
                  Icons.devices,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'Backup Recovery Phrase',
                  'View your seed phrase',
                  Icons.key,
                  onTap: () {},
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSettingsRow(
                  'FAQ',
                  'Frequently asked questions',
                  Icons.help_outline,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'User Guide',
                  'Learn how to use the app',
                  Icons.menu_book,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'AR Tutorial',
                  'Get started with AR experiences',
                  Icons.view_in_ar,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'Web3 Guide',
                  'Learn about wallets, tokens & NFTs',
                  Icons.account_balance_wallet,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Contact Us',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSettingsRow(
                  'Email Support',
                  'support@art-kubus.io',
                  Icons.email_outlined,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'Discord Community',
                  'Join our Discord server',
                  Icons.chat_bubble_outline,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'Report a Bug',
                  'Help us improve the app',
                  Icons.bug_report_outlined,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'Feature Request',
                  'Suggest new features',
                  Icons.lightbulb_outline,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Legal',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSettingsRow(
                  'Terms of Service',
                  'Read our terms',
                  Icons.description_outlined,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'Privacy Policy',
                  'How we handle your data',
                  Icons.privacy_tip_outlined,
                  onTap: () {},
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  'Licenses',
                  'Open source licenses',
                  Icons.article_outlined,
                  onTap: () {},
                ),
              ],
            ),
          ),
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
          // App Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.15),
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.view_in_ar,
                        size: 40,
                        color: Provider.of<ThemeProvider>(context).accentColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'art.kubus',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 0.0.2',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Desktop Web App',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Provider.of<ThemeProvider>(context).accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'What is art.kubus?',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'art.kubus is an AR art platform that bridges the gap between digital and physical art worlds. '
            'We connect artists, collectors, and cultural institutions through immersive augmented reality experiences, '
            'blockchain-based ownership verification, and a vibrant community of art enthusiasts.',
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
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
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.account_balance_wallet, 'Web3 Integration', 'Solana blockchain with KUB8 tokens'),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.auto_awesome, 'NFT Minting', 'Create and trade digital art collectibles'),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.groups, 'Community', 'Connect with artists and collectors'),
          const SizedBox(height: 12),
          _buildFeatureItem(Icons.museum, 'Institutions', 'Partner with galleries and museums'),
          const SizedBox(height: 32),
          Text(
            'Connect With Us',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSocialButton(Icons.language, 'Website', () {}),
              const SizedBox(width: 12),
              _buildSocialButton(Icons.alternate_email, 'Instagram', () {}),
              const SizedBox(width: 12),
              _buildSocialButton(Icons.code, 'GitHub', () {}),
              const SizedBox(width: 12),
              _buildSocialButton(Icons.work_outline, 'LinkedIn', () {}),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  '© 2025 KUBUS',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ❤️ in Slovenia',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildSocialButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
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
            _saveSettings();
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
}

class _SettingsItem {
  final String title;
  final IconData icon;
  final int index;

  _SettingsItem(this.title, this.icon, this.index);
}
