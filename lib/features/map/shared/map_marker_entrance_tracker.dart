import 'package:flutter/foundation.dart';

/// Classifies marker visibility changes without replaying entrance motion.
///
/// A stable marker identity is remembered for the controller lifetime. Panning
/// a known marker out of view and back in is therefore a visibility change,
/// while an identity first delivered after viewport initialization is a true
/// entrance eligible for motion.
class KubusMarkerEntranceTracker {
  final Set<String> _knownIds = <String>{};
  final Set<String> _pendingTrueEntranceIds = <String>{};

  @visibleForTesting
  Set<String> get knownIds => Set<String>.unmodifiable(_knownIds);

  @visibleForTesting
  Set<String> get pendingTrueEntranceIds =>
      Set<String>.unmodifiable(_pendingTrueEntranceIds);

  int get knownCount => _knownIds.length;
  int get pendingTrueEntranceCount => _pendingTrueEntranceIds.length;

  void observeIncoming(
    Iterable<String> incomingIds, {
    required bool viewportInitialized,
  }) {
    final incoming = incomingIds.toSet();
    if (viewportInitialized) {
      _pendingTrueEntranceIds.addAll(incoming.difference(_knownIds));
    }
    _knownIds.addAll(incoming);
  }

  Set<String> consumeTrueEntrances({
    required Set<String> enteredIds,
    required Set<String> eligibleIds,
  }) {
    final trueEntrances = enteredIds.intersection(_pendingTrueEntranceIds);
    _pendingTrueEntranceIds.removeAll(eligibleIds);
    return trueEntrances;
  }

  void clear() {
    _knownIds.clear();
    _pendingTrueEntranceIds.clear();
  }
}
