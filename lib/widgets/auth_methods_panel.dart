import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user_persona.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/onboarding/onboarding_flow_screen.dart';
import 'package:art_kubus/services/auth_onboarding_service.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/google_auth_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/security/post_auth_security_setup_service.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:art_kubus/services/wallet_session_sync_service.dart';
import 'package:art_kubus/utils/auth_password_policy.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/auth_google_wallet.dart';
import 'package:art_kubus/utils/wallet_utils.dart';
import 'package:art_kubus/widgets/auth_entry_shell.dart';
import 'package:art_kubus/widgets/email_registration_form.dart';
import 'package:art_kubus/widgets/google_sign_in_button.dart';
import 'package:art_kubus/widgets/google_sign_in_web_button.dart';
import 'package:art_kubus/widgets/auth_wallet_entry_menu.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/wallet_mnemonic_backup_prompt.dart';
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
  static const int _usernameMinLength = 3;
  static const int _usernameMaxLength = 50;

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

  bool _isUsernameTakenConflict(BackendApiRequestException error) {
    try {
      final decoded = jsonDecode((error.body ?? '').toString());
      final bodyMap = decoded is Map<String, dynamic> ? decoded : null;
      final errorCode =
          (bodyMap?['errorCode'] ?? bodyMap?['code'] ?? '').toString().trim();
      if (errorCode.toUpperCase() == 'USERNAME_ALREADY_TAKEN') {
        return true;
      }
      final rawError = (bodyMap?['error'] ?? '').toString().toLowerCase();
      return rawError.contains('username') &&
          (rawError.contains('taken') || rawError.contains('exists'));
    } catch (_) {
      return false;
    }
  }

  String? _validateUsername(
    AppLocalizations l10n,
    String rawUsername, {
    required bool required,
  }) {
    final username = rawUsername.trim();
    if (username.isEmpty) {
      return required ? l10n.profileEditUsernameRequiredError : null;
    }
    if (username.length < _usernameMinLength) {
      return l10n.profileEditUsernameMinLengthError;
    }
    if (username.length > _usernameMaxLength) {
      return l10n.profileEditUsernameMaxLengthError;
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<bool> _maybeRouteToStructuredOnboarding({
    required SharedPreferences prefs,
    required ProfileProvider profileProvider,
    required WalletProvider walletProvider,
    String? walletAddress,
    required Map<String, dynamic> payload,
  }) async {
    if (widget.embedded || widget.onAuthSuccess != null) return false;

    final normalizedWalletAddress = (walletAddress ?? '').trim();
    final flowScopeKey = OnboardingStateService.buildAuthOnboardingScopeKey(
      walletAddress:
          normalizedWalletAddress.isEmpty ? null : normalizedWalletAddress,
      userId: (prefs.getString('user_id') ?? '').trim(),
    );
    final requiresWalletBackup =
        AppConfig.isFeatureEnabled('walletBackupOnboarding')
            ? await walletProvider.isMnemonicBackupRequired(
                walletAddress: walletAddress,
              )
            : false;
    final resumeState =
        await AuthOnboardingService.resolveStructuredOnboardingResume(
      prefs: prefs,
      hasPendingAuthOnboarding:
          OnboardingStateService.hasPendingAuthOnboardingSync(
        prefs,
        scopeKey: flowScopeKey,
      ),
      hasAuthenticatedSession: true,
      hasHydratedProfile: profileProvider.hasHydratedProfile,
      requiresWalletBackup: requiresWalletBackup,
      heuristicNextStepId: profileProvider.nextStructuredOnboardingStepId,
      persona: profileProvider.userPersona?.storageValue,
      payload: payload,
      flowScopeKey: flowScopeKey,
    );
    final nextStepId = resumeState.nextStepId;

    if (!resumeState.requiresStructuredOnboarding ||
        nextStepId == null ||
        nextStepId.isEmpty) {
      await OnboardingStateService.clearPendingAuthOnboarding(
        prefs: prefs,
        scopeKey: flowScopeKey,
      );
      return false;
    }

    await OnboardingStateService.markAuthOnboardingPending(
      prefs: prefs,
      scopeKey: flowScopeKey,
    );
    if (!mounted) return true;

    final isDesktop = DesktopBreakpoints.isDesktop(context);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnboardingFlowScreen(
          forceDesktop: isDesktop,
          initialStepId: nextStepId,
        ),
        settings: const RouteSettings(name: '/onboarding'),
      ),
    );
    return true;
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> payload) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final gate = Provider.of<SecurityGateProvider>(context, listen: false);
    final data = (payload['data'] as Map<String, dynamic>?) ?? payload;
    final user = (data['user'] as Map<String, dynamic>?) ?? data;
    final isNewAccount =
        AuthOnboardingService.payloadIndicatesNewAccount(payload);
    final expectedWalletAddress =
        (user['walletAddress'] ?? user['wallet_address'] ?? '')
            .toString()
            .trim();
    String? walletAddress = expectedWalletAddress;
    final usernameFromUser =
        (user['username'] ?? _usernameController.text ?? '').toString();
    final userId = user['id'];
    try {
      AppConfig.debugPrint(
          'AuthMethodsPanel._handleAuthSuccess: ensuring wallet provisioning');
      walletAddress = await _ensureWalletProvisioned(walletAddress.toString(),
          desiredUsername: usernameFromUser);
    } catch (e) {
      AppConfig.debugPrint('AuthMethodsPanel: wallet provisioning failed: $e');
    }
    var normalizedWalletAddress = (walletAddress ?? '').toString().trim();
    if (expectedWalletAddress.isNotEmpty && normalizedWalletAddress.isEmpty) {
      final signerReady = await _requireSignerForWallet(expectedWalletAddress);
      if (!mounted) return;
      if (!signerReady) {
        await BackendApiService().clearAuth();
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.connectWalletImportFailedToast)),
          tone: KubusSnackBarTone.error,
        );
        return;
      }
      normalizedWalletAddress = expectedWalletAddress;
      walletAddress = expectedWalletAddress;
    }
    if (isNewAccount &&
        normalizedWalletAddress.isNotEmpty &&
        walletProvider.hasSigner &&
        WalletUtils.equals(
          walletProvider.currentWalletAddress,
          normalizedWalletAddress,
        )) {
      try {
        await walletProvider.setMnemonicBackupRequired(
          required: true,
          walletAddress: normalizedWalletAddress,
        );
      } catch (e) {
        AppConfig.debugPrint(
            'AuthMethodsPanel: failed to set wallet backup-required state: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (userId != null && userId.toString().isNotEmpty) {
      await prefs.setString('user_id', userId.toString());
      TelemetryService().setActorUserId(userId.toString());
    }
    if (!mounted) return;

    if (walletAddress != null && walletAddress.toString().isNotEmpty) {
      await const WalletSessionSyncService().bindAuthenticatedWallet(
        context: context,
        walletAddress: walletAddress.toString(),
        userId: userId,
      );
      if (!mounted) return;
    }

    final ok =
        await const PostAuthSecuritySetupService().ensurePostAuthSecuritySetup(
      navigator: navigator,
      walletProvider: walletProvider,
      securityGateProvider: gate,
    );
    if (!mounted) return;
    if (!ok) return;

    try {
      if ((walletAddress == null || walletAddress.toString().isEmpty) &&
          walletProvider.currentWalletAddress != null &&
          walletProvider.currentWalletAddress!.isNotEmpty) {
        await Provider.of<ProfileProvider>(context, listen: false)
            .loadProfile(walletProvider.currentWalletAddress!)
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      AppConfig.debugPrint('AuthMethodsPanel: profile load skipped/failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authAccountCreatedProfileLoading)),
        );
      }
    }
    if (!mounted) return;
    await maybeShowGooglePasswordUpgradePrompt(context, payload);
    if (!mounted) return;
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    if (await _maybeRouteToStructuredOnboarding(
      prefs: prefs,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
      walletAddress: normalizedWalletAddress.isEmpty
          ? walletProvider.currentWalletAddress
          : normalizedWalletAddress,
      payload: payload,
    )) {
      return;
    }
    if (widget.embedded) {
      AppConfig.debugPrint(
          'AuthMethodsPanel._handleAuthSuccess: embedded flow auth success callback');
      if (widget.onAuthSuccess != null) {
        await widget.onAuthSuccess!();
      }
      return;
    }
    AppConfig.debugPrint(
        'AuthMethodsPanel._handleAuthSuccess: navigating to /main');
    navigator.pushReplacementNamed('/main');
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
    final usernameError = _validateUsername(
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
        throw Exception('Signer-backed wallet provisioning failed');
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
      if (e is BackendApiRequestException && e.statusCode == 409) {
        final usernameTaken = _isUsernameTakenConflict(e);
        if (usernameTaken) {
          setState(() {
            _usernameError = l10n.authUsernameAlreadyTaken;
          });
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.authUsernameAlreadyTaken)),
            tone: KubusSnackBarTone.error,
          );
          return;
        }
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.authAccountAlreadyExistsToast)),
          tone: KubusSnackBarTone.error,
        );
        return;
      } else {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.authRegistrationFailed)),
          tone: KubusSnackBarTone.error,
        );
      }
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
              .connectWalletWithAddress(targetWallet)
              .timeout(walletConnectTimeout);
        } catch (e) {
          AppConfig.debugPrint(
              'AuthMethodsPanel: connectWalletWithAddress failed: $e');
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
      final mnemonic = (result['mnemonic'] ?? '').trim();
      if (address.isEmpty || mnemonic.isEmpty) {
        return null;
      }
      if (!mounted) return null;
      final confirmed = await showWalletMnemonicBackupPrompt(
        context: context,
        mnemonic: mnemonic,
        address: address,
      );
      if (!mounted || !confirmed) {
        return null;
      }
      await _upsertProfileWithUsername(address, desiredUsername);
      return address;
    } catch (e) {
      AppConfig.debugPrint(
          'AuthMethodsPanel: signer-backed wallet creation failed: $e');
      return null;
    }
  }

  Future<bool> _requireSignerForWallet(String walletAddress) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectWallet(
          initialStep: 1,
          telemetryAuthFlow: 'signin',
          requiredWalletAddress: walletAddress,
        ),
        settings: const RouteSettings(name: '/connect-wallet/import-required'),
      ),
    );
    if (!mounted) return false;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    return walletProvider.hasSigner &&
        WalletUtils.equals(
          walletProvider.currentWalletAddress,
          walletAddress,
        );
  }

  Future<String?> _prepareProvisionalProfileBeforeRegister({
    required String desiredUsername,
  }) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
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

    try {
      await profileProvider
          .createProfileFromWallet(
            walletAddress: normalizedWallet,
            username: desiredUsername.isNotEmpty ? desiredUsername : null,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      AppConfig.debugPrint(
        'AuthMethodsPanel._prepareProvisionalProfileBeforeRegister: createProfileFromWallet failed: $e',
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', normalizedWallet);
      await prefs.setString('wallet', normalizedWallet);
      await prefs.setString('walletAddress', normalizedWallet);
      await prefs.setBool('has_wallet', true);
    } catch (e) {
      AppConfig.debugPrint(
        'AuthMethodsPanel._prepareProvisionalProfileBeforeRegister: wallet prefs update failed: $e',
      );
    }

    // Do not block registration on profile fetch fallback paths (orbit/source
    // retries can be slow). Provisioning here should stay fast and best-effort.

    return normalizedWallet;
  }

  Future<void> _upsertProfileWithUsername(
      String address, String? desiredUsername) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final effectiveUsername =
        (desiredUsername ?? '').isNotEmpty ? desiredUsername : null;
    try {
      await profileProvider.createProfileFromWallet(
          walletAddress: address, username: effectiveUsername);
    } catch (e) {
      AppConfig.debugPrint(
          'AuthMethodsPanel: createProfileFromWallet failed: $e');
    }
    if (effectiveUsername != null && effectiveUsername.isNotEmpty) {
      try {
        await BackendApiService().updateProfile(address, {
          'username': effectiveUsername,
          'displayName': effectiveUsername,
        });
      } catch (err) {
        AppConfig.debugPrint(
            'AuthMethodsPanel: updateProfile username patch failed: $err');
      }
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
      Map<String, dynamic> result;
      try {
        // For account merge: only pass email, let backend decide on
        // username/profile preservation.
        result = await api.loginWithGoogle(
          idToken: googleResult.idToken,
          code: googleResult.serverAuthCode,
          email: googleResult.email,
          username: null,
          walletAddress: _signerBackedWalletForGoogleAuth(),
        );
      } catch (e) {
        if (!isWalletRequiredForNewGoogleAccount(e)) {
          rethrow;
        }
        final provisionedWallet = await _createSignerBackedWallet();
        if ((provisionedWallet ?? '').trim().isEmpty) {
          throw Exception('Signer-backed wallet provisioning failed');
        }
        result = await api.loginWithGoogle(
          idToken: googleResult.idToken,
          code: googleResult.serverAuthCode,
          email: googleResult.email,
          username: null,
          walletAddress: provisionedWallet,
        );
      }
      await _handleAuthSuccess(result);
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

  Future<void> _openConnectWalletRoute({
    required int initialStep,
    required String routeName,
  }) async {
    final hadAuth =
        (BackendApiService().getAuthToken() ?? '').trim().isNotEmpty;
    final routeResult = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectWallet(
          initialStep: initialStep,
          telemetryAuthFlow: 'signup',
        ),
        settings: RouteSettings(name: routeName),
      ),
    );
    if (!mounted) return;

    final hasAuthNow =
        (BackendApiService().getAuthToken() ?? '').trim().isNotEmpty;
    if (!hadAuth && hasAuthNow) {
      if (routeResult is Map<String, dynamic>) {
        await _handleAuthSuccess(routeResult);
        return;
      }
      if (widget.embedded) {
        if (widget.onAuthSuccess != null) {
          await widget.onAuthSuccess!();
        }
      } else {
        Navigator.of(context).pushReplacementNamed('/main');
      }
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
    final option = await showAuthWalletEntryMenu(
      context: context,
      description: l10n.authConnectWalletModalDescriptionRegister,
    );
    if (!mounted || option == null) return;
    await _openConnectWalletRoute(
      initialStep: option.initialStep,
      routeName: option.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
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

    final form = _buildRegisterForm(
      colorScheme: colorScheme,
      enableWallet: enableWallet,
      enableEmail: enableEmail,
      enableGoogle: enableGoogle,
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

  Widget _buildRegisterForm({
    required ColorScheme colorScheme,
    required bool enableWallet,
    required bool enableEmail,
    required bool enableGoogle,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showEmailForm = _showCompactEmailForm;
    final compactLayout =
        widget.embedded || MediaQuery.sizeOf(context).height < 820;
    final showSectionCopy = !widget.embedded && !compactLayout;
    final emailSurface = Color.lerp(
        colorScheme.surface, colorScheme.primary, isDark ? 0.18 : 0.10)!;
    final walletSurface = Color.lerp(
      colorScheme.surface,
      roles.web3MarketplaceAccent,
      isDark ? 0.24 : 0.14,
    )!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSectionCopy) ...[
          Text(
            showEmailForm ? l10n.authOrUseEmail : l10n.authRegisterSubtitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            showEmailForm
                ? l10n.authRegisterSubtitle
                : l10n.authHighlightOptionalWeb3,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.66),
                  height: 1.45,
                ),
          ),
          SizedBox(height: compactLayout ? KubusSpacing.md : KubusSpacing.lg),
        ],
        if (!showEmailForm && enableGoogle) ...[
          if (kIsWeb)
            GoogleSignInWebButton(
              colorScheme: colorScheme,
              isLoading: _isGoogleSubmitting,
              onAuthResult: (GoogleAuthResult googleResult) async {
                unawaited(
                  TelemetryService().trackSignUpAttempt(method: 'google'),
                );
                if (!_isGoogleSubmitting && mounted) {
                  setState(() => _isGoogleSubmitting = true);
                }
                try {
                  final api = BackendApiService();
                  final result = await api.loginWithGoogle(
                    idToken: googleResult.idToken,
                    code: googleResult.serverAuthCode,
                    email: googleResult.email,
                    username: null,
                    walletAddress: _signerBackedWalletForGoogleAuth(),
                  );
                  if (!mounted) return;
                  await _handleAuthSuccess(result);
                  unawaited(
                    TelemetryService().trackSignUpSuccess(method: 'google'),
                  );
                } finally {
                  if (mounted) {
                    setState(() => _isGoogleSubmitting = false);
                  }
                }
              },
              onAuthError: (Object error) {
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
            )
          else
            GoogleSignInButton(
              onPressed: _registerWithGoogle,
              isLoading: _isGoogleSubmitting,
              colorScheme: colorScheme,
            ),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
        ],
        if (!showEmailForm && enableEmail) ...[
          KubusButton(
            onPressed: () {
              setState(() => _showCompactEmailForm = true);
            },
            icon: Icons.email_outlined,
            label: l10n.authContinueWithEmail,
            variant: KubusButtonVariant.secondary,
            backgroundColor: emailSurface,
            foregroundColor: colorScheme.onSurface,
            isFullWidth: true,
          ),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
        ],
        if (!showEmailForm && enableWallet) ...[
          if (showSectionCopy)
            _buildMethodDivider(l10n.authHighlightOptionalWeb3),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
          KubusButton(
            onPressed: _showConnectWalletModal,
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.authConnectWalletButton,
            variant: KubusButtonVariant.secondary,
            backgroundColor: walletSurface,
            foregroundColor: colorScheme.onSurface,
            isFullWidth: true,
          ),
        ],
        if (showEmailForm) ...[
          _buildEmailForm(compact: compactLayout),
          const SizedBox(height: KubusSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => _showCompactEmailForm = false);
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.82),
              ),
              child: Text(l10n.commonBack),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmailForm({bool compact = false}) {
    final l10n = AppLocalizations.of(context)!;
    return EmailRegistrationForm(
      emailController: _emailController,
      passwordController: _passwordController,
      confirmPasswordController: _confirmPasswordController,
      usernameController: _usernameController,
      requireUsername: widget.requireUsernameForEmailRegistration,
      showUsernameInCompact: widget.requireUsernameForEmailRegistration,
      emailError: _emailError,
      passwordError: _passwordError,
      confirmPasswordError: _confirmPasswordError,
      usernameError: _usernameError,
      onSubmit: _registerWithEmail,
      isSubmitting: _isSubmitting,
      compact: compact,
      autofocusEmail: true,
      submitLabel: l10n.authContinueWithEmail,
      submittingLabel: l10n.commonWorking,
    );
  }

  Widget _buildMethodDivider(String label) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.sm),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            height: 1,
          ),
        ),
      ],
    );
  }
}
