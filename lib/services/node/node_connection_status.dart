import 'kubus_node_transport.dart';
import 'node_transport_health.dart';
import 'node_transport_resolver.dart';

/// What the user is told about their Node's connection.
///
/// Deliberately coarse. A person wants to know whether they can process this
/// capture right now, and roughly where their Node is — not which NAT
/// traversal strategy won. Anything finer belongs in
/// [NodeConnectionDiagnostics], behind an explicit disclosure.
enum NodeConnectionStatus {
  /// No Node has been paired with this device.
  unpaired,

  /// Paired, and reachable on the local network.
  connectedNearby,

  /// Paired, and reachable from wherever the phone currently is.
  connectedRemotely,

  /// Paired, with an attempt in progress.
  connecting,

  /// Paired, but no route currently reaches it.
  offline,
}

extension NodeConnectionStatusX on NodeConnectionStatus {
  /// Whether a capture can be sent to the Node right now.
  bool get canProcess =>
      this == NodeConnectionStatus.connectedNearby ||
      this == NodeConnectionStatus.connectedRemotely;
}

/// The secondary, opt-in technical view (A22).
///
/// Separated from [NodeConnectionStatus] so that transport vocabulary cannot
/// leak into primary UI by accident: a screen that wants the headline can only
/// obtain the headline.
class NodeConnectionDiagnostics {
  const NodeConnectionDiagnostics({
    required this.activeKind,
    required this.usingRelay,
    required this.latencyMs,
    required this.routeHealth,
  });

  /// The rung currently carrying traffic, or null when nothing has succeeded.
  final KubusNodeTransportKind? activeKind;

  /// Whether traffic is being carried by a third-party relay.
  ///
  /// Worth surfacing because it is the one route with a cost and a privacy
  /// nuance the operator may care about — though even then the payload is
  /// encrypted and the Node identity is verified independently.
  final bool usingRelay;

  /// Smoothed round-trip for the active route, if measured.
  final double? latencyMs;

  final Map<KubusNodeTransportKind, KubusTransportHealth> routeHealth;
}

/// Derives what to show from what the resolver knows.
///
/// Pure and separately testable: no widget, no provider, no I/O.
class NodeConnectionPresenter {
  const NodeConnectionPresenter();

  /// The headline status.
  ///
  /// [isPaired] comes from the service rather than the resolver, because
  /// having routes configured is not the same as having a trust relationship
  /// with a Node — an unpaired device may still have a perfectly healthy LAN.
  NodeConnectionStatus statusFor({
    required bool isPaired,
    required KubusNodeTransportResolver resolver,
  }) {
    if (!isPaired) return NodeConnectionStatus.unpaired;

    final active = resolver.activeKind;
    if (active != null &&
        resolver.health[active]?.state == KubusTransportHealth.healthy) {
      return active == KubusNodeTransportKind.localDirect
          ? NodeConnectionStatus.connectedNearby
          // Every other rung is, from the user's point of view, "my Node,
          // somewhere else". Whether that is a direct peer connection, a
          // relay, or the operator's own HTTPS ingress changes nothing they
          // can act on.
          : NodeConnectionStatus.connectedRemotely;
    }

    final states = resolver.health.values.map((r) => r.state);
    if (states.any((s) => s == KubusTransportHealth.connecting)) {
      return NodeConnectionStatus.connecting;
    }
    // A route that has never been tried is not yet a failure: the honest
    // report while the ladder is still deciding is "connecting", not
    // "offline".
    if (states.any((s) => s == KubusTransportHealth.unknown) &&
        resolver.isAvailable) {
      return NodeConnectionStatus.connecting;
    }
    return NodeConnectionStatus.offline;
  }

  NodeConnectionDiagnostics diagnosticsFor(
    KubusNodeTransportResolver resolver,
  ) {
    final active = resolver.activeKind;
    return NodeConnectionDiagnostics(
      activeKind: active,
      usingRelay: active?.isRelayed ?? false,
      latencyMs: active == null ? null : resolver.health[active]?.latencyEwmaMs,
      routeHealth: <KubusNodeTransportKind, KubusTransportHealth>{
        for (final entry in resolver.health.entries)
          entry.key: entry.value.state,
      },
    );
  }
}
