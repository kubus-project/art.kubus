/// Durable, non-secret record that a web sign-out has not been confirmed on the
/// server. It carries no credential: only the fact that a revocation is owed.
abstract interface class BrowserSessionLogoutIntentStore {
  /// Writes the marker. Returns true only when it reads back as present.
  ///
  /// [sharedMarkerWritten] is for the tab-scoped store: true when the shared
  /// marker was written first, so this tab marker is only meaningful while the
  /// shared one still exists. False means this marker is the sole record.
  Future<bool> writePendingLogout({bool sharedMarkerWritten = false});

  /// True when the present marker was written alongside a shared marker and so
  /// goes stale once the shared marker is gone. False when absent, when it is
  /// the sole record, or when unreadable.
  Future<bool> readDependsOnSharedMarker();

  /// True when the marker is present, false when absent, and null when the
  /// storage cannot be read. Null never authorizes a restore.
  Future<bool?> readPendingLogout();

  /// Removes the marker. Returns true only when it reads back as absent.
  Future<bool> clear();
}
