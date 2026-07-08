import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../models/user_persona.dart';
import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/security_gate_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/auth_onboarding_service.dart';
import '../services/auth_redirect_controller.dart';
import '../services/app_bootstrap_service.dart';
import '../services/security/post_auth_security_setup_service.dart';
import '../services/telemetry/telemetry_service.dart';
import '../services/wallet_session_sync_service.dart';
import '../services/wallet_session_sync_dependencies.dart';
import '../services/wallet_recovery_flow_service.dart';
import '../utils/wallet_utils.dart';

enum PostAuthStage {
  preparingSession,
  securingWallet,
  loadingProfile,
  syncingSavedItems,
  checkingOnboarding,
  openingWorkspace,
  failed,
}

class PostAuthResult {
  const PostAuthResult({
    required this.completed,
    this.routeName,
    this.arguments,
    this.replaceStack = true,
    this.error,
    this.onboardingStepId,
  });

  final bool completed;
  final String? routeName;
  final Object? arguments;
  final bool replaceStack;
  final Object? error;
  final String? onboardingStepId;

  static const failed = PostAuthResult(completed: false);
}

class PostAuthCoordinator {
  const PostAuthCoordinator();

  Future<PostAuthResult> complete({
    required BuildContext context,
    required AuthOrigin origin,
    required Map<String, dynamic> payload,
    String? redirectRoute,
    Object? redirectArguments,
    String? walletAddress,
    Object? userId,
    bool embedded = false,
    bool modalReauth = false,
    bool requiresWalletBackup = false,
    Future<void> Function()? onBeforeSavedItemsSync,
    required ValueChanged<PostAuthStage> onStageChanged,
  }) async {
    void setStage(PostAuthStage stage) {
      onStageChanged(stage);
    }

    try {
      final navigator = Navigator.of(context);
      final walletProvider = context.read<WalletProvider>();
      final profileProvider = context.read<ProfileProvider>();
      final securityGateProvider = context.read<SecurityGateProvider>();
      final savedItemsProvider = context.read<SavedItemsProvider>();
      final walletSessionProviders = WalletSessionSyncProvidersPayload(
        walletProvider: walletProvider,
        profileProvider: profileProvider,
        chatProvider: context.read<ChatProvider>(),
      );
      final prefs = await SharedPreferences.getInstance();
      final data = _mapOrNull(payload['data']) ?? payload;
      final user = _mapOrNull(data['user']) ?? data;
      var normalizedWallet = _walletAddressForFlow(
        walletAddress: walletAddress,
        walletProvider: walletProvider,
        payload: payload,
      );
      final normalizedUserId = (userId ?? user['id'] ?? '').toString().trim();
      final expectedWalletFromPayload = _expectedWalletFromPayload(data, user);
      final isGoogleAuth =
          origin == AuthOrigin.google || origin == AuthOrigin.googleOnboarding;
      final isAccountAuth = isGoogleAuth ||
          origin == AuthOrigin.emailPassword ||
          origin == AuthOrigin.passkey;
      final isGoogleOnboarding = origin == AuthOrigin.googleOnboarding;
      final payloadRequiresWalletSetup = _payloadRequiresWalletSetup(
        payload: payload,
        data: data,
      );
      final accountAuthWithoutWallet = isAccountAuth &&
          expectedWalletFromPayload.isEmpty &&
          (walletAddress ?? '').trim().isEmpty;

      setStage(PostAuthStage.preparingSession);
      if (normalizedUserId.isNotEmpty) {
        await prefs.setString('user_id', normalizedUserId);
        TelemetryService().setActorUserId(normalizedUserId);
      }

      setStage(PostAuthStage.securingWallet);
      if (!modalReauth && !isGoogleOnboarding) {
        // Ensure wallet is provisioned from the auth payload before session sync
        String? provisionedWallet = normalizedWallet;
        final expectedWallet = expectedWalletFromPayload;
        if (accountAuthWithoutWallet) {
          normalizedWallet = '';
          provisionedWallet = null;
        }

        if (!context.mounted) {
          return const PostAuthResult(completed: false);
        }

        if (!accountAuthWithoutWallet) {
          try {
            provisionedWallet = await _ensureWalletProvisioned(
              context: context,
              securityGateProvider: securityGateProvider,
              existingWallet:
                  normalizedWallet.isEmpty ? expectedWallet : normalizedWallet,
            );
          } catch (e) {
            AppConfig.debugPrint(
                'PostAuthCoordinator: wallet provisioning failed: $e');
          }
        }

        var resolvedWallet = (provisionedWallet ?? '').toString().trim();

        // If expected wallet exists but signer restoration/provisioning is not ready,
        // continue with a read-only identity instead of hard-failing auth.
        if (expectedWallet.isNotEmpty && resolvedWallet.isEmpty) {
          try {
            await walletProvider
                .setReadOnlyWalletIdentity(expectedWallet)
                .timeout(const Duration(seconds: 6));
            resolvedWallet = expectedWallet;
          } catch (e) {
            AppConfig.debugPrint(
              'PostAuthCoordinator: fallback read-only wallet identity failed: $e',
            );
          }
        }

        // Sync wallet session with backend
        if (resolvedWallet.isNotEmpty) {
          if (!context.mounted) {
            return const PostAuthResult(completed: false);
          }
          final shouldSyncBackendWallet = isGoogleAuth &&
              expectedWallet.isNotEmpty &&
              resolvedWallet.isNotEmpty &&
              !WalletUtils.equals(expectedWallet, resolvedWallet);

          try {
            await const WalletSessionSyncService().bindAuthenticatedWallet(
              providers: walletSessionProviders,
              walletAddress: resolvedWallet,
              userId: normalizedUserId,
              loadProfile:
                  false, // Profile loading happens in loadingProfile stage
              syncBackend: shouldSyncBackendWallet,
            );
            if (!context.mounted) {
              return const PostAuthResult(completed: false);
            }
            await _warmUpWalletSession(
              context: context,
              walletAddress: resolvedWallet,
            );
            if (!context.mounted) {
              return const PostAuthResult(completed: false);
            }
          } catch (e) {
            AppConfig.debugPrint(
              'PostAuthCoordinator: wallet session sync failed: $e',
            );
          }
        }
        // NOTE: No wallet is ever auto-created or auto-bound for Google/email
        // accounts here. When the authenticated account has no wallet, the
        // redirect below routes into the dedicated WalletSetup step, which
        // binds the wallet to the same users.id through the verified
        // account-link transaction.

        // Update normalized wallet for remaining stages
        if (resolvedWallet.isNotEmpty) {
          normalizedWallet = resolvedWallet;
        }

        // Set backup required flag
        final wallet = normalizedWallet.isNotEmpty
            ? normalizedWallet
            : (walletProvider.currentWalletAddress ?? '').trim();
        final shouldRequireBackup = requiresWalletBackup ||
            (AuthOnboardingService.payloadIndicatesNewAccount(payload) &&
                wallet.isNotEmpty);
        if (shouldRequireBackup &&
            wallet.isNotEmpty &&
            walletProvider.hasSigner) {
          try {
            await walletProvider.setMnemonicBackupRequired(
              required: true,
              walletAddress: wallet,
            );
          } catch (e) {
            AppConfig.debugPrint(
              'PostAuthCoordinator: failed to set wallet backup-required state: $e',
            );
          }
        }
      }

      setStage(PostAuthStage.loadingProfile);
      var walletForProfile = accountAuthWithoutWallet
          ? ''
          : (normalizedWallet.isNotEmpty
              ? normalizedWallet
              : (walletProvider.currentWalletAddress ?? '').trim());
      if (isAccountAuth) {
        try {
          await profileProvider
              .loadAuthenticatedProfile()
              .timeout(const Duration(seconds: 5));
          final hydratedWallet =
              (profileProvider.currentUser?.walletAddress ?? '').trim();
          if (hydratedWallet.isNotEmpty) {
            walletForProfile = hydratedWallet;
            normalizedWallet = hydratedWallet;
          }
        } catch (e) {
          AppConfig.debugPrint(
            'PostAuthCoordinator: authenticated profile load skipped/failed: $e',
          );
        }
      } else if (walletForProfile.isNotEmpty) {
        try {
          await profileProvider
              .loadProfile(
                walletForProfile,
                allowWalletAutoRegister: origin == AuthOrigin.wallet,
              )
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          AppConfig.debugPrint(
            'PostAuthCoordinator: profile load skipped/failed: $e',
          );
        }
      }

      if (!modalReauth) {
        final walletForSecurity = walletForProfile.isNotEmpty
            ? walletForProfile
            : (walletProvider.currentWalletAddress ?? '').trim();
        if (walletForSecurity.isNotEmpty) {
          final securityOk = await const PostAuthSecuritySetupService()
              .ensurePostAuthSecuritySetup(
            navigator: navigator,
            walletProvider: walletProvider,
            securityGateProvider: securityGateProvider,
          );
          if (!context.mounted || !securityOk) {
            return const PostAuthResult(
              completed: false,
              error: 'security-setup-cancelled',
            );
          }
        }
      }

      setStage(PostAuthStage.syncingSavedItems);
      if (onBeforeSavedItemsSync != null) {
        await onBeforeSavedItemsSync();
        if (!context.mounted) {
          return const PostAuthResult(completed: false);
        }
      }

      try {
        await savedItemsProvider.refreshFromBackend();
      } catch (e) {
        AppConfig.debugPrint(
          'PostAuthCoordinator: saved items refresh skipped/failed: $e',
        );
      }

      setStage(PostAuthStage.checkingOnboarding);
      final routeResult =
          await const AuthRedirectController().resolvePostAuthRedirect(
        prefs: prefs,
        payload: payload,
        hasHydratedProfile: profileProvider.hasHydratedProfile,
        requiresWalletBackup: requiresWalletBackup,
        // Account-auth sessions without a wallet always enter the dedicated
        // WalletSetup step; wallet-origin sessions already have one.
        requiresWalletSetup: !modalReauth &&
            (payloadRequiresWalletSetup || isAccountAuth) &&
            walletForProfile.isEmpty,
        walletAddress: walletForProfile.isEmpty ? null : walletForProfile,
        userId: normalizedUserId.isEmpty ? null : normalizedUserId,
        redirectRoute: redirectRoute,
        redirectArguments: redirectArguments,
        heuristicNextStepId: profileProvider.nextStructuredOnboardingStepId,
        persona: profileProvider.userPersona?.storageValue,
        origin: origin,
      );

      setStage(PostAuthStage.openingWorkspace);
      return PostAuthResult(
        completed: true,
        routeName: routeResult.routeName,
        arguments: routeResult.arguments,
        replaceStack: routeResult.removeAuthStack,
        onboardingStepId: routeResult.onboardingStepId,
      );
    } catch (e) {
      AppConfig.debugPrint('PostAuthCoordinator: failed: $e');
      onStageChanged(PostAuthStage.failed);
      return PostAuthResult(completed: false, error: e);
    }
  }

  Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _walletAddressForFlow({
    required String? walletAddress,
    required WalletProvider walletProvider,
    required Map<String, dynamic> payload,
  }) {
    final candidate = (walletAddress ?? '').trim();
    if (candidate.isNotEmpty) return candidate;
    final data = _mapOrNull(payload['data']) ?? payload;
    final user = _mapOrNull(data['user']) ?? data;
    final fromPayload = (user['walletAddress'] ?? user['wallet_address'] ?? '')
        .toString()
        .trim();
    if (fromPayload.isNotEmpty) return fromPayload;
    return (walletProvider.currentWalletAddress ?? '').trim();
  }

