import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import '../l10n/app_localizations.dart';
import '../services/google_auth_service.dart';
import 'google_sign_in_button.dart';
import 'kubus_auth_method_button.dart';

/// Web Google Sign-In button.
///
/// The google_sign_in_web plugin does not support programmatic
/// [GoogleSignIn.authenticate] on web; its platform implementation requires
/// [web.renderButton] for user-initiated sign-in. To keep that supported path
/// while matching the Kubus auth UI, the SDK-rendered button is kept as an
/// invisible hit target and a pointer-transparent Kubus button is rendered
/// above it.
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
  static Future<void>? _sharedInitializeFuture;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventsSub;
  late final Future<void> _initializeFuture;
  bool _handlingAuthEvent = false;
  bool _reportedInitError = false;
  Widget? _cachedOfficialButton;
  Brightness? _cachedBrightness;
  double? _cachedMinWidth;

  @override
  void initState() {
    super.initState();
    _initializeFuture =
        _sharedInitializeFuture ??= GoogleAuthService().ensureInitialized();
    _authEventsSub = GoogleSignIn.instance.authenticationEvents.listen(
      (event) async {
        if (event is! GoogleSignInAuthenticationEventSignIn) {
          return;
        }
        if (_handlingAuthEvent) {
          return;
        }

        _handlingAuthEvent = true;
        try {
          final result = GoogleAuthService().resultFromAccount(event.user);
          await widget.onAuthResult(result);
        } catch (error) {
          widget.onAuthError?.call(error);
        } finally {
          _handlingAuthEvent = false;
        }
      },
      onError: (Object error) {
        widget.onAuthError?.call(error);
      },
    );
  }

  @override
  void dispose() {
    unawaited(_authEventsSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (!_reportedInitError) {
            _reportedInitError = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              widget.onAuthError?.call(snapshot.error!);
            });
          }
          return KubusAuthMethodButtonSkeleton(
            label: l10n.authContinueWithGoogleLabel,
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return KubusAuthMethodButtonSkeleton(
            label: l10n.authContinueWithGoogleLabel,
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final brightness = widget.colorScheme.brightness;
            final maxWidth =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
            final officialWidth =
                (maxWidth < 240.0 ? maxWidth : maxWidth.clamp(240.0, 400.0))
                    .toDouble();
            final shouldRecreateButton = _cachedOfficialButton == null ||
                _cachedBrightness != brightness ||
                _cachedMinWidth == null ||
                (_cachedMinWidth! - officialWidth).abs() > 1;

            if (shouldRecreateButton) {
              _cachedOfficialButton = web.renderButton(
                configuration: web.GSIButtonConfiguration(
                  type: web.GSIButtonType.standard,
                  size: web.GSIButtonSize.large,
                  text: web.GSIButtonText.continueWith,
                  shape: web.GSIButtonShape.rectangular,
                  theme: brightness == Brightness.dark
                      ? web.GSIButtonTheme.filledBlack
                      : web.GSIButtonTheme.outline,
                  logoAlignment: web.GSIButtonLogoAlignment.left,
                  minimumWidth: officialWidth,
                ),
              );
              _cachedBrightness = brightness;
              _cachedMinWidth = officialWidth;
            }

            return SizedBox(
              height: 56,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AbsorbPointer(
                    absorbing: widget.isLoading,
                    child: Center(
                      child: SizedBox(
                        width: officialWidth,
                        height: 44,
                        child: Opacity(
                          opacity: 0,
                          alwaysIncludeSemantics: false,
                          child: _cachedOfficialButton!,
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: GoogleSignInButton(
                      key: const ValueKey<String>(
                        'kubus-google-web-visible-button',
                      ),
                      onPressed: () async {},
                      isLoading: widget.isLoading,
                      colorScheme: widget.colorScheme,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
