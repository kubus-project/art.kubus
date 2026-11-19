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

  /// [expectedEpoch] is the auth session the caller started under. The wallet
  /// signature can take seconds, and a session that ends meanwhile must not
  /// receive this wallet's token.
  ///
  /// A caller that passes none is bound to the session current at entry: the
  /// epoch AND the account that session belongs to. When the signature returns,
  /// the commit is refused if the live session belongs to another account or
  /// is logged out. A change of credentials within the same account (link,
  /// refresh, a non-wallet sign-in token swap) is not an ended session, and a
  /// session that does not exist yet (guest, or the account this very call
  /// creates) is not one either.
  Future<AuthSessionPayload> ensureSessionForActiveSigner({
    required String walletAddress,
    required Future<String> Function(String message) signMessage,
    int? expectedEpoch,
  }) async {
    final normalizedWallet = walletAddress.trim();
    if (normalizedWallet.isEmpty) {
      throw ArgumentError('walletAddress cannot be empty');
    }
    final sessionEpoch = expectedEpoch ?? authSessionEpoch;
    // Captured with the epoch: the epoch is current here (checked below), so
    // this is the account the operation started under.
    final entryAccountKey = pendingAuthAccountKey;

    // A wallet-signed session for this very wallet is never the wrong
    // account's: when another caller committed it while this one waited, it is
    // the result this caller wanted, and nothing more is committed.
    AuthSessionPayload? liveSessionForWallet() {
      final token = (_authToken ?? '').trim();
      final currentWallet = (getCurrentAuthWalletAddress() ?? '').trim();
      if (token.isNotEmpty &&
          !hasPendingAccountSwitch &&
          WalletUtils.equals(currentWallet, normalizedWallet) &&
          getCurrentAuthLevel() == BackendAuthLevel.walletSigned) {
        return AuthSessionPayload(
          token: token,
          walletAddress: currentWallet,
          authProvider: inferSignInMethodFromClaims().name,
        );
      }
      return null;
    }

    // The session the operation started under still stands: same epoch, or the
    // same account under a swapped credential.
    bool sessionStillStands() {
      if (sessionEpoch == authSessionEpoch) return true;
      return entryAccountKey.isNotEmpty &&
          pendingAuthAccountKey == entryAccountKey;
    }

    if (sessionEpoch != authSessionEpoch) {
      final live = liveSessionForWallet();
      if (live != null) return live;
      throw StateError('Authentication request belongs to an ended session');
    }

    setPreferredWalletAddress(
      normalizedWallet,
      expectedAuthSessionEpoch: sessionEpoch,
    );
    await restoreExistingSession(allowRefresh: false);
    final existing = liveSessionForWallet();
    if (existing != null) return existing;

    final challenge = await requestWalletAuthChallenge(normalizedWallet);
    final signature = await signMessage(challenge.message);
    if (!sessionStillStands()) {
      final live = liveSessionForWallet();
      if (live != null) return live;
      throw StateError('Authentication request belongs to an ended session');
    }
    final response = await loginWithWallet(
      walletAddress: normalizedWallet,
      signature: signature,
      message: challenge.message,
      // Rebound to the live epoch of the same account: nothing awaits between
      // the check above and the commit's epoch test.
      expectedEpoch: authSessionEpoch,
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

    final sessionEpoch = authSessionEpoch;
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
          await setAuthToken(token, expectedEpoch: sessionEpoch);
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
