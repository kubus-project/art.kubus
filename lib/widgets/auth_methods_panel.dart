import 'dart:async';
import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/auth_success_handoff_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/google_auth_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:art_kubus/utils/auth_password_policy.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/auth_google_wallet.dart';
import 'package:art_kubus/utils/wallet_utils.dart';
import 'package:art_kubus/utils/auth_wallet_result_normalizer.dart';
import 'package:art_kubus/widgets/auth_entry_shell.dart';
import 'package:art_kubus/widgets/auth/post_auth_loading_screen.dart';
import 'package:art_kubus/widgets/auth_methods_panel_helpers.dart';
import 'package:art_kubus/widgets/auth_methods_panel_sections.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/wallet_backup_prompts.dart';
import 'package:art_kubus/widgets/secure_account_password_prompt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthMethodsPanel extends StatefulWidget {
  const AuthMethodsPanel({
    super.key,
    this.embedded = false,
    this.onAuthSuccess,
    this.onVerificationRequired,
    this.onEmailRegistrationAttempted,
    this.onEmailCredentialsCaptured,
    this.preferredEmailGreetingName,
    this.prepareProvisionalProfileBeforeRegister = false,
    this.requireUsernameForEmailRegistration = false,
    this.onError,
    this.onSwitchToSignIn,
  });

  final bool embedded;
  final Future<void> Function()? onAuthSuccess;
  final ValueChanged<String>? onVerificationRequired;
  final ValueChanged<String>? onEmailRegistrationAttempted;
  final Future<void> Function(String email, String password)?
      onEmailCredentialsCaptured;
  final String? preferredEmailGreetingName;
  final bool prepareProvisionalProfileBeforeRegister;
  final bool requireUsernameForEmailRegistration;
  final ValueChanged<Object>? onError;
  final VoidCallback? onSwitchToSignIn;

  @override
  State<AuthMethodsPanel> createState() => _AuthMethodsPanelState();
}

