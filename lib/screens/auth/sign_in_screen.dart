import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/config.dart';
import '../../providers/profile_provider.dart';
import '../../providers/security_gate_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/auth_redirect_controller.dart';
import '../../services/auth_onboarding_service.dart';
import '../../services/backend_api_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/security/post_auth_security_setup_service.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../../services/wallet_session_sync_service.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/google_sign_in_web_button.dart';
import '../../widgets/secure_account_password_prompt.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/auth_entry_shell.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/auth_google_wallet.dart';
import '../../utils/keyboard_inset_resolver.dart';
import '../../utils/wallet_utils.dart';
import '../web3/wallet/connectwallet_screen.dart';
import '../community/profile_edit_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import '../../widgets/wallet_backup_prompts.dart';

enum _AuthOrigin { emailPassword, google }

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.redirectRoute,
    this.redirectArguments,
    this.initialEmail,
    this.onAuthSuccess,
    this.embedded = false,
    this.openWalletFlowOnStart = false,
    this.onVerificationRequired,
    this.onSwitchToRegister,
  });

  final String? redirectRoute;
  final Object? redirectArguments;
  final String? initialEmail;
  final FutureOr<void> Function(Map<String, dynamic> payload)? onAuthSuccess;
  final bool embedded;
  final bool openWalletFlowOnStart;
  final ValueChanged<String>? onVerificationRequired;
  final VoidCallback? onSwitchToRegister;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isEmailSubmitting = false;
  bool _isGoogleSubmitting = false;
  bool _obscureEmailPassword = true;
  int? _googleRateLimitUntilMs;
  String _googleAuthDiagStage = 'idle';
  String? _googleAuthDiagCode;
  bool _showCompactEmailForm = false;
  bool _showAlternativeMethods = false;
  bool _walletFlowOpening = false;
  bool _showInlineWalletFlow = false;
  int _walletInlineInitialStep = 0;
  String? _walletInlineRequiredWalletAddress;
  Completer<Object?>? _walletFlowCompleter;

  @override
  void initState() {
    super.initState();
    final seededEmail = (widget.initialEmail ?? '').trim();
    if (seededEmail.isNotEmpty) {
      _emailController.text = seededEmail;
    }
    // Preload rate-limit cooldown so the Google sign-in click handler can
    // start the popup flow without awaiting (browser user-activation rules).
    unawaited(_loadGoogleAuthCooldown());

    if (widget.openWalletFlowOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_showConnectWalletFlow());
      });
    }
  }

  Future<void> _loadGoogleAuthCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final untilMs = prefs.getInt('rate_limit_auth_google_until');
      if (!mounted) return;
      _googleRateLimitUntilMs = untilMs;
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  void dispose() {
    final completer = _walletFlowCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
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

  void _setGoogleAuthDiagnostics(String stage, {String? code}) {
    _googleAuthDiagStage = stage;
    _googleAuthDiagCode = code;
    if (kDebugMode) {
      AppConfig.debugPrint(
        'SignInScreen.googleAuth stage=$_googleAuthDiagStage code=${_googleAuthDiagCode ?? 'none'}',
      );
    }
  }

  String _googleErrorCode(Object error) {
    if (error is BackendApiRequestException) {
      try {
        final parsed = jsonDecode((error.body ?? '').toString());
        if (parsed is Map) {
          final code =
              (parsed['errorCode'] ?? parsed['code'] ?? '').toString().trim();
          if (code.isNotEmpty) return code;
        }
      } catch (_) {}
      return 'http_${error.statusCode}';
    }
    return error.runtimeType.toString();
  }

  bool _isEmailPasswordNotConfigured(Object error) {
    if (error is! BackendApiRequestException) {
      return false;
    }
    if (error.statusCode != 400) {
      return false;
    }

    try {
      final decoded = jsonDecode((error.body ?? '').toString().trim());
      if (decoded is Map<String, dynamic>) {
        final code =
            (decoded['errorCode'] ?? '').toString().trim().toUpperCase();
        if (code == 'EMAIL_PASSWORD_NOT_CONFIGURED') {
          return true;
        }
        final rawError =
            (decoded['error'] ?? '').toString().trim().toLowerCase();
        if (rawError.contains('password not set for this account')) {
          return true;
        }
      }
    } catch (_) {
      // Fall through to false.
    }

    return false;
  }

  Future<bool> _maybeRouteToStructuredOnboarding({
    required SharedPreferences prefs,
    required ProfileProvider profileProvider,
    required WalletProvider walletProvider,
    String? walletAddress,
    required Map<String, dynamic> payload,
  }) async {
    if (widget.embedded || widget.onAuthSuccess != null) return false;

    return const AuthRedirectController().routeAfterAuth(
      context: context,
      prefs: prefs,
      profileProvider: profileProvider,
      walletProvider: walletProvider,
      walletAddress: walletAddress,
      userId: (prefs.getString('user_id') ?? '').trim(),
      payload: payload,
      redirectRoute: widget.redirectRoute,
      redirectArguments: widget.redirectArguments,
    );
  }

  Future<void> _handleAuthSuccess(
    Map<String, dynamic> payload, {
    _AuthOrigin origin = _AuthOrigin.emailPassword,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final redirectRoute = widget.redirectRoute?.trim();
    final isModalReauth = widget.onAuthSuccess != null && !widget.embedded;
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
        (user['username'] ?? user['displayName'] ?? '').toString();
    final userId = user['id'];
    try {
      walletAddress = await _ensureWalletProvisioned(walletAddress.toString(),
          desiredUsername: usernameFromUser);
    } catch (e) {
      AppConfig.debugPrint('SignInScreen: wallet provisioning failed: $e');
    }
    var normalizedWalletAddress = (walletAddress ?? '').toString().trim();
    if (expectedWalletAddress.isNotEmpty && normalizedWalletAddress.isEmpty) {
      final signerReady = await _requireSignerForWallet(expectedWalletAddress);
      if (!mounted) return;
      if (!signerReady) {
        await BackendApiService().clearAuth();
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.connectWalletImportFailedToast)),
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
            'SignInScreen: failed to set wallet backup-required state: $e');
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
        warmUp: !isModalReauth,
        loadProfile: !isModalReauth,
      );
      if (!mounted) return;
    }

    if (!isModalReauth) {
      final ok = await const PostAuthSecuritySetupService()
          .ensurePostAuthSecuritySetup(
        navigator: navigator,
        walletProvider: walletProvider,
        securityGateProvider: gate,
      );
      if (!mounted) return;
      if (!ok) return;
    }

    // In modal re-auth flows, avoid running protected API calls here because the
    // auth coordinator may be waiting on this route to pop (deadlock risk).
    // The app refreshes profile/session via SecurityGateProvider after re-auth.
    if (!isModalReauth) {
      try {
        if ((walletAddress == null || walletAddress.toString().isEmpty) &&
            walletProvider.currentWalletAddress != null &&
            walletProvider.currentWalletAddress!.isNotEmpty) {
          await Provider.of<ProfileProvider>(context, listen: false)
              .loadProfile(walletProvider.currentWalletAddress!)
              .timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        AppConfig.debugPrint('SignInScreen: profile load skipped/failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(content: Text(l10n.authSignedInProfileRefreshSoon)),
          );
        }
      }
      if (!mounted) return;
    }

    if (!isModalReauth && origin != _AuthOrigin.google) {
      await maybeShowGooglePasswordUpgradePrompt(context, payload);
      if (!mounted) return;
    }

    if (widget.onAuthSuccess != null) {
      try {
        await widget.onAuthSuccess!(payload);
      } catch (e) {
        AppConfig.debugPrint('SignInScreen: onAuthSuccess callback failed: $e');
      }
      if (!mounted) return;
      if (!widget.embedded) {
        Navigator.of(context).pop(true);
      }
      return;
    }

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

    if (redirectRoute != null && redirectRoute.isNotEmpty) {
      navigator.pushReplacementNamed(
        redirectRoute,
        arguments: widget.redirectArguments,
      );
      return;
    }

    final profile = profileProvider.currentUser;
    final needsProfileSetup = profile != null &&
        (profile.displayName.isEmpty ||
            profile.displayName == profile.username) &&
        (profile.bio).isEmpty;

    if (needsProfileSetup) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ProfileEditScreen(isOnboarding: true),
        ),
      );
      return;
    }

    navigator.pushReplacementNamed('/main');
  }

  Future<String?> _ensureWalletProvisioned(String? existingWallet,
      {String? desiredUsername}) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final targetWallet = (existingWallet ?? '').trim();
    final signerWallet = _signerBackedWalletForGoogleAuth();

    // Keep auth completion snappy and offline-friendly.
    // Wallet + Web3 initialization is best-effort and must never block the UI
    // indefinitely (e.g. on slow RPC / captive portals / flaky mobile data).
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
              'SignInScreen: setReadOnlyWalletIdentity failed: $e');
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
              'SignInScreen: managed reconnect after auth failed: $e');
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
      final result = await walletProvider.createWallet();
      final address = (result['address'] ?? '').trim();
      return address.isEmpty ? null : address;
    } catch (e) {
      AppConfig.debugPrint(
          'SignInScreen: signer-backed wallet creation failed: $e');
      return null;
    }
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
        description: l10n.authRestoreWalletBeforeSignInDescription,
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

  Future<bool> _requireSignerForWallet(String walletAddress) async {
    await _showConnectWalletFlow(
      initialStep: 1,
      requiredWalletAddress: walletAddress,
    );
    if (!mounted) return false;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    return walletProvider.hasSigner &&
        WalletUtils.equals(
          walletProvider.currentWalletAddress,
          walletAddress,
        );
  }

  Future<void> _submitEmail() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableEmailAuth) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authEmailSignInDisabled)));
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 8) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authEnterValidEmailPassword)));
      return;
    }
    unawaited(TelemetryService().trackSignInAttempt(method: 'email'));
    setState(() => _isEmailSubmitting = true);
    try {
      final api = BackendApiService();
      final result = await api.loginWithEmail(email: email, password: password);
      await _handleAuthSuccess(result, origin: _AuthOrigin.emailPassword);
      unawaited(TelemetryService().trackSignInSuccess(method: 'email'));
    } catch (e) {
      unawaited(TelemetryService().trackSignInFailure(
          method: 'email', errorClass: e.runtimeType.toString()));
      if (!mounted) return;
      if (_isEmailPasswordNotConfigured(e)) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(
              l10n.authWalletOnlyAccountSignInHint,
            ),
          ),
          tone: KubusSnackBarTone.error,
        );
        return;
      }
      if (e is BackendApiRequestException && e.statusCode == 403) {
        try {
          final decoded = jsonDecode((e.body ?? '').toString());
          if (decoded is Map && decoded['requiresEmailVerification'] == true) {
            if (widget.embedded) {
              widget.onVerificationRequired?.call(email);
            } else {
              Navigator.of(context).pushReplacementNamed(
                '/verify-email',
                arguments: {'email': email},
              );
            }
            ScaffoldMessenger.of(context).showKubusSnackBar(
              SnackBar(content: Text(l10n.authEmailNotVerifiedToast)),
            );
            return;
          }
        } catch (_) {
          // Fall through to generic error toast.
        }
      }
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authEmailSignInFailed)));
    } finally {
      if (mounted) setState(() => _isEmailSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableGoogleAuth) {
      _setGoogleAuthDiagnostics('disabled', code: 'feature_flag_off');
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authGoogleSignInDisabled)));
      return;
    }

    // Web sign-in is handled by the dedicated web button widget.
    if (kIsWeb) {
      return;
    }
    _setGoogleAuthDiagnostics('native_start');

    unawaited(TelemetryService().trackSignInAttempt(method: 'google'));

    // Honor any server-provided rate-limit cooldown persisted from prior attempts.
    final untilMs = _googleRateLimitUntilMs;
    if (untilMs != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
      if (DateTime.now().isBefore(until)) {
        _setGoogleAuthDiagnostics('blocked', code: 'rate_limited_local');
        final remaining = until.difference(DateTime.now());
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        final friendly = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authGoogleRateLimitedRetryIn(friendly))),
        );
        unawaited(TelemetryService()
            .trackSignInFailure(method: 'google', errorClass: 'rate_limited'));
        return;
      }
    }

    setState(() => _isGoogleSubmitting = true);
    try {
      final googleResult = await GoogleAuthService().signIn();
      if (googleResult == null) {
        _setGoogleAuthDiagnostics('cancelled', code: 'user_cancelled');
        unawaited(TelemetryService()
            .trackSignInFailure(method: 'google', errorClass: 'cancelled'));
        if (!mounted) return;
        setState(() => _isGoogleSubmitting = false);
        return;
      }
      await _completeGoogleSignIn(googleResult);
      _setGoogleAuthDiagnostics('success');
      unawaited(TelemetryService().trackSignInSuccess(method: 'google'));
    } catch (e) {
      _setGoogleAuthDiagnostics('native_error', code: _googleErrorCode(e));
      unawaited(TelemetryService().trackSignInFailure(
          method: 'google', errorClass: e.runtimeType.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authGoogleSignInFailed)));
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  Future<void> _completeGoogleSignIn(GoogleAuthResult googleResult) async {
    final l10n = AppLocalizations.of(context)!;

    // Honor any server-provided rate-limit cooldown persisted from prior attempts.
    final untilMs = _googleRateLimitUntilMs;
    if (untilMs != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
      if (DateTime.now().isBefore(until)) {
        _setGoogleAuthDiagnostics('blocked', code: 'rate_limited_local');
        final remaining = until.difference(DateTime.now());
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        final friendly = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authGoogleRateLimitedRetryIn(friendly))),
        );
        unawaited(TelemetryService()
            .trackSignInFailure(method: 'google', errorClass: 'rate_limited'));
        return;
      }
    }

    if (!_isGoogleSubmitting && mounted) {
      setState(() => _isGoogleSubmitting = true);
    }

    final api = BackendApiService();
    _setGoogleAuthDiagnostics('backend_exchange');
    // For email account merge: pass email but NOT username to avoid overwriting
    // existing account data. Backend preserves existing username/avatar/name
    // for existing users and only uses walletAddress when creating a new user.
    late final Map<String, dynamic> result;
    try {
      result = await loginWithGoogleWalletRecovery(
        api: api,
        googleResult: googleResult,
        walletAddress: _signerBackedWalletForGoogleAuth(),
        createSignerBackedWallet: _createSignerBackedWallet,
      );
    } catch (e) {
      _setGoogleAuthDiagnostics('backend_error', code: _googleErrorCode(e));
      rethrow;
    }

    // Clear any stored cooldown on success.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rate_limit_auth_google_until');
      _googleRateLimitUntilMs = null;
    } catch (_) {}

    if (!mounted) return;
    _setGoogleAuthDiagnostics('profile_hydration');
    await _handleAuthSuccess(result, origin: _AuthOrigin.google);
    _setGoogleAuthDiagnostics('success');
  }

  String? _signerBackedWalletForGoogleAuth() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    return signerBackedGoogleWalletAddress(
      hasSigner: walletProvider.hasSigner,
      currentWalletAddress: walletProvider.currentWalletAddress,
    );
  }

  Future<Map<String, dynamic>?> _resolveAuthPayloadFromCurrentSession() async {
    final api = BackendApiService();

    final profile = await api.getMyProfile();
    final profileData = profile['data'];
    if (profile['success'] == true && profileData is Map<String, dynamic>) {
      return <String, dynamic>{
        'data': <String, dynamic>{'user': profileData},
      };
    }

    final walletAddress = (api.getCurrentAuthWalletAddress() ?? '').trim();
    if (walletAddress.isEmpty) {
      return null;
    }

    return <String, dynamic>{
      'data': <String, dynamic>{
        'user': <String, dynamic>{'walletAddress': walletAddress},
      },
    };
  }

  Future<void> _showConnectWalletFlow({
    int initialStep = 0,
    String? requiredWalletAddress,
  }) async {
    if (_walletFlowOpening) {
      await _walletFlowCompleter?.future;
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableWalletConnect || !AppConfig.enableWeb3) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authWalletConnectionDisabled)));
      return;
    }

    _walletFlowOpening = true;
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final api = BackendApiService();
      final hadAuthBeforeOpen = (api.getAuthToken() ?? '').trim().isNotEmpty;
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

      unawaited(TelemetryService().trackSignInAttempt(method: 'wallet'));
      final routeResult = await completer.future;
      if (!mounted) return;

      if (routeResult is Map<String, dynamic>) {
        await _handleAuthSuccess(routeResult, origin: _AuthOrigin.google);
        return;
      }

      final hasAuthNow = (api.getAuthToken() ?? '').trim().isNotEmpty;
      if (!hasAuthNow || hadAuthBeforeOpen) return;

      final hydratedPayload = await _resolveAuthPayloadFromCurrentSession();
      if (!mounted) return;
      if (hydratedPayload != null) {
        await _handleAuthSuccess(hydratedPayload, origin: _AuthOrigin.google);
      }
    } finally {
      _walletFlowOpening = false;
      _walletFlowCompleter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final accentStart = colorScheme.primary;
    final accentEnd = roles.positiveAction;
    final isDark = theme.brightness == Brightness.dark;
    final enableWallet = AppConfig.enableWeb3 && AppConfig.enableWalletConnect;
    final enableEmail = AppConfig.enableEmailAuth;
    final enableGoogle = AppConfig.enableGoogleAuth;

    final form = _buildAuthForm(
      colorScheme: colorScheme,
      enableWallet: enableWallet,
      enableEmail: enableEmail,
      enableGoogle: enableGoogle,
    );

    if (widget.embedded) {
      return form;
    }

    return AuthEntryShell(
      title: l10n.authSignInTitle,
      subtitle: l10n.authSignInSubtitle,
      heroIcon: Icons.login_rounded,
      gradientStart: accentStart,
      gradientEnd: accentEnd,
      allowMobilePageScroll: false,
      highlights: [
        l10n.authHighlightSignInMethods,
        l10n.authHighlightNoFees,
        l10n.authHighlightControl,
      ],
      topAction: TextButton(
        onPressed: _continueAsGuest,
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
        child: Text(l10n.commonSkip),
      ),
      footer: Center(
        child: TextButton(
          onPressed: _navigateToRegister,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(
              horizontal: KubusSpacing.md,
              vertical: KubusSpacing.xs,
            ),
          ),
          child: Text(l10n.authNeedAccountRegister),
        ),
      ),
      form: form,
    );
  }

  Widget _buildAuthForm({
    required ColorScheme colorScheme,
    required bool enableWallet,
    required bool enableEmail,
    required bool enableGoogle,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showEmailForm = _showCompactEmailForm;
    final viewportSize = MediaQuery.sizeOf(context);
    final keyboardVisible = KeyboardInsetResolver.isKeyboardVisible(context);
    final compactLayout = widget.embedded ||
        keyboardVisible ||
        viewportSize.height < 820 ||
        viewportSize.width < 430;
    final showSectionCopy = !widget.embedded && !compactLayout;
    final methodGap = compactLayout ? KubusSpacing.sm : KubusSpacing.md;
    final emailSurface = Color.lerp(
        colorScheme.surface, colorScheme.primary, isDark ? 0.18 : 0.10)!;
    final walletSurface = Color.lerp(
      colorScheme.surface,
      roles.web3MarketplaceAccent,
      isDark ? 0.24 : 0.14,
    )!;
    final secondarySurface = colorScheme.surface.withValues(
      alpha: isDark ? 0.18 : 0.78,
    );
    final hasSecondaryMethods = enableGoogle || enableEmail;
    final shouldShowSecondaryMethods =
        !showEmailForm && (!enableWallet || _showAlternativeMethods);

    final authMethods = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSectionCopy) ...[
          Text(
            showEmailForm
                ? l10n.authOrLogInWithEmailOrUsername
                : l10n.authHighlightSignInMethods,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            l10n.authSignInSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.66),
                  height: 1.45,
                ),
          ),
          SizedBox(height: compactLayout ? KubusSpacing.md : KubusSpacing.lg),
        ],
        if (!showEmailForm && enableWallet) ...[
          KubusButton(
            onPressed: () => unawaited(_showConnectWalletFlow()),
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.authConnectWalletButton,
            variant: KubusButtonVariant.primary,
            backgroundColor: walletSurface,
            foregroundColor: colorScheme.onSurface,
            isFullWidth: true,
          ),
          if (hasSecondaryMethods) ...[
            SizedBox(height: methodGap),
            _buildMethodDivider(l10n.commonOr),
            SizedBox(height: methodGap),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAlternativeMethods = !_showAlternativeMethods;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurface.withValues(alpha: 0.82),
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.sm,
                  vertical: KubusSpacing.xs,
                ),
              ),
              icon: Icon(
                _showAlternativeMethods
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _showAlternativeMethods
                    ? l10n.authHideOtherOptions
                    : l10n.authShowOtherOptions,
              ),
            ),
            if (_showAlternativeMethods) SizedBox(height: methodGap),
          ],
        ],
        if (shouldShowSecondaryMethods)
          Container(
            decoration: BoxDecoration(
              color: secondarySurface,
              borderRadius: BorderRadius.circular(KubusRadius.lg),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            padding: EdgeInsets.all(
                compactLayout ? KubusSpacing.sm : KubusSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.authOtherOptionsLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SizedBox(height: methodGap),
                if (enableGoogle) ...[
                  if (kIsWeb)
                    GoogleSignInWebButton(
                      colorScheme: colorScheme,
                      isLoading: _isGoogleSubmitting,
                      onAuthResult: (GoogleAuthResult googleResult) async {
                        if (mounted) {
                          setState(() => _isGoogleSubmitting = true);
                        }
                        _setGoogleAuthDiagnostics('web_auth_event');
                        try {
                          unawaited(
                            TelemetryService()
                                .trackSignInAttempt(method: 'google'),
                          );
                          await _completeGoogleSignIn(googleResult);
                          _setGoogleAuthDiagnostics('success');
                          unawaited(
                            TelemetryService()
                                .trackSignInSuccess(method: 'google'),
                          );
                        } catch (error) {
                          _setGoogleAuthDiagnostics(
                            'web_error',
                            code: _googleErrorCode(error),
                          );
                          unawaited(
                            TelemetryService().trackSignInFailure(
                              method: 'google',
                              errorClass: error.runtimeType.toString(),
                            ),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showKubusSnackBar(
                              SnackBar(
                                  content: Text(l10n.authGoogleSignInFailed)),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isGoogleSubmitting = false);
                          }
                        }
                      },
                      onAuthError: (Object error) {
                        _setGoogleAuthDiagnostics(
                          'web_plugin_error',
                          code: _googleErrorCode(error),
                        );
                        unawaited(
                          TelemetryService().trackSignInFailure(
                            method: 'google',
                            errorClass: error.runtimeType.toString(),
                          ),
                        );
                        if (!mounted) return;
                        setState(() => _isGoogleSubmitting = false);
                        ScaffoldMessenger.of(context).showKubusSnackBar(
                          SnackBar(content: Text(l10n.authGoogleSignInFailed)),
                        );
                      },
                    )
                  else
                    GoogleSignInButton(
                      onPressed: _signInWithGoogle,
                      isLoading: _isGoogleSubmitting,
                      colorScheme: colorScheme,
                    ),
                  SizedBox(height: methodGap),
                ],
                if (enableEmail)
                  KubusButton(
                    onPressed: () {
                      setState(() {
                        _showCompactEmailForm = true;
                        _showAlternativeMethods = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _emailFocusNode.requestFocus();
                        }
                      });
                    },
                    icon: Icons.email_outlined,
                    label: l10n.authSignInWithEmail,
                    variant: KubusButtonVariant.secondary,
                    backgroundColor: emailSurface,
                    foregroundColor: colorScheme.onSurface,
                    isFullWidth: true,
                  ),
              ],
            ),
          ),
        if (showEmailForm) ...[
          _buildEmailForm(),
          SizedBox(height: methodGap),
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

    final inlineWallet = ConnectWallet(
      embedded: true,
      authInline: true,
      initialStep: _walletInlineInitialStep,
      telemetryAuthFlow: 'signin',
      requiredWalletAddress: _walletInlineRequiredWalletAddress,
      onRequestClose: () => _completeInlineWalletFlow(),
      onFlowComplete: (result) => _completeInlineWalletFlow(result),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey<String>(
          _showInlineWalletFlow ? 'signin-wallet-inline' : 'signin-auth-forms',
        ),
        child: _showInlineWalletFlow ? inlineWallet : authMethods,
      ),
    );
  }

  Widget _buildEmailForm() {
    final viewportSize = MediaQuery.sizeOf(context);
    final compact = widget.embedded ||
        KeyboardInsetResolver.isKeyboardVisible(context) ||
        viewportSize.height < 820 ||
        viewportSize.width < 430;
    final fieldGap = compact ? KubusSpacing.sm : KubusSpacing.md;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          autofocus: _showCompactEmailForm,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _passwordFocusNode.requestFocus(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: _authInputDecoration(
            context,
            label: AppLocalizations.of(context)!.commonEmail,
            compact: compact,
          ),
        ),
        SizedBox(height: fieldGap),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscureEmailPassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submitEmail(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: _authInputDecoration(
            context,
            label: AppLocalizations.of(context)!.commonPassword,
            compact: compact,
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _obscureEmailPassword = !_obscureEmailPassword);
              },
              icon: Icon(
                _obscureEmailPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              final email = _emailController.text.trim();
              Navigator.of(context).pushNamed(
                '/forgot-password',
                arguments: {'email': email},
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.82),
            ),
            child: Text(AppLocalizations.of(context)!.authForgotPasswordLink),
          ),
        ),
        SizedBox(height: fieldGap),
        KubusButton(
          onPressed: _isEmailSubmitting ? null : _submitEmail,
          isLoading: _isEmailSubmitting,
          icon: _isEmailSubmitting ? null : Icons.login_rounded,
          label: _isEmailSubmitting
              ? AppLocalizations.of(context)!.commonWorking
              : AppLocalizations.of(context)!.authSignInWithEmail,
          isFullWidth: true,
        ),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
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

  InputDecoration _authInputDecoration(
    BuildContext context, {
    required String label,
    bool compact = false,
    Widget? suffixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.12),
      ),
    );
    return InputDecoration(
      labelText: label,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: scheme.surface.withValues(alpha: 0.54),
      hoverColor: scheme.surface.withValues(alpha: 0.62),
      contentPadding: EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: compact ? 14 : 18,
      ),
      enabledBorder: border,
      border: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.56)),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.error.withValues(alpha: 0.56)),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
    );
  }

  void _navigateToRegister() {
    if (widget.onSwitchToRegister != null) {
      widget.onSwitchToRegister!.call();
      return;
    }
    Navigator.of(context).pushNamed('/register');
  }

  void _continueAsGuest() {
    unawaited(TelemetryService().trackSignInAttempt(method: 'guest'));
    unawaited(TelemetryService().trackSignInSuccess(method: 'guest'));
    Navigator.of(context).pushReplacementNamed('/main');
  }
}
