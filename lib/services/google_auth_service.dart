import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_keys.dart';
import '../config/config.dart';

/// Lightweight wrapper around GoogleSignIn to centralize clientId usage and
/// return a stable payload for backend auth.
class GoogleAuthResult {
  GoogleAuthResult({
    required this.idToken,
    required this.email,
    required this.displayName,
  });

  final String idToken;
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
    // On Android, Google recommends passing the Web client ID as serverClientId for OIDC.
    final serverId = kIsWeb ? null : (webId.isNotEmpty ? webId : androidId);

    await GoogleSignIn.instance.initialize(
      clientId: selectedClientId.isNotEmpty ? selectedClientId : null,
      serverClientId: serverId != null && serverId.isNotEmpty ? serverId : null,
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

      // Web: try lightweight (FedCM/One Tap) flow first.
      if (kIsWeb) {
        try {
          final Future<GoogleSignInAccount?>? maybeFuture =
              GoogleSignIn.instance.attemptLightweightAuthentication();
          if (maybeFuture != null) {
            account = await maybeFuture;
          }
        } catch (e) {
          debugPrint('GoogleAuthService: attemptLightweightAuthentication failed on web: $e');
        }
      }

      // Interactive auth (popup/button) as fallback.
      if (account == null) {
        if (!GoogleSignIn.instance.supportsAuthenticate()) {
          throw Exception('Google Sign-In authenticate() not supported on this platform.');
        }
        try {
          account = await GoogleSignIn.instance.authenticate();
        } on GoogleSignInException catch (e) {
          // User canceled or UI not available: surface a benign null so UI can retry.
          if (e.code == GoogleSignInExceptionCode.canceled ||
              e.code == GoogleSignInExceptionCode.interrupted ||
              e.code == GoogleSignInExceptionCode.uiUnavailable) {
            debugPrint('GoogleAuthService: authenticate canceled/interrupted (${e.code}), returning null');
            return null;
          }
          rethrow;
        }
      }
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        final hasClientId = (kIsWeb ? ApiKeys.googleWebClientId : ApiKeys.googleClientId).trim().isNotEmpty;
        final hint = hasClientId
            ? 'Verify OAuth consent and platform config for Google Sign-In.'
            : 'Add ApiKeys.googleClientId (Web client ID) to enable Google token issuance.';
        throw Exception('Google returned an empty token. $hint');
      }
      return GoogleAuthResult(
        idToken: idToken,
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
