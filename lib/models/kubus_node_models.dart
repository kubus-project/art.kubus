enum KubusNodeConnectionState {
  unpaired,
  connecting,
  paired,
  unavailable,
  error,
}

class KubusNodePairingPayload {
  const KubusNodePairingPayload({
    required this.endpoint,
    required this.sessionId,
    required this.secret,
    this.fingerprint,
    this.label,
  });
  final Uri endpoint;
  final String sessionId;
  final String secret;
  final String? fingerprint;
  final String? label;

  factory KubusNodePairingPayload.fromJson(Map<String, dynamic> json) {
    final node = json['node'] is Map<String, dynamic>
        ? json['node'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final endpoint = Uri.tryParse(
      (node['endpoint'] ?? json['endpoint'] ?? '').toString(),
    );
    if (endpoint == null || !endpoint.hasScheme || !endpoint.hasAuthority) {
      throw const FormatException('Invalid kubus Node endpoint');
    }
    final sessionId = (json['sessionId'] ?? '').toString().trim();
    final secret = (json['secret'] ?? '').toString().trim();
    if (sessionId.isEmpty || secret.isEmpty) {
      throw const FormatException('Invalid pairing session');
    }
    return KubusNodePairingPayload(
      endpoint: endpoint,
      sessionId: sessionId,
      secret: secret,
      fingerprint: (node['fingerprint'] ?? '').toString(),
      label: (node['label'] ?? '').toString(),
    );
  }
}

class KubusNodeSnapshot {
  const KubusNodeSnapshot({
    required this.status,
    required this.capabilities,
    this.info = const {},
    this.worker = const {},
    this.storage = const {},
    this.network = const {},
  });
  final Map<String, dynamic> status;
  final List<Map<String, dynamic>> capabilities;
  final Map<String, dynamic> info;
  final Map<String, dynamic> worker;
  final Map<String, dynamic> storage;
  final Map<String, dynamic> network;
  bool capabilityAvailable(String name) => capabilities.any(
        (item) =>
            item['name'] == name &&
            item['available'] == true &&
            item['healthy'] == true,
      );
  int get runningJobs =>
      int.tryParse(
        (status['jobs'] is Map ? (status['jobs'] as Map)['running'] : 0)
            .toString(),
      ) ??
      0;
  int get queuedJobs =>
      int.tryParse(
        (status['jobs'] is Map ? (status['jobs'] as Map)['queued'] : 0)
            .toString(),
      ) ??
      0;
}

class KubusNodeJob {
  const KubusNodeJob({
    required this.id,
    required this.type,
    required this.state,
    required this.progress,
    this.input = const {},
    this.output,
    this.error,
  });
  final String id;
  final String type;
  final String state;
  final double progress;
  final Map<String, dynamic> input;
  final Map<String, dynamic>? output;
  final Map<String, dynamic>? error;
  factory KubusNodeJob.fromJson(Map<String, dynamic> json) => KubusNodeJob(
        id: (json['id'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        state: (json['state'] ?? '').toString(),
        progress: double.tryParse((json['progress'] ?? 0).toString()) ?? 0,
        input: json['input'] is Map<String, dynamic>
            ? json['input'] as Map<String, dynamic>
            : const {},
        output: json['output'] is Map<String, dynamic>
            ? json['output'] as Map<String, dynamic>
            : null,
        error: json['error'] is Map<String, dynamic>
            ? json['error'] as Map<String, dynamic>
            : null,
      );
}

class SpatialVariant {
  const SpatialVariant({
    required this.role,
    required this.cid,
    required this.sizeBytes,
    required this.mimeType,
    required this.format,
    required this.storageClass,
  });
  final String role;
  final String cid;
  final int sizeBytes;
  final String mimeType;
  final String format;
  final String storageClass;
  factory SpatialVariant.fromJson(Map<String, dynamic> json) => SpatialVariant(
        role: (json['role'] ?? '').toString(),
        cid: (json['cid'] ?? '').toString(),
        sizeBytes: int.tryParse((json['sizeBytes'] ?? 0).toString()) ?? 0,
        mimeType: (json['mimeType'] ?? '').toString(),
        format: (json['format'] ?? '').toString(),
        storageClass: (json['storageClass'] ?? '').toString(),
      );
}

class SpatialContent {
  const SpatialContent({
    required this.id,
    required this.type,
    required this.artworkId,
    required this.captureId,
    required this.capturedAt,
    required this.variants,
    this.markerId,
    this.transform,
    this.viewerDefaults = const {},
  });
  final String id;
  final String type;
  final String artworkId;
  final String? markerId;
  final String captureId;
  final DateTime capturedAt;
  final List<SpatialVariant> variants;
  final Map<String, dynamic>? transform;
  final Map<String, dynamic> viewerDefaults;
  factory SpatialContent.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 'kubus.spatial/1') {
      throw const FormatException('Unsupported spatial manifest');
    }
    return SpatialContent(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      artworkId: (json['artworkId'] ?? '').toString(),
      markerId: (json['markerId'] ?? '').toString().trim().isEmpty
          ? null
          : json['markerId'].toString(),
      captureId: (json['captureId'] ?? '').toString(),
      capturedAt: DateTime.parse(json['capturedAt'].toString()),
      variants: (json['variants'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SpatialVariant.fromJson)
          .toList(growable: false),
      transform: json['transform'] is Map<String, dynamic>
          ? json['transform'] as Map<String, dynamic>
          : null,
      viewerDefaults: json['viewerDefaults'] is Map<String, dynamic>
          ? json['viewerDefaults'] as Map<String, dynamic>
          : const {},
    );
  }
}
