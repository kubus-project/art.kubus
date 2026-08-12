part of 'backend_api_service.dart';

extension BackendApiServiceSpatialTransport on BackendApiService {
  Future<ArtworkSpatialHistory> getArtworkSpatialHistory(
    String artworkId,
  ) async {
    final response = await _get(
      Uri.parse(
          '$baseUrl/api/artworks/${Uri.encodeComponent(artworkId)}/spatial'),
      headers: _getHeaders(),
    );
    if (!_isSuccessStatus(response.statusCode)) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: '/api/artworks/$artworkId/spatial',
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] is Map
        ? Map<String, dynamic>.from(decoded['data'] as Map)
        : decoded;
    return ArtworkSpatialHistory.fromJson(data);
  }

  Future<Map<String, dynamic>> publishExistingSpatialCid({
    required Map<String, dynamic> spatial,
    required String artworkId,
    String? markerId,
  }) async {
    final response = await _post(
      Uri.parse('$baseUrl/api/publications/spatial/cid'),
      headers: _getHeaders(),
      body: jsonEncode(<String, dynamic>{
        'spatial': spatial,
        'artworkId': artworkId,
        if (markerId != null && markerId.trim().isNotEmpty)
          'markerId': markerId,
      }),
    );
    if (!_isSuccessStatus(response.statusCode)) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: '/api/publications/spatial/cid',
        body: response.body,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['data'] is Map<String, dynamic>
        ? decoded['data'] as Map<String, dynamic>
        : decoded;
  }
}
