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
    } catch (error) {
      widget.onAuthError?.call(error);
    }

    if (!mounted) return;

    _sub ??= GoogleSignIn.instance.authenticationEvents.listen(
      (GoogleSignInAuthenticationEvent event) async {
        if (event is! GoogleSignInAuthenticationEventSignIn) {
          return;
        }
        if (!mounted || widget.isLoading || _processingAuth) {
          return;
        }

        final uid = event.user.id;
        if (_lastProcessedUid == uid) {
          return;
        }

        try {
          _processingAuth = true;
          final result = GoogleAuthService().resultFromAccount(event.user);
          await widget.onAuthResult(result);
          _lastProcessedUid = uid;
        } catch (error) {
          _lastProcessedUid = null;
          widget.onAuthError?.call(error);
        } finally {
          if (mounted) {
            _processingAuth = false;
          }
        }
      },
      onError: (Object error) {
        widget.onAuthError?.call(error);
      },
    );

    if (AppConfig.isFeatureEnabled('googleOneTapWeb')) {
      try {
        final account =
            await GoogleSignIn.instance.attemptLightweightAuthentication();
        if (mounted &&
            account != null &&
            !widget.isLoading &&
            !_processingAuth) {
          final uid = account.id;
          if (_lastProcessedUid != uid) {
            _processingAuth = true;
            try {
              final result = GoogleAuthService().resultFromAccount(account);
              await widget.onAuthResult(result);
              _lastProcessedUid = uid;
            } catch (error) {
              _lastProcessedUid = null;
              widget.onAuthError?.call(error);
            } finally {
              if (mounted) {
                _processingAuth = false;
              }
            }
          }
        }
      } catch (_) {
        // Silent auth on web is best-effort only.
      }
    }

    if (!mounted) return;
    setState(() {
      _ready = true;
    });
  }

  @override
  void didUpdateWidget(GoogleSignInWebButton oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final platform = GoogleSignInPlatform.instance;

    const reservedHeight = 56.0;
    return SizedBox(
      height: reservedHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: _ready ? 0 : 1,
              child: IgnorePointer(
                ignoring: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.colorScheme.surface.withValues(
                      alpha: isDark ? 0.9 : 0.96,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
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
            ),
          ),
          if (_ready)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double maxWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 400.0;
                  final config = gweb.GSIButtonConfiguration(
                    type: gweb.GSIButtonType.standard,
                    theme: isDark
                        ? gweb.GSIButtonTheme.filledBlack
                        : gweb.GSIButtonTheme.outline,
                    size: gweb.GSIButtonSize.large,
                    text: gweb.GSIButtonText.continueWith,
                    shape: gweb.GSIButtonShape.rectangular,
                    logoAlignment: gweb.GSIButtonLogoAlignment.left,
                    minimumWidth: maxWidth,
                  );

                  Widget? gisButton;
                  try {
                    if (platform is gweb.GoogleSignInPlugin) {
                      gisButton = platform.renderButton(configuration: config);
                    } else {
                      final dynamic dyn = platform;
                      final dynamic rendered =
                          dyn.renderButton(configuration: config);
                      if (rendered is Widget) {
                        gisButton = rendered;
                      }
                    }
                  } catch (_) {}

                  if (gisButton == null) {
                    return const SizedBox.shrink();
                  }

                  return AbsorbPointer(
                    absorbing: widget.isLoading,
                    child: SizedBox(
                      width: maxWidth,
                      child: gisButton,
                    ),
                  );
                },
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
