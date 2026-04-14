part of 'backend_api_service.dart';

Future<Map<String, dynamic>> _backendApiRegisterWallet(
  BackendApiService service, {
  required String walletAddress,
  String? username,
}) async {
  try {
    service.setPreferredWalletAddress(walletAddress);
    final body = {
      'walletAddress': walletAddress,
      if (username != null) 'username': username,
    };
    const path = '/api/auth/register';
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    }
    throw Exception('Register failed: ${response.statusCode} ${response.body}');
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.registerWallet failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiLoginWithWallet(
  BackendApiService service, {
  required String walletAddress,
  required String signature,
  required String message,
}) async {
  try {
    const path = '/api/auth/login';
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
      body: jsonEncode({
        'walletAddress': walletAddress,
        'signature': signature,
        'message': message,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await service._persistTokenFromResponse(data);
      await service.syncSecureAccountStatusFromResponse(data);
      await service.setLastSignInMethod(AuthSignInMethod.wallet);
      return data;
    }
    throw Exception('Login failed: ${response.statusCode} ${response.body}');
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.loginWithWallet failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiRegisterWithEmail(
  BackendApiService service, {
  required String email,
  required String password,
  String? username,
  String? displayName,
  String? walletAddress,
  bool includeAuth = false,
}) async {
  try {
    const path = '/api/auth/register/email';
    final uri = service._buildApiUri(service.baseUrl, path);
    final key = service._rateLimitKey('POST', uri);
    if (service._isRateLimited(key)) {
      throw Exception(service._rateLimitMessage(key));
    }
    const profileDisplayNameMaxLength = 100;
    final normalizedDisplayName =
        displayName?.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sanitizedDisplayName = (normalizedDisplayName == null ||
            normalizedDisplayName.isEmpty)
        ? null
        : (normalizedDisplayName.length > profileDisplayNameMaxLength
            ? normalizedDisplayName.substring(0, profileDisplayNameMaxLength)
            : normalizedDisplayName);
    final body = {
      'email': email,
      'password': password,
      if (username != null && username.isNotEmpty) 'username': username,
      if (sanitizedDisplayName != null) 'displayName': sanitizedDisplayName,
      if (walletAddress != null && walletAddress.isNotEmpty)
        'walletAddress': walletAddress,
    };
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: includeAuth,
      headers: service._getHeaders(includeAuth: includeAuth),
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) {
      await service._persistTokenFromResponse(data);
      await service.syncSecureAccountStatusFromResponse(data);
      await service.setLastSignInMethod(AuthSignInMethod.email);
      return data;
    }
    if (response.statusCode == 429) {
      service._markRateLimited(key, response, defaultWindowMs: 900000);
      throw Exception(service._rateLimitMessage(key));
    }
    if (response.statusCode == 404) {
      throw Exception(
        'Email registration endpoint not available on the backend (received 404). Ensure the server is updated and ENABLE_EMAIL_AUTH=true.',
      );
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.registerWithEmail failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiLoginWithEmail(
  BackendApiService service, {
  required String email,
  required String password,
}) async {
  try {
    const path = '/api/auth/login/email';
    final uri = service._buildApiUri(service.baseUrl, path);
    final key = service._rateLimitKey('POST', uri);
    if (service._isRateLimited(key)) {
      throw Exception(service._rateLimitMessage(key));
    }
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      await service._persistTokenFromResponse(data);
      await service.syncSecureAccountStatusFromResponse(data);
      await service.setLastSignInMethod(AuthSignInMethod.email);
      return data;
    }
    if (response.statusCode == 429) {
      service._markRateLimited(key, response, defaultWindowMs: 900000);
      throw Exception(service._rateLimitMessage(key));
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.loginWithEmail failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiResendEmailVerificationRequest(
  BackendApiService service, {
  required String email,
  required bool includeAuth,
}) async {
  try {
    const path = '/api/auth/resend-verification';
    final uri = service._buildApiUri(service.baseUrl, path);
    final key = service._rateLimitKey('POST', uri);
    if (service._isRateLimited(key)) {
      throw Exception(service._rateLimitMessage(key));
    }
    if (includeAuth) {
      await service.loadAuthToken();
      if ((service._authToken ?? '').trim().isEmpty) {
        throw Exception('Authentication required');
      }
    }
    final normalizedEmail = email.trim();
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: includeAuth,
      headers: service._getHeaders(includeAuth: includeAuth),
      body: normalizedEmail.isEmpty
          ? jsonEncode(<String, dynamic>{})
          : jsonEncode(<String, dynamic>{'email': normalizedEmail}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await service.syncSecureAccountStatusFromResponse(
        data,
        fetchIfMissing: false,
      );
      return data;
    }
    if (response.statusCode == 429) {
      service._markRateLimited(key, response, defaultWindowMs: 900000);
      throw Exception(service._rateLimitMessage(key));
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.resendEmailVerification failed: $e',
    );
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiGetEmailVerificationStatus(
  BackendApiService service, {
  required String email,
}) async {
  try {
    const path = '/api/auth/email-status';
    final response = await service._sendAuthRequestWithFailover(
      'GET',
      path,
      queryParameters: {'email': email.trim()},
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
    );
    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      return {'verified': data['verified'] == true};
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.getEmailVerificationStatus failed: $e',
    );
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiGetAccountSecurityStatus(
  BackendApiService service,
) async {
  try {
    const path = '/api/auth/account-security-status';
    final response = await service._sendAuthRequestWithFailover(
      'GET',
      path,
      includeAuth: true,
      headers: service._getHeaders(),
    );
    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      return service._normalizeSecurityStatusMap(data);
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.getAccountSecurityStatus failed: $e',
    );
    rethrow;
  }
}

Future<void> _backendApiSyncSecureAccountStatusToPrefs(
  BackendApiService service,
) async {
  try {
    if (!AppConfig.isFeatureEnabled('emailAuth')) return;
    final status = service._normalizeSecurityStatusMap(
      await service.getAccountSecurityStatus(),
    );

    await service._persistSecureAccountStatus(
      hasEmail: status['hasEmail'] == true,
      hasPassword: status['hasPassword'] == true,
      email: status['email']?.toString(),
      emailVerified: status['emailVerified'] == true,
      emailAuthEnabled: status['emailAuthEnabled'] != false,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.syncSecureAccountStatusToPrefs failed: $e',
    );
  }
}

Future<Map<String, dynamic>> _backendApiAddPasswordToCurrentAccount(
  BackendApiService service, {
  required String password,
}) async {
  try {
    const path = '/api/auth/account-security/password';
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: true,
      headers: service._getHeaders(),
      body: jsonEncode(<String, dynamic>{'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      await service.syncSecureAccountStatusFromResponse(data);
      return data;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.addPasswordToCurrentAccount failed: $e',
    );
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiVerifyEmail(
  BackendApiService service, {
  required String token,
}) async {
  try {
    const path = '/api/auth/verify-email';
    final uri = service._buildApiUri(service.baseUrl, path);
    final key = service._rateLimitKey('POST', uri);
    if (service._isRateLimited(key)) {
      throw Exception(service._rateLimitMessage(key));
    }
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
      body: jsonEncode({'token': token}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await service.syncSecureAccountStatusFromResponse(data);
      return data;
    }
    if (response.statusCode == 429) {
      service._markRateLimited(key, response, defaultWindowMs: 900000);
      throw Exception(service._rateLimitMessage(key));
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.verifyEmail failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiForgotPassword(
  BackendApiService service, {
  required String email,
}) async {
  try {
    const path = '/api/auth/forgot-password';
    final uri = service._buildApiUri(service.baseUrl, path);
    final key = service._rateLimitKey('POST', uri);
    if (service._isRateLimited(key)) {
      throw Exception(service._rateLimitMessage(key));
    }
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 429) {
      service._markRateLimited(key, response, defaultWindowMs: 900000);
      throw Exception(service._rateLimitMessage(key));
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.forgotPassword failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiResetPassword(
  BackendApiService service, {
  required String token,
  required String newPassword,
}) async {
  try {
    const path = '/api/auth/reset-password';
    final uri = service._buildApiUri(service.baseUrl, path);
    final key = service._rateLimitKey('POST', uri);
    if (service._isRateLimited(key)) {
      throw Exception(service._rateLimitMessage(key));
    }
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 429) {
      service._markRateLimited(key, response, defaultWindowMs: 900000);
      throw Exception(service._rateLimitMessage(key));
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.resetPassword failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiLoginWithGoogle(
  BackendApiService service, {
  String? idToken,
  String? code,
  String? email,
  String? username,
  String? walletAddress,
  String? displayName,
}) async {
  try {
    if ((code == null || code.isEmpty) &&
        (idToken == null || idToken.isEmpty)) {
      throw Exception(
        'Either auth code or idToken is required for Google login',
      );
    }

    final isCodeFlow = code != null && code.isNotEmpty;
    final endpoint =
        isCodeFlow ? '/api/auth/login/google/code' : '/api/auth/login/google';
    final uri = service._buildApiUri(service.baseUrl, endpoint);
    final key = service._rateLimitKey('POST', uri);

    if (service._isRateLimited(key)) {
      throw Exception(service._rateLimitMessage(key));
    }

    final body = {
      if (isCodeFlow) 'code': code,
      if (!isCodeFlow && idToken != null) 'idToken': idToken,
      if (email != null && email.isNotEmpty) 'email': email,
      if (username != null && username.isNotEmpty) 'username': username,
      if (walletAddress != null && walletAddress.isNotEmpty)
        'walletAddress': walletAddress,
      if (displayName != null && displayName.isNotEmpty) 'displayName': displayName,
    };

    final response = await service._sendAuthRequestWithFailover(
      'POST',
      endpoint,
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) {
      await service._persistTokenFromResponse(data);
      await service.syncSecureAccountStatusFromResponse(data);
      await service.setLastSignInMethod(AuthSignInMethod.google);
      return data;
    }
    if (response.statusCode == 429) {
      service._markRateLimited(key, response, defaultWindowMs: 900000);
      try {
        final prefs = await SharedPreferences.getInstance();
        final resetAt = service._rateLimitResets[key];
        if (resetAt != null) {
          await prefs.setInt(
            'rate_limit_auth_google_until',
            resetAt.millisecondsSinceEpoch,
          );
        }
      } catch (_) {}
      throw Exception(service._rateLimitMessage(key));
    }
    if (response.statusCode == 404) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.loginWithGoogle failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiBindAuthenticatedWallet(
  BackendApiService service,
  String walletAddress,
) async {
  try {
    const path = '/api/auth/bind-wallet';
    final response = await service._sendAuthRequestWithFailover(
      'POST',
      path,
      includeAuth: true,
      headers: service._getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{'walletAddress': walletAddress}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) {
      await service._persistTokenFromResponse(data);
      await service.syncSecureAccountStatusFromResponse(data);
      return data;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.bindAuthenticatedWallet failed: $e',
    );
    rethrow;
  }
}

Future<EncryptedWalletBackupDefinition?>
    _backendApiGetEncryptedWalletBackup(
  BackendApiService service, {
  String? walletAddress,
}) async {
  try {
    final normalizedWallet = (walletAddress ?? '').trim();
    final uri = Uri.parse('${service.baseUrl}/api/wallet-backup').replace(
      queryParameters: normalizedWallet.isEmpty
          ? null
          : <String, String>{'walletAddress': normalizedWallet},
    );
    final response = await service._get(
      uri,
      includeAuth: true,
      headers: service._getHeaders(includeAuth: true),
    );
    if (response.statusCode == 200) {
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      return EncryptedWalletBackupDefinition.fromJson(data);
    }
    if (response.statusCode == 404) {
      return null;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.getEncryptedWalletBackup failed: $e',
    );
    rethrow;
  }
}

Future<EncryptedWalletBackupDefinition>
    _backendApiPutEncryptedWalletBackup(
  BackendApiService service,
  EncryptedWalletBackupDefinition definition,
) async {
  try {
    final uri = Uri.parse('${service.baseUrl}/api/wallet-backup');
    final response = await service._put(
      uri,
      includeAuth: true,
      headers: service._getHeaders(includeAuth: true),
      body: jsonEncode(definition.toApiPayload()),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      return EncryptedWalletBackupDefinition.fromJson(data);
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.putEncryptedWalletBackup failed: $e',
    );
    rethrow;
  }
}

Future<void> _backendApiDeleteEncryptedWalletBackup(
  BackendApiService service, {
  String? walletAddress,
}) async {
  try {
    final normalizedWallet = (walletAddress ?? '').trim();
    final uri = Uri.parse('${service.baseUrl}/api/wallet-backup').replace(
      queryParameters: normalizedWallet.isEmpty
          ? null
          : <String, String>{'walletAddress': normalizedWallet},
    );
    final response = await service._delete(
      uri,
      includeAuth: true,
      headers: service._getHeaders(includeAuth: true),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.deleteEncryptedWalletBackup failed: $e',
    );
    rethrow;
  }
}

Future<Map<String, dynamic>>
    _backendApiGetWalletBackupPasskeyRegistrationOptions(
  BackendApiService service, {
  required String walletAddress,
  String? nickname,
}) async {
  try {
    final uri =
        Uri.parse('${service.baseUrl}/api/wallet-backup/passkey/register/options');
    final response = await service._post(
      uri,
      includeAuth: true,
      headers: service._getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'walletAddress': walletAddress.trim(),
        if ((nickname ?? '').trim().isNotEmpty) 'nickname': nickname!.trim(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      return raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.getWalletBackupPasskeyRegistrationOptions failed: $e',
    );
    rethrow;
  }
}

Future<Map<String, dynamic>>
    _backendApiVerifyWalletBackupPasskeyRegistration(
  BackendApiService service, {
  required String walletAddress,
  required Map<String, dynamic> responsePayload,
  String? nickname,
}) async {
  try {
    final uri =
        Uri.parse('${service.baseUrl}/api/wallet-backup/passkey/register/verify');
    final response = await service._post(
      uri,
      includeAuth: true,
      headers: service._getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'walletAddress': walletAddress.trim(),
        if ((nickname ?? '').trim().isNotEmpty) 'nickname': nickname!.trim(),
        'response': responsePayload,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      return raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.verifyWalletBackupPasskeyRegistration failed: $e',
    );
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiGetWalletBackupPasskeyAuthOptions(
  BackendApiService service, {
  required String walletAddress,
}) async {
  try {
    final uri = Uri.parse('${service.baseUrl}/api/wallet-backup/passkey/auth/options');
    final response = await service._post(
      uri,
      includeAuth: true,
      headers: service._getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'walletAddress': walletAddress.trim(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      return raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.getWalletBackupPasskeyAuthOptions failed: $e',
    );
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiVerifyWalletBackupPasskeyAuth(
  BackendApiService service, {
  required String walletAddress,
  required Map<String, dynamic> responsePayload,
}) async {
  try {
    final uri = Uri.parse('${service.baseUrl}/api/wallet-backup/passkey/auth/verify');
    final response = await service._post(
      uri,
      includeAuth: true,
      headers: service._getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'walletAddress': walletAddress.trim(),
        'response': responsePayload,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final raw = jsonDecode(response.body) as Map<String, dynamic>;
      return raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.verifyWalletBackupPasskeyAuth failed: $e',
    );
    rethrow;
  }
}

Future<void> _backendApiEmitWalletBackupEvent(
  BackendApiService service, {
  required String walletAddress,
  required String eventType,
}) async {
  try {
    final uri = Uri.parse('${service.baseUrl}/api/wallet-backup/events');
    final response = await service._post(
      uri,
      includeAuth: true,
      headers: service._getHeaders(includeAuth: true),
      body: jsonEncode(<String, dynamic>{
        'walletAddress': walletAddress.trim(),
        'eventType': eventType.trim(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  } catch (e) {
    AppConfig.debugPrint(
      'BackendApiService.emitWalletBackupEvent failed: $e',
    );
    rethrow;
  }
}
