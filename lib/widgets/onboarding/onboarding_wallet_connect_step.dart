import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/wallet_session_sync_service.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingWalletConnectAction {
  create,
  import,
  connect,
}

class OnboardingWalletConnectStep extends StatefulWidget {
  const OnboardingWalletConnectStep({
    super.key,
    required this.onWalletLinked,
  });

  final Future<void> Function(String walletAddress) onWalletLinked;

  @override
  State<OnboardingWalletConnectStep> createState() =>
      _OnboardingWalletConnectStepState();
}

class _OnboardingWalletConnectStepState
    extends State<OnboardingWalletConnectStep> {
  final TextEditingController _mnemonicController = TextEditingController();
  OnboardingWalletConnectAction? _busyAction;
  String? _linkedWallet;
  String? _error;
  bool _showImport = false;

  @override
  void dispose() {
    _mnemonicController.dispose();
    super.dispose();
  }

  Future<String?> _currentUserId() async {
    final user = context.read<ProfileProvider>().currentUser;
    final fromProfile = (user?.userId ?? user?.id ?? '').trim();
    if (fromProfile.isNotEmpty) return fromProfile;
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = (prefs.getString('user_id') ?? '').trim();
    return fromPrefs.isEmpty ? null : fromPrefs;
  }

  Future<void> _bindWallet(String walletAddress) async {
    final normalizedWallet = walletAddress.trim();
    if (normalizedWallet.isEmpty) {
      throw StateError('Wallet address missing after wallet action.');
    }
    final userId = await _currentUserId();
    if (!mounted) return;
    await const WalletSessionSyncService().bindAuthenticatedWallet(
      context: context,
      walletAddress: normalizedWallet,
      userId: userId,
      warmUp: false,
      loadProfile: true,
      syncBackend: true,
      requireBackendSync: true,
    );
    if (!mounted) return;
    setState(() {
      _linkedWallet = normalizedWallet;
      _error = null;
    });
    await widget.onWalletLinked(normalizedWallet);
  }

  Future<void> _runWalletAction(
    OnboardingWalletConnectAction action,
    Future<String> Function(WalletProvider walletProvider) operation,
  ) async {
    if (_busyAction != null) return;
    if (!AppConfig.enableWeb3 || !AppConfig.enableWalletConnect) {
      setState(() {
        _error = 'Wallet connection is disabled right now.';
      });
      return;
    }
    setState(() {
      _busyAction = action;
      _error = null;
    });
    try {
      final walletProvider = context.read<WalletProvider>();
      final address = await operation(walletProvider).timeout(
        const Duration(seconds: 30),
      );
      await _bindWallet(address);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageForError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busyAction = null;
        });
      } else {
        _busyAction = null;
      }
    }
  }

  String _messageForError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'Wallet linking failed. Try again.';
    }
    return message;
  }

  Future<void> _createWallet() {
    return _runWalletAction(
      OnboardingWalletConnectAction.create,
      (walletProvider) async {
        final result = await walletProvider.createWallet(syncBackend: false);
        final address = (result['address'] ?? '').trim();
        if (address.isEmpty) {
          throw StateError('Created wallet did not return an address.');
        }
        return address;
      },
    );
  }

  Future<void> _importWallet() {
    final mnemonic =
        _mnemonicController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (mnemonic.isEmpty) {
      setState(() {
        _error = 'Enter your recovery phrase to import a wallet.';
        _showImport = true;
      });
      return Future<void>.value();
    }
    return _runWalletAction(
      OnboardingWalletConnectAction.import,
      (walletProvider) => walletProvider.importWalletFromMnemonic(
        mnemonic,
        markBackedUp: true,
        syncBackend: false,
      ),
    );
  }

  Future<void> _connectExternalWallet() {
    return _runWalletAction(
      OnboardingWalletConnectAction.connect,
      (walletProvider) async {
        final result = await walletProvider.connectExternalWallet(
          context,
          allowReplacingWalletIdentity: true,
          syncBackend: false,
        );
        return result.address.trim();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final currentUser = context.watch<ProfileProvider>().currentUser;
    final linkedWallet =
        _linkedWallet ?? (currentUser?.walletAddress ?? '').trim();
    final accountLabel = (currentUser?.displayName ?? '').trim().isNotEmpty
        ? currentUser!.displayName.trim()
        : ((currentUser?.username ?? '').trim().isNotEmpty
            ? currentUser!.username.trim()
            : ((currentUser?.userId ?? currentUser?.id ?? '').trim()));

    final status = _WalletConnectStatus(
      accountLabel:
          accountLabel.isEmpty ? 'Authenticated account' : accountLabel,
      walletAddress: linkedWallet,
      error: _error,
    );

    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WalletConnectActionCard(
          icon: Icons.add_card_outlined,
          title: 'Create new art.kubus wallet',
          body:
              'Generate a new wallet and link it to the account you just created.',
          actionLabel: 'Create wallet',
          busy: _busyAction == OnboardingWalletConnectAction.create,
          disabled: _busyAction != null,
          onPressed: _createWallet,
        ),
        const SizedBox(height: KubusSpacing.sm),
        _WalletConnectActionCard(
          icon: Icons.input_outlined,
          title: 'Import existing wallet',
          body: 'Use a recovery phrase for a wallet you already control.',
          actionLabel: _showImport ? 'Link imported wallet' : 'Import wallet',
          busy: _busyAction == OnboardingWalletConnectAction.import,
          disabled: _busyAction != null,
          onPressed: _showImport
              ? _importWallet
              : () {
                  setState(() {
                    _showImport = true;
                    _error = null;
                  });
                  return Future<void>.value();
                },
          child: _showImport
              ? Padding(
                  padding: const EdgeInsets.only(top: KubusSpacing.sm),
                  child: TextField(
                    controller: _mnemonicController,
                    minLines: 2,
                    maxLines: 4,
                    enabled: _busyAction == null,
                    decoration: const InputDecoration(
                      labelText: 'Recovery phrase',
                      border: OutlineInputBorder(),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: KubusSpacing.sm),
        _WalletConnectActionCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Connect external wallet',
          body: 'Connect a browser or mobile wallet you already use.',
          actionLabel: 'Connect wallet',
          busy: _busyAction == OnboardingWalletConnectAction.connect,
          disabled: _busyAction != null,
          onPressed: _connectExternalWallet,
        ),
      ],
    );

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect your wallet',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          'This wallet will become your public Web3 identity on art.kubus.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
                height: 1.42,
              ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          'Your Google/email account remains your login and recovery account.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.74),
                height: 1.4,
              ),
        ),
        const SizedBox(height: KubusSpacing.md),
        status,
      ],
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LiquidGlassCard(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              borderRadius: BorderRadius.circular(KubusRadius.lg),
              child: intro,
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Expanded(
            child: SingleChildScrollView(child: actions),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiquidGlassCard(
            padding: const EdgeInsets.all(KubusSpacing.md),
            borderRadius: BorderRadius.circular(KubusRadius.lg),
            child: intro,
          ),
          const SizedBox(height: KubusSpacing.md),
          actions,
          SizedBox(
              height: MediaQuery.viewInsetsOf(context).bottom > 0 ? 120 : 0),
        ],
      ),
    );
  }
}

