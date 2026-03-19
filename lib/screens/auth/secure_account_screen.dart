import 'dart:async';

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

class SecureAccountScreen extends StatefulWidget {
  const SecureAccountScreen({super.key});

  @override
  State<SecureAccountScreen> createState() => _SecureAccountScreenState();
}

enum _SecureAccountMode {
  loading,
  addEmailAndPassword,
  addPasswordOnly,
  secured,
}

class _SecureAccountScreenState extends State<SecureAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _SecureAccountMode _mode = _SecureAccountMode.loading;
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _verificationSent = false;
  bool _emailVerified = false;
  String? _accountEmail;

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatus());
  }

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

  Future<void> _loadStatus() async {
    try {
      final api = BackendApiService();
      Map<String, dynamic> status;
      try {
        status = await api.getAccountSecurityStatus();
      } catch (_) {
        status = await api.getCachedSecureAccountStatus();
      }
      _applyStatus(status);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mode = _SecureAccountMode.addEmailAndPassword;
      });
    }
  }

  void _applyStatus(Map<String, dynamic> status) {
    final hasEmail = status['hasEmail'] == true;
    final hasPassword = status['hasPassword'] == true;
    final email = hasEmail ? (status['email'] ?? '').toString().trim() : '';
    if (email.isNotEmpty) {
      _emailController.text = email;
    }

    if (!mounted) return;
    setState(() {
      _accountEmail = email.isNotEmpty ? email : null;
      _emailVerified = status['emailVerified'] == true;
      _mode = hasEmail
          ? (hasPassword
              ? _SecureAccountMode.secured
              : _SecureAccountMode.addPasswordOnly)
          : _SecureAccountMode.addEmailAndPassword;
    });
  }

  void _clearErrors() {
    _emailError = null;
    _passwordError = null;
    _confirmPasswordError = null;
    _inlineError = null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final needsEmail = _mode == _SecureAccountMode.addEmailAndPassword;
    final emailLooksValid =
        !needsEmail || (email.contains('@') && email.contains('.'));
    final passwordOk = AuthPasswordPolicy.isValid(password);
    final confirmOk = password == confirm;

    setState(() {
      _emailError = emailLooksValid || !needsEmail
          ? null
          : l10n.authEnterValidEmailInline;
      _passwordError = passwordOk ? null : l10n.authPasswordPolicyError;
      _confirmPasswordError =
          confirmOk ? null : l10n.authPasswordMismatchInline;
      _inlineError = null;
    });

    if (!emailLooksValid || !passwordOk || !confirmOk) return;

    setState(() => _isSubmitting = true);
    try {
      final api = BackendApiService();
      if (_mode == _SecureAccountMode.addPasswordOnly) {
        try {
          await api.ensureAuthLoaded().timeout(const Duration(seconds: 8));
        } catch (_) {}
        final response = await api.addPasswordToCurrentAccount(
          password: password,
        );
        final payload = response['data'] is Map<String, dynamic>
            ? response['data'] as Map<String, dynamic>
            : response;
        final securityStatus = payload['securityStatus'] is Map<String, dynamic>
            ? payload['securityStatus'] as Map<String, dynamic>
            : <String, dynamic>{};
        _passwordController.clear();
        _confirmPasswordController.clear();
        _clearErrors();
        _applyStatus(securityStatus);
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.authSecureAccountPasswordAddedToast)),
        );
      } else {
        final walletAddress = _resolveWalletAddress();
        if (walletAddress.isEmpty) {
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.authConnectWalletModalTitle)),
          );
          return;
        }

        try {
          await api
              .ensureAuthLoaded(walletAddress: walletAddress)
              .timeout(const Duration(seconds: 8));
        } catch (_) {}

        final response = await api.registerWithEmail(
          email: email,
          password: password,
          walletAddress: walletAddress,
          includeAuth: true,
        );
        await api.syncSecureAccountStatusFromResponse(response);
        final payload = response['data'] is Map<String, dynamic>
            ? response['data'] as Map<String, dynamic>
            : response;
        final emailVerificationSent = payload['emailVerificationSent'] == true;

        if (!mounted) return;
        if (emailVerificationSent) {
          setState(() => _verificationSent = true);
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.authVerifyEmailRegistrationToast)),
          );
        } else {
          setState(() {
            _verificationSent = false;
            _inlineError = l10n.authVerifyEmailResendFailedInline;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureAccountScreen: submit failed: $e');
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
    final email = (_accountEmail ?? _emailController.text).trim();
    if (email.isEmpty) return;
    setState(() {
      _isResending = true;
      _inlineError = null;
    });
    try {
      final response = await BackendApiService()
          .resendEmailVerificationForCurrentAccount(email: email);
      await BackendApiService().syncSecureAccountStatusFromResponse(
        response,
        fetchIfMissing: false,
      );
      final payload = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      final emailVerificationSent = payload['emailVerificationSent'] == true;
      if (!mounted) return;
      if (emailVerificationSent || payload['message'] != null) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(
              emailVerificationSent
                  ? l10n.authVerifyEmailResendToast
                  : (payload['message'] ?? l10n.authVerifyEmailResendToast)
                      .toString(),
            ),
          ),
        );
      } else {
        setState(() => _inlineError = l10n.authVerifyEmailResendFailedInline);
      }
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
          l10n.authSecureAccountVerificationSentTitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          l10n.authSecureAccountVerificationSentSubtitle,
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

  Widget _buildSecuredState({
    required AppLocalizations l10n,
    required ColorScheme scheme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.authSecureAccountSecuredTitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          _emailVerified
              ? l10n.authSecureAccountSecuredVerifiedSubtitle
              : l10n.authSecureAccountSecuredUnverifiedSubtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.35,
            color: scheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
        if ((_accountEmail ?? '').isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.md),
          _buildAccountEmailChip(scheme),
        ],
        const SizedBox(height: KubusSpacing.lg),
        KubusButton(
          onPressed: _close,
          label: l10n.commonDone,
          isFullWidth: true,
        ),
        if (!_emailVerified) ...[
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
      ],
    );
  }

  Widget _buildAccountEmailChip(ColorScheme scheme) {
    final email = (_accountEmail ?? _emailController.text).trim();
    if (email.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.email_outlined,
            size: 18,
            color: scheme.onSurface.withValues(alpha: 0.78),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Text(
              email,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState({
    required AppLocalizations l10n,
    required ColorScheme scheme,
  }) {
    final passwordOnly = _mode == _SecureAccountMode.addPasswordOnly;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          passwordOnly
              ? l10n.authSecureAccountAddPasswordTitle
              : l10n.authSecureAccountTitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Text(
          passwordOnly
              ? l10n.authSecureAccountFormAddPasswordSubtitle
              : l10n.authSecureAccountFormDefaultSubtitle,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.35,
            color: scheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
        if (passwordOnly) ...[
          const SizedBox(height: KubusSpacing.lg),
          _buildAccountEmailChip(scheme),
        ],
        const SizedBox(height: KubusSpacing.lg),
        EmailRegistrationForm(
          emailController: _emailController,
          passwordController: _passwordController,
          confirmPasswordController: _confirmPasswordController,
          submitLabel: passwordOnly
              ? l10n.authSecureAccountAddPasswordButton
              : l10n.authSecureAccountButton,
          submittingLabel: l10n.commonWorking,
          icon: Icons.lock_outline,
          isSubmitting: _isSubmitting,
          onSubmit: _submit,
          compact: true,
          showUsername: false,
          showEmailField: !passwordOnly,
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

    final Widget body;
    if (_verificationSent) {
      body = _buildSuccessState(l10n: l10n, scheme: scheme);
    } else if (_mode == _SecureAccountMode.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_mode == _SecureAccountMode.secured) {
      body = _buildSecuredState(l10n: l10n, scheme: scheme);
    } else {
      body = _buildFormState(l10n: l10n, scheme: scheme);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const AppLogoStatic(
          width: 36,
          height: 36,
          forLightMode: false,
        ),
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