  String _expectedWalletFromPayload(
    Map<String, dynamic>? data,
    Map<String, dynamic>? user,
  ) {
    return ((user ?? data)?['walletAddress'] ??
            (user ?? data)?['wallet_address'] ??
            '')
        .toString()
        .trim();
  }

  bool _payloadRequiresWalletSetup({
    required Map<String, dynamic> payload,
    required Map<String, dynamic>? data,
  }) {
    bool readBool(Map<String, dynamic>? source, String key) {
      if (source == null) return false;
      final value = source[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1' || normalized == 'yes';
      }
      return false;
    }

    return readBool(payload, 'requiresWalletSetup') ||
        readBool(data, 'requiresWalletSetup');
  }

  /// Ensure wallet is provisioned for the authenticated user.
  /// Returns the wallet address if successful, null otherwise.
  Future<String?> _ensureWalletProvisioned({
    required BuildContext context,
    required SecurityGateProvider securityGateProvider,
    String? existingWallet,
  }) async {
    final walletProvider = context.read<WalletProvider>();
    final targetWallet = (existingWallet ?? '').trim();

    // Wallet provisioning should be quick, but use a reasonable timeout
    const walletConnectTimeout = Duration(seconds: 6);

    if (targetWallet.isNotEmpty) {
      // Target wallet from auth payload
      final currentWallet = (walletProvider.currentWalletAddress ?? '').trim();
      if (currentWallet.isEmpty ||
          !WalletUtils.equals(currentWallet, targetWallet)) {
        try {
          await walletProvider
              .setReadOnlyWalletIdentity(targetWallet)
              .timeout(walletConnectTimeout);
        } catch (e) {
          AppConfig.debugPrint(
              'PostAuthCoordinator: setReadOnlyWalletIdentity failed: $e');
        }
      }

      if (walletProvider.isReadOnlySession) {
        try {
          final managedEligible =
              await walletProvider.isManagedReconnectEligible();
          if (managedEligible) {
            await walletProvider
                .recoverManagedWalletSession(
                  walletAddress: targetWallet,
                  refreshBackendSession: false,
                )
                .timeout(walletConnectTimeout);
          }
        } catch (e) {
          AppConfig.debugPrint(
              'PostAuthCoordinator: managed reconnect after auth failed: $e');
        }
      }

      final activeWallet = (walletProvider.currentWalletAddress ?? '').trim();
      if (walletProvider.hasSigner &&
          WalletUtils.equals(activeWallet, targetWallet)) {
        return targetWallet;
      }

      // Try encrypted backup recovery if available
      if (!context.mounted) {
        return null;
      }
      WalletRecoveryResult result;
      try {
        result = await const WalletRecoveryFlowService()
            .recoverSignerForAccountWallet(
          context: context,
          walletAddress: targetWallet,
          walletProvider: walletProvider,
          securityGateProvider: securityGateProvider,
          origin: WalletRecoveryOrigin.postAuth,
        );
      } catch (e) {
        AppConfig.debugPrint(
          'PostAuthCoordinator: wallet recovery flow failed: $e',
        );
        result = WalletRecoveryResult(
          kind: WalletRecoveryResultKind.failed,
          walletAddress: targetWallet,
          error: e,
        );
      }
      if (result.restored) {
        final restoredWallet =
            (walletProvider.currentWalletAddress ?? '').trim();
        if (walletProvider.hasSigner &&
            WalletUtils.equals(restoredWallet, targetWallet)) {
          return targetWallet;
        }
      }
      return null;
    }

    // No target wallet: never create one implicitly. Wallet creation happens
    // only in the dedicated WalletSetup step (account-link mode) or in the
    // explicit wallet sign-in flow.
    return null;
  }

  Future<void> _warmUpWalletSession({
    required BuildContext context,
    required String walletAddress,
  }) async {
    try {
      await const AppBootstrapService()
          .warmUp(
            context: context,
            walletAddress: walletAddress,
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      AppConfig.debugPrint('PostAuthCoordinator: bootstrap warm-up failed: $e');
    }
  }
}
