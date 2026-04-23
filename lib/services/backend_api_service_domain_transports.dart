part of 'backend_api_service.dart';

enum BackendAuthLevel {
  unknown,
  bootstrap,
  accountLinked,
  walletSigned,
}

BackendAuthLevel _backendAuthLevelFromValue(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'bootstrap':
      return BackendAuthLevel.bootstrap;
    case 'account_linked':
    case 'accountlinked':
      return BackendAuthLevel.accountLinked;
    case 'wallet_signed':
    case 'walletsigned':
      return BackendAuthLevel.walletSigned;
    default:
      return BackendAuthLevel.unknown;
  }
}

enum BackendTransportLifecycle {
  canonical,
  legacy,
  draftLocalOnly,
  deadUnwired,
}

class BackendTransportSurfaceDefinition {
  const BackendTransportSurfaceDefinition({
    required this.name,
    required this.domain,
    required this.lifecycle,
    required this.route,
    required this.notes,
    this.requiresBackendSession = false,
    this.requiresWalletSignature = false,
  });

  final String name;
  final String domain;
  final BackendTransportLifecycle lifecycle;
  final String route;
  final String notes;
  final bool requiresBackendSession;
  final bool requiresWalletSignature;
}

class BackendSessionStateDto {
  const BackendSessionStateDto({
    required this.hasBackendSession,
    required this.authLevel,
    required this.signInMethod,
    required this.impliesSignerAuthority,
    this.walletAddress,
    this.email,
  });

  final bool hasBackendSession;
  final BackendAuthLevel authLevel;
  final AuthSignInMethod signInMethod;
  final bool impliesSignerAuthority;
  final String? walletAddress;
  final String? email;
}

class BackendAuthSessionTransport {
  const BackendAuthSessionTransport(this._service);

  final BackendApiService _service;

  Future<BackendSessionStateDto> restoreStoredSession({
    bool allowRefresh = true,
  }) async {
    final hasBackendSession = await _service.restoreExistingSession(
      allowRefresh: allowRefresh,
    );
    return BackendSessionStateDto(
      hasBackendSession: hasBackendSession,
      authLevel: _service.getCurrentAuthLevel(),
      signInMethod: await _service.resolveLastSignInMethod(),
      impliesSignerAuthority: false,
      walletAddress: _service.getCurrentAuthWalletAddress(),
      email: _service.getCurrentAuthEmail(),
    );
  }

  Future<Map<String, dynamic>> registerWalletBootstrap({
    required String walletAddress,
    String? username,
  }) {
    return _service.registerWallet(
      walletAddress: walletAddress,
      username: username,
    );
  }

  Future<Map<String, dynamic>> registerLinkedEmail({
    required String email,
    required String password,
    String? username,
    String? displayName,
    String? walletAddress,
    bool includeAuth = false,
  }) {
    return _service.registerWithEmail(
      email: email,
      password: password,
      username: username,
      displayName: displayName,
      walletAddress: walletAddress,
      includeAuth: includeAuth,
    );
  }

  Future<Map<String, dynamic>> loginLinkedEmail({
    required String email,
    required String password,
  }) {
    return _service.loginWithEmail(email: email, password: password);
  }

  Future<Map<String, dynamic>> loginLinkedGoogle({
    String? idToken,
    String? code,
    String? email,
    String? username,
    String? walletAddress,
    String? displayName,
  }) {
    return _service.loginWithGoogle(
      idToken: idToken,
      code: code,
      email: email,
      username: username,
      walletAddress: walletAddress,
      displayName: displayName,
    );
  }
}

class BackendRecoveryTransport {
  const BackendRecoveryTransport(this._service);

  final BackendApiService _service;

  Future<EncryptedWalletBackupDefinition?> getEncryptedWalletBackup({
    String? walletAddress,
  }) {
    return _service.getEncryptedWalletBackup(walletAddress: walletAddress);
  }

  Future<EncryptedWalletBackupDefinition> putEncryptedWalletBackup(
    EncryptedWalletBackupDefinition definition,
  ) {
    return _service.putEncryptedWalletBackup(definition);
  }

  Future<void> deleteEncryptedWalletBackup({String? walletAddress}) {
    return _service.deleteEncryptedWalletBackup(walletAddress: walletAddress);
  }

  Future<Map<String, dynamic>> getPasskeyRegistrationOptions({
    required String walletAddress,
    String? nickname,
  }) {
    return _service.getWalletBackupPasskeyRegistrationOptions(
      walletAddress: walletAddress,
      nickname: nickname,
    );
  }

  Future<Map<String, dynamic>> verifyPasskeyRegistration({
    required String walletAddress,
    required Map<String, dynamic> responsePayload,
    String? nickname,
  }) {
    return _service.verifyWalletBackupPasskeyRegistration(
      walletAddress: walletAddress,
      responsePayload: responsePayload,
      nickname: nickname,
    );
  }

  Future<Map<String, dynamic>> getPasskeyAuthOptions({
    required String walletAddress,
  }) {
    return _service.getWalletBackupPasskeyAuthOptions(
      walletAddress: walletAddress,
    );
  }

