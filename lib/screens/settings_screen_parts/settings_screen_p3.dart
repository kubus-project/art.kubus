part of '../settings_screen.dart';

// Extracted from settings_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _SettingsScreenStatePart3 on _SettingsScreenState {
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
          _applyState(() => _pushNotifications = false);
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
    _applyState(() => _pushNotifications = value);
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
          style: KubusTypography.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsLogoutDialogBody,
          style: KubusTypography.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.commonCancel,
              style: KubusTypography.inter(
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
      savedItemsProvider:
          Provider.of<SavedItemsProvider>(context, listen: false),
    );

    if (!mounted) return;
    _restartToOnboarding();
  }

  void _restartToOnboarding() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingFlowScreen()),
      (route) => false,
    );
  }

  // Load all settings
  Future<void> _loadAllSettings() async {
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
      _walletBackupStatus = walletBackupStatus;

      _profileVisibility = settings.profileVisibility;
      _showAchievements = settings.showAchievements;
      _showFriends = settings.showFriends;
      _allowMessages = settings.allowMessages;
      _accountType = settings.accountType;
      _publicProfile = settings.publicProfile;
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
          style: KubusTypography.inter(
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
                      style: KubusTypography.inter(
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
              style: KubusTypography.inter(
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
      margin: const EdgeInsets.only(bottom: KubusSpacing.sm),
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(KubusRadius.sm),
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
                  style: KubusTypography.inter(
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
                  style: KubusTypography.inter(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  timestamp,
                  style: KubusTypography.inter(
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
            style: KubusTypography.inter(
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
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'art.kubus',
              style: KubusTypography.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsVersionValue(AppInfo.version),
              style: KubusTypography.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              l10n.settingsBuildValue(AppInfo.buildNumber),
              style: KubusTypography.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '\u00A9 2026 kubus',
              style: KubusTypography.inter(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            Text(
              l10n.settingsAllRightsReserved,
              style: KubusTypography.inter(
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
              style: KubusTypography.inter(
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
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsTermsDialogBody,
            style: KubusTypography.inter(
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
              style: KubusTypography.inter(
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
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.settingsPrivacyPolicyDialogBody,
            style: KubusTypography.inter(
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
              style: KubusTypography.inter(
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
          style: KubusTypography.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.settingsSupportDialogBody,
              style: KubusTypography.inter(
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
              style: KubusTypography.inter(
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
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.settingsRateAppDialogBodyTitle,
              style: KubusTypography.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsRateAppDialogBodySubtitle,
              style: KubusTypography.inter(
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
              style: KubusTypography.inter(
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
    final accentColor = Provider.of<ThemeProvider>(context).accentColor;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SharedSettingsToggleRow(
          switchKey: tileKey,
          title: title,
          subtitle: subtitle,
          value: value,
          onChanged: enabled ? onChanged : null,
          enabled: enabled,
          activeColor: accentColor,
          titleStyle: KubusTypography.inter(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          subtitleStyle: KubusTypography.inter(
            fontSize: 12,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SharedSettingsRowTile(
          title: title,
          subtitle: subtitle,
          icon: Icons.tune,
          showChevron: false,
          trailing: DropdownButton<String>(
            value: value,
            underline: Container(),
            dropdownColor: scheme.surface,
            style: KubusTypography.inter(
              color: scheme.onSurface,
            ),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(optionLabelBuilder?.call(option) ?? option),
              );
            }).toList(),
            onChanged: onChanged,
          ),
          leadingBackgroundColor: Colors.transparent,
          leadingBorderColor: Colors.transparent,
          leadingIconColor: scheme.onSurface.withValues(alpha: 0.7),
          titleStyle: KubusTypography.inter(
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
          ),
          subtitleStyle: KubusTypography.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          backgroundColor: scheme.primaryContainer,
          borderColor: scheme.outline,
        ),
      ),
    );
  }

  Widget _buildActionTile(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: SharedSettingsRowTile(
          title: title,
          subtitle: subtitle,
          icon: icon,
          onTap: onTap,
          showChevron: true,
          leadingBackgroundColor: Colors.transparent,
          leadingBorderColor: Colors.transparent,
          leadingIconColor:
              Provider.of<ThemeProvider>(context, listen: false).accentColor,
          titleStyle: KubusTypography.inter(
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
          ),
          subtitleStyle: KubusTypography.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
          backgroundColor: scheme.primaryContainer,
          borderColor: scheme.outline,
        ),
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
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      child: AnimatedContainer(
        duration: context.animationTheme.short,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(KubusRadius.lg),
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
                    style: KubusTypography.inter(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: KubusTypography.inter(
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
            style: KubusTypography.inter(
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
                style: KubusTypography.inter(
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
                _applyState(() {
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
    bool showAchievements = initialPrefs.showAchievements;
    bool shareLastVisitedLocation = initialPrefs.shareLastVisitedLocation;
    bool showCollection = initialPrefs.showCollection;
    bool allowMessages = initialPrefs.allowMessages;
    bool showFriends = _showFriends;

    showKubusDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => KubusAlertDialog(
          backgroundColor: Theme.of(innerContext).colorScheme.surface,
          title: Text(
            l10n.settingsPrivacySettingsDialogTitle,
            style: KubusTypography.inter(
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
                      style: KubusTypography.inter(
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
                    l10n.desktopSettingsShowAchievementsTitle,
                    l10n.desktopSettingsShowAchievementsSubtitle,
                    showAchievements,
                    (value) => setDialogState(() => showAchievements = value),
                    tileKey: const Key('settings_privacy_show_achievements'),
                  ),
                  _buildSwitchTile(
                    l10n.desktopSettingsShowFriendsTitle,
                    l10n.desktopSettingsShowFriendsSubtitle,
                    showFriends,
                    (value) => setDialogState(() => showFriends = value),
                    tileKey: const Key('settings_privacy_show_friends'),
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
                style: KubusTypography.inter(
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
                _applyState(() {
                  _allowMessages = allowMessages;
                  _publicProfile = !privateProfile;
                  _showAchievements = showAchievements;
                  _showFriends = showFriends;
                });
                await profileProvider.updatePreferences(
                  privateProfile: privateProfile,
                  showActivityStatus: showActivityStatus,
                  showAchievements: showAchievements,
                  shareLastVisitedLocation: shareLastVisitedLocation,
                  showCollection: showCollection,
                  allowMessages: allowMessages,
                );
                await _saveAllSettings();
                if (!mounted) return;
                navigator.pop();
                final preferenceSyncFailed =
                    profileProvider.preferencesSaveError != null;
                ScaffoldMessenger.of(context).showKubusSnackBar(
                  SnackBar(
                    content: Text(
                      preferenceSyncFailed
                          ? l10n.commonActionFailedToast
                          : l10n.settingsPrivacySettingsUpdatedToast,
                    ),
                    backgroundColor: preferenceSyncFailed
                        ? Theme.of(context).colorScheme.error
                        : null,
                    action: preferenceSyncFailed
                        ? SnackBarAction(
                            label: l10n.commonRetry,
                            onPressed: () {
                              unawaited(profileProvider.retryPreferenceSync());
                            },
                          )
                        : null,
                  ),
                );
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
