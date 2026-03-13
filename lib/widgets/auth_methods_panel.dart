import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/providers/web3provider.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/screens/web3/wallet/connectwallet_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/google_auth_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/security/post_auth_security_setup_service.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:art_kubus/utils/auth_password_policy.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/auth_entry_shell.dart';
import 'package:art_kubus/widgets/email_registration_form.dart';
import 'package:art_kubus/widgets/google_sign_in_button.dart';
import 'package:art_kubus/widgets/google_sign_in_web_button.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
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
    this.onEmailRegistrationAttempted,
    this.onEmailCredentialsCaptured,
    this.preferredEmailGreetingName,
    this.prepareProvisionalProfileBeforeRegister = false,
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
      AppConfig.debugPrint('AuthMethodsPanel._handleAuthSuccess: ensuring wallet provisioning');
      walletAddress = await _ensureWalletProvisioned(walletAddress?.toString(),
          desiredUsername: usernameFromUser);
    } catch (e) {
      AppConfig.debugPrint('AuthMethodsPanel: wallet provisioning failed: $e');
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
      AppConfig.debugPrint('AuthMethodsPanel: profile load skipped/failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authAccountCreatedProfileLoading)),
        );
      }
    }
    if (!mounted) return;
    if (widget.embedded) {
      AppConfig.debugPrint('AuthMethodsPanel._handleAuthSuccess: embedded flow auth success callback');
      if (widget.onAuthSuccess != null) {
        await widget.onAuthSuccess!();
      }
      return;
    }
    AppConfig.debugPrint('AuthMethodsPanel._handleAuthSuccess: navigating to /main');
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
    const profileDisplayNameMaxLength = 100;
    final rawGreetingName = (widget.preferredEmailGreetingName ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final greetingName = rawGreetingName.isEmpty
        ? null
        : (rawGreetingName.length > profileDisplayNameMaxLength
            ? rawGreetingName.substring(0, profileDisplayNameMaxLength)
            : rawGreetingName);
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
      AppConfig.debugPrint('AuthMethodsPanel._registerWithEmail: start email registration for $email');
      String? provisionalWalletAddress;
      if (widget.prepareProvisionalProfileBeforeRegister) {
        AppConfig.debugPrint('AuthMethodsPanel._registerWithEmail: preparing provisional profile');
        provisionalWalletAddress = await _prepareProvisionalProfileBeforeRegister(
          desiredUsername: username,
        ).timeout(const Duration(seconds: 16));
        AppConfig.debugPrint(
          'AuthMethodsPanel._registerWithEmail: provisional wallet resolved=${(provisionalWalletAddress ?? '').isNotEmpty}',
        );
      }
      final api = BackendApiService();
      await api
          .registerWithEmail(
        email: email,
        password: password,
        username: username.isNotEmpty ? username : null,
        displayName: greetingName,
        walletAddress: provisionalWalletAddress,
      )
          .timeout(const Duration(seconds: 16));
      AppConfig.debugPrint('AuthMethodsPanel._registerWithEmail: registerWithEmail completed');
      widget.onEmailRegistrationAttempted?.call(email);
      if (widget.onEmailCredentialsCaptured != null) {
        await widget.onEmailCredentialsCaptured!(email, password);
      }
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
      AppConfig.debugPrint('AuthMethodsPanel._registerWithEmail: success path complete');
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
      AppConfig.debugPrint('AuthMethodsPanel._registerWithEmail: clearing submit loading state');
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String?> _ensureWalletProvisioned(String? existingWallet,
      {String? desiredUsername}) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final sanitizedExisting = existingWallet?.trim();
    String? address = sanitizedExisting;
    address ??= walletProvider.currentWalletAddress;
    bool createdFreshWallet = false;

    // Keep registration completion offline-friendly.
    // Web3 sync can be slow on mobile networks; never block UI indefinitely.
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
          AppConfig.debugPrint('AuthMethodsPanel: connectWalletWithAddress failed: $e');
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
              AppConfig.debugPrint(
                  'AuthMethodsPanel: connectExistingWallet skipped/failed: $e');
            }
          }());
        }
      } catch (e) {
        AppConfig.debugPrint('AuthMethodsPanel: connectExistingWallet failed: $e');
      }
      return address;
    }

    try {
      final result = await walletProvider
          .createWallet()
          .timeout(const Duration(seconds: 12));
      final mnemonic = result['mnemonic']!;
      address = result['address']!;
      createdFreshWallet = true;
      try {
        await web3Provider.importWallet(mnemonic).timeout(web3ConnectTimeout);
      } catch (e) {
        AppConfig.debugPrint('AuthMethodsPanel: web3 import failed: $e');
      }
      try {
        if (AppConfig.enableDebugIssueToken) {
          await BackendApiService().issueTokenForWallet(address);
        }
      } catch (e) {
        AppConfig.debugPrint('AuthMethodsPanel: issueTokenForWallet failed: $e');
      }
    } catch (e) {
      AppConfig.debugPrint('AuthMethodsPanel: wallet creation failed: $e');
    }

    if (address != null && address.isNotEmpty && createdFreshWallet) {
      await _upsertProfileWithUsername(address, desiredUsername);
    }

    return address;
  }

  Future<String?> _prepareProvisionalProfileBeforeRegister({
    required String desiredUsername,
  }) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    String? walletAddress;
    try {
      walletAddress = await _ensureWalletProvisioned(
        null,
        desiredUsername: null,
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
      AppConfig.debugPrint('AuthMethodsPanel: createProfileFromWallet failed: $e');
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
      icon: Icon(icon, color: colorScheme.onSurface, size: 22),
      label: Text(label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
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
    final showEmailForm = _showCompactEmailForm;
    final compactLayout =
        widget.embedded || MediaQuery.sizeOf(context).height < 820;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          showEmailForm ? l10n.authOrUseEmail : l10n.authRegisterSubtitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
          maxLines: compactLayout ? 2 : null,
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
          maxLines: compactLayout ? 2 : null,
        ),
        SizedBox(height: compactLayout ? KubusSpacing.md : KubusSpacing.lg),
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
          AuthSecondaryActionButton(
            onPressed: () {
              setState(() => _showCompactEmailForm = true);
            },
            icon: Icons.email_outlined,
            label: l10n.authContinueWithEmail,
          ),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
        ],
        if (!showEmailForm && enableWallet) ...[
          _buildMethodDivider(l10n.authHighlightOptionalWeb3),
          SizedBox(height: compactLayout ? KubusSpacing.xs : KubusSpacing.sm),
          KubusButton(
            onPressed: _showConnectWalletModal,
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.authConnectWalletButton,
            isFullWidth: true,
          ),
        ],
        if (showEmailForm) ...[
          _buildEmailForm(compact: widget.embedded),
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
      emailError: _emailError,
      passwordError: _passwordError,
      confirmPasswordError: _confirmPasswordError,
      onSubmit: _registerWithEmail,
      isSubmitting: _isSubmitting,
      compact: compact,
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
