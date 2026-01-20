import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:art_kubus/l10n/app_localizations.dart';
import '../../config/config.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_icon_card.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/kubus_card.dart';
import '../../widgets/kubus_snackbar.dart';
import '../../widgets/glass_components.dart';
import '../desktop/auth/desktop_auth_shell.dart';
import '../desktop/desktop_shell.dart';
import '../../services/backend_api_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.email,
    this.token,
  });

  final String? email;
  final String? token;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final TextEditingController _emailController;
  bool _verifying = false;
  bool _verified = false;
  bool _resending = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: (widget.email ?? '').trim());
    final token = (widget.token ?? '').trim();
    if (token.isNotEmpty) {
      unawaited(_verifyToken(token));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _verifyToken(String token) async {
    if (_verifying || _verified) return;
    setState(() {
      _verifying = true;
      _inlineError = null;
    });
    try {
      await BackendApiService().verifyEmail(token: token);
      if (!mounted) return;
      setState(() => _verified = true);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.authVerifyEmailSuccessToast)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = AppLocalizations.of(context)!.authVerifyEmailFailedInline);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resendVerification() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableEmailAuth) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.authEmailSignInDisabled)),
      );
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _inlineError = l10n.authVerifyEmailEnterEmailInline);
      return;
    }
    setState(() {
      _resending = true;
      _inlineError = null;
    });
    try {
      await BackendApiService().resendEmailVerification(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.authVerifyEmailResendToast)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = l10n.authVerifyEmailResendFailedInline);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _goToSignIn() {
    Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (_) => false);
  }

  Widget _buildForm({
    required AppLocalizations l10n,
    required ColorScheme scheme,
  }) {
    final tokenPresent = (widget.token ?? '').trim().isNotEmpty;
    final statusText = _verified
        ? l10n.authVerifyEmailStatusVerified
        : (_verifying ? l10n.authVerifyEmailStatusVerifying : l10n.authVerifyEmailStatusPending);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tokenPresent) ...[
          Text(
            statusText,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _verified
                  ? KubusColorRoles.of(context).positiveAction
                  : scheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.commonEmail,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_inlineError != null) ...[
          Text(
            _inlineError!,
            style: GoogleFonts.inter(color: scheme.error),
          ),
          const SizedBox(height: 12),
        ],
        KubusButton(
          onPressed: _resending ? null : _resendVerification,
          isLoading: _resending,
          icon: _resending ? null : Icons.refresh_rounded,
          label: l10n.authVerifyEmailResendButton,
          isFullWidth: true,
        ),
        const SizedBox(height: 12),
        KubusButton(
          onPressed: _goToSignIn,
          icon: Icons.login_rounded,
          label: l10n.commonSignIn,
          isFullWidth: true,
        ),
        if (!_verified) ...[
          const SizedBox(height: 10),
          Text(
            l10n.authVerifyEmailSignInHint,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;

    final form = _buildForm(l10n: l10n, scheme: scheme);

    if (isDesktop) {
      return DesktopAuthShell(
        title: l10n.authVerifyEmailTitle,
        subtitle: l10n.authVerifyEmailSubtitle,
        highlights: [
          l10n.authVerifyEmailHighlightInbox,
          l10n.authVerifyEmailHighlightSpam,
          l10n.authVerifyEmailHighlightSecure,
        ],
        icon: GradientIconCard(
          start: scheme.primary,
          end: roles.positiveAction,
          icon: Icons.mark_email_read_outlined,
          iconSize: 52,
          width: 100,
          height: 100,
          radius: 20,
        ),
        gradientStart: scheme.primary,
        gradientEnd: roles.positiveAction,
        form: form,
        footer: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _goToSignIn,
            child: Text(
              l10n.commonBack,
              style: GoogleFonts.inter(
                color: scheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    final bgStart = scheme.primary.withValues(alpha: 0.55);
    final bgEnd = roles.positiveAction.withValues(alpha: 0.50);
    final bgMid = (Color.lerp(bgStart, bgEnd, 0.55) ?? bgEnd).withValues(alpha: 0.52);
    final bgColors = <Color>[bgStart, bgMid, bgEnd, bgStart];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: const AppLogo(width: 36, height: 36),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Padding(
                padding: const EdgeInsets.only(top: kToolbarHeight + 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          children: [
                            GradientIconCard(
                              start: scheme.primary,
                              end: roles.positiveAction,
                              icon: Icons.mark_email_read_outlined,
                              iconSize: 52,
                              width: 100,
                              height: 100,
                              radius: 20,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.authVerifyEmailTitle,
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.authVerifyEmailSubtitle,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: scheme.onSurface.withValues(alpha: 0.85),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        KubusCard(
                          padding: const EdgeInsets.all(16),
                          color: scheme.surfaceContainerHighest,
                          child: form,
                        ),
                      ],
                    ),
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