class _AuthMethodsPanelState extends State<AuthMethodsPanel> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _usernameError;
  bool _showCompactEmailForm = false;
  bool _showAlternativeMethods = false;
  bool _walletFlowOpening = false;
  bool _showInlineWalletFlow = false;
  int _walletInlineInitialStep = 0;
  String? _walletInlineRequiredWalletAddress;
  Completer<Object?>? _walletFlowCompleter;

  // Post-auth state - shows loading surface instead of auth form
  bool _postAuthActive = false;
  Map<String, dynamic>? _postAuthPayload;
  AuthOrigin? _postAuthOrigin;
  String? _postAuthWalletAddress;
  Object? _postAuthUserId;

  @override
  void dispose() {
    final completer = _walletFlowCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _completeInlineWalletFlow([Object? result]) {
    if (mounted && _showInlineWalletFlow) {
      setState(() {
        _showInlineWalletFlow = false;
        _walletInlineInitialStep = 0;
        _walletInlineRequiredWalletAddress = null;
      });
    }
    final completer = _walletFlowCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  Future<void> _handleAuthSuccess(
    Map<String, dynamic> payload, {
    AuthOrigin origin = AuthOrigin.emailPassword,
  }) async {
    final navigator = Navigator.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final data = (payload['data'] as Map<String, dynamic>?) ?? payload;
    final user = (data['user'] as Map<String, dynamic>?) ?? data;

    // Normalize payload and collect values for post-auth
    final userId = user['id'];
    final walletAddressFromPayload =
        (user['walletAddress'] ?? user['wallet_address'] ?? '')
            .toString()
            .trim();
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    
    final normalizedWalletAddress = walletAddressFromPayload.isNotEmpty
        ? walletAddressFromPayload
        : (walletProvider.currentWalletAddress ?? '').trim();

    // Set post-auth state immediately. This will cause rebuild() to show
    // PostAuthLoadingScreen instead of auth form.
    // Auth UI must not remain visible while post-auth work runs.
    if (!mounted) return;
    setState(() {
      _postAuthActive = true;
      _postAuthPayload = payload;
      _postAuthOrigin = origin;
      _postAuthWalletAddress = normalizedWalletAddress;
      _postAuthUserId = userId;
    });

    // For non-embedded flows, push PostAuthLoadingScreen route
    if (!widget.embedded) {
      await const AuthSuccessHandoffService().handle(
        navigator: navigator,
        isMounted: () => mounted,
        screenWidth: screenWidth,
        payload: payload,
        origin: origin,
        walletAddress: normalizedWalletAddress,
        userId: userId,
        embedded: widget.embedded,
        modalReauth: false,
        requiresWalletBackup: false,
        onBeforeSavedItemsSync: (origin == AuthOrigin.google ||
                origin == AuthOrigin.wallet)
            ? null
            : () => maybeShowGooglePasswordUpgradePrompt(context, payload),
        onAuthSuccess: widget.onAuthSuccess == null
            ? null
            : (_) async {
                await widget.onAuthSuccess!();
              },
      );
    }
    // For embedded flows, local build() will show PostAuthLoadingScreen
    // because _postAuthActive is true
  }

  @visibleForTesting
  Future<void> debugTriggerAuthSuccess(
    Map<String, dynamic> payload, {
    AuthOrigin origin = AuthOrigin.emailPassword,
  }) {
    return _handleAuthSuccess(payload, origin: origin);
  }

  Future<void> _registerWithEmail() async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!AppConfig.enableEmailAuth) {
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.authEmailRegistrationDisabled)));
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final username = _usernameController.text.trim();
    const profileDisplayNameMaxLength = 100;
    final rawGreetingName = (widget.preferredEmailGreetingName ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final greetingName = rawGreetingName.isEmpty
        ? null
        : (rawGreetingName.length > profileDisplayNameMaxLength
            ? rawGreetingName.substring(0, profileDisplayNameMaxLength)
            : rawGreetingName);
    final fallbackDisplayNameFromUsername = username.isEmpty
        ? null
        : (username.length > profileDisplayNameMaxLength
            ? username.substring(0, profileDisplayNameMaxLength)
            : username);
    final effectiveDisplayName =
        greetingName ?? fallbackDisplayNameFromUsername;
    final emailLooksValid = email.contains('@') && email.contains('.');
    final passwordOk = AuthPasswordPolicy.isValid(password);
    final confirmOk = password == confirm;
    final usernameError = validateAuthMethodsPanelUsername(
      l10n,
      username,
      required: widget.requireUsernameForEmailRegistration,
    );
    final usernameOk = usernameError == null;

    setState(() {
      _emailError = emailLooksValid ? null : l10n.authEnterValidEmailInline;
      _passwordError = passwordOk ? null : l10n.authPasswordPolicyError;
      _confirmPasswordError =
          confirmOk ? null : l10n.authPasswordMismatchInline;
      _usernameError = usernameError;
    });
    if (!emailLooksValid || !passwordOk || !confirmOk || !usernameOk) return;

    unawaited(TelemetryService().trackSignUpAttempt(method: 'email'));
    setState(() => _isSubmitting = true);
    try {
      AppConfig.debugPrint(
          'AuthMethodsPanel._registerWithEmail: start email registration for $email');
      AppConfig.debugPrint(
          'AuthMethodsPanel._registerWithEmail: preparing signer-backed wallet');
      final provisionalWalletAddress =
          await _prepareProvisionalProfileBeforeRegister(
        desiredUsername: username,
      ).timeout(const Duration(seconds: 20));
      if ((provisionalWalletAddress ?? '').trim().isEmpty) {
        throw Exception(l10n.authSignerProvisioningFailed);
      }
      final api = BackendApiService();
      await api
          .registerWithEmail(
            email: email,
            password: password,
            username: username.isNotEmpty ? username : null,
            displayName: effectiveDisplayName,
            walletAddress: provisionalWalletAddress,
          )
          .timeout(const Duration(seconds: 16));
      AppConfig.debugPrint(
          'AuthMethodsPanel._registerWithEmail: registerWithEmail completed');
      widget.onEmailRegistrationAttempted?.call(email);
      if (widget.onEmailCredentialsCaptured != null) {
        await widget.onEmailCredentialsCaptured!(email, password);
      }
      final prefs = await SharedPreferences.getInstance();
      final authOnboardingScopeKey =
          OnboardingStateService.buildAuthOnboardingScopeKey(
        walletAddress: provisionalWalletAddress,
      );
      await OnboardingStateService.markAuthOnboardingPending(
        prefs: prefs,
        scopeKey: authOnboardingScopeKey,
      );
      if (!mounted) return;
      if (widget.embedded) {
        // Embedded onboarding is verification-first: avoid immediate login
        // attempts that fail on unverified accounts and confuse the flow.
        widget.onVerificationRequired?.call(email);
      } else {
        navigator.pushReplacementNamed(
          '/verify-email',
          arguments: {'email': email},
        );
      }
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.authVerifyEmailRegistrationToast)),
      );
      unawaited(TelemetryService().trackSignUpSuccess(method: 'email'));
      AppConfig.debugPrint(
          'AuthMethodsPanel._registerWithEmail: success path complete');
      // Note: email registration no longer creates a session until verification.
      // Avoid writing local account/session state here.
    } on TimeoutException catch (e) {
      widget.onError?.call(e);
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonNetworkErrorToast)),
      );
    } catch (e) {
      widget.onError?.call(e);
      unawaited(TelemetryService().trackSignUpFailure(
          method: 'email', errorClass: e.runtimeType.toString()));
      if (!mounted) return;
      final usernameTaken = isAuthMethodsPanelUsernameTakenConflict(e);
      if (usernameTaken) {
        setState(() {
          _emailError = null;
          _usernameError = l10n.authUsernameAlreadyTaken;
          _showCompactEmailForm = true;
        });
        return;
      }

      if (isAuthMethodsPanelDuplicateEmailConflict(e)) {
        setState(() {
          _emailError = l10n.authAccountAlreadyExistsToast;
          _showCompactEmailForm = true;
        });
        return;
      }

      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.authRegistrationFailed)),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      AppConfig.debugPrint(
          'AuthMethodsPanel._registerWithEmail: clearing submit loading state');
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String?> _ensureWalletProvisioned(String? existingWallet,
      {String? desiredUsername}) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final targetWallet = (existingWallet ?? '').trim();
    final signerWallet = _signerBackedWalletForGoogleAuth();

    // Keep auth completion offline-friendly. RPC recovery should never block
    // the UI indefinitely.
    const walletConnectTimeout = Duration(seconds: 6);

    if (targetWallet.isNotEmpty) {
      if (signerWallet != null &&
          WalletUtils.equals(signerWallet, targetWallet)) {
        return targetWallet;
      }

      final currentWallet = (walletProvider.currentWalletAddress ?? '').trim();
      if (currentWallet.isEmpty ||
          !WalletUtils.equals(currentWallet, targetWallet)) {
        try {
          await walletProvider
              .setReadOnlyWalletIdentity(targetWallet)
              .timeout(walletConnectTimeout);
        } catch (e) {
          AppConfig.debugPrint(
              'AuthMethodsPanel: setReadOnlyWalletIdentity failed: $e');
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
              'AuthMethodsPanel: managed reconnect after auth failed: $e');
        }
      }

      final activeWallet = (walletProvider.currentWalletAddress ?? '').trim();
      if (walletProvider.hasSigner &&
          WalletUtils.equals(activeWallet, targetWallet)) {
        return targetWallet;
      }
      final recovered = await _attemptEncryptedBackupRecovery(targetWallet);
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

    if (signerWallet != null && signerWallet.isNotEmpty) {
      return signerWallet;
    }

    return _createSignerBackedWallet(desiredUsername: desiredUsername);
  }

  Future<String?> _createSignerBackedWallet({String? desiredUsername}) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    try {
      final result = await walletProvider
          .createWallet()
          .timeout(const Duration(seconds: 12));
      final address = (result['address'] ?? '').trim();
      return address.isEmpty ? null : address;
    } catch (e) {
      AppConfig.debugPrint(
          'AuthMethodsPanel: signer-backed wallet creation failed: $e');
      return null;
    }
  }

  Future<String?> _prepareProvisionalProfileBeforeRegister({
    required String desiredUsername,
  }) async {
    String? walletAddress;
    try {
      walletAddress = await _ensureWalletProvisioned(
        null,
        desiredUsername: desiredUsername,
      );
    } catch (e) {
      AppConfig.debugPrint(
        'AuthMethodsPanel._prepareProvisionalProfileBeforeRegister: wallet provisioning failed: $e',
      );
    }

    final normalizedWallet = walletAddress?.trim();
    if (normalizedWallet == null || normalizedWallet.isEmpty) {
      return null;
    }

    return normalizedWallet;
  }

  Future<bool> _attemptEncryptedBackupRecovery(String walletAddress) async {
    if (!AppConfig.isFeatureEnabled('encryptedWalletBackup')) {
      return false;
    }

    final l10n = AppLocalizations.of(context)!;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
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
      if (!mounted) return false;

      final recoveryPassword = await showWalletBackupPasswordPrompt(
        context: context,
        title: l10n.authRestoreWalletTitle,
        description: l10n.authRestoreWalletForAccountDescription,
        actionLabel: l10n.authRestoreWalletAction,
      );
      if (!mounted || recoveryPassword == null) {
        return false;
      }

      final gate = Provider.of<SecurityGateProvider>(context, listen: false);
      final verified = await gate.requireSensitiveActionVerification();
      if (!mounted) return false;
      if (!verified) {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.lockAuthenticationFailedToast)),
          tone: KubusSnackBarTone.error,
        );
        return false;
      }

      return await walletProvider.restoreSignerFromEncryptedWalletBackup(
        walletAddress: walletAddress,
        recoveryPassword: recoveryPassword,
      );
    } catch (e) {
      if (!mounted) return false;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(e.toString())),
        tone: KubusSnackBarTone.error,
      );
      return false;
    }
  }

  Future<void> _registerWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableGoogleAuth) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authGoogleSignInDisabled)));
      return;
    }

    // Web sign-in is handled by the dedicated web button widget.
    if (kIsWeb) {
      return;
    }
    unawaited(TelemetryService().trackSignUpAttempt(method: 'google'));
    setState(() => _isGoogleSubmitting = true);
    try {
      final googleResult = await GoogleAuthService().signIn();
      if (googleResult == null) {
        unawaited(TelemetryService()
            .trackSignUpFailure(method: 'google', errorClass: 'cancelled'));
        setState(() => _isGoogleSubmitting = false);
        return;
      }
      final api = BackendApiService();
      final result = await loginWithGoogleWalletRecovery(
        api: api,
        googleResult: googleResult,
        walletAddress: _signerBackedWalletForGoogleAuth(),
        createSignerBackedWallet: _createSignerBackedWallet,
      );
      await _handleAuthSuccess(result, origin: AuthOrigin.google);
      unawaited(TelemetryService().trackSignUpSuccess(method: 'google'));
    } catch (e) {
      widget.onError?.call(e);
      unawaited(TelemetryService().trackSignUpFailure(
          method: 'google', errorClass: e.runtimeType.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authGoogleSignInFailed)));
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  void _navigateToSignIn() {
    if (widget.onSwitchToSignIn != null) {
      widget.onSwitchToSignIn!.call();
      return;
    }
    Navigator.of(context).pushReplacementNamed('/sign-in');
  }

  Future<void> _showConnectWalletFlow({
    int initialStep = 0,
    String? requiredWalletAddress,
  }) async {
    if (_walletFlowOpening) {
      await _walletFlowCompleter?.future;
      return;
    }

    final api = BackendApiService();
    final hadAuthBeforeOpen = (api.getAuthToken() ?? '').trim().isNotEmpty;
    _walletFlowOpening = true;
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final completer = Completer<Object?>();
      _walletFlowCompleter = completer;
      if (mounted) {
        setState(() {
          _showInlineWalletFlow = true;
          _walletInlineInitialStep = initialStep;
          _walletInlineRequiredWalletAddress = requiredWalletAddress;
          _showCompactEmailForm = false;
          _showAlternativeMethods = false;
        });
      }

      final routeResult = await completer.future;
      if (!mounted) return;

      if (kDebugMode) {
        AppConfig.debugPrint(
          'AuthMethodsPanel.wallet: flow completed with result type=${routeResult.runtimeType}',
        );
      }

      // Normalize wallet auth result using comprehensive helper
      final apiForNormalize = BackendApiService();
      final normalizedPayload = await normalizeWalletAuthResult(
        routeResult: routeResult,
        api: apiForNormalize,
      );

      if (kDebugMode) {
        AppConfig.debugPrint(
          'AuthMethodsPanel.wallet: normalized payload=${normalizedPayload != null ? 'present' : 'null'}, auth_token=${(apiForNormalize.getAuthToken() ?? '').trim().isNotEmpty}',
        );
      }

      if (!mounted) return;

      if (normalizedPayload != null) {
        // Success: we have a valid auth payload
        await _handleAuthSuccess(normalizedPayload, origin: AuthOrigin.wallet);
        unawaited(TelemetryService().trackSignUpSuccess(method: 'wallet'));
        return;
      }

      // No normalized payload and no auth token: treat as cancel
      if ((apiForNormalize.getAuthToken() ?? '').trim().isEmpty &&
          hadAuthBeforeOpen == false) {
        if (kDebugMode) {
          AppConfig.debugPrint(
            'AuthMethodsPanel.wallet: no payload and no auth token, treating as cancel',
          );
        }
        unawaited(TelemetryService().trackSignUpFailure(
          method: 'wallet',
          errorClass: 'wallet_cancelled',
        ));
        return;
      }

      // Shouldn't reach here: auth token exists but no payload
      if (kDebugMode) {
        AppConfig.debugPrint(
          'AuthMethodsPanel.wallet: WARNING - auth token exists but no normalized payload',
        );
      }
      unawaited(TelemetryService().trackSignUpFailure(
        method: 'wallet',
        errorClass: 'wallet_payload_empty',
      ));
    } finally {
      // Do not restore wallet UI state if post-auth is active
      if (!_postAuthActive && mounted && _walletFlowOpening) {
        _walletFlowOpening = false;
      }
      _walletFlowCompleter = null;
    }
  }

  String? _signerBackedWalletForGoogleAuth() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    return signerBackedGoogleWalletAddress(
      hasSigner: walletProvider.hasSigner,
      currentWalletAddress: walletProvider.currentWalletAddress,
    );
  }

  Future<void> _showConnectWalletModal() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableWalletConnect || !AppConfig.enableWeb3) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authWalletConnectionDisabled)));
      return;
    }
    unawaited(TelemetryService().trackSignUpAttempt(method: 'wallet'));
    await _showConnectWalletFlow();
  }

  @override
  Widget build(BuildContext context) {
    // If post-auth is in progress, show loading screen instead of auth form
    if (_postAuthActive) {
      return PostAuthLoadingScreen(
        payload: _postAuthPayload ?? {},
        origin: _postAuthOrigin ?? AuthOrigin.emailPassword,
        walletAddress: _postAuthWalletAddress,
        userId: _postAuthUserId,
        embedded: widget.embedded,
        modalReauth: false,
        requiresWalletBackup: false,
        onAuthSuccess: widget.onAuthSuccess == null
            ? null
            : (_) async {
                await widget.onAuthSuccess!();
              },
      );
    }

    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final accentStart = roles.lockedFeature;
    final accentEnd = roles.likeAction;
    final isDark = theme.brightness == Brightness.dark;
    final enableWallet = AppConfig.enableWeb3 && AppConfig.enableWalletConnect;
    final enableEmail = AppConfig.enableEmailAuth;
    final enableGoogle = AppConfig.enableGoogleAuth;
    final compactLayout =
        widget.embedded || MediaQuery.sizeOf(context).height < 820;

    final form = AuthMethodsPanelRegistrationMethods(
      embedded: widget.embedded,
      colorScheme: colorScheme,
      roles: roles,
      showCompactEmailForm: _showCompactEmailForm,
      showInlineWalletFlow: _showInlineWalletFlow,
      compactLayout: compactLayout,
      enableWallet: enableWallet,
      enableEmail: enableEmail,
      enableGoogle: enableGoogle,
      showAlternativeMethods: _showAlternativeMethods,
      isGoogleSubmitting: _isGoogleSubmitting,
      emailFormShell: AuthMethodsPanelEmailFormShell(
        emailController: _emailController,
        passwordController: _passwordController,
        confirmPasswordController: _confirmPasswordController,
        usernameController: _usernameController,
        requireUsername: widget.requireUsernameForEmailRegistration,
        emailError: _emailError,
        passwordError: _passwordError,
        confirmPasswordError: _confirmPasswordError,
        usernameError: _usernameError,
        onSubmit: _registerWithEmail,
        isSubmitting: _isSubmitting,
        compact: compactLayout,
        onBack: () {
          setState(() => _showCompactEmailForm = false);
        },
      ),
      inlineWalletSurface: AuthMethodsPanelInlineWalletSurface(
        initialStep: _walletInlineInitialStep,
        requiredWalletAddress: _walletInlineRequiredWalletAddress,
        onRequestClose: () => _completeInlineWalletFlow(),
        onFlowComplete: (result) => _completeInlineWalletFlow(result),
      ),
      onShowCompactEmailForm: () {
        setState(() {
          _showCompactEmailForm = true;
          _showAlternativeMethods = true;
        });
      },
      onToggleAlternativeMethods: (visible) {
        setState(() => _showAlternativeMethods = visible);
      },
      onShowConnectWalletModal: _showConnectWalletModal,
      onGooglePressed: _registerWithGoogle,
      onWebGoogleAuthResult: (GoogleAuthResult googleResult) async {
        unawaited(
          TelemetryService().trackSignUpAttempt(method: 'google'),
        );
        if (!_isGoogleSubmitting && mounted) {
          setState(() => _isGoogleSubmitting = true);
        }
        try {
          final api = BackendApiService();
          final result = await loginWithGoogleWalletRecovery(
            api: api,
            googleResult: googleResult,
            walletAddress: _signerBackedWalletForGoogleAuth(),
            createSignerBackedWallet: _createSignerBackedWallet,
          );
          if (!mounted) return;
          await _handleAuthSuccess(result, origin: AuthOrigin.google);
          unawaited(
            TelemetryService().trackSignUpSuccess(method: 'google'),
          );
        } finally {
          if (mounted) {
            setState(() => _isGoogleSubmitting = false);
          }
        }
      },
      onWebGoogleAuthError: (Object error) {
        widget.onError?.call(error);
        unawaited(
          TelemetryService().trackSignUpFailure(
            method: 'google',
            errorClass: error.runtimeType.toString(),
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authGoogleSignInFailed)),
        );
      },
    );

    if (widget.embedded) {
      return form;
    }

    return AuthEntryShell(
      title: l10n.authRegisterTitle,
      subtitle: l10n.authRegisterSubtitle,
      heroIcon: Icons.person_add_alt_rounded,
      gradientStart: accentStart,
      gradientEnd: accentEnd,
      highlights: [
        l10n.authHighlightOnboardingOptions,
        l10n.authHighlightKeysLocal,
        l10n.authHighlightOptionalWeb3,
      ],
      topAction: TextButton(
        onPressed: _navigateToSignIn,
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor:
              colorScheme.surface.withValues(alpha: isDark ? 0.16 : 0.78),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.md,
            vertical: 10,
          ),
        ),
        child: Text(l10n.commonSignIn),
      ),
      form: form,
    );
  }
}
