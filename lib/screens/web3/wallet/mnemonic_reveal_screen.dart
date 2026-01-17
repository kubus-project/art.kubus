import 'package:art_kubus/utils/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/wallet_provider.dart';
import '../../../widgets/app_loading.dart';
import '../../../widgets/glass_components.dart';
import '../../../widgets/kubus_button.dart';
import '../../../utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class MnemonicRevealScreen extends StatefulWidget {
  const MnemonicRevealScreen({super.key});

  @override
  State<MnemonicRevealScreen> createState() => _MnemonicRevealScreenState();
}

class _MnemonicRevealScreenState extends State<MnemonicRevealScreen> {
  bool _isLoading = true;
  String? _mnemonic;
  bool _masked = true;
  final _pinController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _attemptBiometricReveal();
  }

  Future<void> _attemptBiometricReveal() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final m = await wallet.revealMnemonic();
    if (!mounted) return;
    if (m != null) {
      setState(() {
        _mnemonic = m;
        _isLoading = false;
        _masked = true;
      });
      return;
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _attemptPinReveal() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final remaining = await wallet.getPinLockoutRemainingSeconds();
    if (!mounted) return;
    if (remaining > 0) {
      setState(() {
        _error = l10n.mnemonicRevealPinLockedError(remaining);
        _isLoading = false;
      });
      return;
    }
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() {
        _error = l10n.mnemonicRevealPinError;
        _isLoading = false;
      });
      return;
    }
    final m = await wallet.revealMnemonic(pin: pin);
    if (!mounted) return;
    if (m != null) {
      setState(() {
        _mnemonic = m;
        _isLoading = false;
        _masked = true;
      });
    } else {
      final rem = await wallet.getPinLockoutRemainingSeconds();
      if (!mounted) return;
      setState(() {
        _error = rem > 0
            ? l10n.mnemonicRevealPinLockedError(rem)
            : l10n.mnemonicRevealIncorrectPinError;
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_mnemonic == null) return;
    final m = _mnemonic!;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    Clipboard.setData(ClipboardData(text: m));
    if (!mounted) return;
    messenger
        .showKubusSnackBar(SnackBar(content: Text(l10n.mnemonicRevealCopiedToast)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);
    final words = _mnemonic?.split(RegExp(r"\s+")) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mnemonicRevealTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: _isLoading
            ? const AppLoading()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_mnemonic != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: KubusSizes.sidebarActionIcon,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: KubusSpacing.sm),
                        Text(
                          l10n.mnemonicRevealPrivacyWarning,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2, childAspectRatio: 6),
                        itemCount: words.length,
                        itemBuilder: (context, index) {
                          final w = words[index];
                          final display = _masked ? '•••••' : w;
                          return Container(
                            margin: const EdgeInsets.all(
                              KubusSpacing.xs + KubusSpacing.xxs,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: KubusSpacing.sm + KubusSpacing.xs,
                              vertical: KubusSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(KubusRadius.sm),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.25),
                                width: KubusSizes.hairline,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text('${index + 1}. ',
                                    style: KubusTypography.textTheme.bodyMedium),
                                Expanded(
                                    child: Text(display,
                                        overflow: TextOverflow.ellipsis,  
                                        style: KubusTypography.textTheme.bodyMedium),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
                    Row(
                      children: [
                        KubusButton(
                          onPressed: () async {
                            // Biometric re-check before showing
                            final wallet = Provider.of<WalletProvider>(context,
                                listen: false);
                            final messenger = ScaffoldMessenger.of(context);
                            final ok =
                                await wallet.authenticateWithBiometrics();
                            if (!mounted) return;
                            if (ok) {
                              setState(() => _masked = false);
                              return;
                            }
                            // fallback to PIN entry dialog
                            final entered = await showKubusDialog<String?>(
                              context: this.context,
                              builder: (ctx) => KubusAlertDialog(
                                title: Text(
                                    l10n.mnemonicRevealEnterPinDialogTitle),
                                content: TextField(
                                    controller: _pinController,
                                    obscureText: true,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                        labelText: l10n.commonPinLabel)),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(null),
                                      child: Text(l10n.commonCancel)),
                                  ElevatedButton(
                                      onPressed: () => Navigator.of(ctx)
                                          .pop(_pinController.text.trim()),
                                      child: Text(l10n.commonUnlock)),
                                ],
                              ),
                            );

                            if (!mounted) return;
                            if (entered == null || entered.isEmpty) return;
                            final m2 =
                                await wallet.revealMnemonic(pin: entered);
                            if (!mounted) return;
                            if (m2 != null) {
                              setState(() {
                                _mnemonic = m2;
                                _masked = false;
                              });
                            } else {
                              final rem =
                                  await wallet.getPinLockoutRemainingSeconds();
                              if (!mounted) return;
                              messenger.showKubusSnackBar(
                                SnackBar(
                                  content: Text(rem > 0
                                      ? l10n.mnemonicRevealPinLockedError(rem)
                                      : l10n.mnemonicRevealIncorrectPinError),
                                ),
                              );
                            }
                          },
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
                          onPressed: () => Navigator.of(context).pop(),
                          label: l10n.commonClose,
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: KubusSizes.sidebarActionIcon,
                          color: roles.warningAction,
                        ),
                        const SizedBox(width: KubusSpacing.sm),
                        Expanded(
                            child: Text(l10n.mnemonicRevealBiometricUnavailable,
                                style: KubusTypography.textTheme.bodyMedium)),
                      ],
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
                    TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: l10n.commonPinLabel)),
                    const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
                    KubusButton(
                      onPressed: _attemptPinReveal,
                      label: l10n.commonUnlock,
                      icon: Icons.lock_open,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: KubusSpacing.sm),
                    KubusOutlineButton(
                      onPressed: () => Navigator.of(context).pop(),
                      label: l10n.commonCancel,
                      isFullWidth: true,
                    ),
                  ]
                ],
              ),
      ),
    );
  }
}
