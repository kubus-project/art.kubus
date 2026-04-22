part of 'backend_api_service.dart';

String? _backendApiNormalizePublicObjectType(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'artwork':
    case 'artworks':
    case 'profile':
    case 'profiles':
    case 'community_post':
    case 'community-post':
    case 'post':
    case 'posts':
    case 'collection':
    case 'collections':
    case 'marker':
    case 'markers':
    case 'exhibition':
    case 'exhibitions':
      return normalized;
    default:
      return null;
  }
}

String _backendApiCanonicalPublicObjectType(String normalized) {
  switch (normalized) {
    case 'artworks':
      return 'artwork';
    case 'profiles':
      return 'profile';
    case 'community-post':
    case 'post':
    case 'posts':
      return 'community_post';
    case 'collections':
      return 'collection';
    case 'markers':
      return 'marker';
    case 'exhibitions':
      return 'exhibition';
    default:
      return normalized;
  }
}

List<Map<String, dynamic>> _backendApiDecodeMapList(dynamic raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

extension BackendApiPublicObjectRegistryAccess on BackendApiService {
  Future<Map<String, dynamic>?> getCanonicalPublicObject({
    required String objectType,
    required String objectId,
  }) async {
    final normalizedType = _backendApiNormalizePublicObjectType(objectType);
    final normalizedId = objectId.trim();
    if (normalizedType == null || normalizedId.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/api/public-objects/${Uri.encodeComponent(_backendApiCanonicalPublicObjectType(normalizedType))}/${Uri.encodeComponent(normalizedId)}',
      );
      final response = await _fetchJson(
        uri,
        includeAuth: false,
        allowOrbitFallback: false,
      );
      return _backendApiMapOrNull(response['data']) ?? response;
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.getCanonicalPublicObject failed: $e',
      );
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCanonicalPublicObjectVersions({
    required String objectType,
    required String objectId,
  }) async {
    final normalizedType = _backendApiNormalizePublicObjectType(objectType);
    final normalizedId = objectId.trim();
    if (normalizedType == null || normalizedId.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/api/public-objects/${Uri.encodeComponent(_backendApiCanonicalPublicObjectType(normalizedType))}/${Uri.encodeComponent(normalizedId)}/versions',
      );
      final response = await _fetchJson(
        uri,
        includeAuth: false,
        allowOrbitFallback: false,
      );
      return _backendApiDecodeMapList(response['data']);
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.getCanonicalPublicObjectVersions failed: $e',
      );
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> getRewardablePublicCids({
    String? objectType,
    String? objectId,
    int limit = 50,
  }) async {
    final normalizedType = objectType == null
        ? null
        : _backendApiNormalizePublicObjectType(objectType);
    final normalizedObjectId = objectId?.trim();
    try {
      final uri = Uri.parse('$baseUrl/api/public-objects/rewardable-cids')
          .replace(queryParameters: <String, String>{
        if (normalizedType != null)
          'type': _backendApiCanonicalPublicObjectType(normalizedType),
        if (normalizedObjectId != null && normalizedObjectId.isNotEmpty)
          'id': normalizedObjectId,
        'limit': limit.clamp(1, 200).toString(),
      });
      final response = await _fetchJson(
        uri,
        includeAuth: false,
        allowOrbitFallback: false,
      );
      return _backendApiDecodeMapList(response['data']);
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.getRewardablePublicCids failed: $e',
      );
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> getPublicCidRecord(String cid) async {
    final normalizedCid = cid.trim();
    if (normalizedCid.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/api/public-objects/cid/${Uri.encodeComponent(normalizedCid)}',
      );
      final response = await _fetchJson(
        uri,
        includeAuth: false,
        allowOrbitFallback: false,
      );
      return _backendApiMapOrNull(response['data']) ?? response;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getPublicCidRecord failed: $e');
      return null;
    }
  }
}
