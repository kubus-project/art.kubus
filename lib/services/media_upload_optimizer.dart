import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path/path.dart' as path;

import '../config/config.dart';
import 'media_upload_video_optimizer_stub.dart'
    if (dart.library.io) 'media_upload_video_optimizer_io.dart';

typedef UploadCompressionPolicy = UploadCompressionPolicyDto;
typedef UploadCompressionProgress = UploadCompressionProgressDto;

enum UploadCompressionStage {
  queued,
  processing,
  skipped,
  done,
}

enum UploadCompressionKind {
  none,
  image,
  video,
  model,
}

class UploadCompressionPolicyDto {
  final bool enabled;
  final bool compressImages;
  final bool compressVideos;
  final bool optimizeModels;
  final int imageMinBytes;
  final int videoMinBytes;
  final int modelMinBytes;
  final int maxImageDimension;
  final int maxModelTextureDimension;
  final int imageQuality;
  final int modelTextureQuality;
  final int videoFrameRate;

  const UploadCompressionPolicyDto({
    this.enabled = true,
    this.compressImages = true,
    this.compressVideos = true,
    this.optimizeModels = true,
    this.imageMinBytes = AppConfig.clientUploadImageCompressionMinBytes,
    this.videoMinBytes = AppConfig.clientUploadVideoCompressionMinBytes,
    this.modelMinBytes = AppConfig.clientUploadModelCompressionMinBytes,
    this.maxImageDimension = AppConfig.clientUploadImageMaxDimension,
    this.maxModelTextureDimension =
        AppConfig.clientUploadModelTextureMaxDimension,
    this.imageQuality = AppConfig.clientUploadImageCompressionQuality,
    this.modelTextureQuality =
        AppConfig.clientUploadModelTextureCompressionQuality,
    this.videoFrameRate = AppConfig.clientUploadVideoFrameRate,
  });

  static const standard = UploadCompressionPolicyDto();

  static const noCompression = UploadCompressionPolicyDto(
    enabled: false,
    compressImages: false,
    compressVideos: false,
    optimizeModels: false,
  );

  UploadCompressionPolicyDto copyWith({
    bool? enabled,
    bool? compressImages,
    bool? compressVideos,
    bool? optimizeModels,
    int? imageMinBytes,
    int? videoMinBytes,
    int? modelMinBytes,
    int? maxImageDimension,
    int? maxModelTextureDimension,
    int? imageQuality,
    int? modelTextureQuality,
    int? videoFrameRate,
  }) {
    return UploadCompressionPolicyDto(
      enabled: enabled ?? this.enabled,
      compressImages: compressImages ?? this.compressImages,
      compressVideos: compressVideos ?? this.compressVideos,
      optimizeModels: optimizeModels ?? this.optimizeModels,
      imageMinBytes: imageMinBytes ?? this.imageMinBytes,
      videoMinBytes: videoMinBytes ?? this.videoMinBytes,
      modelMinBytes: modelMinBytes ?? this.modelMinBytes,
      maxImageDimension: maxImageDimension ?? this.maxImageDimension,
      maxModelTextureDimension:
          maxModelTextureDimension ?? this.maxModelTextureDimension,
      imageQuality: imageQuality ?? this.imageQuality,
      modelTextureQuality: modelTextureQuality ?? this.modelTextureQuality,
      videoFrameRate: videoFrameRate ?? this.videoFrameRate,
    );
  }
}

class UploadCompressionRequestDto {
  final Uint8List bytes;
  final String fileName;
  final String fileType;
  final String? contentType;
  final Map<String, String> metadata;
  final UploadCompressionPolicyDto policy;

  const UploadCompressionRequestDto({
    required this.bytes,
    required this.fileName,
    required this.fileType,
    this.contentType,
    this.metadata = const <String, String>{},
    this.policy = UploadCompressionPolicyDto.standard,
  });
}

class UploadCompressionProgressDto {
  final UploadCompressionStage stage;
  final String messageKey;
  final double? progress;

  const UploadCompressionProgressDto({
    required this.stage,
    required this.messageKey,
    this.progress,
  });
}

