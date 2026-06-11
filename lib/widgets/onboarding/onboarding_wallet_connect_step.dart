import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_wallet_link_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
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

/// Link transaction phases shown in the WalletConnect status timeline.
enum OnboardingWalletLinkPhase {
  ready,
  creatingWallet,
  walletReady,
  linking,
  linked,
  failed,
}

/// Snapshot of the authenticated account taken before any wallet operation,
/// used both for the strict bind and to roll back local state on failure.
class _AccountLinkSnapshot {
  const _AccountLinkSnapshot({
    required this.userId,
    required this.token,
    required this.prefsStrings,
    required this.prefsBools,
  });

  final String userId;
  final String token;
  final Map<String, String?> prefsStrings;
  final Map<String, bool?> prefsBools;
}

class OnboardingWalletConnectStep extends StatefulWidget {
  const OnboardingWalletConnectStep({
    super.key,
    required this.onWalletLinked,
    this.linkService,
  });

  final Future<void> Function(String walletAddress) onWalletLinked;

  /// Test seam: overrides the strict account-link transaction transport.
  final AccountWalletLinkService? linkService;

  @override
  State<OnboardingWalletConnectStep> createState() =>
      _OnboardingWalletConnectStepState();
}

class _OnboardingWalletConnectStepState
    extends State<OnboardingWalletConnectStep> {
  static const List<String> _snapshotStringKeys = <String>[
    'wallet_address',
    'walletAddress',
    'wallet',
    'user_id',
  ];
  static const List<String> _snapshotBoolKeys = <String>['has_wallet'];

  final TextEditingController _mnemonicController = TextEditingController();
  OnboardingWalletConnectAction? _busyAction;
  OnboardingWalletLinkPhase _phase = OnboardingWalletLinkPhase.ready;
  String? _linkedWallet;
  String? _localWallet;
  String? _error;
  bool _showImport = false;

  @override
  void dispose() {
    _mnemonicController.dispose();
    super.dispose();
  }

  Future<String?> _resolveCurrentUserId() async {
    final user = context.read<ProfileProvider>().currentUser;
    final fromProfile = (user?.userId ?? user?.id ?? '').trim();
    if (fromProfile.isNotEmpty) return fromProfile;
    final prefs = await SharedPreferences.getInstance();
    final fromPrefs = (prefs.getString('user_id') ?? '').trim();
    return fromPrefs.isEmpty ? null : fromPrefs;
  }

  Future<_AccountLinkSnapshot?> _captureAccountSnapshot() async {
    final userId = await _resolveCurrentUserId();
    if (!mounted) return null;
    final backendApi = BackendApiService();
    var token = (backendApi.getAuthToken() ?? '').trim();
    if (token.isEmpty) {
      try {
        await backendApi.loadAuthToken();
      } catch (_) {}
      token = (backendApi.getAuthToken() ?? '').trim();
    }
    if ((userId ?? '').isEmpty || token.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final prefsStrings = <String, String?>{
      for (final key in _snapshotStringKeys) key: prefs.getString(key),
    };
    final prefsBools = <String, bool?>{
      for (final key in _snapshotBoolKeys) key: prefs.getBool(key),
    };
    return _AccountLinkSnapshot(
      userId: userId!,
      token: token,
      prefsStrings: prefsStrings,
      prefsBools: prefsBools,
    );
  }

  Future<void> _restoreSnapshot(_AccountLinkSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in snapshot.prefsStrings.entries) {
        final value = entry.value;
        if (value == null) {
          await prefs.remove(entry.key);
        } else {
          await prefs.setString(entry.key, value);
        }
      }
      for (final entry in snapshot.prefsBools.entries) {
        final value = entry.value;
        if (value == null) {
          await prefs.remove(entry.key);
        } else {
          await prefs.setBool(entry.key, value);
        }
      }
    } catch (_) {}
    try {
      await BackendApiService().setAuthToken(snapshot.token);
    } catch (_) {}
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

    // 1. Capture the authenticated account before touching wallet state.
    final snapshot = await _captureAccountSnapshot();
    if (!mounted) return;
    if (snapshot == null) {
      setState(() {
        _phase = OnboardingWalletLinkPhase.failed;
        _error =
            'Your account session could not be confirmed. Go back to the '
            'account step and sign in again — do not create a new account.';
      });
      return;
    }

    // Persist the account-link guard so an app refresh recovers into this
    // step instead of falling back to sign-in.
    await OnboardingStateService.markAccountLinkStarted(
      userId: snapshot.userId,
    );
    if (!mounted) return;

    final profileSnapshot = context.read<ProfileProvider>().currentUser;
    setState(() {
      _busyAction = action;
      _phase = OnboardingWalletLinkPhase.creatingWallet;
      _error = null;
    });

    try {
      // 2. Local wallet operation only — no backend auth may happen here.
      final walletProvider = context.read<WalletProvider>();
      final address = (await operation(walletProvider).timeout(
        const Duration(seconds: 30),
      ))
          .trim();
      if (address.isEmpty) {
        throw StateError('Wallet action did not return an address.');
      }
      if (!mounted) return;
      setState(() {
        _localWallet = address;
        _phase = OnboardingWalletLinkPhase.walletReady;
      });

      // 3. Restore the original account auth before the backend bind, in
      // case the wallet operation touched session state.
      final backendApi = BackendApiService();
      await backendApi.setAuthToken(snapshot.token);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', snapshot.userId);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _phase = OnboardingWalletLinkPhase.linking;
      });

      // 4-7. Strict bind + verification through /api/profiles/me.
      final service = widget.linkService ?? AccountWalletLinkService();
      final result = await service.linkWalletToCurrentAccount(
        context: context,
        walletAddress: address,
        expectedUserId: snapshot.userId,
        originalAuthToken: snapshot.token,
      );

      // 8. Verified: the original account owns the wallet.
      await OnboardingStateService.clearAccountLinkGuard();
      if (!mounted) return;
      setState(() {
        _linkedWallet = result.walletAddress;
        _phase = OnboardingWalletLinkPhase.linked;
        _error = null;
      });
      await widget.onWalletLinked(result.walletAddress);
    } catch (error) {
      // Roll back wallet/session pollution and stay on this step. The guard
      // stays active so a refresh recovers into WalletConnect, never sign-in.
      await _restoreSnapshot(snapshot);
      if (profileSnapshot != null && mounted) {
        try {
          await context
              .read<ProfileProvider>()
              .loadAuthenticatedProfile()
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _phase = OnboardingWalletLinkPhase.failed;
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
      (walletProvider) => walletProvider.createWalletForAccountLink(),
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
      (walletProvider) => walletProvider.importWalletForAccountLink(mnemonic),
    );
  }

  Future<void> _connectExternalWallet() {
    return _runWalletAction(
      OnboardingWalletConnectAction.connect,
      (walletProvider) =>
          walletProvider.connectExternalWalletForAccountLink(context),
    );
  }

  String _truncateWallet(String wallet) {
    final normalized = wallet.trim();
    if (normalized.length <= 14) return normalized;
    return '${normalized.substring(0, 6)}…${normalized.substring(normalized.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final profileProvider = context.watch<ProfileProvider>();
    final currentUser = profileProvider.currentUser;

    // Trust the hydrated profile wallet only when it belongs to the same
    // account that is signed in here — never local wallet state alone.
    final profileUserId = (currentUser?.userId ?? currentUser?.id ?? '').trim();
    final profileWallet = (currentUser?.walletAddress ?? '').trim();
    final verifiedWallet = (_linkedWallet ?? '').trim().isNotEmpty
        ? _linkedWallet!.trim()
        : ((profileWallet.isNotEmpty &&
                profileUserId.isNotEmpty &&
                profileProvider.hasHydratedProfile)
            ? profileWallet
            : '');
    final isLinked = verifiedWallet.isNotEmpty;

    final accountLabel = (currentUser?.displayName ?? '').trim().isNotEmpty
        ? currentUser!.displayName.trim()
        : ((currentUser?.username ?? '').trim().isNotEmpty
            ? currentUser!.username.trim()
            : profileUserId);
    final accountEmail = (currentUser?.username ?? '').trim().isNotEmpty &&
            (currentUser?.username ?? '').trim() != accountLabel
        ? '@${currentUser!.username.trim().replaceFirst(RegExp(r'^@+'), '')}'
        : '';

    final status = _WalletConnectStatusPanel(
      accountLabel:
          accountLabel.isEmpty ? 'Authenticated account' : accountLabel,
      accountEmail: accountEmail,
      accountId: profileUserId.isEmpty ? null : _truncateWallet(profileUserId),
      phase: isLinked && _phase != OnboardingWalletLinkPhase.failed
          ? OnboardingWalletLinkPhase.linked
          : _phase,
      localWallet:
          (_localWallet ?? '').isEmpty ? null : _truncateWallet(_localWallet!),
      linkedWallet: isLinked ? _truncateWallet(verifiedWallet) : null,
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
          'Your wallet becomes your public Web3 identity on art.kubus.',
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
              child: SingleChildScrollView(child: intro),
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

enum _TimelineState { pending, active, done, failed }

class _WalletConnectStatusPanel extends StatelessWidget {
  const _WalletConnectStatusPanel({
    required this.accountLabel,
    required this.accountEmail,
    required this.accountId,
    required this.phase,
    required this.localWallet,
    required this.linkedWallet,
    required this.error,
  });

  final String accountLabel;
  final String accountEmail;
  final String? accountId;
  final OnboardingWalletLinkPhase phase;
  final String? localWallet;
  final String? linkedWallet;
  final String? error;

  _TimelineState get _localWalletState {
    switch (phase) {
      case OnboardingWalletLinkPhase.ready:
        return _TimelineState.pending;
      case OnboardingWalletLinkPhase.creatingWallet:
        return _TimelineState.active;
      case OnboardingWalletLinkPhase.failed:
        return localWallet == null
            ? _TimelineState.failed
            : _TimelineState.done;
      case OnboardingWalletLinkPhase.walletReady:
      case OnboardingWalletLinkPhase.linking:
      case OnboardingWalletLinkPhase.linked:
        return _TimelineState.done;
    }
  }

  _TimelineState get _accountLinkState {
    switch (phase) {
      case OnboardingWalletLinkPhase.ready:
      case OnboardingWalletLinkPhase.creatingWallet:
      case OnboardingWalletLinkPhase.walletReady:
        return _TimelineState.pending;
      case OnboardingWalletLinkPhase.linking:
        return _TimelineState.active;
      case OnboardingWalletLinkPhase.linked:
        return _TimelineState.done;
      case OnboardingWalletLinkPhase.failed:
        return localWallet == null
            ? _TimelineState.pending
            : _TimelineState.failed;
    }
  }

  _TimelineState get _verificationState {
    switch (phase) {
      case OnboardingWalletLinkPhase.linking:
        return _TimelineState.active;
      case OnboardingWalletLinkPhase.linked:
        return _TimelineState.done;
      case OnboardingWalletLinkPhase.failed:
        return localWallet == null
            ? _TimelineState.pending
            : _TimelineState.failed;
      case OnboardingWalletLinkPhase.ready:
      case OnboardingWalletLinkPhase.creatingWallet:
      case OnboardingWalletLinkPhase.walletReady:
        return _TimelineState.pending;
    }
  }

  String get _statusHeadline {
    switch (phase) {
      case OnboardingWalletLinkPhase.ready:
        return 'Choose a wallet action to continue.';
      case OnboardingWalletLinkPhase.creatingWallet:
        return 'Creating local wallet…';
      case OnboardingWalletLinkPhase.walletReady:
        return 'Local wallet ready — preparing account link.';
      case OnboardingWalletLinkPhase.linking:
        return 'Linking wallet to your account and verifying…';
      case OnboardingWalletLinkPhase.linked:
        return 'Wallet linked to this account.';
      case OnboardingWalletLinkPhase.failed:
        return 'Wallet link failed. Your account was not changed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_outline, color: Colors.white, size: 18),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login account',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.66),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (accountEmail.isNotEmpty)
                      Text(
                        accountEmail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                      ),
                    if (accountId != null)
                      Text(
                        'Account ID $accountId',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
          _TimelineRow(
            label: 'Local wallet',
            detail: localWallet,
            state: _localWalletState,
          ),
          const SizedBox(height: KubusSpacing.xs),
          _TimelineRow(
            label: 'Account link',
            detail: null,
            state: _accountLinkState,
          ),
          const SizedBox(height: KubusSpacing.xs),
          _TimelineRow(
            label: 'Verification',
            detail: linkedWallet == null
                ? null
                : 'Verified linked wallet $linkedWallet',
            state: phase == OnboardingWalletLinkPhase.linked
                ? _TimelineState.done
                : _verificationState,
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            _statusHeadline,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: phase == OnboardingWalletLinkPhase.failed
                      ? scheme.error
                      : Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
          ),
          if (error != null) ...[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.detail,
    required this.state,
  });

  final String label;
  final String? detail;
  final _TimelineState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget marker;
    switch (state) {
      case _TimelineState.pending:
        marker = Icon(
          Icons.radio_button_unchecked,
          size: 16,
          color: Colors.white.withValues(alpha: 0.4),
        );
        break;
      case _TimelineState.active:
        marker = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case _TimelineState.done:
        marker = const Icon(
          Icons.check_circle_outline,
          size: 16,
          color: Colors.white,
        );
        break;
      case _TimelineState.failed:
        marker = Icon(
          Icons.error_outline,
          size: 16,
          color: scheme.error,
        );
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: marker,
        ),
        const SizedBox(width: KubusSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if ((detail ?? '').isNotEmpty)
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.62),
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
