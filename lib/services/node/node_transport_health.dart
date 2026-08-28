import 'kubus_node_transport.dart';

/// What the resolver currently believes about one route.
enum KubusTransportHealth {
  /// Never attempted, or the previous verdict has expired.
  unknown,

  /// An attempt is in flight.
  connecting,

  /// Recently carried a request successfully.
  healthy,

  /// Working, but slow or intermittently failing.
  degraded,

  /// Failed and is not worth trying right now.
  unreachable,

  /// Failed repeatedly; suppressed until [TransportHealthRecord.cooldownUntil].
  cooldown,
}

/// Rolling health for a single transport.
///
/// Exists so the resolver can order candidates on evidence rather than on a
/// hard-coded guess, and so it does not aggressively probe every rung on every
/// request — which on a phone is a battery and radio cost, not just wasted
/// work.
class TransportHealthRecord {
  TransportHealthRecord({required this.kind});

  final KubusNodeTransportKind kind;

  KubusTransportHealth state = KubusTransportHealth.unknown;
  DateTime? lastSuccess;
  DateTime? lastFailure;
  DateTime? cooldownUntil;
  int consecutiveFailures = 0;

  /// Exponentially weighted mean round-trip, in milliseconds.
  ///
  /// A single slow request should nudge the estimate, not redefine it, so a
  /// one-off stall cannot demote an otherwise good route.
  double? latencyEwmaMs;

  static const double _ewmaAlpha = 0.3;

  /// Longest a route is suppressed after repeated failure.
  static const Duration maxCooldown = Duration(minutes: 2);

  void recordSuccess(Duration elapsed, DateTime now) {
    lastSuccess = now;
    consecutiveFailures = 0;
    cooldownUntil = null;
    final sample = elapsed.inMicroseconds / 1000.0;
    final previous = latencyEwmaMs;
    latencyEwmaMs = previous == null
        ? sample
        : (previous * (1 - _ewmaAlpha)) + (sample * _ewmaAlpha);
    state = KubusTransportHealth.healthy;
  }

  void recordFailure(DateTime now) {
    lastFailure = now;
    consecutiveFailures += 1;
    // Back off geometrically, capped. Two seconds after one failure is enough
    // to skip a route for the current burst without writing it off; a route
    // that keeps failing earns a real pause.
    final backoffSeconds = (1 << (consecutiveFailures - 1).clamp(0, 6)) * 2;
    final backoff = Duration(seconds: backoffSeconds);
    cooldownUntil = now.add(backoff < maxCooldown ? backoff : maxCooldown);
    state = consecutiveFailures >= 2
        ? KubusTransportHealth.cooldown
        : KubusTransportHealth.unreachable;
  }

  /// Whether this route may be attempted at [now].
  bool isEligible(DateTime now) {
    final until = cooldownUntil;
    if (until == null) return true;
    if (now.isBefore(until)) return false;
    // Cooldown served: allow one attempt to re-establish, without pretending
    // the route is known-good.
    cooldownUntil = null;
    state = KubusTransportHealth.unknown;
    return true;
  }

  /// Clears failure state after a network change.
  ///
  /// Moving between Wi-Fi and cellular invalidates every prior verdict: a LAN
  /// route that was unreachable a second ago may now be the right one, and a
  /// route that worked may now be gone. Keeping stale cooldowns would strand
  /// the user on a worse rung until they expired.
  void resetForNetworkChange() {
    state = KubusTransportHealth.unknown;
    consecutiveFailures = 0;
    cooldownUntil = null;
    latencyEwmaMs = null;
  }
}
