import 'dart:collection';

/// Media URLs that recently failed to load, shared by the surfaces that draw
/// the same artwork media (map marker covers, the marker quick card, ...).
///
/// Flutter's image cache does not keep failed loads, so a widget that rebuilds
/// while showing a broken image (a quick card following its marker, a list
/// re-laying out) requests the same dead URL again on every rebuild. Recording
/// the failure once lets every surface show its fallback straight away for
/// [retryAfter], instead of re-fetching media that is known to be unavailable.
/// It is bounded ([maxEntries], oldest first) and keyed by the exact URL that
/// was requested, so a different size or a changed record is never affected.
class KubusMediaFailureRegistry {
  KubusMediaFailureRegistry({
    this.retryAfter = const Duration(minutes: 2),
    this.maxEntries = 512,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// The registry shared by the app's media surfaces.
  static final KubusMediaFailureRegistry shared = KubusMediaFailureRegistry();

  final Duration retryAfter;
  final int maxEntries;
  final DateTime Function() _now;

  final LinkedHashMap<String, DateTime> _failedAt =
      LinkedHashMap<String, DateTime>();

  int get length => _failedAt.length;

  /// Whether [url] failed less than [retryAfter] ago.
  bool hasRecentlyFailed(String? url) {
    if (url == null || url.isEmpty) return false;
    final at = _failedAt[url];
    if (at == null) return false;
    if (_now().difference(at) >= retryAfter) {
      _failedAt.remove(url);
      return false;
    }
    return true;
  }

  void markFailed(String? url) {
    if (url == null || url.isEmpty) return;
    _failedAt.remove(url);
    _failedAt[url] = _now();
    while (_failedAt.length > maxEntries) {
      _failedAt.remove(_failedAt.keys.first);
    }
  }

  void clear() => _failedAt.clear();
}
