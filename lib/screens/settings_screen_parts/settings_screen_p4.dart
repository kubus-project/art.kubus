part of '../settings_screen.dart';

// Extracted from settings_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _SettingsScreenStatePart4 on _SettingsScreenState {
  Future<void> _showSecuritySettingsDialog() async {
    final l10n = AppLocalizations.of(context)!;
    await showKubusDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => KubusAlertDialog(
          backgroundColor: Theme.of(innerContext).colorScheme.surface,
          title: Text(
            l10n.settingsSecuritySettingsDialogTitle,
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
                _applyState(() {}); // Update main state
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

  Future<void> _showAccountManagementDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final emailPreferencesProvider = context.read<EmailPreferencesProvider>();
    if (emailPreferencesProvider.canManage &&
        !emailPreferencesProvider.initialized &&
        !emailPreferencesProvider.isLoading) {
      unawaited(emailPreferencesProvider.initialize());
    }
    final followUpAction = await showKubusDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) =>
            Consumer2<EmailPreferencesProvider, ProfileProvider>(
          builder: (context, emailPreferences, profileProvider, _) {
            final messenger = ScaffoldMessenger.of(this.context);
            final notificationPreferences =
                profileProvider.preferences.notificationPreferences;

            Future<void> persistEmailPreferences(EmailPreferences next) async {
              final ok = await emailPreferences.updatePreferences(next);
              if (!ok && mounted) {
                messenger.showKubusSnackBar(
                  SnackBar(
                    content:
                        Text(l10n.settingsEmailPreferencesUpdateFailedToast),
                  ),
                );
              }
            }

            Future<void> persistNotificationPreferences(
              NotificationPreferenceSettings next,
            ) async {
              await profileProvider.updateNotificationPreferences(next);
            }

            return KubusAlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                l10n.settingsAccountManagementDialogTitle,
                style: KubusTypography.inter(
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
                        style: KubusTypography.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.settingsEmailPreferencesTransactionalNote,
                        style: KubusTypography.inter(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      if (emailPreferences.isLoading) ...[
                        const SizedBox(height: 12),
                        InlineLoading(height: 2, borderRadius: BorderRadius.circular(2), color: Provider.of<ThemeProvider>(context, listen: false)
                                .accentColor,),
                      ],
                      const SizedBox(height: 12),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesProductUpdatesTitle,
                        l10n.settingsEmailPreferencesProductUpdatesSubtitle,
                        emailPreferences.preferences.marketingProductUpdates,
                        (value) {
                          final next = emailPreferences.preferences
                              .copyWith(marketingProductUpdates: value);
                          unawaited(persistEmailPreferences(next));
                        },
                        enabled: emailPreferences.canManage &&
                            !emailPreferences.isUpdating,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesNewsletterTitle,
                        l10n.settingsEmailPreferencesNewsletterSubtitle,
                        emailPreferences.preferences.marketingNewsletter,
                        (value) {
                          final next = emailPreferences.preferences
                              .copyWith(marketingNewsletter: value);
                          unawaited(persistEmailPreferences(next));
                        },
                        enabled: emailPreferences.canManage &&
                            !emailPreferences.isUpdating,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesCommunityDigestTitle,
                        l10n.settingsEmailPreferencesCommunityDigestSubtitle,
                        emailPreferences.preferences.marketingCommunityDigest,
                        (value) {
                          final next = emailPreferences.preferences
                              .copyWith(marketingCommunityDigest: value);
                          unawaited(persistEmailPreferences(next));
                        },
                        enabled: emailPreferences.canManage &&
                            !emailPreferences.isUpdating,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesActivityArtTitle,
                        l10n.settingsEmailPreferencesActivityArtSubtitle,
                        emailPreferences.preferences.activityArt,
                        (value) {
                          final next = emailPreferences.preferences
                              .copyWith(activityArt: value);
                          unawaited(persistEmailPreferences(next));
                        },
                        enabled: emailPreferences.canManage &&
                            !emailPreferences.isUpdating,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesActivityCommunityTitle,
                        l10n.settingsEmailPreferencesActivityCommunitySubtitle,
                        emailPreferences.preferences.activityCommunity,
                        (value) {
                          final next = emailPreferences.preferences
                              .copyWith(activityCommunity: value);
                          unawaited(persistEmailPreferences(next));
                        },
                        enabled: emailPreferences.canManage &&
                            !emailPreferences.isUpdating,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesActivityDaoTitle,
                        l10n.settingsEmailPreferencesActivityDaoSubtitle,
                        emailPreferences.preferences.activityDao,
                        (value) {
                          final next = emailPreferences.preferences
                              .copyWith(activityDao: value);
                          unawaited(persistEmailPreferences(next));
                        },
                        enabled: emailPreferences.canManage &&
                            !emailPreferences.isUpdating,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesActivityArtistHubTitle,
                        l10n.settingsEmailPreferencesActivityArtistHubSubtitle,
                        emailPreferences.preferences.activityArtistHub,
                        (value) {
                          final next = emailPreferences.preferences
                              .copyWith(activityArtistHub: value);
                          unawaited(persistEmailPreferences(next));
                        },
                        enabled: emailPreferences.canManage &&
                            !emailPreferences.isUpdating,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesActivityInstitutionHubTitle,
                        l10n.settingsEmailPreferencesActivityInstitutionHubSubtitle,
                        emailPreferences.preferences.activityInstitutionHub,
                        (value) {
                          final next = emailPreferences.preferences
                              .copyWith(activityInstitutionHub: value);
                          unawaited(persistEmailPreferences(next));
                        },
                        enabled: emailPreferences.canManage &&
                            !emailPreferences.isUpdating,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesActivityPromotionTitle,
                        l10n.settingsEmailPreferencesActivityPromotionSubtitle,
                        emailPreferences.preferences.activityPromotion,
                        (value) {
                          final next = emailPreferences.preferences.copyWith(
                            activityPromotion: value,
                          );
                          unawaited(persistEmailPreferences(next));
                        },
                        enabled: emailPreferences.canManage &&
                            !emailPreferences.isUpdating,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesCriticalAccountSecurityTitle,
                        l10n.settingsEmailPreferencesCriticalAccountSecuritySubtitle,
                        true,
                        (_) {},
                        enabled: false,
                      ),
                      _buildSwitchTile(
                        l10n.settingsEmailPreferencesCriticalWalletSecurityTitle,
                        l10n.settingsEmailPreferencesCriticalWalletSecuritySubtitle,
                        true,
                        (_) {},
                        enabled: false,
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
                        style: KubusTypography.inter(
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
                      _buildSwitchTile(
                        l10n.settingsInAppNotificationsMasterTitle,
                        l10n.settingsInAppNotificationsMasterSubtitle,
                        notificationPreferences.enabled,
                        (value) {
                          final next =
                              notificationPreferences.copyWith(enabled: value);
                          unawaited(persistNotificationPreferences(next));
                        },
                      ),
                      _buildSwitchTile(
                        l10n.settingsInAppNotificationsArtTitle,
                        l10n.settingsInAppNotificationsArtSubtitle,
                        notificationPreferences.art,
                        (value) {
                          final next =
                              notificationPreferences.copyWith(art: value);
                          unawaited(persistNotificationPreferences(next));
                        },
                        enabled: notificationPreferences.enabled,
                      ),
                      _buildSwitchTile(
                        l10n.settingsInAppNotificationsCommunityTitle,
                        l10n.settingsInAppNotificationsCommunitySubtitle,
                        notificationPreferences.community,
                        (value) {
                          final next = notificationPreferences.copyWith(
                            community: value,
                          );
                          unawaited(persistNotificationPreferences(next));
                        },
                        enabled: notificationPreferences.enabled,
                      ),
                      _buildSwitchTile(
                        l10n.settingsInAppNotificationsDaoTitle,
                        l10n.settingsInAppNotificationsDaoSubtitle,
                        notificationPreferences.dao,
                        (value) {
                          final next =
                              notificationPreferences.copyWith(dao: value);
                          unawaited(persistNotificationPreferences(next));
                        },
                        enabled: notificationPreferences.enabled,
                      ),
                      _buildSwitchTile(
                        l10n.settingsInAppNotificationsArtistHubTitle,
                        l10n.settingsInAppNotificationsArtistHubSubtitle,
                        notificationPreferences.artistHub,
                        (value) {
                          final next = notificationPreferences.copyWith(
                            artistHub: value,
                          );
                          unawaited(persistNotificationPreferences(next));
                        },
                        enabled: notificationPreferences.enabled,
                      ),
                      _buildSwitchTile(
                        l10n.settingsInAppNotificationsInstitutionHubTitle,
                        l10n.settingsInAppNotificationsInstitutionHubSubtitle,
                        notificationPreferences.institutionHub,
                        (value) {
                          final next = notificationPreferences.copyWith(
                            institutionHub: value,
                          );
                          unawaited(persistNotificationPreferences(next));
                        },
                        enabled: notificationPreferences.enabled,
                      ),
                      _buildSwitchTile(
                        l10n.settingsInAppNotificationsAccountTitle,
                        l10n.settingsInAppNotificationsAccountSubtitle,
                        notificationPreferences.account,
                        (value) {
                          final next = notificationPreferences.copyWith(
                            account: value,
                          );
                          unawaited(persistNotificationPreferences(next));
                        },
                        enabled: notificationPreferences.enabled,
                      ),
                      _buildSwitchTile(
                        l10n.settingsInAppNotificationsPromotionTitle,
                        l10n.settingsInAppNotificationsPromotionSubtitle,
                        notificationPreferences.promotion,
                        (value) {
                          final next = notificationPreferences.copyWith(
                            promotion: value,
                          );
                          unawaited(persistNotificationPreferences(next));
                        },
                        enabled: notificationPreferences.enabled,
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
                        () => Navigator.pop(context, 'deactivate'),
                      ),
                      _buildActionTile(
                        l10n.settingsDeleteAccountTileTitle,
                        l10n.settingsDeleteAccountTileSubtitle,
                        Icons.delete_forever,
                        () => Navigator.pop(context, 'delete'),
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
                  onPressed: () async {
                    final dialogContext = context;
                    final navigator = Navigator.of(dialogContext);
                    final snackbarMessenger =
                        ScaffoldMessenger.of(dialogContext);
                    _applyState(() {});
                    await _saveAllSettings();
                    if (!mounted) return;
                    navigator.pop();
                    snackbarMessenger.showKubusSnackBar(
                      SnackBar(
                        content: Text(l10n.settingsAccountSettingsUpdatedToast),
                      ),
                    );
                  },
                  child: Text(l10n.commonSave),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    switch (followUpAction) {
      case 'deactivate':
        _showAccountDeactivationDialog();
        break;
      case 'delete':
        _showDeleteAccountDialog();
        break;
    }
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
          style: KubusTypography.inter(
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
          style: KubusTypography.inter(
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
              style: KubusTypography.inter(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsDeactivateAccountDialogBodySubtitle,
              style: KubusTypography.inter(
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
              style: KubusTypography.inter(
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
