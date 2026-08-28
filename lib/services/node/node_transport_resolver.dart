import 'dart:async';
import 'dart:io';

import 'kubus_data_channel.dart';
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

/// Proves that a rung still reaches the paired Node, before anything is sent.
///
/// Runs *before* the request is handed to the transport, so a rung that can no
/// longer prove its identity never receives the Node credential or the request
/// body. Returning normally authorizes the send; throwing rejects the rung.
typedef NodeRungIdentityGuard = Future<void> Function(
  KubusNodeTransport transport,
  KubusNodeRequest request,
);

/// Chooses which route carries each Node operation.
///
/// Composite: it *is* a [KubusNodeTransport], so `KubusNodeService` and every
/// caller above it stay unchanged as rungs are added. The service keeps asking
/// for `/local/v1/...`; this decides how it gets there.
///
/// Three rules shape the policy:
///
/// 1. **A Node error is not a transport failure.** If the Node answers 503,
///    the route worked perfectly — it is the Node that is unhappy. Only a
///    connection-level fault (socket, timeout) demotes a route. Conflating
///    them would let one unhealthy Node poison every rung's health.
/// 2. **Failover must never duplicate work.** A request is only retried on
///    another route when [KubusNodeRequest.isSafeToRetry] allows it, so a
///    switch mid-flight cannot create a second capture or a second job.
/// 3. **Reachability is not identity.** A stored address can be reassigned by
///    DHCP or redirected by DNS, so [identityGuard] runs before each attempt
///    and a rung that fails it is skipped without anything being sent.
///
/// ## Resource ownership
///
/// A rung is *detached* by [adopt] replacing it or by [release] removing it.
/// Neither closes it: both hand it back, because the resolver did not build it
/// and cannot know what it shares. The HTTP rungs are built on one
/// `http.Client` that `KubusNodeService` also uses for pairing, identity
/// probes and content fetches, so closing a detached HTTP rung would close
/// that client and kill every remaining route. Whoever built a rung decides
/// how it dies. [close] is the one exception: it is whole-ladder teardown
/// performed by the ladder's owner, who is finished with the shared client at
/// the same moment.
class KubusNodeTransportResolver implements KubusNodeTransport {
  KubusNodeTransportResolver({
    required List<KubusNodeTransport> transports,
    NodeTransportPolicy? policy,
    TransportSelectionContext Function()? contextForOperation,
    DateTime Function()? clock,
  })  : _transports = List<KubusNodeTransport>.of(transports),
        _policy = policy ?? const NativeTransportPolicy(),
        _contextForOperation = contextForOperation ?? _defaultContext,
        _clock = clock ?? DateTime.now {
    for (final transport in _transports) {
      _health[transport.kind] = TransportHealthRecord(kind: transport.kind);
    }
  }

  /// Mutable because a WebRTC route cannot exist at construction time.
  ///
  /// The ladder is assembled during startup, but the WebRTC rungs need a
  /// signalling session, ICE credentials, and a completed identity proof —
  /// none of which are available then, and all of which can be lost and
  /// re-established while the app runs. Routes therefore join and leave a live
  /// resolver rather than being fixed once.
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

  /// Proves a rung still reaches the paired Node before anything is sent on it.
  ///
  /// Settable rather than constructor-injected because the ladder is assembled
  /// by `NodeTransportFactory` while the service that owns the paired identity
  /// is still constructing, so the guard cannot exist at that moment. Left
  /// null, every rung is trusted — which is only ever correct for a
  /// test-injected ladder that reaches nothing real.
  NodeRungIdentityGuard? identityGuard;

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
  ///
  /// A route that failed on the previous network says nothing about this one.
  /// Leaving it in cooldown is how a perfectly good LAN route stays out of
  /// consideration after the user walks back through their own front door.
  void onNetworkChanged() {
    for (final record in _health.values) {
      record.resetForNetworkChange();
    }
    _activeKind = null;
  }

