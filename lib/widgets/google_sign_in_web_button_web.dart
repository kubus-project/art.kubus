import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as gweb;

import '../services/google_auth_service.dart';
import 'google_sign_in_button.dart';

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

  Future<void> _handleFallbackPress() async {
    if (widget.isLoading || _processingAuth) return;
    try {
      _processingAuth = true;
      final result = await GoogleAuthService().signIn();
      if (result == null) {
        throw StateError('Google sign-in cancelled or unavailable.');
      }
      await widget.onAuthResult(result);
      final email = result.email.trim().toLowerCase();
      _lastProcessedUid = email.isNotEmpty ? email : null;
    } catch (error) {
      _lastProcessedUid = null;
      widget.onAuthError?.call(error);
    } finally {
      _processingAuth = false;
    }
  }

  Widget _buildRenderedButton(BoxConstraints constraints) {
    final platform = GoogleSignInPlatform.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxWidth =
        constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;

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

    try {
      final rendered = platform is gweb.GoogleSignInPlugin
          ? platform.renderButton(configuration: config)
          : (platform as dynamic).renderButton(configuration: config);
      if (rendered is Widget) {
        return SizedBox(
          width: maxWidth,
          height: 56,
          child: rendered,
        );
      }
    } catch (_) {
      // Fall back to the interactive Flutter button below.
    }

    return GoogleSignInButton(
      onPressed: _handleFallbackPress,
      isLoading: widget.isLoading || _processingAuth,
      colorScheme: widget.colorScheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || widget.isLoading) {
      return GoogleSignInButton(
        onPressed: _handleFallbackPress,
        isLoading: widget.isLoading || (!_ready && _processingAuth),
        colorScheme: widget.colorScheme,
      );
    }

    return SizedBox(
      height: 56,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return _buildRenderedButton(constraints);
        },
      ),
    );
  }
}
