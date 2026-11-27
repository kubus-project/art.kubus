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

  Uri _spatialDraftUri(String artworkId, [String suffix = '']) => Uri.parse(
        '$baseUrl/api/publications/spatial/drafts/${Uri.encodeComponent(artworkId)}$suffix',
      );

  SpatialUploadDraft? _spatialDraftResponse(http.Response response, Uri uri) {
    if (!_isSuccessStatus(response.statusCode)) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true || !body.containsKey('data')) {
      throw const FormatException('Invalid spatial draft upload response');
    }
    final data = body['data'];
    return data == null
        ? null
        : SpatialUploadDraft.fromJson(data as Map<String, dynamic>);
  }

  Future<SpatialUploadDraft?> getSpatialUploadDraft(String artworkId) async {
    final uri = _spatialDraftUri(artworkId);
    return _spatialDraftResponse(await _get(uri), uri);
  }

  Future<SpatialUploadDraft> createSpatialUploadDraft({
    required String artworkId,
    required String fileName,
    required String format,
    required int sizeBytes,
    required String sha256,
  }) async {
    final uri = _spatialDraftUri(artworkId);
    final response = await _post(
      uri,
      body: jsonEncode({
        'fileName': fileName,
        'format': format,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
      }),
      allowImplicitBackendFailover: false,
    );
    return _spatialDraftResponse(response, uri) ??
        (throw const FormatException('Missing spatial draft upload'));
  }

  Future<SpatialUploadDraft> uploadSpatialDraftChunk({
    required SpatialUploadDraft draft,
    required Uint8List bytes,
  }) async {
    final uri = _spatialDraftUri(
      draft.artworkId,
      '/${Uri.encodeComponent(draft.id)}/chunks/${draft.receivedBytes}',
    );
    final response = await _request(
      'PUT',
      uri,
      headers: {..._getHeaders(), 'Content-Type': 'application/octet-stream'},
      body: bytes,
      timeout: const Duration(seconds: 90),
      allowImplicitBackendFailover: false,
    );
    final updated = _spatialDraftResponse(response, uri);
    if (updated == null ||
        updated.id != draft.id ||
        updated.artworkId != draft.artworkId ||
        updated.sizeBytes != draft.sizeBytes ||
        updated.sha256 != draft.sha256 ||
        updated.receivedBytes != draft.receivedBytes + bytes.length) {
      throw const FormatException('Invalid spatial draft upload progress');
    }
    return updated;
  }

  Uri _spatialDraftAction(SpatialUploadDraft draft, String action) =>
      _spatialDraftUri(
          draft.artworkId, '/${Uri.encodeComponent(draft.id)}/$action');

  Future<Map<String, dynamic>> getSpatialDraftReview(
      SpatialUploadDraft draft) async {
    final uri = _spatialDraftAction(draft, 'submission');
    return _spatialReviewResponse(await _get(uri), uri);
  }

  Future<void> submitSpatialDraft(
      SpatialUploadDraft draft, Map<String, dynamic> input) async {
    final uri = _spatialDraftAction(draft, 'submission');
    final response = await _post(uri,
        body: jsonEncode(input), allowImplicitBackendFailover: false);
    _spatialReviewResponse(response, uri);
  }

  Map<String, dynamic> _spatialReviewResponse(http.Response response, Uri uri) {
    if (!_isSuccessStatus(response.statusCode)) {
      throw BackendApiRequestException(
          statusCode: response.statusCode, path: uri.path, body: response.body);
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
  }

  Future<void> retireSpatialDraft(
      SpatialUploadDraft draft, String submissionId, int revision) async {
    final uri = _spatialDraftAction(draft, 'retire');
    final response = await _post(uri,
        body: jsonEncode({
          'expectedSubmissionId': submissionId,
          'expectedRevision': revision,
        }),
        allowImplicitBackendFailover: false);
    if (!_isSuccessStatus(response.statusCode)) {
      throw BackendApiRequestException(
          statusCode: response.statusCode, path: uri.path, body: response.body);
    }
  }

  Future<Uint8List> getSpatialDraftPreview(SpatialUploadDraft draft) async {
    final uri = _spatialDraftAction(draft, 'preview');
    final response = await _get(uri, timeout: const Duration(minutes: 2));
    if (!_isSuccessStatus(response.statusCode) ||
        response.bodyBytes.length != draft.sizeBytes) {
      throw BackendApiRequestException(
          statusCode: response.statusCode, path: uri.path, body: '');
    }
    return response.bodyBytes;
  }

  Future<void> deleteSpatialUploadDraft(SpatialUploadDraft draft) async {
    final uri =
        _spatialDraftUri(draft.artworkId, '/${Uri.encodeComponent(draft.id)}');
    final response =
        await _request('DELETE', uri, allowImplicitBackendFailover: false);
    if (!_isSuccessStatus(response.statusCode)) {
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    }
  }
}