  /// Adds a route that became available after construction.
  ///
  /// This is how a verified WebRTC transport joins the ladder: it can only be
  /// built once signalling has run and the Node has proved its identity, which
  /// is necessarily later than the moment the service was created.
  ///
  /// Returns the route of the same kind it displaced, if any, **without
  /// closing it** — see the ownership note on this class. Closing a displaced
  /// HTTP rung would close the `http.Client` every other route shares, so the
  /// caller that built the rung decides how it is disposed.
  ///
  /// Health is deliberately reset for the adopted kind: the new route is a
  /// different connection, and inheriting the failures of the one it replaces
  /// would put a working route straight into cooldown.
  KubusNodeTransport? adopt(KubusNodeTransport transport) {
    KubusNodeTransport? displaced;
    final existingIndex =
        _transports.indexWhere((candidate) => candidate.kind == transport.kind);
    if (existingIndex >= 0) {
      final previous = _transports[existingIndex];
      _transports[existingIndex] = transport;
      if (!identical(previous, transport)) displaced = previous;
    } else {
      _transports.add(transport);
    }
    _health[transport.kind] = TransportHealthRecord(kind: transport.kind);
    if (_activeKind == transport.kind) _activeKind = null;
    return displaced;
  }

  /// Removes a route that is no longer usable and returns it.
  ///
  /// Called when a peer connection drops, and when unpairing: leaving a dead
  /// transport in the list costs every subsequent operation a failed attempt
  /// before it falls through to a route that works, and leaving a rung from a
  /// previous pairing in the list is how the next Node's credential reaches
  /// the previous Node's address.
  ///
  /// The removed rung is returned rather than closed, for the same ownership
  /// reason as [adopt]. Returns null when no route of [kind] was present.
  KubusNodeTransport? release(KubusNodeTransportKind kind) {
    final index = _transports.indexWhere((candidate) => candidate.kind == kind);
    if (index < 0) return null;
    final removed = _transports.removeAt(index);
    _health.remove(kind);
    if (_activeKind == kind) _activeKind = null;
    return removed;
  }

  /// Whether a route of this kind is currently part of the ladder.
  bool hasTransport(KubusNodeTransportKind kind) =>
      _transports.any((candidate) => candidate.kind == kind);

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
    // Kept separately from [lastError]: a rung the guard rejected never
    // carried the request, so it says something quite different from a rung
    // that tried and failed. It is only surfaced when nothing else answered.
    Object? rejection;
    StackTrace? rejectionStack;

    for (final transport in ordered) {
      final record = _health[transport.kind]!;
      attempted.add(transport.kind);
      record.state = KubusTransportHealth.connecting;
      final guard = identityGuard;
      if (guard != null) {
        try {
          await guard(transport, request);
        } on Object catch (error, stack) {
          // Nothing left the process on this rung — not the credential, not
          // the body. Demote it and move to the next candidate, which is
          // proved independently rather than on this one's authority.
          record.recordFailure(_clock());
          rejection = error;
          rejectionStack = stack;
          continue;
        }
      }
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
    // Every rung was refused before it could be used. The guard's own reason
    // is far more useful than "unreachable" — it is the difference between
    // "your Node is offline" and "something else is answering at its address".
    if (rejection != null) {
      Error.throwWithStackTrace(
        rejection,
        rejectionStack ?? StackTrace.current,
      );
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
      error is KubusDataChannelClosedException ||
      error is KubusNodeUnreachableException;

  /// Terminal teardown of the whole ladder.
  ///
  /// Unlike [adopt] and [release], this *does* close every rung, including the
  /// HTTP ones that borrow a shared `http.Client`. That is only correct
  /// because the caller closing the ladder is the same owner that is finished
  /// with the client — closing one rung while the ladder keeps running is what
  /// [adopt] and [release] deliberately refuse to do.
  @override
  void close() {
    for (final transport in _transports) {
      transport.close();
    }
  }
}
