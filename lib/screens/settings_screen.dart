import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/themeprovider.dart';
import '../providers/web3provider.dart';
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: themeProvider.isDarkMode 
          ? const Color(0xFF0A0A0A) 
          : const Color(0xFFF8F9FA),
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
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
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
                        color: Colors.white,
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
                child: const Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          if (web3Provider.isConnected) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceCard('KUB8', web3Provider.kub8Balance.toStringAsFixed(2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBalanceCard('SOL', web3Provider.solBalance.toStringAsFixed(3)),
                ),
              ],
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
                color: Colors.white,
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
                        ? Border.all(color: Colors.white, width: 3)
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
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Network'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Mainnet'),
              subtitle: const Text('Live network'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Switch to mainnet
              },
            ),
            ListTile(
              title: const Text('Devnet'),
              subtitle: const Text('Development network'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Switch to devnet
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Wallet'),
        content: const Text('This will show your recovery phrase. Make sure you\'re in a private place.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Show backup screen
            },
            child: const Text('Continue'),
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
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
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
            child: const Text('Delete Forever', style: TextStyle(color: Colors.white)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaction History'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No transactions found'),
            SizedBox(height: 16),
            Text('Your transaction history will appear here when you start making transactions.'),
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Are you sure you want to deactivate your account?',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'You can reactivate it later by logging in.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
