import 'dart:typed_data';

export 'spatial_upload_source_stub.dart'
    if (dart.library.js_interop) 'spatial_upload_source_web.dart'
    show pickSpatialUploadFile, pickSpatialSourceMedia;

/// Owns a browser file handle and reads bounded byte ranges on demand.
class SpatialUploadSource {
  const SpatialUploadSource({
    required this.name,
    required this.size,
    required this.read,
  });

  final String name;
  final int size;
  final Future<Uint8List> Function(int start, int end) read;

  String get format =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
}