class UploadCompressionResultDto {
  final Uint8List bytes;
  final String fileName;
  final String? contentType;
  final UploadCompressionKind kind;
  final bool applied;
  final int originalBytes;
  final int finalBytes;
  final String? skippedReason;

  const UploadCompressionResultDto({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.kind,
    required this.applied,
    required this.originalBytes,
    required this.finalBytes,
    this.skippedReason,
  });

  factory UploadCompressionResultDto.skipped(
    UploadCompressionRequestDto request,
    String reason, {
    UploadCompressionKind kind = UploadCompressionKind.none,
  }) {
    return UploadCompressionResultDto(
      bytes: request.bytes,
      fileName: request.fileName,
      contentType: request.contentType,
      kind: kind,
      applied: false,
      originalBytes: request.bytes.length,
      finalBytes: request.bytes.length,
      skippedReason: reason,
    );
  }

  Map<String, String> toMetadataFields() {
    return <String, String>{
      'clientCompressionApplied': applied.toString(),
      'clientCompressionKind': kind.name,
      'clientCompressionOriginalBytes': originalBytes.toString(),
      'clientCompressionFinalBytes': finalBytes.toString(),
      if (skippedReason != null && skippedReason!.isNotEmpty)
        'clientCompressionSkippedReason': skippedReason!,
    };
  }
}

class MediaUploadOptimizer {
  final PlatformVideoUploadOptimizer _videoOptimizer;

  const MediaUploadOptimizer({
    PlatformVideoUploadOptimizer videoOptimizer =
        const PlatformVideoUploadOptimizer(),
  }) : _videoOptimizer = videoOptimizer;

