import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ServicesBinding;
import 'package:http/http.dart' as http;

import 'http_node_transport.dart';
import 'kubus_node_transport.dart';
import 'node_transport_policy.dart';
import 'node_transport_resolver.dart';

/// Builds the transport a production app actually uses.
///
/// Until this existed, `KubusNodeService` defaulted to a single
/// `HttpNodeTransport` and the entire ladder — the resolver, the policy, the
/// health accounting, the WebRTC rungs — was unreachable from the running app.
/// Architecture that nothing constructs is not a feature; it is a plan. This
/// is the one place that turns it into the former.
///
/// Deliberately a factory rather than a constructor default: the WebRTC rungs
/// need a signalling client, an authenticated user, and ICE credentials, none
/// of which a service that may be built during early startup can assume. The
/// ladder is therefore assembled with whatever is genuinely available now, and
/// [KubusNodeTransportResolver.adopt] adds a verified WebRTC route later
/// without anything above noticing.
class NodeTransportFactory {
  const NodeTransportFactory._();

  /// Assembles the ladder for a paired Node.
  ///
  /// [endpoint] is the address recorded at pairing; [remoteEndpoint] is an
  /// operator-configured public HTTPS ingress when one exists. They are
  /// separate rungs even when they point at the same Node, because only one of
  /// them works from outside the user's network and only one of them avoids
  /// the public internet entirely.
  static KubusNodeTransportResolver build({
    required Uri Function() endpoint,
    required String? Function() credential,
    Uri? Function()? remoteEndpoint,
    http.Client? client,
    NodeTransportPolicy? policy,
    TransportSelectionContext Function()? contextForOperation,
  }) {
    final shared = client ?? http.Client();
    // A callback alone is not evidence that an ingress exists. Building a
    // remote rung whose endpoint falls back to the LAN address makes a phone
    // on mobile data spend its remote attempt on a guaranteed private-address
    // timeout, so include it only after a real HTTPS URL is present.
    final initialRemoteEndpoint = remoteEndpoint?.call();
    final transports = <KubusNodeTransport>[
      HttpNodeTransport(
        endpoint: endpoint,
        credential: credential,
        kind: KubusNodeTransportKind.localDirect,
        client: shared,
      ),
      if (initialRemoteEndpoint != null)
        HttpNodeTransport(
          // Resolved lazily so an operator can configure an ingress after
          // pairing without the app being rebuilt around it.
          endpoint: () => remoteEndpoint?.call() ?? initialRemoteEndpoint,
          credential: credential,
          kind: KubusNodeTransportKind.remoteHttps,
          client: shared,
        ),
    ];

    return KubusNodeTransportResolver(
      transports: transports,
      policy: policy ?? defaultPolicy(),
      contextForOperation: contextForOperation ?? NetworkContextSource().read,
    );
  }

  /// The ordering appropriate to this platform.
  ///
  /// Web gets a different policy for a concrete reason rather than a stylistic
  /// one: a page served over HTTPS cannot reach a private HTTP address without
  /// a Local Network Access prompt, and browser ICE hides host candidates
  /// behind mDNS names. See [BrowserTransportPolicy].
  static NodeTransportPolicy defaultPolicy() =>
      kIsWeb ? const BrowserTransportPolicy() : const NativeTransportPolicy();
}

/// Supplies routing context from the platform's real connectivity state.
///
/// `connectivity_plus` was already a dependency and was imported nowhere: the
/// resolver's `onNetworkChanged` hook existed with nothing to call it, so a
/// switch from Wi-Fi to mobile data stayed invisible to routing until a route
/// timed out. This closes that loop.
///
/// The reported class is cached rather than awaited per request, because
/// routing happens on the hot path of every operation and a platform-channel
/// round trip per request would be a real cost for information that changes
/// every few minutes at most.
class NetworkContextSource {
  NetworkContextSource({Connectivity? connectivity, bool? isWeb})
      : _connectivity = connectivity ?? Connectivity(),
        _isWeb = isWeb ?? kIsWeb;

  final Connectivity _connectivity;
  final bool _isWeb;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Starts unknown rather than optimistic.
  ///
  /// Unknown is treated as metered and as possibly-LAN-capable, which is the
  /// conservative pair: it avoids spending someone's data plan on a bulk
  /// transfer, without ruling out the local route before anything is known.
  NetworkClass _current = NetworkClass.unknown;

  NetworkClass get current => _current;

  AppActivityState activity = AppActivityState.foreground;

  /// Begins tracking, and reports every change to [onChanged].
  ///
  /// The callback is where the resolver invalidates stale route health: a
  /// route that failed on the previous network says nothing about this one,
  /// and leaving it in cooldown would keep a perfectly good LAN route out of
  /// consideration after the user walks back through their front door.
  Future<void> start({void Function(NetworkClass network)? onChanged}) async {
    await _refresh();
    if (_subscription != null) return;
    if (!_hasServicesBinding()) return;
    try {
      // On headless Dart tests (and during very early embedding startup) the
      // connectivity plugin can throw before a ServicesBinding exists. Route
      // selection must remain usable in that state: the already-conservative
      // `unknown` context is preferable to making Node initialization fail.
      _subscription = _connectivity.onConnectivityChanged.listen(
        (results) {
          final next = _classify(results);
          if (next == _current) return;
          _current = next;
          onChanged?.call(next);
        },
        // Platform channels can report a binding/plugin failure *after* the
        // subscription has been created. Do not let an optional diagnostics
        // signal turn a valid Node operation into an uncaught async error.
        onError: (_, __) {},
      );
    } on Object {
      // Keep the last successful snapshot (or `unknown`) and simply forgo
      // live changes until this service is reconstructed on a bound runtime.
    }
  }

  bool _hasServicesBinding() {
    try {
      // Accessing the binding is deliberately only a readiness probe. This
      // class must also work in pure-Dart/IO callers, where asking the plugin
      // to create its EventChannel would otherwise report an uncaught error.
      ServicesBinding.instance;
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _refresh() async {
    try {
      _current = _classify(await _connectivity.checkConnectivity());
    } on Object {
      // A platform that will not answer is left as unknown rather than being
      // guessed at. Every downstream decision already handles that safely.
      _current = NetworkClass.unknown;
    }
  }

  TransportSelectionContext read() => TransportSelectionContext(
        network: _current,
        activity: activity,
        // A browser build has WebRTC; every native platform this app ships on has
        // it through flutter_webrtc. The flag exists for the case where a target
        // genuinely lacks it, so it is answered from a real capability rather than
        // hardcoded true.
        supportsWebRtc:
            _isWeb || defaultTargetPlatform != TargetPlatform.fuchsia,
      );

  static NetworkClass _classify(List<ConnectivityResult> results) {
    if (results.isEmpty) return NetworkClass.unknown;
    if (results.contains(ConnectivityResult.none) && results.length == 1) {
      return NetworkClass.none;
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkClass.ethernet;
    }
    if (results.contains(ConnectivityResult.wifi)) return NetworkClass.wifi;
    if (results.contains(ConnectivityResult.mobile)) return NetworkClass.mobile;
    if (results.contains(ConnectivityResult.vpn)) {
      // A VPN hides what is underneath it. Treating it as "other" keeps the
      // metered assumption conservative without claiming to know the transport.
      return NetworkClass.other;
    }
    return NetworkClass.other;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
