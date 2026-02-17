import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/auth_password_policy.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/email_registration_form.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:art_kubus/widgets/kubus_card.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureAccountScreen extends StatefulWidget {
  const SecureAccountScreen({super.key});

  @override
  State<SecureAccountScreen> createState() => _SecureAccountScreenState();
}

class _SecureAccountScreenState extends State<SecureAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isResending = false;
  bool _verificationSent = false;

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _inlineError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _resolveWalletAddress() {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final direct = (walletProvider.currentWalletAddress ?? '').trim();
    if (direct.isNotEmpty) return direct;
    final fromProfile =
        (profileProvider.currentUser?.walletAddress ?? '').trim();
    if (fromProfile.isNotEmpty) return fromProfile;
    return '';
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final emailLooksValid = email.contains('@') && email.contains('.');
    final passwordOk = AuthPasswordPolicy.isValid(password);
    final confirmOk = password == confirm;

    setState(() {
      _emailError = emailLooksValid ? null : l10n.authEnterValidEmailInline;
      _passwordError = passwordOk ? null : l10n.authPasswordPolicyError;
      _confirmPasswordError =
          confirmOk ? null : l10n.authPasswordMismatchInline;
      _inlineError = null;
    });

    if (!emailLooksValid || !passwordOk || !confirmOk) return;

    final walletAddress = _resolveWalletAddress();
    if (walletAddress.isEmpty) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.authConnectWalletModalTitle)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Ensure the wallet session token is available when linking to an existing wallet user.
      try {
        await BackendApiService()
            .ensureAuthLoaded(walletAddress: walletAddress)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Best-effort only. The backend may still accept the request depending on config.
      }

      await BackendApiService().registerWithEmail(
        email: email,
        password: password,
        walletAddress: walletAddress,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PreferenceKeys.secureAccountEmail, email);
      await prefs.setBool(PreferenceKeys.secureAccountEmailVerifiedV1, false);

      if (!mounted) return;
      setState(() => _verificationSent = true);
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.authVerifyEmailRegistrationToast)),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureAccountScreen: registerWithEmail failed: $e');
      }
      if (!mounted) return;
      setState(() => _inlineError = l10n.authRegistrationFailed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendVerification() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (_isResending) return;
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _isResending = true;
      _inlineError = null;
    });
    try {
      await BackendApiService().resendEmailVerification(email: email);
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.authVerifyEmailResendToast)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = l10n.authVerifyEmailResendFailedInline);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed('/main');
  }

  Widget _buildSuccessState({
    required AppLocalizations l10n,
    required ColorScheme scheme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verification email sent',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          'You’re still signed in. Verify when you can.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.35,
            color: scheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: KubusSpacing.lg),
        KubusButton(
          onPressed: _close,
          label: l10n.commonDone,
          isFullWidth: true,
        ),
        const SizedBox(height: KubusSpacing.xs),
        TextButton(
          onPressed: _isResending ? null : _resendVerification,
          child: Text(
            _isResending
                ? l10n.commonWorking
                : l10n.authVerifyEmailResendButton,
            style: GoogleFonts.inter(
              color: scheme.onSurface.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);

    final bgStart = scheme.primary.withValues(alpha: 0.55);
    final bgEnd = roles.statTeal.withValues(alpha: 0.48);
    final bgMid =
        (Color.lerp(bgStart, bgEnd, 0.55) ?? bgEnd).withValues(alpha: 0.52);
    final bgColors = <Color>[bgStart, bgMid, bgEnd, bgStart];

    final body = _verificationSent
        ? _buildSuccessState(l10n: l10n, scheme: scheme)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Secure your account',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: KubusSpacing.xs),
              Text(
                'Add email + password for recovery. Verification is last and non-blocking.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.35,
                  color: scheme.onSurface.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: KubusSpacing.lg),
              EmailRegistrationForm(
                emailController: _emailController,
                passwordController: _passwordController,
                confirmPasswordController: _confirmPasswordController,
                submitLabel: 'Secure account',
                submittingLabel: l10n.commonWorking,
                icon: Icons.lock_outline,
                isSubmitting: _isSubmitting,
                onSubmit: _submit,
                compact: true,
                showUsername: false,
                emailError: _emailError,
                passwordError: _passwordError,
                confirmPasswordError: _confirmPasswordError,
              ),
              if (_inlineError != null) ...[
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  _inlineError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: KubusSpacing.xs),
              TextButton(
                onPressed: _isSubmitting ? null : _close,
                child: Text(
                  l10n.commonSkipForNow,
                  style: GoogleFonts.inter(
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const AppLogo(width: 36, height: 36),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedGradientBackground(
            duration: const Duration(seconds: 10),
            intensity: 0.18,
            colors: bgColors,
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.lg,
                vertical: KubusSpacing.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: KubusCard(
                    padding: const EdgeInsets.all(KubusSpacing.lg),
                    color: scheme.surfaceContainerHigh,
                    child: body,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