  Future<UploadCompressionResultDto> optimize(
    UploadCompressionRequestDto request, {
    void Function(UploadCompressionProgressDto progress)? onProgress,
  }) async {
    if (!AppConfig.isFeatureEnabled('clientUploadCompression') ||
        !request.policy.enabled) {
      return UploadCompressionResultDto.skipped(request, 'disabled');
    }
    if (request.bytes.isEmpty) {
      return UploadCompressionResultDto.skipped(request, 'empty_file');
    }
    if (_isSvg(request)) {
      return UploadCompressionResultDto.skipped(request, 'svg_exempt');
    }
    if (_isArMarkerPng(request)) {
      return UploadCompressionResultDto.skipped(request, 'ar_marker_exempt');
    }

    onProgress?.call(const UploadCompressionProgressDto(
      stage: UploadCompressionStage.processing,
      messageKey: 'uploadCompressionProcessing',
      progress: 0,
    ));

    try {
      if (_isImage(request)) {
        return await _optimizeImage(request, onProgress: onProgress);
      }
      if (_isVideo(request)) {
        return await _optimizeVideo(request, onProgress: onProgress);
      }
      if (_isModel(request)) {
        return await _optimizeModel(request, onProgress: onProgress);
      }
      return UploadCompressionResultDto.skipped(request, 'unsupported_type');
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint('MediaUploadOptimizer.optimize failed: $e');
      }
      return UploadCompressionResultDto.skipped(
        request,
        'compression_failed',
      );
    }
  }

  Future<UploadCompressionResultDto> _optimizeImage(
    UploadCompressionRequestDto request, {
    void Function(UploadCompressionProgressDto progress)? onProgress,
  }) async {
    if (!request.policy.compressImages) {
      return UploadCompressionResultDto.skipped(
        request,
        'image_compression_disabled',
        kind: UploadCompressionKind.image,
      );
    }
    if (request.bytes.length < request.policy.imageMinBytes) {
      return UploadCompressionResultDto.skipped(
        request,
        'below_image_threshold',
        kind: UploadCompressionKind.image,
      );
    }
    if (_extension(request.fileName) == '.gif') {
      return UploadCompressionResultDto.skipped(
        request,
        'animated_image_exempt',
        kind: UploadCompressionKind.image,
      );
    }

    final compressed = await _compressRasterImage(
      request.bytes,
      fileName: request.fileName,
      contentType: request.contentType,
      maxDimension: request.policy.maxImageDimension,
      quality: request.policy.imageQuality,
    );
    return _smallerOrSkipped(
      request,
      compressed,
      kind: UploadCompressionKind.image,
      skippedReason: 'image_not_smaller',
      contentType: _contentTypeForImage(request),
    );
  }

  Future<UploadCompressionResultDto> _optimizeVideo(
    UploadCompressionRequestDto request, {
    void Function(UploadCompressionProgressDto progress)? onProgress,
  }) async {
    if (!request.policy.compressVideos) {
      return UploadCompressionResultDto.skipped(
        request,
        'video_compression_disabled',
        kind: UploadCompressionKind.video,
      );
    }
    if (request.bytes.length < request.policy.videoMinBytes) {
      return UploadCompressionResultDto.skipped(
        request,
        'below_video_threshold',
        kind: UploadCompressionKind.video,
      );
    }
    if (!_videoOptimizer.isSupported) {
      return UploadCompressionResultDto.skipped(
        request,
        'video_platform_unsupported',
        kind: UploadCompressionKind.video,
      );
    }

    final compressed = await _videoOptimizer.optimize(
      bytes: request.bytes,
      fileName: request.fileName,
      policy: request.policy,
      onProgress: onProgress,
    );
    if (compressed == null) {
      return UploadCompressionResultDto.skipped(
        request,
        'video_compression_failed',
        kind: UploadCompressionKind.video,
      );
    }
    if (compressed.bytes.length >= request.bytes.length) {
      return UploadCompressionResultDto.skipped(
        request,
        'video_not_smaller',
        kind: UploadCompressionKind.video,
      );
    }
    return UploadCompressionResultDto(
      bytes: compressed.bytes,
      fileName: compressed.fileName,
      contentType: compressed.contentType,
      kind: UploadCompressionKind.video,
      applied: true,
      originalBytes: request.bytes.length,
      finalBytes: compressed.bytes.length,
    );
  }

  Future<UploadCompressionResultDto> _optimizeModel(
    UploadCompressionRequestDto request, {
    void Function(UploadCompressionProgressDto progress)? onProgress,
  }) async {
    if (!request.policy.optimizeModels) {
      return UploadCompressionResultDto.skipped(
        request,
        'model_optimization_disabled',
        kind: UploadCompressionKind.model,
      );
    }
    if (request.bytes.length < request.policy.modelMinBytes) {
      return UploadCompressionResultDto.skipped(
        request,
        'below_model_threshold',
        kind: UploadCompressionKind.model,
      );
    }

    final ext = _extension(request.fileName);
    if (ext == '.usdz' || ext == '.zip') {
      return UploadCompressionResultDto.skipped(
        request,
        'model_format_exempt',
        kind: UploadCompressionKind.model,
      );
    }

    Uint8List? optimized;
    if (ext == '.glb' || _looksLikeGlb(request.bytes)) {
      optimized = await _optimizeGlb(request.bytes, request.policy);
    } else if (ext == '.gltf') {
      optimized = await _optimizeGltfJson(request.bytes, request.policy);
    }
    return _smallerOrSkipped(
      request,
      optimized,
      kind: UploadCompressionKind.model,
      skippedReason: 'model_not_smaller_or_safe',
      contentType: request.contentType,
    );
  }

  Future<Uint8List?> _compressRasterImage(
    Uint8List bytes, {
    required String fileName,
    String? contentType,
    required int maxDimension,
    required int quality,
  }) async {
    final decoded = image_lib.decodeImage(bytes);
    if (decoded == null) return null;
    final target = _targetSize(decoded.width, decoded.height, maxDimension);
    final format = _imageCompressFormat(fileName, contentType);
    Uint8List? pluginResult;

    if (format != null) {
      try {
        pluginResult = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: target.width,
          minHeight: target.height,
          quality: quality,
          format: format,
          keepExif: false,
        );
      } catch (_) {
        pluginResult = null;
      }
    }
    if (pluginResult != null && pluginResult.isNotEmpty) {
      return pluginResult;
    }

    final resized =
        target.width == decoded.width && target.height == decoded.height
            ? decoded
            : image_lib.copyResize(
                decoded,
                width: target.width,
                height: target.height,
                interpolation: image_lib.Interpolation.average,
              );

    final ext = _extension(fileName);
    if (ext == '.png' || contentType == 'image/png') {
      return Uint8List.fromList(image_lib.encodePng(resized, level: 6));
    }
    if (ext == '.jpg' || ext == '.jpeg' || contentType == 'image/jpeg') {
      return Uint8List.fromList(image_lib.encodeJpg(resized, quality: quality));
    }
    return null;
  }

  Future<Uint8List?> _optimizeGltfJson(
    Uint8List bytes,
    UploadCompressionPolicyDto policy,
  ) async {
    final source = utf8.decode(bytes, allowMalformed: false);
    final parsed = jsonDecode(source);
    if (parsed is! Map<String, dynamic>) return null;
    final changed = await _optimizeEmbeddedDataUriImages(parsed, policy);
    if (!changed) return null;
    return Uint8List.fromList(utf8.encode(jsonEncode(parsed)));
  }

  Future<Uint8List?> _optimizeGlb(
    Uint8List bytes,
    UploadCompressionPolicyDto policy,
  ) async {
    final parsed = _parseGlb(bytes);
    if (parsed == null) return null;
    final jsonMap = parsed.jsonMap;
    var changed = await _optimizeEmbeddedDataUriImages(jsonMap, policy);
    final bin = parsed.binChunk;
    if (bin != null) {
      final rebuiltBin =
          await _optimizeGlbBufferViewImages(jsonMap, bin, policy);
      if (rebuiltBin != null) {
        parsed.binChunk = rebuiltBin;
        changed = true;
      }
    }
    if (!changed) return null;
    return _buildGlb(jsonMap, parsed.binChunk, parsed.trailingChunks);
  }

  Future<bool> _optimizeEmbeddedDataUriImages(
    Map<String, dynamic> jsonMap,
    UploadCompressionPolicyDto policy,
  ) async {
    final images = jsonMap['images'];
    if (images is! List) return false;
    var changed = false;
    for (final entry in images) {
      if (entry is! Map<String, dynamic>) continue;
      final uri = entry['uri'];
      if (uri is! String || !uri.startsWith('data:image/')) continue;
      final comma = uri.indexOf(',');
      if (comma <= 0 || !uri.substring(0, comma).contains(';base64')) {
        continue;
      }
      final header = uri.substring(0, comma);
      final mime = header.substring('data:'.length, header.indexOf(';'));
      if (mime != 'image/jpeg' && mime != 'image/png') continue;

      final raw = base64Decode(uri.substring(comma + 1));
      final optimized = await _compressRasterImage(
        Uint8List.fromList(raw),
        fileName: mime == 'image/png' ? 'texture.png' : 'texture.jpg',
        contentType: mime,
        maxDimension: policy.maxModelTextureDimension,
        quality: policy.modelTextureQuality,
      );
      if (optimized == null || optimized.length >= raw.length) continue;
      entry['uri'] = '$header,${base64Encode(optimized)}';
      changed = true;
    }
    return changed;
  }

  Future<Uint8List?> _optimizeGlbBufferViewImages(
    Map<String, dynamic> jsonMap,
    Uint8List bin,
    UploadCompressionPolicyDto policy,
  ) async {
    final images = jsonMap['images'];
    final bufferViews = jsonMap['bufferViews'];
    if (images is! List || bufferViews is! List) return null;

    final replacements = <int, Uint8List>{};
    for (final entry in images) {
      if (entry is! Map<String, dynamic>) continue;
      final viewIndex = entry['bufferView'];
      final mime = entry['mimeType'];
      if (viewIndex is! int || mime is! String) continue;
      if (mime != 'image/jpeg' && mime != 'image/png') continue;
      if (viewIndex < 0 || viewIndex >= bufferViews.length) continue;
      final view = bufferViews[viewIndex];
      if (view is! Map<String, dynamic>) continue;
      final offset = (view['byteOffset'] as num?)?.toInt() ?? 0;
      final length = (view['byteLength'] as num?)?.toInt();
      if (length == null ||
          offset < 0 ||
          length <= 0 ||
          offset + length > bin.length) {
        continue;
      }
      final raw = Uint8List.sublistView(bin, offset, offset + length);
      final optimized = await _compressRasterImage(
        raw,
        fileName: mime == 'image/png' ? 'texture.png' : 'texture.jpg',
        contentType: mime,
        maxDimension: policy.maxModelTextureDimension,
        quality: policy.modelTextureQuality,
      );
      if (optimized == null || optimized.length >= raw.length) continue;
      replacements[viewIndex] = optimized;
    }
    if (replacements.isEmpty) return null;

    final rebuilt = _rebuildBinaryChunkWithBufferViewReplacements(
      jsonMap,
      bin,
      replacements,
    );
    if (rebuilt == null) return null;
    jsonMap['buffers'] = _updatedBuffers(jsonMap, rebuilt.length);
    return rebuilt;
  }

  UploadCompressionResultDto _smallerOrSkipped(
    UploadCompressionRequestDto request,
    Uint8List? candidate, {
    required UploadCompressionKind kind,
    required String skippedReason,
    String? contentType,
  }) {
    if (candidate == null ||
        candidate.isEmpty ||
        candidate.length >= request.bytes.length) {
      return UploadCompressionResultDto.skipped(
        request,
        skippedReason,
        kind: kind,
      );
    }
    return UploadCompressionResultDto(
      bytes: candidate,
      fileName: request.fileName,
      contentType: contentType ?? request.contentType,
      kind: kind,
      applied: true,
      originalBytes: request.bytes.length,
      finalBytes: candidate.length,
    );
  }

  _ImageSize _targetSize(int width, int height, int maxDimension) {
    if (maxDimension <= 0 ||
        (width <= maxDimension && height <= maxDimension)) {
      return _ImageSize(width, height);
    }
    final scale = maxDimension / math.max(width, height);
    return _ImageSize(
      math.max(1, (width * scale).round()),
      math.max(1, (height * scale).round()),
    );
  }

  CompressFormat? _imageCompressFormat(String fileName, String? contentType) {
    final normalizedContentType = (contentType ?? '').toLowerCase();
    final ext = _extension(fileName);
    if (normalizedContentType == 'image/png' || ext == '.png') {
      return CompressFormat.png;
    }
    if (normalizedContentType == 'image/webp' || ext == '.webp') {
      return CompressFormat.webp;
    }
    if (normalizedContentType == 'image/jpeg' ||
        ext == '.jpg' ||
        ext == '.jpeg') {
      return CompressFormat.jpeg;
    }
    return null;
  }

  String? _contentTypeForImage(UploadCompressionRequestDto request) {
    final ext = _extension(request.fileName);
    if (ext == '.png') return 'image/png';
    if (ext == '.webp') return 'image/webp';
    if (ext == '.jpg' || ext == '.jpeg') return 'image/jpeg';
    return request.contentType;
  }

  bool _isSvg(UploadCompressionRequestDto request) {
    return request.contentType == 'image/svg+xml' ||
        _extension(request.fileName) == '.svg';
  }

  bool _isArMarkerPng(UploadCompressionRequestDto request) {
    final source = (request.metadata['source'] ?? '').toLowerCase();
    final kind = (request.metadata['kind'] ?? '').toLowerCase();
    final entity = (request.metadata['entity'] ?? '').toLowerCase();
    return _extension(request.fileName) == '.png' &&
        (source.contains('ar_marker') ||
            kind == 'ar_marker' ||
            entity == 'ar_marker');
  }

  bool _isImage(UploadCompressionRequestDto request) {
    final fileType = request.fileType.toLowerCase();
    final contentType = (request.contentType ?? '').toLowerCase();
    final ext = _extension(request.fileName);
    return fileType == 'image' ||
        fileType.endsWith('-image') ||
        contentType.startsWith('image/') ||
        const {'.jpg', '.jpeg', '.png', '.webp', '.gif'}.contains(ext);
  }

  bool _isVideo(UploadCompressionRequestDto request) {
    final fileType = request.fileType.toLowerCase();
    final contentType = (request.contentType ?? '').toLowerCase();
    final ext = _extension(request.fileName);
    return fileType == 'video' ||
        fileType.endsWith('-video') ||
        contentType.startsWith('video/') ||
        const {'.mp4', '.mov', '.avi', '.webm'}.contains(ext);
  }

  bool _isModel(UploadCompressionRequestDto request) {
    final fileType = request.fileType.toLowerCase();
    final contentType = (request.contentType ?? '').toLowerCase();
    final ext = _extension(request.fileName);
    return fileType == 'model' ||
        contentType.startsWith('model/') ||
        const {'.glb', '.gltf', '.usdz', '.zip'}.contains(ext) ||
        _looksLikeGlb(request.bytes);
  }

  String _extension(String fileName) => path.extension(fileName).toLowerCase();

  bool _looksLikeGlb(Uint8List bytes) {
    if (bytes.length < 4) return false;
    final data = ByteData.sublistView(bytes);
    return data.getUint32(0, Endian.little) == _glbMagic;
  }
}

