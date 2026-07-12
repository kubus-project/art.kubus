part of '../desktop_settings_screen.dart';

// Extracted from desktop_settings_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _DesktopSettingsScreenStatePart3 on _DesktopSettingsScreenState {
  Widget _buildPrivacySettings(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = Provider.of<ProfileProvider>(context);
    final prefs = profileProvider.preferences;
    final bool privateProfile = prefs.privacy.toLowerCase() == 'private';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsPrivacySettingsTileTitle,
            style: KubusTextStyles.screenTitle.copyWith(
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
                  onChanged: (value) =>
                      profileProvider.updatePreferences(privateProfile: value),
                  switchKey:
                      const Key('desktop_settings_privacy_private_profile'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsShowActivityStatusTitle,
                  l10n.settingsShowActivityStatusSubtitle,
                  prefs.showActivityStatus,
                  saveAfterToggle: false,
                  onChanged: (value) => profileProvider.updatePreferences(
                    showActivityStatus: value,
                    shareLastVisitedLocation:
                        value ? prefs.shareLastVisitedLocation : false,
                  ),
                  switchKey: const Key(
                      'desktop_settings_privacy_show_activity_status'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsShareLastVisitedLocationTitle,
                  l10n.settingsShareLastVisitedLocationSubtitle,
                  prefs.shareLastVisitedLocation,
                  saveAfterToggle: false,
                  onChanged: (value) => profileProvider.updatePreferences(
                      shareLastVisitedLocation: value),
                  enabled: prefs.showActivityStatus,
                  switchKey: const Key(
                      'desktop_settings_privacy_share_last_visited_location'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsShowCollectionTitle,
                  l10n.settingsShowCollectionSubtitle,
                  prefs.showCollection,
                  saveAfterToggle: false,
                  onChanged: (value) =>
                      profileProvider.updatePreferences(showCollection: value),
                  switchKey:
                      const Key('desktop_settings_privacy_show_collection'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsAllowMessagesTitle,
                  l10n.settingsAllowMessagesSubtitle,
                  prefs.allowMessages,
                  saveAfterToggle: false,
                  onChanged: (value) =>
                      profileProvider.updatePreferences(allowMessages: value),
                  switchKey:
                      const Key('desktop_settings_privacy_allow_messages'),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.desktopSettingsShowFriendsTitle,
                  l10n.desktopSettingsShowFriendsSubtitle,
                  _showFriends,
                  onChanged: (value) => _applyState(() => _showFriends = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.desktopSettingsShowAchievementsTitle,
                  l10n.desktopSettingsShowAchievementsSubtitle,
                  _showAchievements,
                  onChanged: (value) {
                    _applyState(() => _showAchievements = value);
                    unawaited(
                      profileProvider
                          .updatePreferences(showAchievements: value),
                    );
                  },
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsAnalyticsTileTitle,
                  l10n.settingsAnalyticsTileSubtitle,
                  _analytics,
                  onChanged: (value) => _applyState(() => _analytics = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsCrashReportingTileTitle,
                  l10n.settingsCrashReportingTileSubtitle,
                  _crashReporting,
                  onChanged: (value) => _applyState(() => _crashReporting = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsSkipOnboardingTileTitle,
                  l10n.settingsSkipOnboardingTileSubtitle,
                  _skipOnboardingForReturningUsers,
                  onChanged: (value) =>
                      _applyState(() => _skipOnboardingForReturningUsers = value),
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
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsSecuritySettingsDialogTitle,
            style: KubusTextStyles.screenTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          DesktopCard(
            child: Column(
              children: [
                _buildSettingsRow(
                  l10n.authSecureAccountTitle,
                  _secureAccountSubtitle(l10n),
                  Icons.verified_user_outlined,
                  trailing: const EmailVerificationStatusBadge(
                    dense: true,
                    alignment: Alignment.centerRight,
                  ),
                  onTap: () async {
                    final shellScope = DesktopShellScope.of(context);
                    if (shellScope != null) {
                      shellScope.pushScreen(const SecureAccountScreen());
                    } else {
                      await Navigator.of(context).pushNamed('/secure-account');
                    }
                    if (!mounted) return;
                    await _loadSecureAccountStatus();
                  },
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  l10n.settingsChangePasswordTileTitle,
                  l10n.settingsChangePasswordTileSubtitle,
                  Icons.lock_outline,
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 32),
                _buildSettingsRow(
                  l10n.settingsSetPinTileTitle,
                  l10n.settingsSetPinTileSubtitle,
                  Icons.pin,
                  onTap: _showSetPinDialog,
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsRequirePinTileTitle,
                  l10n.settingsRequirePinTileSubtitle,
                  _requirePin,
                  saveAfterToggle: false,
                  onChanged: (value) {
                    _applyState(() => _requirePin = value);
                    _toggleRequirePin(value);
                  },
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsTwoFactorTitle,
                  l10n.settingsTwoFactorSubtitle,
                  _twoFactorAuth,
                  onChanged: (value) => _applyState(() => _twoFactorAuth = value),
                ),
                const Divider(height: 32),
                if (_hasPin && _biometricsSupported)
                  _buildToggleSetting(
                    l10n.settingsBiometricTileTitle,
                    l10n.settingsBiometricTileSubtitle,
                    _biometricAuth,
                    saveAfterToggle: false,
                    onChanged: (value) {
                      _applyState(() => _biometricAuth = value);
                      _toggleBiometric(value);
                    },
                  )
                else if (_hasPin && !_biometricsSupported)
                  _buildSettingsRow(
                    l10n.settingsBiometricTileTitle,
                    l10n.settingsBiometricUnavailableToast,
                    Icons.fingerprint,
                  ),
                if (_biometricAuth && _hasPin && _biometricsSupported) ...[
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsUseBiometricsOnUnlockTitle,
                    l10n.settingsUseBiometricsOnUnlockSubtitle,
                    _useBiometricsOnUnlock,
                    onChanged: (value) =>
                        _applyState(() => _useBiometricsOnUnlock = value),
                  ),
                ],
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsSessionTimeoutTitle,
                  l10n.settingsSessionTimeoutSubtitle,
                  _sessionTimeout,
                  onChanged: (value) => _applyState(() => _sessionTimeout = value),
                ),
                const Divider(height: 32),
                _buildAutoLockDropdown(),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsLoginNotificationsTitle,
                  l10n.settingsLoginNotificationsSubtitle,
                  _loginNotifications,
                  onChanged: (value) =>
                      _applyState(() => _loginNotifications = value),
                ),
                const Divider(height: 32),
                _buildToggleSetting(
                  l10n.settingsPrivacyModeTileTitle,
                  l10n.settingsPrivacyModeTileSubtitle,
                  _privacyMode,
                  onChanged: (value) => _applyState(() => _privacyMode = value),
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
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final definitions = achievement_svc
            .AchievementService.achievementDefinitions.values
            .toList(growable: false);
        final progressById = <String, AchievementProgress>{
          for (final progress in taskProvider.achievementProgress)
            progress.achievementId: progress,
        };

        bool isCompleted(achievement_svc.AchievementDefinition achievement) {
          final progress = progressById[achievement.id];
          if (progress == null) return false;
          final required =
              achievement.requiredCount > 0 ? achievement.requiredCount : 1;
          return progress.isCompleted || progress.currentProgress >= required;
        }

        int currentProgressFor(achievement_svc.AchievementDefinition achievement) {
          return progressById[achievement.id]?.currentProgress ?? 0;
        }

        int maxProgressForTypes(Set<achievement_svc.AchievementType> types) {
          var maxProgress = 0;
          for (final achievement in definitions) {
            if (!types.contains(achievement.type)) continue;
            final value = currentProgressFor(achievement);
            if (value > maxProgress) {
              maxProgress = value;
            }
          }
          return maxProgress;
        }

        final discoveryCount = maxProgressForTypes({
          achievement_svc.AchievementType.firstDiscovery,
          achievement_svc.AchievementType.artExplorer,
          achievement_svc.AchievementType.artMaster,
          achievement_svc.AchievementType.artLegend,
        });
        final arViews = maxProgressForTypes({
          achievement_svc.AchievementType.firstARView,
          achievement_svc.AchievementType.arEnthusiast,
          achievement_svc.AchievementType.arPro,
        });
        final eventCount = maxProgressForTypes({
          achievement_svc.AchievementType.eventAttendee,
          achievement_svc.AchievementType.galleryVisitor,
          achievement_svc.AchievementType.workshopParticipant,
        });

        final completedCount =
            definitions.where((achievement) => isCompleted(achievement)).length;
        final kub8Earned = definitions.fold<int>(
          0,
          (sum, achievement) =>
              sum + (isCompleted(achievement) ? achievement.tokenReward : 0),
        );
        final previewAchievements = definitions.take(9).toList(growable: false);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(KubusSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SharedSectionHeader(
                title: l10n.desktopSettingsAchievementsTitle,
                subtitle: l10n.userProfileAchievementsProgressLabel(
                  completedCount,
                  definitions.length,
                ),
                icon: Icons.emoji_events_outlined,
                iconColor: Provider.of<ThemeProvider>(context).accentColor,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: KubusSpacing.lg),
              DesktopGrid(
                minCrossAxisCount: 2,
                maxCrossAxisCount: 4,
                childAspectRatio: 1.8,
                spacing: KubusSpacing.md,
                children: [
                  KubusStatCard(
                    title: l10n.desktopSettingsAchievementsStatArtworksDiscovered,
                    value: discoveryCount.toString(),
                    icon: Icons.explore_outlined,
                    layout: KubusStatCardLayout.centered,
                    accent: KubusColorRoles.of(context).statBlue,
                    centeredWatermarkAlignment: Alignment.center,
                    centeredWatermarkScale: 0.84,
                    minHeight: 0,
                  ),
                  KubusStatCard(
                    title: l10n.desktopSettingsAchievementsStatArViews,
                    value: arViews.toString(),
                    icon: Icons.view_in_ar,
                    layout: KubusStatCardLayout.centered,
                    accent: KubusColorRoles.of(context).statTeal,
                    centeredWatermarkAlignment: Alignment.center,
                    centeredWatermarkScale: 0.84,
                    minHeight: 0,
                  ),
                  KubusStatCard(
                    title: l10n.desktopSettingsAchievementsStatEventsAttended,
                    value: eventCount.toString(),
                    icon: Icons.event_available,
                    layout: KubusStatCardLayout.centered,
                    accent: KubusColorRoles.of(context).web3InstitutionAccent,
                    centeredWatermarkAlignment: Alignment.center,
                    centeredWatermarkScale: 0.84,
                    minHeight: 0,
                  ),
                  KubusStatCard(
                    title: l10n.desktopSettingsAchievementsStatKub8PointsEarned,
                    value: kub8Earned.toString(),
                    icon: Icons.token,
                    layout: KubusStatCardLayout.centered,
                    accent: KubusColorRoles.of(context).web3MarketplaceAccent,
                    centeredWatermarkAlignment: Alignment.center,
                    centeredWatermarkScale: 0.84,
                    minHeight: 0,
                  ),
                ],
              ),
              const SizedBox(height: KubusSpacing.xl),
              Text(
                l10n.userProfileAchievementsTitle,
                style: KubusTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final maxColumns = width >= 1650
                      ? 5
                      : width >= 1320
                          ? 4
                          : 3;
                  final spacing = width >= 1320
                      ? KubusSpacing.lg
                      : KubusSpacing.md;
                  final columns = (width / 300)
                      .floor()
                      .clamp(1, maxColumns);
                  final cardWidth =
                      (width - (spacing * (columns - 1))) / columns;
                  final childAspectRatio = columns == 1
                      ? 2.45
                      : (cardWidth >= 280 ? 1.12 : 1.22);

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: previewAchievements.length,
                    itemBuilder: (context, index) {
                      final achievement = previewAchievements[index];
                      final required = achievement.requiredCount > 0
                          ? achievement.requiredCount
                          : 1;
                      final progress = currentProgressFor(achievement);
                      final unlocked = isCompleted(achievement);
                      final progressLabel = unlocked
                          ? '+${achievement.tokenReward} KUB8'
                          : '$progress/$required';
                      final roomyCard = cardWidth >= 280;
                      final compactCard = cardWidth < 220;

                      return KubusStatCard(
                        title: achievement.title,
                        value: progressLabel,
                        icon: AchievementUi.iconFor(achievement),
                        layout: KubusStatCardLayout.centered,
                        accent: AchievementUi.accentFor(context, achievement),
                        centeredWatermarkAlignment: Alignment.center,
                        centeredWatermarkScale: compactCard ? 0.80 : 0.84,
                        minHeight: 0,
                        padding: EdgeInsets.all(
                          roomyCard
                              ? KubusChromeMetrics.cardPadding
                              : KubusSpacing.md,
                        ),
                        titleMaxLines: roomyCard ? 3 : 2,
                        titleStyle: KubusTextStyles.detailCaption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: roomyCard ? 13 : 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: unlocked ? 0.84 : 0.7),
                        ),
                        valueStyle: KubusTextStyles.detailCardTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: roomyCard ? 15 : 14,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: KubusSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: DesktopActionButton(
                  label: l10n.commonViewAll,
                  icon: Icons.arrow_forward,
                  onPressed: () {
                    final shellScope = DesktopShellScope.of(context);
                    if (shellScope != null) {
                      shellScope.pushScreen(const AchievementsPage());
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AchievementsPage(),
                      ),
                    );
                  },
                  isPrimary: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpSettings() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(KubusSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KubusHeaderText(
            title: l10n.desktopSettingsHelpSupportTitle,
            subtitle: l10n.desktopSettingsHelpSupportSubtitle,
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
              ScaffoldMessenger.of(context).showKubusSnackBar(
                SnackBar(
                    content: Text(l10n.desktopSettingsOpeningBugReportToast)),
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
      padding: const EdgeInsets.all(KubusSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KubusHeaderText(
            title: l10n.settingsAboutSectionTitle,
            subtitle: l10n.desktopSettingsAboutSubtitle,
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
            style: KubusTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),

          _buildFeatureItem(
              Icons.view_in_ar,
              l10n.desktopSettingsFeatureArDiscoveryTitle,
              l10n.desktopSettingsFeatureArDiscoveryDescription),
          const SizedBox(height: KubusSpacing.md),
          _buildFeatureItem(
              Icons.account_balance_wallet,
              l10n.desktopSettingsFeatureWeb3IntegrationTitle,
              l10n.desktopSettingsFeatureWeb3IntegrationDescription),
          const SizedBox(height: KubusSpacing.md),
          _buildFeatureItem(
              Icons.auto_awesome,
              l10n.desktopSettingsFeatureNftMintingTitle,
              l10n.desktopSettingsFeatureNftMintingDescription),
          const SizedBox(height: KubusSpacing.md),
          _buildFeatureItem(
              Icons.groups,
              l10n.desktopSettingsFeatureCommunityTitle,
              l10n.desktopSettingsFeatureCommunityDescription),
          const SizedBox(height: KubusSpacing.md),
          _buildFeatureItem(
              Icons.museum,
              l10n.desktopSettingsFeatureInstitutionsTitle,
              l10n.desktopSettingsFeatureInstitutionsDescription),

          const SizedBox(height: KubusSpacing.xl),

          // Legal Links
          Text(
            l10n.desktopSettingsLegalSectionTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),

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
            style: KubusTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),

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

          const SizedBox(height: KubusSpacing.xl),

          // Copyright
          Center(
            child: Text(
              '\u00A9 2026 kubus \u2022 ${l10n.settingsAllRightsReserved}',
              style: KubusTextStyles.navMetaLabel.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    final accentColor = Provider.of<ThemeProvider>(context).accentColor;
    final scheme = Theme.of(context).colorScheme;
    return SharedSettingsRowTile(
      title: title,
      subtitle: description,
      icon: icon,
      showChevron: false,
      padding: EdgeInsets.zero,
      leadingBoxSize: KubusHeaderMetrics.searchBarHeight,
      leadingIconSize: KubusHeaderMetrics.actionIcon,
      leadingBackgroundColor: accentColor.withValues(alpha: 0.1),
      leadingIconColor: accentColor,
      titleStyle: KubusTextStyles.sectionTitle.copyWith(
        color: scheme.onSurface,
      ),
      subtitleStyle: KubusTextStyles.sectionSubtitle.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildSettingsRow(
    String title,
    String subtitle,
    IconData icon, {
    bool isDestructive = false,
    VoidCallback? onTap,
    Widget? trailing,
    Key? tileKey,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final errorColor = scheme.error;
    return SharedSettingsRowTile(
      tileKey: tileKey,
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
      trailing: trailing,
      isDestructive: isDestructive,
      showChevron: trailing == null,
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xs),
      borderRadius: BorderRadius.circular(KubusRadius.sm),
      leadingBoxSize: KubusHeaderMetrics.actionHitArea,
      leadingIconSize: KubusHeaderMetrics.actionIcon,
      leadingBackgroundColor: isDestructive
          ? errorColor.withValues(alpha: 0.1)
          : scheme.primaryContainer,
      leadingIconColor:
          isDestructive ? errorColor : scheme.onSurface.withValues(alpha: 0.7),
      titleStyle: KubusTextStyles.sectionTitle.copyWith(
        color: isDestructive ? errorColor : scheme.onSurface,
      ),
      subtitleStyle: KubusTextStyles.sectionSubtitle.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.5),
      ),
      chevronColor: scheme.onSurface.withValues(alpha: 0.3),
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
    final accentColor = Provider.of<ThemeProvider>(context).accentColor;
    return SharedSettingsToggleRow(
      switchKey: switchKey,
      title: title,
      subtitle: subtitle,
      value: initialValue,
      enabled: enabled,
      activeColor: accentColor,
      onChanged: enabled
          ? (value) {
              onChanged?.call(value);
              if (saveAfterToggle) {
                _saveSettings();
              }
            }
          : null,
      titleStyle: KubusTextStyles.sectionTitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
      subtitleStyle: KubusTextStyles.sectionSubtitle.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildAutoLockDropdown() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final options = <Map<String, dynamic>>[
      {
        'storedLabel': 'Immediately',
        'displayLabel': l10n.settingsAutoLockImmediately,
        'seconds': -1
      },
      {
        'storedLabel': '10 seconds',
        'displayLabel': l10n.settingsAutoLock10Seconds,
        'seconds': 10
      },
      {
        'storedLabel': '30 seconds',
        'displayLabel': l10n.settingsAutoLock30Seconds,
        'seconds': 30
      },
      {
        'storedLabel': '1 minute',
        'displayLabel': l10n.settingsAutoLock1Minute,
        'seconds': 60
      },
      {
        'storedLabel': '5 minutes',
        'displayLabel': l10n.settingsAutoLock5Minutes,
        'seconds': 5 * 60
      },
      {
        'storedLabel': '15 minutes',
        'displayLabel': l10n.settingsAutoLock15Minutes,
        'seconds': 15 * 60
      },
      {
        'storedLabel': '30 minutes',
        'displayLabel': l10n.settingsAutoLock30Minutes,
        'seconds': 30 * 60
      },
      {
        'storedLabel': '1 hour',
        'displayLabel': l10n.settingsAutoLock1Hour,
        'seconds': 60 * 60
      },
      {
        'storedLabel': '3 hours',
        'displayLabel': l10n.settingsAutoLock3Hours,
        'seconds': 3 * 60 * 60
      },
      {
        'storedLabel': '6 hours',
        'displayLabel': l10n.settingsAutoLock6Hours,
        'seconds': 6 * 60 * 60
      },
      {
        'storedLabel': '12 hours',
        'displayLabel': l10n.settingsAutoLock12Hours,
        'seconds': 12 * 60 * 60
      },
      {
        'storedLabel': '1 day',
        'displayLabel': l10n.settingsAutoLock1Day,
        'seconds': 24 * 60 * 60
      },
      {
        'storedLabel': 'Never',
        'displayLabel': l10n.settingsAutoLockNever,
        'seconds': 0
      },
    ];

    String displayLabelForStored(String storedLabel) {
      final match = options.cast<Map<String, dynamic>?>().firstWhere(
            (opt) => opt?['storedLabel'] == storedLabel,
            orElse: () => null,
          );
      return (match?['displayLabel'] as String?) ?? storedLabel;
    }

    return SharedSettingsRowTile(
      icon: Icons.lock_clock,
      title: l10n.settingsAutoLockTimeTitle,
      subtitle: displayLabelForStored(_autoLockTime),
      showChevron: false,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      leadingBoxSize: KubusHeaderMetrics.actionHitArea,
      leadingIconSize: KubusHeaderMetrics.actionIcon,
      leadingBackgroundColor: Colors.transparent,
      leadingIconColor: scheme.onSurface.withValues(alpha: 0.7),
      titleStyle: KubusTextStyles.sectionTitle.copyWith(
        fontSize: KubusChromeMetrics.profileName + 1,
        color: scheme.onSurface,
      ),
      subtitleStyle: KubusTextStyles.detailCaption.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.5),
      ),
      trailing: DropdownButton<String>(
        value: _autoLockTime,
        underline: const SizedBox.shrink(),
        dropdownColor: scheme.surface,
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
          final gate =
              Provider.of<SecurityGateProvider>(context, listen: false);
          _applyState(() {
            _autoLockTime = value;
          });
          await _saveSettings();
          await gate.reloadSettings();
        },
      ),
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
    );
  }
}
