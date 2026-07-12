part of '../desktop_settings_screen.dart';

// Extracted from desktop_settings_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _DesktopSettingsScreenStatePart1 on _DesktopSettingsScreenState {
  String _secureAccountSubtitle(AppLocalizations l10n) =>
      _secureAccountHasEmail && !_secureAccountHasPassword
          ? l10n.authSecureAccountSettingsAddPasswordSubtitle
          : l10n.authSecureAccountSettingsAddEmailPasswordSubtitle;

  Future<void> _handleReadOnlyWalletReconnect(
    WalletProvider walletProvider,
  ) async {
    await WalletReconnectAction.handleReadOnlyReconnect(
      context: context,
      walletProvider: walletProvider,
      refreshBackendSession: true,
    );
  }

  Future<void> _openWalletBackupProtection() async {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      shellScope.pushScreen(
        WalletBackupProtectionScreen(
          onBackupStateChanged: _loadSettings,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WalletBackupProtectionScreen(),
      ),
    );
    if (!mounted) return;
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final settings = await SettingsService.loadSettings(
      fallbackNetwork: walletProvider.currentSolanaNetwork.isNotEmpty
          ? walletProvider.currentSolanaNetwork
          : null,
    );
    final hasPin = await walletProvider.hasPin();
    final biometricsSupported = await walletProvider.canUseBiometrics();
    final secureAccountStatus = await _loadSecureAccountStatus();
    final walletBackupStatus = await WalletBackupStatusResolver.resolve(
      walletProvider: walletProvider,
      refreshRemote: true,
    );
    if (!mounted) return;

    _applyState(() {
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
      _requirePin = settings.requirePin;
      _biometricAuth = settings.biometricAuth && hasPin && biometricsSupported;
      _biometricsDeclined = settings.biometricsDeclined;
      _useBiometricsOnUnlock = settings.useBiometricsOnUnlock;
      _privacyMode = settings.privacyMode;
      _hasPin = hasPin;
      _biometricsSupported = biometricsSupported;

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
      _walletBackupStatus = walletBackupStatus;
      _secureAccountHasEmail = secureAccountStatus['hasEmail'] == true;
      _secureAccountHasPassword = secureAccountStatus['hasPassword'] == true;
    });
  }

  String _walletBackupSummary(AppLocalizations l10n) {
    return _walletBackupStatus.settingsSummary(l10n);
  }

  Future<Map<String, dynamic>> _loadSecureAccountStatus() async {
    final api = BackendApiService();
    try {
      final status = await api.getAccountSecurityStatus();
      if (mounted) {
        _applyState(() {
          _secureAccountHasEmail = status['hasEmail'] == true;
          _secureAccountHasPassword = status['hasPassword'] == true;
        });
      }
      return status;
    } catch (_) {
      final status = await api.getCachedSecureAccountStatus();
      if (mounted) {
        _applyState(() {
          _secureAccountHasEmail = status['hasEmail'] == true;
          _secureAccountHasPassword = status['hasPassword'] == true;
        });
      }
      return status;
    }
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

  Widget _buildSettingsSidebar(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;
    final settingsItems = [
      _SettingsItem(l10n.settingsWalletSectionTitle,
          Icons.account_balance_wallet_outlined, 0),
      _SettingsItem(
          l10n.settingsAppearanceSectionTitle, Icons.palette_outlined, 1),
      _SettingsItem(
          l10n.permissionsNotificationsTitle, Icons.notifications_outlined, 2),
      _SettingsItem(l10n.settingsSecuritySettingsTileTitle, Icons.security, 3),
      _SettingsItem(
          l10n.settingsPrivacySettingsTileTitle, Icons.lock_outline, 4),
      _SettingsItem(
          l10n.userProfileAchievementsTitle, Icons.emoji_events_outlined, 5),
      _SettingsItem(l10n.settingsPlatformFeaturesSectionTitle,
          Icons.phone_android_outlined, 6),
      _SettingsItem(l10n.settingsSupportDialogTitle, Icons.help_outline, 7),
      _SettingsItem(l10n.settingsAboutSectionTitle, Icons.info_outline, 8),
      _SettingsItem(
          l10n.settingsDangerZoneSectionTitle, Icons.warning_outlined, 9),
    ];

    return ListView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      children: [
        if (!widget.embeddedInShell) ...[
          Padding(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: KubusScreenHeaderBar(
              title: l10n.settingsTitle,
              compact: true,
              minHeight: KubusHeaderMetrics.actionHitArea,
              leading: IconButton(
                onPressed: () => popDesktopShellAware(context),
                icon: Icon(
                  Icons.arrow_back,
                  size: KubusHeaderMetrics.actionIcon,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                tooltip: l10n.commonBack,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
        ],

        // Settings items
        ...settingsItems
            .map((item) => _buildSettingsSidebarItem(item, themeProvider)),

        const SizedBox(height: KubusSpacing.xl),
        const Divider(),
        const SizedBox(height: KubusSpacing.lg),

        // Logout button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(DetailRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    Icons.logout,
                    size: KubusHeaderMetrics.actionIcon,
                    color: errorColor,
                  ),
                  const SizedBox(width: KubusSpacing.lg),
                  Text(
                    l10n.settingsLogoutButton,
                    style: KubusTextStyles.sectionTitle.copyWith(
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
      case 0: // Wallet
        return AppColorUtils.amberAccent;
      case 1: // Appearance
        return scheme.tertiary;
      case 2: // Notifications
        return AppColorUtils.amberAccent;
      case 3: // Privacy
      case 4: // Security
        return AppColorUtils.indigoAccent;
      case 5: // Achievements
        return Colors.amber;
      case 6: // Platform
        return scheme.secondary;
      case 7: // Help
      case 8: // About
        return scheme.secondary;
      case 9: // Danger Zone
        return scheme.error;
      default:
        return scheme.secondary;
    }
  }

  Widget _buildSettingsSidebarItem(
      _SettingsItem item, ThemeProvider themeProvider) {
    final isSelected = _selectedSettingsIndex == item.index;
    final scheme = Theme.of(context).colorScheme;
    final sectionColor = _getSectionColor(item.index, scheme);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _applyState(() => _selectedSettingsIndex = item.index);
        },
        borderRadius: BorderRadius.circular(DetailRadius.md),
        child: Container(
          key: ValueKey('desktop_settings_sidebar_item_${item.index}'),
          padding: EdgeInsets.all(DetailSpacing.lg),
          decoration: BoxDecoration(
            color: isSelected
                ? sectionColor.withValues(alpha: 0.1)
                : Colors.transparent,
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
                      ? DetailTypography.label(context)
                          .copyWith(color: sectionColor)
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
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, _) {
        final statsProvider = Provider.of<StatsProvider?>(
          context,
          listen: true,
        );
        final l10n = AppLocalizations.of(context)!;
        final user = profileProvider.currentUser;
        final wallet = (user?.walletAddress ?? '').trim();
        final scheme = Theme.of(context).colorScheme;
        final headerColor = scheme.secondary;

        const metrics = <String>['artworks', 'followers', 'following'];
        if (wallet.isNotEmpty && statsProvider != null) {
          statsProvider.ensureSnapshot(
            entityType: 'user',
            entityId: wallet,
            metrics: metrics,
            scope: 'public',
          );
        }

        final snapshot = wallet.isEmpty || statsProvider == null
            ? null
            : statsProvider.getSnapshot(
                entityType: 'user',
                entityId: wallet,
                metrics: metrics,
                scope: 'public',
              );
        final isLoading = wallet.isNotEmpty &&
            statsProvider != null &&
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
        String displayCount(int value) =>
            isLoading ? '\u2026' : value.toString();

        return Container(
          padding: const EdgeInsets.all(KubusSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile card
              DesktopCard(
                padding: EdgeInsets.zero,
                showBorder: false,
                child: Container(
                  padding: const EdgeInsets.all(KubusSpacing.xxl),
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
                        radius:
                            KubusChromeMetrics.heroIconBox - KubusSpacing.xxs,
                        allowFabricatedFallback: true,
                      ),
                      const SizedBox(width: KubusSpacing.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? l10n.settingsGuestUserName,
                              style: KubusTextStyles.heroTitle.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            if (user?.bio != null) ...[
                              const SizedBox(height: KubusSpacing.xs),
                              Text(
                                user!.bio,
                                style: KubusTextStyles.heroSubtitle.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: KubusSpacing.md),
                            Row(
                              children: [
                                _buildProfileStat(l10n.userProfileArtworksTitle,
                                    displayCount(artworks)),
                                const SizedBox(width: KubusSpacing.xl),
                                _buildProfileStat(
                                    l10n.userProfileFollowersStatLabel,
                                    displayCount(followers)),
                                const SizedBox(width: KubusSpacing.xl),
                                _buildProfileStat(
                                    l10n.userProfileFollowingStatLabel,
                                    displayCount(following)),
                              ],
                            ),
                          ],
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
          style: KubusTextStyles.statValue.copyWith(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          label,
          style: KubusTextStyles.statLabel.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedContent(ThemeProvider themeProvider) {
    switch (_selectedSettingsIndex) {
      case 0:
        return _buildWalletSettings(themeProvider);
      case 1:
        return _buildAppearanceSettings(themeProvider);
      case 2:
        return _buildNotificationSettings(themeProvider);
      case 3:
        return _buildSecuritySettings(themeProvider);
      case 4:
        return _buildPrivacySettings(themeProvider);
      case 5:
        return _buildAchievementsSettings();
      case 6:
        return _buildPlatformCapabilitiesSection();
      case 7:
        return _buildHelpSettings();
      case 8:
        return _buildAboutSettings();
      case 9:
        return _buildDangerZoneSettings();
      default:
        return _buildWalletSettings(themeProvider);
    }
  }

  Widget _buildWalletSettings(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xl),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KubusHeaderText(
              title: l10n.settingsWalletSectionTitle,
              subtitle: l10n.desktopSettingsWalletSectionSubtitle,
            ),
            const SizedBox(height: KubusSpacing.lg),

            // Network selection
            DesktopCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsNetworkTileTitle,
                    style: KubusTextStyles.sectionTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ['Mainnet', 'Devnet', 'Testnet'].map((network) {
                      final isSelected =
                          walletProvider.currentSolanaNetwork.toLowerCase() ==
                              network.toLowerCase();
                      return ChoiceChip(
                        label: Text(network),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            walletProvider.switchSolanaNetwork(network);
                            _applyState(() => _networkSelection = network);
                            unawaited(_saveSettings());
                          }
                        },
                        selectedColor:
                            AppColorUtils.amberAccent.withValues(alpha: 0.2),
                        labelStyle: KubusTextStyles.navLabel.copyWith(
                          color: isSelected
                              ? AppColorUtils.amberAccent
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Security options
            if (walletProvider.hasWalletIdentity) ...[
              Text(
                l10n.desktopSettingsSecuritySectionTitle,
                style: KubusTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              DesktopCard(
                child: Column(
                  children: [
                    _buildSettingsRow(
                      l10n.settingsBackupSettingsTileTitle,
                      _walletBackupSummary(l10n),
                      Icons.backup_outlined,
                      onTap: () {
                        unawaited(_openWalletBackupProtection());
                      },
                    ),
                    const Divider(height: 32),
                    _buildSettingsRow(
                      l10n.settingsExportRecoveryPhraseTileTitle,
                      l10n.settingsExportRecoveryPhraseTileSubtitle,
                      Icons.vpn_key,
                      onTap: () => _showRecoveryWarning(),
                    ),
                    if (AppConfig.isFeatureEnabled('availabilityNodes')) ...[
                      const Divider(height: 32),
                      _buildSettingsRow(
                        _availabilityNodeNavTitle(context),
                        _availabilityNodeNavSubtitle(context),
                        Icons.dns_outlined,
                        onTap: () => Navigator.of(context)
                            .pushNamed('/wallet/availability-node'),
                      ),
                    ],
                    const Divider(height: 32),
                    _buildSettingsRow(
                      walletProvider.isReadOnlySession
                          ? l10n.commonReconnect
                          : l10n.desktopSettingsDisconnectWalletTileTitle,
                      walletProvider.isReadOnlySession
                          ? l10n.walletReconnectManualRequiredToast
                          : l10n.desktopSettingsDisconnectWalletTileSubtitle,
                      walletProvider.isReadOnlySession
                          ? Icons.link
                          : Icons.logout,
                      isDestructive: !walletProvider.isReadOnlySession,
                      tileKey: const Key('desktop_settings_wallet_disconnect'),
                      onTap: walletProvider.isReadOnlySession
                          ? () => unawaited(
                                _handleReadOnlyWalletReconnect(walletProvider),
                              )
                          : () => _showDisconnectConfirmation(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            WalletCustodyStatusPanel(
              authority: walletProvider.authority,
              onRestoreSigner:
                  walletProvider.authority.canRestoreFromEncryptedBackup
                      ? () => unawaited(
                            _handleReadOnlyWalletReconnect(walletProvider),
                          )
                      : null,
              onConnectExternalWallet: !walletProvider.authority.canTransact
                  ? () => Navigator.of(context).pushNamed('/connect-wallet')
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _availabilityNodeNavTitle(BuildContext context) {
    return AppLocalizations.of(context)!.availabilityNodeNavTitle;
  }

  String _availabilityNodeNavSubtitle(BuildContext context) {
    return AppLocalizations.of(context)!.availabilityNodeNavSubtitle;
  }

  void _showRecoveryWarning() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.xl),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: KubusSpacing.sm),
            Text(
              l10n.settingsSecurityWarningTitle,
              style: KubusTextStyles.sheetTitle.copyWith(
                fontSize: KubusHeaderMetrics.sectionTitle + KubusSpacing.xxs,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsExportRecoveryPhraseDialogBody,
              style: KubusTextStyles.detailBody.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              l10n.settingsSecurityWarningBullets,
              style: KubusTextStyles.detailCaption.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
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
              unawaited(_openWalletBackupProtection());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
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
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KubusRadius.xl),
        ),
        title: Text(
          l10n.desktopSettingsDisconnectWalletDialogTitle,
          style: KubusTextStyles.sheetTitle,
        ),
        content: Text(
          l10n.desktopSettingsDisconnectWalletDialogBody,
          style: KubusTextStyles.detailBody.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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
              unawaited(
                Provider.of<WalletProvider>(context, listen: false)
                    .disconnectWallet(),
              );
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(
                    content: Text(l10n.desktopSettingsWalletDisconnectedToast)),
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
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsAppVersionDialogTitle,
          style: KubusTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.appTitle,
              style: KubusTextStyles.sheetTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsVersionValue(AppInfo.version),
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              l10n.settingsBuildValue(AppInfo.buildNumber),
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.settingsCopyright(DateTime.now().year),
              style: KubusTextStyles.sectionSubtitle.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            Text(
              l10n.settingsAllRightsReserved,
              style: KubusTextStyles.sectionSubtitle.copyWith(
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
              child: Text(l10n.commonClose)),
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
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsTermsDialogBody,
            style: KubusTextStyles.detailBody.copyWith(
                height: 1.5, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonClose)),
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
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsPrivacyPolicyDialogBody,
            style: KubusTextStyles.detailBody.copyWith(
                height: 1.5, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonClose)),
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
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.settingsSupportDialogBody,
              style: KubusTextStyles.detailBody.copyWith(
                color: Theme.of(dialogContext).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(dialogContext).colorScheme.secondary,
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(rootContext).showKubusSnackBar(
                    SnackBar(content: Text(l10n.settingsOpeningFaqToast)));
              },
              icon: const Icon(Icons.help_outline),
              label: Text(l10n.settingsViewFaqButton),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(dialogContext).colorScheme.secondary,
                  foregroundColor: Colors.white),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(rootContext);
                Navigator.pop(dialogContext);

                if (!AppConfig.isFeatureEnabled('supportTickets')) {
                  messenger.showKubusSnackBar(SnackBar(
                      content: Text(l10n.settingsOpeningEmailClientToast)));
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
              child: Text(l10n.commonClose)),
        ],
      ),
    );
  }

  void _showLicensesDialog() {
    final l10n = AppLocalizations.of(context)!;
    showLicensePage(
      context: context,
      applicationName: l10n.appTitle,
      applicationVersion: AppInfo.version,
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
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsRateAppDialogBodyTitle,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsRateAppDialogBodySubtitle,
              style: KubusTextStyles.detailBody.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.settingsMaybeLaterButton)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showKubusSnackBar(
                  SnackBar(content: Text(l10n.settingsOpeningAppStoreToast)));
            },
            child: Text(l10n.settingsRateNowButton),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsChangePasswordDialogTitle,
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(dialogContext).colorScheme.onSurface,
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
              style: KubusTextStyles.navLabel.copyWith(
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

  void _showResetDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsResetAppDialogTitle,
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.settingsResetAppDialogBody,
          style: KubusTextStyles.detailBody.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
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
              navigator.pop();
              messenger.showKubusSnackBar(SnackBar(
                  content: Text(l10n.settingsAppResetSuccessToast),
                  duration: const Duration(seconds: 3)));
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
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsDeleteAccountDialogTitle,
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.settingsDeleteAccountDialogBody,
          style: KubusTextStyles.detailBody.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
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

              // Delete the authenticated account (users.id), never just
              // wallet-scoped data. Local state is only cleared after the
              // backend confirms the deletion.
              try {
                await BackendApiService().deleteMyAccount();
              } catch (e) {
                debugPrint(
                    'DesktopSettingsScreen: backend deletion failed: $e');
                messenger.showKubusSnackBar(SnackBar(
                    content:
                        Text(l10n.settingsDeleteAccountBackendFailedToast)));
                if (!mounted) return;
                navigator.pop();
                return;
              }

              await SettingsService.resetApp(
                walletProvider: walletProvider,
                backendApi: BackendApiService(),
                notificationProvider: notificationProvider,
                profileProvider: profileProvider,
              );
              if (!mounted) return;
              navigator.pop();
              messenger.showKubusSnackBar(
                  SnackBar(content: Text(l10n.settingsAccountDeletedToast)));
              _restartToOnboarding();
            },
            child: Text(l10n.settingsDeleteForeverButton),
          ),
        ],
      ),
    );
  }
}
