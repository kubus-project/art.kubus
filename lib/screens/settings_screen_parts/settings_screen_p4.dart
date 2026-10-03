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

            final email = emailPreferences.preferences;
            final canEditEmail =
                emailPreferences.canManage && !emailPreferences.isUpdating;

            Widget emailRow(
              String title,
              String subtitle,
              bool value,
              EmailPreferences Function(bool value) next,
            ) {
              return _buildPreferenceRow(
                title,
                subtitle,
                value,
                (value) => unawaited(persistEmailPreferences(next(value))),
                enabled: canEditEmail,
              );
            }

            Widget appRow(
              String title,
              String subtitle,
              bool value,
              NotificationPreferenceSettings Function(bool value) next,
            ) {
              return _buildPreferenceRow(
                title,
                subtitle,
                value,
                (value) =>
                    unawaited(persistNotificationPreferences(next(value))),
                enabled: notificationPreferences.enabled,
              );
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
                      // Same hierarchy as desktop: Marketing / Activity /
                      // Essential email groups, then app notifications.
                      SharedSettingsSectionHeader(
                        title: l10n.settingsEmailPreferencesSectionTitle,
                        subtitle:
                            l10n.settingsEmailPreferencesTransactionalNote,
                      ),
                      if (emailPreferences.isLoading) ...[
                        const SizedBox(height: KubusSpacing.sm),
                        InlineLoading(
                          height: 2,
                          borderRadius: BorderRadius.circular(2),
                          color: KubusColorRoles.of(context).active,
                        ),
                      ],
                      const SizedBox(height: KubusSpacing.lg),
                      SharedSettingsGroup(
                        label: l10n.settingsEmailGroupMarketing,
                        children: [
                          emailRow(
                            l10n.settingsEmailPreferencesProductUpdatesTitle,
                            l10n.settingsEmailPreferencesProductUpdatesSubtitle,
                            email.marketingProductUpdates,
                            (v) => email.copyWith(marketingProductUpdates: v),
                          ),
                          emailRow(
                            l10n.settingsEmailPreferencesNewsletterTitle,
                            l10n.settingsEmailPreferencesNewsletterSubtitle,
                            email.marketingNewsletter,
                            (v) => email.copyWith(marketingNewsletter: v),
                          ),
                          emailRow(
                            l10n.settingsEmailPreferencesCommunityDigestTitle,
                            l10n.settingsEmailPreferencesCommunityDigestSubtitle,
                            email.marketingCommunityDigest,
                            (v) => email.copyWith(marketingCommunityDigest: v),
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.xl),
                      SharedSettingsGroup(
                        label: l10n.settingsEmailGroupActivity,
                        children: [
                          emailRow(
                            l10n.settingsEmailPreferencesActivityArtTitle,
                            l10n.settingsEmailPreferencesActivityArtSubtitle,
                            email.activityArt,
                            (v) => email.copyWith(activityArt: v),
                          ),
                          emailRow(
                            l10n.settingsEmailPreferencesActivityCommunityTitle,
                            l10n.settingsEmailPreferencesActivityCommunitySubtitle,
                            email.activityCommunity,
                            (v) => email.copyWith(activityCommunity: v),
                          ),
                          emailRow(
                            l10n.settingsEmailPreferencesActivityDaoTitle,
                            l10n.settingsEmailPreferencesActivityDaoSubtitle,
                            email.activityDao,
                            (v) => email.copyWith(activityDao: v),
                          ),
                          emailRow(
                            l10n.settingsEmailPreferencesActivityArtistHubTitle,
                            l10n.settingsEmailPreferencesActivityArtistHubSubtitle,
                            email.activityArtistHub,
                            (v) => email.copyWith(activityArtistHub: v),
                          ),
                          emailRow(
                            l10n.settingsEmailPreferencesActivityInstitutionHubTitle,
                            l10n.settingsEmailPreferencesActivityInstitutionHubSubtitle,
                            email.activityInstitutionHub,
                            (v) => email.copyWith(activityInstitutionHub: v),
                          ),
                          emailRow(
                            l10n.settingsEmailPreferencesActivityPromotionTitle,
                            l10n.settingsEmailPreferencesActivityPromotionSubtitle,
                            email.activityPromotion,
                            (v) => email.copyWith(activityPromotion: v),
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.xl),
                      SharedSettingsGroup(
                        label: l10n.settingsEmailGroupEssential,
                        note: l10n.settingsEmailGroupEssentialNote,
                        children: [
                          _buildPreferenceRow(
                            l10n.settingsEmailPreferencesCriticalAccountSecurityTitle,
                            l10n.settingsEmailPreferencesCriticalAccountSecuritySubtitle,
                            true,
                            null,
                            mandatory: true,
                          ),
                          _buildPreferenceRow(
                            l10n.settingsEmailPreferencesCriticalWalletSecurityTitle,
                            l10n.settingsEmailPreferencesCriticalWalletSecuritySubtitle,
                            true,
                            null,
                            mandatory: true,
                          ),
                          _buildPreferenceRow(
                            l10n.settingsEmailPreferencesTransactionalTitle,
                            l10n.settingsEmailPreferencesTransactionalSubtitle,
                            true,
                            null,
                            mandatory: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: KubusSpacing.xl),
                      Divider(
                        height: KubusSpacing.lg,
                        thickness: KubusSizes.hairline,
                        color: KubusColorRoles.of(context).ruleStrong,
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      SharedSettingsSectionHeader(
                        title: l10n.settingsAppNotificationsSectionTitle,
                        subtitle: l10n.settingsAppNotificationsSectionSubtitle,
                      ),
                      const SizedBox(height: KubusSpacing.lg),
                      SharedSettingsGroup(
                        children: [
                          _buildPreferenceRow(
                            l10n.settingsPushNotificationsTitle,
                            l10n.settingsPushNotificationsSubtitle,
                            _pushNotifications,
                            (value) async {
                              setDialogState(() => _pushNotifications = value);
                              await _togglePushNotifications(value);
                            },
                          ),
                          _buildPreferenceRow(
                            l10n.settingsInAppNotificationsMasterTitle,
                            l10n.settingsInAppNotificationsMasterSubtitle,
                            notificationPreferences.enabled,
                            (value) {
                              final next = notificationPreferences.copyWith(
                                enabled: value,
                              );
                              unawaited(persistNotificationPreferences(next));
                            },
                          ),
                          appRow(
                            l10n.settingsInAppNotificationsArtTitle,
                            l10n.settingsInAppNotificationsArtSubtitle,
                            notificationPreferences.art,
                            (v) => notificationPreferences.copyWith(art: v),
                          ),
                          appRow(
                            l10n.settingsInAppNotificationsCommunityTitle,
                            l10n.settingsInAppNotificationsCommunitySubtitle,
                            notificationPreferences.community,
                            (v) =>
                                notificationPreferences.copyWith(community: v),
                          ),
                          appRow(
                            l10n.settingsInAppNotificationsDaoTitle,
                            l10n.settingsInAppNotificationsDaoSubtitle,
                            notificationPreferences.dao,
                            (v) => notificationPreferences.copyWith(dao: v),
                          ),
                          appRow(
                            l10n.settingsInAppNotificationsArtistHubTitle,
                            l10n.settingsInAppNotificationsArtistHubSubtitle,
                            notificationPreferences.artistHub,
                            (v) =>
                                notificationPreferences.copyWith(artistHub: v),
                          ),
                          appRow(
                            l10n.settingsInAppNotificationsInstitutionHubTitle,
                            l10n.settingsInAppNotificationsInstitutionHubSubtitle,
                            notificationPreferences.institutionHub,
                            (v) => notificationPreferences.copyWith(
                              institutionHub: v,
                            ),
                          ),
                          appRow(
                            l10n.settingsInAppNotificationsAccountTitle,
                            l10n.settingsInAppNotificationsAccountSubtitle,
                            notificationPreferences.account,
                            (v) => notificationPreferences.copyWith(account: v),
                          ),
                          appRow(
                            l10n.settingsInAppNotificationsPromotionTitle,
                            l10n.settingsInAppNotificationsPromotionSubtitle,
                            notificationPreferences.promotion,
                            (v) =>
                                notificationPreferences.copyWith(promotion: v),
                          ),
                        ],
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
