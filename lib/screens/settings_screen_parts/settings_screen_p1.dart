part of '../settings_screen.dart';

// Extracted from settings_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _SettingsScreenStatePart1 on _SettingsScreenState {
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

  Widget _buildAppBar(AppLocalizations l10n) {
    final roles = KubusColorRoles.of(context);
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: roles.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: Border(
        bottom: BorderSide(color: roles.rule, width: KubusSizes.hairline),
      ),
      title: KubusHeaderText(
        title: l10n.settingsTitle,
        kind: KubusHeaderKind.screen,
        titleColor: Theme.of(context).colorScheme.onSurface,
        maxTitleLines: 1,
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          size: KubusHeaderMetrics.actionIcon,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildUserSection(AppLocalizations l10n) {
    final web3Provider = Provider.of<Web3Provider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final access = WalletSessionAccessSnapshot.fromProviders(
      profileProvider: profileProvider,
      walletProvider: walletProvider,
    );
    final roles = KubusColorRoles.of(context);
    final textTheme = Theme.of(context).textTheme;

    // Flat identity summary. Balances belong to the wallet screen; the
    // settings header only states who is signed in and the session state.
    return _buildSettingsPanel(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Row(
        children: [
          AvatarWidget(
            wallet: profileProvider.currentUser?.walletAddress ?? '',
            avatarUrl: profileProvider.currentUser?.avatar,
            radius: 26,
            cornerRadiusFactor: AvatarWidget.defaultCornerRadiusFactor,
            enableProfileNavigation: false,
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profileProvider.currentUser?.displayName ??
                      l10n.settingsGuestUserName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: roles.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xxs),
                if (walletProvider.hasWalletIdentity) ...[
                  Text(
                    web3Provider.formatAddress(
                      walletProvider.currentWalletAddress ?? '',
                    ),
                    style: KubusTextStyles.machineValue.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                  Text(
                    access.settingsStatusSummary(l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                  if (walletProvider.isReadOnlySession)
                    Text(
                      l10n.walletReconnectManualRequiredToast,
                      style: textTheme.bodySmall?.copyWith(
                        color: roles.warning,
                      ),
                    ),
                ] else
                  Text(
                    l10n.settingsNoWalletConnected,
                    style: textTheme.bodySmall?.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Structural group heading (Space Mono register) above related sections.
  Widget _buildSettingsGroupHeading(String label) {
    final roles = KubusColorRoles.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: KubusTextStyles.structuralLabel.copyWith(
            color: roles.foregroundMuted,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSection(AppLocalizations l10n) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final scheme = Theme.of(context).colorScheme;

    return _buildSection(
      l10n.settingsAppearanceSectionTitle,
      [
        _buildThemeModeTile(l10n, themeProvider),
        const SizedBox(height: 12),
        _buildAccentColorTile(l10n, themeProvider),
        const SizedBox(height: 12),
        _buildReduceEffectsTile(scheme),
      ],
    );
  }

  Widget _buildLanguageSection(AppLocalizations l10n) {
    final localeProvider = context.watch<LocaleProvider>();

    return _buildSection(
      l10n.settingsLanguageTitle,
      [
        _buildSettingsPanel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsLanguageTitle,
                      style: KubusTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.settingsLanguageDescription,
                      style: KubusTypography.inter(
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
    return _buildSettingsPanel(
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
                style: KubusTypography.inter(
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
          vertical: isSmallScreen ? KubusSpacing.md : KubusSpacing.sm,
          horizontal: isSmallScreen ? KubusSpacing.md : KubusSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? themeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
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
                    size: KubusHeaderMetrics.actionIcon,
                  ),
                  const SizedBox(width: KubusSpacing.md),
                  Text(
                    label,
                    style: KubusTextStyles.navLabel.copyWith(
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
                    size: KubusHeaderMetrics.actionIcon,
                  ),
                  const SizedBox(height: KubusSpacing.xs),
                  Text(
                    label,
                    style: KubusTextStyles.navMetaLabel.copyWith(
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
    return _buildSettingsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.color_lens,
                color: scheme.tertiary,
                size: KubusHeaderMetrics.actionIcon,
              ),
              const SizedBox(width: KubusSpacing.md),
              Text(
                l10n.settingsAccentColorTitle,
                style: KubusTextStyles.sectionTitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          Wrap(
            spacing: KubusSpacing.md,
            runSpacing: KubusSpacing.md,
            children: ThemeProvider.availableAccentColors.map((color) {
              final isSelected = themeProvider.accentColor == color;
              return GestureDetector(
                onTap: () => themeProvider.setAccentColor(color),
                child: Container(
                  width: KubusHeaderMetrics.searchBarHeight - 4,
                  height: KubusHeaderMetrics.searchBarHeight - 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(KubusRadius.lg),
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

  Widget _buildReduceEffectsTile(ColorScheme scheme) {
    final glassProv = context.watch<GlassCapabilitiesProvider?>();
    final isOn = glassProv?.reduceEffects ?? false;
    final autoDetected = glassProv?.autoReduceEffectsApplied ?? false;

    return _buildSettingsPanel(
      child: Row(
        children: [
          Icon(
            Icons.blur_off,
            color: scheme.tertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.settingsReduceEffectsTitle,
                  style: KubusTypography.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  autoDetected
                      ? AppLocalizations.of(context)!
                          .settingsReduceEffectsAutoSubtitle
                      : AppLocalizations.of(context)!
                          .settingsReduceEffectsSubtitle,
                  style: KubusTypography.inter(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOn,
            onChanged: glassProv == null
                ? null
                : (value) {
                    glassProv.setReduceEffects(value);
                  },
            activeTrackColor: Provider.of<ThemeProvider>(context, listen: false)
                .accentColor
                .withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Provider.of<ThemeProvider>(context, listen: false)
                    .accentColor;
              }
              return null;
            }),
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
          [
            _buildSettingsPanel(
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
                        style: KubusTypography.inter(
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
                    style: KubusTypography.inter(
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
                              style: KubusTypography.inter(
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
    final artistRole = profileProvider.currentUser?.isArtist ?? false;
    final institutionRole = profileProvider.currentUser?.isInstitution ?? false;
    final roleSummary = l10n.settingsRoleSummary(
      artistRole ? l10n.commonOn : l10n.commonOff,
      institutionRole ? l10n.commonOn : l10n.commonOff,
    );

    final managedEmailEnabled =
        emailPreferencesProvider.preferences.marketingProductUpdates ||
            emailPreferencesProvider.preferences.marketingNewsletter ||
            emailPreferencesProvider.preferences.marketingCommunityDigest ||
            emailPreferencesProvider.preferences.activityArt ||
            emailPreferencesProvider.preferences.activityCommunity ||
            emailPreferencesProvider.preferences.activityDao ||
            emailPreferencesProvider.preferences.activityArtistHub ||
            emailPreferencesProvider.preferences.activityInstitutionHub ||
            emailPreferencesProvider.preferences.activityPromotion;
    final emailNotificationsState = emailPreferencesProvider.canManage
        ? (managedEmailEnabled ? l10n.commonOn : l10n.commonOff)
        : (_emailNotifications ? l10n.commonOn : l10n.commonOff);
    return _buildSection(
      l10n.settingsProfileSectionTitle,
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
          l10n.authSecureAccountTitle,
          _secureAccountSubtitle(l10n),
          Icons.lock_outline,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmailVerificationStatusBadge(
                dense: true,
                alignment: Alignment.centerRight,
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
              ),
            ],
          ),
          onTap: () async {
            await Navigator.of(context).pushNamed('/secure-account');
            if (!mounted) return;
            await _loadSecureAccountStatus();
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
              final walletProvider =
                  Provider.of<WalletProvider>(context, listen: false);
              final walletAddress =
                  (walletProvider.currentWalletAddress ?? '').trim();
              if (walletProvider.hasWalletIdentity &&
                  walletAddress.isNotEmpty) {
                await profileProvider.loadProfile(walletAddress);
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
          tileKey: const Key('settings_tile_account_management'),
          onTap: () {
            _showAccountManagementDialog();
          },
        ),
        if (kDebugMode)
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
    if (!kDebugMode) return;
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
          builder: (context, setState) => KeyboardInsetPadding(
            extraBottom: 24,
            child: Container(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KubusRadius.lg + KubusRadius.xs)),
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
                    style: KubusTypography.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.settingsRoleSimulationSheetSubtitle,
                    style: KubusTypography.inter(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      l10n.settingsRoleArtistTitle,
                      style: KubusTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      l10n.settingsRoleArtistSubtitle,
                      style: KubusTypography.inter(fontSize: 13),
                    ),
                    value: artist,
                    activeThumbColor: KubusColorRoles.of(context).active,
                    onChanged: (val) {
                      _applyState(() => artist = val);
                      profileProvider.setRoleFlags(
                        isArtist: val,
                        isInstitution: institution,
                      );
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      l10n.settingsRoleInstitutionTitle,
                      style: KubusTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      l10n.settingsRoleInstitutionSubtitle,
                      style: KubusTypography.inter(fontSize: 13),
                    ),
                    value: institution,
                    activeThumbColor: KubusColorRoles.of(context).active,
                    onChanged: (val) {
                      _applyState(() => institution = val);
                      profileProvider.setRoleFlags(
                        isArtist: artist,
                        isInstitution: val,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalletSection(AppLocalizations l10n) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final profileProvider = Provider.of<ProfileProvider>(context);
    final access = WalletSessionAccessSnapshot.fromProviders(
      profileProvider: profileProvider,
      walletProvider: walletProvider,
    );
    final scheme = Theme.of(context).colorScheme;
    final walletStatusLabel = access.settingsStatusSummary(l10n);
    return _buildSection(
      l10n.settingsWalletSectionTitle,
      [
        _buildSettingsTile(
          l10n.settingsWalletConnectionTileTitle,
          walletStatusLabel,
          Icons.link,
          tileKey: const Key('settings_tile_wallet_connection'),
          onTap: () async {
            if (walletProvider.isReadOnlySession) {
              await _handleReadOnlyWalletReconnect(walletProvider);
              return;
            }
            if (walletProvider.hasWalletIdentity) {
              unawaited(walletProvider.disconnectWallet());
            } else {
              unawaited(
                WalletActionGuard.ensureSignerAccess(
                  context: context,
                  profileProvider: profileProvider,
                  walletProvider: walletProvider,
                  returnRoute: '/settings',
                ),
              );
            }
          },
          trailing: walletProvider.hasWalletIdentity
              ? Icon(
                  walletProvider.isReadOnlySession
                      ? Icons.visibility
                      : Icons.check_circle,
                  color: AppColorUtils.amberAccent,
                )
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
        if (AppConfig.isFeatureEnabled('availabilityNodes'))
          _buildSettingsTile(
            _availabilityNodeNavTitle(context),
            _availabilityNodeNavSubtitle(context),
            Icons.dns_outlined,
            onTap: () =>
                Navigator.of(context).pushNamed('/wallet/availability-node'),
          ),
        _buildSettingsTile(
          l10n.settingsBackupSettingsTileTitle,
          _walletBackupSummary(l10n),
          Icons.backup,
          onTap: () {
            unawaited(_showBackupDialog());
          },
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
        const SizedBox(height: KubusSpacing.sm),
        WalletCustodyStatusPanel(
          authority: walletProvider.authority,
          compact: true,
          onRestoreSigner: walletProvider
                  .authority.canRestoreFromEncryptedBackup
              ? () => unawaited(_handleReadOnlyWalletReconnect(walletProvider))
              : null,
          onConnectExternalWallet: !walletProvider.authority.canTransact
              ? () => WalletActionGuard.ensureSignerAccess(
                    context: context,
                    profileProvider: profileProvider,
                    walletProvider: walletProvider,
                    returnRoute: '/settings',
                  )
              : null,
        ),
      ],
    );
  }

  String _availabilityNodeNavTitle(BuildContext context) {
    return AppLocalizations.of(context)!.availabilityNodeNavTitle;
  }

  String _availabilityNodeNavSubtitle(BuildContext context) {
    return AppLocalizations.of(context)!.availabilityNodeNavSubtitle;
  }

  Widget _buildSecuritySection(AppLocalizations l10n) {
    final canShowBiometricsToggle = _hasPin && _biometricsSupported;
    return _buildSection(
      l10n.settingsSecurityPrivacySectionTitle,
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
            activeThumbColor: KubusColorRoles.of(context).active,
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
              activeThumbColor: KubusColorRoles.of(context).active,
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
                _applyState(() => _useBiometricsOnUnlock = value);
                unawaited(
                    _saveAllSettings().then((_) => gate.reloadSettings()));
              },
              activeThumbColor: KubusColorRoles.of(context).active,
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
              _applyState(() {
                _privacyMode = value;
              });
              _saveAllSettings();
            },
            activeThumbColor: KubusColorRoles.of(context).active,
          ),
        ),
        _buildSettingsTile(
          l10n.settingsClearCacheTileTitle,
          l10n.settingsClearCacheTileSubtitle,
          Icons.clear_all,
          onTap: () => _showClearCacheDialog(),
        ),
      ],
    );
  }
}