const int _glbMagic = 0x46546c67;
const int _glbVersion = 2;
const int _glbJsonChunkType = 0x4e4f534a;
const int _glbBinChunkType = 0x004e4942;

class _ImageSize {
  final int width;
  final int height;

  const _ImageSize(this.width, this.height);
}

class _GlbChunk {
  final int type;
  final Uint8List data;

  const _GlbChunk(this.type, this.data);
}

class _ParsedGlb {
  final Map<String, dynamic> jsonMap;
  Uint8List? binChunk;
  final List<_GlbChunk> trailingChunks;

  _ParsedGlb({
    required this.jsonMap,
    required this.binChunk,
    required this.trailingChunks,
  });
}

_ParsedGlb? _parseGlb(Uint8List bytes) {
  if (bytes.length < 20) return null;
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(0, Endian.little) != _glbMagic) return null;
  if (data.getUint32(4, Endian.little) != _glbVersion) return null;
  final declaredLength = data.getUint32(8, Endian.little);
  if (declaredLength > bytes.length) return null;

  var offset = 12;
  Map<String, dynamic>? jsonMap;
  Uint8List? binChunk;
  final trailing = <_GlbChunk>[];
  while (offset + 8 <= declaredLength) {
    final chunkLength = data.getUint32(offset, Endian.little);
    final chunkType = data.getUint32(offset + 4, Endian.little);
    offset += 8;
    if (chunkLength < 0 || offset + chunkLength > declaredLength) return null;
    final chunkData =
        Uint8List.sublistView(bytes, offset, offset + chunkLength);
    offset += chunkLength;
    if (chunkType == _glbJsonChunkType) {
      final jsonText = utf8.decode(chunkData).trimRight();
      final parsed = jsonDecode(jsonText);
      if (parsed is! Map<String, dynamic>) return null;
      jsonMap = parsed;
    } else if (chunkType == _glbBinChunkType && binChunk == null) {
      binChunk = Uint8List.fromList(chunkData);
    } else {
      trailing.add(_GlbChunk(chunkType, Uint8List.fromList(chunkData)));
    }
  }
  if (jsonMap == null) return null;
  return _ParsedGlb(
      jsonMap: jsonMap, binChunk: binChunk, trailingChunks: trailing);
}

