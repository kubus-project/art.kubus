import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as gweb;

import '../config/config.dart';
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
  bool _processingAuth = false;
  String? _lastProcessedUid;

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
          if (widget.isLoading || _processingAuth) return;

          // Prevent reprocessing the same authentication event
          final uid = event.user.id;
          if (_lastProcessedUid == uid) return;

          try {
            _processingAuth = true;
            _lastProcessedUid = uid;
            final result = GoogleAuthService().resultFromAccount(event.user);
            await widget.onAuthResult(result);
          } catch (e) {
            widget.onAuthError?.call(e);
          } finally {
            if (mounted) {
              _processingAuth = false;
            }
          }
        }
      },
      onError: (Object error) {
        widget.onAuthError?.call(error);
      },
    );

    if (AppConfig.isFeatureEnabled('googleOneTapWeb')) {
      // Bring back "automatic" / low-friction sign-in on web:
      // - attemptLightweightAuthentication() enables silent re-auth when possible
      //   (returning users, existing session, etc.).
      // - best-effort One Tap prompt when supported by the underlying web plugin.
      try {
        final account =
            await GoogleSignIn.instance.attemptLightweightAuthentication();
        if (!mounted) return;
        if (account != null && !widget.isLoading && !_processingAuth) {
          final uid = account.id;
          if (_lastProcessedUid != uid) {
            _processingAuth = true;
            _lastProcessedUid = uid;
            try {
              final result = GoogleAuthService().resultFromAccount(account);
              await widget.onAuthResult(result);
            } catch (e) {
              widget.onAuthError?.call(e);
            } finally {
              if (mounted) {
                _processingAuth = false;
              }
            }
          }
        }
      } catch (_) {
        // Best-effort only; One Tap / silent auth may be blocked by browser policies.
      }

      // Avoid GIS One Tap prompt on web until FedCM configuration is wired.
      // This prevents deprecation warnings about prompt UI status methods.
    }
  }

  @override
  void didUpdateWidget(GoogleSignInWebButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset the processing flag if isLoading changed back to false
    if (oldWidget.isLoading && !widget.isLoading) {
      _processingAuth = false;
    }
  }

  @override
  void dispose() {
    _processingAuth = false;
    _lastProcessedUid = null;
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget child;
    if (!_ready) {
      child = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      final platform = GoogleSignInPlatform.instance;
      child = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 400;
          // Match the surrounding auth buttons: take the full available width.
          // Keep GIS unscaled so logo/text match Google's sizing.
          final double buttonWidth = maxWidth;

          final config = gweb.GSIButtonConfiguration(
            type: gweb.GSIButtonType.standard,
            theme: isDark
                ? gweb.GSIButtonTheme.filledBlack
                : gweb.GSIButtonTheme.outline,
            size: gweb.GSIButtonSize.large,
            text: gweb.GSIButtonText.continueWith,
            shape: gweb.GSIButtonShape.rectangular,
            logoAlignment: gweb.GSIButtonLogoAlignment.left,
            minimumWidth: buttonWidth,
          );

          Widget? gisButton;
          try {
            if (platform is gweb.GoogleSignInPlugin) {
              gisButton = platform.renderButton(configuration: config);
            } else {
              // Capability-based fallback: some runtimes may not expose the web
              // plugin type directly even though `renderButton` is available.
              final dynamic dyn = platform;
              final dynamic rendered = dyn.renderButton(configuration: config);
              if (rendered is Widget) gisButton = rendered;
            }
          } catch (e) {
            // Never crash the auth screen due to a GIS rendering failure.
          }

          if (gisButton == null) {
            return SizedBox(width: buttonWidth);
          }

          // Use only the GIS button (no custom visible wrappers).
          // Keep the GIS button unscaled so its typography matches Google specs.
          // We still match the surrounding layout by centering it inside the
          // 56px auth row height.
          return SizedBox(
            width: buttonWidth,
            child: gisButton,
          );
        },
      );
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
