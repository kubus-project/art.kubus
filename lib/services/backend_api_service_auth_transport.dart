part of 'backend_api_service.dart';

class WalletAuthChallengeDto {
  const WalletAuthChallengeDto({
    required this.message,
    this.expiresAt,
  });

  final String message;
  final DateTime? expiresAt;

  factory WalletAuthChallengeDto.fromJson(Map<String, dynamic> json) {
    final data = _backendApiMapOrNull(json['data']);
    final rawMessage =
        (json['message'] ?? data?['message'] ?? '').toString().trim();
    final rawExpiresAt = json['expiresAt'] ?? data?['expiresAt'];
    DateTime? expiresAt;
    if (rawExpiresAt is num) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(rawExpiresAt.toInt());
    } else if (rawExpiresAt != null) {
      expiresAt = DateTime.tryParse(rawExpiresAt.toString());
    }
    return WalletAuthChallengeDto(
      message: rawMessage,
      expiresAt: expiresAt,
    );
  }
}

class AuthSessionPayload {
  const AuthSessionPayload({
    required this.token,
    required this.walletAddress,
    required this.authProvider,
  });

  final String token;
  final String? walletAddress;
  final String authProvider;

  factory AuthSessionPayload.fromResponse(Map<String, dynamic> body) {
    final payload = _backendApiResponsePayload(body);
    final token = (payload['token'] ?? body['token'] ?? '').toString().trim();
    final user = _backendApiMapOrNull(payload['user']) ??
        _backendApiMapOrNull(body['user']);
    final wallet = (user?['walletAddress'] ??
            user?['wallet_address'] ??
            payload['walletAddress'] ??
            payload['wallet_address'] ??
            '')
        .toString()
        .trim();
    final authProvider =
        (payload['authProvider'] ?? payload['auth_provider'] ?? '')
            .toString()
            .trim();
    return AuthSessionPayload(
      token: token,
      walletAddress: wallet.isEmpty ? null : wallet,
      authProvider: authProvider.isEmpty ? 'unknown' : authProvider,
    );
  }
}

extension BackendApiAuthTransport on BackendApiService {
  Future<WalletAuthChallengeDto> requestWalletAuthChallenge(
    String walletAddress,
  ) async {
    final normalizedWallet = walletAddress.trim();
    if (normalizedWallet.isEmpty) {
      throw ArgumentError('walletAddress cannot be empty');
    }

    const path = '/api/auth/challenge';
    final response = await _sendAuthRequestWithFailover(
      'GET',
      path,
      queryParameters: <String, String>{'walletAddress': normalizedWallet},
      includeAuth: false,
      headers: _getHeaders(includeAuth: false),
      isIdempotent: true,
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final challenge = WalletAuthChallengeDto.fromJson(decoded);
      if (challenge.message.isEmpty) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: path,
          body: response.body,
        );
      }
      return challenge;
    }

    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: path,
      body: response.body,
    );
  }

  Future<AuthSessionPayload> ensureSessionForActiveSigner({
    required String walletAddress,
    required Future<String> Function(String message) signMessage,
  }) async {
    final normalizedWallet = walletAddress.trim();
    if (normalizedWallet.isEmpty) {
      throw ArgumentError('walletAddress cannot be empty');
    }

    setPreferredWalletAddress(normalizedWallet);
    await restoreExistingSession(allowRefresh: false);
    final token = (_authToken ?? '').trim();
    final currentWallet = (getCurrentAuthWalletAddress() ?? '').trim();
    final authLevel = getCurrentAuthLevel();
    if (token.isNotEmpty &&
        WalletUtils.equals(currentWallet, normalizedWallet) &&
        authLevel == BackendAuthLevel.walletSigned) {
      return AuthSessionPayload(
        token: token,
        walletAddress: currentWallet,
        authProvider: inferSignInMethodFromClaims().name,
      );
    }

    final challenge = await requestWalletAuthChallenge(normalizedWallet);
    final signature = await signMessage(challenge.message);
    final response = await loginWithWallet(
      walletAddress: normalizedWallet,
      signature: signature,
      message: challenge.message,
    );
    return AuthSessionPayload.fromResponse(response);
  }

  Future<bool> issueDebugTokenForWallet(String walletAddress) async {
    if (!AppConfig.enableDebugIssueToken) {
      AppConfig.debugPrint(
        'BackendApiService.issueDebugTokenForWallet skipped: debug token issuance is disabled',
      );
      return false;
    }

    try {
      const path = '/api/profiles/issue-token';
      final resp = await _sendAuthRequestWithFailover(
        'POST',
        path,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'walletAddress': walletAddress.trim()}),
      );
      AppConfig.debugPrint(
        'BackendApiService.issueDebugTokenForWallet: status=${resp.statusCode}',
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = _backendApiMapOrNull(body['data']);
        final token = body['token'] as String? ?? data?['token'] as String?;
        if (token != null && token.isNotEmpty) {
          await setAuthToken(token);
          return true;
        }
      }
      return false;
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.issueDebugTokenForWallet failed: $e',
      );
      return false;
    }
  }
}
