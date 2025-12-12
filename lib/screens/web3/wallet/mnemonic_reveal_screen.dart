import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../providers/wallet_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/app_loading.dart';

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
    setState(() { _isLoading = true; _error = null; });
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final m = await wallet.revealMnemonic();
    if (!mounted) return;
    if (m != null) {
      setState(() { _mnemonic = m; _isLoading = false; _masked = true; });
      return;
    }
    setState(() { _isLoading = false; });
  }

  Future<void> _attemptPinReveal() async {
    setState(() { _isLoading = true; _error = null; });
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final remaining = await wallet.getPinLockoutRemainingSeconds();
    if (!mounted) return;
    if (remaining > 0) {
      setState(() { _error = 'PIN locked for $remaining seconds'; _isLoading = false; });
      return;
    }
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() { _error = 'PIN must be at least 4 digits'; _isLoading = false; });
      return;
    }
    final m = await wallet.revealMnemonic(pin: pin);
    if (!mounted) return;
    if (m != null) {
      setState(() { _mnemonic = m; _isLoading = false; _masked = true; });
    } else {
      final rem = await wallet.getPinLockoutRemainingSeconds();
      if (!mounted) return;
      setState(() { _error = rem > 0 ? 'PIN locked for $rem seconds' : 'Incorrect PIN'; _isLoading = false; });
    }
  }

  void _copyToClipboard() {
    if (_mnemonic == null) return;
    final m = _mnemonic!;
    Clipboard.setData(ClipboardData(text: m));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mnemonic copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final words = _mnemonic?.split(RegExp(r"\s+")) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reveal Recovery Phrase'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
          ? const AppLoading()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_mnemonic != null) ...[
                  Text('Your recovery phrase (keep it private)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 6),
                      itemCount: words.length,
                      itemBuilder: (context, index) {
                        final w = words[index];
                        final display = _masked ? '•••••' : w;
                        return Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                          ),
                          child: Row(
                            children: [
                              Text('${index + 1}. ', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              Expanded(child: Text(display, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter())),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          // Biometric re-check before showing
                          final wallet = Provider.of<WalletProvider>(context, listen: false);
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await wallet.authenticateWithBiometrics();
                          if (!mounted) return;
                          if (ok) {
                            setState(() => _masked = false);
                            return;
                          }
                          // fallback to PIN entry dialog
                          final entered = await showDialog<String?>(
                            context: this.context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Enter PIN'),
                              content: TextField(controller: _pinController, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN')),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(_pinController.text.trim()), child: const Text('Unlock')),
                              ],
                            ),
                          );

                          if (!mounted) return;
                          if (entered == null || entered.isEmpty) return;
                          final m2 = await wallet.revealMnemonic(pin: entered);
                          if (!mounted) return;
                          if (m2 != null) {
                            setState(() {
                              _mnemonic = m2;
                              _masked = false;
                            });
                          } else {
                            final rem = await wallet.getPinLockoutRemainingSeconds();
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(rem > 0 ? 'PIN locked for $rem seconds' : 'Incorrect PIN'),
                              ),
                            );
                          }
                        },
                        child: const Text('Show'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _copyToClipboard,
                        child: const Text('Copy'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ] else ...[
                  Text('Biometric unlock unavailable. Enter PIN to reveal your recovery phrase.', style: GoogleFonts.inter()),
                  const SizedBox(height: 12),
                  if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  TextField(controller: _pinController, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN')),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _attemptPinReveal, child: const Text('Unlock')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                ]
              ],
            ),
      ),
    );
  }
}
