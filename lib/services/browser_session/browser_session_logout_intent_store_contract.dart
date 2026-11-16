/// Durable, non-secret record that a web sign-out has not been confirmed on the
/// server. It carries no credential: only the fact that a revocation is owed.
abstract interface class BrowserSessionLogoutIntentStore {
  /// Writes the marker. Returns true only when it reads back as present.
  Future<bool> writePendingLogout();

  /// True when the marker is present, false when absent, and null when the
  /// storage cannot be read. Null never authorizes a restore.
  Future<bool?> readPendingLogout();

  /// Removes the marker. Returns true only when it reads back as absent.
  Future<bool> clear();
}
