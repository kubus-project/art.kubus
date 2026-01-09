import 'dart:async';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/web3provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/platform_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/detail/detail_shell_components.dart';
import '../../widgets/support/support_ticket_dialog.dart';
import '../../utils/app_animations.dart';
import 'components/desktop_widgets.dart';
import 'community/desktop_profile_edit_screen.dart';
import '../web3/wallet/wallet_home.dart';
import '../web3/wallet/mnemonic_reveal_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../../../config/config.dart';
import '../../providers/locale_provider.dart';
import '../../utils/app_color_utils.dart';


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
    final l10n = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;
    final settingsItems = [
      _SettingsItem(l10n.userProfileTitle, Icons.person_outline, 0),
      _SettingsItem(l10n.settingsWalletSectionTitle, Icons.account_balance_wallet_outlined, 1),
      _SettingsItem(l10n.settingsAppearanceSectionTitle, Icons.palette_outlined, 2),
      _SettingsItem(l10n.permissionsNotificationsTitle, Icons.notifications_outlined, 3),
      _SettingsItem(l10n.settingsPrivacySettingsTileTitle, Icons.lock_outline, 4),
      _SettingsItem(l10n.settingsSecuritySettingsTileTitle, Icons.security, 5),
      _SettingsItem(l10n.userProfileAchievementsTitle, Icons.emoji_events_outlined, 6),
      _SettingsItem(l10n.settingsPlatformFeaturesSectionTitle, Icons.phone_android_outlined, 7),
      _SettingsItem(l10n.settingsSupportDialogTitle, Icons.help_outline, 8),
      _SettingsItem(l10n.settingsAboutSectionTitle, Icons.info_outline, 9),
      _SettingsItem(l10n.settingsDangerZoneSectionTitle, Icons.warning_outlined, 10),
    ];

    return ListView(
      padding: EdgeInsets.all(DetailSpacing.lg),
      children: [
        // Header with back button
        Padding(
          padding: EdgeInsets.all(DetailSpacing.lg),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: l10n.commonBack,
              ),
              SizedBox(width: DetailSpacing.sm),
              Expanded(
                child: Text(
                  l10n.settingsTitle,
                  style: DetailTypography.sectionTitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: DetailSpacing.sm),

        // Settings items
        ...settingsItems.map((item) => _buildSettingsSidebarItem(item, themeProvider)),

        SizedBox(height: DetailSpacing.xl),
        const Divider(),
        SizedBox(height: DetailSpacing.lg),

        // Logout button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(DetailRadius.md),
            child: Padding(
              padding: EdgeInsets.all(DetailSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    size: 22,
                    color: errorColor,
                  ),
                  SizedBox(width: DetailSpacing.lg),
                  Text(
                    l10n.settingsLogoutButton,
                    style: DetailTypography.label(context).copyWith(
                      color: errorColor,
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

  /// Returns semantic color based on settings section index
  Color _getSectionColor(int index, ColorScheme scheme) {
    switch (index) {
      case 0: // Profile
        return scheme.secondary;
      case 1: // Wallet
        return AppColorUtils.amberAccent;
      case 2: // Appearance
        return scheme.tertiary;
      case 3: // Notifications
        return AppColorUtils.amberAccent;
      case 4: // Privacy
      case 5: // Security
        return AppColorUtils.indigoAccent;
      case 6: // Achievements
        return Colors.amber;
      case 7: // Platform
        return scheme.secondary;
      case 8: // Help
      case 9: // About
        return scheme.secondary;
      case 10: // Danger Zone
        return scheme.error;
      default:
        return scheme.secondary;
    }
  }

  Widget _buildSettingsSidebarItem(_SettingsItem item, ThemeProvider themeProvider) {
    final isSelected = _selectedSettingsIndex == item.index;
    final scheme = Theme.of(context).colorScheme;
    final sectionColor = _getSectionColor(item.index, scheme);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedSettingsIndex = item.index);
        },
        borderRadius: BorderRadius.circular(DetailRadius.md),
        child: Container(
          key: ValueKey('desktop_settings_sidebar_item_${item.index}'),
          padding: EdgeInsets.all(DetailSpacing.lg),
          decoration: BoxDecoration(
            color: isSelected ? sectionColor.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(DetailRadius.md),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 22,
                color: isSelected
                    ? sectionColor
                    : scheme.onSurface.withValues(alpha: 0.6),
              ),
               SizedBox(width: DetailSpacing.lg),
              Expanded(
                child: Text(
                  item.title,
                  style: isSelected 
                      ? DetailTypography.label(context).copyWith(color: sectionColor)
                      : DetailTypography.body(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    return Consumer2<ProfileProvider, StatsProvider>(
      builder: (context, profileProvider, statsProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final user = profileProvider.currentUser;
        final wallet = (user?.walletAddress ?? '').trim();
        final scheme = Theme.of(context).colorScheme;
        final headerColor = scheme.secondary;

        const metrics = <String>['artworks', 'followers', 'following'];
        if (wallet.isNotEmpty) {
          statsProvider.ensureSnapshot(
            entityType: 'user',
            entityId: wallet,
            metrics: metrics,
            scope: 'public',
          );
        }

        final snapshot = wallet.isEmpty
            ? null
            : statsProvider.getSnapshot(
                entityType: 'user',
                entityId: wallet,
                metrics: metrics,
                scope: 'public',
              );
        final isLoading = wallet.isNotEmpty &&
            statsProvider.isSnapshotLoading(
              entityType: 'user',
              entityId: wallet,
              metrics: metrics,
              scope: 'public',
            ) &&
            snapshot == null;
        final counters = snapshot?.counters ?? const <String, int>{};

        final artworks = wallet.isEmpty
            ? 0
            : (counters['artworks'] ?? user?.stats?.artworksCreated ?? 0);
        final followers = wallet.isEmpty
            ? 0
            : (counters['followers'] ?? user?.stats?.followersCount ?? 0);
        final following = wallet.isEmpty
            ? 0
            : (counters['following'] ?? user?.stats?.followingCount ?? 0);
        String displayCount(int value) => isLoading ? '\u2026' : value.toString();

        return Container(
          padding: EdgeInsets.all(DetailSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile card
              DesktopCard(
                padding: EdgeInsets.zero,
                showBorder: false,
                child: Container(
                  padding: EdgeInsets.all(DetailSpacing.xxl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        headerColor,
                        headerColor.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(DetailRadius.xl),
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(
                        avatarUrl: user?.avatar,
                        wallet: user?.walletAddress ?? '',
                        radius: 52,
                        allowFabricatedFallback: true,
                      ),
                      SizedBox(width: DetailSpacing.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? l10n.settingsGuestUserName,
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (user?.bio != null) ...[
                              SizedBox(height: DetailSpacing.xs),
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
                            SizedBox(height: DetailSpacing.md),
                            Row(
                              children: [
                                _buildProfileStat(l10n.userProfileArtworksTitle, displayCount(artworks)),
                                SizedBox(width: DetailSpacing.xl),
                                _buildProfileStat(l10n.userProfileFollowersStatLabel, displayCount(followers)),
                                SizedBox(width: DetailSpacing.xl),
                                _buildProfileStat(l10n.userProfileFollowingStatLabel, displayCount(following)),
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
                        label: Text(l10n.settingsEditProfileTileTitle),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: headerColor,
                          padding: EdgeInsets.symmetric(horizontal: DetailSpacing.lg + DetailSpacing.xs, vertical: DetailSpacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DetailRadius.md),
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: DetailSpacing.xs),
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsProfileSectionTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.desktopSettingsProfileSectionSubtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          
          DesktopCard(
            child: Column(
              children: [
                _buildTextField(l10n.desktopSettingsDisplayNameLabel, l10n.desktopSettingsDisplayNameHint),
                const SizedBox(height: 20),
                _buildTextField(l10n.desktopSettingsUsernameLabel, l10n.desktopSettingsUsernameHint),
                const SizedBox(height: 20),
                _buildTextField(l10n.desktopSettingsBioLabel, l10n.desktopSettingsBioHint, maxLines: 3),
                const SizedBox(height: 20),
                _buildTextField(l10n.desktopSettingsWebsiteLabel, l10n.desktopSettingsWebsiteHint),
                const SizedBox(height: 20),
                _buildTextField(l10n.desktopSettingsLocationLabel, l10n.desktopSettingsLocationHint),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  _loadSettings();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.commonCancel),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  await _saveSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.commonSave),
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
                color: Theme.of(context).colorScheme.secondary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletSettings(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final web3Provider = Provider.of<Web3Provider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsWalletSectionTitle,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.desktopSettingsWalletSectionSubtitle,
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
                                  ? l10n.settingsWalletConnectionConnected
                                  : l10n.settingsWalletConnectionNotConnected,
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
                          label: Text(l10n.desktopSettingsViewWalletButton),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColorUtils.amberAccent,
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
                    l10n.settingsNetworkTileTitle,
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
                        selectedColor: AppColorUtils.amberAccent.withValues(alpha: 0.2),
                        labelStyle: GoogleFonts.inter(
                          color: isSelected 
                              ? AppColorUtils.amberAccent 
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
                l10n.desktopSettingsSecuritySectionTitle,
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
                      l10n.settingsExportRecoveryPhraseTileTitle,
                      l10n.settingsExportRecoveryPhraseTileSubtitle,
                      Icons.vpn_key,
                      onTap: () => _showRecoveryWarning(),
                    ),
                    const Divider(height: 32),
                    _buildSettingsRow(
                      l10n.desktopSettingsDisconnectWalletTileTitle,
                      l10n.desktopSettingsDisconnectWalletTileSubtitle,
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Text(l10n.settingsSecurityWarningTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsExportRecoveryPhraseDialogBody,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settingsSecurityWarningBullets,
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
            child: Text(l10n.commonCancel),
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
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
  }

  void _showDisconnectConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.desktopSettingsDisconnectWalletDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          l10n.desktopSettingsDisconnectWalletDialogBody,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<Web3Provider>(context, listen: false).disconnectWallet();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.desktopSettingsWalletDisconnectedToast)),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.desktopSettingsDisconnectButton),
          ),
        ],
      ),
    );
  }

  // Dialog Methods from Mobile Settings
  void _showVersionDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.settingsAppVersionDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.appTitle, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(l10n.settingsVersionValue(AppInfo.version), style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
            Text(l10n.settingsBuildValue(AppInfo.buildNumber), style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 16),
            Text(l10n.settingsCopyright(DateTime.now().year), style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            Text(l10n.settingsAllRightsReserved, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.settingsTermsDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsTermsDialogBody,
            style: GoogleFonts.inter(height: 1.5, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.settingsPrivacyPolicyDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsPrivacyPolicyDialogBody,
            style: GoogleFonts.inter(height: 1.5, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    final l10n = AppLocalizations.of(context)!;
    final rootContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(l10n.settingsSupportDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(dialogContext).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsSupportDialogBody, style: GoogleFonts.inter(color: Theme.of(dialogContext).colorScheme.onSurface)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.secondary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(rootContext).showSnackBar(SnackBar(content: Text(l10n.settingsOpeningFaqToast)));
              },
              icon: const Icon(Icons.help_outline),
              label: Text(l10n.settingsViewFaqButton),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.secondary, foregroundColor: Colors.white),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(rootContext);
                Navigator.pop(dialogContext);

                if (!AppConfig.isFeatureEnabled('supportTickets')) {
                  messenger.showSnackBar(SnackBar(content: Text(l10n.settingsOpeningEmailClientToast)));
                  return;
                }

                await showDialog<bool>(
                  context: rootContext,
                  builder: (_) => const SupportTicketDialog(),
                );
              },
              icon: const Icon(Icons.email),
              label: Text(l10n.settingsContactSupportButton),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  void _showLicensesDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.settingsLicensesDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsLicensesDialogBody,
            style: GoogleFonts.inter(height: 1.5, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  void _showRateAppDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.settingsRateAppDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsRateAppDialogBodyTitle, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(l10n.settingsRateAppDialogBodySubtitle, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.settingsMaybeLaterButton)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.settingsOpeningAppStoreToast))); },
            child: Text(l10n.settingsRateNowButton),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsChangePasswordDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsCurrentPasswordLabel,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsNewPasswordLabel,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsConfirmNewPasswordLabel,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.commonCancel,
              style: GoogleFonts.inter(
                color: Theme.of(dialogContext).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColorUtils.indigoAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.settingsPasswordUpdatedToast)),
              );
            },
            child: Text(l10n.settingsUpdateButton),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.settingsResetAppDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text(l10n.settingsResetAppDialogBody, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
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
              messenger.showSnackBar(SnackBar(content: Text(l10n.settingsAppResetSuccessToast), duration: const Duration(seconds: 3)));
              _restartToOnboarding();
            },
            child: Text(l10n.settingsResetButton),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.settingsDeleteAccountDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          l10n.settingsDeleteAccountDialogBody,
          style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
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
                debugPrint('DesktopSettingsScreen: backend deletion failed: $e');
                messenger.showSnackBar(SnackBar(content: Text(l10n.settingsDeleteAccountBackendFailedToast)));
              }

              await SettingsService.resetApp(
                walletProvider: walletProvider,
                backendApi: BackendApiService(),
                notificationProvider: notificationProvider,
                profileProvider: profileProvider,
              );
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(SnackBar(content: Text(l10n.settingsAccountDeletedToast)));
              _restartToOnboarding();
            },
            child: Text(l10n.settingsDeleteForeverButton),
          ),
        ],
      ),
    );
  }

  void _showDataExportDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.settingsExportDataDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text(l10n.settingsExportDataDialogBody, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.desktopSettingsExportingDataToast)));
            },
            child: Text(l10n.settingsExportButton),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(l10n.settingsClearCacheDialogTitle, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        content: Text(l10n.settingsClearCacheDialogBody, style: GoogleFonts.inter(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor, foregroundColor: Colors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await SettingsService.clearNonCriticalCaches();
              if (!mounted) return;
              navigator.pop();
              messenger.showSnackBar(SnackBar(content: Text(l10n.settingsCacheClearedToast)));
            },
            child: Text(l10n.settingsClearButton),
          ),
        ],
      ),
    );
  }

  void _showResetPermissionFlagsDialog() {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsResetPermissionFlagsDialogTitle,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.settingsResetPermissionFlagsDialogBody,
          style: GoogleFonts.inter(color: Theme.of(dialogContext).colorScheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<ThemeProvider>(dialogContext, listen: false).accentColor,
              foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _resetPermissionFlags();
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(content: Text(l10n.settingsPermissionFlagsResetToast)));
            },
            child: Text(l10n.settingsResetButton),
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
    final l10n = AppLocalizations.of(context)!;
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsPlatformFeaturesSectionTitle,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.desktopSettingsPlatformSubtitle,
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
                                _getCapabilityDisplayName(l10n, capability),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                isAvailable ? l10n.commonAvailable : l10n.commonNotAvailable,
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

  String _getCapabilityDisplayName(AppLocalizations l10n, PlatformCapability capability) {
    switch (capability) {
      case PlatformCapability.camera:
        return l10n.settingsCapabilityCamera;
      case PlatformCapability.ar:
        return l10n.settingsCapabilityAr;
      case PlatformCapability.nfc:
        return l10n.settingsCapabilityNfc;
      case PlatformCapability.gps:
        return l10n.settingsCapabilityGps;
      case PlatformCapability.biometrics:
        return l10n.settingsCapabilityBiometrics;
      case PlatformCapability.notifications:
        return l10n.settingsCapabilityNotifications;
      case PlatformCapability.fileSystem:
        return l10n.settingsCapabilityFileSystem;
      case PlatformCapability.bluetooth:
        return l10n.settingsCapabilityBluetooth;
      case PlatformCapability.vibration:
        return l10n.settingsCapabilityVibration;
      case PlatformCapability.orientation:
        return l10n.settingsCapabilityOrientation;
      case PlatformCapability.background:
        return l10n.settingsCapabilityBackground;
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    if (value) {
      final granted = await PushNotificationService().requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() => _pushNotifications = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.settingsEnableNotificationsInSystemToast)),
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
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    if (value) {
      final canUse = await walletProvider.canUseBiometrics();
      if (!canUse) {
        if (mounted) {
          setState(() => _biometricAuth = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.settingsBiometricUnavailableToast)),
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
            SnackBar(content: Text(l10n.settingsBiometricFailedToast)),
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsLogoutDialogTitle,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.settingsLogoutDialogBody,
          style: GoogleFonts.inter(color: Theme.of(dialogContext).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.commonCancel,
              style: GoogleFonts.inter(color: Theme.of(dialogContext).colorScheme.outline),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.settingsLogoutButton),
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsDangerZoneSectionTitle,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.desktopSettingsDangerZoneSubtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSettingsRow(
              l10n.settingsClearCacheTileTitle,
              l10n.settingsClearCacheTileSubtitle,
              Icons.delete_outline,
              isDestructive: true,
              onTap: _showClearCacheDialog,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsRow(
              l10n.settingsResetPermissionFlagsTileTitle,
              l10n.settingsResetPermissionFlagsTileSubtitle,
              Icons.location_off,
              isDestructive: true,
              onTap: _showResetPermissionFlagsDialog,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsRow(
              l10n.settingsDataExportTileTitle,
              l10n.settingsDataExportTileSubtitle,
              Icons.download,
              isDestructive: true,
              onTap: _showDataExportDialog,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsRow(
              l10n.settingsResetAppTileTitle,
              l10n.settingsResetAppTileSubtitle,
              Icons.refresh,
              isDestructive: true,
              onTap: _showResetDialog,
            ),
            const SizedBox(height: 12),
            
            _buildSettingsRow(
              l10n.settingsDeleteAccountTileTitle,
              l10n.settingsDeleteAccountTileSubtitle,
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
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsAppearanceSectionTitle,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.desktopSettingsAppearanceSubtitle,
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
                  l10n.settingsThemeModeTitle,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildThemeModeOption(l10n.settingsThemeModeLight, Icons.light_mode, !themeProvider.isDarkMode && !themeProvider.isSystemMode, () {
                      themeProvider.setThemeMode(ThemeMode.light);
                    }),
                    const SizedBox(width: 12),
                    _buildThemeModeOption(l10n.settingsThemeModeDark, Icons.dark_mode, themeProvider.isDarkMode && !themeProvider.isSystemMode, () {
                      themeProvider.setThemeMode(ThemeMode.dark);
                    }),
                    const SizedBox(width: 12),
                    _buildThemeModeOption(l10n.settingsThemeModeSystem, Icons.settings_suggest, themeProvider.isSystemMode, () {
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
                  l10n.settingsAccentColorTitle,
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

          const SizedBox(height: 24),

          DesktopCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsLanguageTitle,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.settingsLanguageDescription,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: localeProvider.languageCode,
                    items: [
                      DropdownMenuItem(
                        value: 'sl',
                        child: Text(l10n.languageSlovenian),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(l10n.languageEnglish),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      unawaited(localeProvider.setLanguageCode(value));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    final themeColor = scheme.tertiary;

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
                  ? themeColor.withValues(alpha: 0.1)
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? themeColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? themeColor
                      : scheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? themeColor
                        : scheme.onSurface,
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.permissionsNotificationsTitle,
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
                  l10n.settingsPushNotificationsTitle,
                  l10n.settingsPushNotificationsSubtitle,
                  _pushNotifications,
                  saveAfterToggle: false,
                  onChanged: (value) {
                    setState(() => _pushNotifications = value);
                    _togglePushNotifications(value);
                  },
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsEmailNotificationsTitle,
                  l10n.settingsEmailNotificationsSubtitle,
                  _emailNotifications,
                  onChanged: (value) => setState(() => _emailNotifications = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsMarketingEmailsTitle,
                  l10n.settingsMarketingEmailsSubtitle,
                  _marketingEmails,
                  onChanged: (value) => setState(() => _marketingEmails = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsLoginNotificationsTitle,
                  l10n.settingsLoginNotificationsSubtitle,
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
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = Provider.of<ProfileProvider>(context);
    final prefs = profileProvider.preferences;
    final bool privateProfile = prefs.privacy.toLowerCase() == 'private';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsPrivacySettingsTileTitle,
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
                  l10n.settingsPrivateProfileTitle,
                  l10n.settingsPrivateProfileSubtitle,
                  privateProfile,
                  saveAfterToggle: false,
                  onChanged: (value) => profileProvider.updatePreferences(privateProfile: value),
                  switchKey: const Key('desktop_settings_privacy_private_profile'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsShowActivityStatusTitle,
                  l10n.settingsShowActivityStatusSubtitle,
                  prefs.showActivityStatus,
                  saveAfterToggle: false,
                  onChanged: (value) => profileProvider.updatePreferences(
                    showActivityStatus: value,
                    shareLastVisitedLocation: value ? prefs.shareLastVisitedLocation : false,
                  ),
                  switchKey: const Key('desktop_settings_privacy_show_activity_status'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsShareLastVisitedLocationTitle,
                  l10n.settingsShareLastVisitedLocationSubtitle,
                  prefs.shareLastVisitedLocation,
                  saveAfterToggle: false,
                  onChanged: (value) => profileProvider.updatePreferences(shareLastVisitedLocation: value),
                  enabled: prefs.showActivityStatus,
                  switchKey: const Key('desktop_settings_privacy_share_last_visited_location'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsShowCollectionTitle,
                  l10n.settingsShowCollectionSubtitle,
                  prefs.showCollection,
                  saveAfterToggle: false,
                  onChanged: (value) => profileProvider.updatePreferences(showCollection: value),
                  switchKey: const Key('desktop_settings_privacy_show_collection'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsAllowMessagesTitle,
                  l10n.settingsAllowMessagesSubtitle,
                  prefs.allowMessages,
                  saveAfterToggle: false,
                  onChanged: (value) => profileProvider.updatePreferences(allowMessages: value),
                  switchKey: const Key('desktop_settings_privacy_allow_messages'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.desktopSettingsShowFriendsTitle,
                  l10n.desktopSettingsShowFriendsSubtitle,
                  _showFriends,
                  onChanged: (value) => setState(() => _showFriends = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.desktopSettingsShowAchievementsTitle,
                  l10n.desktopSettingsShowAchievementsSubtitle,
                  _showAchievements,
                  onChanged: (value) => setState(() => _showAchievements = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsAnalyticsTileTitle,
                  l10n.settingsAnalyticsTileSubtitle,
                  _analytics,
                  onChanged: (value) => setState(() => _analytics = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsCrashReportingTileTitle,
                  l10n.settingsCrashReportingTileSubtitle,
                  _crashReporting,
                  onChanged: (value) => setState(() => _crashReporting = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsSkipOnboardingTileTitle,
                  l10n.settingsSkipOnboardingTileSubtitle,
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsSecuritySettingsDialogTitle,
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
                  l10n.settingsChangePasswordTileTitle,
                  l10n.settingsChangePasswordTileSubtitle,
                  Icons.lock_outline,
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsTwoFactorTitle,
                  l10n.settingsTwoFactorSubtitle,
                  _twoFactorAuth,
                  onChanged: (value) => setState(() => _twoFactorAuth = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsBiometricTileTitle,
                  l10n.settingsBiometricTileSubtitle,
                  _biometricAuth,
                  saveAfterToggle: false,
                  onChanged: (value) {
                    setState(() => _biometricAuth = value);
                    _toggleBiometric(value);
                  },
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsSessionTimeoutTitle,
                  l10n.settingsSessionTimeoutSubtitle,
                  _sessionTimeout,
                  onChanged: (value) => setState(() => _sessionTimeout = value),
                ),
                const Divider(height: 32),
                _buildAutoLockDropdown(),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsLoginNotificationsTitle,
                  l10n.settingsLoginNotificationsSubtitle,
                  _loginNotifications,
                  onChanged: (value) => setState(() => _loginNotifications = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsPrivacyModeTileTitle,
                  l10n.settingsPrivacyModeTileSubtitle,
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
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.desktopSettingsAchievementsTitle,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.desktopSettingsAchievementsSubtitle,
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
                  child: _buildStatItem(l10n.desktopSettingsAchievementsStatArtworksDiscovered, '12', Icons.image),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: _buildStatItem(l10n.desktopSettingsAchievementsStatArViews, '28', Icons.view_in_ar),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: _buildStatItem(l10n.desktopSettingsAchievementsStatEventsAttended, '5', Icons.event),
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: _buildStatItem(l10n.desktopSettingsAchievementsStatKub8PointsEarned, '150', Icons.token),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.userProfileAchievementsTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildAchievementCard(
            l10n.desktopSettingsAchievementFirstDiscoveryTitle,
            l10n.desktopSettingsAchievementFirstDiscoveryDescription,
            Icons.explore,
            isUnlocked: true,
            reward: 10,
          ),
          const SizedBox(height: 12),
          _buildAchievementCard(
            l10n.desktopSettingsAchievementArtCollectorTitle,
            l10n.desktopSettingsAchievementArtCollectorDescription,
            Icons.collections,
            isUnlocked: true,
            reward: 25,
          ),
          const SizedBox(height: 12),
          _buildAchievementCard(
            l10n.desktopSettingsAchievementCommunityMemberTitle,
            l10n.desktopSettingsAchievementCommunityMemberDescription,
            Icons.groups,
            isUnlocked: false,
            progress: 2,
            total: 3,
            reward: 50,
          ),
          const SizedBox(height: 12),
          _buildAchievementCard(
            l10n.desktopSettingsAchievementEventExplorerTitle,
            l10n.desktopSettingsAchievementEventExplorerDescription,
            Icons.event_available,
            isUnlocked: false,
            progress: 5,
            total: 5,
            reward: 75,
          ),
          const SizedBox(height: 12),
          _buildAchievementCard(
            l10n.desktopSettingsAchievementNftCreatorTitle,
            l10n.desktopSettingsAchievementNftCreatorDescription,
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
    final scheme = Theme.of(context).colorScheme;
    final achievementColor = Colors.amber;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? achievementColor.withValues(alpha: 0.5)
              : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? achievementColor.withValues(alpha: 0.2)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 28,
              color: isUnlocked
                  ? achievementColor
                  : scheme.onSurface.withValues(alpha: 0.4),
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
                        color: scheme.onSurface,
                      ),
                    ),
                    if (isUnlocked) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: achievementColor,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (!isUnlocked && progress != null && total != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress / total,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(achievementColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$progress / $total',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.5),
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
                  ? achievementColor.withValues(alpha: 0.2)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.token,
                  size: 16,
                  color: isUnlocked
                      ? achievementColor
                      : scheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '+$reward',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? achievementColor
                        : scheme.onSurface.withValues(alpha: 0.5),
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
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.desktopSettingsHelpSupportTitle,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.desktopSettingsHelpSupportSubtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          _buildSettingsRow(
            l10n.desktopSettingsFaqTileTitle,
            l10n.desktopSettingsFaqTileSubtitle,
            Icons.help_outline,
            onTap: _showSupportDialog,
          ),
          const SizedBox(height: 12),
          _buildSettingsRow(
            l10n.settingsContactSupportButton,
            l10n.desktopSettingsContactSupportTileSubtitle,
            Icons.email_outlined,
            onTap: _showSupportDialog,
          ),
          const SizedBox(height: 12),
          _buildSettingsRow(
            l10n.desktopSettingsReportBugTileTitle,
            l10n.desktopSettingsReportBugTileSubtitle,
            Icons.bug_report_outlined,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.desktopSettingsOpeningBugReportToast)),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAboutSettings() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsAboutSectionTitle,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.desktopSettingsAboutSubtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          
          // Version Info
          _buildSettingsRow(
            l10n.settingsAboutVersionTileTitle,
            AppInfo.version,
            Icons.app_registration,
            onTap: _showVersionDialog,
          ),
          const SizedBox(height: 12),
          
          // Features Section
          Text(
            l10n.desktopSettingsFeaturesSectionTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildFeatureItem(Icons.view_in_ar, l10n.desktopSettingsFeatureArDiscoveryTitle, l10n.desktopSettingsFeatureArDiscoveryDescription),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.account_balance_wallet, l10n.desktopSettingsFeatureWeb3IntegrationTitle, l10n.desktopSettingsFeatureWeb3IntegrationDescription),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.auto_awesome, l10n.desktopSettingsFeatureNftMintingTitle, l10n.desktopSettingsFeatureNftMintingDescription),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.groups, l10n.desktopSettingsFeatureCommunityTitle, l10n.desktopSettingsFeatureCommunityDescription),
          const SizedBox(height: 16),
          _buildFeatureItem(Icons.museum, l10n.desktopSettingsFeatureInstitutionsTitle, l10n.desktopSettingsFeatureInstitutionsDescription),
          
          const SizedBox(height: 32),
          
          // Legal Links
          Text(
            l10n.desktopSettingsLegalSectionTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSettingsRow(
            l10n.settingsAboutTermsTileTitle,
            l10n.settingsAboutTermsTileSubtitle,
            Icons.description,
            onTap: _showTermsDialog,
          ),
          const SizedBox(height: 12),
          
          _buildSettingsRow(
            l10n.settingsAboutPrivacyTileTitle,
            l10n.settingsAboutPrivacyTileSubtitle,
            Icons.privacy_tip,
            onTap: _showPrivacyPolicyDialog,
          ),
          const SizedBox(height: 12),
          
          _buildSettingsRow(
            l10n.settingsAboutLicensesTileTitle,
            l10n.settingsAboutLicensesTileSubtitle,
            Icons.code,
            onTap: _showLicensesDialog,
          ),
          
          const SizedBox(height: 32),
          
          // Support Section
          Text(
            l10n.settingsSupportDialogTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSettingsRow(
            l10n.settingsAboutSupportTileTitle,
            l10n.settingsAboutSupportTileSubtitle,
            Icons.help,
            onTap: _showSupportDialog,
          ),
          const SizedBox(height: 12),
          
          _buildSettingsRow(
            l10n.settingsAboutRateTileTitle,
            l10n.settingsAboutRateTileSubtitle,
            Icons.star,
            onTap: _showRateAppDialog,
          ),
          
          const SizedBox(height: 32),
          
          // Copyright
          Center(
            child: Text(
              '© 2025 kubus • ${l10n.settingsAllRightsReserved}',
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
    final errorColor = Theme.of(context).colorScheme.error;
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
                      ? errorColor.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? errorColor
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
                            ? errorColor
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
    bool enabled = true,
    Key? switchKey,
  }) {
    final displayedValue = enabled ? initialValue : false;
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
          key: switchKey,
          value: displayedValue,
          onChanged: enabled ? (value) {
            onChanged?.call(value);
            if (saveAfterToggle) {
              _saveSettings();
            }
          } : null,
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
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final options = <Map<String, dynamic>>[
      {'storedLabel': '10 seconds', 'displayLabel': l10n.settingsAutoLock10Seconds, 'seconds': 10},
      {'storedLabel': '30 seconds', 'displayLabel': l10n.settingsAutoLock30Seconds, 'seconds': 30},
      {'storedLabel': '1 minute', 'displayLabel': l10n.settingsAutoLock1Minute, 'seconds': 60},
      {'storedLabel': '5 minutes', 'displayLabel': l10n.settingsAutoLock5Minutes, 'seconds': 5 * 60},
      {'storedLabel': '15 minutes', 'displayLabel': l10n.settingsAutoLock15Minutes, 'seconds': 15 * 60},
      {'storedLabel': '30 minutes', 'displayLabel': l10n.settingsAutoLock30Minutes, 'seconds': 30 * 60},
      {'storedLabel': '1 hour', 'displayLabel': l10n.settingsAutoLock1Hour, 'seconds': 60 * 60},
      {'storedLabel': '3 hours', 'displayLabel': l10n.settingsAutoLock3Hours, 'seconds': 3 * 60 * 60},
      {'storedLabel': '6 hours', 'displayLabel': l10n.settingsAutoLock6Hours, 'seconds': 6 * 60 * 60},
      {'storedLabel': '12 hours', 'displayLabel': l10n.settingsAutoLock12Hours, 'seconds': 12 * 60 * 60},
      {'storedLabel': '1 day', 'displayLabel': l10n.settingsAutoLock1Day, 'seconds': 24 * 60 * 60},
      {'storedLabel': 'Never', 'displayLabel': l10n.settingsAutoLockNever, 'seconds': 0},
    ];

    String displayLabelForStored(String storedLabel) {
      final match = options.cast<Map<String, dynamic>?>().firstWhere(
            (opt) => opt?['storedLabel'] == storedLabel,
            orElse: () => null,
          );
      return (match?['displayLabel'] as String?) ?? storedLabel;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        Icons.lock_clock,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        l10n.settingsAutoLockTimeTitle,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        displayLabelForStored(_autoLockTime),
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
                value: opt['storedLabel'] as String,
                child: Text(opt['displayLabel'] as String),
              ),
            )
            .toList(),
        onChanged: (value) async {
          if (value == null) return;
          final seconds =
              options.firstWhere((opt) => opt['storedLabel'] == value)['seconds'] as int;
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