Uint8List? _rebuildBinaryChunkWithBufferViewReplacements(
  Map<String, dynamic> jsonMap,
  Uint8List bin,
  Map<int, Uint8List> replacements,
) {
  final bufferViews = jsonMap['bufferViews'];
  if (bufferViews is! List) return null;

  final views = <_BufferViewRecord>[];
  for (var i = 0; i < bufferViews.length; i++) {
    final view = bufferViews[i];
    if (view is! Map<String, dynamic>) continue;
    final buffer = (view['buffer'] as num?)?.toInt() ?? 0;
    if (buffer != 0) continue;
    final offset = (view['byteOffset'] as num?)?.toInt() ?? 0;
    final length = (view['byteLength'] as num?)?.toInt();
    if (length == null ||
        offset < 0 ||
        length < 0 ||
        offset + length > bin.length) {
      return null;
    }
    views.add(_BufferViewRecord(i, offset, length));
  }
  views.sort((a, b) => a.offset.compareTo(b.offset));
  for (var i = 1; i < views.length; i++) {
    if (views[i].offset < views[i - 1].offset + views[i - 1].length) {
      return null;
    }
  }

  final out = BytesBuilder(copy: false);
  var cursor = 0;
  for (final view in views) {
    if (cursor < view.offset) {
      out.add(Uint8List.sublistView(bin, cursor, view.offset));
    }
    _addAlignmentPadding(out, 4);
    final newOffset = out.length;
    final replacement = replacements[view.index];
    final bytes = replacement ??
        Uint8List.sublistView(bin, view.offset, view.offset + view.length);
    out.add(bytes);
    final jsonView = bufferViews[view.index] as Map<String, dynamic>;
    jsonView['byteOffset'] = newOffset;
    jsonView['byteLength'] = bytes.length;
    cursor = view.offset + view.length;
  }
  if (cursor < bin.length) {
    out.add(Uint8List.sublistView(bin, cursor));
  }
  return out.toBytes();
}

