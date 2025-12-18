import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../../providers/wallet_provider.dart';
import '../../../widgets/app_loading.dart';
import '../../../utils/app_color_utils.dart';

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
        .showSnackBar(SnackBar(content: Text(l10n.mnemonicRevealCopiedToast)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final words = _mnemonic?.split(RegExp(r"\s+")) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mnemonicRevealTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const AppLoading()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_mnemonic != null) ...[
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 20, color: AppColorUtils.indigoAccent),
                        const SizedBox(width: 8),
                        Text(l10n.mnemonicRevealPrivacyWarning,
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColorUtils.indigoAccent
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColorUtils.indigoAccent
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Text('${index + 1}. ',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600)),
                                Expanded(
                                    child: Text(display,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter())),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.visibility,
                              size: 18, color: scheme.onPrimary),
                          label: Text(l10n.mnemonicRevealShowButton),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColorUtils.indigoAccent,
                            foregroundColor: Colors.white,
                          ),
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
                            final entered = await showDialog<String?>(
                              context: this.context,
                              builder: (ctx) => AlertDialog(
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
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(rem > 0
                                      ? l10n.mnemonicRevealPinLockedError(rem)
                                      : l10n.mnemonicRevealIncorrectPinError),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text(l10n.commonCopy),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.surface,
                            foregroundColor: scheme.onSurface,
                          ),
                          onPressed: _copyToClipboard,
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.commonClose),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: AppColorUtils.amberAccent),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(l10n.mnemonicRevealBiometricUnavailable,
                                style: GoogleFonts.inter())),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(_error!,
                              style: TextStyle(color: scheme.error))),
                    TextField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration:
                            InputDecoration(labelText: l10n.commonPinLabel)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColorUtils.indigoAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _attemptPinReveal,
                      child: Text(l10n.commonUnlock),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.commonCancel)),
                  ]
                ],
              ),
      ),
    );
  }
}
