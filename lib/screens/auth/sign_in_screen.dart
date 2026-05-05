import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/config.dart';
import '../../services/auth_redirect_controller.dart';
import '../../providers/wallet_provider.dart';
import '../../services/auth_success_handoff_service.dart';
import '../../services/backend_api_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/google_sign_in_web_button.dart';
import '../../widgets/secure_account_password_prompt.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/auth_entry_shell.dart';
import '../../widgets/auth/post_auth_loading_screen.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/auth_google_wallet.dart';
import '../../utils/keyboard_inset_resolver.dart';
import '../../utils/auth_wallet_result_normalizer.dart';
import '../web3/wallet/connectwallet_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

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

  // Post-auth state - shows loading screen instead of auth form
  bool _postAuthActive = false;
  Map<String, dynamic>? _postAuthPayload;
  AuthOrigin? _postAuthOrigin;
  String? _postAuthWalletAddress;
  Object? _postAuthUserId;

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

  void _returnToAuthOptionsAfterWalletEnd() {
    if (!mounted || _postAuthActive) return;
    setState(() {
      _showInlineWalletFlow = false;
      _walletFlowOpening = false;
      _walletInlineInitialStep = 0;
      _walletInlineRequiredWalletAddress = null;
    });
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
      _showInlineWalletFlow = false;
      _walletFlowOpening = false;
      _walletInlineInitialStep = 0;
      _walletInlineRequiredWalletAddress = null;
    });

    // For non-embedded flows, push PostAuthLoadingScreen route
    if (!widget.embedded) {
      await const AuthSuccessHandoffService().handle(
        navigator: navigator,
        isMounted: () => mounted,
        screenWidth: screenWidth,
        payload: payload,
        origin: origin,
        redirectRoute: widget.redirectRoute,
        redirectArguments: widget.redirectArguments,
        walletAddress: normalizedWalletAddress,
        userId: userId,
        embedded: widget.embedded,
        modalReauth: false,
        requiresWalletBackup: false,
        onBeforeSavedItemsSync:
            (origin == AuthOrigin.google || origin == AuthOrigin.wallet)
                ? null
                : () => maybeShowGooglePasswordUpgradePrompt(context, payload),
        onAuthSuccess: widget.onAuthSuccess == null
            ? null
            : (payload) async {
                try {
                  await widget.onAuthSuccess!(payload);
                } catch (e) {
                  AppConfig.debugPrint(
                    'SignInScreen: onAuthSuccess callback failed: $e',
                  );
                }
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

  Future<void> _handleWalletFlowResult(
    Object? routeResult, {
    BackendApiService? apiOverride,
    String? fallbackWalletAddress,
    bool hadAuthBeforeOpen = false,
  }) async {
    final apiForNormalize = apiOverride ?? BackendApiService();
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final normalized = await normalizeWalletAuthResult(
      routeResult: routeResult,
      api: apiForNormalize,
      fallbackWalletAddress: fallbackWalletAddress ??
          _walletInlineRequiredWalletAddress ??
          walletProvider.currentWalletAddress,
      hadAuthBeforeOpen: hadAuthBeforeOpen,
    );

    if (!mounted) return;

    if (normalized.isSuccess) {
      await _handleAuthSuccess(
        normalized.payload!,
        origin: AuthOrigin.wallet,
      );
      unawaited(TelemetryService().trackSignInSuccess(method: 'wallet'));
      return;
    }

    if (normalized.isFailure) {
      _returnToAuthOptionsAfterWalletEnd();
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.authWalletSignInFailed)),
        tone: KubusSnackBarTone.error,
      );
      unawaited(TelemetryService().trackSignInFailure(
        method: 'wallet',
        errorClass: normalized.reason ?? 'wallet_failed',
      ));
      return;
    }

    _returnToAuthOptionsAfterWalletEnd();
    unawaited(TelemetryService().trackSignInFailure(
      method: 'wallet',
      errorClass: 'wallet_cancelled',
    ));
  }

  @visibleForTesting
  Future<void> debugHandleWalletFlowResult(
    Object? routeResult, {
    BackendApiService? apiOverride,
    String? fallbackWalletAddress,
    bool hadAuthBeforeOpen = false,
  }) {
    return _handleWalletFlowResult(
      routeResult,
      apiOverride: apiOverride,
      fallbackWalletAddress: fallbackWalletAddress,
      hadAuthBeforeOpen: hadAuthBeforeOpen,
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
      await _handleAuthSuccess(result, origin: AuthOrigin.emailPassword);
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

  Future<String?> _createSignerBackedWallet() async {
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
    await _handleAuthSuccess(result, origin: AuthOrigin.google);
    _setGoogleAuthDiagnostics('success');
  }

  String? _signerBackedWalletForGoogleAuth() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    return signerBackedGoogleWalletAddress(
      hasSigner: walletProvider.hasSigner,
      currentWalletAddress: walletProvider.currentWalletAddress,
    );
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

      if (kDebugMode) {
        AppConfig.debugPrint(
          'SignInScreen.wallet: flow completed with result type=${routeResult.runtimeType}',
        );
      }

      await _handleWalletFlowResult(
        routeResult,
        fallbackWalletAddress: requiredWalletAddress,
        hadAuthBeforeOpen: hadAuthBeforeOpen,
      );
    } finally {
      // Do not restore wallet UI state if post-auth is active
      if (!_postAuthActive && mounted && _walletFlowOpening) {
        setState(() {
          _walletFlowOpening = false;
        });
      }
      _walletFlowCompleter = null;
    }
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
            : (payload) async {
                try {
                  await widget.onAuthSuccess!(payload);
                } catch (e) {
                  AppConfig.debugPrint(
                    'SignInScreen: onAuthSuccess callback failed: $e',
                  );
                }
              },
      );
    }

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
