import 'dart:convert';

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
    this.nodeId,
    this.publicKey,
    this.alternateEndpoints = const <Uri>[],
    this.version = 0,
  });
  final Uri endpoint;
  final String sessionId;
  final String secret;

  /// The Node's identity fingerprint, for a human to compare on screen.
  ///
  /// Derived from [publicKey]; it is a display convenience, never the thing
  /// that decides trust — anyone who has seen this QR can repeat a fingerprint.
  final String? fingerprint;
  final String? label;

  /// The Node's stable public identifier, used to reach it through the control
  /// plane when no direct address works.
  final String? nodeId;

  /// The Node's raw Ed25519 public key, base64url, 32 bytes.
  ///
  /// This is the only field in the payload that makes remote connection safe.
  /// Without it a device can confirm nothing about a peer that dials in later:
  /// endpoints move, fingerprints can be repeated, and a node id is public.
  /// With it, the device can demand a signature over a challenge it chose.
  final String? publicKey;

  /// Other addresses the same Node answers on, best-effort.
  final List<Uri> alternateEndpoints;

  /// Every address this payload offers, primary first, without repeats.
  ///
  /// Pairing walks this list in order, so the Node's own preferred address is
  /// tried before its alternates. Deduplicated because a Node that advertises
  /// its primary address again among its alternates should not cost the user a
  /// second connection attempt on the same host.
  List<Uri> get endpoints {
    final ordered = <Uri>[endpoint];
    for (final alternate in alternateEndpoints) {
      if (!ordered.contains(alternate)) ordered.add(alternate);
    }
    return List<Uri>.unmodifiable(ordered);
  }

  /// Payload schema version. v3 is the first to carry [publicKey].
  final int version;

  /// Whether this payload can support a verifiable remote connection.
  ///
  /// A payload without a public key can still pair over the local network,
  /// but the device will never be able to prove a remote peer's identity, so
  /// the Node must be re-paired before it can be reached from elsewhere.
  bool get supportsIdentityVerification =>
      (publicKey ?? '').isNotEmpty && version >= 3;

  /// Reads a scanned or pasted pairing code.
  ///
  /// The node's GUI encodes its QR as `kubus-node://pair?e=…&s=…&k=…`, which is
  /// what a camera returns. The JSON form is still accepted because it is what
  /// the node's pairing endpoint returns verbatim, and an operator who copies
  /// that response by hand should not be told it is invalid.
  factory KubusNodePairingPayload.parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) throw const FormatException('Empty pairing code');
    if (text.startsWith('kubus-node://')) {
      final uri = Uri.tryParse(text);
      if (uri == null) throw const FormatException('Invalid pairing code');
      final endpoint = Uri.tryParse(uri.queryParameters['e'] ?? '');
      final sessionId = (uri.queryParameters['s'] ?? '').trim();
      final secret = (uri.queryParameters['k'] ?? '').trim();
      final nodeId = (uri.queryParameters['n'] ?? '').trim();
      final fingerprint = (uri.queryParameters['f'] ?? '').trim();
      if (endpoint == null ||
          !endpoint.hasScheme ||
          !endpoint.hasAuthority ||
          sessionId.isEmpty ||
          secret.isEmpty ||
          nodeId.isEmpty ||
          fingerprint.isEmpty) {
        throw const FormatException('Invalid pairing code');
      }
      return KubusNodePairingPayload(
        endpoint: endpoint,
        sessionId: sessionId,
        secret: secret,
        fingerprint: fingerprint,
        label: uri.queryParameters['l'],
        nodeId: nodeId,
        publicKey: uri.queryParameters['pk'],
        alternateEndpoints: uri.queryParametersAll['a']
                ?.map(Uri.tryParse)
                .whereType<Uri>()
                .where((value) => value.hasScheme && value.hasAuthority)
                .toList(growable: false) ??
            const <Uri>[],
        version: int.tryParse(uri.queryParameters['v'] ?? '') ?? 0,
      );
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid pairing code');
    }
    return KubusNodePairingPayload.fromJson(decoded);
  }

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
      nodeId: (node['id'] ?? '').toString(),
      publicKey: (node['publicKey'] ?? '').toString(),
      alternateEndpoints:
          (node['endpoints'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => Uri.tryParse(value.toString()))
              .whereType<Uri>()
              .where((value) => value.hasScheme && value.hasAuthority)
              .where((value) => value != endpoint)
              .toList(growable: false),
      version: (json['version'] as num?)?.toInt() ?? 0,
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
  Map<String, dynamic> get participation =>
      status['participation'] is Map<String, dynamic>
          ? status['participation'] as Map<String, dynamic>
          : const {};
  String get participationState =>
      (participation['state'] ?? 'UNCONFIGURED').toString();
  bool get participationLeaseEligible => participation['leaseEligible'] == true;
}

