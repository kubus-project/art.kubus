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

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    final webId = ApiKeys.googleWebClientId.trim();
    final androidId = ApiKeys.googleClientId.trim();
    final String? selectedClientId =
        kIsWeb
            ? (webId.isNotEmpty ? webId : null)
            : (androidId.isNotEmpty ? androidId : null);

    // Web does not support serverClientId in google_sign_in_web.
    // On mobile, if server auth code is ever required, serverClientId should
    // be the Web OAuth client id.
    final String? serverClientId = (!kIsWeb && webId.isNotEmpty) ? webId : null;

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

  /// Sign in with Google. Supports both mobile and web.
  /// - Mobile (iOS/Android): Uses authenticate() / attemptLightweightAuthentication().
  /// - Web: Interactive authentication is not supported via this API.
  ///   On web, use a GIS-rendered button and listen to
  ///   [GoogleSignIn.instance.authenticationEvents].
  Future<GoogleAuthResult?> signIn() async {
    if (!AppConfig.enableGoogleAuth) {
      throw Exception('Google sign-in is disabled by feature flag.');
    }

    await ensureInitialized();

    if (kIsWeb) {
      throw UnsupportedError(
        'GoogleAuthService.signIn is not supported on the web. '
        'Use the google_sign_in_web renderButton UI and listen to '
        'GoogleSignIn.instance.authenticationEvents instead.',
      );
    }

    try {
      GoogleSignInAccount? account;

      // Mobile flow: Try lightweight auth first (may return null or throw).
      try {
        final Future<GoogleSignInAccount?>? attempt =
            GoogleSignIn.instance.attemptLightweightAuthentication();
        if (attempt != null) {
          account = await attempt;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'GoogleAuthService: attemptLightweightAuthentication failed: $e',
          );
        }
      }

      // If no user, trigger interactive authentication.
      if (account == null) {
        try {
          account = await GoogleSignIn.instance.authenticate();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('GoogleAuthService: authenticate failed: $e');
          }
          return null;
        }
      }

      return resultFromAccount(account);
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