void _addAlignmentPadding(BytesBuilder out, int alignment) {
  final remainder = out.length % alignment;
  if (remainder == 0) return;
  out.add(Uint8List(alignment - remainder));
}

List<dynamic> _updatedBuffers(Map<String, dynamic> jsonMap, int byteLength) {
  final buffers = jsonMap['buffers'];
  if (buffers is List && buffers.isNotEmpty) {
    final next = buffers.map((buffer) {
      if (buffer is Map<String, dynamic>) {
        return <String, dynamic>{...buffer};
      }
      return buffer;
    }).toList();
    final first = next.first;
    if (first is Map<String, dynamic>) {
      first['byteLength'] = byteLength;
    }
    return next;
  }
  return <Map<String, dynamic>>[
    <String, dynamic>{'byteLength': byteLength},
  ];
}

Uint8List _buildGlb(
  Map<String, dynamic> jsonMap,
  Uint8List? binChunk,
  List<_GlbChunk> trailingChunks,
) {
  final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(jsonMap)));
  final chunks = <_GlbChunk>[
    _GlbChunk(_glbJsonChunkType, _padBytes(jsonBytes, 0x20)),
    if (binChunk != null)
      _GlbChunk(_glbBinChunkType, _padBytes(binChunk, 0x00)),
    ...trailingChunks
        .map((chunk) => _GlbChunk(chunk.type, _padBytes(chunk.data, 0x00))),
  ];
  final totalLength =
      12 + chunks.fold<int>(0, (sum, chunk) => sum + 8 + chunk.data.length);
  final out = BytesBuilder(copy: false);
  final header = ByteData(12)
    ..setUint32(0, _glbMagic, Endian.little)
    ..setUint32(4, _glbVersion, Endian.little)
    ..setUint32(8, totalLength, Endian.little);
  out.add(header.buffer.asUint8List());
  for (final chunk in chunks) {
    final chunkHeader = ByteData(8)
      ..setUint32(0, chunk.data.length, Endian.little)
      ..setUint32(4, chunk.type, Endian.little);
    out.add(chunkHeader.buffer.asUint8List());
    out.add(chunk.data);
  }
  return out.toBytes();
}

Uint8List _padBytes(Uint8List input, int padByte) {
  final remainder = input.length % 4;
  if (remainder == 0) return input;
  final padded = Uint8List(input.length + (4 - remainder));
  padded.setAll(0, input);
  for (var i = input.length; i < padded.length; i++) {
    padded[i] = padByte;
  }
  return padded;
}

class _BufferViewRecord {
  final int index;
  final int offset;
  final int length;

  const _BufferViewRecord(this.index, this.offset, this.length);
}