class KubusComputeCandidate {
  const KubusComputeCandidate({
    required this.nodeId,
    required this.label,
    required this.encryptionPublicKey,
    required this.signingPublicKey,
    required this.gpu,
    required this.worker,
    required this.reliability,
    required this.queue,
    required this.rankScore,
  });

  final String nodeId;
  final String label;
  final String encryptionPublicKey;
  final String signingPublicKey;
  final Map<String, dynamic> gpu;
  final Map<String, dynamic> worker;
  final Map<String, dynamic> reliability;
  final Map<String, dynamic> queue;
  final double rankScore;

  int get totalVramBytes =>
      int.tryParse((gpu['totalVramBytes'] ?? 0).toString()) ?? 0;
  int get jobsAhead =>
      int.tryParse((queue['queued'] ?? queue['queuedJobs'] ?? 0).toString()) ??
      0;
  double get successRate =>
      double.tryParse(
        (reliability['successfulJobRate'] ?? reliability['successRate'] ?? 0)
            .toString(),
      ) ??
      0;

  factory KubusComputeCandidate.fromJson(Map<String, dynamic> json) =>
      KubusComputeCandidate(
        nodeId: (json['nodeId'] ?? '').toString(),
        label: (json['label'] ?? 'kubus Node').toString(),
        encryptionPublicKey: (json['encryptionPublicKey'] ?? '').toString(),
        signingPublicKey: (json['signingPublicKey'] ?? '').toString(),
        gpu: json['gpu'] is Map<String, dynamic>
            ? json['gpu'] as Map<String, dynamic>
            : const {},
        worker: json['worker'] is Map<String, dynamic>
            ? json['worker'] as Map<String, dynamic>
            : const {},
        reliability: json['reliability'] is Map<String, dynamic>
            ? json['reliability'] as Map<String, dynamic>
            : const {},
        queue: json['queue'] is Map<String, dynamic>
            ? json['queue'] as Map<String, dynamic>
            : const {},
        rankScore: double.tryParse((json['rankScore'] ?? 0).toString()) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'label': label,
        'encryptionPublicKey': encryptionPublicKey,
        'signingPublicKey': signingPublicKey,
        'gpu': gpu,
        'worker': worker,
        'reliability': reliability,
        'queue': queue,
        'rankScore': rankScore,
      };
}

class KubusRemoteComputeJob {
  const KubusRemoteComputeJob({
    required this.id,
    required this.state,
    required this.type,
    required this.protocolVersion,
    this.providerNodeId,
    this.outputManifestCid,
    this.outputCids = const [],
    this.failure,
  });

  final String id;
  final String state;
  final String type;
  final String protocolVersion;
  final String? providerNodeId;
  final String? outputManifestCid;
  final List<String> outputCids;
  final Map<String, dynamic>? failure;

  bool get isTerminal => const {
        'COMPLETED',
        'DECLINED',
        'EXPIRED',
        'FAILED',
        'CANCELLED',
        'DISPUTED',
      }.contains(state);

