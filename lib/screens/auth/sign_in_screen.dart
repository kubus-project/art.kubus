import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/config.dart';
import '../../providers/profile_provider.dart';
import '../../providers/security_gate_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/web3provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/onboarding_state_service.dart';
import '../../services/security/post_auth_security_setup_service.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/google_sign_in_web_button.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/auth_entry_shell.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../web3/wallet/connectwallet_screen.dart';
import '../desktop/desktop_shell.dart';
import '../community/profile_edit_screen.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.redirectRoute,
    this.redirectArguments,
    this.initialEmail,
    this.onAuthSuccess,
    this.embedded = false,
    this.onVerificationRequired,
    this.onSwitchToRegister,
  });

  final String? redirectRoute;
  final Object? redirectArguments;
  final String? initialEmail;
  final FutureOr<void> Function(Map<String, dynamic> payload)? onAuthSuccess;
  final bool embedded;
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
  int? _googleRateLimitUntilMs;
  String _googleAuthDiagStage = 'idle';
  String? _googleAuthDiagCode;
  bool _showCompactEmailForm = false;

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
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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

  Future<void> _handleAuthSuccess(Map<String, dynamic> payload) async {
    final l10n = AppLocalizations.of(context)!;
    final redirectRoute = widget.redirectRoute?.trim();
    final isModalReauth = widget.onAuthSuccess != null && !widget.embedded;
    final navigator = Navigator.of(context);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final gate = Provider.of<SecurityGateProvider>(context, listen: false);
    final data = (payload['data'] as Map<String, dynamic>?) ?? payload;
    final user = (data['user'] as Map<String, dynamic>?) ?? data;
    String? walletAddress = user['walletAddress'] ?? user['wallet_address'];
    final usernameFromUser =
        (user['username'] ?? user['displayName'] ?? '').toString();
    final userId = user['id'];
    try {
      walletAddress = await _ensureWalletProvisioned(walletAddress?.toString(),
          desiredUsername: usernameFromUser);
    } catch (e) {
      AppConfig.debugPrint('SignInScreen: wallet provisioning failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!widget.embedded) {
      await OnboardingStateService.markCompleted(prefs: prefs);
    }
    if (walletAddress != null && walletAddress.toString().isNotEmpty) {
      await prefs.setString('wallet_address', walletAddress.toString());
      await prefs.setString('wallet', walletAddress.toString());
      await prefs.setString('walletAddress', walletAddress.toString());
      await prefs.setBool('has_wallet', true);
    }
    if (userId != null && userId.toString().isNotEmpty) {
      await prefs.setString('user_id', userId.toString());
      TelemetryService().setActorUserId(userId.toString());
    }
    if (!mounted) return;

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
        if (walletAddress != null && walletAddress.toString().isNotEmpty) {
          await Provider.of<ProfileProvider>(context, listen: false)
              .loadProfile(walletAddress.toString())
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

    if (redirectRoute != null && redirectRoute.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed(
        redirectRoute,
        arguments: widget.redirectArguments,
      );
      return;
    }

    // Check if user needs profile onboarding (new users from email registration)
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final profile = profileProvider.currentUser;
    final needsProfileSetup = profile != null &&
        (profile.displayName.isEmpty ||
            profile.displayName == profile.username) &&
        (profile.bio).isEmpty;

    if (needsProfileSetup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ProfileEditScreen(isOnboarding: true),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed('/main');
  }

  Future<String?> _ensureWalletProvisioned(String? existingWallet,
      {String? desiredUsername}) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final sanitizedExisting = existingWallet?.trim();
    String? address = sanitizedExisting;
    address ??= walletProvider.currentWalletAddress;
    bool createdFreshWallet = false;

    // Keep auth completion snappy and offline-friendly.
    // Wallet + Web3 initialization is best-effort and must never block the UI
    // indefinitely (e.g. on slow RPC / captive portals / flaky mobile data).
    const walletConnectTimeout = Duration(seconds: 6);
    const web3ConnectTimeout = Duration(seconds: 10);

    if (address != null && address.isNotEmpty) {
      final currentWallet = (walletProvider.currentWalletAddress ?? '').trim();
      if (currentWallet.isEmpty || currentWallet != address) {
        try {
          await walletProvider
              .connectWalletWithAddress(address)
              .timeout(walletConnectTimeout);
        } catch (e) {
          AppConfig.debugPrint(
              'SignInScreen: connectWalletWithAddress failed: $e');
        }
      }
      try {
        if (!web3Provider.isConnected ||
            web3Provider.walletAddress != address) {
          // Do not block sign-in on Web3 initialization; it can be retried later.
          unawaited(() async {
            try {
              await web3Provider
                  .connectExistingWallet(address!)
                  .timeout(web3ConnectTimeout);
            } catch (e) {
              AppConfig.debugPrint(
                  'SignInScreen: connectExistingWallet skipped/failed: $e');
            }
          }());
        }
      } catch (e) {
        AppConfig.debugPrint('SignInScreen: connectExistingWallet failed: $e');
      }
      return address;
    }

    try {
      final result = await walletProvider.createWallet();
      final mnemonic = result['mnemonic']!;
      address = result['address']!;
      createdFreshWallet = true;
      try {
        // Importing may trigger RPC/network sync; keep it bounded.
        await web3Provider.importWallet(mnemonic).timeout(web3ConnectTimeout);
      } catch (e) {
        AppConfig.debugPrint('SignInScreen: web3 import failed: $e');
      }
      try {
        if (AppConfig.enableDebugIssueToken) {
          await BackendApiService().issueTokenForWallet(address);
        }
      } catch (e) {
        AppConfig.debugPrint('SignInScreen: issueTokenForWallet failed: $e');
      }
    } catch (e) {
      AppConfig.debugPrint('SignInScreen: wallet creation failed: $e');
    }

    if (address != null && address.isNotEmpty && createdFreshWallet) {
      await _upsertProfileWithUsername(address, desiredUsername);
    }

    return address;
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
      AppConfig.debugPrint('SignInScreen: createProfileFromWallet failed: $e');
    }
    if (effectiveUsername != null && effectiveUsername.isNotEmpty) {
      try {
        await BackendApiService().updateProfile(address, {
          'username': effectiveUsername,
          'displayName': effectiveUsername,
        });
      } catch (err) {
        AppConfig.debugPrint(
            'SignInScreen: updateProfile username patch failed: $err');
      }
    }
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
      await _handleAuthSuccess(result);
      unawaited(TelemetryService().trackSignInSuccess(method: 'email'));
    } catch (e) {
      unawaited(TelemetryService().trackSignInFailure(
          method: 'email', errorClass: e.runtimeType.toString()));
      if (!mounted) return;
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
    // existing account data. Backend preserves existing username/avatar/name.
    Map<String, dynamic> result;
    try {
      result = await api.loginWithGoogle(
        idToken: googleResult.idToken,
        code: googleResult.serverAuthCode,
        email: googleResult.email,
        username: null,
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
    await _handleAuthSuccess(result);
    _setGoogleAuthDiagnostics('success');
  }

  void _showConnectWalletModal() {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableWalletConnect || !AppConfig.enableWeb3) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authWalletConnectionDisabled)));
      return;
    }

    unawaited(TelemetryService().trackSignInAttempt(method: 'wallet'));
    final isDesktop =
        MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;
    if (isDesktop) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const ConnectWallet(initialStep: 0, telemetryAuthFlow: 'signin'),
          settings: const RouteSettings(name: '/connect-wallet'),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final sheetL10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(sheetL10n.authConnectWalletModalTitle,
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface)),
                const SizedBox(height: 12),
                Text(sheetL10n.authConnectWalletModalDescriptionSignIn,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 24),
                const SizedBox(height: 16),
                _walletOptionButton(
                    ctx,
                    sheetL10n.authWalletOptionWalletConnect,
                    Icons.qr_code_2_outlined, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ConnectWallet(
                          initialStep: 3, telemetryAuthFlow: 'signin'),
                      settings: const RouteSettings(
                          name: '/connect-wallet/walletconnect'),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                _walletOptionButton(ctx, sheetL10n.authWalletOptionOtherWallets,
                    Icons.apps_outlined, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ConnectWallet(
                          initialStep: 0, telemetryAuthFlow: 'signin'),
                      settings: const RouteSettings(name: '/connect-wallet'),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _walletOptionButton(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return KubusButton(
      onPressed: onTap,
      icon: icon,
      label: label,
      variant: KubusButtonVariant.secondary,
      foregroundColor: colorScheme.onSurface,
      isFullWidth: true,
    );
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
    final compactLayout =
        widget.embedded || MediaQuery.sizeOf(context).height < 820;
    final showSectionCopy = !widget.embedded && !compactLayout;
    final emailSurface =
        Color.lerp(colorScheme.surface, colorScheme.primary, isDark ? 0.18 : 0.10)!;
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
            onPressed: _showConnectWalletModal,
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.authConnectWalletButton,
            variant: KubusButtonVariant.secondary,
            backgroundColor: walletSurface,
            foregroundColor: colorScheme.onSurface,
            isFullWidth: true,
          ),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
        ],
        if (!showEmailForm && enableGoogle) ...[
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
                    TelemetryService().trackSignInAttempt(method: 'google'),
                  );
                  await _completeGoogleSignIn(googleResult);
                  _setGoogleAuthDiagnostics('success');
                  unawaited(
                    TelemetryService().trackSignInSuccess(method: 'google'),
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
                      SnackBar(content: Text(l10n.authGoogleSignInFailed)),
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
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
        ],
        if (!showEmailForm && enableEmail) ...[
          if (showSectionCopy)
            _buildMethodDivider(l10n.authOrLogInWithEmailOrUsername),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
          KubusButton(
            onPressed: () {
              setState(() => _showCompactEmailForm = true);
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
        if (showEmailForm) ...[
          _buildEmailForm(),
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

  Widget _buildEmailForm() {
    final compact =
        widget.embedded || MediaQuery.sizeOf(context).height < 820;
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
        SizedBox(height: compact ? KubusSpacing.xs : KubusSpacing.sm),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submitEmail(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: _authInputDecoration(
            context,
            label: AppLocalizations.of(context)!.commonPassword,
            compact: compact,
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
              foregroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.82),
            ),
            child: Text(AppLocalizations.of(context)!.authForgotPasswordLink),
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
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

  InputDecoration _authInputDecoration(
    BuildContext context, {
    required String label,
    bool compact = false,
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
      filled: true,
      fillColor: scheme.surface.withValues(alpha: 0.54),
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
