part of '../settings_screen.dart';

// Extracted from settings_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _SettingsScreenStatePart2 on _SettingsScreenState {
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
              _applyState(() {
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
              _applyState(() {
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
              _applyState(() {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SharedSectionHeader(
          title: title,
          icon: icon,
          iconColor: sectionColor,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildSettingsPanel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(KubusSpacing.md),
    BorderRadius? borderRadius,
    Color? tintBase,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final style = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.card,
      tintBase: tintBase ?? scheme.surface,
    );
    return LiquidGlassPanel(
      padding: padding,
      margin: EdgeInsets.zero,
      borderRadius: borderRadius ?? BorderRadius.circular(KubusRadius.md),
      blurSigma: style.blurSigma,
      backgroundColor: style.tintColor,
      fallbackMinOpacity: style.fallbackMinOpacity,
      child: child,
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
    final scheme = Theme.of(context).colorScheme;
    final tintBase = isDestructive
        ? Color.lerp(scheme.surface, scheme.errorContainer, 0.32)
        : scheme.surface;
    final accentColor = Provider.of<ThemeProvider>(context).accentColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: _buildSettingsPanel(
        tintBase: tintBase,
        padding: EdgeInsets.zero,
        child: SharedSettingsRowTile(
          tileKey: tileKey,
          title: title,
          subtitle: subtitle,
          icon: icon,
          onTap: onTap,
          trailing: trailing,
          isDestructive: isDestructive,
          showChevron: trailing == null,
          backgroundColor: tintBase,
          borderColor: isDestructive
              ? Colors.red.withValues(alpha: 0.3)
              : scheme.outline,
          leadingBackgroundColor: Colors.transparent,
          leadingBorderColor: Colors.transparent,
          leadingIconColor: isDestructive ? Colors.red : accentColor,
          titleStyle: KubusTypography.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.red : scheme.onSurface,
          ),
          subtitleStyle: KubusTypography.inter(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  // Dialog methods
  void _showNetworkDialog() {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final currentNetwork = walletProvider.currentSolanaNetwork.toLowerCase();

    showKubusDialog(
      context: context,
      builder: (context) => KubusAlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          l10n.settingsSelectNetworkDialogTitle,
          style: KubusTypography.inter(
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
                walletProvider.switchSolanaNetwork('Mainnet');
                _applyState(() {
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
                walletProvider.switchSolanaNetwork('Devnet');
                _applyState(() {
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
                walletProvider.switchSolanaNetwork('Testnet');
                _applyState(() {
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
              style: KubusTypography.inter(
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
      borderRadius: BorderRadius.circular(KubusRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(KubusSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Provider.of<ThemeProvider>(context).accentColor
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(KubusRadius.sm),
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
            const SizedBox(width: KubusSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: KubusTextStyles.navLabel.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: KubusTypography.inter(
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

  Future<void> _showBackupDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    if (!walletProvider.hasWalletIdentity) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.settingsConnectWalletFirstToast)),
      );
      return;
    }
    await _navigateToRecoveryReveal(walletProvider);
  }

  Future<void> _navigateToRecoveryReveal(WalletProvider walletProvider) async {
    final l10n = AppLocalizations.of(context)!;
    final hasWallet = walletProvider.wallet != null ||
        (walletProvider.currentWalletAddress ?? '').isNotEmpty;
    if (!hasWallet) {
      ScaffoldMessenger.of(context).showKubusSnackBar(SnackBar(
          content: Text(l10n.settingsConnectOrCreateWalletFirstToast)));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WalletBackupProtectionScreen()),
    );
    if (!mounted) return;
    await _loadAllSettings();
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
          style: KubusTypography.inter(
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
                style: KubusTypography.inter(
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
                _applyState(() {
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
        _applyState(() => _biometricAuth = false);
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
        _applyState(() => _biometricAuth = false);
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
        _applyState(() => _biometricAuth = false);
        await _saveAllSettings();
        await gate.reloadSettings();
        return;
      }
    }
    _applyState(() {
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
        _applyState(() => _requirePin = false);
        await _saveAllSettings();
        await gate.reloadSettings();
        return;
      }
      _applyState(() => _requirePin = true);
      await _saveAllSettings();
      await gate.reloadSettings();
      return;
    }

    // Disabling requires a local verification.
    await gate.lock(SecurityLockReason.sensitiveAction);
    final settled = await gate.waitForResolution();
    if (settled == null || !settled.isSuccess) {
      if (!mounted) return;
      _applyState(() => _requirePin = true);
      return;
    }

    if (!mounted) return;
    _applyState(() => _requirePin = false);
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
                style: KubusTypography.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsExportRecoveryPhraseDialogBody,
              style: KubusTypography.inter(
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
                    style: KubusTypography.inter(
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WalletBackupProtectionScreen(),
                ),
              );
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
                style: KubusTypography.inter(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsImportWalletDialogBody,
              style: KubusTypography.inter(
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
                    style: KubusTypography.inter(
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
          style: KubusTypography.inter(
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
                style: KubusTypography.inter(
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
              _applyState(() {
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
                style: KubusTypography.inter(
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
                _applyState(() {
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
                style: KubusTypography.inter(
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
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsClearCacheDialogBody,
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
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
          style: KubusTypography.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsResetPermissionFlagsDialogBody,
          style: KubusTypography.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonCancel,
                style: KubusTypography.inter(
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
                style: KubusTypography.inter(
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
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsExportDataDialogBody,
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
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
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              // Prepare export data
              final prefs = await SharedPreferences.getInstance();
              final exportData = {
                'profile': {
                  'profileVisibility':
                      prefs.getString('profileVisibility') ?? 'Public',
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
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsResetAppDialogBody,
          style: KubusTypography.inter(
            color: Theme.of(context).colorScheme.onSurface,
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
          style: KubusTypography.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          l10n.settingsDeleteAccountDialogBody,
          style: KubusTypography.inter(
            color: Theme.of(dialogContext).colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.commonCancel,
              style: KubusTypography.inter(
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
              // Show confirmation dialog; ensure mounted before calling showDialog.
              if (!mounted) return;
              final dialogNavigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(context);
              final confirmed = await showKubusDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) => KubusAlertDialog(
                  backgroundColor: Theme.of(confirmContext).colorScheme.surface,
                  title: Text(
                    l10n.settingsFinalConfirmationTitle,
                    style: KubusTypography.inter(
                      color: Theme.of(confirmContext).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Text(
                    l10n.settingsDeleteAccountFinalConfirmationBody,
                    style: KubusTypography.inter(
                      color: Theme.of(confirmContext).colorScheme.onSurface,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: Text(l10n.commonCancel,
                          style: KubusTypography.inter()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: Text(
                        l10n.settingsConfirmButton,
                        style: KubusTypography.inter(
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

                // Delete the authenticated account (users.id), never just
                // wallet-scoped data. Requires a valid backend token; local
                // state is only cleared after the backend confirms.
                try {
                  await BackendApiService().deleteMyAccount();
                } catch (e) {
                  debugPrint('SettingsScreen: backend deletion failed: $e');
                  messenger.showKubusSnackBar(
                    SnackBar(
                        content:
                            Text(l10n.settingsDeleteAccountBackendFailedToast)),
                  );
                  if (!mounted) return;
                  dialogNavigator.pop();
                  return;
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
}
