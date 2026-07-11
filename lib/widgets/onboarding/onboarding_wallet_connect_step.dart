// ignore_for_file: kubus_no_raw_border
// Grandfathered kubus design-token violations. Remove this header
// when migrating this file to tokens (see docs/superpowers/specs/2026-07-10-ui-kit-token-enforcement-design.md).
import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_wallet_link_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/wallet_session_sync_dependencies.dart';
import 'package:art_kubus/utils/design_tokens.dart';
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
  bool _showMoreOptions = false;

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
        _error = AppLocalizations.of(context)!.walletSetupDisabledError;
      });
      return;
    }

    // 1. Capture the authenticated account before touching wallet state.
    final snapshot = await _captureAccountSnapshot();
    if (!mounted) return;
    if (snapshot == null) {
      setState(() {
        _phase = OnboardingWalletLinkPhase.failed;
        _error = AppLocalizations.of(context)!.walletSetupSessionMissingError;
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
        walletAddress: address,
        expectedUserId: snapshot.userId,
        originalAuthToken: snapshot.token,
        providers: WalletSessionSyncProvidersPayload(
          walletProvider: context.read<WalletProvider>(),
          profileProvider: context.read<ProfileProvider>(),
          chatProvider: context.read<ChatProvider>(),
        ),
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
      return AppLocalizations.of(context)!.walletSetupGenericLinkError;
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
        _error =
            AppLocalizations.of(context)!.walletSetupEnterRecoveryPhraseInline;
        _showMoreOptions = true;
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

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
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
    final resolvedAccountLabel = accountLabel.isEmpty
        ? l10n.walletSetupStatusAuthenticatedAccount
        : accountLabel;

    final busy = _busyAction != null;
    final showStatus = _phase != OnboardingWalletLinkPhase.ready ||
        isLinked ||
        (_error ?? '').isNotEmpty;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quiet account chip: reassures whose identity the wallet will join.
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.walletSetupSignedInAs(resolvedAccountLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        Text(
          l10n.walletSetupTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          l10n.walletSetupSubtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.86),
            height: 1.45,
          ),
        ),
        const SizedBox(height: KubusSpacing.xl),
        KubusButton(
          onPressed: busy || isLinked ? null : () => unawaited(_createWallet()),
          isLoading: _busyAction == OnboardingWalletConnectAction.create,
          isSuccess: isLinked,
          icon: isLinked ? null : Icons.add_rounded,
          label: l10n.walletSetupCreateAction,
          isFullWidth: true,
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          l10n.walletSetupAccountNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.62),
            height: 1.4,
          ),
        ),
        if (!isLinked) ...[
          const SizedBox(height: KubusSpacing.md),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() {
                        _showMoreOptions = !_showMoreOptions;
                        if (!_showMoreOptions) _error = null;
                      });
                    },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.85),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l10n.walletSetupAlreadyHaveWallet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showMoreOptions
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
          // Conditional child (not a cross-fade) so the folded options leave
          // the tree entirely; AnimatedSize keeps the reveal smooth.
          AnimatedSize(
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_showMoreOptions
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: KubusSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _mnemonicController,
                          minLines: 2,
                          maxLines: 4,
                          enabled: !busy,
                          decoration: InputDecoration(
                            labelText: l10n.walletSetupRecoveryPhraseLabel,
                            helperText: l10n.walletSetupImportBody,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: KubusSpacing.sm),
                        KubusOutlineButton(
                          onPressed:
                              busy ? null : () => unawaited(_importWallet()),
                          isLoading: _busyAction ==
                              OnboardingWalletConnectAction.import,
                          icon: Icons.input_outlined,
                          label: l10n.walletSetupImportAction,
                          isFullWidth: true,
                        ),
                        const SizedBox(height: KubusSpacing.sm),
                        KubusOutlineButton(
                          onPressed: busy
                              ? null
                              : () => unawaited(_connectExternalWallet()),
                          isLoading: _busyAction ==
                              OnboardingWalletConnectAction.connect,
                          icon: Icons.account_balance_wallet_outlined,
                          label: l10n.walletSetupConnectAction,
                          isFullWidth: true,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
        // Status appears only once something is happening — progressive
        // disclosure keeps the resting state calm.
        AnimatedSize(
          duration:
              _reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showStatus
              ? Padding(
                  padding: const EdgeInsets.only(top: KubusSpacing.lg),
                  child: _WalletConnectStatusPanel(
                    phase:
                        isLinked && _phase != OnboardingWalletLinkPhase.failed
                            ? OnboardingWalletLinkPhase.linked
                            : _phase,
                    localWallet: (_localWallet ?? '').isEmpty
                        ? null
                        : _truncateWallet(_localWallet!),
                    linkedWallet:
                        isLinked ? _truncateWallet(verifiedWallet) : null,
                    error: _error,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: KubusSpacing.lg,
              horizontal: KubusSpacing.xs,
            ),
            child: Column(
              children: [
                content,
                SizedBox(
                  height: MediaQuery.viewInsetsOf(context).bottom > 0 ? 120 : 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _TimelineState { pending, active, done, failed }

class _WalletConnectStatusPanel extends StatelessWidget {
  const _WalletConnectStatusPanel({
    required this.phase,
    required this.localWallet,
    required this.linkedWallet,
    required this.error,
  });

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

  String _statusHeadline(AppLocalizations l10n) {
    switch (phase) {
      case OnboardingWalletLinkPhase.ready:
        return l10n.walletSetupPhaseReady;
      case OnboardingWalletLinkPhase.creatingWallet:
        return l10n.walletSetupPhaseCreating;
      case OnboardingWalletLinkPhase.walletReady:
        return l10n.walletSetupPhaseWalletReady;
      case OnboardingWalletLinkPhase.linking:
        return l10n.walletSetupPhaseLinking;
      case OnboardingWalletLinkPhase.linked:
        return l10n.walletSetupPhaseLinked;
      case OnboardingWalletLinkPhase.failed:
        return l10n.walletSetupPhaseFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          _TimelineRow(
            label: l10n.walletSetupStatusLocalWallet,
            detail: localWallet,
            state: _localWalletState,
          ),
          const SizedBox(height: KubusSpacing.xs),
          _TimelineRow(
            label: l10n.walletSetupStatusAccountLink,
            detail: null,
            state: _accountLinkState,
          ),
          const SizedBox(height: KubusSpacing.xs),
          _TimelineRow(
            label: l10n.walletSetupStatusVerification,
            detail: linkedWallet == null
                ? null
                : l10n.walletSetupStatusVerifiedLinked(linkedWallet!),
            state: phase == OnboardingWalletLinkPhase.linked
                ? _TimelineState.done
                : _verificationState,
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            _statusHeadline(l10n),
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
