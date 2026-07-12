part of '../desktop_settings_screen.dart';

// Extracted from desktop_settings_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _DesktopSettingsScreenStatePart2 on _DesktopSettingsScreenState {
  void _showDataExportDialog() {
    final l10n = AppLocalizations.of(context)!;
    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsExportDataDialogTitle,
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.settingsExportDataDialogBody,
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
                backgroundColor:
                    Provider.of<ThemeProvider>(context, listen: false)
                        .accentColor,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showKubusSnackBar(SnackBar(
                  content: Text(l10n.desktopSettingsExportingDataToast)));
            },
            child: Text(l10n.settingsExportButton),
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
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.settingsClearCacheDialogBody,
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
                backgroundColor:
                    Provider.of<ThemeProvider>(context, listen: false)
                        .accentColor,
                foregroundColor: Colors.white),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await SettingsService.clearNonCriticalCaches();
              if (!mounted) return;
              navigator.pop();
              messenger.showKubusSnackBar(
                  SnackBar(content: Text(l10n.settingsCacheClearedToast)));
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
    showKubusDialog(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsResetPermissionFlagsDialogTitle,
          style: KubusTextStyles.sheetTitle.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.settingsResetPermissionFlagsDialogBody,
          style: KubusTextStyles.detailBody.copyWith(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.commonCancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Provider.of<ThemeProvider>(dialogContext, listen: false)
                      .accentColor,
              foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _resetPermissionFlags();
              if (!mounted) return;
              messenger.showKubusSnackBar(SnackBar(
                  content: Text(l10n.settingsPermissionFlagsResetToast)));
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
          padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xl),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KubusHeaderText(
                  title: l10n.settingsPlatformFeaturesSectionTitle,
                  subtitle: l10n.desktopSettingsPlatformSubtitle,
                ),
                const SizedBox(height: KubusSpacing.lg),
                ...platformProvider.capabilities.entries.map((entry) {
                  final capability = entry.key;
                  final isAvailable = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: KubusSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          isAvailable ? Icons.check_circle : Icons.cancel,
                          color: isAvailable
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.error,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getCapabilityDisplayName(l10n, capability),
                                style: KubusTextStyles.sectionTitle.copyWith(
                                  fontSize: KubusHeaderMetrics.screenSubtitle,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                isAvailable
                                    ? l10n.commonAvailable
                                    : l10n.commonNotAvailable,
                                style: KubusTextStyles.navMetaLabel.copyWith(
                                  color: isAvailable
                                      ? Theme.of(context).colorScheme.tertiary
                                      : Theme.of(context).colorScheme.error,
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
        await _saveSettings();
        return;
      }
      await notificationProvider.initialize(force: true);
    } else {
      await PushNotificationService().cancelAllNotifications();
      notificationProvider.reset();
    }
    if (!mounted) return;
    _applyState(() => _pushNotifications = value);
    await _saveSettings();
  }

  Future<void> _toggleBiometric(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final gate = Provider.of<SecurityGateProvider>(context, listen: false);
    if (value) {
      final hasPin = await walletProvider.hasPin();
      if (!hasPin) {
        if (mounted) {
          _applyState(() => _biometricAuth = false);
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(content: Text(l10n.settingsPinSetFailedToast)),
          );
        }
        await _saveSettings();
        await gate.reloadSettings();
        return;
      }
      final canUse = await walletProvider.canUseBiometrics();
      if (!canUse) {
        if (mounted) {
          _applyState(() => _biometricAuth = false);
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(content: Text(l10n.settingsBiometricUnavailableToast)),
          );
        }
        await _saveSettings();
        await gate.reloadSettings();
        return;
      }
      final ok = await walletProvider.authenticateWithBiometrics();
      if (!ok) {
        if (mounted) {
          _applyState(() => _biometricAuth = false);
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(content: Text(l10n.settingsBiometricFailedToast)),
          );
        }
        await _saveSettings();
        await gate.reloadSettings();
        return;
      }
    }
    if (!mounted) return;
    _applyState(() {
      _biometricAuth = value;
      if (!value) {
        _useBiometricsOnUnlock = true;
      }
      if (value) {
        _biometricsDeclined = false;
      }
    });
    await _saveSettings();
    await gate.reloadSettings();
  }

  Future<void> _toggleRequirePin(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final gate = Provider.of<SecurityGateProvider>(context, listen: false);

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
        _applyState(() => _requirePin = false);
        await _saveSettings();
        await gate.reloadSettings();
        return;
      }
      _applyState(() => _requirePin = true);
      await _saveSettings();
      await gate.reloadSettings();
      return;
    }

    await gate.lock(SecurityLockReason.sensitiveAction);
    final settled = await gate.waitForResolution();
    if (settled == null || !settled.isSuccess) {
      if (mounted) _applyState(() => _requirePin = true);
      return;
    }

    if (!mounted) return;
    _applyState(() => _requirePin = false);
    await _saveSettings();
    await gate.reloadSettings();
  }

  Future<void> _showSetPinDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final gate = Provider.of<SecurityGateProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    await showKubusDialog<void>(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsSetPinDialogTitle,
          style: KubusTextStyles.sheetTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
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
            child: Text(
              l10n.commonCancel,
              style: KubusTextStyles.navLabel.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              await gate.lock(SecurityLockReason.sensitiveAction);
              final settled = await gate.waitForResolution();
              if (settled == null || !settled.isSuccess) {
                return;
              }

              await walletProvider.clearPin();
              if (!mounted) return;
              _applyState(() {
                _requirePin = false;
                _biometricAuth = false;
                _useBiometricsOnUnlock = true;
                _hasPin = false;
              });
              await _saveSettings();
              await gate.reloadSettings();
              navigator.pop();
              messenger.showKubusSnackBar(
                  SnackBar(content: Text(l10n.settingsPinClearedToast)));
            },
            child: Text(
              l10n.settingsClearPinButton,
              style: KubusTextStyles.navLabel.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: themeProvider.accentColor),
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
                _applyState(() {
                  _hasPin = hasPin;
                  _biometricsSupported = biometricsSupported;
                });
                await gate.reloadSettings();
                navigator.pop();
                messenger.showKubusSnackBar(
                    SnackBar(content: Text(l10n.settingsPinSetSuccessToast)));
              } catch (_) {
                if (!mounted) return;
                messenger.showKubusSnackBar(
                    SnackBar(content: Text(l10n.settingsPinSetFailedToast)));
              }
            },
            child: Text(
              l10n.commonSave,
              style: KubusTextStyles.navLabel.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
        title: Text(
          l10n.settingsLogoutDialogTitle,
          style: KubusTextStyles.sheetTitle.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.settingsLogoutDialogBody,
          style: KubusTextStyles.detailBody.copyWith(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              l10n.commonCancel,
              style: KubusTextStyles.navLabel.copyWith(
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
      savedItemsProvider: Provider.of<SavedItemsProvider>(context, listen: false),
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

  Widget _buildDangerZoneSettings() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xl),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KubusHeaderText(
              title: l10n.settingsDangerZoneSectionTitle,
              subtitle: l10n.desktopSettingsDangerZoneSubtitle,
              titleColor: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: KubusSpacing.lg),
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
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KubusHeaderText(
            title: l10n.settingsAppearanceSectionTitle,
            subtitle: l10n.desktopSettingsAppearanceSubtitle,
          ),
          const SizedBox(height: KubusSpacing.lg),

          // Theme mode
          DesktopCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsThemeModeTitle,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
                Row(
                  children: [
                    _buildThemeModeOption(
                        l10n.settingsThemeModeLight,
                        Icons.light_mode,
                        !themeProvider.isDarkMode &&
                            !themeProvider.isSystemMode, () {
                      themeProvider.setThemeMode(ThemeMode.light);
                    }),
                    const SizedBox(width: 12),
                    _buildThemeModeOption(
                        l10n.settingsThemeModeDark,
                        Icons.dark_mode,
                        themeProvider.isDarkMode && !themeProvider.isSystemMode,
                        () {
                      themeProvider.setThemeMode(ThemeMode.dark);
                    }),
                    const SizedBox(width: 12),
                    _buildThemeModeOption(l10n.settingsThemeModeSystem,
                        Icons.settings_suggest, themeProvider.isSystemMode, () {
                      themeProvider.setThemeMode(ThemeMode.system);
                    }),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: KubusSpacing.lg),

          // Accent color
          DesktopCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsAccentColorTitle,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
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
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
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
                        style: KubusTextStyles.sectionTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(
                          height: KubusSpacing.sm - KubusSpacing.xxs),
                      Text(
                        l10n.settingsLanguageDescription,
                        style: KubusTextStyles.sectionSubtitle.copyWith(
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

          const SizedBox(height: KubusSpacing.lg),

          // Reduce effects
          Builder(
            builder: (context) {
              final glassProv = context.watch<GlassCapabilitiesProvider>();
              final isOn = glassProv.reduceEffects;
              final autoDetected = glassProv.autoReduceEffectsApplied;

              return DesktopCard(
                child: Row(
                  children: [
                    Icon(
                      Icons.blur_off,
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reduce effects',
                            style: KubusTextStyles.sectionTitle.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: KubusSpacing.xs),
                          Text(
                            autoDetected
                                ? 'Automatically enabled for this device'
                                : 'Disable blur, animations and other effects',
                            style: KubusTextStyles.detailCaption.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isOn,
                      onChanged: (value) {
                        glassProv.setReduceEffects(value);
                      },
                      activeTrackColor:
                          Provider.of<ThemeProvider>(context, listen: false)
                              .accentColor
                              .withValues(alpha: 0.5),
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Provider.of<ThemeProvider>(context,
                                  listen: false)
                              .accentColor;
                        }
                        return null;
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(
      String label, IconData icon, bool isSelected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    final themeColor = scheme.tertiary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KubusRadius.md),
          child: Container(
            padding: const EdgeInsets.all(KubusChromeMetrics.cardPadding),
            decoration: BoxDecoration(
              color: isSelected
                  ? themeColor.withValues(alpha: 0.1)
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(KubusRadius.md),
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
                  style: KubusTextStyles.navLabel.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? themeColor : scheme.onSurface,
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
    final emailPreferencesProvider = context.watch<EmailPreferencesProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final notificationPreferences =
        profileProvider.preferences.notificationPreferences;
    Future<void> persistEmailPreferences(EmailPreferences next) async {
      final ok = await emailPreferencesProvider.updatePreferences(next);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(l10n.settingsEmailPreferencesUpdateFailedToast),
          ),
        );
      }
    }

    Future<void> persistNotificationPreferences(
      NotificationPreferenceSettings next,
    ) async {
      await profileProvider.updateNotificationPreferences(next);
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.permissionsNotificationsTitle,
              style: KubusTextStyles.screenTitle.copyWith(
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
                      _applyState(() => _pushNotifications = value);
                      _togglePushNotifications(value);
                    },
                  ),
                  const Divider(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.settingsEmailPreferencesSectionTitle,
                      style: KubusTextStyles.detailCardTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.settingsEmailPreferencesTransactionalNote,
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  if (emailPreferencesProvider.isLoading) ...[
                    const SizedBox(height: 12),
                    InlineLoading(height: 2, borderRadius: BorderRadius.circular(2), color: Provider.of<ThemeProvider>(context, listen: false)
                            .accentColor,),
                  ],
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsEmailPreferencesProductUpdatesTitle,
                    l10n.settingsEmailPreferencesProductUpdatesSubtitle,
                    emailPreferencesProvider.preferences.marketingProductUpdates,
                    saveAfterToggle: false,
                    enabled: emailPreferencesProvider.canManage &&
                        !emailPreferencesProvider.isUpdating,
                    onChanged: (value) {
                      final next = emailPreferencesProvider.preferences
                          .copyWith(marketingProductUpdates: value);
                      unawaited(persistEmailPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsEmailPreferencesNewsletterTitle,
                    l10n.settingsEmailPreferencesNewsletterSubtitle,
                    emailPreferencesProvider.preferences.marketingNewsletter,
                    saveAfterToggle: false,
                    enabled: emailPreferencesProvider.canManage &&
                        !emailPreferencesProvider.isUpdating,
                    onChanged: (value) {
                      final next = emailPreferencesProvider.preferences
                          .copyWith(marketingNewsletter: value);
                      unawaited(persistEmailPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsEmailPreferencesCommunityDigestTitle,
                    l10n.settingsEmailPreferencesCommunityDigestSubtitle,
                    emailPreferencesProvider
                        .preferences.marketingCommunityDigest,
                    saveAfterToggle: false,
                    enabled: emailPreferencesProvider.canManage &&
                        !emailPreferencesProvider.isUpdating,
                    onChanged: (value) {
                      final next = emailPreferencesProvider.preferences
                          .copyWith(marketingCommunityDigest: value);
                      unawaited(persistEmailPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsEmailPreferencesActivityArtTitle,
                    l10n.settingsEmailPreferencesActivityArtSubtitle,
                    emailPreferencesProvider.preferences.activityArt,
                    saveAfterToggle: false,
                    enabled: emailPreferencesProvider.canManage &&
                        !emailPreferencesProvider.isUpdating,
                    onChanged: (value) {
                      final next = emailPreferencesProvider.preferences
                          .copyWith(activityArt: value);
                      unawaited(persistEmailPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsEmailPreferencesActivityCommunityTitle,
                    l10n.settingsEmailPreferencesActivityCommunitySubtitle,
                    emailPreferencesProvider.preferences.activityCommunity,
                    saveAfterToggle: false,
                    enabled: emailPreferencesProvider.canManage &&
                        !emailPreferencesProvider.isUpdating,
                    onChanged: (value) {
                      final next = emailPreferencesProvider.preferences
                          .copyWith(activityCommunity: value);
                      unawaited(persistEmailPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsEmailPreferencesActivityDaoTitle,
                    l10n.settingsEmailPreferencesActivityDaoSubtitle,
                    emailPreferencesProvider.preferences.activityDao,
                    saveAfterToggle: false,
                    enabled: emailPreferencesProvider.canManage &&
                        !emailPreferencesProvider.isUpdating,
                    onChanged: (value) {
                      final next = emailPreferencesProvider.preferences
                          .copyWith(activityDao: value);
                      unawaited(persistEmailPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsEmailPreferencesActivityArtistHubTitle,
                    l10n.settingsEmailPreferencesActivityArtistHubSubtitle,
                    emailPreferencesProvider.preferences.activityArtistHub,
                    saveAfterToggle: false,
                    enabled: emailPreferencesProvider.canManage &&
                        !emailPreferencesProvider.isUpdating,
                    onChanged: (value) {
                      final next = emailPreferencesProvider.preferences
                          .copyWith(activityArtistHub: value);
                      unawaited(persistEmailPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsEmailPreferencesActivityInstitutionHubTitle,
                    l10n.settingsEmailPreferencesActivityInstitutionHubSubtitle,
                    emailPreferencesProvider.preferences.activityInstitutionHub,
                    saveAfterToggle: false,
                    enabled: emailPreferencesProvider.canManage &&
                        !emailPreferencesProvider.isUpdating,
                    onChanged: (value) {
                      final next = emailPreferencesProvider.preferences
                          .copyWith(activityInstitutionHub: value);
                      unawaited(persistEmailPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsEmailPreferencesActivityPromotionTitle,
                    l10n.settingsEmailPreferencesActivityPromotionSubtitle,
                    emailPreferencesProvider.preferences.activityPromotion,
                    saveAfterToggle: false,
                    enabled: emailPreferencesProvider.canManage &&
                        !emailPreferencesProvider.isUpdating,
                    onChanged: (value) {
                      final next =
                          emailPreferencesProvider.preferences.copyWith(
                        activityPromotion: value,
                      );
                      unawaited(persistEmailPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n
                                  .settingsEmailPreferencesCriticalAccountSecurityTitle,
                              style: KubusTextStyles.sectionTitle.copyWith(
                                fontSize: KubusChromeMetrics.profileName + 1,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              l10n
                                  .settingsEmailPreferencesCriticalAccountSecuritySubtitle,
                              style: KubusTextStyles.detailCaption.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: true,
                        onChanged: null,
                        activeTrackColor: Provider.of<ThemeProvider>(context)
                            .accentColor
                            .withValues(alpha: 0.5),
                        thumbColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Provider.of<ThemeProvider>(context,
                                    listen: false)
                                .accentColor;
                          }
                          return null;
                        }),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n
                                  .settingsEmailPreferencesCriticalWalletSecurityTitle,
                              style: KubusTextStyles.sectionTitle.copyWith(
                                fontSize: KubusChromeMetrics.profileName + 1,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              l10n
                                  .settingsEmailPreferencesCriticalWalletSecuritySubtitle,
                              style: KubusTextStyles.detailCaption.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: true,
                        onChanged: null,
                        activeTrackColor: Provider.of<ThemeProvider>(context)
                            .accentColor
                            .withValues(alpha: 0.5),
                        thumbColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Provider.of<ThemeProvider>(context,
                                    listen: false)
                                .accentColor;
                          }
                          return null;
                        }),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsEmailPreferencesTransactionalTitle,
                              style: KubusTextStyles.sectionTitle.copyWith(
                                fontSize: KubusChromeMetrics.profileName + 1,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              l10n.settingsEmailPreferencesTransactionalSubtitle,
                              style: KubusTextStyles.detailCaption.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: true,
                        onChanged: null,
                        activeTrackColor: Provider.of<ThemeProvider>(context)
                            .accentColor
                            .withValues(alpha: 0.5),
                        thumbColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Provider.of<ThemeProvider>(context,
                                    listen: false)
                                .accentColor;
                          }
                          return null;
                        }),
                      ),
                    ],
                  ),
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
                    l10n.settingsInAppNotificationsMasterTitle,
                    l10n.settingsInAppNotificationsMasterSubtitle,
                    notificationPreferences.enabled,
                    saveAfterToggle: false,
                    onChanged: (value) {
                      final next =
                          notificationPreferences.copyWith(enabled: value);
                      unawaited(persistNotificationPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsInAppNotificationsArtTitle,
                    l10n.settingsInAppNotificationsArtSubtitle,
                    notificationPreferences.art,
                    saveAfterToggle: false,
                    enabled: notificationPreferences.enabled,
                    onChanged: (value) {
                      final next = notificationPreferences.copyWith(art: value);
                      unawaited(persistNotificationPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsInAppNotificationsCommunityTitle,
                    l10n.settingsInAppNotificationsCommunitySubtitle,
                    notificationPreferences.community,
                    saveAfterToggle: false,
                    enabled: notificationPreferences.enabled,
                    onChanged: (value) {
                      final next =
                          notificationPreferences.copyWith(community: value);
                      unawaited(persistNotificationPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsInAppNotificationsDaoTitle,
                    l10n.settingsInAppNotificationsDaoSubtitle,
                    notificationPreferences.dao,
                    saveAfterToggle: false,
                    enabled: notificationPreferences.enabled,
                    onChanged: (value) {
                      final next = notificationPreferences.copyWith(dao: value);
                      unawaited(persistNotificationPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsInAppNotificationsArtistHubTitle,
                    l10n.settingsInAppNotificationsArtistHubSubtitle,
                    notificationPreferences.artistHub,
                    saveAfterToggle: false,
                    enabled: notificationPreferences.enabled,
                    onChanged: (value) {
                      final next =
                          notificationPreferences.copyWith(artistHub: value);
                      unawaited(persistNotificationPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsInAppNotificationsInstitutionHubTitle,
                    l10n.settingsInAppNotificationsInstitutionHubSubtitle,
                    notificationPreferences.institutionHub,
                    saveAfterToggle: false,
                    enabled: notificationPreferences.enabled,
                    onChanged: (value) {
                      final next = notificationPreferences.copyWith(
                        institutionHub: value,
                      );
                      unawaited(persistNotificationPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsInAppNotificationsAccountTitle,
                    l10n.settingsInAppNotificationsAccountSubtitle,
                    notificationPreferences.account,
                    saveAfterToggle: false,
                    enabled: notificationPreferences.enabled,
                    onChanged: (value) {
                      final next =
                          notificationPreferences.copyWith(account: value);
                      unawaited(persistNotificationPreferences(next));
                    },
                  ),
                  const Divider(height: 32),
                  _buildToggleSetting(
                    l10n.settingsInAppNotificationsPromotionTitle,
                    l10n.settingsInAppNotificationsPromotionSubtitle,
                    notificationPreferences.promotion,
                    saveAfterToggle: false,
                    enabled: notificationPreferences.enabled,
                    onChanged: (value) {
                      final next =
                          notificationPreferences.copyWith(promotion: value);
                      unawaited(persistNotificationPreferences(next));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
