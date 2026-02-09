import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/config.dart';
import '../../providers/profile_provider.dart';
import '../../providers/security_gate_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/web3provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/locale_provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/onboarding_state_service.dart';
import '../../services/security/post_auth_security_setup_service.dart';
import '../../services/telemetry/telemetry_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_icon_card.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/google_sign_in_web_button.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/kubus_card.dart';
import '../../widgets/glass_components.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../web3/wallet/connectwallet_screen.dart';
import '../desktop/auth/desktop_auth_shell.dart';
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
  });

  final String? redirectRoute;
  final Object? redirectArguments;
  final String? initialEmail;
  final FutureOr<void> Function(Map<String, dynamic> payload)? onAuthSuccess;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isEmailSubmitting = false;
  bool _isGoogleSubmitting = false;
  int? _googleRateLimitUntilMs;
  bool _didAttemptGoogleAutoSignIn = false;

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

    // Best-effort "automatic" sign-in on mobile (silent re-auth for returning users).
    // Note: One Tap is web-only (GIS iframe) and cannot be replicated on native.
    if (!kIsWeb && AppConfig.enableGoogleAuth) {
      unawaited(_attemptGoogleAutoSignIn());
    }
  }

  Future<void> _attemptGoogleAutoSignIn() async {
    if (_didAttemptGoogleAutoSignIn) return;
    _didAttemptGoogleAutoSignIn = true;
    if (_isGoogleSubmitting) return;

    try {
      await GoogleAuthService().ensureInitialized();
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (!mounted) return;
      if (account == null) return;

      if (mounted) {
        setState(() => _isGoogleSubmitting = true);
      }
      final result = GoogleAuthService().resultFromAccount(account);
      await _completeGoogleSignIn(result);
    } catch (_) {
      // Best-effort only.
    } finally {
      if (mounted) {
        setState(() => _isGoogleSubmitting = false);
      }
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> payload) async {
    final l10n = AppLocalizations.of(context)!;
    final redirectRoute = widget.redirectRoute?.trim();
    final isModalReauth = widget.onAuthSuccess != null;
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
    await OnboardingStateService.markCompleted(prefs: prefs);
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
      final ok = await const PostAuthSecuritySetupService().ensurePostAuthSecuritySetup(
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
      Navigator.of(context).pop(true);
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
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final profile = profileProvider.currentUser;
    final needsProfileSetup = profile != null && 
        (profile.displayName.isEmpty || profile.displayName == profile.username) &&
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
    String? address = walletProvider.currentWalletAddress;
    bool createdFreshWallet = false;

    // Keep auth completion snappy and offline-friendly.
    // Wallet + Web3 initialization is best-effort and must never block the UI
    // indefinitely (e.g. on slow RPC / captive portals / flaky mobile data).
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
      ScaffoldMessenger.of(context)
          .showKubusSnackBar(SnackBar(content: Text(l10n.authEmailSignInDisabled)));
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
            Navigator.of(context).pushReplacementNamed(
              '/verify-email',
              arguments: {'email': email},
            );
            ScaffoldMessenger.of(context).showKubusSnackBar(
              SnackBar(content: Text(l10n.authEmailNotVerifiedToast)),
            );
            return;
          }
        } catch (_) {
          // Fall through to generic error toast.
        }
      }
      ScaffoldMessenger.of(context)
          .showKubusSnackBar(SnackBar(content: Text(l10n.authEmailSignInFailed)));
    } finally {
      if (mounted) setState(() => _isEmailSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableGoogleAuth) {
      ScaffoldMessenger.of(context)
          .showKubusSnackBar(SnackBar(content: Text(l10n.authGoogleSignInDisabled)));
      return;
    }

    // Web uses a GIS-rendered button which triggers auth events instead of an
    // imperative signIn call.
    if (kIsWeb) {
      return;
    }

    unawaited(TelemetryService().trackSignInAttempt(method: 'google'));

    // Honor any server-provided rate-limit cooldown persisted from prior attempts.
    final untilMs = _googleRateLimitUntilMs;
    if (untilMs != null) {
      final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
      if (DateTime.now().isBefore(until)) {
        final remaining = until.difference(DateTime.now());
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        final friendly = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authGoogleRateLimitedRetryIn(friendly))),
        );
        unawaited(TelemetryService().trackSignInFailure(
            method: 'google', errorClass: 'rate_limited'));
        return;
      }
    }

    setState(() => _isGoogleSubmitting = true);
    try {
      final googleResult = await GoogleAuthService().signIn();
      if (googleResult == null) {
        unawaited(TelemetryService()
            .trackSignInFailure(method: 'google', errorClass: 'cancelled'));
        if (!mounted) return;
        setState(() => _isGoogleSubmitting = false);
        return;
      }
      await _completeGoogleSignIn(googleResult);
      unawaited(TelemetryService().trackSignInSuccess(method: 'google'));
    } catch (e) {
      unawaited(TelemetryService().trackSignInFailure(
          method: 'google', errorClass: e.runtimeType.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showKubusSnackBar(SnackBar(content: Text(l10n.authGoogleSignInFailed)));
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
        final remaining = until.difference(DateTime.now());
        final mins = remaining.inMinutes;
        final secs = remaining.inSeconds % 60;
        final friendly = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.authGoogleRateLimitedRetryIn(friendly))),
        );
        unawaited(TelemetryService().trackSignInFailure(
            method: 'google', errorClass: 'rate_limited'));
        return;
      }
    }

    if (!_isGoogleSubmitting && mounted) {
      setState(() => _isGoogleSubmitting = true);
    }

    final api = BackendApiService();

    // For email account merge: pass email but NOT username to avoid overwriting
    // existing account data. Backend preserves existing username/avatar/name.
    final result = await api.loginWithGoogle(
      idToken: googleResult.idToken,
      code: googleResult.serverAuthCode,
      email: googleResult.email,
      username: null,
    );

    // Clear any stored cooldown on success.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rate_limit_auth_google_until');
      _googleRateLimitUntilMs = null;
    } catch (_) {}

    if (!mounted) return;
    await _handleAuthSuccess(result);
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
    return KubusCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          vertical: KubusSpacing.md, horizontal: KubusSpacing.md),
      color: colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colorScheme.primary, size: 22),
          const SizedBox(width: KubusSpacing.sm),
          Text(label,
              style: KubusTypography.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final accentStart = colorScheme.primary;
    final accentEnd = roles.positiveAction;
    final enableWallet = AppConfig.enableWeb3 && AppConfig.enableWalletConnect;
    final enableEmail = AppConfig.enableEmailAuth;
    final enableGoogle = AppConfig.enableGoogleAuth;
    final isDesktop =
        MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;

    final form = _buildAuthForm(
      colorScheme: colorScheme,
      enableWallet: enableWallet,
      enableEmail: enableEmail,
      enableGoogle: enableGoogle,
      isDesktop: isDesktop,
    );

    if (isDesktop) {
      return DesktopAuthShell(
        title: l10n.authSignInTitle,
        subtitle: l10n.authSignInSubtitle,
        highlights: [
          l10n.authHighlightSignInMethods,
          l10n.authHighlightNoFees,
          l10n.authHighlightControl,
        ],
        icon: GradientIconCard(
          start: accentStart,
          end: accentEnd,
          icon: Icons.login_rounded,
          iconSize: 52,
          width: 100,
          height: 100,
          radius: 20,
        ),
        gradientStart: accentStart,
        gradientEnd: accentEnd,
        form: form,
        footer: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              unawaited(TelemetryService().trackSignInAttempt(method: 'guest'));
              unawaited(TelemetryService().trackSignInSuccess(method: 'guest'));
              Navigator.of(context).pushReplacementNamed('/main');
            },
            child: Text(
              l10n.commonSkipForNow,
              style: GoogleFonts.inter(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        showHeaderControls: true,
      );
    }

    final bgStart = accentStart.withValues(alpha: 0.55);
    final bgEnd = accentEnd.withValues(alpha: 0.50);
    final bgMid = (Color.lerp(bgStart, bgEnd, 0.55) ?? bgEnd).withValues(alpha: 0.52);
    final bgColors = <Color>[bgStart, bgMid, bgEnd, bgStart];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const AppLogo(width: 36, height: 36),
        actions: [
          // Language selector
          PopupMenuButton<String>(
            onSelected: (value) {
              final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
              unawaited(localeProvider.setLanguageCode(value));
            },
            itemBuilder: (BuildContext context) {
              final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
              return [
                PopupMenuItem(
                  value: 'sl',
                  child: Row(
                    children: [
                      if (localeProvider.languageCode == 'sl')
                        Icon(Icons.check, size: 18, color: colorScheme.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(l10n.languageSlovenian),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'en',
                  child: Row(
                    children: [
                      if (localeProvider.languageCode == 'en')
                        Icon(Icons.check, size: 18, color: colorScheme.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text(l10n.languageEnglish),
                    ],
                  ),
                ),
              ];
            },
            tooltip: l10n.settingsLanguageTitle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.language,
                size: 24,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          // Theme toggle
          IconButton(
            icon: Icon(
              Provider.of<ThemeProvider>(context).isDarkMode ? Icons.brightness_7 : Icons.brightness_4,
              size: 24,
            ),
            tooltip: Provider.of<ThemeProvider>(context).isDarkMode ? l10n.settingsThemeModeLight : l10n.settingsThemeModeDark,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
            onPressed: () {
              final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
              final currentMode = themeProvider.themeMode;
              final newMode = currentMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
              unawaited(themeProvider.setThemeMode(newMode));
            },
          ),
          TextButton(
            onPressed: () {
              unawaited(
                  TelemetryService().trackSignInAttempt(method: 'guest'));
              unawaited(
                  TelemetryService().trackSignInSuccess(method: 'guest'));
              Navigator.of(context).pushReplacementNamed('/main');
            },
            child: Text(
              l10n.commonSkipForNow,
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
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: kToolbarHeight + 12),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: form,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
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

  Widget _buildAuthForm({
    required ColorScheme colorScheme,
    required bool enableWallet,
    required bool enableEmail,
    required bool enableGoogle,
    required bool isDesktop,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isDesktop)
          SizedBox(
            width: double.infinity,
            child: LiquidGlassPanel(
              padding: const EdgeInsets.all(18),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  GradientIconCard(
                    start: colorScheme.primary,
                    end: roles.positiveAction,
                    icon: Icons.login_rounded,
                    iconSize: 52,
                    width: 100,
                    height: 100,
                    radius: 20,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.authSignInTitle,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authSignInSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        if (!isDesktop) const SizedBox(height: 20),
        if (enableWallet)
          KubusButton(
            onPressed: _showConnectWalletModal,
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.authConnectWalletButton,
            isFullWidth: true,
          ),
        if (enableWallet) const SizedBox(height: KubusSpacing.md),
        KubusCard(
          padding: const EdgeInsets.all(KubusSpacing.md),
          color: colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.authOrLogInWithEmailOrUsername,
                style: KubusTypography.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: KubusSpacing.md),
              if (enableEmail) _buildEmailForm(colorScheme),
              if (enableGoogle) ...[
                const SizedBox(height: KubusSpacing.md),
                if (kIsWeb)
                  GoogleSignInWebButton(
                    colorScheme: colorScheme,
                    isLoading: _isGoogleSubmitting,
                    onAuthResult: (GoogleAuthResult googleResult) async {
                      unawaited(
                        TelemetryService().trackSignInAttempt(method: 'google'),
                      );
                      await _completeGoogleSignIn(googleResult);
                      unawaited(
                        TelemetryService().trackSignInSuccess(method: 'google'),
                      );
                    },
                    onAuthError: (Object error) {
                      unawaited(
                        TelemetryService().trackSignInFailure(
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
                    onPressed: _signInWithGoogle,
                    isLoading: _isGoogleSubmitting,
                    colorScheme: colorScheme,
                  ),
              ],
              const SizedBox(height: KubusSpacing.md),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/register'),
                child: Text(
                  l10n.authNeedAccountRegister,
                  style: KubusTypography.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.commonEmail,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.commonPassword,
            border: const OutlineInputBorder(),
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
}
