import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as gweb;

import '../services/google_auth_service.dart';

class GoogleSignInWebButton extends StatefulWidget {
  const GoogleSignInWebButton({
    super.key,
    required this.onAuthResult,
    this.onAuthError,
    required this.isLoading,
    required this.colorScheme,
    this.scale = 1.15,
  });

  final Future<void> Function(GoogleAuthResult result) onAuthResult;
  final void Function(Object error)? onAuthError;
  final bool isLoading;
  final ColorScheme colorScheme;
  final double scale;

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

    // Defensive: avoid weird layout/math if someone passes 0 or negative.
    final scale = widget.scale <= 0 ? 1.0 : widget.scale;

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
            // We scale the rendered button up for better tap targets/visual weight.
            // Because Transform.scale doesn't affect layout, we compensate by
            // shrinking the minimumWidth so the post-scale visual width matches
            // the available space.
            final double desiredVisualWidth = maxWidth.clamp(200, 420);
            final double minWidthBeforeScale = (desiredVisualWidth / scale)
                .clamp(160, desiredVisualWidth);

            return Center(
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: platform.renderButton(
                  configuration: gweb.GSIButtonConfiguration(
                    type: gweb.GSIButtonType.standard,
                    theme: isDark
                        ? gweb.GSIButtonTheme.filledBlack
                        : gweb.GSIButtonTheme.outline,
                    size: gweb.GSIButtonSize.large,
                    text: gweb.GSIButtonText.continueWith,
                    shape: gweb.GSIButtonShape.pill,
                    logoAlignment: gweb.GSIButtonLogoAlignment.left,
                    minimumWidth: minWidthBeforeScale,
                  ),
                ),
              ),
            );
          },
        );
      } else {
        child = _buildFallbackUnsupported();
      }
    }

    // No wrapper/background: show the original GIS button as-is.
    // We only reserve enough height so the scaled button doesn't get clipped.
    final double reservedHeight = 56 * scale;
    return SizedBox(
      height: reservedHeight,
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
