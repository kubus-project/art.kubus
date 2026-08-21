import 'dart:async';
import 'dart:io';

import 'kubus_node_transport.dart';
import 'node_transport_health.dart';
import 'node_transport_policy.dart';

/// Raised when no route to the paired Node could carry the request.
///
/// Distinct from a Node error: the Node was never reached, so nothing about
/// its state can be inferred.
class KubusNodeUnreachableException implements Exception {
  const KubusNodeUnreachableException(this.attempted);

  /// Rungs that were tried, in order.
  final List<KubusNodeTransportKind> attempted;

  @override
  String toString() =>
      'KubusNodeUnreachableException(tried: ${attempted.join(', ')})';
}

/// Chooses which route carries each Node operation.
///
/// Composite: it *is* a [KubusNodeTransport], so `KubusNodeService` and every
/// caller above it stay unchanged as rungs are added. The service keeps asking
/// for `/local/v1/...`; this decides how it gets there.
///
/// Two rules shape the policy:
///
/// 1. **A Node error is not a transport failure.** If the Node answers 503,
///    the route worked perfectly — it is the Node that is unhappy. Only a
///    connection-level fault (socket, timeout) demotes a route. Conflating
///    them would let one unhealthy Node poison every rung's health.
/// 2. **Failover must never duplicate work.** A request is only retried on
///    another route when [KubusNodeRequest.isSafeToRetry] allows it, so a
///    switch mid-flight cannot create a second capture or a second job.
class KubusNodeTransportResolver implements KubusNodeTransport {
  KubusNodeTransportResolver({
    required List<KubusNodeTransport> transports,
    NodeTransportPolicy? policy,
    TransportSelectionContext Function()? contextForOperation,
    DateTime Function()? clock,
  })  : _transports = List.unmodifiable(transports),
        _policy = policy ?? const NativeTransportPolicy(),
        _contextForOperation = contextForOperation ?? _defaultContext,
        _clock = clock ?? DateTime.now {
    for (final transport in _transports) {
      _health[transport.kind] = TransportHealthRecord(kind: transport.kind);
    }
  }

  final List<KubusNodeTransport> _transports;
  final DateTime Function() _clock;

  /// Decides ordering. Injected rather than fixed, because the right order is
  /// not yet measured and is unlikely to be the same for a native client and
  /// a browser — see [NodeTransportPolicy].
  final NodeTransportPolicy _policy;

  /// Supplies what the policy knows about the operation about to be routed.
  ///
  /// A function rather than a value: the answer changes between operations and
  /// between moments. Holding one context for the resolver's lifetime meant a
  /// 400 MB capture upload was routed with the same information as a status
  /// poll, and a switch from Wi-Fi to mobile data was invisible to routing
  /// until a route actually timed out.
  final TransportSelectionContext Function() _contextForOperation;

  /// Used when no supplier is injected. Conservative on purpose: an unknown
  /// network is treated as metered, and every rung stays available.
  static TransportSelectionContext _defaultContext() =>
      const TransportSelectionContext();

  final Map<KubusNodeTransportKind, TransportHealthRecord> _health =
      <KubusNodeTransportKind, TransportHealthRecord>{};

  /// The rung that last carried a request successfully, for diagnostics.
  KubusNodeTransportKind? get activeKind => _activeKind;
  KubusNodeTransportKind? _activeKind;

  /// Read-only health view, for the diagnostics surface.
  Map<KubusNodeTransportKind, TransportHealthRecord> get health =>
      Map.unmodifiable(_health);

  @override
  KubusNodeTransportKind get kind =>
      _activeKind ?? _policy.order(_contextForOperation()).first;

  @override
  bool get isAvailable => _transports.any((t) => t.isAvailable);

  /// Discards cached verdicts after the network changed underneath us.
  void onNetworkChanged() {
    for (final record in _health.values) {
      record.resetForNetworkChange();
    }
    _activeKind = null;
  }

  /// Candidates worth trying now for [context], best first.
  ///
  /// Takes the context explicitly so ordering is a pure function of the
  /// operation and the current health, which is what makes it testable without
  /// mutating resolver state between assertions.
  List<KubusNodeTransport> candidates([TransportSelectionContext? context]) {
    final resolved = context ?? _contextForOperation();
    final now = _clock();
    final order = _policy.order(resolved);
    final eligible = _transports
        .where((t) => t.isAvailable)
        // A route the policy omits entirely is not attempted at all.
        .where((t) => order.contains(t.kind))
        .where((t) => _health[t.kind]!.isEligible(now))
        .toList();
    eligible.sort(
      (a, b) =>
          _score(a, order, resolved).compareTo(_score(b, order, resolved)),
    );
    return eligible;
  }

