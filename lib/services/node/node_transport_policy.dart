import 'kubus_node_transport.dart';

/// What kind of work an operation is, in the terms routing actually cares about.
///
/// Not the HTTP verb: a status poll and a 400 MB capture upload are both
/// requests, and routing them identically is how a relay ends up carrying
/// traffic it should never have seen.
enum NodeOperationClass {
  /// Small, frequent, and worth failing fast on — status, info, job polling.
  /// Latency is the only thing that matters; nobody notices the bytes.
  interactive,

  /// A large upload. Throughput matters, the user is watching a progress bar,
  /// and the bytes are private capture data.
  bulkUpload,

  /// A large download — a reconstructed result coming back.
  bulkDownload,

  /// A mutation that changes durable state. Ordinary size, but the cost of
  /// getting it wrong is not ordinary.
  mutation,
}

/// Whether the app is in a position to keep a transfer alive.
enum AppActivityState {
  /// On screen. A user is waiting and long transfers are expected to run.
  foreground,

  /// Backgrounded. The OS may suspend sockets at any moment, so starting a
  /// large transfer that cannot survive suspension is worse than deferring it.
  background,
}

/// How the device is currently attached to the network.
///
/// Sourced from the platform rather than assumed. "Unknown" is a real answer
/// and is treated conservatively: it is what a platform that will not tell us
/// looks like, and guessing "unmetered" there is how someone's data plan pays
/// for a capture upload.
enum NetworkClass { wifi, ethernet, mobile, other, none, unknown }

extension NetworkClassX on NetworkClass {
  /// Whether the user plausibly pays per byte on this connection.
  ///
  /// Mobile is metered. Unknown is treated as metered, because the failure
  /// modes are asymmetric: wrongly assuming metered costs some speed, wrongly
  /// assuming unmetered costs the user money.
  bool get isMetered =>
      this == NetworkClass.mobile || this == NetworkClass.unknown;

  /// Whether a private-network address could plausibly reach the Node.
  ///
  /// A device on mobile data is not on the Node's LAN, so spending the first
  /// attempt there is a guaranteed timeout rather than a hopeful one.
  bool get canReachPrivateNetwork =>
      this == NetworkClass.wifi ||
      this == NetworkClass.ethernet ||
      this == NetworkClass.unknown;
}

/// What the resolver knows about the operation it is about to route.
///
/// Built per operation, not once per resolver. An instance describes one
/// request: how big it is, which direction the bytes move, whether the user is
/// watching, and what the device is attached to right now. A single context
/// held for a resolver's lifetime cannot answer any of those, which is what
/// made the earlier version unable to distinguish a status poll from a capture
/// upload.
class TransportSelectionContext {
  const TransportSelectionContext({
    this.operationClass = NodeOperationClass.interactive,
    this.expectedUploadBytes,
    this.expectedDownloadBytes,
    this.network = NetworkClass.unknown,
    this.activity = AppActivityState.foreground,
    this.supportsWebRtc = true,
    this.bulkTransferThresholdBytes = defaultBulkTransferThresholdBytes,
  });

  /// A cheap, latency-sensitive call.
  const TransportSelectionContext.interactive({
    NetworkClass network = NetworkClass.unknown,
    AppActivityState activity = AppActivityState.foreground,
    bool supportsWebRtc = true,
  }) : this(
          operationClass: NodeOperationClass.interactive,
          network: network,
          activity: activity,
          supportsWebRtc: supportsWebRtc,
        );

  final NodeOperationClass operationClass;

  /// Bytes this operation will send, when known.
  ///
  /// For a streamed upload this is the actual file length, which the caller
  /// always has — there is no reason to guess.
  final int? expectedUploadBytes;

  /// Bytes this operation will receive, when the size is known in advance.
  final int? expectedDownloadBytes;

  final NetworkClass network;
  final AppActivityState activity;

  /// Whether this build can open a peer connection at all.
  ///
  /// False on a platform without a WebRTC implementation, so the resolver
  /// omits those rungs rather than attempting and failing on every one.
  final bool supportsWebRtc;

  /// Above this, an operation counts as a bulk transfer.
  ///
  /// Configurable rather than a constant because the right value depends on
  /// relay bandwidth cost and on measurements this project has not finished
  /// taking. Treating the current number as settled would bake a guess into
  /// the routing rules.
  final int bulkTransferThresholdBytes;

  /// Starting value, to be revisited with real measurements.
  ///
  /// Relay bandwidth is paid for by whoever runs the relay, and a spatial
  /// capture is precisely the payload that turns "occasional fallback" into a
  /// standing bill.
  static const int defaultBulkTransferThresholdBytes = 8 * 1024 * 1024;

  int get totalBytes =>
      (expectedUploadBytes ?? 0) + (expectedDownloadBytes ?? 0);

  bool get isBulkTransfer =>
      operationClass == NodeOperationClass.bulkUpload ||
      operationClass == NodeOperationClass.bulkDownload ||
      totalBytes >= bulkTransferThresholdBytes;

  bool get isMeteredNetwork => network.isMetered;

  /// Whether the operation is worth a slower but working route.
  ///
  /// A mutation that has already been attempted must reach the Node; a status
  /// poll can simply fail and be retried in a second.
  bool get toleratesSlowRoute =>
      operationClass != NodeOperationClass.interactive;

