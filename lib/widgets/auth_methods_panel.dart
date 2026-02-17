import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/auth/desktop_auth_shell.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/google_auth_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/security/post_auth_security_setup_service.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:art_kubus/utils/auth_password_policy.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/auth_title_row.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/google_sign_in_button.dart';
import 'package:art_kubus/widgets/google_sign_in_web_button.dart';
import 'package:art_kubus/widgets/gradient_icon_card.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthMethodsPanel extends StatefulWidget {
  const AuthMethodsPanel({
    super.key,
    this.embedded = false,
    this.onAuthSuccess,
    this.onVerificationRequired,
    this.onError,
    this.onSwitchToSignIn,
  });

  final bool embedded;
  final Future<void> Function()? onAuthSuccess;
  final ValueChanged<String>? onVerificationRequired;
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
  bool _didAttemptGoogleAutoSignIn = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _showCompactEmailForm = false;

  @override
  void initState() {
    super.initState();
    // Best-effort "automatic" sign-in on mobile (silent re-auth for returning users).
    // Note: One Tap is web-only (GIS iframe) and cannot be replicated on native.
    if (!widget.embedded && !kIsWeb && AppConfig.enableGoogleAuth) {
      unawaited(_attemptGoogleAutoSignIn());
    }
  }

  Future<void> _attemptGoogleAutoSignIn() async {
    if (_didAttemptGoogleAutoSignIn) return;
    _didAttemptGoogleAutoSignIn = true;
    if (_isGoogleSubmitting) return;

    try {
      await GoogleAuthService().ensureInitialized();
      final account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (!mounted) return;
      if (account == null) return;

      if (mounted) {
        setState(() => _isGoogleSubmitting = true);
      }

      final googleResult = GoogleAuthService().resultFromAccount(account);
      final api = BackendApiService();
      final result = await api.loginWithGoogle(
        idToken: googleResult.idToken,
        code: googleResult.serverAuthCode,
        email: googleResult.email,
        username: null,
      );
      if (!mounted) return;
      await _handleAuthSuccess(result);
    } catch (_) {
      // Best-effort only.
    } finally {
      if (mounted) {
        setState(() => _isGoogleSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> payload) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final gate = Provider.of<SecurityGateProvider>(context, listen: false);
    final data = (payload['data'] as Map<String, dynamic>?) ?? payload;
    final user = (data['user'] as Map<String, dynamic>?) ?? data;
    String? walletAddress = user['walletAddress'] ?? user['wallet_address'];
    final usernameFromUser =
        (user['username'] ?? _usernameController.text ?? '').toString();
    final userId = user['id'];
    try {
      walletAddress = await _ensureWalletProvisioned(walletAddress?.toString(),
          desiredUsername: usernameFromUser);
    } catch (e) {
      debugPrint('AuthMethodsPanel: wallet provisioning failed: $e');
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

    final ok =
        await const PostAuthSecuritySetupService().ensurePostAuthSecuritySetup(
      navigator: navigator,
      walletProvider: walletProvider,
      securityGateProvider: gate,
    );
    if (!mounted) return;
    if (!ok) return;

    try {
      if (walletAddress != null && walletAddress.toString().isNotEmpty) {
        await Provider.of<ProfileProvider>(context, listen: false)
            .loadProfile(walletAddress.toString())
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('AuthMethodsPanel: profile load skipped/failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authAccountCreatedProfileLoading)),
        );
      }
    }
    if (!mounted) return;
    if (widget.embedded) {
      if (widget.onAuthSuccess != null) {
        await widget.onAuthSuccess!();
      }
      return;
    }
    Navigator.of(context).pushReplacementNamed('/main');
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
    final emailLooksValid = email.contains('@') && email.contains('.');
    final passwordOk = AuthPasswordPolicy.isValid(password);
    final confirmOk = password == confirm;

    setState(() {
      _emailError = emailLooksValid ? null : l10n.authEnterValidEmailInline;
      _passwordError = passwordOk ? null : l10n.authPasswordPolicyError;
      _confirmPasswordError =
          confirmOk ? null : l10n.authPasswordMismatchInline;
    });
    if (!emailLooksValid || !passwordOk || !confirmOk) return;

    unawaited(TelemetryService().trackSignUpAttempt(method: 'email'));
    setState(() => _isSubmitting = true);
    try {
      final api = BackendApiService();
      await api.registerWithEmail(
        email: email,
        password: password,
        username: username.isNotEmpty ? username : null,
      );
      if (!mounted) return;
      if (widget.embedded) {
        // Keep verification as a final onboarding step, but try to establish a
        // session immediately so the user is not prompted to log in again.
        widget.onVerificationRequired?.call(email);
        try {
          final loginResult =
              await api.loginWithEmail(email: email, password: password);
          if (!mounted) return;
          await _handleAuthSuccess(loginResult);
        } catch (_) {
          // Best-effort only: some backends require verification before email login.
          // In that case we keep the user in-flow and finish verification later.
        }
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
      // Note: email registration no longer creates a session until verification.
      // Avoid writing local account/session state here.
    } catch (e) {
      widget.onError?.call(e);
      unawaited(TelemetryService().trackSignUpFailure(
          method: 'email', errorClass: e.runtimeType.toString()));
      if (!mounted) return;
      if (e is BackendApiRequestException && e.statusCode == 409) {
        if (widget.embedded) {
          // Existing account: try signing in with provided credentials first to
          // keep onboarding frictionless. If this fails, fall back to sign-in UI.
          try {
            final api = BackendApiService();
            final loginResult =
                await api.loginWithEmail(email: email, password: password);
            if (!mounted) return;
            await _handleAuthSuccess(loginResult);
            return;
          } catch (_) {
            widget.onSwitchToSignIn?.call();
          }
        } else {
          navigator.pushReplacementNamed(
            '/sign-in',
            arguments: {'email': email},
          );
        }
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.authAccountAlreadyExistsToast)),
        );
      } else {
        messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.authRegistrationFailed)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String?> _ensureWalletProvisioned(String? existingWallet,
      {String? desiredUsername}) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final sanitizedExisting = existingWallet?.trim();
    String? address = walletProvider.currentWalletAddress;
    bool createdFreshWallet = false;

    // Keep registration completion offline-friendly.
    // Web3 sync can be slow on mobile networks; never block UI indefinitely.
    const walletConnectTimeout = Duration(seconds: 6);
    const web3ConnectTimeout = Duration(seconds: 10);

    if (address == null || address.isEmpty) {
      if (sanitizedExisting != null && sanitizedExisting.isNotEmpty) {
        address = sanitizedExisting;
      }
    }

    if (address != null && address.isNotEmpty) {
      if ((walletProvider.currentWalletAddress ?? '').isEmpty) {
        try {
          await walletProvider
              .connectWalletWithAddress(address)
              .timeout(walletConnectTimeout);
        } catch (e) {
          debugPrint('AuthMethodsPanel: connectWalletWithAddress failed: $e');
        }
      }
      try {
        if (!web3Provider.isConnected ||
            web3Provider.walletAddress != address) {
          unawaited(() async {
            try {
              await web3Provider
                  .connectExistingWallet(address!)
                  .timeout(web3ConnectTimeout);
            } catch (e) {
              debugPrint(
                  'AuthMethodsPanel: connectExistingWallet skipped/failed: $e');
            }
          }());
        }
      } catch (e) {
        debugPrint('AuthMethodsPanel: connectExistingWallet failed: $e');
      }
      return address;
    }

    try {
      final result = await walletProvider.createWallet();
      final mnemonic = result['mnemonic']!;
      address = result['address']!;
      createdFreshWallet = true;
      try {
        await web3Provider.importWallet(mnemonic).timeout(web3ConnectTimeout);
      } catch (e) {
        debugPrint('AuthMethodsPanel: web3 import failed: $e');
      }
      try {
        if (AppConfig.enableDebugIssueToken) {
          await BackendApiService().issueTokenForWallet(address);
        }
      } catch (e) {
        debugPrint('AuthMethodsPanel: issueTokenForWallet failed: $e');
      }
    } catch (e) {
      debugPrint('AuthMethodsPanel: wallet creation failed: $e');
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
      debugPrint('AuthMethodsPanel: createProfileFromWallet failed: $e');
    }
    if (effectiveUsername != null && effectiveUsername.isNotEmpty) {
      try {
        await BackendApiService().updateProfile(address, {
          'username': effectiveUsername,
          'displayName': effectiveUsername,
        });
      } catch (err) {
        debugPrint(
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

    // Web uses a GIS-rendered button which triggers auth events instead of an
    // imperative signIn call.
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
      // For account merge: only pass email, let backend decide on username/profile preservation
      final result = await api.loginWithGoogle(
        idToken: googleResult.idToken,
        code: googleResult.serverAuthCode,
        email: googleResult.email,
        // Don't pass username to let backend preserve existing account data if email matches
        username: null,
      );
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
    await Navigator.of(context).push(
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
      if (widget.embedded) {
        if (widget.onAuthSuccess != null) {
          await widget.onAuthSuccess!();
        }
      } else {
        Navigator.of(context).pushReplacementNamed('/main');
      }
    }
  }

  Future<void> _showConnectWalletModal() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableWalletConnect || !AppConfig.enableWeb3) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authWalletConnectionDisabled)));
      return;
    }
    unawaited(TelemetryService().trackSignUpAttempt(method: 'wallet'));
    final isDesktop =
        MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;
    if (isDesktop) {
      await _openConnectWalletRoute(
        initialStep: 0,
        routeName: '/connect-wallet',
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
                const SizedBox(height: 6),
                Text(sheetL10n.authConnectWalletModalDescriptionRegister,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 16),
                const SizedBox(height: 8),
                _walletOptionButton(
                    ctx,
                    sheetL10n.authWalletOptionWalletConnect,
                    Icons.qr_code_2_outlined, () {
                  Navigator.of(ctx).pop();
                  unawaited(_openConnectWalletRoute(
                    initialStep: 3,
                    routeName: '/connect-wallet/walletconnect',
                  ));
                }),
                const SizedBox(height: 8),
                _walletOptionButton(ctx, sheetL10n.authWalletOptionOtherWallets,
                    Icons.apps_outlined, () {
                  Navigator.of(ctx).pop();
                  unawaited(_openConnectWalletRoute(
                    initialStep: 0,
                    routeName: '/connect-wallet',
                  ));
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
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      onPressed: onTap,
      icon: Icon(icon, color: colorScheme.primary, size: 22),
      label: Text(label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final accentStart = roles.lockedFeature;
    final accentEnd = roles.likeAction;
    final enableWallet = AppConfig.enableWeb3 && AppConfig.enableWalletConnect;
    final enableEmail = AppConfig.enableEmailAuth;
    final enableGoogle = AppConfig.enableGoogleAuth;
    final isDesktop =
        MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;

    final bgStart = accentStart.withValues(alpha: 0.55);
    final bgEnd = accentEnd.withValues(alpha: 0.50);
    final bgMid =
        (Color.lerp(bgStart, bgEnd, 0.55) ?? bgEnd).withValues(alpha: 0.52);
    final bgColors = <Color>[bgStart, bgMid, bgEnd, bgStart];

    final form = _buildRegisterForm(
      colorScheme: colorScheme,
      enableWallet: enableWallet,
      enableEmail: enableEmail,
      enableGoogle: enableGoogle,
      isDesktop: isDesktop,
      compact: widget.embedded,
    );

    if (widget.embedded) {
      return form;
    }

    if (isDesktop) {
      return DesktopAuthShell(
        title: l10n.authRegisterTitle,
        subtitle: l10n.authRegisterSubtitle,
        highlights: [
          l10n.authHighlightOnboardingOptions,
          l10n.authHighlightKeysLocal,
          l10n.authHighlightOptionalWeb3,
        ],
        icon: GradientIconCard(
          start: accentStart,
          end: accentEnd,
          icon: Icons.person_add_alt_rounded,
          iconSize: 48,
          width: 96,
          height: 96,
          radius: 18,
        ),
        gradientStart: accentStart,
        gradientEnd: accentEnd,
        form: form,
        footer: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _navigateToSignIn,
            child: Text(
              l10n.authHaveAccountSignIn,
              style: GoogleFonts.inter(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const AppLogo(width: 36, height: 36),
        actions: [
          TextButton(
            onPressed: _navigateToSignIn,
            child: Text(
              l10n.authHaveAccountSignIn,
              style: GoogleFonts.inter(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedGradientBackground(
            duration: const Duration(seconds: 10),
            intensity: 0.2,
            colors: bgColors,
            child: const SizedBox.expand(),
          ),
          SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(
                      bottom: keyboardInset > 140 ? 140 : keyboardInset,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Column(
                        children: [
                          const SizedBox(height: kToolbarHeight + 12),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: 520,
                                  maxHeight:
                                      constraints.maxHeight - kToolbarHeight,
                                ),
                                child: form,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm({
    required ColorScheme colorScheme,
    required bool enableWallet,
    required bool enableEmail,
    required bool enableGoogle,
    required bool isDesktop,
    bool compact = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final compactEmailOpen = compact && _showCompactEmailForm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isDesktop && !compact)
          AuthTitleRow(
            title: l10n.authRegisterTitle,
            icon: Icons.person_add_alt_rounded,
          ),
        if (!isDesktop && !compact) const SizedBox(height: 20),
        if (enableWallet && !compactEmailOpen)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: Size.fromHeight(compact ? 44 : 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            onPressed: _showConnectWalletModal,
            icon: Icon(Icons.account_balance_wallet_outlined,
                size: 24, color: colorScheme.onPrimary),
            label: Text(l10n.authConnectWalletButton,
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimary)),
          ),
        if (enableWallet && !compactEmailOpen)
          SizedBox(height: compact ? 8 : 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(l10n.authOrUseEmail,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface)),
              SizedBox(height: compact ? 8 : 12),
              if (enableEmail)
                if (compact && !_showCompactEmailForm)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _showCompactEmailForm = true);
                      },
                      icon: const Icon(Icons.email_outlined),
                      label: Text(l10n.authContinueWithEmail),
                    ),
                  )
                else
                  _buildEmailForm(colorScheme, compact: compact),
              if (enableGoogle && !compactEmailOpen) ...[
                SizedBox(height: compact ? 8 : 12),
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
                        );
                        if (!mounted) return;
                        await _handleAuthSuccess(result);
                        unawaited(
                          TelemetryService()
                              .trackSignUpSuccess(method: 'google'),
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
              ],
              if (compact && _showCompactEmailForm) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() => _showCompactEmailForm = false);
                    },
                    child: Text(l10n.commonBack),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(ColorScheme colorScheme, {bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.commonEmail,
            border: const OutlineInputBorder(),
            errorText: _emailError,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.commonPassword,
            border: const OutlineInputBorder(),
            errorText: _passwordError,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.commonConfirmPassword,
            border: const OutlineInputBorder(),
            errorText: _confirmPasswordError,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.commonUsernameOptional,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        SizedBox(height: compact ? 8 : 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: EdgeInsets.symmetric(
                vertical: compact ? 12 : 16, horizontal: compact ? 10 : 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            minimumSize: Size.fromHeight(compact ? 46 : 54),
          ),
          onPressed: _isSubmitting ? null : _registerWithEmail,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: InlineLoading(width: 20, height: 20, tileSize: 5))
              : Icon(Icons.person_add_alt,
                  color: colorScheme.onPrimary, size: 22),
          label: Text(
            _isSubmitting
                ? AppLocalizations.of(context)!.commonWorking
                : AppLocalizations.of(context)!.authContinueWithEmail,
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
