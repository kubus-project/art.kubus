part of 'backend_api_service.dart';

String? _backendApiTrimmedString(dynamic value) {
  if (value == null) return null;
  final next = value.toString().trim();
  return next.isEmpty ? null : next;
}

String? _backendApiResolveUploadedUrl(Map<String, dynamic> data) {
  try {
    if (data.containsKey('relativeUrl') &&
        (data['relativeUrl'] as String).isNotEmpty) {
      return data['relativeUrl'] as String;
    }
    if (data.containsKey('relative_url') &&
        (data['relative_url'] as String).isNotEmpty) {
      return data['relative_url'] as String;
    }

    String? normalizePublicPath(dynamic raw) {
      final publicPath = _backendApiTrimmedString(raw);
      if (publicPath == null) return null;
      if (publicPath.startsWith('/uploads/') ||
          publicPath.startsWith('uploads/')) {
        return publicPath.startsWith('/') ? publicPath : '/$publicPath';
      }
      return '/uploads/$publicPath';
    }

    final publicPath = normalizePublicPath(data['publicPath']) ??
        normalizePublicPath(data['public_path']);
    if (publicPath != null) return publicPath;

    for (final key in const <String>['url', 'ipfsUrl', 'httpUrl', 'fileUrl', 'path']) {
      final value = _backendApiTrimmedString(data[key]);
      if (value != null) return value;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String? _backendApiGuessContentType(String fileName, String fileType) {
  final normalizedType = fileType.trim().toLowerCase();
  if (normalizedType.contains('/')) return normalizedType;
  final lowerName = fileName.trim().toLowerCase();
  if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lowerName.endsWith('.png')) return 'image/png';
  if (lowerName.endsWith('.webp')) return 'image/webp';
  if (lowerName.endsWith('.gif')) return 'image/gif';
  if (lowerName.endsWith('.svg')) return 'image/svg+xml';
  if (lowerName.endsWith('.mp4')) return 'video/mp4';
  if (lowerName.endsWith('.mov')) return 'video/quicktime';
  if (lowerName.endsWith('.webm')) return 'video/webm';
  if (lowerName.endsWith('.glb')) return 'model/gltf-binary';
  if (lowerName.endsWith('.gltf')) return 'model/gltf+json';
  if (lowerName.endsWith('.usdz')) return 'model/vnd.usdz+zip';
  return null;
}

bool _backendApiIsNodeNotWritableException(Object error) {
  return error is BackendApiRequestException &&
      error.statusCode == 503 &&
      (error.body ?? '').contains('NODE_NOT_WRITABLE');
}

String? _backendApiExtractPreferredWriteBaseUrl(String? body) {
  if (body == null || body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final response = decoded['response'];
      if (response is Map<String, dynamic>) {
        final value = _backendApiTrimmedString(response['preferredWriteBaseUrl']);
        if (value != null) return value;
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        final value = _backendApiTrimmedString(data['preferredWriteBaseUrl']);
        if (value != null) return value;
      }
      return _backendApiTrimmedString(decoded['preferredWriteBaseUrl']);
    }
  } catch (_) {
    return null;
  }
  return null;
}

bool _backendApiIsValidWriteFailoverUrl(
  Uri currentUri,
  String? candidateBaseUrl,
) {
  if (candidateBaseUrl == null || candidateBaseUrl.isEmpty) return false;
  try {
    final candidate = Uri.parse(candidateBaseUrl);
    if (candidate.scheme != 'http' && candidate.scheme != 'https') {
      return false;
    }
    return candidate.origin != currentUri.origin;
  } catch (_) {
    return false;
  }
}

Future<Map<String, dynamic>> _backendApiUploadFileImpl(
  BackendApiService service, {
  required List<int> fileBytes,
  required String fileName,
  required String fileType,
  Map<String, String>? metadata,
  String? walletAddress,
  bool compress = true,
  UploadCompressionPolicy? compressionPolicy,
  void Function(UploadCompressionProgress progress)? onCompressionProgress,
}) async {
  await service._ensureAuthBeforeRequest(walletAddress: walletAddress);
  final initialMetadata = Map<String, String>.from(metadata ?? const {});
  initialMetadata.putIfAbsent('publicationScope', () => 'draft');

  var uploadBytes = Uint8List.fromList(fileBytes);
  var uploadFileName = fileName;
  var uploadContentType = _backendApiGuessContentType(fileName, fileType);

  if (compress) {
    final compression = await service._mediaUploadOptimizer.optimize(
      UploadCompressionRequestDto(
        bytes: uploadBytes,
        fileName: fileName,
        fileType: fileType,
        metadata: initialMetadata,
        policy: compressionPolicy ?? UploadCompressionPolicyDto.standard,
      ),
      onProgress: onCompressionProgress,
    );
    uploadBytes = compression.bytes;
    uploadFileName = compression.fileName;
    uploadContentType = compression.contentType;
    initialMetadata.addAll(compression.toMetadataFields());
  } else {
    initialMetadata.addAll(
      UploadCompressionResultDto.skipped(
        UploadCompressionRequestDto(
          bytes: uploadBytes,
          fileName: fileName,
          fileType: fileType,
          metadata: initialMetadata,
          policy: UploadCompressionPolicyDto.noCompression,
        ),
        'disabled_by_caller',
      ).toMetadataFields(),
    );
  }

  const int maxRetries = 3;
  const int maxWriteFailovers = 1;
  int attempt = 0;
  int writeFailoverAttempt = 0;
  String? failoverBaseUrl;

  while (true) {
    attempt++;
    try {
      http.MultipartRequest buildRequest() {
        final effectiveBaseUrl = failoverBaseUrl ?? service.baseUrl;
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$effectiveBaseUrl/api/upload'),
        );

        request.headers.addAll(service._getHeaders());
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            uploadBytes,
            filename: uploadFileName,
            contentType: uploadContentType == null
                ? null
                : MediaType.parse(uploadContentType),
          ),
        );

        request.fields['fileType'] = fileType;
        request.fields['targetStorage'] = 'http';
        if (initialMetadata.isNotEmpty) {
          request.fields['metadata'] = jsonEncode(initialMetadata);
        }

        if (kDebugMode && AppConfig.enableNetworkLogging) {
          AppConfig.networkLog(
            'UPLOAD',
            request.url.toString(),
            data: <String, dynamic>{
              'attempt': attempt,
              'failoverAttempt': writeFailoverAttempt,
              'contentType': 'multipart/form-data',
              'fileField': 'file',
              'fileName': uploadFileName,
              'bytes': uploadBytes.length,
              'fileType': fileType,
              'targetStorage': 'http',
              'baseUrl': effectiveBaseUrl,
              if (initialMetadata.isNotEmpty) 'metadata': initialMetadata,
            },
          );
        }
        return request;
      }

      final response = await service._sendMultipart(
        buildRequest,
        includeAuth: true,
      );

      service._debugLogThrottled(
        'uploadFile:status',
        'BackendApiService.uploadFile: status=${response.statusCode} bodyLen=${response.body.length}',
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
            : (body['data'] != null
                ? Map<String, dynamic>.from(body['data'])
                : {});
        final uploadedUrl = _backendApiResolveUploadedUrl(data);

        if (kDebugMode && AppConfig.enableNetworkLogging) {
          AppConfig.networkLog(
            'UPLOAD_RES',
            Uri.parse('${failoverBaseUrl ?? service.baseUrl}/api/upload')
                .toString(),
            data: <String, dynamic>{
              'status': response.statusCode,
              'success': body['success'],
              'data.url': data['url'],
              'data.relativeUrl': data['relativeUrl'] ?? data['relative_url'],
              'data.publicPath': data['publicPath'] ?? data['public_path'],
              'uploadedUrl': uploadedUrl,
            },
          );
        }
        return <String, dynamic>{
          'raw': body,
          'data': data,
          'uploadedUrl': uploadedUrl,
        };
      }

      if (kDebugMode && AppConfig.enableNetworkLogging) {
        AppConfig.networkLog(
          'UPLOAD_RES',
          Uri.parse('${failoverBaseUrl ?? service.baseUrl}/api/upload')
              .toString(),
          data: <String, dynamic>{
            'status': response.statusCode,
            'bodyLen': response.body.length,
          },
        );
      }

      if (response.statusCode == 429) {
        final retryAfter = response.headers['retry-after'];
        final waitSeconds =
            int.tryParse(retryAfter ?? '') ?? (2 << (attempt - 1));
        if (attempt < maxRetries) {
          service._debugLogThrottled(
            'uploadFile:429',
            'BackendApiService.uploadFile: received 429, retrying in ${waitSeconds}s (attempt $attempt/$maxRetries)',
          );
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
        throw Exception('Too many requests (429) while uploading file.');
      }

      throw Exception('Failed to upload file: ${response.statusCode}');
    } catch (e, stackTrace) {
      if (_backendApiIsNodeNotWritableException(e) &&
          writeFailoverAttempt < maxWriteFailovers) {
        writeFailoverAttempt++;
        final responseBody = (e as BackendApiRequestException).body;
        final writeBaseUrl = _backendApiExtractPreferredWriteBaseUrl(responseBody);
        final currentUri = Uri.parse('${failoverBaseUrl ?? service.baseUrl}/api/upload');

        if (_backendApiIsValidWriteFailoverUrl(currentUri, writeBaseUrl)) {
          service._debugLogThrottled(
            'uploadFile:failover',
            'BackendApiService.uploadFile: attempting write failover to $writeBaseUrl (attempt $writeFailoverAttempt/$maxWriteFailovers)',
          );
          failoverBaseUrl = writeBaseUrl;
          attempt = 0;
          continue;
        }

        service._debugLogThrottled(
          'uploadFile:failover:invalid',
          'BackendApiService.uploadFile: invalid or missing preferredWriteBaseUrl=$writeBaseUrl',
        );
        rethrow;
      }

      if (_backendApiIsNodeNotWritableException(e)) {
        rethrow;
      }

      if (attempt >= maxRetries) {
        service._debugLogThrottled(
          'uploadFile:error:final',
          'BackendApiService.uploadFile: error (final): $e\n$stackTrace',
        );
        rethrow;
      }

      final backoff = 1 << (attempt - 1);
      service._debugLogThrottled(
        'uploadFile:error:retry',
        'BackendApiService.uploadFile: transient error, retrying in ${backoff}s (attempt $attempt/$maxRetries): $e',
      );
      await Future.delayed(Duration(seconds: backoff));
    }
  }
}