  factory KubusRemoteComputeJob.fromJson(Map<String, dynamic> json) =>
      KubusRemoteComputeJob(
        id: (json['id'] ?? '').toString(),
        state: (json['state'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        protocolVersion: (json['protocolVersion'] ?? '').toString(),
        providerNodeId: json['providerNodeId']?.toString(),
        outputManifestCid: json['outputManifestCid']?.toString(),
        outputCids: (json['outputCids'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        failure: json['failure'] is Map<String, dynamic>
            ? json['failure'] as Map<String, dynamic>
            : null,
      );
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

/// An in-flight streaming capture upload on the paired node.
///
/// The node holds drafts in memory, so a draft is a transfer in progress
/// rather than durable state: it is only meaningful until it is committed or
/// the node restarts.
class KubusCaptureDraft {
  const KubusCaptureDraft({
    required this.id,
    required this.fileCount,
    required this.sizeBytes,
    this.files = const <String>[],
  });

  final String id;
  final int fileCount;
  final int sizeBytes;

  /// Paths already uploaded. Populated by the progress endpoint, so a resumed
  /// transfer can skip what already landed.
  final List<String> files;

  factory KubusCaptureDraft.fromJson(Map<String, dynamic> json) =>
      KubusCaptureDraft(
        id: (json['id'] ?? '').toString(),
        fileCount: int.tryParse((json['fileCount'] ?? 0).toString()) ?? 0,
        sizeBytes: int.tryParse((json['sizeBytes'] ?? 0).toString()) ?? 0,
        files: (json['files'] as List<dynamic>? ?? const [])
            .map((entry) => entry.toString())
            .toList(growable: false),
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
    this.localPath,
  });
  final String role;
  final String cid;
  final int sizeBytes;
  final String mimeType;
  final String format;
  final String storageClass;

  /// Where this variant is cached on the device, once it has been downloaded.
  ///
  /// Null until the importer streams it to disk. It is a device-local path, so
  /// it is never sent back to the Node — only [cid] identifies the object
  /// there.
  final String? localPath;

  SpatialVariant copyWith({String? localPath}) => SpatialVariant(
        role: role,
        cid: cid,
        sizeBytes: sizeBytes,
        mimeType: mimeType,
        format: format,
        storageClass: storageClass,
        localPath: localPath ?? this.localPath,
      );

  factory SpatialVariant.fromJson(Map<String, dynamic> json) => SpatialVariant(
        role: (json['role'] ?? '').toString(),
        cid: (json['cid'] ?? '').toString(),
        sizeBytes: int.tryParse((json['sizeBytes'] ?? 0).toString()) ?? 0,
        mimeType: (json['mimeType'] ?? '').toString(),
        format: (json['format'] ?? '').toString(),
        storageClass: (json['storageClass'] ?? '').toString(),
        localPath: json['localPath']?.toString(),
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

class ArtworkSpatialCapture {
  const ArtworkSpatialCapture({
    required this.id,
    required this.artworkId,
    required this.capturedAt,
    required this.publishedAt,
    required this.version,
    required this.variants,
    required this.isCurrent,
    this.capturedBy,
    this.canonicalManifestCid,
    this.canonicalRecordCid,
  });

  final String id;
  final String artworkId;
  final DateTime capturedAt;
  final DateTime publishedAt;
  final int version;
  final List<SpatialVariant> variants;
  final bool isCurrent;
  final String? capturedBy;
  final String? canonicalManifestCid;
  final String? canonicalRecordCid;

  SpatialContent get content => SpatialContent(
        id: id,
        type: 'gaussianSplat',
        artworkId: artworkId,
        captureId: id,
        capturedAt: capturedAt,
        variants: variants,
      );

  factory ArtworkSpatialCapture.fromJson(Map<String, dynamic> json) {
    final capturedAt = DateTime.tryParse((json['capturedAt'] ?? '').toString());
    final publishedAt =
        DateTime.tryParse((json['publishedAt'] ?? '').toString());
    return ArtworkSpatialCapture(
      id: (json['id'] ?? '').toString(),
      artworkId: (json['artworkId'] ?? '').toString(),
      capturedAt: capturedAt ??
          publishedAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      publishedAt: publishedAt ??
          capturedAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      version: int.tryParse((json['version'] ?? 0).toString()) ?? 0,
      variants: (json['variants'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) =>
              SpatialVariant.fromJson(Map<String, dynamic>.from(value)))
          .where((variant) => variant.role != 'spatial_manifest')
          .toList(growable: false),
      isCurrent: json['isCurrent'] == true,
      capturedBy: (json['capturedBy'] ?? '').toString().trim().isEmpty
          ? null
          : json['capturedBy'].toString(),
      canonicalManifestCid: json['canonicalManifestCid']?.toString(),
      canonicalRecordCid: json['canonicalRecordCid']?.toString(),
    );
  }
}

class ArtworkSpatialHistory {
  const ArtworkSpatialHistory({required this.history});

  final List<ArtworkSpatialCapture> history;
  ArtworkSpatialCapture? get current =>
      history.where((capture) => capture.isCurrent).firstOrNull ??
      history.firstOrNull;

  factory ArtworkSpatialHistory.fromJson(Map<String, dynamic> json) =>
      ArtworkSpatialHistory(
        history: (json['history'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((value) => ArtworkSpatialCapture.fromJson(
                  Map<String, dynamic>.from(value),
                ))
            .toList(growable: false),
      );
}