  TransportSelectionContext copyWith({
    NodeOperationClass? operationClass,
    int? expectedUploadBytes,
    int? expectedDownloadBytes,
    NetworkClass? network,
    AppActivityState? activity,
    bool? supportsWebRtc,
    int? bulkTransferThresholdBytes,
  }) =>
      TransportSelectionContext(
        operationClass: operationClass ?? this.operationClass,
        expectedUploadBytes: expectedUploadBytes ?? this.expectedUploadBytes,
        expectedDownloadBytes:
            expectedDownloadBytes ?? this.expectedDownloadBytes,
        network: network ?? this.network,
        activity: activity ?? this.activity,
        supportsWebRtc: supportsWebRtc ?? this.supportsWebRtc,
        bulkTransferThresholdBytes:
            bulkTransferThresholdBytes ?? this.bulkTransferThresholdBytes,
      );
}

/// Decides which routes to prefer, and in what order.
///
/// Deliberately an interface rather than a constant. The correct order is not
/// yet known — it needs benchmarking on real networks — and it is unlikely to
/// be one answer for every client. A native app can reach a private address
/// directly; a browser often cannot, because private-network requests from
/// public origins are increasingly restricted. Encoding one order for both
/// would be wrong for at least one of them.
abstract class NodeTransportPolicy {
  const NodeTransportPolicy();

  /// Preferred order, best first. Routes omitted are not attempted.
  List<KubusNodeTransportKind> order(TransportSelectionContext context);

  /// Penalty added to a route's score. Lower sorts earlier.
  ///
  /// Lets a policy express "possible, but avoid" without removing a route
  /// outright — which matters because removing the last usable route means
  /// failing the operation entirely.
  int penaltyFor(
    KubusNodeTransportKind kind,
    TransportSelectionContext context,
  ) =>
      0;

  /// Shared relay reluctance, applied by every policy.
  ///
  /// A relay is the only rung that spends a third party's bandwidth, so the
  /// reasons to avoid it do not depend on which client is asking.
  static int relayPenalty(
    KubusNodeTransportKind kind,
    TransportSelectionContext context,
  ) {
    if (!kind.isRelayed) return 0;
    // Push a relay far down for bulk transfers, but never off the list: if it
    // is the only surviving route, a slow upload beats no upload.
    if (context.isBulkTransfer) return 5000;
    if (context.isMeteredNetwork) return 1000;
    return 0;
  }
}

/// Ordering for a native client (Android, iOS, desktop).
///
/// LAN first when the device could plausibly be on the Node's network: it is
/// the only route needing no internet, adds no hop, and keeps a capture inside
/// the user's own network. On mobile data that assumption is simply false, so
/// trying it first buys a guaranteed timeout — the rung is dropped rather than
/// merely deprioritised.
///
/// Relay last, always — it is both the slowest rung and the only one that
/// spends someone else's bandwidth.
///
/// This is a starting position to be measured, not a claim of optimality.
class NativeTransportPolicy extends NodeTransportPolicy {
  const NativeTransportPolicy();

  @override
  List<KubusNodeTransportKind> order(TransportSelectionContext context) {
    final order = <KubusNodeTransportKind>[
      if (context.network.canReachPrivateNetwork)
        KubusNodeTransportKind.localDirect,
      if (context.supportsWebRtc) KubusNodeTransportKind.webRtcDirect,
      KubusNodeTransportKind.remoteHttps,
      if (context.supportsWebRtc) KubusNodeTransportKind.webRtcRelay,
    ];
    // Never return nothing: a context that rules out every rung would fail the
    // operation before a single attempt, which is worse than one wasted try.
    return order.isEmpty
        ? const <KubusNodeTransportKind>[KubusNodeTransportKind.remoteHttps]
        : order;
  }

  @override
  int penaltyFor(
    KubusNodeTransportKind kind,
    TransportSelectionContext context,
  ) {
    var penalty = NodeTransportPolicy.relayPenalty(kind, context);
    // Backgrounded, a long transfer is likely to be suspended mid-flight.
    // Prefer the rung least sensitive to being torn down and resumed.
    if (context.activity == AppActivityState.background &&
        context.isBulkTransfer &&
        kind == KubusNodeTransportKind.webRtcDirect) {
      penalty += 250;
    }
    return penalty;
  }
}

/// Ordering for a browser client.
///
/// Direct private-network HTTP is not merely unreliable from a public origin —
/// as of Chrome 142 it triggers an explicit Local Network Access permission
/// prompt, and mixed-content rules block it outright on an HTTPS page. So a
/// browser must not spend its first attempt there. WebRTC is the route most
/// likely to work, and unlike the native case that is a property of the
/// platform rather than of the network.
///
/// Note that browser WebRTC does not recover LAN speed by itself: every major
/// browser obfuscates host ICE candidates behind random `.local` mDNS names by
/// default, so `webRtcDirect` between a browser and a Node on the same network
/// is not equivalent to reaching that Node's private address directly. The two
/// rungs are genuinely different, which is why both exist.
class BrowserTransportPolicy extends NodeTransportPolicy {
  const BrowserTransportPolicy();

  @override
  List<KubusNodeTransportKind> order(TransportSelectionContext context) {
    final order = <KubusNodeTransportKind>[
      if (context.supportsWebRtc) KubusNodeTransportKind.webRtcDirect,
      KubusNodeTransportKind.remoteHttps,
      // Last, and only where it could work at all: a permission prompt the
      // user has to answer is not something to spend on a status poll.
      if (context.network.canReachPrivateNetwork)
        KubusNodeTransportKind.localDirect,
      if (context.supportsWebRtc) KubusNodeTransportKind.webRtcRelay,
    ];
    return order.isEmpty
        ? const <KubusNodeTransportKind>[KubusNodeTransportKind.remoteHttps]
        : order;
  }

  @override
  int penaltyFor(
    KubusNodeTransportKind kind,
    TransportSelectionContext context,
  ) =>
      NodeTransportPolicy.relayPenalty(kind, context);
}
