import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as gweb;

import '../services/google_auth_service.dart';
import 'glass_components.dart';

class GoogleSignInWebButton extends StatefulWidget {
  const GoogleSignInWebButton({
    super.key,
    required this.onAuthResult,
    this.onAuthError,
    required this.isLoading,
    required this.colorScheme,
  });

  final Future<void> Function(GoogleAuthResult result) onAuthResult;
  final void Function(Object error)? onAuthError;
  final bool isLoading;
  final ColorScheme colorScheme;

  @override
  State<GoogleSignInWebButton> createState() => _GoogleSignInWebButtonState();
}

class _GoogleSignInWebButtonState extends State<GoogleSignInWebButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await GoogleAuthService().ensureInitialized();
    } catch (e) {
      widget.onAuthError?.call(e);
    }

    if (!mounted) return;
    setState(() {
      _ready = true;
    });

    _sub ??= GoogleSignIn.instance.authenticationEvents.listen(
      (GoogleSignInAuthenticationEvent event) async {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          if (!mounted) return;
          if (widget.isLoading) return;

          try {
            final result = GoogleAuthService().resultFromAccount(event.user);
            await widget.onAuthResult(result);
          } catch (e) {
            widget.onAuthError?.call(e);
          }
        }
      },
      onError: (Object error) {
        widget.onAuthError?.call(error);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);

    // Brand-ish tones (we still render the required GIS button for web).
    const googleBlue = Color(0xFF4285F4);
    const googleAmber = Color(0xFFFBBC05);

    final brandBackground = isDark ? googleBlue : googleAmber;
    final glassTint = brandBackground.withValues(alpha: isDark ? 0.78 : 0.86);

    final Widget child;
    if (!_ready) {
      child = _buildFallbackLoading();
    } else {
      final platform = GoogleSignInPlatform.instance;
      if (platform is gweb.GoogleSignInPlugin) {
        child = LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 400;
            final double buttonWidth = maxWidth.clamp(180, 400);

            return platform.renderButton(
              configuration: gweb.GSIButtonConfiguration(
                type: gweb.GSIButtonType.standard,
                // Keep Google's button readable against our brand-tinted glass.
                theme: isDark
                    ? gweb.GSIButtonTheme.filledBlack
                    : gweb.GSIButtonTheme.outline,
                size: gweb.GSIButtonSize.large,
                text: gweb.GSIButtonText.continueWith,
                shape: gweb.GSIButtonShape.pill,
                logoAlignment: gweb.GSIButtonLogoAlignment.left,
                minimumWidth: buttonWidth,
              ),
            );
          },
        );
      } else {
        child = _buildFallbackUnsupported();
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: brandBackground.withValues(alpha: 0.35),
        ),
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AbsorbPointer(
                absorbing: widget.isLoading,
                child: Center(child: child),
              ),
              if (widget.isLoading)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.transparent,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLoading() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(
          'Preparing Google sign-in…',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackUnsupported() {
    return Text(
      'Google sign-in is unavailable',
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
