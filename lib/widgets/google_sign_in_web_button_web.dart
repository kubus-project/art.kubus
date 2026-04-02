import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as gweb;

import '../services/google_auth_service.dart';
import '../utils/design_tokens.dart';

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
  bool _initializing = false;
  bool _processingAuth = false;
  String? _lastProcessedUid;
  Object? _initError;
  Widget? _renderedButton;
  double? _renderedWidth;
  Brightness? _renderedBrightness;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init({bool force = false}) async {
    if (_initializing) return;
    if (_ready && !force) return;
    if (mounted) {
      setState(() {
        _initializing = true;
        _initError = null;
      });
    }

    try {
      await GoogleAuthService().ensureInitialized();

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
            _processingAuth = false;
          }
        },
        onError: (Object error) {
          widget.onAuthError?.call(error);
        },
      );

      if (!mounted) return;
      setState(() {
        _ready = true;
        _initializing = false;
      });
    } catch (error) {
      widget.onAuthError?.call(error);
      if (!mounted) return;
      setState(() {
        _ready = false;
        _initializing = false;
        _initError = error;
        _renderedButton = null;
        _renderedWidth = null;
        _renderedBrightness = null;
      });
    }
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

  Widget _createRenderedButton(double width, Brightness brightness) {
    final platform = GoogleSignInPlatform.instance;
    final config = gweb.GSIButtonConfiguration(
      type: gweb.GSIButtonType.standard,
      theme: brightness == Brightness.dark
          ? gweb.GSIButtonTheme.filledBlack
          : gweb.GSIButtonTheme.outline,
      size: gweb.GSIButtonSize.large,
      text: gweb.GSIButtonText.continueWith,
      shape: gweb.GSIButtonShape.rectangular,
      logoAlignment: gweb.GSIButtonLogoAlignment.left,
      minimumWidth: width,
    );

    final rendered = platform is gweb.GoogleSignInPlugin
        ? platform.renderButton(configuration: config)
        : (platform as dynamic).renderButton(configuration: config);
    if (rendered is! Widget) {
      throw StateError('Google Sign-In web button did not return a widget.');
    }

    return SizedBox(
      width: width,
      height: 56,
      child: rendered,
    );
  }

  Widget _buildRenderedHost(BoxConstraints constraints) {
    final brightness = Theme.of(context).brightness;
    final maxWidth =
        constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
    final shouldRebuild = _renderedButton == null ||
        _renderedWidth == null ||
        (_renderedWidth! - maxWidth).abs() > 1 ||
        _renderedBrightness != brightness;

    if (shouldRebuild) {
      try {
        _renderedButton = _createRenderedButton(maxWidth, brightness);
        _renderedWidth = maxWidth;
        _renderedBrightness = brightness;
        _initError = null;
      } catch (error) {
        _initError = error;
        widget.onAuthError?.call(error);
      }
    }

    if (_initError != null || _renderedButton == null) {
      return _buildRetryState();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _renderedButton!,
        if (widget.isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.colorScheme.surface.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _retryInit() async {
    await _init(force: true);
  }

  Widget _buildRetryState() {
    final scheme = widget.colorScheme;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: KubusSpacing.sm + KubusSpacing.xxs),
          Expanded(
            child: Text(
              'Google Sign-In is not ready. Retry setup.',
              style: KubusTextStyles.navMetaLabel.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: _initializing ? null : _retryInit,
            child: Text(
              _initializing ? 'Retrying…' : 'Retry',
              style: KubusTextStyles.navLabel.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return _buildRetryState();
    }

    if (!_ready) {
      return SizedBox(
        height: 56,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(KubusRadius.sm),
            border: Border.all(
              color: widget.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
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
      );
    }

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return _buildRenderedHost(constraints);
        },
      ),
    );
  }
}