class _WalletConnectStatus extends StatelessWidget {
  const _WalletConnectStatus({
    required this.accountLabel,
    required this.walletAddress,
    required this.error,
  });

  final String accountLabel;
  final String walletAddress;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final linked = walletAddress.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(
            icon: Icons.person_outline,
            label: 'Linked account',
            value: accountLabel,
          ),
          const SizedBox(height: KubusSpacing.sm),
          _StatusLine(
            icon: linked ? Icons.check_circle_outline : Icons.link_outlined,
            label: 'Wallet status',
            value: linked
                ? walletAddress
                : 'Choose a wallet action to continue after it is linked.',
          ),
          if (error != null) ...[
            const SizedBox(height: KubusSpacing.sm),
            Text(
              error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.66),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalletConnectActionCard extends StatelessWidget {
  const _WalletConnectActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.busy,
    required this.disabled,
    required this.onPressed,
    this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final bool busy;
  final bool disabled;
  final Future<void> Function() onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.74),
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (child != null) child!,
          const SizedBox(height: KubusSpacing.md),
          KubusButton(
            onPressed: disabled && !busy
                ? null
                : () {
                    unawaited(onPressed());
                  },
            isLoading: busy,
            icon: busy ? null : Icons.arrow_forward_rounded,
            label: actionLabel,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }
}
