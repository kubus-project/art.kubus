import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_icon_card.dart';
import '../../widgets/glass_components.dart';
import '../../services/backend_api_service.dart';

class EmailVerificationSuccessScreen extends StatefulWidget {
  const EmailVerificationSuccessScreen({
    super.key,
    required this.token,
  });

  final String token;

  @override
  State<EmailVerificationSuccessScreen> createState() => _EmailVerificationSuccessScreenState();
}

class _EmailVerificationSuccessScreenState extends State<EmailVerificationSuccessScreen> {
  bool _verifying = true;
  bool _verified = false;
  String? _error;
  int _countdown = 5;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _verifyToken();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyToken() async {
    try {
      await BackendApiService().verifyEmail(token: widget.token);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = true;
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'This verification link is invalid or expired.';
      });
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
      });
      if (_countdown <= 0) {
        timer.cancel();
        _closeTab();
      }
    });
  }

  void _closeTab() {
    // Try to close the window/tab
    if (kIsWeb) {
      // On web, try to close the window
      // Note: This only works if the window was opened by script
      // Otherwise it will just show the message
      try {
        // ignore: avoid_web_libraries_in_flutter
        // We use conditional import in web-specific code
        // For now, just show a message that they can close the tab
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roles = KubusColorRoles.of(context);

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
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedGradientBackground(
            duration: const Duration(seconds: 10),
            intensity: 0.2,
            colors: [
              scheme.primary.withValues(alpha: 0.15),
              scheme.secondary.withValues(alpha: 0.12),
              roles.positiveAction.withValues(alpha: 0.1),
            ],
            child: const SizedBox.expand(),
          ),
          SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_verifying) ...[
                        GradientIconCard(
                          start: scheme.primary,
                          end: roles.positiveAction,
                          icon: Icons.hourglass_empty,
                          iconSize: 52,
                          width: 100,
                          height: 100,
                          radius: 20,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Verifying...',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                      ] else if (_verified) ...[
                        GradientIconCard(
                          start: roles.positiveAction,
                          end: scheme.primary,
                          icon: Icons.check_circle_outline,
                          iconSize: 52,
                          width: 100,
                          height: 100,
                          radius: 20,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Email Verified!',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        LiquidGlassPanel(
                          blurSigma: 12,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: roles.positiveAction,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your email has been successfully verified!',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: scheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'This tab will auto-close in',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: scheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$_countdown',
                                      style: GoogleFonts.inter(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: roles.positiveAction,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Go back to your session and sign in to continue',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface.withValues(alpha: 0.85),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushReplacementNamed('/sign-in'),
                          child: Text(
                            'Or continue in this tab →',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ] else if (_error != null) ...[
                        GradientIconCard(
                          start: scheme.error,
                          end: scheme.error.withValues(alpha: 0.7),
                          icon: Icons.error_outline,
                          iconSize: 52,
                          width: 100,
                          height: 100,
                          radius: 20,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Verification Failed',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LiquidGlassPanel(
                          blurSigma: 12,
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: scheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushReplacementNamed('/sign-in'),
                          child: Text(
                            'Go to Sign In',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
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
