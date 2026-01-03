enum AuthReauthOutcome {
  success,
  cancelled,
  failed,
  cooldown,
  notEnabled,
}

class AuthReauthResult {
  const AuthReauthResult(this.outcome, {this.message});

  final AuthReauthOutcome outcome;
  final String? message;

  bool get isSuccess => outcome == AuthReauthOutcome.success;
}

class AuthFailureContext {
  const AuthFailureContext({
    required this.statusCode,
    required this.method,
    required this.path,
    this.body,
  });

  final int statusCode;
  final String method;
  final String path;
  final String? body;
}

/// Contract consumed by HTTP-layer code to coordinate "token expired" flows
/// without importing UI/provider code.
abstract class AuthSessionCoordinator {
  bool get isResolving;

  /// When a request fails due to auth, coordinate a single re-auth prompt.
  Future<AuthReauthResult> handleAuthFailure(AuthFailureContext context);

  /// Wait for any in-flight auth resolution (if any) to settle.
  Future<AuthReauthResult?> waitForResolution();

  /// Reset any pending auth resolution (e.g. after logout).
  void reset();
}

