import 'dart:async';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/config.dart';
import '../../main_app.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/web3provider.dart';
import '../../services/backend_api_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/onboarding_state_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/gradient_icon_card.dart';
import '../../widgets/google_sign_in_button.dart';
import '../web3/wallet/connectwallet_screen.dart';
import 'register_screen.dart';
import '../desktop/auth/desktop_auth_shell.dart';
import '../desktop/desktop_shell.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.redirectRoute,
    this.redirectArguments,
    this.onAuthSuccess,
  });

  final String? redirectRoute;
  final Object? redirectArguments;
  final FutureOr<void> Function(Map<String, dynamic> payload)? onAuthSuccess;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isEmailSubmitting = false;
  bool _isGoogleSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> payload) async {
    final l10n = AppLocalizations.of(context)!;
    final redirectRoute = widget.redirectRoute?.trim();
    final data = (payload['data'] as Map<String, dynamic>?) ?? payload;
    final user = (data['user'] as Map<String, dynamic>?) ?? data;
    String? walletAddress = user['walletAddress'] ?? user['wallet_address'];
    final usernameFromUser = (user['username'] ?? user['displayName'] ?? '').toString();
    final userId = user['id'];
    try {
      walletAddress = await _ensureWalletProvisioned(walletAddress?.toString(), desiredUsername: usernameFromUser);
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
    }
    if (!mounted) return;
    try {
      if (walletAddress != null && walletAddress.toString().isNotEmpty) {
        await Provider.of<ProfileProvider>(context, listen: false)
            .loadProfile(walletAddress.toString())
            .timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      AppConfig.debugPrint('SignInScreen: profile load skipped/failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authSignedInProfileRefreshSoon)),
        );
      }
    }
    if (!mounted) return;

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

    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainApp()));
  }

  Future<String?> _ensureWalletProvisioned(String? existingWallet, {String? desiredUsername}) async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final web3Provider = Provider.of<Web3Provider>(context, listen: false);
    final sanitizedExisting = existingWallet?.trim();
    String? address = walletProvider.currentWalletAddress;
    bool createdFreshWallet = false;

    if (address == null || address.isEmpty) {
      if (sanitizedExisting != null && sanitizedExisting.isNotEmpty) {
        address = sanitizedExisting;
      }
    }

    if (address != null && address.isNotEmpty) {
      if ((walletProvider.currentWalletAddress ?? '').isEmpty) {
        try {
          await walletProvider.connectWalletWithAddress(address);
        } catch (e) {
          AppConfig.debugPrint('SignInScreen: connectWalletWithAddress failed: $e');
        }
      }
      try {
        if (!web3Provider.isConnected || web3Provider.walletAddress != address) {
          await web3Provider.connectExistingWallet(address);
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
        await web3Provider.importWallet(mnemonic);
      } catch (e) {
        AppConfig.debugPrint('SignInScreen: web3 import failed: $e');
      }
      try {
        await BackendApiService().issueTokenForWallet(address);
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

  Future<void> _upsertProfileWithUsername(String address, String? desiredUsername) async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final effectiveUsername = (desiredUsername ?? '').isNotEmpty ? desiredUsername : null;
    try {
      await profileProvider.createProfileFromWallet(walletAddress: address, username: effectiveUsername);
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
        AppConfig.debugPrint('SignInScreen: updateProfile username patch failed: $err');
      }
    }
  }

  Future<void> _submitEmail() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableEmailAuth) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authEmailSignInDisabled)));
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authEnterValidEmailPassword)));
      return;
    }
    setState(() => _isEmailSubmitting = true);
    try {
      final api = BackendApiService();
      final result = await api.loginWithEmail(email: email, password: password);
      await _handleAuthSuccess(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authEmailSignInFailed)));
    } finally {
      if (mounted) setState(() => _isEmailSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableGoogleAuth) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authGoogleSignInDisabled)));
      return;
    }

    // Honor any server-provided rate-limit cooldown persisted from prior attempts.
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final untilMs = prefs.getInt('rate_limit_auth_google_until');
      if (untilMs != null) {
        final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
        if (DateTime.now().isBefore(until)) {
          final remaining = until.difference(DateTime.now());
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          final friendly = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.authGoogleRateLimitedRetryIn(friendly))),
          );
          return;
        }
      }
    } catch (_) {}

    setState(() => _isGoogleSubmitting = true);
    try {
      final googleResult = await GoogleAuthService().signIn();
      if (googleResult == null) {
        if (!mounted) return;
        setState(() => _isGoogleSubmitting = false);
        return;
      }
      final api = BackendApiService();
      final result = await api.loginWithGoogle(
        idToken: googleResult.idToken,
        email: googleResult.email,
        username: googleResult.displayName,
      );
      // Clear any stored cooldown on success.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('rate_limit_auth_google_until');
      } catch (_) {}
      await _handleAuthSuccess(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authGoogleSignInFailed)));
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  void _showConnectWalletModal() {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableWalletConnect || !AppConfig.enableWeb3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authWalletConnectionDisabled)));
      return;
    }
    final isDesktop = MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;
    if (isDesktop) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectWallet(initialStep: 0)));
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
                Text(sheetL10n.authConnectWalletModalTitle, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                const SizedBox(height: 12),
                Text(sheetL10n.authConnectWalletModalDescriptionSignIn, style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 24),
                const SizedBox(height: 16),
                _walletOptionButton(ctx, sheetL10n.authWalletOptionWalletConnect, Icons.qr_code_2_outlined, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectWallet(initialStep: 3)));
                }),
                const SizedBox(height: 16),
                _walletOptionButton(ctx, sheetL10n.authWalletOptionOtherWallets, Icons.apps_outlined, () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectWallet(initialStep: 0)));
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _walletOptionButton(BuildContext context, String label, IconData icon, VoidCallback onTap) {
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
      label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final enableWallet = AppConfig.enableWeb3 && AppConfig.enableWalletConnect;
    final enableEmail = AppConfig.enableEmailAuth;
    final enableGoogle = AppConfig.enableGoogleAuth;
    final isDesktop = MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;

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
          start: const Color(0xFF0EA5E9),
          end: const Color(0xFF10B981),
          icon: Icons.login_rounded,
          iconSize: 52,
          width: 100,
          height: 100,
          radius: 20,
        ),
        gradientStart: const Color(0xFF0EA5E9),
        gradientEnd: const Color(0xFF10B981),
        form: form,
        footer: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainApp())),
            child: Text(
              l10n.commonSkipForNow,
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
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppLogo(width: 48, height: 48),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainApp())),
                        child: Text(l10n.commonSkipForNow, style: GoogleFonts.inter(color: colorScheme.onSurface.withValues(alpha: 0.7))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  form,
                ],
              ),
            ),
          ),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isDesktop)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                GradientIconCard(
                  start: const Color(0xFF0EA5E9),
                  end: const Color(0xFF10B981),
                  icon: Icons.login_rounded,
                  iconSize: 52,
                  width: 100,
                  height: 100,
                  radius: 20,
                ),
                const SizedBox(height: 12),
                Text(l10n.authSignInTitle, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text(
                  l10n.authSignInSubtitle,
                  style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.85)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (!isDesktop) const SizedBox(height: 20),
        if (enableWallet)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            onPressed: _showConnectWalletModal,
            icon: Icon(Icons.account_balance_wallet_outlined, size: 24, color: colorScheme.onPrimary),
            label: Text(l10n.authConnectWalletButton, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onPrimary)),
          ),
        if (enableWallet) const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(l10n.authOrLogInWithEmailOrUsername, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
              const SizedBox(height: 12),
              if (enableEmail) _buildEmailForm(colorScheme),
              if (enableGoogle) ...[
                const SizedBox(height: 12),
                GoogleSignInButton(
                  onPressed: _signInWithGoogle,
                  isLoading: _isGoogleSubmitting,
                  colorScheme: colorScheme,
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Text(l10n.authNeedAccountRegister, style: GoogleFonts.inter(color: colorScheme.primary, fontWeight: FontWeight.w700)),
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
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.commonPassword,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            minimumSize: const Size.fromHeight(54),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
          ),
          onPressed: _isEmailSubmitting ? null : _submitEmail,
          icon: _isEmailSubmitting
              ? const SizedBox(width: 20, height: 20, child: InlineLoading(width: 20, height: 20, tileSize: 5))
              : Icon(Icons.login_rounded, color: colorScheme.onPrimary, size: 22),
          label: Text(
            _isEmailSubmitting ? AppLocalizations.of(context)!.commonWorking : AppLocalizations.of(context)!.authSignInWithEmail,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}
