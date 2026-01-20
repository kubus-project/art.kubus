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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _submitting = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: (widget.initialEmail ?? '').trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.enableEmailAuth) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.authEmailSignInDisabled)),
      );
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _inlineError = l10n.authForgotPasswordEnterEmailInline);
      return;
    }
    setState(() {
      _submitting = true;
      _inlineError = null;
    });
    try {
      await BackendApiService().forgotPassword(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.authForgotPasswordSentToast)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _inlineError = l10n.authForgotPasswordFailedInline);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goToSignIn() {
    Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (_) => false);
  }

  Widget _buildForm({
    required AppLocalizations l10n,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          Text(_inlineError!, style: GoogleFonts.inter(color: scheme.error)),
          const SizedBox(height: 12),
        ],
        KubusButton(
          onPressed: _submitting ? null : _submit,
          isLoading: _submitting,
          icon: _submitting ? null : Icons.send_rounded,
          label: l10n.authForgotPasswordSendButton,
          isFullWidth: true,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _goToSignIn,
          child: Text(
            l10n.commonBack,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= DesktopBreakpoints.medium;

    final form = _buildForm(l10n: l10n);

    if (isDesktop) {
      return DesktopAuthShell(
        title: l10n.authForgotPasswordTitle,
        subtitle: l10n.authForgotPasswordSubtitle,
        highlights: [
          l10n.authForgotPasswordHighlightOne,
          l10n.authForgotPasswordHighlightTwo,
        ],
        icon: GradientIconCard(
          start: scheme.primary,
          end: roles.positiveAction,
          icon: Icons.lock_reset_rounded,
          iconSize: 52,
          width: 100,
          height: 100,
          radius: 20,
        ),
        gradientStart: scheme.primary,
        gradientEnd: roles.positiveAction,
        form: form,
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
                              icon: Icons.lock_reset_rounded,
                              iconSize: 52,
                              width: 100,
                              height: 100,
                              radius: 20,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.authForgotPasswordTitle,
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.authForgotPasswordSubtitle,
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
