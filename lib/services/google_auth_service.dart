import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_keys.dart';
import '../config/config.dart';

/// Lightweight wrapper around GoogleSignIn to centralize clientId usage and
/// return a stable payload for backend auth.
class GoogleAuthResult {
  GoogleAuthResult({
    required this.idToken,
    this.serverAuthCode,
    required this.email,
    required this.displayName,
  });

  final String idToken;
  final String? serverAuthCode;
  final String email;
  final String? displayName;
}

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService _instance = GoogleAuthService._();
  factory GoogleAuthService() => _instance;

  bool _initialized = false;

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _selectedClientId() {
    if (kIsWeb) {
      return _trimmedOrNull(ApiKeys.googleWebClientId);
    }
    if (_isApplePlatform) {
      return _trimmedOrNull(ApiKeys.googleIosClientId) ??
          _trimmedOrNull(ApiKeys.googleClientId);
    }
    if (_isAndroidPlatform) {
      return null;
    }
    return _trimmedOrNull(ApiKeys.googleClientId);
  }

  String? _selectedServerClientId() {
    if (kIsWeb) {
      return null;
    }
    return _trimmedOrNull(ApiKeys.googleWebClientId);
  }

  String? configurationIssue() {
    if (kIsWeb) {
      return _selectedClientId() == null
          ? 'Missing Google web client ID.'
          : null;
    }

    if (_selectedServerClientId() == null) {
      return 'Missing Google web/server client ID.';
    }

    if (_isApplePlatform && _selectedClientId() == null) {
      return 'Missing Google iOS client ID.';
    }

    return null;
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final selectedClientId = _selectedClientId();
    final serverClientId = _selectedServerClientId();

    // GoogleSignIn 7.x: Initialize with clientId and serverClientId
    // Note: GoogleSignIn.instance is a singleton, configure before use
    try {
      await GoogleSignIn.instance.initialize(
        clientId: selectedClientId,
        serverClientId: serverClientId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleAuthService: Failed to initialize: $e');
      }
    }
    _initialized = true;
  }

  GoogleAuthResult resultFromAccount(GoogleSignInAccount account) {
    final auth = account.authentication;
    final idToken = auth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google sign-in failed: No ID token returned.');
    }

    return GoogleAuthResult(
      idToken: idToken,
      // google_sign_in 7.x no longer provides serverAuthCode via the auth
      // object. This remains for backward compatibility with backend calls.
      serverAuthCode: null,
      email: account.email,
      displayName: account.displayName,
    );
  }

  /// Starts a single interactive Google sign-in flow and returns the result.
  ///
  /// This intentionally avoids silent/lightweight auth attempts here because
  /// those flows are easy to duplicate from multiple entry surfaces and can
  /// lead to unstable UX on mobile.
  Future<GoogleAuthResult?> signIn() async {
    if (!AppConfig.enableGoogleAuth) {
      throw Exception('Google sign-in is disabled by feature flag.');
    }

    final configurationError = configurationIssue();
    if (configurationError != null) {
      throw Exception(configurationError);
    }

    await ensureInitialized();

    try {
      try {
        final account = await GoogleSignIn.instance.authenticate();
        return resultFromAccount(account);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('GoogleAuthService: authenticate failed: $e');
        }
        return null;
      }
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }

  /// Sign out the current user.
  /// - Mobile: Removes account from the device
  /// - Web: Clears the session (user can still be signed in to Google account in browser)
  Future<void> signOut() async {
    if (!_initialized) {
      return;
    }
    
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleAuthService.signOut: $e');
      }
    }
  }

  /// Disconnect the app's access to the user's Google account.
  /// - Mobile: Removes account and disconnects app
  /// - Web: Disconnects app access (user remains signed in to Google)
  Future<void> disconnect() async {
    if (!_initialized) {
      return;
    }
    
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GoogleAuthService.disconnect: $e');
      }
    }
  }
}
