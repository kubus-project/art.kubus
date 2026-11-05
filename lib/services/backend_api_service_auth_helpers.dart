part of 'backend_api_service.dart';

Future<int> _backendApiPersistTokenFromResponse(
  BackendApiService service,
  Map<String, dynamic> body, {
  required int expectedEpoch,
}) async {
  if (expectedEpoch != service.authSessionEpoch) {
    throw StateError('Authentication session ended');
  }
  final payload = _backendApiResponsePayload(body);
  final token = payload['token'] as String? ?? body['token'] as String?;
  final refresh = payload['refreshToken'] as String? ??
      payload['refresh_token'] as String? ??
      body['refreshToken'] as String? ??
      body['refresh_token'] as String?;
  if (token != null && token.isNotEmpty) {
    return service._commitAuthSession(token,
        refreshToken: refresh, expectedEpoch: expectedEpoch);
  }
  return service.authSessionEpoch;
}

Map<String, dynamic> _backendApiResponsePayload(Map<String, dynamic> body) {
  return body['data'] is Map<String, dynamic>
      ? body['data'] as Map<String, dynamic>
      : body;
}

Map<String, dynamic>? _backendApiMapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

/// Preference keys that describe the signed-in account's email and security
/// status. They are account data: every sign-out removes them, and the next
/// sign-in repopulates them from the backend.
const List<String> secureAccountStatusPrefKeys = <String>[
  PreferenceKeys.secureAccountEmail,
  PreferenceKeys.secureAccountEmailVerifiedV1,
  PreferenceKeys.secureAccountStatusCacheV1,
  PreferenceKeys.secureAccountStatusCacheTsV1,
];

/// Whether a request captured under [sessionEpoch] belongs to a session that
/// has since ended. A null epoch means the caller did not capture one.
bool _backendApiSessionEpochStale(int? sessionEpoch) =>
    sessionEpoch != null &&
    sessionEpoch != BackendApiService()._authSessionEpoch;

Future<void> _backendApiPersistSecureAccountStatus({
  required bool hasEmail,
  required bool hasPassword,
  required String? email,
  required bool emailVerified,
  required bool emailAuthEnabled,
  int? sessionEpoch,
}) async {
  final prefs = await SharedPreferences.getInstance();
  // Checked before every write: each await can yield to a sign-out, and a
  // response for a session that has ended must not write the previous
  // account's email or status back.
  if (_backendApiSessionEpochStale(sessionEpoch)) return;
  final normalizedEmail = (email ?? '').trim();
  if (!hasEmail || normalizedEmail.isEmpty) {
    await prefs.remove(PreferenceKeys.secureAccountEmail);
    if (_backendApiSessionEpochStale(sessionEpoch)) return;
    await prefs.setBool(
      PreferenceKeys.secureAccountEmailVerifiedV1,
      false,
    );
  } else {
    await prefs.setString(PreferenceKeys.secureAccountEmail, normalizedEmail);
    if (_backendApiSessionEpochStale(sessionEpoch)) return;
    await prefs.setBool(
      PreferenceKeys.secureAccountEmailVerifiedV1,
      emailVerified,
    );
  }

  if (_backendApiSessionEpochStale(sessionEpoch)) return;
  await prefs.setString(
    PreferenceKeys.secureAccountStatusCacheV1,
    jsonEncode(<String, dynamic>{
      'hasEmail': hasEmail,
      'hasPassword': hasPassword,
      'email': hasEmail ? normalizedEmail : null,
      'emailVerified': emailVerified,
      'emailAuthEnabled': emailAuthEnabled,
    }),
  );
  if (_backendApiSessionEpochStale(sessionEpoch)) return;
  await prefs.setInt(
    PreferenceKeys.secureAccountStatusCacheTsV1,
    DateTime.now().millisecondsSinceEpoch,
  );
}

Map<String, dynamic> _backendApiNormalizeSecurityStatusMap(
  Map<String, dynamic> data,
) {
  final email = (data['email'] ?? '').toString().trim();
  final hasEmail = data['hasEmail'] == true || email.isNotEmpty;
  return <String, dynamic>{
    'hasEmail': hasEmail,
    'hasPassword': data['hasPassword'] == true,
    'email': hasEmail ? email : null,
    'emailVerified': data['emailVerified'] == true,
    'emailAuthEnabled': data['emailAuthEnabled'] != false,
  };
}

Future<Map<String, dynamic>> _backendApiGetCachedSecureAccountStatus(
  BackendApiService service,
) async {
  final prefs = await SharedPreferences.getInstance();
  final cachedRaw =
      (prefs.getString(PreferenceKeys.secureAccountStatusCacheV1) ?? '').trim();
  if (cachedRaw.isNotEmpty) {
    try {
      final decoded = jsonDecode(cachedRaw);
      if (decoded is Map<String, dynamic>) {
        return service._normalizeSecurityStatusMap(decoded);
      }
      if (decoded is Map) {
        return service._normalizeSecurityStatusMap(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      // Fall through to legacy prefs.
    }
  }

  final email =
      (prefs.getString(PreferenceKeys.secureAccountEmail) ?? '').trim();
  final emailVerified =
      prefs.getBool(PreferenceKeys.secureAccountEmailVerifiedV1) ?? false;
  return <String, dynamic>{
    'hasEmail': email.isNotEmpty,
    'hasPassword': false,
    'email': email.isNotEmpty ? email : null,
    'emailVerified': emailVerified,
    'emailAuthEnabled': true,
  };
}

Future<void> _backendApiSyncSecureAccountStatusFromResponse(
  BackendApiService service,
  Map<String, dynamic> body, {
  required bool fetchIfMissing,
  int? sessionEpoch,
}) async {
  try {
    if (!AppConfig.isFeatureEnabled('emailAuth')) return;

    final payload = service._responsePayload(body);
    final securityStatus = service._mapOrNull(payload['securityStatus']) ??
        service._mapOrNull(body['securityStatus']);
    if (securityStatus != null) {
      final normalized = service._normalizeSecurityStatusMap(securityStatus);
      await service._persistSecureAccountStatus(
        hasEmail: normalized['hasEmail'] == true,
        hasPassword: normalized['hasPassword'] == true,
        email: normalized['email']?.toString(),
        emailVerified: normalized['emailVerified'] == true,
        emailAuthEnabled: normalized['emailAuthEnabled'] != false,
        sessionEpoch: sessionEpoch,
      );
      return;
    }

    final user =
        service._mapOrNull(payload['user']) ?? service._mapOrNull(body['user']);
    if (user != null) {
      final email = (user['email'] ?? '').toString().trim();
      final hasEmail = email.isNotEmpty;
      final hasVerificationFlag = user.containsKey('emailVerified') ||
          user.containsKey('email_verified');
      if (hasEmail || hasVerificationFlag) {
        await service._persistSecureAccountStatus(
          hasEmail: hasEmail,
          hasPassword: false,
          email: hasEmail ? email : null,
          emailVerified:
              user['emailVerified'] == true || user['email_verified'] == true,
          emailAuthEnabled: true,
          sessionEpoch: sessionEpoch,
        );
        return;
      }
    }

    if (fetchIfMissing &&
        !_backendApiSessionEpochStale(sessionEpoch) &&
        (service._authToken ?? '').trim().isNotEmpty) {
      await service.syncSecureAccountStatusToPrefs();
    }
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.syncSecureAccountStatusFromResponse failed: $e',
    );
  }
}
