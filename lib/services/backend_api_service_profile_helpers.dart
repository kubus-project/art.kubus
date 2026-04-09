part of 'backend_api_service.dart';

Future<Map<String, dynamic>> _backendApiUpdateProfileImpl(
  BackendApiService service,
  String walletAddress,
  Map<String, dynamic> updates,
) async {
  service._throwIfIpfsFallbackUnavailable('Profile editing');
  try {
    await service._ensureAuthBeforeRequest(walletAddress: walletAddress);
    final payload = {
      'walletAddress': walletAddress,
      ...updates,
    };
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/profiles'),
      headers: service._getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update profile: ${response.statusCode}');
    }
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.updateProfile failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiGetProfileByWalletImpl(
  BackendApiService service,
  String walletAddress,
) async {
  try {
    // Public read: do NOT attempt to auto-issue/auth-switch for the wallet
    // being viewed.
    // Avoid making pointless network calls when wallet is a known placeholder
    final normalized = WalletUtils.normalize(walletAddress);
    if (normalized.isEmpty ||
        ['unknown', 'anonymous', 'n/a', 'none']
            .contains(normalized.toLowerCase())) {
      throw Exception('Profile not found');
    }
    // URL-encode the wallet address for safe path segments
    final encodedWallet = Uri.encodeComponent(normalized);
    return await service._performPublicRead<Map<String, dynamic>>(
      liveRead: (candidateBaseUrl) async {
        final data = await service._fetchJsonFromBaseUrl(
          candidateBaseUrl,
          '/api/profiles/$encodedWallet',
          includeAuth: false,
          allowOrbitFallback: true,
        );
        final raw = data['data'] ?? data;
        if (raw is Map<String, dynamic>) {
          AppConfig.debugPrint(
              'BackendApiService.getProfileByWallet: parsed profile keys: ${raw.keys.toList()}');
          return raw;
        }
        throw Exception('Invalid profile payload');
      },
      snapshotRead: () async {
        final profiles = await service._loadSnapshotDatasetMaps('profiles');
        for (final profile in profiles) {
          final candidate = WalletUtils.normalize(
            profile['walletAddress'] ??
                profile['wallet_address'] ??
                profile['wallet'] ??
                profile['id'],
          );
          if (candidate == normalized) {
            return profile;
          }
        }
        throw Exception('Profile not found');
      },
    );
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.getProfileByWallet failed: $e');
    rethrow;
  }
}

Future<Map<String, dynamic>> _backendApiGetProfilesBatchImpl(
  BackendApiService service,
  List<String> wallets,
) async {
  try {
    if (wallets.isEmpty) return {'success': true, 'data': <dynamic>[]};
    await service._ensureAuthBeforeRequest();
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/profiles/batch'),
      headers: service._getHeaders(),
      body: jsonEncode({'wallets': wallets}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data['data'] ?? data};
    }
    return {
      'success': false,
      'status': response.statusCode,
      'body': response.body
    };
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.getProfilesBatch failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiGetPresenceBatchImpl(
  BackendApiService service,
  List<String> wallets,
) async {
  try {
    if (wallets.isEmpty) return {'success': true, 'data': <dynamic>[]};
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/presence/batch'),
      includeAuth: false,
      headers: service._getHeaders(includeAuth: false),
      body: jsonEncode({'wallets': wallets}),
      timeout: const Duration(seconds: 8),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data['data'] ?? data};
    }
    return {
      'success': false,
      'status': response.statusCode,
      'body': response.body
    };
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.getPresenceBatch failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiRecordPresenceVisitImpl(
  BackendApiService service, {
  required String type,
  required String id,
  String? walletAddress,
}) async {
  try {
    await service._ensureAuthBeforeRequest(walletAddress: walletAddress);
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/presence/visit'),
      headers: service._getHeaders(includeAuth: true),
      body: jsonEncode({'type': type, 'id': id}),
      timeout: const Duration(seconds: 8),
    );

    if (response.statusCode == 204) {
      return {'success': true, 'stored': false};
    }
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': true,
        'stored': true,
        'data': data['data'] ?? data,
      };
    }
    return {
      'success': false,
      'status': response.statusCode,
      'body': response.body
    };
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.recordPresenceVisit failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>> _backendApiPingPresenceImpl(
  BackendApiService service, {
  String? walletAddress,
}) async {
  try {
    await service._ensureAuthBeforeRequest(walletAddress: walletAddress);
    final response = await service._post(
      Uri.parse('${service.baseUrl}/api/presence/ping'),
      headers: service._getHeaders(includeAuth: true),
      timeout: const Duration(seconds: 8),
    );

    if (response.statusCode == 204) {
      return {'success': true};
    }
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': true, 'data': data['data'] ?? data};
    }
    return {
      'success': false,
      'status': response.statusCode,
      'body': response.body
    };
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.pingPresence failed: $e');
    return {'success': false, 'error': e.toString()};
  }
}