  Future<Map<String, dynamic>> verifyPasskeyAuth({
    required String walletAddress,
    required Map<String, dynamic> responsePayload,
  }) {
    return _service.verifyWalletBackupPasskeyAuth(
      walletAddress: walletAddress,
      responsePayload: responsePayload,
    );
  }

  Future<void> emitBackupEvent({
    required String walletAddress,
    required String eventType,
  }) {
    return _service.emitWalletBackupEvent(
      walletAddress: walletAddress,
      eventType: eventType,
    );
  }
}

class BackendPublicObjectTransport {
  const BackendPublicObjectTransport(this._service);

  final BackendApiService _service;

  Future<List<ArtMarker>> getMyMarkers() => _service.getMyArtMarkers();

  Future<ArtMarker?> createMarker(Map<String, dynamic> payload) {
    return _service.createArtMarkerRecord(payload);
  }

  Future<ArtMarker?> updateMarker(
    String markerId,
    Map<String, dynamic> updates,
  ) {
    return _service.updateArtMarkerRecord(markerId, updates);
  }

  Future<bool> deleteMarker(String markerId) {
    return _service.deleteArtMarkerRecord(markerId);
  }

  Future<Artwork?> createArtwork(Map<String, dynamic> payload) {
    return _service.createArtworkRecord(
      title: (payload['title'] ?? '').toString(),
      description: (payload['description'] ?? '').toString(),
      imageUrl: (payload['imageUrl'] ?? payload['image_url'] ?? '').toString(),
      imageCid:
          payload['imageCid']?.toString() ?? payload['image_cid']?.toString(),
      walletAddress:
          (payload['walletAddress'] ?? payload['wallet_address'] ?? '')
              .toString(),
      artistName: payload['artistName']?.toString(),
      category: (payload['category'] ?? 'General').toString(),
      tags: (payload['tags'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      galleryUrls: (payload['galleryUrls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      galleryMeta: (payload['galleryMeta'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      isPublic: payload['isPublic'] == true,
      enableAR: payload['enableAR'] == true || payload['isAREnabled'] == true,
      modelUrl: payload['modelUrl']?.toString(),
      modelCid: payload['modelCid']?.toString(),
      arScale: payload['arScale'] is num
          ? (payload['arScale'] as num).toDouble()
          : 1,
      mintAsNFT: payload['mintAsNFT'] == true || payload['isNFT'] == true,
      price:
          payload['price'] is num ? (payload['price'] as num).toDouble() : null,
      royaltyPercent: payload['royaltyPercent'] is num
          ? (payload['royaltyPercent'] as num).toDouble()
          : null,
      metadata: payload['metadata'] is Map<String, dynamic>
          ? payload['metadata'] as Map<String, dynamic>
          : null,
      locationName: payload['locationName']?.toString(),
      latitude: payload['latitude'] is num
          ? (payload['latitude'] as num).toDouble()
          : null,
      longitude: payload['longitude'] is num
          ? (payload['longitude'] as num).toDouble()
          : null,
    );
  }

  Future<Artwork?> updateArtwork(
    String artworkId,
    Map<String, dynamic> updates,
  ) {
    return _service.updateArtwork(artworkId, updates);
  }

  Future<Artwork?> publishArtwork(String artworkId) {
    return _service.publishArtwork(artworkId);
  }

  Future<Artwork?> unpublishArtwork(String artworkId) {
    return _service.unpublishArtwork(artworkId);
  }

  Future<bool> deleteArtwork(String artworkId) {
    return _service.deleteArtwork(artworkId);
  }

  Future<List<Map<String, dynamic>>> getCollections({
    String? walletAddress,
    int page = 1,
    int limit = 20,
  }) {
    return _service.getCollections(
      walletAddress: walletAddress,
      page: page,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getCanonicalObject({
    required String objectType,
    required String objectId,
  }) {
    return _service.getCanonicalPublicObject(
      objectType: objectType,
      objectId: objectId,
    );
  }

  Future<List<Map<String, dynamic>>> getObjectVersions({
    required String objectType,
    required String objectId,
  }) {
    return _service.getCanonicalPublicObjectVersions(
      objectType: objectType,
      objectId: objectId,
    );
  }

  Future<List<Map<String, dynamic>>> getRewardableCids({
    String? objectType,
    String? objectId,
    int limit = 50,
  }) {
    return _service.getRewardablePublicCids(
      objectType: objectType,
      objectId: objectId,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> getCidRecord(String cid) {
    return _service.getPublicCidRecord(cid);
  }
}

class BackendCollectiblesAttestationsTransport {
  const BackendCollectiblesAttestationsTransport(this._service);

  final BackendApiService _service;

  Future<Map<String, dynamic>> getAttendanceChallenge({
    required String markerId,
    String? walletAddress,
  }) {
    return _service.getAttendanceChallenge(
      markerId: markerId,
      walletAddress: walletAddress,
    );
  }

  Future<Map<String, dynamic>> confirmAttendance({
    required String markerId,
    required String challengeToken,
    required Map<String, dynamic> clientLocation,
    String? walletAddress,
  }) {
    return _service.confirmAttendance(
      markerId: markerId,
      challengeToken: challengeToken,
      clientLocation: clientLocation,
      walletAddress: walletAddress,
    );
  }
}

extension BackendApiDomainAccess on BackendApiService {
  BackendAuthSessionTransport get session => BackendAuthSessionTransport(this);

  BackendSignedActionTransport get signedActions =>
      BackendSignedActionTransport(this);

  BackendRecoveryTransport get recovery => BackendRecoveryTransport(this);

  BackendPublicObjectTransport get publicObjects =>
      BackendPublicObjectTransport(this);

  BackendDaoTransport get dao => BackendDaoTransport(this);

  BackendWalletSettlementTransport get walletSettlements =>
      BackendWalletSettlementTransport(this);

  BackendCollectiblesAttestationsTransport get collectibles =>
      BackendCollectiblesAttestationsTransport(this);

  BackendAuthLevel getCurrentAuthLevel() {
    final claims = getCurrentAuthTokenClaims();
    if (claims == null) return BackendAuthLevel.unknown;
    final raw = (claims['authLevel'] ??
            claims['auth_level'] ??
            claims['walletAuthority'] ??
            claims['wallet_authority'] ??
            '')
        .toString();
    return _backendAuthLevelFromValue(raw);
  }

  List<BackendTransportSurfaceDefinition> get transportInventory =>
      const <BackendTransportSurfaceDefinition>[
        BackendTransportSurfaceDefinition(
          name: 'registerWallet',
          domain: 'auth/session',
          lifecycle: BackendTransportLifecycle.legacy,
          route: 'POST /api/auth/register',
          notes: 'Wallet bootstrap only. Does not prove signer authority.',
        ),
        BackendTransportSurfaceDefinition(
          name: 'ensureSessionForActiveSigner',
          domain: 'signed action',
          lifecycle: BackendTransportLifecycle.canonical,
          route: 'GET /api/auth/challenge + POST /api/auth/login',
          notes: 'Canonical signer-backed wallet session flow.',
          requiresWalletSignature: true,
        ),
        BackendTransportSurfaceDefinition(
          name: 'registerWithEmail',
          domain: 'auth/session',
          lifecycle: BackendTransportLifecycle.canonical,
          route: 'POST /api/auth/register/email',
          notes:
              'Linked account auth. Backend session only, never signer authority.',
        ),
        BackendTransportSurfaceDefinition(
          name: 'loginWithGoogle',
          domain: 'auth/session',
          lifecycle: BackendTransportLifecycle.canonical,
          route: 'POST /api/auth/login/google',
          notes:
              'Linked account auth. Wallet identity is metadata until signer login upgrades it.',
        ),
        BackendTransportSurfaceDefinition(
          name: 'bindAuthenticatedWallet',
          domain: 'auth/session',
          lifecycle: BackendTransportLifecycle.deadUnwired,
          route: 'POST /api/auth/bind-wallet',
          notes:
              'Deprecated unsafe wallet-link bridge. Kept only as a compatibility surface.',
          requiresBackendSession: true,
        ),
        BackendTransportSurfaceDefinition(
          name: 'issueDebugTokenForWallet',
          domain: 'signed action',
          lifecycle: BackendTransportLifecycle.draftLocalOnly,
          route: 'POST /api/profiles/issue-token',
          notes: 'Debug-only token issuance. Never production authority.',
        ),
        BackendTransportSurfaceDefinition(
          name: 'getEncryptedWalletBackup',
          domain: 'recovery/backup',
          lifecycle: BackendTransportLifecycle.canonical,
          route: 'GET /api/wallet-backup',
          notes:
              'Recovery transport. Backend account auth plus recovery checks, not wallet signature.',
          requiresBackendSession: true,
        ),
        BackendTransportSurfaceDefinition(
          name: 'walletSettlements.getFeeSplitterConfig',
          domain: 'wallet settlement',
          lifecycle: BackendTransportLifecycle.canonical,
          route: 'GET /api/wallet-settlements/fee-splitter/config',
          notes:
              'Canonical fee splitter configuration surface for swap fee settlement mode selection.',
        ),
        BackendTransportSurfaceDefinition(
          name: 'walletSettlements.submitSwapFees',
          domain: 'wallet settlement',
          lifecycle: BackendTransportLifecycle.canonical,
          route: 'POST /api/wallet-settlements/swap-fees',
          notes:
              'Wallet-signed backend settlement fallback for swap fee splitting.',
          requiresBackendSession: true,
          requiresWalletSignature: true,
        ),
        BackendTransportSurfaceDefinition(
          name: 'getDAOReview',
          domain: 'dao',
          lifecycle: BackendTransportLifecycle.draftLocalOnly,
          route: 'GET /api/dao/reviews/:id',
          notes:
              'DAO remains provisional and must not be treated as canonical signer authority.',
        ),
      ];
}
