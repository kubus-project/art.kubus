import 'kubus_node_transport.dart';

/// What the resolver knows about the operation it is about to route.
///
/// Passed to a [NodeTransportPolicy] so ordering can respond to the situation
/// rather than being fixed once in code. Sending a 400 MB capture over a
/// metered connection is not the same decision as fetching a status line, and
/// pretending otherwise is how a relay ends up carrying traffic it never
/// should have seen.
class TransportSelectionContext {
  const TransportSelectionContext({
    this.payloadBytes,
    this.isMeteredNetwork = false,
  });

  /// Approximate bytes this operation will move, when known.
  final int? payloadBytes;

  /// Whether the device is on a connection the user pays per byte for.
  final bool isMeteredNetwork;

  /// Above this, an operation counts as a bulk transfer.
  ///
  /// Relay bandwidth is paid for by whoever runs the relay, and a spatial
  /// capture is precisely the payload that turns "occasional fallback" into a
  /// standing bill. The threshold is a policy input, not a hard rule: if a
  /// relay is genuinely the only route, a large transfer still goes over it.
  static const int bulkTransferThresholdBytes = 8 * 1024 * 1024;

  bool get isBulkTransfer => (payloadBytes ?? 0) >= bulkTransferThresholdBytes;
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
}

/// Ordering for a native client (Android, iOS, desktop).
///
/// LAN first: it is the only route needing no internet, adds no hop, and keeps
/// a capture inside the user's own network. Relay last, always — it is both
/// the slowest rung and the only one that spends someone else's bandwidth.
///
/// This is a starting position to be measured, not a claim of optimality.
class NativeTransportPolicy extends NodeTransportPolicy {
  const NativeTransportPolicy();

  @override
  List<KubusNodeTransportKind> order(TransportSelectionContext context) =>
      const <KubusNodeTransportKind>[
        KubusNodeTransportKind.localDirect,
        KubusNodeTransportKind.webRtcDirect,
        KubusNodeTransportKind.remoteHttps,
        KubusNodeTransportKind.webRtcRelay,
      ];

  @override
  int penaltyFor(
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

/// Ordering for a browser client.
///
/// Direct private-network HTTP is unreliable from a public origin — mixed
/// content and private-network-access restrictions frequently block it — so a
/// browser should not spend its first attempt there. WebRTC is the route most
/// likely to work, and unlike the native case that is a property of the
/// platform rather than of the network.
class BrowserTransportPolicy extends NodeTransportPolicy {
  const BrowserTransportPolicy();

  @override
  List<KubusNodeTransportKind> order(TransportSelectionContext context) =>
      const <KubusNodeTransportKind>[
        KubusNodeTransportKind.webRtcDirect,
        KubusNodeTransportKind.remoteHttps,
        KubusNodeTransportKind.localDirect,
        KubusNodeTransportKind.webRtcRelay,
      ];

  @override
  int penaltyFor(
    KubusNodeTransportKind kind,
    TransportSelectionContext context,
  ) {
    if (!kind.isRelayed) return 0;
    if (context.isBulkTransfer) return 5000;
    if (context.isMeteredNetwork) return 1000;
    return 0;
  }
}