  /// Lower is better. Deterministic, so ordering is testable.
  int _score(
    KubusNodeTransport transport,
    List<KubusNodeTransportKind> order,
    TransportSelectionContext context,
  ) {
    final record = _health[transport.kind]!;
    final base = order.indexOf(transport.kind) * 1000;
    final healthPenalty = switch (record.state) {
      KubusTransportHealth.healthy => 0,
      KubusTransportHealth.unknown => 100,
      KubusTransportHealth.connecting => 150,
      KubusTransportHealth.degraded => 300,
      KubusTransportHealth.unreachable => 600,
      KubusTransportHealth.cooldown => 900,
    };
    // Latency refines the choice but cannot outrank the structural preference,
    // so a fast relay never displaces a working direct route.
    final latencyPenalty =
        ((record.latencyEwmaMs ?? 0) / 50).clamp(0, 99).toInt();
    // The policy's own judgement — for example pushing a relay far down for a
    // bulk spatial transfer, without removing it as a last resort.
    final policyPenalty = _policy.penaltyFor(transport.kind, context);
    return base + healthPenalty + latencyPenalty + policyPenalty;
  }

  @override
  Future<KubusNodeResponse> request(KubusNodeRequest request) => _run(
        request,
        (transport) => transport.request(request),
        _contextForOperation().copyWith(
          operationClass: request.isSafeToRetry
              ? NodeOperationClass.interactive
              : NodeOperationClass.mutation,
        ),
      );

  @override
  Future<KubusNodeResponse> streamUpload(
    KubusNodeRequest request, {
    required File file,
    required String contentType,
  }) async {
    // The actual file length is known here, so routing never has to guess how
    // big this transfer is — which is the whole reason a relay can be pushed
    // down for a capture but not for a status poll.
    final length = await file.length();
    return _run(
      request,
      (transport) => transport.streamUpload(
        request,
        file: file,
        contentType: contentType,
      ),
      _contextForOperation().copyWith(
        operationClass: NodeOperationClass.bulkUpload,
        expectedUploadBytes: length,
      ),
    );
  }

  Future<KubusNodeResponse> _run(
    KubusNodeRequest request,
    Future<KubusNodeResponse> Function(KubusNodeTransport) operation,
    TransportSelectionContext context,
  ) async {
    final ordered = candidates(context);
    if (ordered.isEmpty) {
      throw const KubusNodeUnreachableException(<KubusNodeTransportKind>[]);
    }

    final attempted = <KubusNodeTransportKind>[];
    Object? lastError;
    StackTrace? lastStack;

    for (final transport in ordered) {
      final record = _health[transport.kind]!;
      attempted.add(transport.kind);
      record.state = KubusTransportHealth.connecting;
      final started = _clock();
      try {
        final response = await operation(transport);
        // The Node answered. Whatever it said, this route works.
        record.recordSuccess(_clock().difference(started), _clock());
        _activeKind = transport.kind;
        return response;
      } on Object catch (error, stack) {
        if (!_isTransportFailure(error)) {
          // The route delivered the request; the failure belongs to the Node
          // or the caller. Do not blame the transport, and do not try another
          // route only to get the same answer.
          record.recordSuccess(_clock().difference(started), _clock());
          _activeKind = transport.kind;
          rethrow;
        }
        record.recordFailure(_clock());
        lastError = error;
        lastStack = stack;
        if (!request.isSafeToRetry) {
          // Non-idempotent and already in flight: another route might succeed,
          // but it might also duplicate the work. Correctness wins.
          rethrow;
        }
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStack ?? StackTrace.current);
    }
    throw KubusNodeUnreachableException(attempted);
  }

  /// Whether [error] means the route failed, as opposed to the Node replying
  /// with something the caller dislikes.
  static bool _isTransportFailure(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is HandshakeException ||
      error is KubusNodeUnreachableException;

  @override
  void close() {
    for (final transport in _transports) {
      transport.close();
    }
  }
}
