import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../kubus_node_transport.dart';

/// How a peer connection turned out to be carried.
///
/// [undetermined] is a real state rather than a placeholder. ICE stats are
/// asked for the moment the connection reports connected, but the answer can
/// arrive after the data channel is already open and the identity proof has
/// already completed. Treating that window as "direct" is precisely how a
/// TURN-backed connection ends up registered as `webRtcDirect` and skips every
/// relay penalty for bulk and metered transfers.
enum KubusRtcRouteClass {
  /// Stats have not yet proved anything. Must be treated as relayed.
  undetermined,

  /// The selected candidate pair uses no relay on either side.
  direct,

  /// The selected candidate pair goes through a TURN relay.
  relayed,
}

extension KubusRtcRouteClassX on KubusRtcRouteClass {
  /// Whether stats have actually answered.
  bool get isSettled => this != KubusRtcRouteClass.undetermined;

  /// Whether this route must be charged relay penalties.
  ///
  /// Pessimistic: only a proven direct pair escapes them. An undetermined route
  /// costs some routing preference if it later turns out to be direct; a
  /// relayed route mistaken for direct spends a third party's bandwidth on a
  /// spatial capture, which is the failure worth preventing.
  bool get isRelayed => this != KubusRtcRouteClass.direct;

  /// The rung a route of this class may be registered as.
  KubusNodeTransportKind get transportKind => this == KubusRtcRouteClass.direct
      ? KubusNodeTransportKind.webRtcDirect
      : KubusNodeTransportKind.webRtcRelay;
}

/// Decides whether a peer connection is carried by a TURN relay.
///
/// Split out of `KubusRtcPeer` so the decision can be exercised against
/// scripted stats reports — no peer connection, no ICE, no platform plugin.
/// The interesting cases are the ones a live connection cannot be made to
/// produce on demand: stats that answer late, stats that never answer, and
/// stats that name a candidate pair whose candidate reports are missing.
///
/// Stats are polled rather than read once, because a report taken the instant
/// the connection reports connected routinely has no selected pair in it yet.
/// Polling stops the moment a verdict is reached, and [settle] guarantees a
/// verdict either way within its timeout.
class NodeRelayClassifier {
  NodeRelayClassifier({
    required Future<List<StatsReport>> Function() readStats,
    Duration pollInterval = defaultPollInterval,
    Duration settleTimeout = defaultSettleTimeout,
  })  : _readStats = readStats,
        _pollInterval = pollInterval,
        _settleTimeout = settleTimeout;

  /// How often stats are re-read while the verdict is still undetermined.
  static const Duration defaultPollInterval = Duration(milliseconds: 100);

  /// How long [settle] waits before deciding pessimistically.
  ///
  /// Generous relative to how long a connected peer takes to publish a
  /// selected candidate pair (milliseconds), and short relative to the
  /// connection and identity-proof deadlines, so a platform whose stats are
  /// broken delays a usable transport by seconds rather than blocking it.
  static const Duration defaultSettleTimeout = Duration(seconds: 3);

  final Future<List<StatsReport>> Function() _readStats;
  final Duration _pollInterval;
  final Duration _settleTimeout;

  final Completer<KubusRtcRouteClass> _settled =
      Completer<KubusRtcRouteClass>();

  Timer? _poll;
  bool _reading = false;
  bool _disposed = false;

  KubusRtcRouteClass _routeClass = KubusRtcRouteClass.undetermined;

  /// The verdict so far. [KubusRtcRouteClass.undetermined] until stats prove
  /// otherwise, and never revised once settled.
  KubusRtcRouteClass get routeClass => _routeClass;

  /// Whether the route must be charged relay penalties right now.
  bool get isRelayed => _routeClass.isRelayed;

  /// The rung this route may be registered as right now.
  KubusNodeTransportKind get transportKind => _routeClass.transportKind;