Future<String?> _backendApiUploadMarkerCoverImageImpl(
  BackendApiService service, {
  required List<int> fileBytes,
  required String fileName,
  required String fileType,
  required String source,
  String? walletAddress,
  bool compress = true,
  UploadCompressionPolicy? compressionPolicy,
  void Function(UploadCompressionProgress progress)? onCompressionProgress,
}) async {
  if (fileBytes.isEmpty) return null;
  final safeName = fileName.trim().isEmpty ? 'marker-cover.png' : fileName;
  final rawType = fileType.trim().toLowerCase();
  final normalizedType =
      rawType.isEmpty || rawType.startsWith('image/') ? 'image' : rawType;

  final upload = await service.uploadFile(
    fileBytes: fileBytes,
    fileName: safeName,
    fileType: normalizedType,
    metadata: <String, String>{
      'entity': 'art_marker',
      'kind': 'cover',
      'source': source,
      'publicationScope': 'draft',
    },
    walletAddress: walletAddress,
    compress: compress,
    compressionPolicy: compressionPolicy,
    onCompressionProgress: onCompressionProgress,
  );

  final primary = _backendApiTrimmedString(upload['uploadedUrl']);
  if (primary != null) return primary;

  final data = upload['data'];
  if (data is Map<String, dynamic>) {
    return _backendApiResolveUploadedUrl(data) ?? primary;
  }
  if (data is Map) {
    return _backendApiResolveUploadedUrl(Map<String, dynamic>.from(data)) ??
        primary;
  }
  return null;
}

