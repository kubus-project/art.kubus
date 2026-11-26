class SpatialSourceFile {
  SpatialSourceFile.fromJson(Map<String, dynamic> value)
      : id = value['id'] as String,
        name = value['fileName'] as String,
        size = value['sizeBytes'] as int,
        received = value['receivedBytes'] as int,
        sha256 = value['sha256'] as String;

  final String id;
  final String name;
  final int size;
  final int received;
  final String sha256;

  bool get ready => received == size;
}

class SpatialSourceIntake {
  SpatialSourceIntake.fromJson(Map<String, dynamic> value)
      : maxBytes = value['maxSourceBytes'] as int,
        chunkSize = value['chunkSizeBytes'] as int,
        maxFiles = value['maxFiles'] as int,
        workspaceId = (value['workspace'] as Map?)?['id'] as String?,
        files = [
          for (final file
              in ((value['workspace'] as Map?)?['files'] as List? ?? const []))
            SpatialSourceFile.fromJson(file as Map<String, dynamic>),
        ];

  final int maxBytes;
  final int chunkSize;
  final int maxFiles;
  final String? workspaceId;
  final List<SpatialSourceFile> files;
}
