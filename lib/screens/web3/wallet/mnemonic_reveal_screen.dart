import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/app_loading.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/security_gate_provider.dart';
import '../../../providers/wallet_provider.dart';

/// Full-screen recovery phrase reveal used from wallet settings/security.
///
/// The sensitive phrase UI itself lives in [MnemonicRevealContent] so it can be
/// reused inside the onboarding flow (embedded in a Kubus dialog/sheet) without
/// pushing a separate route.
class MnemonicRevealScreen extends StatelessWidget {
  const MnemonicRevealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mnemonicRevealTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: MnemonicRevealContent(
          onCompleted: () => Navigator.of(context).maybePop(true),
          onClose: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

/// Reusable sensitive recovery-phrase reveal surface.
///
/// Preserves all wallet security behaviour:
/// - [SecurityGateProvider.requireSensitiveActionVerification] before load and
///   before reveal,
/// - [WalletProvider.readCachedMnemonic] to load the phrase,
/// - masked-by-default state,
/// - copy-to-clipboard only once the phrase is loaded,
/// - [WalletProvider.markMnemonicBackedUp] on confirmation,
/// - snackbar/error feedback.
///
/// Set [embedded] to true when hosting inside an onboarding dialog/sheet so the
/// layout is shrink-wrapped (safe inside a scroll view) and completion is routed
/// through [onCompleted]/[onClose] instead of popping a route.
class MnemonicRevealContent extends StatefulWidget {
  const MnemonicRevealContent({
    super.key,
    this.embedded = false,
    this.onCompleted,
    this.onClose,
  });

  final bool embedded;

  /// Invoked after the recovery phrase has been marked backed up.
  final VoidCallback? onCompleted;

  /// Invoked when the user dismisses the reveal without completing.
  final VoidCallback? onClose;

  @override
  State<MnemonicRevealContent> createState() => _MnemonicRevealContentState();
}

class _MnemonicRevealContentState extends State<MnemonicRevealContent> {
  bool _isLoading = true;
  String? _mnemonic;
  bool _masked = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _unlockAndLoadMnemonic();
    });
  }

  Future<void> _unlockAndLoadMnemonic() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final gate = Provider.of<SecurityGateProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);

    final settled = await gate.requireSensitiveActionVerification();
    if (!mounted) return;
    if (!settled) {
      setState(() {
        _isLoading = false;
        _error = l10n.lockAuthenticationFailedToast;
      });
      return;
    }

    final mnemonic = await wallet.readCachedMnemonic();
    if (!mounted) return;
    if (mnemonic != null) {
      setState(() {
        _mnemonic = mnemonic;
        _isLoading = false;
        _masked = true;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _error = l10n.lockAuthenticationFailedToast;
    });
  }

  Future<void> _copyToClipboard() async {
    final mnemonic = _mnemonic?.trim();
    if (mnemonic == null || mnemonic.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: mnemonic));
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.mnemonicRevealCopiedToast)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        const SnackBar(
          content: Text('Unable to copy the recovery phrase on this device.'),
        ),
        tone: KubusSnackBarTone.error,
      );
    }
  }

  Future<void> _revealMnemonic() async {
    final gate = Provider.of<SecurityGateProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final settled = await gate.requireSensitiveActionVerification();
    if (!mounted) return;
    if (!settled) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.lockAuthenticationFailedToast)),
        tone: KubusSnackBarTone.error,
      );
      return;
    }

    setState(() => _masked = false);
  }

  Future<void> _markBackupComplete() async {
    if (_mnemonic == null || _masked) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    await wallet.markMnemonicBackedUp();
    if (!mounted) return;
    messenger.showKubusSnackBar(
      SnackBar(content: Text(l10n.walletBackupMarkedCompleteToast)),
    );
    _handleCompleted();
  }

  void _handleCompleted() {
    if (widget.onCompleted != null) {
      widget.onCompleted!.call();
    }
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final words = _mnemonic?.split(RegExp(r'\s+')) ?? <String>[];

    if (_isLoading) {
      return widget.embedded
          ? const Padding(
              padding: EdgeInsets.all(KubusSpacing.lg),
              child: Center(child: AppLoading()),
            )
          : const AppLoading();
    }

    final wordGrid = GridView.builder(
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 6,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final display = _masked ? '•••••' : words[index];
        return FrostedContainer(
          margin: const EdgeInsets.all(KubusSpacing.xs + KubusSpacing.xxs),
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.sm + KubusSpacing.xs,
            vertical: KubusSpacing.sm,
          ),
          backgroundColor: scheme.primary.withValues(alpha: 0.10),
          child: Row(
            children: [
              Text(
                '${index + 1}. ',
                style: KubusTypography.textTheme.bodyMedium,
              ),
              Expanded(
                child: Text(
                  display,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTypography.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        );
      },
    );

    final warningHeader = FrostedContainer(
      backgroundColor: scheme.primary.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            size: KubusSizes.sidebarActionIcon,
            color: scheme.primary,
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Text(
              l10n.mnemonicRevealPrivacyWarning,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );

    final cardChildren = <Widget>[
      warningHeader,
      const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
      widget.embedded ? wordGrid : Expanded(child: wordGrid),
    ];

    final phraseCard = LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: widget.embedded ? MainAxisSize.min : MainAxisSize.max,
        children: cardChildren,
      ),
    );

    final actionsRow = Row(
      children: [
        KubusButton(
          onPressed: _revealMnemonic,
          label: l10n.mnemonicRevealShowButton,
          icon: Icons.visibility,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
        const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
        KubusOutlineButton(
          onPressed: _copyToClipboard,
          label: l10n.commonCopy,
          icon: Icons.copy,
        ),
        const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
        KubusOutlineButton(
          onPressed: _handleClose,
          label: l10n.commonClose,
        ),
      ],
    );

    final confirmButton = KubusButton(
      onPressed: _masked ? null : _markBackupComplete,
      label: l10n.walletBackupConfirmAction,
      icon: Icons.verified_user_outlined,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      isFullWidth: true,
    );

    final loadedColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.embedded ? MainAxisSize.min : MainAxisSize.max,
      children: [
        widget.embedded ? phraseCard : Expanded(child: phraseCard),
        const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
        actionsRow,
        const SizedBox(height: KubusSpacing.sm),
        confirmButton,
      ],
    );

    final errorColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FrostedContainer(
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: KubusSizes.sidebarActionIcon,
                color: roles.warningAction,
              ),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Text(
                  l10n.mnemonicRevealBiometricUnavailable,
                  style: KubusTypography.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
            child: Text(
              _error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ),
        KubusButton(
          onPressed: _unlockAndLoadMnemonic,
          label: l10n.commonUnlock,
          icon: Icons.lock_open,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          isFullWidth: true,
        ),
        const SizedBox(height: KubusSpacing.sm),
        KubusOutlineButton(
          onPressed: _handleClose,
          label: l10n.commonCancel,
          isFullWidth: true,
        ),
      ],
    );

    return _mnemonic != null ? loadedColumn : errorColumn;
  }
}