Future<Map<String, dynamic>> _backendApiUploadAvatarToProfileImpl(
  BackendApiService service, {
  required List<int> fileBytes,
  required String fileName,
  required String fileType,
  Map<String, String>? metadata,
  bool compress = true,
  UploadCompressionPolicy? compressionPolicy,
  void Function(UploadCompressionProgress progress)? onCompressionProgress,
}) async {
  service._debugLogThrottled(
    'uploadAvatarToProfile:start',
    'BackendApiService.uploadAvatarToProfile: starting upload (fileName=$fileName, fileType=$fileType, bytes=${fileBytes.length})',
  );

  const int maxRetries = 3;
  const int maxWriteFailovers = 1;
  final initialMetadata = Map<String, String>.from(metadata ?? const {});
  initialMetadata.putIfAbsent('publicationScope', () => 'draft');

  var uploadBytes = Uint8List.fromList(fileBytes);
  var uploadFileName = fileName;
  var uploadFileType =
      _backendApiGuessContentType(fileName, fileType) ?? fileType;

  if (compress) {
    final compression = await service._mediaUploadOptimizer.optimize(
      UploadCompressionRequestDto(
        bytes: uploadBytes,
        fileName: fileName,
        fileType: fileType,
        contentType: fileType,
        metadata: {
          ...initialMetadata,
          'entity': 'profile',
          'kind': 'avatar',
        },
        policy: compressionPolicy ?? UploadCompressionPolicyDto.standard,
      ),
      onProgress: onCompressionProgress,
    );
    uploadBytes = compression.bytes;
    uploadFileName = compression.fileName;
    uploadFileType = compression.contentType ?? uploadFileType;
    initialMetadata.addAll(compression.toMetadataFields());
  } else {
    initialMetadata.addAll(
      UploadCompressionResultDto.skipped(
        UploadCompressionRequestDto(
          bytes: uploadBytes,
          fileName: fileName,
          fileType: fileType,
          contentType: fileType,
          metadata: initialMetadata,
          policy: UploadCompressionPolicyDto.noCompression,
        ),
        'disabled_by_caller',
      ).toMetadataFields(),
    );
  }

  int attempt = 0;
  int writeFailoverAttempt = 0;
  String? failoverBaseUrl;

  while (true) {
    attempt++;
    service._debugLogThrottled(
      'uploadAvatarToProfile:attempt',
      'BackendApiService.uploadAvatarToProfile: attempt $attempt/$maxRetries',
    );

    try {
      http.MultipartRequest buildRequest() {
        final effectiveBaseUrl = failoverBaseUrl ?? service.baseUrl;
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$effectiveBaseUrl/api/profiles/avatars'),
        );

        request.headers.addAll(service._getHeaders());
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            uploadBytes,
            filename: uploadFileName,
            contentType: MediaType.parse(uploadFileType),
          ),
        );

        request.fields['fileType'] = uploadFileType;
        if (initialMetadata.isNotEmpty) {
          request.fields['metadata'] = jsonEncode(initialMetadata);
        }
        return request;
      }

      final response = await service._sendMultipart(
        buildRequest,
        includeAuth: true,
      );

      service._debugLogThrottled(
        'uploadAvatarToProfile:status',
        'BackendApiService.uploadAvatarToProfile: status=${response.statusCode} bodyLen=${response.body.length}',
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
            : (body['data'] != null
                ? Map<String, dynamic>.from(body['data'])
                : {});

        final uploadedUrl = _backendApiTrimmedString(data['avatar']) ??
            _backendApiResolveUploadedUrl(data);
        service._debugLogThrottled(
          'uploadAvatarToProfile:done',
          'BackendApiService.uploadAvatarToProfile: upload complete (uploadedUrl=${uploadedUrl ?? 'null'})',
        );
        return <String, dynamic>{
          'raw': body,
          'data': data,
          'uploadedUrl': uploadedUrl,
        };
      }

      if (response.statusCode == 429) {
        final retryAfter = response.headers['retry-after'];
        final waitSeconds =
            int.tryParse(retryAfter ?? '') ?? (2 << (attempt - 1));
        if (attempt < maxRetries) {
          service._debugLogThrottled(
            'uploadAvatarToProfile:429',
            'BackendApiService.uploadAvatarToProfile: received 429, retrying in ${waitSeconds}s (attempt $attempt/$maxRetries)',
          );
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
        throw Exception('Too many requests (429) while uploading avatar.');
      }

      throw Exception(
        'Failed to upload avatar: ${response.statusCode} ${response.body}',
      );
    } catch (e, stackTrace) {
      if (_backendApiIsNodeNotWritableException(e) &&
          writeFailoverAttempt < maxWriteFailovers) {
        writeFailoverAttempt++;
        final responseBody = (e as BackendApiRequestException).body;
        final writeBaseUrl = _backendApiExtractPreferredWriteBaseUrl(responseBody);
        final currentUri = Uri.parse(
          '${failoverBaseUrl ?? service.baseUrl}/api/profiles/avatars',
        );

        if (_backendApiIsValidWriteFailoverUrl(currentUri, writeBaseUrl)) {
          service._debugLogThrottled(
            'uploadAvatarToProfile:failover',
            'BackendApiService.uploadAvatarToProfile: attempting write failover to $writeBaseUrl (attempt $writeFailoverAttempt/$maxWriteFailovers)',
          );
          failoverBaseUrl = writeBaseUrl;
          attempt = 0;
          continue;
        }

        service._debugLogThrottled(
          'uploadAvatarToProfile:failover:invalid',
          'BackendApiService.uploadAvatarToProfile: invalid or missing preferredWriteBaseUrl=$writeBaseUrl',
        );
        rethrow;
      }

      if (_backendApiIsNodeNotWritableException(e)) {
        rethrow;
      }

      if (attempt >= maxRetries) {
        service._debugLogThrottled(
          'uploadAvatarToProfile:error:final',
          'BackendApiService.uploadAvatarToProfile: error (final): $e\n$stackTrace',
          throttle: const Duration(seconds: 1),
        );
        rethrow;
      }

      final backoff = 1 << (attempt - 1);
      service._debugLogThrottled(
        'uploadAvatarToProfile:error:retry',
        'BackendApiService.uploadAvatarToProfile: transient error, retrying in ${backoff}s (attempt $attempt/$maxRetries): $e',
      );
      await Future.delayed(Duration(seconds: backoff));
    }
  }
}
