import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/platform_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/navigation_provider.dart';
import '../models/wallet.dart';
import '../widgets/platform_aware_widgets.dart';
import 'web3/wallet/wallet_home.dart' as web3_wallet;
import 'web3/wallet/connectwallet_screen.dart';
import 'onboarding_reset_screen.dart';
import 'community/profile_edit_screen.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/empty_state_card.dart';
import 'web3/wallet/mnemonic_reveal_screen.dart';
import '../utils/app_animations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _didAnimateEntrance = false;

  static const List<_ProfileVisibilityOption> _profileVisibilityOptions = [
    _ProfileVisibilityOption(
      value: 'Public',
      label: 'Public',
      description: 'Anyone can see your profile',
    ),
    _ProfileVisibilityOption(
      value: 'Private',
      label: 'Private',
      description: 'Only you can see your profile',
    ),
    _ProfileVisibilityOption(
      value: 'Friends Only',
      label: 'Friends Only',
      description: 'Only friends can see your profile',
    ),
  ];

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
  bool _enableAnalytics = true;
  bool _enableCrashReporting = true;
  bool _skipOnboardingForReturningUsers = true;
  
  // Wallet settings state
  String _networkSelection = 'Solana';
  bool _autoBackup = true;
  
  // Profile interaction settings
  bool _showAchievements = true;
  bool _showFriends = true;
  bool _allowMessages = true;

  @override
  void initState() {
    super.initState();
    final animationTheme = AppAnimationTheme.defaults;
    _animationController = AnimationController(
      duration: animationTheme.long,
      vsync: this,
    );
    _configureAnimations(animationTheme);
    _loadAllSettings();
  }

  void _configureAnimations(AppAnimationTheme animationTheme) {
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: animationTheme.fadeCurve,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: animationTheme.defaultCurve,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationTheme = context.animationTheme;
    if (_animationController.duration != animationTheme.long) {
      _animationController.duration = animationTheme.long;
    }
    _configureAnimations(animationTheme);
    if (!_didAnimateEntrance) {
      _didAnimateEntrance = true;
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildUserSection(),
                          const SizedBox(height: 32),
                          _buildThemeSection(),
                          const SizedBox(height: 24),
                          _buildPlatformCapabilitiesSection(),
                          const SizedBox(height: 24),
                          _buildProfileSection(),
                          const SizedBox(height: 24),
                          _buildWalletSection(),
                          const SizedBox(height: 24),
                          _buildSecuritySection(),
                          const SizedBox(height: 24),
                          _buildPrivacySection(),
                          const SizedBox(height: 24),
                          _buildAboutSection(),
                          const SizedBox(height: 24),
                          _buildDangerZone(),
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'Settings',
        style: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildUserSection() {
    final web3Provider = Provider.of<Web3Provider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
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
        boxShadow: [
          BoxShadow(
            color: themeProvider.accentColor.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AvatarWidget(
                  wallet: profileProvider.currentUser?.walletAddress ?? '',
                  avatarUrl: profileProvider.currentUser?.avatar,
                  radius: 30,
                  enableProfileNavigation: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profileProvider.currentUser?.displayName ?? 'Guest User',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    if (web3Provider.isConnected) ...[
                      Text(
                        web3Provider.formatAddress(web3Provider.walletAddress),
                        style: GoogleFonts.robotoMono(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No wallet connected',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 20,
                ),
              ),
            ],
          ),
          if (web3Provider.isConnected) ...[
            const SizedBox(height: 20),
            Consumer<WalletProvider>(
              builder: (context, walletProvider, child) {
                // Get KUB8 balance
                final kub8Balance = walletProvider.tokens
                    .where((token) => token.symbol.toUpperCase() == 'KUB8')
                    .isNotEmpty 
                    ? walletProvider.tokens
                        .where((token) => token.symbol.toUpperCase() == 'KUB8')
                        .first.balance 
                    : 0.0;
                
                // Get SOL balance  
                final solBalance = walletProvider.tokens
                    .where((token) => token.symbol.toUpperCase() == 'SOL')
                    .isNotEmpty 
                    ? walletProvider.tokens
                        .where((token) => token.symbol.toUpperCase() == 'SOL')
                        .first.balance 
                    : 0.0;

                return Row(
                  children: [
                    Expanded(
                      child: _buildBalanceCard('KUB8', kub8Balance.toStringAsFixed(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBalanceCard('SOL', solBalance.toStringAsFixed(3)),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String symbol, String amount) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const web3_wallet.WalletHome()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              amount,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            Text(
              symbol,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return _buildSection(
      'Appearance',
      Icons.palette,
      [
        _buildThemeModeTile(themeProvider),
        const SizedBox(height: 12),
        _buildAccentColorTile(themeProvider),
      ],
    );
  }

  Widget _buildThemeModeTile(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6,
                color: themeProvider.accentColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Theme Mode',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 375;
              
              if (isSmallScreen) {
                // Stack vertically on small screens
                return Column(
                  children: [
                    _buildThemeOption(
                      'Light',
                      Icons.light_mode,
                      ThemeMode.light,
                      themeProvider,
                      isSmallScreen: true,
                    ),
                    const SizedBox(height: 8),
                    _buildThemeOption(
                      'Dark',
                      Icons.dark_mode,
                      ThemeMode.dark,
                      themeProvider,
                      isSmallScreen: true,
                    ),
                    const SizedBox(height: 8),
                    _buildThemeOption(
                      'System',
                      Icons.auto_mode,
                      ThemeMode.system,
                      themeProvider,
                      isSmallScreen: true,
                    ),
                  ],
                );
              } else {
                // Keep horizontal layout on larger screens
                return Row(
                  children: [
                    Expanded(
                      child: _buildThemeOption(
                        'Light',
                        Icons.light_mode,
                        ThemeMode.light,
                        themeProvider,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOption(
                        'Dark',
                        Icons.dark_mode,
                        ThemeMode.dark,
                        themeProvider,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOption(
                        'System',
                        Icons.auto_mode,
                        ThemeMode.system,
                        themeProvider,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String label, IconData icon, ThemeMode mode, ThemeProvider themeProvider, {bool isSmallScreen = false}) {
    final isSelected = themeProvider.themeMode == mode;
    
    return GestureDetector(
      onTap: () => themeProvider.setThemeMode(mode),
      child: Container(
        width: isSmallScreen ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 16 : 12, 
          horizontal: isSmallScreen ? 16 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? themeProvider.accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? themeProvider.accentColor
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: isSmallScreen 
          ? Row(
              children: [
                Icon(
                  icon,
                  color: isSelected 
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected 
                        ? themeProvider.accentColor
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Icon(
                  icon,
                  color: isSelected 
                      ? themeProvider.accentColor
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected 
                        ? themeProvider.accentColor
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildAccentColorTile(ThemeProvider themeProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.color_lens,
                color: themeProvider.accentColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Accent Color',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ThemeProvider.availableAccentColors.map((color) {
              final isSelected = themeProvider.accentColor == color;
              return GestureDetector(
                onTap: () => themeProvider.setAccentColor(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected 
                        ? Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 3)
                        : null,
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: isSelected 
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCapabilitiesSection() {
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, child) {
        return _buildSection(
          'Platform Features',
          Icons.devices,
          [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        platformProvider.isMobile ? Icons.phone_android :
                        platformProvider.isDesktop ? Icons.computer :
                        Icons.web,
                        color: Provider.of<ThemeProvider>(context).accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Running on ${platformProvider.currentPlatform.toString().split('.').last}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Available Features:',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...platformProvider.capabilities.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            entry.value ? Icons.check_circle : Icons.cancel,
                            color: entry.value ? Provider.of<ThemeProvider>(context).accentColor : Theme.of(context).colorScheme.error,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getCapabilityDisplayName(entry.key),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: entry.value ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Developer Tools Section (Debug Mode Only)
            if (kDebugMode) const SizedBox(height: 24),
            if (kDebugMode)
              _buildSection(
                'Developer Tools',
                Icons.developer_mode,
                [
                  _buildSettingsTile(
                    'Reset Onboarding',
                    'Reset onboarding state for testing',
                    Icons.refresh,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OnboardingResetScreen(),
                        ),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    'Clear Quick Actions',
                    'Reset recently visited screens',
                    Icons.clear_all,
                    onTap: () async {
                      final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
                      await navigationProvider.clearVisitData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Quick actions cleared')),
                        );
                      }
                    },
                  ),
                ],
              ),
            if (kDebugMode) const PlatformDebugWidget(),
          ],
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

  Widget _buildProfileSection() {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final artistRole = profileProvider.currentUser?.isArtist ?? false;
    final institutionRole = profileProvider.currentUser?.isInstitution ?? false;
    final roleSummary = 'Artist: ${artistRole ? "On" : "Off"}, Institution: ${institutionRole ? "On" : "Off"}';
    return _buildSection(
      'Profile Settings',
      Icons.person_outline,
      [
        _buildSettingsTile(
          'Profile Visibility',
          'Currently: $_profileVisibility',
          Icons.visibility,
          onTap: () {
            _showProfileVisibilityDialog();
          },
        ),
        _buildSettingsTile(
          'Privacy Settings',
          'Data: ${_dataCollection ? "Enabled" : "Disabled"}, Ads: ${_personalizedAds ? "Enabled" : "Disabled"}',
          Icons.privacy_tip,
          onTap: () {
            _showPrivacySettingsDialog();
          },
        ),
        _buildSettingsTile(
          'Security Settings',
          '2FA: ${_twoFactorAuth ? "Enabled" : "Disabled"}, Auto-lock: $_autoLockTime',
          Icons.security,
          onTap: () {
            _showSecuritySettingsDialog();
          },
        ),
        _buildSettingsTile(
          'Edit Profile',
          'Update your username, bio, and avatar',
          Icons.person_outline,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileEditScreen(),
              ),
            );
            // Reload profile if changes were saved
            if (result == true && mounted) {
              final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
              final web3Provider = Provider.of<Web3Provider>(context, listen: false);
              if (web3Provider.isConnected && web3Provider.walletAddress.isNotEmpty) {
                await profileProvider.loadProfile(web3Provider.walletAddress);
              }
            }
          },
        ),
        _buildSettingsTile(
          'Account Management',
          'Type: $_accountType, Notifications: ${_emailNotifications ? "On" : "Off"}',
          Icons.manage_accounts,
          onTap: () {
            _showAccountManagementDialog();
          },
        ),
        _buildSettingsTile(
          'Role Simulation',
          roleSummary,
          Icons.workspace_premium,
          onTap: _showRoleSimulationSheet,
        ),
      ],
    );
  }

  void _showRoleSimulationSheet() {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final initialArtist = profileProvider.currentUser?.isArtist ?? false;
    final initialInstitution = profileProvider.currentUser?.isInstitution ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        bool artist = initialArtist;
        bool institution = initialInstitution;
        return StatefulBuilder(
          builder: (context, setState) => Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Role Simulation',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toggle roles to preview profile layouts locally. Changes are local to this device.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Artist profile', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: Text('Show artist sections (artworks, collections)', style: GoogleFonts.inter(fontSize: 13)),
                  value: artist,
                  activeThumbColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
                  onChanged: (val) {
                    setState(() => artist = val);
                    profileProvider.setRoleFlags(isArtist: val, isInstitution: institution);
                  },
                ),
                SwitchListTile(
                  title: Text('Institution profile', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: Text('Show institution sections (events, collections)', style: GoogleFonts.inter(fontSize: 13)),
                  value: institution,
                  activeThumbColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
                  onChanged: (val) {
                    setState(() => institution = val);
                    profileProvider.setRoleFlags(isArtist: artist, isInstitution: val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.outline)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalletSection() {
    final web3Provider = Provider.of<Web3Provider>(context);
    
    return _buildSection(
      'Wallet & Web3',
      Icons.account_balance_wallet,
      [
        _buildSettingsTile(
          'Wallet Connection',
          web3Provider.isConnected ? 'Connected' : 'Not Connected',
          Icons.link,
          onTap: () {
            if (web3Provider.isConnected) {
              web3Provider.disconnectWallet();
            } else {
              // Navigate to connect wallet screen instead
              Navigator.of(context).pushNamed('/connect-wallet');
            }
          },
          trailing: web3Provider.isConnected 
              ? Icon(Icons.check_circle, color: Provider.of<ThemeProvider>(context).accentColor)
              : Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
        ),
        _buildSettingsTile(
          'Network',
          'Current: $_networkSelection',
          Icons.network_check,
          onTap: () => _showNetworkDialog(),
        ),
        _buildSettingsTile(
          'Transaction History',
          'View all transactions',
          Icons.history,
          onTap: () => _showTransactionHistoryDialog(),
        ),
        _buildSettingsTile(
          'Backup Settings',
          'Auto-backup: ${_autoBackup ? "Enabled" : "Disabled"}',
          Icons.backup,
          onTap: () => _showBackupDialog(),
        ),
        _buildSettingsTile(
          'Export recovery phrase',
          'Back up your wallet (sensitive)',
          Icons.warning_amber_rounded,
          onTap: _showRecoveryWarningDialog,
        ),
        _buildSettingsTile(
          'Import existing wallet (advanced)',
          'Use a recovery phrase you already have',
          Icons.upload_file,
          onTap: _showImportWarningDialog,
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return _buildSection(
      'Security & Privacy',
      Icons.security,
      [
        _buildSettingsTile(
          'Biometric Authentication',
          'Use fingerprint or face unlock',
          Icons.fingerprint,
          trailing: Switch(
            value: _biometricAuth,
            onChanged: (value) {
              _toggleBiometric(value);
            },
            activeThumbColor: Provider.of<ThemeProvider>(context).accentColor,
          ),
        ),
        _buildSettingsTile(
          'Set App PIN',
          'Protect the app with a numeric PIN',
          Icons.pin,
          onTap: () => _showSetPinDialog(),
        ),
        _buildSettingsTile(
          'Auto-lock',
          'Lock app after inactivity',
          Icons.lock_clock,
          onTap: () => _showAutoLockDialog(),
        ),
        _buildSettingsTile(
          'Privacy Mode',
          'Hide sensitive information',
          Icons.visibility_off,
          trailing: Switch(
            value: _privacyMode,
            onChanged: (value) {
              setState(() {
                _privacyMode = value;
              });
              _saveAllSettings();
            },
            activeThumbColor: Provider.of<ThemeProvider>(context).accentColor,
          ),
        ),
        _buildSettingsTile(
          'Clear Cache',
          'Remove temporary files',
          Icons.clear_all,
          onTap: () => _showClearCacheDialog(),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return _buildSection(
      'Data & Analytics',
      Icons.analytics,
      [
        // Mock Data toggle removed - backend controls via USE_MOCK_DATA env variable
        _buildSettingsTile(
          'Analytics',
          'Help improve the app',
          Icons.analytics,
          trailing: Switch(
            value: _analytics,
            onChanged: (value) {
              setState(() {
                _analytics = value;
              });
              _saveAllSettings();
            },
            activeThumbColor: Provider.of<ThemeProvider>(context).accentColor,
          ),
        ),
        _buildSettingsTile(
          'Crash Reporting',
          'Send crash reports automatically',
          Icons.bug_report,
          trailing: Switch(
            value: _crashReporting,
            onChanged: (value) {
              setState(() {
                _crashReporting = value;
              });
              _saveAllSettings();
            },
            activeThumbColor: Provider.of<ThemeProvider>(context).accentColor,
          ),
        ),
        _buildSettingsTile(
          'Skip Onboarding',
          'Skip welcome screens for returning users',
          Icons.fast_forward,
          trailing: Switch(
            value: _skipOnboardingForReturningUsers,
            onChanged: (value) {
              setState(() {
                _skipOnboardingForReturningUsers = value;
              });
              _saveAllSettings();
            },
            activeThumbColor: Provider.of<ThemeProvider>(context).accentColor,
          ),
        ),
        _buildSettingsTile(
          'Data Export',
          'Download your data',
          Icons.download,
          onTap: () => _showDataExportDialog(),
        ),
        _buildSettingsTile(
          'Reset Permission Flags',
          'Clear saved permission/service prompts',
          Icons.location_off,
          onTap: () => _showResetPermissionFlagsDialog(),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      'About',
      Icons.info,
      [
        _buildSettingsTile(
          'Version',
          AppInfo.version,
          Icons.app_registration,
          onTap: () => _showVersionDialog(),
        ),
        _buildSettingsTile(
          'Terms of Service',
          'Read our terms',
          Icons.description,
          onTap: () => _showTermsDialog(),
        ),
        _buildSettingsTile(
          'Privacy Policy',
          'Read our privacy policy',
          Icons.privacy_tip,
          onTap: () => _showPrivacyPolicyDialog(),
        ),
        _buildSettingsTile(
          'Support',
          'Get help or report issues',
          Icons.help,
          onTap: () => _showSupportDialog(),
        ),
        _buildSettingsTile(
          'Open Source Licenses',
          'View third-party licenses',
          Icons.code,
          onTap: () => _showLicensesDialog(),
        ),
        _buildSettingsTile(
          'Rate App',
          'Rate us on the app store',
          Icons.star,
          onTap: () => _showRateAppDialog(),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return _buildSection(
      'Danger Zone',
      Icons.warning,
      [
        _buildSettingsTile(
          'Reset App',
          'Clear all data and settings',
          Icons.refresh,
          onTap: () => _showResetDialog(),
          isDestructive: true,
        ),
        _buildSettingsTile(
          'Delete Account',
          'Permanently delete your account',
          Icons.delete_forever,
          onTap: () => _showDeleteAccountDialog(),
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: Provider.of<ThemeProvider>(context).accentColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildSettingsTile(
    String title,
    String subtitle,
    IconData icon, {
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDestructive 
                ? Colors.red.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        leading: Icon(
          icon,
          color: isDestructive 
              ? Colors.red
              : Provider.of<ThemeProvider>(context).accentColor,
          size: 24,
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDestructive 
                ? Colors.red
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: trailing ?? (onTap != null 
            ? Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              )
            : null),
        onTap: onTap,
      ),
    );
  }

  // Dialog methods
  void _showNetworkDialog() {
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final currentNetwork = web3Provider.currentNetwork.toLowerCase();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Select Network',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNetworkOption(
              'Mainnet',
              'Live Solana network',
              currentNetwork == 'mainnet',
              () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                navigator.pop();
                web3Provider.switchNetwork('Mainnet');
                walletProvider.switchSolanaNetwork('Mainnet');
                setState(() {
                  _networkSelection = 'Mainnet';
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('networkSelection', 'Mainnet');
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Switched to Mainnet')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildNetworkOption(
              'Devnet',
              'Development network for testing',
              currentNetwork == 'devnet',
              () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                navigator.pop();
                web3Provider.switchNetwork('Devnet');
                walletProvider.switchSolanaNetwork('Devnet');
                setState(() {
                  _networkSelection = 'Devnet';
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('networkSelection', 'Devnet');
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Switched to Devnet')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildNetworkOption(
              'Testnet',
              'Test network for development',
              currentNetwork == 'testnet',
              () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                navigator.pop();
                web3Provider.switchNetwork('Testnet');
                walletProvider.switchSolanaNetwork('Testnet');
                setState(() {
                  _networkSelection = 'Testnet';
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('networkSelection', 'Testnet');
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Switched to Testnet')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkOption(String name, String description, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected 
              ? Provider.of<ThemeProvider>(context).accentColor 
              : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected 
            ? Provider.of<ThemeProvider>(context).accentColor.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected 
                ? Provider.of<ThemeProvider>(context).accentColor 
                : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog() {
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (!web3Provider.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect your wallet first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Backup Wallet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will show your recovery phrase.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.error, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Security Warning',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Make sure you\'re in a private place\n• Never share your recovery phrase\n• Write it down and store it safely',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
            ),
            onPressed: () {
              Navigator.pop(context);
              _navigateToRecoveryReveal(walletProvider);
            },
            child: Text(
              'Continue',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToRecoveryReveal(WalletProvider walletProvider) {
    final hasWallet = walletProvider.wallet != null || (walletProvider.currentWalletAddress ?? '').isNotEmpty;
    if (!hasWallet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connect or create a wallet first.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MnemonicRevealScreen()));
  }

  void _showAutoLockDialog() {
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Auto-lock Timer',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final label = opt['label'] as String;
            final seconds = opt['seconds'] as int;
            final isSelected = _autoLockTime == label;
            return ListTile(
              title: Text(
                label,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              trailing: isSelected ? Icon(Icons.check, color: Provider.of<ThemeProvider>(context, listen: false).accentColor) : null,
              onTap: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                setState(() {
                  _autoLockTime = label;
                });
                // Persist selection to provider and secure storage
                try {
                  await walletProvider.setLockTimeoutSeconds(seconds);
                } catch (e) {
                  debugPrint('Failed to set lock timeout: $e');
                }
                await _saveAllSettings();
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Auto-lock set to $label')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    if (value) {
      final canUse = await walletProvider.canUseBiometrics();
      if (!canUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric unlock not available on this device.')),
          );
        }
        setState(() => _biometricAuth = false);
        _saveAllSettings();
        return;
      }
      // Optional: require one successful auth when enabling
      final ok = await walletProvider.authenticateWithBiometrics();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication failed.')),
          );
        }
        setState(() => _biometricAuth = false);
        _saveAllSettings();
        return;
      }
    }
    setState(() => _biometricAuth = value);
    _saveAllSettings();
  }

  void _showRecoveryWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text('Export recovery phrase', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Only view your phrase in private. We never store it, and anyone with it can move your assets.',
              style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Confirm you are ready before revealing the words.',
                    style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MnemonicRevealScreen()));
            },
            child: const Text('Show phrase'),
          ),
        ],
      ),
    );
  }

  void _showImportWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.report_gmailerrorred, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text('Import existing wallet', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Only paste a recovery phrase from a trusted source. Avoid public Wi-Fi and screensharing while importing.',
              style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.privacy_tip_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'We never store your seed phrase. You keep full ownership of your assets.',
                    style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectWallet(initialStep: 1)));
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  void _showSetPinDialog() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Set App PIN',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'PIN',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Confirm PIN',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.outline)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              // Clear PIN
              await walletProvider.clearPin();
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(const SnackBar(content: Text('PIN cleared')));
            },
            child: Text('Clear PIN', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              if (pin.length < 4 || confirm.length < 4) {
                messenger.showSnackBar(const SnackBar(content: Text('PIN must be at least 4 digits')));
                return;
              }
              if (pin != confirm) {
                messenger.showSnackBar(const SnackBar(content: Text('PINs do not match')));
                return;
              }
              try {
                await walletProvider.setPin(pin);
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(const SnackBar(content: Text('PIN set successfully')));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(content: Text('Failed to set PIN')));
              }
            },
            child: Text('Save', style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onPrimary)),
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
        title: Text(
          'Clear Cache',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will clear temporary files and may improve performance.',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              // Clear SharedPreferences cache (except critical data)
              final prefs = await SharedPreferences.getInstance();
              final keysToKeep = ['has_wallet', 'wallet_address', 'private_key', 'mnemonic'];
              final allKeys = prefs.getKeys();
              
              for (var key in allKeys) {
                if (!keysToKeep.contains(key)) {
                  await prefs.remove(key);
                }
              }
              
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showResetPermissionFlagsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          'Reset Permission Flags',
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will clear the app\'s stored permission and service request flags. Use this to re-trigger permission prompts if needed.',
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.inter(color: Theme.of(dialogContext).colorScheme.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _resetPermissionFlags();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Permission flags reset')),
              );
            },
            child: Text('Reset', style: GoogleFonts.inter(color: Theme.of(dialogContext).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPermissionFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      // Keep a small whitelist of critical keys
      const keepKeys = {'has_wallet', 'wallet_address', 'private_key', 'mnemonic'};

      for (final key in keys) {
        if (keepKeys.contains(key)) continue;
        final k = key.toLowerCase();
        if (k.contains('permission') || k.contains('service') || k.contains('location') || k.contains('camera') || k.contains('_requested') || k.contains('gps')) {
          try {
            await prefs.remove(key);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Failed to reset persisted permission flags: $e');
    }
  }

  void _showDataExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Export Data',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will create a file with your app data (excluding private keys).',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              // Prepare export data
              final prefs = await SharedPreferences.getInstance();
              final exportData = {
                'profile': {
                  'profileVisibility': prefs.getString('profile_visibility') ?? 'Public',
                  'showAchievements': prefs.getBool('showAchievements') ?? true,
                  'showFriends': prefs.getBool('showFriends') ?? true,
                },
                'settings': {
                  'enableAnalytics': prefs.getBool('enableAnalytics') ?? true,
                  'enableCrashReporting': prefs.getBool('enableCrashReporting') ?? true,
                  'skipOnboarding': prefs.getBool('skipOnboardingForReturningUsers') ?? true,
                },
                'exportDate': DateTime.now().toIso8601String(),
              };
              
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(content: Text('Data exported: ${exportData.length} categories')),
              );
            },
            child: const Text('Export'),
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
        title: Text(
          'Reset App',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will clear all app data and settings. Your wallet will be disconnected but not deleted.',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final web3Provider = Provider.of<Web3Provider>(context, listen: false);

              // Clear all SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              // Disconnect wallet if connected
              if (web3Provider.isConnected) {
                web3Provider.disconnectWallet();
              }

              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('App reset successfully. Please restart the app.'),
                  duration: Duration(seconds: 3),
                ),
              );
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          'Delete Account',
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Show confirmation dialog — ensure mounted before calling showDialog
              if (!mounted) return;
              final dialogNavigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              final confirmed = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) => AlertDialog(
                  backgroundColor: Theme.of(confirmContext).colorScheme.surface,
                  title: Text(
                    'Final Confirmation',
                    style: GoogleFonts.inter(
                      color: Theme.of(confirmContext).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Text(
                    'Type "DELETE" to confirm permanent account deletion.',
                    style: GoogleFonts.inter(
                      color: Theme.of(confirmContext).colorScheme.onSurface,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: Text('Cancel', style: GoogleFonts.inter()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: Text(
                        'Confirm',
                        style: GoogleFonts.inter(color: Theme.of(confirmContext).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );
              
              if (!mounted) return;
              if (confirmed == true) {
                // Clear all data
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                // Disconnect wallet
                if (!mounted) return;
                final web3Provider = Provider.of<Web3Provider>(context, listen: false);
                if (web3Provider.isConnected) {
                  web3Provider.disconnectWallet();
                }

                if (!mounted) return;
                dialogNavigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Account deleted. All data has been removed.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              } else {
                if (!mounted) return;
                dialogNavigator.pop();
              }
            },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  // Save all settings
  Future<void> _saveAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Security settings
    await prefs.setBool('biometricAuth', _biometricAuth);
    await prefs.setBool('privacyMode', _privacyMode);
    
    // Privacy settings  
    await prefs.setBool('enableAnalytics', _enableAnalytics);
    await prefs.setBool('enableCrashReporting', _enableCrashReporting);
    
    // App behavior settings
    await prefs.setBool('skipOnboardingForReturningUsers', _skipOnboardingForReturningUsers);
    
    // Wallet settings
    await prefs.setString('networkSelection', _networkSelection);
    await prefs.setBool('autoBackup', _autoBackup);
    
    // Profile settings
    await prefs.setString('profileVisibility', _profileVisibility);
    await prefs.setBool('showAchievements', _showAchievements);
    await prefs.setBool('showFriends', _showFriends);
    await prefs.setBool('allowMessages', _allowMessages);
  }

  // Load all settings
  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    
    setState(() {
      // Security settings
      _biometricAuth = prefs.getBool('biometricAuth') ?? false;
      _privacyMode = prefs.getBool('privacyMode') ?? false;
      
      // Privacy settings
      _enableAnalytics = prefs.getBool('enableAnalytics') ?? true;
      _enableCrashReporting = prefs.getBool('enableCrashReporting') ?? true;
      
      // App behavior settings
      _skipOnboardingForReturningUsers = prefs.getBool('skipOnboardingForReturningUsers') ?? AppConfig.skipOnboardingForReturningUsers;
      
      // Wallet settings - sync with web3Provider
      _networkSelection = web3Provider.currentNetwork.isNotEmpty 
          ? web3Provider.currentNetwork 
          : (prefs.getString('networkSelection') ?? 'Mainnet');
      _autoBackup = prefs.getBool('autoBackup') ?? true;
      
      // Profile settings
      _profileVisibility = prefs.getString('profileVisibility') ?? 'Public';
      _showAchievements = prefs.getBool('showAchievements') ?? true;
      _showFriends = prefs.getBool('showFriends') ?? true;
      _allowMessages = prefs.getBool('allowMessages') ?? true;
    });
  }

  Future<void> _saveProfileVisibility(String visibility) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_visibility', visibility);
  }

  // Wallet dialog methods
  void _showTransactionHistoryDialog() {
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Transaction History',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.5,
          child: web3Provider.transactions.isNotEmpty
            ? Column(
                children: [
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: web3Provider.transactions.length,
                      itemBuilder: (context, index) {
                        final tx = web3Provider.transactions[index];
                        return _buildWalletTransactionItem(tx);
                      },
                    ),
                  ),
                ],
              )
            : Center(
                child: EmptyStateCard(
                  icon: Icons.receipt_long,
                  title: 'No Transactions Found',
                  description: 'Your transaction history will appear here when you start making transactions.',
                ),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletTransactionItem(WalletTransaction tx) {
    final isIncoming = tx.type == TransactionType.receive;
    final amount = tx.amount;
    final token = tx.token;
    final timestamp = tx.timestamp.toString();
    final from = tx.fromAddress ?? 'Unknown';
    final to = tx.toAddress ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isIncoming 
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) 
                : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isIncoming ? Icons.call_received : Icons.call_made,
              color: isIncoming ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIncoming ? 'Received' : 'Sent',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${isIncoming ? 'From' : 'To'}: ${(isIncoming ? from : to).substring(0, 8)}...',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  timestamp,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncoming ? '+' : '-'}$amount $token',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isIncoming ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }


  // About dialog methods
  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'App Version',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'art.kubus',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version: ${AppInfo.version}',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Build: ${AppInfo.buildNumber}',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2025 kubus',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            Text(
              'All rights reserved.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Terms of Service',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'By using ART.KUBUS, you agree to these terms:\n\n'
            '1. You are responsible for maintaining the security of your wallet.\n'
            '2. We do not store your private keys or seed phrases.\n'
            '3. All transactions are final and irreversible.\n'
            '4. Use the app at your own risk.\n'
            '5. We reserve the right to update these terms.\n\n'
            'For the complete terms, visit our website.',
            style: GoogleFonts.inter(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'Your privacy is important to us:\n\n'
            '• We do not collect personal data without consent\n'
            '• Your wallet data is stored locally on your device\n'
            '• We may collect anonymous usage statistics\n'
            '• We do not share your data with third parties\n'
            '• You can disable analytics in Privacy settings\n\n'
            'For our complete privacy policy, visit our website.',
            style: GoogleFonts.inter(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Support',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Need help? Choose an option:',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening FAQ...')),
                );
              },
              icon: const Icon(Icons.help_outline),
              label: const Text('View FAQ'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening email client...')),
                );
              },
              icon: const Icon(Icons.email),
              label: const Text('Contact Support'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLicensesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Open Source Licenses',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'This app uses the following open source libraries:\n\n'
            '• Flutter SDK (BSD License)\n'
            '• Material Design Icons (Apache 2.0)\n'
            '• SharedPreferences (BSD License)\n'
            '• HTTP (BSD License)\n'
            '• Path Provider (BSD License)\n\n'
            'Full license texts are available in the app repository.',
            style: GoogleFonts.inter(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRateAppDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Rate ART.KUBUS',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enjoying the app?',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please consider rating us on the app store!',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Provider.of<ThemeProvider>(context).accentColor, size: 30),
                Icon(Icons.star, color: Provider.of<ThemeProvider>(context).accentColor, size: 30),
                Icon(Icons.star, color: Provider.of<ThemeProvider>(context).accentColor, size: 30),
                Icon(Icons.star, color: Provider.of<ThemeProvider>(context).accentColor, size: 30),
                Icon(Icons.star, color: Provider.of<ThemeProvider>(context).accentColor, size: 30),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening app store...')),
              );
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  // Helper methods for dialog components
  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: SwitchListTile(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        activeThumbColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
      ),
    );
  }

  Widget _buildDropdownTile(String title, String subtitle, String value, List<String> options, Function(String?) onChanged) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        trailing: DropdownButton<String>(
          value: value,
          underline: Container(),
          dropdownColor: Theme.of(context).colorScheme.surface,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          items: options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: onChanged,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        leading: Icon(
          icon,
          color: Provider.of<ThemeProvider>(context, listen: false).accentColor,
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildVisibilityOptionTile({
    required BuildContext context,
    required _ProfileVisibilityOption option,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: context.animationTheme.short,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : theme.colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: context.animationTheme.short,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : theme.colorScheme.outline,
                  width: 2,
                ),
              ),
              child: AnimatedContainer(
                duration: context.animationTheme.short,
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accentColor : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: accentColor,
              ),
          ],
        ),
      ),
    );
  }

  // Profile Settings Dialog Methods
  void _showProfileVisibilityDialog() {
    String selectedVisibility = _profileVisibility;
    final accentColor = Provider.of<ThemeProvider>(context, listen: false).accentColor;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(innerContext).colorScheme.surface,
          title: Text(
            'Profile Visibility',
            style: GoogleFonts.inter(
              color: Theme.of(innerContext).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _profileVisibilityOptions
                .map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildVisibilityOptionTile(
                      context: innerContext,
                      option: option,
                      accentColor: accentColor,
                      isSelected: option.value == selectedVisibility,
                      onTap: () => setDialogState(() => selectedVisibility = option.value),
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(innerContext).colorScheme.outline,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                setState(() {
                  _profileVisibility = selectedVisibility;
                });
                await _saveProfileVisibility(selectedVisibility);
                if (!mounted) return;
                navigator.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Profile visibility set to $selectedVisibility')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacySettingsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(innerContext).colorScheme.surface,
          title: Text(
            'Privacy Settings',
            style: GoogleFonts.inter(
              color: Theme.of(innerContext).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSwitchTile(
                    'Data Collection',
                    'Allow app to collect usage data',
                    _dataCollection,
                    (value) => setDialogState(() => _dataCollection = value),
                  ),
                  _buildSwitchTile(
                    'Personalized Ads',
                    'Show ads based on your interests',
                    _personalizedAds,
                    (value) => setDialogState(() => _personalizedAds = value),
                  ),
                  _buildSwitchTile(
                    'Location Tracking',
                    'Allow location-based features',
                    _locationTracking,
                    (value) => setDialogState(() => _locationTracking = value),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownTile(
                    'Data Retention',
                    'How long to keep your data',
                    _dataRetention,
                    ['3 Months', '6 Months', '1 Year', '2 Years', 'Indefinite'],
                    (value) => setDialogState(() => _dataRetention = value!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(innerContext).colorScheme.outline,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                setState(() {}); // Update main state
                await _saveAllSettings();
                if (!mounted) return;
                navigator.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Privacy settings updated')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecuritySettingsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(innerContext).colorScheme.surface,
          title: Text(
            'Security Settings',
            style: GoogleFonts.inter(
              color: Theme.of(innerContext).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionTile(
                    'Change Password',
                    'Update your account password',
                    Icons.lock_outline,
                    () {
                      Navigator.pop(innerContext);
                      _showChangePasswordDialog();
                    },
                  ),
                  _buildSwitchTile(
                    'Two-Factor Authentication',
                    'Add extra security to your account',
                    _twoFactorAuth,
                    (value) => setDialogState(() => _twoFactorAuth = value),
                  ),
                  _buildSwitchTile(
                    'Session Timeout',
                    'Automatically sign out when idle',
                    _sessionTimeout,
                    (value) => setDialogState(() => _sessionTimeout = value),
                  ),
                  _buildDropdownTile(
                    'Auto-Lock Time',
                    'Lock app after inactivity',
                    _autoLockTime,
                    ['1 minute', '5 minutes', '15 minutes', '30 minutes', 'Never'],
                    (value) => setDialogState(() => _autoLockTime = value!),
                  ),
                  _buildSwitchTile(
                    'Login Notifications',
                    'Get notified of new sign-ins',
                    _loginNotifications,
                    (value) => setDialogState(() => _loginNotifications = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(innerContext).colorScheme.outline,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                setState(() {}); // Update main state
                await _saveAllSettings();
                if (!mounted) return;
                navigator.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Security settings updated')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Account Management',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSwitchTile(
                    'Email Notifications',
                    'Receive updates via email',
                    _emailNotifications,
                    (value) => setDialogState(() => _emailNotifications = value),
                  ),
                  _buildSwitchTile(
                    'Push Notifications',
                    'Get notifications on your device',
                    _pushNotifications,
                    (value) => setDialogState(() => _pushNotifications = value),
                  ),
                  _buildSwitchTile(
                    'Marketing Emails',
                    'Receive promotional content',
                    _marketingEmails,
                    (value) => setDialogState(() => _marketingEmails = value),
                  ),
                  _buildDropdownTile(
                    'Account Type',
                    'Your current membership level',
                    _accountType,
                    ['Standard', 'Premium', 'Enterprise'],
                    (value) => setDialogState(() => _accountType = value!),
                  ),
                  _buildSwitchTile(
                    'Public Profile',
                    'Allow others to find your profile',
                    _publicProfile,
                    (value) => setDialogState(() => _publicProfile = value),
                  ),
                  const SizedBox(height: 16),
                  _buildActionTile(
                    'Deactivate Account',
                    'Temporarily disable your account',
                    Icons.pause_circle_outline,
                    () {
                      Navigator.pop(context);
                      _showAccountDeactivationDialog();
                    },
                  ),
                  _buildActionTile(
                    'Delete Account',
                    'Permanently remove your account',
                    Icons.delete_forever,
                    () {
                      Navigator.pop(context);
                      _showDeleteAccountDialog();
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final dialogContext = context;
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(dialogContext);
                setState(() {}); // Update main state
                await _saveAllSettings();
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Account settings updated')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Additional Dialog Methods
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Change Password',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
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

  void _showAccountDeactivationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Deactivate Account',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to deactivate your account?',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You can reactivate it later by logging in.',
              style: GoogleFonts.inter(
                fontSize: 14, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deactivated')),
              );
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

class _ProfileVisibilityOption {
  final String value;
  final String label;
  final String description;

  const _ProfileVisibilityOption({
    required this.value,
    required this.label,
    required this.description,
  });
}