Future<Map<String, dynamic>?> _backendApiFindProfileByUsernameImpl(
  BackendApiService service,
  String username,
) async {
  final sanitized = username.trim().replaceFirst(RegExp(r'^@+'), '');
  if (sanitized.isEmpty) return null;
  try {
    final response =
        await service.search(query: sanitized, type: 'profiles', limit: 10, page: 1);
    if (response['success'] != true) return null;
    final normalizedTarget = sanitized.toLowerCase();
    final resultsPayload = response['results'];
    List<dynamic> profiles = const [];
    if (resultsPayload is Map<String, dynamic>) {
      profiles = (resultsPayload['profiles'] as List<dynamic>? ?? const []);
    } else if (response['profiles'] is List) {
      profiles = response['profiles'] as List<dynamic>;
    }
    if (profiles.isEmpty && response['data'] is List) {
      profiles = response['data'] as List<dynamic>;
    }
    for (final entry in profiles) {
      if (entry is! Map<String, dynamic>) continue;
      final rawUsername = (entry['username'] ??
              entry['walletAddress'] ??
              entry['wallet_address'] ??
              entry['wallet'])
          ?.toString() ??
          '';
      if (rawUsername.isEmpty) continue;
      final normalized =
          rawUsername.replaceFirst(RegExp(r'^@+'), '').toLowerCase();
      if (normalized == normalizedTarget) {
        return entry;
      }
    }
    // No exact match found; fallback to first profile result if available
    if (profiles.isNotEmpty && profiles.first is Map<String, dynamic>) {
      return profiles.first as Map<String, dynamic>;
    }
  } catch (e) {
    AppConfig.debugPrint(
        'BackendApiService.findProfileByUsername failed: $e');
  }
  return null;
}

Future<Map<String, dynamic>> _backendApiSaveProfileImpl(
  BackendApiService service,
  Map<String, dynamic> profileData,
) async {
  service._throwIfIpfsFallbackUnavailable('Profile editing');
  // Backend requires authentication (verifyToken). Make sure we have a token
  // available before attempting to save.
  final walletAddress =
      (profileData['walletAddress'] ?? profileData['wallet_address'])
          ?.toString();
  await service._ensureAuthBeforeRequest(walletAddress: walletAddress);

  const int maxRetries = 3;
  int attempt = 0;
  while (true) {
    attempt++;
    try {
      if (kDebugMode) {
        debugPrint(
            'BackendApiService.saveProfile: POST /api/profiles payload: ${jsonEncode(profileData)}');
      }
      final uri = Uri.parse('${service.baseUrl}/api/profiles');
      final response = await service._post(
        uri,
        headers: service._getHeaders(includeAuth: true),
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Some legacy backends used to return a token. Keep support.
        if (data['token'] is String && (data['token'] as String).isNotEmpty) {
          await service.setAuthToken(data['token'] as String);
          if (kDebugMode) {
            debugPrint(
                'BackendApiService.saveProfile: token received and stored from profile creation');
          }
        }

        final payload = data['data'] ?? data;
        if (payload is Map<String, dynamic>) {
          return payload;
        }
        // Defensive: sometimes data can be wrapped differently.
        return Map<String, dynamic>.from(payload as dynamic);
      }

      if (response.statusCode == 429) {
        // Too many requests - check Retry-After header
        final retryAfter = response.headers['retry-after'];
        final waitSeconds =
            int.tryParse(retryAfter ?? '') ?? (2 << (attempt - 1));
        if (attempt < maxRetries) {
          AppConfig.debugPrint(
              'BackendApiService.saveProfile: 429 retry in $waitSeconds seconds (attempt $attempt)');
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        } else {
          throw Exception(
              'Too many requests (429). Please wait and try again later.');
        }
      }

      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    } catch (e) {
      if (e is BackendApiRequestException &&
          (e.statusCode == 401 || e.statusCode == 403)) {
        rethrow;
      }
      // If we've exhausted retries, rethrow
      if (attempt >= maxRetries) {
        AppConfig.debugPrint(
            'BackendApiService.saveProfile failed (final): $e');
        rethrow;
      }

      // If this was a transient error, wait briefly and retry
      final backoff = 1 << (attempt - 1);
      AppConfig.debugPrint(
          'BackendApiService.saveProfile transient error, retrying in $backoff seconds: $e');
      await Future.delayed(Duration(seconds: backoff));
    }
  }
}

Future<List<Map<String, dynamic>>> _backendApiListArtistsImpl(
  BackendApiService service, {
  bool? verified,
  int limit = 50,
  int offset = 0,
}) async {
  try {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (verified != null) queryParams['verified'] = verified.toString();

    final uri = Uri.parse('${service.baseUrl}/api/profiles/artists/list')
        .replace(queryParameters: queryParams);
    final response = await service._get(uri,
        includeAuth: false, headers: service._getHeaders(includeAuth: false));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('Failed to list artists: ${response.statusCode}');
    }
  } catch (e) {
    AppConfig.debugPrint('BackendApiService.listArtists failed: $e');
    rethrow;
  }
}
