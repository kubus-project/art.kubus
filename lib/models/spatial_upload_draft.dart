/// A prepared spatial asset stored privately for an artwork.
class SpatialUploadDraft {
  const SpatialUploadDraft({
    required this.id,
    required this.artworkId,
    required this.fileName,
    required this.format,
    required this.sizeBytes,
    required this.receivedBytes,
    required this.sha256,
    required this.chunkSizeBytes,
    required this.ready,
    this.lightweight,
  });

  /// Parses a draft. A reconstruction candidate may carry a `lightweight`
  /// companion (same shape, or null). It only ever shortens the preview, so a
  /// malformed one is dropped and the full draft stays usable.
  factory SpatialUploadDraft.fromJson(Map<String, dynamic> json) =>
      _parse(json, allowLightweight: true);

  static SpatialUploadDraft _parse(
    Map<String, dynamic> json, {
    required bool allowLightweight,
  }) {
    final size = json['sizeBytes'];
    final received = json['receivedBytes'];
    final chunkSize = json['chunkSizeBytes'];
    final state = json['state'];
    if (size is! int ||
        size <= 0 ||
        size > maxSizeBytes ||
        received is! int ||
        received < 0 ||
        received > size ||
        chunkSize is! int ||
        chunkSize <= 0 ||
        chunkSize > maxChunkSizeBytes ||
        (state != 'uploading' && state != 'ready') ||
        (state == 'ready' && received != size)) {
      throw const FormatException('Invalid spatial draft upload response');
    }
    SpatialUploadDraft? lightweight;
    final companion = json['lightweight'];
    if (allowLightweight && companion is Map) {
      try {
        lightweight = _parse(
          Map<String, dynamic>.from(companion),
          allowLightweight: false,
        );
      } on FormatException {
        lightweight = null;
      } on TypeError {
        lightweight = null;
      }
    }
    return SpatialUploadDraft(
      id: json['id'] as String,
      artworkId: json['artworkId'] as String,
      fileName: json['fileName'] as String,
      format: json['format'] as String,
      sizeBytes: size,
      receivedBytes: received,
      sha256: json['sha256'] as String,
      chunkSizeBytes: chunkSize,
      ready: state == 'ready',
      lightweight: lightweight,
    );
  }

  static const maxSizeBytes = 512 * 1024 * 1024;
  static const maxChunkSizeBytes = 4 * 1024 * 1024;
  static const formats = <String>{'ply', 'spz', 'splat', 'ksplat'};

  final String id;
  final String artworkId;
  final String fileName;
  final String format;
  final int sizeBytes;
  final int receivedBytes;
  final String sha256;
  final int chunkSizeBytes;
  final bool ready;

  /// The smaller preview companion of a candidate (SH degree 0, at most
  /// 20 MiB), or null when the candidate has none.
  final SpatialUploadDraft? lightweight;
}