  /// Begins polling. Safe to call repeatedly; only the first call starts it.
  void start() {
    if (_disposed || _settled.isCompleted || _poll != null) return;
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(_read()));
    unawaited(_read());
  }

  /// Resolves to a settled verdict, never to [KubusRtcRouteClass.undetermined].
  ///
  /// On timeout the route settles to [KubusRtcRouteClass.relayed] and stays
  /// there: a bounded wait that ends in the pessimistic answer, rather than an
  /// unbounded one that could hold up connection setup, or an optimistic one
  /// that would quietly hand a relay the bulk-transfer routing of a direct
  /// link.
  Future<KubusRtcRouteClass> settle() {
    if (_settled.isCompleted) return _settled.future;
    start();
    return _settled.future.timeout(
      _settleTimeout,
      onTimeout: () {
        _finish(KubusRtcRouteClass.relayed);
        return KubusRtcRouteClass.relayed;
      },
    );
  }

  /// Stops polling and releases anyone waiting on [settle].
  ///
  /// Settles pessimistically when nothing had answered, so a caller awaiting a
  /// verdict for a connection that has since been torn down is released rather
  /// than left hanging until its own timeout.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finish(KubusRtcRouteClass.relayed);
  }

  Future<void> _read() async {
    if (_disposed || _settled.isCompleted || _reading) return;
    _reading = true;
    try {
      final verdict = classify(await _readStats());
      if (verdict.isSettled) _finish(verdict);
    } on Object {
      // A platform that will not answer leaves the route undetermined, which
      // `settle` already resolves conservatively. Never fail a working
      // connection over a diagnostics call.
    } finally {
      _reading = false;
    }
  }

  void _finish(KubusRtcRouteClass verdict) {
    _poll?.cancel();
    _poll = null;
    if (_settled.isCompleted) return;
    _routeClass = verdict;
    _settled.complete(verdict);
  }

  /// Reads a stats report into a verdict.
  ///
  /// Pure and static, so every shape a platform can produce is testable
  /// directly. Deliberately refuses to guess: a pair whose candidate reports
  /// are absent leaves the answer [KubusRtcRouteClass.undetermined] rather than
  /// defaulting to direct, because "we could not tell" and "no relay" are
  /// different facts and only one of them is safe to route on.
  static KubusRtcRouteClass classify(List<StatsReport> reports) {
    final pairs = <Map<dynamic, dynamic>>[];
    final candidates = <String, Map<dynamic, dynamic>>{};
    for (final report in reports) {
      switch (report.type) {
        case 'candidate-pair':
          pairs.add(report.values);
        case 'local-candidate':
        case 'remote-candidate':
          candidates[report.id] = report.values;
        default:
          break;
      }
    }

    // A nominated pair is the one actually carrying traffic. Where no pair is
    // marked — some platforms omit the field entirely — every succeeded pair is
    // considered, and any relay among them is enough to call the route
    // relayed.
    var active = pairs.where(_isNominated).toList();
    if (active.isEmpty) {
      active = pairs.where((pair) => pair['state'] == 'succeeded').toList();
    }
    if (active.isEmpty) return KubusRtcRouteClass.undetermined;

    var allResolved = true;
    for (final pair in active) {
      final local = _candidateFor(candidates, pair['localCandidateId']);
      final remote = _candidateFor(candidates, pair['remoteCandidateId']);
      if (local == null || remote == null) {
        allResolved = false;
        continue;
      }
      if (_isRelayCandidate(local) || _isRelayCandidate(remote)) {
        return KubusRtcRouteClass.relayed;
      }
    }
    return allResolved
        ? KubusRtcRouteClass.direct
        : KubusRtcRouteClass.undetermined;
  }

  static Map<dynamic, dynamic>? _candidateFor(
    Map<String, Map<dynamic, dynamic>> candidates,
    Object? id,
  ) =>
      id is String ? candidates[id] : null;

  static bool _isNominated(Map<dynamic, dynamic> pair) =>
      _isTrue(pair['selected']) || _isTrue(pair['nominated']);

  /// Platforms disagree on whether these flags are booleans or strings.
  static bool _isTrue(Object? value) => value == true || value == 'true';

  static bool _isRelayCandidate(Map<dynamic, dynamic> candidate) {
    final type = candidate['candidateType'];
    if (type == 'relay' || type == 'relayed') return true;
    // Only a relayed candidate carries a relay protocol, and some native
    // reports populate it while spelling `candidateType` differently.
    final relayProtocol = candidate['relayProtocol'];
    return relayProtocol is String && relayProtocol.isNotEmpty;
  }
}
