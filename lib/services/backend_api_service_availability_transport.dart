part of 'backend_api_service.dart';

extension BackendApiAvailabilityNetworkAccess on BackendApiService {
  Future<Map<String, dynamic>> createAvailabilityOperatorToken({
    required String label,
    required String walletAddress,
    int expiresInDays = 90,
    List<String>? scopes,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/api/availability/operator-tokens'),
      headers: _getHeaders(),
      body: jsonEncode(<String, dynamic>{
        'label': label.trim(),
        'walletAddress': walletAddress.trim(),
        'expiresInDays': expiresInDays.clamp(1, 365),
        if (scopes != null && scopes.isNotEmpty) 'scopes': scopes,
      }),
    );
    if (!_isSuccessStatus(response.statusCode)) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: '/api/availability/operator-tokens',
        body: response.body,
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return _backendApiMapOrNull(payload['data']) ?? payload;
  }

  Future<List<Map<String, dynamic>>> listAvailabilityOperatorTokens({
    String? walletAddress,
  }) async {
    final uri = Uri.parse('$baseUrl/api/availability/operator-tokens').replace(
      queryParameters: <String, String>{
        if (walletAddress != null && walletAddress.trim().isNotEmpty)
          'walletAddress': walletAddress.trim(),
      },
    );
    final response = await _fetchJson(
      uri,
      includeAuth: true,
      allowOrbitFallback: false,
    );
    final data = _backendApiMapOrNull(response['data']);
    return _backendApiDecodeMapList(data?['tokens']);
  }

  Future<Map<String, dynamic>> revokeAvailabilityOperatorToken(
    String tokenId, {
    String? reason,
  }) async {
    final response = await _delete(
      Uri.parse(
        '$baseUrl/api/availability/operator-tokens/${Uri.encodeComponent(tokenId)}',
      ),
      headers: _getHeaders(),
      body: jsonEncode(<String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      }),
    );
    if (!_isSuccessStatus(response.statusCode)) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: '/api/availability/operator-tokens/$tokenId',
        body: response.body,
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return _backendApiMapOrNull(payload['data']) ?? payload;
  }

  Future<Map<String, dynamic>?> getKub8UtilityModel() async {
    try {
      final uri = Uri.parse('$baseUrl/api/dao/kub8-utility');
      final response = await _fetchJson(
        uri,
        includeAuth: false,
        allowOrbitFallback: false,
      );
      return _backendApiMapOrNull(response['data']) ?? response;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getKub8UtilityModel failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAvailabilityRewardableCids({
    String? objectType,
    String? objectId,
    String? cid,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/availability/rewardable-cids')
          .replace(queryParameters: <String, String>{
        if (objectType != null && objectType.trim().isNotEmpty)
          'type': objectType.trim(),
        if (objectId != null && objectId.trim().isNotEmpty)
          'id': objectId.trim(),
        if (cid != null && cid.trim().isNotEmpty) 'cid': cid.trim(),
        'limit': limit.clamp(1, 500).toString(),
        'offset': offset.clamp(0, 1 << 31).toString(),
      });
      final response = await _fetchJson(
        uri,
        includeAuth: false,
        allowOrbitFallback: false,
      );
      return _backendApiMapOrNull(response['data']) ?? response;
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.getAvailabilityRewardableCids failed: $e',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> registerAvailabilityNode({
    required String nodeKey,
    required String endpointUrl,
    String? label,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/availability/nodes'),
        headers: _getHeaders(),
        body: jsonEncode(<String, dynamic>{
          'nodeKey': nodeKey,
          'endpointUrl': endpointUrl,
          if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
          if (metadata != null) 'metadata': metadata,
        }),
      );
      if (_isSuccessStatus(response.statusCode)) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _backendApiMapOrNull(data['data']) ?? data;
      }
      throw Exception(
        'Failed to register availability node: ${response.statusCode}',
      );
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.registerAvailabilityNode failed: $e',
      );
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMyAvailabilityNodes() async {
    try {
      final response = await _fetchJson(
        Uri.parse('$baseUrl/api/availability/nodes/me'),
        includeAuth: true,
        allowOrbitFallback: false,
      );
      final data = _backendApiMapOrNull(response['data']);
      return _backendApiDecodeMapList(data?['nodes']);
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.getMyAvailabilityNodes failed: $e',
      );
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> getCurrentAvailabilityEpoch() async {
    try {
      final response = await _fetchJson(
        Uri.parse('$baseUrl/api/availability/epochs/current'),
        includeAuth: false,
        allowOrbitFallback: false,
      );
      final data = _backendApiMapOrNull(response['data']);
      return _backendApiMapOrNull(data?['epoch']);
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.getCurrentAvailabilityEpoch failed: $e',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> createAvailabilityCommitment({
    required String nodeId,
    String? rewardableCidId,
    String? cid,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _post(
        Uri.parse(
          '$baseUrl/api/availability/nodes/${Uri.encodeComponent(nodeId)}/commitments',
        ),
        headers: _getHeaders(),
        body: jsonEncode(<String, dynamic>{
          if (rewardableCidId != null && rewardableCidId.trim().isNotEmpty)
            'rewardableCidId': rewardableCidId.trim(),
          if (cid != null && cid.trim().isNotEmpty) 'cid': cid.trim(),
          if (expiresAt != null)
            'expiresAt': expiresAt.toUtc().toIso8601String(),
          if (metadata != null) 'metadata': metadata,
        }),
      );
      if (_isSuccessStatus(response.statusCode)) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _backendApiMapOrNull(data['data']) ?? data;
      }
      throw Exception(
        'Failed to create availability commitment: ${response.statusCode}',
      );
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.createAvailabilityCommitment failed: $e',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getAvailabilityEpochSummary(
    String epochId,
  ) async {
    try {
      final response = await _fetchJson(
        Uri.parse(
          '$baseUrl/api/availability/epochs/${Uri.encodeComponent(epochId)}/summary',
        ),
        includeAuth: false,
        allowOrbitFallback: false,
      );
      return _backendApiMapOrNull(response['data']) ?? response;
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.getAvailabilityEpochSummary failed: $e',
      );
      return null;
    }
  }
}
