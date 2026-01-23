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

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final webId = ApiKeys.googleWebClientId.trim();
    final androidId = ApiKeys.googleClientId.trim();
    final selectedClientId = kIsWeb && webId.isNotEmpty ? webId : androidId;
    
    // For Authorization Code Flow, we MUST pass the Web Client ID as serverClientId.
    final serverId = webId.isNotEmpty ? webId : (kIsWeb ? null : androidId);

    // GoogleSignIn 7.x: Scopes are not passed in initialize.
    await GoogleSignIn.instance.initialize(
      clientId: selectedClientId.isNotEmpty ? selectedClientId : null,
      serverClientId: serverId,
    );
    _initialized = true;
  }

  Future<GoogleAuthResult?> signIn() async {
    if (!AppConfig.enableGoogleAuth) {
      throw Exception('Google sign-in is disabled by feature flag.');
    }

    await _ensureInitialized();
    try {
      GoogleSignInAccount? account;

      // 1. Try silent/lightweight auth
      try {
        account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      } catch (e) {
         debugPrint('GoogleAuthService: attemptLightweightAuthentication failed: $e');
      }

      // 2. If no user, trigger interactive flow
      if (account == null) {
          try {
             account = await GoogleSignIn.instance.authenticate();
          } catch (e) {
             debugPrint('GoogleAuthService: authenticate failed: $e');
             return null;
          }
      }

      // 7.x: Access authentication synchronously
      final auth = account.authentication;
      final idToken = auth.idToken;
      
      // In 7.x, try to get serverAuthCode from authentication object or cast dynamically if needed
      String? serverAuthCode;
      try {
         // Try to read it from auth if it exists there (dynamic dispatch for safety during upgrade)
         serverAuthCode = (auth as dynamic).serverAuthCode as String?;
      } catch (_) {}

      // Fallback: If no serverAuthCode found on auth object, check the account object 
      // just in case (though error logs said it was missing).
      if (serverAuthCode == null || serverAuthCode.isEmpty) {
         try {
           serverAuthCode = (account as dynamic).serverAuthCode as String?;
         } catch (_) {}
      }

      if ((idToken == null || idToken.isEmpty) && (serverAuthCode == null || serverAuthCode.isEmpty)) {
         throw Exception('Google sign-in failed: No ID token or Server Auth Code returned.');
      }

      return GoogleAuthResult(
        idToken: idToken ?? '',
        serverAuthCode: serverAuthCode,
        email: account.email,
        displayName: account.displayName,
      );
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Google sign-in failed: $e');
    }
  }
}
