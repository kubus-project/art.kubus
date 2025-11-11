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
import '../providers/config_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/artwork_provider.dart';
import '../widgets/platform_aware_widgets.dart';
import '../web3/wallet.dart';

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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
    _loadAllSettings();
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
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeProvider.accentColor,
            themeProvider.accentColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: themeProvider.accentColor.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anonymous User',
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
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No wallet connected',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
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
          MaterialPageRoute(builder: (context) => const Wallet()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
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
                color: Colors.white.withOpacity(0.8),
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
                        color: color.withOpacity(0.4),
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
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Running on ${platformProvider.currentPlatform.toString().split('.').last}',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onPrimary,
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
                            color: entry.value ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getCapabilityDisplayName(entry.key),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: entry.value ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
          'Account Management',
          'Type: $_accountType, Notifications: ${_emailNotifications ? "On" : "Off"}',
          Icons.manage_accounts,
          onTap: () {
            _showAccountManagementDialog();
          },
        ),
      ],
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
              web3Provider.connectWallet();
            }
          },
          trailing: web3Provider.isConnected 
              ? Icon(Icons.check_circle, color: Provider.of<ThemeProvider>(context).accentColor)
              : const Icon(Icons.error_outline, color: Colors.orange),
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
              setState(() {
                _biometricAuth = value;
              });
              _saveAllSettings();
            },
            activeColor: Provider.of<ThemeProvider>(context).accentColor,
          ),
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
            activeColor: Provider.of<ThemeProvider>(context).accentColor,
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
        _buildSettingsTile(
          'Mock Data',
          'Use demo data for testing (Developer)',
          Icons.science,
          trailing: Consumer<ConfigProvider>(
            builder: (context, configProvider, child) {
              return Switch(
                value: configProvider.useMockData,
                onChanged: (value) async {
                  await configProvider.setUseMockData(value);
                  
                  // Sync with ProfileProvider
                  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
                  profileProvider.syncWithConfigProvider(value);
                  
                  // Sync with ArtworkProvider
                  final artworkProvider = Provider.of<ArtworkProvider>(context, listen: false);
                  artworkProvider.setUseMockData(value);
                  
                  _showRestartDialog();
                },
                activeColor: Provider.of<ThemeProvider>(context).accentColor,
              );
            },
          ),
        ),
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
            activeColor: Provider.of<ThemeProvider>(context).accentColor,
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
            activeColor: Provider.of<ThemeProvider>(context).accentColor,
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
            activeColor: Provider.of<ThemeProvider>(context).accentColor,
          ),
        ),
        _buildSettingsTile(
          'Data Export',
          'Download your data',
          Icons.download,
          onTap: () => _showDataExportDialog(),
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
          '1.0.0+1',
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
                ? Colors.red.withOpacity(0.3)
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
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: trailing ?? (onTap != null 
            ? Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              )
            : null),
        onTap: onTap,
      ),
    );
  }

  // Dialog methods
  void _showNetworkDialog() {
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    String currentNetwork = web3Provider.currentNetwork;
    
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
              currentNetwork == 'Mainnet',
              () {
                Navigator.pop(context);
                web3Provider.switchNetwork('Mainnet');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Switched to Mainnet')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildNetworkOption(
              'Devnet',
              'Development network for testing',
              currentNetwork == 'Devnet',
              () {
                Navigator.pop(context);
                web3Provider.switchNetwork('Devnet');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Switched to Devnet')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildNetworkOption(
              'Testnet',
              'Test network for development',
              currentNetwork == 'Testnet',
              () {
                Navigator.pop(context);
                web3Provider.switchNetwork('Testnet');
                ScaffoldMessenger.of(context).showSnackBar(
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
              color: Colors.orange,
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
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Security Warning',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Make sure you\'re in a private place\n• Never share your recovery phrase\n• Write it down and store it safely',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.orange.shade700,
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
              _showRecoveryPhrase();
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

  void _showRecoveryPhrase() {
    // Generate a mock recovery phrase for demo
    final words = [
      'abandon', 'ability', 'able', 'about', 'above', 'absent', 
      'absorb', 'abstract', 'absurd', 'abuse', 'access', 'accident'
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Recovery Phrase',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Write down these 12 words in order:',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}. ${words[index]}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recovery phrase shown. Please store it safely!')),
              );
            },
            child: Text(
              'I\'ve Written It Down',
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

  void _showAutoLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-lock Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'Immediately',
            '1 minute',
            '5 minutes',
            '15 minutes',
            'Never',
          ].map((option) => ListTile(
            title: Text(option),
            onTap: () {
              Navigator.pop(context);
              // TODO: Set auto-lock timer
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear temporary files and may improve performance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Clear cache
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDataExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('This will create a file with your app data (excluding private keys).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Export data
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
        title: const Text('Reset App'),
        content: const Text('This will clear all app data and settings. Your wallet will be disconnected but not deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              // TODO: Reset app state
            },
            child: Text('Reset', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This action cannot be undone. All your data will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              // TODO: Delete account
            },
            child: Text('Delete Forever', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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
    
    setState(() {
      // Security settings
      _biometricAuth = prefs.getBool('biometricAuth') ?? false;
      _privacyMode = prefs.getBool('privacyMode') ?? false;
      
      // Privacy settings
      _enableAnalytics = prefs.getBool('enableAnalytics') ?? true;
      _enableCrashReporting = prefs.getBool('enableCrashReporting') ?? true;
      
      // App behavior settings
      _skipOnboardingForReturningUsers = prefs.getBool('skipOnboardingForReturningUsers') ?? AppConfig.skipOnboardingForReturningUsers;
      
      // Wallet settings
      _networkSelection = prefs.getString('networkSelection') ?? 'Mainnet';
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
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    
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
          child: configProvider.useMockData && web3Provider.transactions.isNotEmpty
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
                        return _buildTransactionItem(tx);
                      },
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Transactions Found',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your transaction history will appear here when you start making transactions.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
        ),
        actions: [
          if (configProvider.useMockData && web3Provider.isConnected)
            TextButton(
              onPressed: () {
                web3Provider.addMockTransaction();
                Navigator.pop(context);
                _showTransactionHistoryDialog();
              },
              child: Text(
                'Add Mock Transaction',
                style: GoogleFonts.inter(
                  color: Provider.of<ThemeProvider>(context).accentColor,
                ),
              ),
            ),
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

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final isIncoming = tx['type'] == 'received';
    final amount = tx['amount'] as double;
    final currency = tx['currency'] as String;
    final timestamp = tx['timestamp'] as String;
    final from = tx['from'] as String;
    final to = tx['to'] as String;

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
                ? Colors.green.withValues(alpha: 0.1) 
                : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isIncoming ? Icons.call_received : Icons.call_made,
              color: isIncoming ? Colors.green : Colors.red,
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
            '${isIncoming ? '+' : '-'}$amount $currency',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isIncoming ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Required'),
        content: const Text('The mock data setting has been changed. Please restart the app for changes to take effect.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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
        title: const Text('App Version'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ART.KUBUS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Version: 1.0.0+1'),
            Text('Build: 001'),
            SizedBox(height: 16),
            Text('© 2024 ART.KUBUS Team'),
            Text('All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'By using ART.KUBUS, you agree to these terms:\n\n'
            '1. You are responsible for maintaining the security of your wallet.\n'
            '2. We do not store your private keys or seed phrases.\n'
            '3. All transactions are final and irreversible.\n'
            '4. Use the app at your own risk.\n'
            '5. We reserve the right to update these terms.\n\n'
            'For the complete terms, visit our website.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us:\n\n'
            '• We do not collect personal data without consent\n'
            '• Your wallet data is stored locally on your device\n'
            '• We may collect anonymous usage statistics\n'
            '• We do not share your data with third parties\n'
            '• You can disable analytics in Privacy settings\n\n'
            'For our complete privacy policy, visit our website.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Need help? Choose an option:'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLicensesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Source Licenses'),
        content: const SingleChildScrollView(
          child: Text(
            'This app uses the following open source libraries:\n\n'
            '• Flutter SDK (BSD License)\n'
            '• Material Design Icons (Apache 2.0)\n'
            '• SharedPreferences (BSD License)\n'
            '• HTTP (BSD License)\n'
            '• Path Provider (BSD License)\n\n'
            'Full license texts are available in the app repository.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRateAppDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate ART.KUBUS'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enjoying the app?'),
            SizedBox(height: 8),
            Text('Please consider rating us on the app store!'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 30),
                Icon(Icons.star, color: Colors.amber, size: 30),
                Icon(Icons.star, color: Colors.amber, size: 30),
                Icon(Icons.star, color: Colors.amber, size: 30),
                Icon(Icons.star, color: Colors.amber, size: 30),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
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
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildDropdownTile(String title, String subtitle, String value, List<String> options, Function(String?) onChanged) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: DropdownButton<String>(
          value: value,
          underline: Container(),
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
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        leading: Icon(icon),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  // Profile Settings Dialog Methods
  void _showProfileVisibilityDialog() {
    String selectedVisibility = _profileVisibility;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Profile Visibility'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Public'),
                subtitle: const Text('Anyone can see your profile'),
                value: 'Public',
                groupValue: selectedVisibility,
                onChanged: (value) => setDialogState(() => selectedVisibility = value!),
              ),
              RadioListTile<String>(
                title: const Text('Private'),
                subtitle: const Text('Only you can see your profile'),
                value: 'Private',
                groupValue: selectedVisibility,
                onChanged: (value) => setDialogState(() => selectedVisibility = value!),
              ),
              RadioListTile<String>(
                title: const Text('Friends Only'),
                subtitle: const Text('Only friends can see your profile'),
                value: 'Friends Only',
                groupValue: selectedVisibility,
                onChanged: (value) => setDialogState(() => selectedVisibility = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _profileVisibility = selectedVisibility;
                });
                await _saveProfileVisibility(selectedVisibility);
                Navigator.pop(context);
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Privacy Settings'),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {}); // Update main state
                await _saveAllSettings();
                Navigator.pop(context);
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Security Settings'),
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
                      Navigator.pop(context);
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {}); // Update main state
                await _saveAllSettings();
                Navigator.pop(context);
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
          title: const Text('Account Management'),
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {}); // Update main state
                await _saveAllSettings();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
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
        title: const Text('Change Password'),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
        title: const Text('Deactivate Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to deactivate your account?',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You can reactivate it later by logging in.',
              style: TextStyle(
                fontSize: 14, 
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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
