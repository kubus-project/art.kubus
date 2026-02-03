import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/themeprovider.dart';
import '../utils/app_color_utils.dart';
import '../providers/notification_provider.dart';
import '../providers/web3provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/platform_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/security_gate_provider.dart';
import '../providers/email_preferences_provider.dart';
import '../models/wallet.dart';
import '../services/backend_api_service.dart';
import '../services/push_notification_service.dart';
import '../services/settings_service.dart';
import '../widgets/platform_aware_widgets.dart';
import '../widgets/glass_components.dart';
import 'onboarding/onboarding_screen.dart';
import 'web3/wallet/wallet_home.dart' as web3_wallet;
import 'web3/wallet/connectwallet_screen.dart';
import 'onboarding_reset_screen.dart';
import 'community/profile_edit_screen.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/empty_state_card.dart';
import '../widgets/support/support_ticket_dialog.dart';
import 'web3/wallet/mnemonic_reveal_screen.dart';
import '../utils/app_animations.dart';
import '../../config/config.dart';
import '../utils/map_performance_debug.dart';
import '../providers/locale_provider.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

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

  List<_ProfileVisibilityOption> _profileVisibilityOptions(
      AppLocalizations l10n) {
    return [
      _ProfileVisibilityOption(
        value: 'Public',
        label: l10n.settingsProfileVisibilityPublicLabel,
        description: l10n.settingsProfileVisibilityPublicDescription,
      ),
      _ProfileVisibilityOption(
        value: 'Private',
        label: l10n.settingsProfileVisibilityPrivateLabel,
        description: l10n.settingsProfileVisibilityPrivateDescription,
      ),
      _ProfileVisibilityOption(
        value: 'Friends Only',
        label: l10n.settingsProfileVisibilityFriendsOnlyLabel,
        description: l10n.settingsProfileVisibilityFriendsOnlyDescription,
      ),
    ];
  }

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
  bool _requirePin = false;
  bool _biometricAuth = false;
  bool _biometricsDeclined = false;
  bool _useBiometricsOnUnlock = true;
  bool _privacyMode = false;
  bool _hasPin = false;
  bool _biometricsSupported = false;

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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    _buildAppBar(l10n),
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildUserSection(l10n),
                          const SizedBox(height: 32),
                          _buildThemeSection(l10n),
                          const SizedBox(height: 24),
                          _buildLanguageSection(l10n),
                          const SizedBox(height: 24),
                          _buildPlatformCapabilitiesSection(l10n),
                          const SizedBox(height: 24),
                          _buildProfileSection(l10n),
                          const SizedBox(height: 24),
                          _buildWalletSection(l10n),
                          const SizedBox(height: 24),
                          _buildSecuritySection(l10n),
                          const SizedBox(height: 24),
                          _buildPrivacySection(l10n),
                          const SizedBox(height: 24),
                          _buildAboutSection(l10n),
                          const SizedBox(height: 24),
                          _buildDangerZone(l10n),
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

  Widget _buildAppBar(AppLocalizations l10n) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        l10n.settingsTitle,
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

  Widget _buildUserSection(AppLocalizations l10n) {
    final web3Provider = Provider.of<Web3Provider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final scheme = Theme.of(context).colorScheme;
    final headerColor = scheme.secondary;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            headerColor,
            headerColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: 0.3),
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
                      profileProvider.currentUser?.displayName ??
                          l10n.settingsGuestUserName,
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
                        l10n.settingsNoWalletConnected,
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
                        .first
                        .balance
                    : 0.0;

                // Get SOL balance
                final solBalance = walletProvider.tokens
                        .where((token) => token.symbol.toUpperCase() == 'SOL')
                        .isNotEmpty
                    ? walletProvider.tokens
                        .where((token) => token.symbol.toUpperCase() == 'SOL')
                        .first
                        .balance
                    : 0.0;

                return Row(
                  children: [
                    Expanded(
                      child: _buildBalanceCard(
                          'KUB8', kub8Balance.toStringAsFixed(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildBalanceCard(
                          'SOL', solBalance.toStringAsFixed(3)),
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
          MaterialPageRoute(
              builder: (context) => const web3_wallet.WalletHome()),
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

  Widget _buildThemeSection(AppLocalizations l10n) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;

    return _buildSection(
      l10n.settingsAppearanceSectionTitle,
      Icons.palette,
      [
        _buildThemeModeTile(l10n, themeProvider),
        const SizedBox(height: 12),
        _buildAccentColorTile(l10n, themeProvider),
      ],
      sectionColor: scheme.tertiary,
    );
  }

  Widget _buildLanguageSection(AppLocalizations l10n) {
    final localeProvider = context.watch<LocaleProvider>();

    return _buildSection(
      l10n.settingsLanguageTitle,
      Icons.language,
      [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
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
    );
  }

  Widget _buildThemeModeTile(
      AppLocalizations l10n, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6,
                color: scheme.tertiary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.settingsThemeModeTitle,
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
                      l10n.settingsThemeModeLight,
                      Icons.light_mode,
                      ThemeMode.light,
                      themeProvider,
                      isSmallScreen: true,
                    ),
                    const SizedBox(height: 8),
                    _buildThemeOption(
                      l10n.settingsThemeModeDark,
                      Icons.dark_mode,
                      ThemeMode.dark,
                      themeProvider,
                      isSmallScreen: true,
                    ),
                    const SizedBox(height: 8),
                    _buildThemeOption(
                      l10n.settingsThemeModeSystem,
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
                        l10n.settingsThemeModeLight,
                        Icons.light_mode,
                        ThemeMode.light,
                        themeProvider,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOption(
                        l10n.settingsThemeModeDark,
                        Icons.dark_mode,
                        ThemeMode.dark,
                        themeProvider,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeOption(
                        l10n.settingsThemeModeSystem,
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

  Widget _buildThemeOption(
      String label, IconData icon, ThemeMode mode, ThemeProvider themeProvider,
      {bool isSmallScreen = false}) {
    final isSelected = themeProvider.themeMode == mode;
    final scheme = Theme.of(context).colorScheme;
    final themeColor = scheme.tertiary;

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
              ? themeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? themeColor : scheme.outline,
          ),
        ),
        child: isSmallScreen
            ? Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? themeColor
                        : scheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? themeColor
                          : scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? themeColor
                        : scheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? themeColor
                          : scheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildAccentColorTile(
      AppLocalizations l10n, ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.color_lens,
                color: scheme.tertiary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.settingsAccentColorTitle,
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
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onPrimary,
                            width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCapabilitiesSection(AppLocalizations l10n) {
    return Consumer<PlatformProvider>(
      builder: (context, platformProvider, child) {
        return _buildSection(
          l10n.settingsPlatformFeaturesSectionTitle,
          Icons.devices,
          [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        platformProvider.isMobile
                            ? Icons.phone_android
                            : platformProvider.isDesktop
                                ? Icons.computer
                                : Icons.web,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.settingsRunningOnPlatform(
                          platformProvider.currentPlatform
                              .toString()
                              .split('.')
                              .last,
                        ),
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
                    l10n.settingsAvailableFeaturesLabel,
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
                            color: entry.value
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).colorScheme.error,
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getCapabilityDisplayName(l10n, entry.key),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: entry.value
                                    ? Colors.white
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
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
                l10n.settingsDeveloperToolsSectionTitle,
                Icons.developer_mode,
                [
                  _buildSettingsTile(
                    'Map performance debug',
                    'Log map timers/subscriptions/fetches (debug-only)',
                    Icons.speed,
                    trailing: ValueListenableBuilder<bool>(
                      valueListenable: MapPerformanceDebug.enabled,
                      builder: (context, enabled, _) => Switch(
                        value: enabled,
                        onChanged: (value) =>
                            MapPerformanceDebug.setEnabled(value),
                      ),
                    ),
                    onTap: () => MapPerformanceDebug.toggle(),
                    tileKey: const Key('settings_map_perf_debug_toggle'),
                  ),
                  _buildSettingsTile(
                    l10n.settingsDeveloperResetOnboardingTitle,
                    l10n.settingsDeveloperResetOnboardingSubtitle,
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
                    l10n.settingsDeveloperClearQuickActionsTitle,
                    l10n.settingsDeveloperClearQuickActionsSubtitle,
                    Icons.clear_all,
                    onTap: () async {
                      final navigationProvider =
                          Provider.of<NavigationProvider>(context,
                              listen: false);
                      await navigationProvider.clearVisitData();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showKubusSnackBar(
                        SnackBar(
                            content: Text(l10n
                                .settingsDeveloperQuickActionsClearedToast)),
                      );
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

  String _getCapabilityDisplayName(
      AppLocalizations l10n, PlatformCapability capability) {
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

  Widget _buildProfileSection(AppLocalizations l10n) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final emailPreferencesProvider = context.watch<EmailPreferencesProvider>();
    if (emailPreferencesProvider.canManage &&
        !emailPreferencesProvider.initialized &&
        !emailPreferencesProvider.isLoading) {
      unawaited(emailPreferencesProvider.initialize());
    }
    final artistRole = profileProvider.currentUser?.isArtist ?? false;
    final institutionRole = profileProvider.currentUser?.isInstitution ?? false;
    final roleSummary = l10n.settingsRoleSummary(
      artistRole ? l10n.commonOn : l10n.commonOff,
      institutionRole ? l10n.commonOn : l10n.commonOff,
    );

    final emailNotificationsState = emailPreferencesProvider.canManage
        ? (emailPreferencesProvider.preferences.productUpdates
            ? l10n.commonOn
            : l10n.commonOff)
        : (_emailNotifications ? l10n.commonOn : l10n.commonOff);
    return _buildSection(
      l10n.settingsProfileSectionTitle,
      Icons.person_outline,
      [
        _buildSettingsTile(
          l10n.settingsProfileVisibilityTileTitle,
          l10n.settingsCurrentlyValue(_profileVisibility),
          Icons.visibility,
          onTap: () {
            _showProfileVisibilityDialog();
          },
        ),
        _buildSettingsTile(
          l10n.settingsPrivacySettingsTileTitle,
          l10n.settingsPrivacySummary(
            _dataCollection ? l10n.commonEnabled : l10n.commonDisabled,
            _personalizedAds ? l10n.commonEnabled : l10n.commonDisabled,
          ),
          Icons.privacy_tip,
          tileKey: const Key('settings_tile_privacy_settings'),
          onTap: () {
            _showPrivacySettingsDialog();
          },
        ),
        _buildSettingsTile(
          l10n.settingsSecuritySettingsTileTitle,
          l10n.settingsSecuritySummary(
            _twoFactorAuth ? l10n.commonEnabled : l10n.commonDisabled,
            _autoLockTime,
          ),
          Icons.security,
          onTap: () {
            _showSecuritySettingsDialog();
          },
        ),
        _buildSettingsTile(
          l10n.settingsEditProfileTileTitle,
          l10n.settingsEditProfileTileSubtitle,
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
              final profileProvider =
                  Provider.of<ProfileProvider>(context, listen: false);
              final web3Provider =
                  Provider.of<Web3Provider>(context, listen: false);
              if (web3Provider.isConnected &&
                  web3Provider.walletAddress.isNotEmpty) {
                await profileProvider.loadProfile(web3Provider.walletAddress);
              }
            }
          },
        ),
        _buildSettingsTile(
          l10n.settingsAccountManagementTileTitle,
          l10n.settingsAccountSummary(
            _accountType,
            emailNotificationsState,
          ),
          Icons.manage_accounts,
          onTap: () {
            _showAccountManagementDialog();
          },
        ),
        _buildSettingsTile(
          l10n.settingsRoleSimulationTileTitle,
          roleSummary,
          Icons.workspace_premium,
          onTap: _showRoleSimulationSheet,
        ),
      ],
    );
  }

  void _showRoleSimulationSheet() {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final initialArtist = profileProvider.currentUser?.isArtist ?? false;
    final initialInstitution =
        profileProvider.currentUser?.isInstitution ?? false;

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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
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
                  l10n.settingsRoleSimulationSheetTitle,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.settingsRoleSimulationSheetSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(l10n.settingsRoleArtistTitle,
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: Text(l10n.settingsRoleArtistSubtitle,
                      style: GoogleFonts.inter(fontSize: 13)),
                  value: artist,
                  activeThumbColor: Theme.of(context).colorScheme.secondary,
                  onChanged: (val) {
                    setState(() => artist = val);
                    profileProvider.setRoleFlags(
                        isArtist: val, isInstitution: institution);
                  },
                ),
                SwitchListTile(
                  title: Text(l10n.settingsRoleInstitutionTitle,
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  subtitle: Text(l10n.settingsRoleInstitutionSubtitle,
                      style: GoogleFonts.inter(fontSize: 13)),
                  value: institution,
                  activeThumbColor: Theme.of(context).colorScheme.secondary,
                  onChanged: (val) {
                    setState(() => institution = val);
                    profileProvider.setRoleFlags(
                        isArtist: artist, isInstitution: val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.commonClose,
                          style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.outline)),
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

  Widget _buildWalletSection(AppLocalizations l10n) {
    final web3Provider = Provider.of<Web3Provider>(context);
    final scheme = Theme.of(context).colorScheme;
    return _buildSection(
      l10n.settingsWalletSectionTitle,
      Icons.account_balance_wallet,
      [
        _buildSettingsTile(
          l10n.settingsWalletConnectionTileTitle,
          web3Provider.isConnected
              ? l10n.settingsWalletConnectionConnected
              : l10n.settingsWalletConnectionNotConnected,
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
              ? Icon(Icons.check_circle, color: AppColorUtils.amberAccent)
              : Icon(Icons.error_outline, color: scheme.error),
        ),
        _buildSettingsTile(
          l10n.settingsNetworkTileTitle,
          l10n.settingsCurrentNetworkValue(_networkSelection),
          Icons.network_check,
          onTap: () => _showNetworkDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsTransactionHistoryTileTitle,
          l10n.settingsTransactionHistoryTileSubtitle,
          Icons.history,
          onTap: () => _showTransactionHistoryDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsBackupSettingsTileTitle,
          l10n.settingsAutoBackupSummary(
              _autoBackup ? l10n.commonEnabled : l10n.commonDisabled),
          Icons.backup,
          onTap: () => _showBackupDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsExportRecoveryPhraseTileTitle,
          l10n.settingsExportRecoveryPhraseTileSubtitle,
          Icons.warning_amber_rounded,
          onTap: _showRecoveryWarningDialog,
        ),
        _buildSettingsTile(
          l10n.settingsImportWalletTileTitle,
          l10n.settingsImportWalletTileSubtitle,
          Icons.upload_file,
          onTap: _showImportWarningDialog,
        ),
      ],
      sectionColor: AppColorUtils.amberAccent,
    );
  }

  Widget _buildSecuritySection(AppLocalizations l10n) {
    final canShowBiometricsToggle = _hasPin && _biometricsSupported;
    return _buildSection(
      l10n.settingsSecurityPrivacySectionTitle,
      Icons.security,
      [
        _buildSettingsTile(
          l10n.settingsSetPinTileTitle,
          l10n.settingsSetPinTileSubtitle,
          Icons.pin,
          trailing: Switch(
            value: _requirePin,
            onChanged: (value) {
              unawaited(_toggleRequirePin(value));
            },
            activeThumbColor: AppColorUtils.indigoAccent,
          ),
          onTap: () {
            unawaited(_showSetPinDialog());
          },
        ),
        if (canShowBiometricsToggle)
          _buildSettingsTile(
            l10n.settingsBiometricTileTitle,
            l10n.settingsBiometricTileSubtitle,
            Icons.fingerprint,
            trailing: Switch(
              value: _biometricAuth,
              onChanged: (value) {
                unawaited(_toggleBiometric(value));
              },
              activeThumbColor: AppColorUtils.indigoAccent,
            ),
          )
        else if (_hasPin && !_biometricsSupported)
          _buildSettingsTile(
            l10n.settingsBiometricTileTitle,
            l10n.settingsBiometricUnavailableToast,
            Icons.fingerprint,
          ),
        if (_biometricAuth && canShowBiometricsToggle)
          _buildSettingsTile(
            l10n.settingsUseBiometricsOnUnlockTitle,
            l10n.settingsUseBiometricsOnUnlockSubtitle,
            Icons.lock_outline,
            trailing: Switch(
              value: _useBiometricsOnUnlock,
              onChanged: (value) {
                final gate = context.read<SecurityGateProvider>();
                setState(() => _useBiometricsOnUnlock = value);
                unawaited(
                    _saveAllSettings().then((_) => gate.reloadSettings()));
              },
              activeThumbColor: AppColorUtils.indigoAccent,
            ),
          ),
        _buildSettingsTile(
          l10n.settingsAutoLockTileTitle,
          l10n.settingsAutoLockTileSubtitle,
          Icons.lock_clock,
          onTap: () => _showAutoLockDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsPrivacyModeTileTitle,
          l10n.settingsPrivacyModeTileSubtitle,
          Icons.visibility_off,
          trailing: Switch(
            value: _privacyMode,
            onChanged: (value) {
              setState(() {
                _privacyMode = value;
              });
              _saveAllSettings();
            },
            activeThumbColor: AppColorUtils.indigoAccent,
          ),
        ),
        _buildSettingsTile(
          l10n.settingsClearCacheTileTitle,
          l10n.settingsClearCacheTileSubtitle,
          Icons.clear_all,
          onTap: () => _showClearCacheDialog(),
        ),
      ],
      sectionColor: AppColorUtils.indigoAccent,
    );
  }

  Widget _buildPrivacySection(AppLocalizations l10n) {
    return _buildSection(
      l10n.settingsDataAnalyticsSectionTitle,
      Icons.analytics,
      [
        // Mock Data toggle removed - backend controls via USE_MOCK_DATA env variable
        _buildSettingsTile(
          l10n.settingsAnalyticsTileTitle,
          l10n.settingsAnalyticsTileSubtitle,
          Icons.analytics,
          trailing: Switch(
            value: _analytics,
            onChanged: (value) {
              setState(() {
                _analytics = value;
              });
              _saveAllSettings();
            },
            activeThumbColor: AppColorUtils.indigoAccent,
          ),
        ),
        _buildSettingsTile(
          l10n.settingsCrashReportingTileTitle,
          l10n.settingsCrashReportingTileSubtitle,
          Icons.bug_report,
          trailing: Switch(
            value: _crashReporting,
            onChanged: (value) {
              setState(() {
                _crashReporting = value;
              });
              _saveAllSettings();
            },
            activeThumbColor: AppColorUtils.indigoAccent,
          ),
        ),
        _buildSettingsTile(
          l10n.settingsSkipOnboardingTileTitle,
          l10n.settingsSkipOnboardingTileSubtitle,
          Icons.fast_forward,
          trailing: Switch(
            value: _skipOnboardingForReturningUsers,
            onChanged: (value) {
              setState(() {
                _skipOnboardingForReturningUsers = value;
              });
              _saveAllSettings();
            },
            activeThumbColor: AppColorUtils.indigoAccent,
          ),
        ),
        _buildSettingsTile(
          l10n.settingsDataExportTileTitle,
          l10n.settingsDataExportTileSubtitle,
          Icons.download,
          onTap: () => _showDataExportDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsResetPermissionFlagsTileTitle,
          l10n.settingsResetPermissionFlagsTileSubtitle,
          Icons.location_off,
          onTap: () => _showResetPermissionFlagsDialog(),
        ),
      ],
      sectionColor: AppColorUtils.indigoAccent,
    );
  }

  Widget _buildAboutSection(AppLocalizations l10n) {
    return _buildSection(
      l10n.settingsAboutSectionTitle,
      Icons.info,
      [
        _buildSettingsTile(
          l10n.settingsAboutVersionTileTitle,
          AppInfo.version,
          Icons.app_registration,
          onTap: () => _showVersionDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsAboutTermsTileTitle,
          l10n.settingsAboutTermsTileSubtitle,
          Icons.description,
          onTap: () => _showTermsDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsAboutPrivacyTileTitle,
          l10n.settingsAboutPrivacyTileSubtitle,
          Icons.privacy_tip,
          onTap: () => _showPrivacyPolicyDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsAboutSupportTileTitle,
          l10n.settingsAboutSupportTileSubtitle,
          Icons.help,
          onTap: () => _showSupportDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsAboutLicensesTileTitle,
          l10n.settingsAboutLicensesTileSubtitle,
          Icons.code,
          onTap: () => _showLicensesDialog(),
        ),
        _buildSettingsTile(
          l10n.settingsAboutRateTileTitle,
          l10n.settingsAboutRateTileSubtitle,
          Icons.star,
          onTap: () => _showRateAppDialog(),
        ),
      ],
    );
  }

  Widget _buildDangerZone(AppLocalizations l10n) {
    return _buildSection(
      l10n.settingsDangerZoneSectionTitle,
      Icons.warning,
      [
        _buildSettingsTile(
          l10n.settingsLogoutTileTitle,
          l10n.settingsLogoutTileSubtitle,
          Icons.logout,
          onTap: _handleLogout,
          isDestructive: true,
        ),
        _buildSettingsTile(
          l10n.settingsResetAppTileTitle,
          l10n.settingsResetAppTileSubtitle,
          Icons.refresh,
          onTap: () => _showResetDialog(),
          isDestructive: true,
        ),
        _buildSettingsTile(
          l10n.settingsDeleteAccountTileTitle,
          l10n.settingsDeleteAccountTileSubtitle,
          Icons.delete_forever,
          onTap: () => _showDeleteAccountDialog(),
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children,
      {Color? sectionColor}) {
    final scheme = Theme.of(context).colorScheme;
    final color = sectionColor ?? scheme.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: color,
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
    Key? tileKey,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        key: tileKey,
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
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: trailing ??
            (onTap != null
                ? Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  )
                : null),
        onTap: onTap,
      ),
    );
  }

  // Dialog methods
  void _showNetworkDialog() {
    final l10n = AppLocalizations.of(context)!;
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final currentNetwork = web3Provider.currentNetwork.toLowerCase();

    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsSelectNetworkDialogTitle,
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
              l10n.settingsNetworkMainnetDescription,
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
                await _saveAllSettings();
                if (!mounted) return;
                messenger.showKubusSnackBar(
                  SnackBar(
                      content:
                          Text(l10n.settingsSwitchedToNetworkToast('Mainnet'))),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildNetworkOption(
              'Devnet',
              l10n.settingsNetworkDevnetDescription,
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
                await _saveAllSettings();
                if (!mounted) return;
                messenger.showKubusSnackBar(
                  SnackBar(
                      content:
                          Text(l10n.settingsSwitchedToNetworkToast('Devnet'))),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildNetworkOption(
              'Testnet',
              l10n.settingsNetworkTestnetDescription,
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
                await _saveAllSettings();
                if (!mounted) return;
                messenger.showKubusSnackBar(
                  SnackBar(
                      content:
                          Text(l10n.settingsSwitchedToNetworkToast('Testnet'))),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkOption(
      String name, String description, bool isSelected, VoidCallback onTap) {
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
              ? Provider.of<ThemeProvider>(context)
                  .accentColor
                  .withValues(alpha: 0.1)
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
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
    final l10n = AppLocalizations.of(context)!;
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (!web3Provider.isConnected) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.settingsConnectWalletFirstToast)),
      );
      return;
    }

    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
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
              l10n.settingsBackupWalletDialogTitle,
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
              l10n.settingsBackupWalletDialogIntro,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context).colorScheme.error, width: 1),
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
                        l10n.settingsSecurityWarningTitle,
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
                    l10n.settingsSecurityWarningBullets,
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
              l10n.commonCancel,
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
              l10n.commonContinue,
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
    final l10n = AppLocalizations.of(context)!;
    final hasWallet = walletProvider.wallet != null ||
        (walletProvider.currentWalletAddress ?? '').isNotEmpty;
    if (!hasWallet) {
      ScaffoldMessenger.of(context).showKubusSnackBar(SnackBar(
          content: Text(l10n.settingsConnectOrCreateWalletFirstToast)));
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MnemonicRevealScreen()));
  }

  void _showAutoLockDialog() {
    final l10n = AppLocalizations.of(context)!;

    final options = <Map<String, dynamic>>[
      {
        'label': 'Immediately',
        'seconds': -1,
        'display': l10n.settingsAutoLockImmediately
      },
      {
        'label': '10 seconds',
        'seconds': 10,
        'display': l10n.settingsAutoLock10Seconds
      },
      {
        'label': '30 seconds',
        'seconds': 30,
        'display': l10n.settingsAutoLock30Seconds
      },
      {
        'label': '1 minute',
        'seconds': 60,
        'display': l10n.settingsAutoLock1Minute
      },
      {
        'label': '5 minutes',
        'seconds': 5 * 60,
        'display': l10n.settingsAutoLock5Minutes
      },
      {
        'label': '15 minutes',
        'seconds': 15 * 60,
        'display': l10n.settingsAutoLock15Minutes
      },
      {
        'label': '30 minutes',
        'seconds': 30 * 60,
        'display': l10n.settingsAutoLock30Minutes
      },
      {
        'label': '1 hour',
        'seconds': 60 * 60,
        'display': l10n.settingsAutoLock1Hour
      },
      {
        'label': '3 hours',
        'seconds': 3 * 60 * 60,
        'display': l10n.settingsAutoLock3Hours
      },
      {
        'label': '6 hours',
        'seconds': 6 * 60 * 60,
        'display': l10n.settingsAutoLock6Hours
      },
      {
        'label': '12 hours',
        'seconds': 12 * 60 * 60,
        'display': l10n.settingsAutoLock12Hours
      },
      {
        'label': '1 day',
        'seconds': 24 * 60 * 60,
        'display': l10n.settingsAutoLock1Day
      },
      {'label': 'Never', 'seconds': 0, 'display': l10n.settingsAutoLockNever},
    ];

    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsAutoLockTimerDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((opt) {
            final label = opt['label'] as String;
            final displayLabel = opt['display'] as String;
            final isSelected = _autoLockTime == label;
            return ListTile(
              title: Text(
                displayLabel,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check,
                      color: Provider.of<ThemeProvider>(context, listen: false)
                          .accentColor)
                  : null,
              onTap: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final gate = context.read<SecurityGateProvider>();
                setState(() {
                  _autoLockTime = label;
                });
                await _saveAllSettings();
                await gate.reloadSettings();
                if (!mounted) return;
                navigator.pop();
                messenger.showKubusSnackBar(
                  SnackBar(
                      content:
                          Text(l10n.settingsAutoLockSetToToast(displayLabel))),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final gate = context.read<SecurityGateProvider>();
    if (value) {
      final hasPin = await walletProvider.hasPin();
      if (!hasPin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
                content: Text(l10n.settingsConnectOrCreateWalletFirstToast)),
          );
        }
        setState(() => _biometricAuth = false);
        await _saveAllSettings();
        await gate.reloadSettings();
        return;
      }
      final canUse = await walletProvider.canUseBiometrics();
      if (!canUse) {
        if (mounted) {
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(content: Text(l10n.settingsBiometricUnavailableToast)),
          );
        }
        setState(() => _biometricAuth = false);
        await _saveAllSettings();
        await gate.reloadSettings();
        return;
      }
      // Optional: require one successful auth when enabling
      final ok = await walletProvider.authenticateWithBiometrics();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(content: Text(l10n.settingsBiometricFailedToast)),
          );
        }
        setState(() => _biometricAuth = false);
        await _saveAllSettings();
        await gate.reloadSettings();
        return;
      }
    }
    setState(() {
      _biometricAuth = value;
      if (!value) {
        _useBiometricsOnUnlock = true;
      }
      if (value) {
        _biometricsDeclined = false;
      }
    });
    await _saveAllSettings();
    await gate.reloadSettings();
  }

  Future<void> _toggleRequirePin(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final gate = context.read<SecurityGateProvider>();

    if (value) {
      final hasPin = await walletProvider.hasPin();
      if (!hasPin) {
        await _showSetPinDialog();
      }
      final nowHasPin = await walletProvider.hasPin();
      if (!mounted) return;
      if (!nowHasPin) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.settingsPinSetFailedToast)),
        );
        setState(() => _requirePin = false);
        await _saveAllSettings();
        await gate.reloadSettings();
        return;
      }
      setState(() => _requirePin = true);
      await _saveAllSettings();
      await gate.reloadSettings();
      return;
    }

    // Disabling requires a local verification.
    await gate.lock(SecurityLockReason.sensitiveAction);
    final settled = await gate.waitForResolution();
    if (settled == null || !settled.isSuccess) {
      if (!mounted) return;
      setState(() => _requirePin = true);
      return;
    }

    if (!mounted) return;
    setState(() => _requirePin = false);
    await _saveAllSettings();
    await gate.reloadSettings();
  }

  void _showRecoveryWarningDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.shield_outlined,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text(l10n.settingsExportRecoveryPhraseDialogTitle,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsExportRecoveryPhraseDialogBody,
              style: GoogleFonts.inter(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.lock_outline,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.settingsExportRecoveryPhraseDialogConfirm,
                    style: GoogleFonts.inter(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MnemonicRevealScreen()));
            },
            child: Text(l10n.settingsShowPhraseButton),
          ),
        ],
      ),
    );
  }

  void _showImportWarningDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.report_gmailerrorred,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text(l10n.settingsImportWalletDialogTitle,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsImportWalletDialogBody,
              style: GoogleFonts.inter(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.privacy_tip_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.settingsImportWalletDialogConfirm,
                    style: GoogleFonts.inter(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ConnectWallet(initialStep: 1)));
            },
            child: Text(l10n.commonProceed),
          ),
        ],
      ),
    );
  }

  Future<void> _showSetPinDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final gate = context.read<SecurityGateProvider>();
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    await showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsSetPinDialogTitle,
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
                labelText: l10n.commonPinLabel,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.settingsConfirmPinLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel,
                style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.outline)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              // Clearing PIN requires verification. If the user forgot it, they
              // must logout and re-login.
              await gate.lock(SecurityLockReason.sensitiveAction);
              final settled = await gate.waitForResolution();
              if (settled == null || !settled.isSuccess) {
                return;
              }

              await walletProvider.clearPin();
              if (!mounted) return;
              setState(() {
                _requirePin = false;
                _biometricAuth = false;
                _useBiometricsOnUnlock = true;
                _hasPin = false;
              });
              await _saveAllSettings();
              await gate.reloadSettings();
              navigator.pop();
              messenger.showKubusSnackBar(
                  SnackBar(content: Text(l10n.settingsPinClearedToast)));
            },
            child: Text(l10n.settingsClearPinButton,
                style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.error)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    Provider.of<ThemeProvider>(context, listen: false)
                        .accentColor),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final pin = pinController.text.trim();
              final confirm = confirmController.text.trim();
              if (pin.length < 4 || confirm.length < 4) {
                messenger.showKubusSnackBar(
                    SnackBar(content: Text(l10n.settingsPinMinLengthError)));
                return;
              }
              if (pin != confirm) {
                messenger.showKubusSnackBar(
                    SnackBar(content: Text(l10n.settingsPinMismatchError)));
                return;
              }
              try {
                await walletProvider.setPin(pin);
                if (!mounted) return;
                final hasPin = await walletProvider.hasPin();
                final biometricsSupported =
                    await walletProvider.canUseBiometrics();
                if (!mounted) return;
                setState(() {
                  _hasPin = hasPin;
                  _biometricsSupported = biometricsSupported;
                });
                await gate.reloadSettings();
                navigator.pop();
                messenger.showKubusSnackBar(
                    SnackBar(content: Text(l10n.settingsPinSetSuccessToast)));
              } catch (e) {
                if (!mounted) return;
                messenger.showKubusSnackBar(
                    SnackBar(content: Text(l10n.settingsPinSetFailedToast)));
              }
            },
            child: Text(l10n.commonSave,
                style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsClearCacheDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsClearCacheDialogBody,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              await SettingsService.clearNonCriticalCaches();

              if (!mounted) return;
              navigator.pop();
              messenger.showKubusSnackBar(
                SnackBar(content: Text(l10n.settingsCacheClearedToast)),
              );
            },
            child: Text(l10n.settingsClearButton),
          ),
        ],
      ),
    );
  }

  void _showResetPermissionFlagsDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsResetPermissionFlagsDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsResetPermissionFlagsDialogBody,
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel,
                style: GoogleFonts.inter(
                    color: Theme.of(dialogContext).colorScheme.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _resetPermissionFlags();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(content: Text(l10n.settingsPermissionFlagsResetToast)),
              );
            },
            child: Text(l10n.settingsResetButton,
                style: GoogleFonts.inter(
                    color: Theme.of(dialogContext).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPermissionFlags() async {
    try {
      await SettingsService.resetPermissionFlags();
    } catch (e) {
      debugPrint('Failed to reset persisted permission flags: $e');
    }
  }

  void _showDataExportDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsExportDataDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsExportDataDialogBody,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              // Prepare export data
              final prefs = await SharedPreferences.getInstance();
              final exportData = {
                'profile': {
                  'profileVisibility':
                      prefs.getString('profile_visibility') ?? 'Public',
                  'showAchievements': prefs.getBool('showAchievements') ?? true,
                  'showFriends': prefs.getBool('showFriends') ?? true,
                },
                'settings': {
                  'enableAnalytics': prefs.getBool('enableAnalytics') ?? true,
                  'enableCrashReporting':
                      prefs.getBool('enableCrashReporting') ?? true,
                  'skipOnboarding':
                      prefs.getBool('skipOnboardingForReturningUsers') ?? true,
                },
                'exportDate': DateTime.now().toIso8601String(),
              };

              if (!mounted) return;
              navigator.pop();
              messenger.showKubusSnackBar(
                SnackBar(
                    content: Text(
                        l10n.settingsDataExportedToast(exportData.length))),
              );
            },
            child: Text(l10n.settingsExportButton),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsResetAppDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsResetAppDialogBody,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
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
              final walletProvider =
                  Provider.of<WalletProvider>(context, listen: false);
              final notificationProvider =
                  Provider.of<NotificationProvider>(context, listen: false);
              final profileProvider =
                  Provider.of<ProfileProvider>(context, listen: false);
              await SettingsService.resetApp(
                walletProvider: walletProvider,
                backendApi: BackendApiService(),
                notificationProvider: notificationProvider,
                profileProvider: profileProvider,
              );

              if (!mounted) return;
              navigator.pop();
              messenger.showKubusSnackBar(
                SnackBar(
                  content: Text(l10n.settingsAppResetSuccessToast),
                  duration: const Duration(seconds: 3),
                ),
              );
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
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsDeleteAccountDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsDeleteAccountDialogBody,
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Show confirmation dialog â€” ensure mounted before calling showDialog
              if (!mounted) return;
              final dialogNavigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              final confirmed = await showKubusDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) => KubusAlertDialog(
                  backgroundColor: Theme.of(confirmContext).colorScheme.surface,
                  title: Text(
                    l10n.settingsFinalConfirmationTitle,
                    style: GoogleFonts.inter(
                      color: Theme.of(confirmContext).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Text(
                    l10n.settingsDeleteAccountFinalConfirmationBody,
                    style: GoogleFonts.inter(
                      color: Theme.of(confirmContext).colorScheme.onSurface,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child:
                          Text(l10n.commonCancel, style: GoogleFonts.inter()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: Text(
                        l10n.settingsConfirmButton,
                        style: GoogleFonts.inter(
                            color: Theme.of(confirmContext).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              );

              if (!mounted) return;
              if (confirmed == true) {
                final walletProvider =
                    Provider.of<WalletProvider>(context, listen: false);
                final notificationProvider =
                    Provider.of<NotificationProvider>(context, listen: false);
                final profileProvider =
                    Provider.of<ProfileProvider>(context, listen: false);

                // Delete server-side profile/community data (wallet remains functional)
                try {
                  final wallet = walletProvider.currentWalletAddress ??
                      profileProvider.currentUser?.walletAddress;
                  await BackendApiService()
                      .deleteMyAccountData(walletAddress: wallet);
                } catch (e) {
                  debugPrint('SettingsScreen: backend deletion failed: $e');
                  messenger.showKubusSnackBar(
                    SnackBar(
                        content:
                            Text(l10n.settingsDeleteAccountBackendFailedToast)),
                  );
                }

                await SettingsService.resetApp(
                  walletProvider: walletProvider,
                  backendApi: BackendApiService(),
                  notificationProvider: notificationProvider,
                  profileProvider: profileProvider,
                );

                if (!mounted) return;
                dialogNavigator.pop();
                messenger.showKubusSnackBar(
                  SnackBar(
                    content: Text(l10n.settingsAccountDeletedToast),
                    duration: const Duration(seconds: 3),
                  ),
                );
                _restartToOnboarding();
              } else {
                if (!mounted) return;
                dialogNavigator.pop();
              }
            },
            child: Text(l10n.settingsDeleteForeverButton),
          ),
        ],
      ),
    );
  }

  // Save all settings
  Future<void> _saveAllSettings() async {
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
      requirePin: _requirePin,
      biometricAuth: _biometricAuth,
      biometricsDeclined: _biometricsDeclined,
      useBiometricsOnUnlock: _useBiometricsOnUnlock,
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
      case 'immediately':
        return -1;
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

  Future<void> _togglePushNotifications(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    if (value) {
      final granted = await PushNotificationService().requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() => _pushNotifications = false);
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
                content: Text(l10n.settingsEnableNotificationsInSystemToast)),
          );
        }
        await _saveAllSettings();
        return;
      }
      await notificationProvider.initialize(force: true);
    } else {
      await PushNotificationService().cancelAllNotifications();
      notificationProvider.reset();
    }
    if (!mounted) return;
    setState(() => _pushNotifications = value);
    await _saveAllSettings();
  }

  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsLogoutDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsLogoutDialogBody,
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.commonCancel,
              style: GoogleFonts.inter(
                color: Theme.of(dialogContext).colorScheme.outline,
              ),
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
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
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

  // Load all settings
  Future<void> _loadAllSettings() async {
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final settings = await SettingsService.loadSettings(
      fallbackNetwork: web3Provider.currentNetwork.isNotEmpty
          ? web3Provider.currentNetwork
          : null,
    );
    final hasPin = await walletProvider.hasPin();
    final biometricsSupported = await walletProvider.canUseBiometrics();
    if (!mounted) return;

    setState(() {
      _pushNotifications = settings.pushNotifications;
      _emailNotifications = settings.emailNotifications;
      _marketingEmails = settings.marketingEmails;
      _loginNotifications = settings.loginNotifications;

      _dataCollection = settings.dataCollection;
      _personalizedAds = settings.personalizedAds;
      _locationTracking = settings.locationTracking;
      _dataRetention = settings.dataRetention;

      _twoFactorAuth = settings.twoFactorAuth;
      _sessionTimeout = settings.sessionTimeout;
      _autoLockTime = settings.autoLockTime;
      _requirePin = settings.requirePin;
      _biometricAuth = settings.biometricAuth && hasPin && biometricsSupported;
      _biometricsDeclined = settings.biometricsDeclined;
      _useBiometricsOnUnlock = settings.useBiometricsOnUnlock;
      _privacyMode = settings.privacyMode;
      _hasPin = hasPin;
      _biometricsSupported = biometricsSupported;

      _analytics = settings.analytics;
      _crashReporting = settings.crashReporting;
      _skipOnboardingForReturningUsers = settings.skipOnboarding;

      _networkSelection = settings.networkSelection;
      _autoBackup = settings.autoBackup;

      _profileVisibility = settings.profileVisibility;
      _showAchievements = settings.showAchievements;
      _showFriends = settings.showFriends;
      _allowMessages = settings.allowMessages;
      _accountType = settings.accountType;
      _publicProfile = settings.publicProfile;
    });
  }

  Future<void> _saveProfileVisibility(String visibility) async {
    await SettingsService.saveProfileVisibility(visibility);
  }

  // Wallet dialog methods
  void _showTransactionHistoryDialog() {
    final l10n = AppLocalizations.of(context)!;
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);

    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsTransactionHistoryDialogTitle,
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
                      l10n.settingsRecentTransactionsTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
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
                    title: l10n.settingsNoTransactionsTitle,
                    description: l10n.settingsNoTransactionsDescription,
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonClose,
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
    final l10n = AppLocalizations.of(context)!;
    final isIncoming = tx.type == TransactionType.receive;
    final amount = tx.amount;
    final token = tx.token;
    final timestamp = tx.timestamp.toString();
    final from = tx.fromAddress ?? l10n.commonUnknown;
    final to = tx.toAddress ?? l10n.commonUnknown;

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
              color: isIncoming
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIncoming
                      ? l10n.settingsTxReceivedLabel
                      : l10n.settingsTxSentLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  l10n.settingsTxFromToLabel(
                    isIncoming
                        ? l10n.settingsTxFromLabel
                        : l10n.settingsTxToLabel,
                    (isIncoming ? from : to).substring(0, 8),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  timestamp,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
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
              color: isIncoming
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  // About dialog methods
  void _showVersionDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsAppVersionDialogTitle,
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
              l10n.settingsVersionValue(AppInfo.version),
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              l10n.settingsBuildValue(AppInfo.buildNumber),
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Â© 2025 kubus',
              style: GoogleFonts.inter(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            Text(
              l10n.settingsAllRightsReserved,
              style: GoogleFonts.inter(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonClose,
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
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsTermsDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsTermsDialogBody,
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
              l10n.commonClose,
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
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsPrivacyPolicyDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsPrivacyPolicyDialogBody,
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
              l10n.commonClose,
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
    final l10n = AppLocalizations.of(context)!;
    final rootContext = context;
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsSupportDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.settingsSupportDialogBody,
              style: GoogleFonts.inter(
                color: Theme.of(dialogContext).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Provider.of<ThemeProvider>(dialogContext, listen: false)
                        .accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(rootContext).showKubusSnackBar(
                  SnackBar(content: Text(l10n.settingsOpeningFaqToast)),
                );
              },
              icon: const Icon(Icons.help_outline),
              label: Text(l10n.settingsViewFaqButton),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Provider.of<ThemeProvider>(dialogContext, listen: false)
                        .accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(rootContext);
                Navigator.pop(dialogContext);

                if (!AppConfig.isFeatureEnabled('supportTickets')) {
                  messenger.showKubusSnackBar(
                    SnackBar(
                        content: Text(l10n.settingsOpeningEmailClientToast)),
                  );
                  return;
                }

                await showKubusDialog<bool>(
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.commonClose,
              style: GoogleFonts.inter(
                color: Theme.of(dialogContext).colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLicensesDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsLicensesDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsLicensesDialogBody,
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
              l10n.commonClose,
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
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsRateAppDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.settingsRateAppDialogBodyTitle,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsRateAppDialogBodySubtitle,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star,
                    color: Provider.of<ThemeProvider>(context).accentColor,
                    size: 30),
                Icon(Icons.star,
                    color: Provider.of<ThemeProvider>(context).accentColor,
                    size: 30),
                Icon(Icons.star,
                    color: Provider.of<ThemeProvider>(context).accentColor,
                    size: 30),
                Icon(Icons.star,
                    color: Provider.of<ThemeProvider>(context).accentColor,
                    size: 30),
                Icon(Icons.star,
                    color: Provider.of<ThemeProvider>(context).accentColor,
                    size: 30),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.settingsMaybeLaterButton,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(content: Text(l10n.settingsOpeningAppStoreToast)),
              );
            },
            child: Text(l10n.settingsRateNowButton),
          ),
        ],
      ),
    );
  }

  // Helper methods for dialog components
  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool enabled = true,
    Key? tileKey,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: SwitchListTile(
        key: tileKey,
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
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        activeThumbColor:
            Provider.of<ThemeProvider>(context, listen: false).accentColor,
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    Function(String?) onChanged, {
    String Function(String option)? optionLabelBuilder,
  }) {
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
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              child: Text(optionLabelBuilder?.call(option) ?? option),
            );
          }).toList(),
          onChanged: onChanged,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildActionTile(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
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
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
    final l10n = AppLocalizations.of(context)!;
    String selectedVisibility = _profileVisibility;
    final accentColor =
        Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final visibilityOptions = _profileVisibilityOptions(l10n);

    showKubusDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => KubusAlertDialog(
          backgroundColor: Theme.of(innerContext).colorScheme.surface,
          title: Text(
            l10n.settingsProfileVisibilityDialogTitle,
            style: GoogleFonts.inter(
              color: Theme.of(innerContext).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: visibilityOptions
                .map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildVisibilityOptionTile(
                      context: innerContext,
                      option: option,
                      accentColor: accentColor,
                      isSelected: option.value == selectedVisibility,
                      onTap: () => setDialogState(
                          () => selectedVisibility = option.value),
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l10n.commonCancel,
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
                final displayVisibility = visibilityOptions
                    .firstWhere(
                      (opt) => opt.value == selectedVisibility,
                      orElse: () => _ProfileVisibilityOption(
                        value: selectedVisibility,
                        label: selectedVisibility,
                        description: '',
                      ),
                    )
                    .label;
                setState(() {
                  _profileVisibility = selectedVisibility;
                });
                await _saveProfileVisibility(selectedVisibility);
                if (!mounted) return;
                navigator.pop();
                ScaffoldMessenger.of(context).showKubusSnackBar(
                  SnackBar(
                      content: Text(l10n.settingsProfileVisibilitySetToast(
                          displayVisibility))),
                );
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacySettingsDialog() {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final initialPrefs = profileProvider.preferences;

    bool privateProfile = initialPrefs.privacy.toLowerCase() == 'private';
    bool showActivityStatus = initialPrefs.showActivityStatus;
    bool shareLastVisitedLocation = initialPrefs.shareLastVisitedLocation;
    bool showCollection = initialPrefs.showCollection;
    bool allowMessages = initialPrefs.allowMessages;

    showKubusDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => KubusAlertDialog(
          backgroundColor: Theme.of(innerContext).colorScheme.surface,
          title: Text(
            l10n.settingsPrivacySettingsDialogTitle,
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
                    l10n.settingsPrivacyDataCollectionTitle,
                    l10n.settingsPrivacyDataCollectionSubtitle,
                    _dataCollection,
                    (value) => setDialogState(() => _dataCollection = value),
                  ),
                  _buildSwitchTile(
                    l10n.settingsPrivacyPersonalizedAdsTitle,
                    l10n.settingsPrivacyPersonalizedAdsSubtitle,
                    _personalizedAds,
                    (value) => setDialogState(() => _personalizedAds = value),
                  ),
                  _buildSwitchTile(
                    l10n.settingsPrivacyLocationTrackingTitle,
                    l10n.settingsPrivacyLocationTrackingSubtitle,
                    _locationTracking,
                    (value) => setDialogState(() => _locationTracking = value),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownTile(
                    l10n.settingsPrivacyDataRetentionTitle,
                    l10n.settingsPrivacyDataRetentionSubtitle,
                    _dataRetention,
                    ['3 Months', '6 Months', '1 Year', '2 Years', 'Indefinite'],
                    (value) => setDialogState(() => _dataRetention = value!),
                    optionLabelBuilder: (option) {
                      switch (option) {
                        case '3 Months':
                          return l10n.settingsRetention3Months;
                        case '6 Months':
                          return l10n.settingsRetention6Months;
                        case '1 Year':
                          return l10n.settingsRetention1Year;
                        case '2 Years':
                          return l10n.settingsRetention2Years;
                        case 'Indefinite':
                          return l10n.settingsRetentionIndefinite;
                        default:
                          return option;
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.settingsProfilePrivacySectionTitle,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(innerContext).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSwitchTile(
                    l10n.settingsPrivateProfileTitle,
                    l10n.settingsPrivateProfileSubtitle,
                    privateProfile,
                    (value) => setDialogState(() => privateProfile = value),
                    tileKey: const Key('settings_privacy_private_profile'),
                  ),
                  _buildSwitchTile(
                    l10n.settingsShowActivityStatusTitle,
                    l10n.settingsShowActivityStatusSubtitle,
                    showActivityStatus,
                    (value) => setDialogState(() {
                      showActivityStatus = value;
                      if (!value) shareLastVisitedLocation = false;
                    }),
                    tileKey: const Key('settings_privacy_show_activity_status'),
                  ),
                  _buildSwitchTile(
                    l10n.settingsShareLastVisitedLocationTitle,
                    l10n.settingsShareLastVisitedLocationSubtitle,
                    shareLastVisitedLocation,
                    (value) =>
                        setDialogState(() => shareLastVisitedLocation = value),
                    enabled: showActivityStatus,
                    tileKey: const Key(
                        'settings_privacy_share_last_visited_location'),
                  ),
                  _buildSwitchTile(
                    l10n.settingsShowCollectionTitle,
                    l10n.settingsShowCollectionSubtitle,
                    showCollection,
                    (value) => setDialogState(() => showCollection = value),
                    tileKey: const Key('settings_privacy_show_collection'),
                  ),
                  _buildSwitchTile(
                    l10n.settingsAllowMessagesTitle,
                    l10n.settingsAllowMessagesSubtitle,
                    allowMessages,
                    (value) => setDialogState(() => allowMessages = value),
                    tileKey: const Key('settings_privacy_allow_messages'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l10n.commonCancel,
                style: GoogleFonts.inter(
                  color: Theme.of(innerContext).colorScheme.outline,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Provider.of<ThemeProvider>(context, listen: false)
                        .accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                setState(() {
                  _allowMessages = allowMessages;
                  _publicProfile = !privateProfile;
                });
                await profileProvider.updatePreferences(
                  privateProfile: privateProfile,
                  showActivityStatus: showActivityStatus,
                  shareLastVisitedLocation: shareLastVisitedLocation,
                  showCollection: showCollection,
                  allowMessages: allowMessages,
                );
                await _saveAllSettings();
                if (!mounted) return;
                navigator.pop();
                ScaffoldMessenger.of(context).showKubusSnackBar(
                  SnackBar(
                      content: Text(l10n.settingsPrivacySettingsUpdatedToast)),
                );
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  void _showSecuritySettingsDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => KubusAlertDialog(
          backgroundColor: Theme.of(innerContext).colorScheme.surface,
          title: Text(
            l10n.settingsSecuritySettingsDialogTitle,
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
                    l10n.settingsChangePasswordTileTitle,
                    l10n.settingsChangePasswordTileSubtitle,
                    Icons.lock_outline,
                    () {
                      Navigator.pop(innerContext);
                      _showChangePasswordDialog();
                    },
                  ),
                  _buildSwitchTile(
                    l10n.settingsTwoFactorTitle,
                    l10n.settingsTwoFactorSubtitle,
                    _twoFactorAuth,
                    (value) => setDialogState(() => _twoFactorAuth = value),
                  ),
                  _buildSwitchTile(
                    l10n.settingsSessionTimeoutTitle,
                    l10n.settingsSessionTimeoutSubtitle,
                    _sessionTimeout,
                    (value) => setDialogState(() => _sessionTimeout = value),
                  ),
                  _buildDropdownTile(
                    l10n.settingsAutoLockTimeTitle,
                    l10n.settingsAutoLockTimeSubtitle,
                    _autoLockTime,
                    [
                      '1 minute',
                      '5 minutes',
                      '15 minutes',
                      '30 minutes',
                      'Never'
                    ],
                    (value) => setDialogState(() => _autoLockTime = value!),
                    optionLabelBuilder: (option) {
                      switch (option) {
                        case '1 minute':
                          return l10n.settingsAutoLock1Minute;
                        case '5 minutes':
                          return l10n.settingsAutoLock5Minutes;
                        case '15 minutes':
                          return l10n.settingsAutoLock15Minutes;
                        case '30 minutes':
                          return l10n.settingsAutoLock30Minutes;
                        case 'Never':
                          return l10n.settingsAutoLockNever;
                        default:
                          return option;
                      }
                    },
                  ),
                  _buildSwitchTile(
                    l10n.settingsLoginNotificationsTitle,
                    l10n.settingsLoginNotificationsSubtitle,
                    _loginNotifications,
                    (value) =>
                        setDialogState(() => _loginNotifications = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l10n.commonCancel,
                style: GoogleFonts.inter(
                  color: Theme.of(innerContext).colorScheme.outline,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Provider.of<ThemeProvider>(context, listen: false)
                        .accentColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                setState(() {}); // Update main state
                await _saveAllSettings();
                if (!mounted) return;
                navigator.pop();
                ScaffoldMessenger.of(context).showKubusSnackBar(
                  SnackBar(
                      content: Text(l10n.settingsSecuritySettingsUpdatedToast)),
                );
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountManagementDialog() {
    final l10n = AppLocalizations.of(context)!;
    final emailPreferencesProvider = context.read<EmailPreferencesProvider>();
    if (emailPreferencesProvider.canManage &&
        !emailPreferencesProvider.initialized &&
        !emailPreferencesProvider.isLoading) {
      unawaited(emailPreferencesProvider.initialize());
    }
    showKubusDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) =>
            Consumer<EmailPreferencesProvider>(
          builder: (context, emailPreferences, _) => KubusAlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              l10n.settingsAccountManagementDialogTitle,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsEmailPreferencesSectionTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.settingsEmailPreferencesTransactionalNote,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    if (emailPreferences.isLoading) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Provider.of<ThemeProvider>(context, listen: false)
                              .accentColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildSwitchTile(
                      l10n.settingsEmailPreferencesProductUpdatesTitle,
                      l10n.settingsEmailPreferencesProductUpdatesSubtitle,
                      emailPreferences.preferences.productUpdates,
                      (value) {
                        final next = emailPreferences.preferences
                            .copyWith(productUpdates: value);
                        final messenger = ScaffoldMessenger.of(this.context);
                        unawaited(() async {
                          final ok =
                              await emailPreferences.updatePreferences(next);
                          if (!ok && mounted) {
                            messenger.showKubusSnackBar(
                              SnackBar(
                                  content: Text(l10n
                                      .settingsEmailPreferencesUpdateFailedToast)),
                            );
                          }
                        }());
                      },
                      enabled: emailPreferences.canManage &&
                          !emailPreferences.isUpdating,
                    ),
                    _buildSwitchTile(
                      l10n.settingsEmailPreferencesNewsletterTitle,
                      l10n.settingsEmailPreferencesNewsletterSubtitle,
                      emailPreferences.preferences.newsletter,
                      (value) {
                        final next = emailPreferences.preferences
                            .copyWith(newsletter: value);
                        final messenger = ScaffoldMessenger.of(this.context);
                        unawaited(() async {
                          final ok =
                              await emailPreferences.updatePreferences(next);
                          if (!ok && mounted) {
                            messenger.showKubusSnackBar(
                              SnackBar(
                                  content: Text(l10n
                                      .settingsEmailPreferencesUpdateFailedToast)),
                            );
                          }
                        }());
                      },
                      enabled: emailPreferences.canManage &&
                          !emailPreferences.isUpdating,
                    ),
                    _buildSwitchTile(
                      l10n.settingsEmailPreferencesCommunityDigestTitle,
                      l10n.settingsEmailPreferencesCommunityDigestSubtitle,
                      emailPreferences.preferences.communityDigest,
                      (value) {
                        final next = emailPreferences.preferences
                            .copyWith(communityDigest: value);
                        final messenger = ScaffoldMessenger.of(this.context);
                        unawaited(() async {
                          final ok =
                              await emailPreferences.updatePreferences(next);
                          if (!ok && mounted) {
                            messenger.showKubusSnackBar(
                              SnackBar(
                                  content: Text(l10n
                                      .settingsEmailPreferencesUpdateFailedToast)),
                            );
                          }
                        }());
                      },
                      enabled: emailPreferences.canManage &&
                          !emailPreferences.isUpdating,
                    ),
                    _buildSwitchTile(
                      l10n.settingsEmailPreferencesSecurityAlertsTitle,
                      l10n.settingsEmailPreferencesSecurityAlertsSubtitle,
                      emailPreferences.preferences.securityAlerts,
                      (value) {
                        final next = emailPreferences.preferences
                            .copyWith(securityAlerts: value);
                        final messenger = ScaffoldMessenger.of(this.context);
                        unawaited(() async {
                          final ok =
                              await emailPreferences.updatePreferences(next);
                          if (!ok && mounted) {
                            messenger.showKubusSnackBar(
                              SnackBar(
                                  content: Text(l10n
                                      .settingsEmailPreferencesUpdateFailedToast)),
                            );
                          }
                        }());
                      },
                      enabled: emailPreferences.canManage &&
                          !emailPreferences.isUpdating,
                    ),
                    _buildSwitchTile(
                      l10n.settingsEmailPreferencesTransactionalTitle,
                      l10n.settingsEmailPreferencesTransactionalSubtitle,
                      true,
                      (_) {},
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.permissionsNotificationsTitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSwitchTile(
                      l10n.settingsPushNotificationsTitle,
                      l10n.settingsPushNotificationsSubtitle,
                      _pushNotifications,
                      (value) async {
                        setDialogState(() => _pushNotifications = value);
                        await _togglePushNotifications(value);
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildDropdownTile(
                      l10n.settingsAccountTypeTitle,
                      l10n.settingsAccountTypeSubtitle,
                      _accountType,
                      ['Standard', 'Premium', 'Enterprise'],
                      (value) => setDialogState(() => _accountType = value!),
                      optionLabelBuilder: (option) {
                        switch (option) {
                          case 'Standard':
                            return l10n.settingsAccountTypeStandard;
                          case 'Premium':
                            return l10n.settingsAccountTypePremium;
                          case 'Enterprise':
                            return l10n.settingsAccountTypeEnterprise;
                          default:
                            return option;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildActionTile(
                      l10n.settingsDeactivateAccountTileTitle,
                      l10n.settingsDeactivateAccountTileSubtitle,
                      Icons.pause_circle_outline,
                      () {
                        Navigator.pop(context);
                        _showAccountDeactivationDialog();
                      },
                    ),
                    _buildActionTile(
                      l10n.settingsDeleteAccountTileTitle,
                      l10n.settingsDeleteAccountTileSubtitle,
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
                  l10n.commonCancel,
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Provider.of<ThemeProvider>(context, listen: false)
                          .accentColor,
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
                  messenger.showKubusSnackBar(
                    SnackBar(
                        content:
                            Text(l10n.settingsAccountSettingsUpdatedToast)),
                  );
                },
                child: Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Additional Dialog Methods
  void _showChangePasswordDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsChangePasswordDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
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
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(content: Text(l10n.settingsPasswordUpdatedToast)),
              );
            },
            child: Text(l10n.settingsUpdateButton),
          ),
        ],
      ),
    );
  }

  void _showAccountDeactivationDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsDeactivateAccountDialogTitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              l10n.settingsDeactivateAccountDialogBodyTitle,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsDeactivateAccountDialogBodySubtitle,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.commonCancel,
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
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(content: Text(l10n.settingsAccountDeactivatedToast)),
              );
            },
            child: Text(l10n.settingsDeactivateButton),
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
