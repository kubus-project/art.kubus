import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import '../services/google_auth_service.dart';
import '../utils/design_tokens.dart';

/// Web Google Sign-In button rendered by official GIS SDK UI.
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
          return const SizedBox(height: 42);
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 56);
        }

        return SizedBox(
          height: 56,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final brightness = widget.colorScheme.brightness;
              final maxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 400.0;
              final minWidth = maxWidth.clamp(260.0, 400.0);
              final shouldRecreateButton = _cachedOfficialButton == null ||
                  _cachedBrightness != brightness ||
                  _cachedMinWidth == null ||
                  (_cachedMinWidth! - minWidth).abs() > 1;

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
                    minimumWidth: minWidth,
                  ),
                );
                _cachedBrightness = brightness;
                _cachedMinWidth = minWidth;
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  AbsorbPointer(
                    absorbing: widget.isLoading,
                    child: _cachedOfficialButton!,
                  ),
                  if (widget.isLoading)
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: widget.colorScheme.surface.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(KubusRadius.sm),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
