import 'dart:async';

import 'package:flutter/material.dart';
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

    // Bring back "automatic" / low-friction sign-in on web:
    // - attemptLightweightAuthentication() enables silent re-auth when possible
    //   (returning users, existing session, etc.).
    // - best-effort One Tap prompt when supported by the underlying web plugin.
    try {
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (!mounted) return;
      if (account != null && !widget.isLoading) {
        final result = GoogleAuthService().resultFromAccount(account);
        await widget.onAuthResult(result);
      }
    } catch (_) {
      // Best-effort only; One Tap / silent auth may be blocked by browser policies.
    }

    // Best-effort One Tap prompt (GIS) when available.
    // The plugin API surface can vary by version; we avoid hard dependency.
    try {
      final platform = GoogleSignInPlatform.instance;
      if (platform is gweb.GoogleSignInPlugin) {
        // ignore: avoid_dynamic_calls
        await (platform as dynamic).prompt();
      }
    } catch (_) {
      // Best-effort only.
    }
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

    final Widget child;
    if (!_ready) {
      child = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      final platform = GoogleSignInPlatform.instance;
      if (platform is gweb.GoogleSignInPlugin) {
        child = LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double maxWidth =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 400;
            // Match the surrounding auth buttons: take the full available width.
            // Keep GIS unscaled so logo/text match Google's sizing.
            final double buttonWidth = maxWidth;

            // Use only the GIS button (no custom visible wrappers).
            // Keep the GIS button unscaled so its typography matches Google specs.
            // We still match the surrounding layout by centering it inside the
            // 56px auth row height.
            return SizedBox(
              width: buttonWidth,
              child: platform.renderButton(
                configuration: gweb.GSIButtonConfiguration(
                  type: gweb.GSIButtonType.standard,
                  theme: isDark
                      ? gweb.GSIButtonTheme.filledBlack
                      : gweb.GSIButtonTheme.outline,
                  size: gweb.GSIButtonSize.large,
                  text: gweb.GSIButtonText.continueWith,
                  shape: gweb.GSIButtonShape.rectangular,
                  logoAlignment: gweb.GSIButtonLogoAlignment.left,
                  minimumWidth: buttonWidth,
                ),
              ),
            );
          },
        );
      } else {
        child = const SizedBox.shrink();
      }
    }

    // Same size as other auth buttons.
    const double reservedHeight = 56;
    return SizedBox(
      height: reservedHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: widget.isLoading,
              child: child,
            ),
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
}
