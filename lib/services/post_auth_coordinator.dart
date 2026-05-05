import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../models/user_persona.dart';
import '../providers/profile_provider.dart';
import '../providers/saved_items_provider.dart';
import '../providers/security_gate_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/auth_onboarding_service.dart';
import '../services/auth_redirect_controller.dart';
import '../services/security/post_auth_security_setup_service.dart';
import '../services/telemetry/telemetry_service.dart';
import '../services/wallet_session_sync_service.dart';
import '../utils/wallet_utils.dart';
import '../widgets/wallet_backup_prompts.dart';
import '../l10n/app_localizations.dart';

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
      final prefs = await SharedPreferences.getInstance();
      final data = _mapOrNull(payload['data']) ?? payload;
      final user = _mapOrNull(data['user']) ?? data;
      var normalizedWallet = _walletAddressForFlow(
        walletAddress: walletAddress,
        walletProvider: walletProvider,
        payload: payload,
      );
      final normalizedUserId = (userId ?? user['id'] ?? '').toString().trim();

      setStage(PostAuthStage.preparingSession);
      if (normalizedUserId.isNotEmpty) {
        await prefs.setString('user_id', normalizedUserId);
        TelemetryService().setActorUserId(normalizedUserId);
      }

      setStage(PostAuthStage.securingWallet);
      if (!modalReauth) {
        // Ensure wallet is provisioned from the auth payload before session sync
        String? provisionedWallet = normalizedWallet;
        final expectedWallet = _expectedWalletFromPayload(data, user);

        if (!context.mounted) {
          return const PostAuthResult(completed: false);
        }

        try {
          provisionedWallet = await _ensureWalletProvisioned(
            context: context,
            existingWallet:
                normalizedWallet.isEmpty ? expectedWallet : normalizedWallet,
          );
        } catch (e) {
          AppConfig.debugPrint(
              'PostAuthCoordinator: wallet provisioning failed: $e');
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
          final shouldSyncBackendWallet = origin == AuthOrigin.google &&
              expectedWallet.isNotEmpty &&
              resolvedWallet.isNotEmpty &&
              !WalletUtils.equals(expectedWallet, resolvedWallet);

          try {
            await const WalletSessionSyncService().bindAuthenticatedWallet(
              context: context,
              walletAddress: resolvedWallet,
              userId: normalizedUserId,
              warmUp: true,
              loadProfile:
                  false, // Profile loading happens in loadingProfile stage
              syncBackend: shouldSyncBackendWallet,
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

      setStage(PostAuthStage.loadingProfile);
      final walletForProfile = normalizedWallet.isNotEmpty
          ? normalizedWallet
          : (walletProvider.currentWalletAddress ?? '').trim();
      if (walletForProfile.isNotEmpty) {
        try {
          await profileProvider
              .loadProfile(walletForProfile)
              .timeout(const Duration(seconds: 5));
        } catch (e) {
          AppConfig.debugPrint(
            'PostAuthCoordinator: profile load skipped/failed: $e',
          );
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

  /// Ensure wallet is provisioned for the authenticated user.
  /// Returns the wallet address if successful, null otherwise.
  Future<String?> _ensureWalletProvisioned({
    required BuildContext context,
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
      final recovered = await _attemptEncryptedBackupRecovery(
        context: context,
        walletAddress: targetWallet,
      );
      if (recovered) {
        final restoredWallet =
            (walletProvider.currentWalletAddress ?? '').trim();
        if (walletProvider.hasSigner &&
            WalletUtils.equals(restoredWallet, targetWallet)) {
          return targetWallet;
        }
      }
      return null;
    }

    // No target wallet, try to create a signer-backed wallet
    return _createSignerBackedWallet(walletProvider: walletProvider);
  }

  Future<String?> _createSignerBackedWallet({
    required WalletProvider walletProvider,
  }) async {
    try {
      final result = await walletProvider.createWallet();
      final address = (result['address'] ?? '').trim();
      return address.isEmpty ? null : address;
    } catch (e) {
      AppConfig.debugPrint(
          'PostAuthCoordinator: signer-backed wallet creation failed: $e');
      return null;
    }
  }

  Future<bool> _attemptEncryptedBackupRecovery({
    required BuildContext context,
    required String walletAddress,
  }) async {
    if (!AppConfig.isFeatureEnabled('encryptedWalletBackup')) {
      return false;
    }

    final l10n = AppLocalizations.of(context);
    final walletProvider = context.read<WalletProvider>();
    final backup = await walletProvider.getEncryptedWalletBackup(
      walletAddress: walletAddress,
      refresh: true,
    );

    if (backup == null) {
      return false;
    }

    try {
      if (kIsWeb &&
          AppConfig.isFeatureEnabled('walletBackupPasskeyWeb') &&
          backup.passkeys.isNotEmpty) {
        await walletProvider.authenticateEncryptedWalletBackupPasskey(
          walletAddress: walletAddress,
        );
      }
      if (!context.mounted) return false;

      final recoveryPassword = await showWalletBackupPasswordPrompt(
        context: context,
        title: l10n?.authRestoreWalletTitle ?? 'Restore Wallet',
        description: l10n?.authRestoreWalletBeforeSignInDescription ??
            'Enter your wallet recovery password',
        actionLabel: l10n?.authRestoreWalletAction ?? 'Restore',
      );
      if (!context.mounted || recoveryPassword == null) {
        return false;
      }

      final gate = context.read<SecurityGateProvider>();
      final verified = await gate.requireSensitiveActionVerification();
      if (!context.mounted) return false;
      if (!verified) {
        return false;
      }

      return await walletProvider.restoreSignerFromEncryptedWalletBackup(
        walletAddress: walletAddress,
        recoveryPassword: recoveryPassword,
      );
    } catch (e) {
      AppConfig.debugPrint(
        'PostAuthCoordinator: encrypted backup recovery failed: $e',
      );
      return false;
    }
  }
}
