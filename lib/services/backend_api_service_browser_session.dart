part of 'backend_api_service.dart';

// Web browser-session restoration (CONTRACT-BROWSER-SESSION-20261116).
//
// Web only: on native every function here returns at once and no browser-session
// endpoint is called. The bearer stays in this tab's memory (AuthCredentialStore
// web mode). The cookie is HttpOnly and held by the browser; this code never reads,
// stores or logs it. Persisted account hints remain hints, never authority.

const String _browserSessionApiPath = '/api/auth/browser-session';
const Duration _browserSessionRetryBackoff = Duration(seconds: 10);
const Duration _browserSessionStartTimeout = Duration(seconds: 4);
const Duration _browserSessionLogoutTimeout = Duration(seconds: 5);

bool _browserSessionIsWebPlatform() => kIsWeb;

BrowserSessionController? _browserSessionFor(BackendApiService service) {
  if (!service._browserSessionIsWeb()) return null;
  return service._browserSessionController ??= BrowserSessionController(
    api: HttpBrowserSessionApi(
      client: createBrowserSessionHttpClient(),
      endpointUri: (endpoint) => service._buildApiUri(
        service.baseUrl,
        '$_browserSessionApiPath/$endpoint',
      ),
    ),
  );
}

String? _browserSessionTokenOf(Map<String, dynamic> body) {
  final token = _backendApiResponsePayload(body)['token'];
  if (token is! String) return null;
  final trimmed = token.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _browserSessionIsBound(BackendApiService service) {
  final bound = service._browserBoundToken;
  return bound != null && (service._authToken ?? '').trim() == bound;
}

/// Web, after a successful email login: exchanges the login token for a
/// session-bound bearer. Returns the body to commit. When no session starts the
/// login body is returned unchanged, so the login token stays this tab's bearer
/// (signed in for this tab only; nothing is restored after a reload).
Future<Map<String, dynamic>> _browserSessionIssueAfterEmailLogin(
  BackendApiService service,
  Map<String, dynamic> loginBody, {
  required int expectedEpoch,
}) async {
  final controller = _browserSessionFor(service);
  final loginToken = _browserSessionTokenOf(loginBody);
  if (controller == null || loginToken == null) return loginBody;
  // A new sign-in ends any block left by an earlier sign-out or refusal.
  service._browserRestoreBlocked = false;

  final result = await controller.issue(loginToken: loginToken);
  final payload = result.payload;
  if (!result.isSuccess || payload == null) return loginBody;
  if (expectedEpoch != service._authSessionEpoch) return loginBody;
  final issuedToken = _browserSessionTokenOf(payload);
  if (issuedToken == null) return loginBody;
  service._browserBoundToken = issuedToken;
  return <String, dynamic>{...loginBody, 'data': payload};
}

/// Restores the browser session, joining the attempt already in flight in this
/// tab. The attempt commits its bearer once, so overlapping callers never
/// commit twice (each commit advances the session epoch).
Future<bool> _browserSessionRestoreOnce(BackendApiService service) {
  final existing = service._browserRestoreFlight;
  if (existing != null) return existing;
  late final Future<bool> flight;
  flight = _browserSessionRestoreAttempt(service).whenComplete(() {
    if (identical(service._browserRestoreFlight, flight)) {
      service._browserRestoreFlight = null;
    }
  });
  service._browserRestoreFlight = flight;
  return flight;
}

Future<bool> _browserSessionRestoreAttempt(BackendApiService service) async {
  final controller = _browserSessionFor(service);
  if (controller == null) return false;
  final epoch = service._authSessionEpoch;
  final result = await controller.restore();
  if (result.isSuccess) {
    final body = result.body;
    if (body == null) return false;
    return _browserSessionAdopt(service, body, expectedEpoch: epoch);
  }
  await _browserSessionHandleRefusal(service, result);
  return false;
}

/// Commits a restored or issued session exactly as the email sign-in does, then
/// records the bearer as session-bound.
Future<bool> _browserSessionAdopt(
  BackendApiService service,
  Map<String, dynamic> body, {
  required int expectedEpoch,
}) async {
  final token = _browserSessionTokenOf(body);
  if (token == null) return false;
  try {
    final sessionEpoch = await service._persistTokenFromResponse(
      body,
      expectedEpoch: expectedEpoch,
    );
    service._browserBoundToken = token;
    service._browserRestoreBlocked = false;
    service._browserRestoreRetryAt = null;
    try {
      await service.syncSecureAccountStatusFromResponse(
        body,
        sessionEpoch: sessionEpoch,
        fetchIfMissing: false,
      );
      await service.setLastSignInMethod(
        AuthSignInMethod.email,
        sessionEpoch: sessionEpoch,
      );
    } catch (_) {
      // Hints only: the bearer is already committed for this tab.
    }
    return true;
  } catch (_) {
    // The session ended while the restore was in flight; nothing was committed.
    return false;
  }
}

Future<void> _browserSessionHandleRefusal(
  BackendApiService service,
  BrowserSessionResult result,
) async {
  switch (result.outcome) {
    case BrowserSessionOutcome.unavailable:
    case BrowserSessionOutcome.rateLimited:
      // A 503 or 429 leaves the cookie valid: retry later, never in a loop.
      service._browserRestoreRetryAt =
          DateTime.now().add(_browserSessionRetryBackoff);
    case BrowserSessionOutcome.invalid:
      // Expired, revoked, replayed or closed: the server ended the session.
      service._browserRestoreBlocked = true;
      if (_browserSessionIsBound(service)) {
        service._browserBoundToken = null;
        await service.clearAuth();
      }
    case BrowserSessionOutcome.success:
    case BrowserSessionOutcome.disabled:
    case BrowserSessionOutcome.notEligible:
    case BrowserSessionOutcome.rejected:
      service._browserRestoreBlocked = true;
  }
}

/// `restoreExistingSession` with no usable bearer in this tab: one restore per
/// settled outcome. Blocked after a refusal, backed off after a transient failure.
Future<bool> _browserSessionRestoreIfDue(BackendApiService service) {
  if (_browserSessionFor(service) == null) return Future<bool>.value(false);
  if (service._browserRestoreBlocked) return Future<bool>.value(false);
  final retryAt = service._browserRestoreRetryAt;
  if (retryAt != null && DateTime.now().isBefore(retryAt)) {
    return Future<bool>.value(false);
  }
  return _browserSessionRestoreOnce(service);
}

/// A 401 for the bearer this request sent. Returns true when the request should
/// be retried once with a current bearer. Only a session-bound bearer is
/// restored; any other rejection keeps the existing re-auth path.
Future<bool> _browserSessionRecoverRejectedBearer(
  BackendApiService service,
  String? sentAuthorization,
) async {
  if (_browserSessionFor(service) == null) return false;
  final sent =
      (sentAuthorization ?? '').replaceFirst(RegExp(r'^Bearer\s+'), '').trim();
  final current = (service._authToken ?? '').trim();
  if (sent.isEmpty || current.isEmpty) return false;
  // Already replaced while this request was in flight: retry once with it.
  if (sent != current) return true;
  if (sent != service._browserBoundToken) return false;
  return _browserSessionRestoreOnce(service);
}

void _debugSetBrowserSession(
  BackendApiService service,
  BrowserSessionController? controller,
  bool Function()? isWeb,
) {
  service._browserSessionController = controller;
  service._browserSessionIsWeb = isWeb ?? _browserSessionIsWebPlatform;
  service._browserRestoreFlight = null;
  service._browserBoundToken = null;
  service._browserRestoreRetryAt = null;
  service._browserRestoreBlocked = false;
}

extension BackendApiBrowserSession on BackendApiService {
  /// Web: restores the browser session before the first routing decision, so a
  /// reload does not show the guest map first. Bounded by [timeout]; a slower
  /// restore finishes in the background. Resolves to false on native.
  Future<bool> restoreBrowserSessionForStart({
    Duration timeout = _browserSessionStartTimeout,
  }) async {
    if (_browserSessionFor(this) == null) return false;
    try {
      return await restoreExistingSession(allowRefresh: false)
          .timeout(timeout, onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  /// Sign-out, web only: revokes the browser session. Sent at once, awaited by
  /// the caller with a bound, never throws. Blocks restoration until the next
  /// email sign-in.
  Future<void> endBrowserSessionForLogout() async {
    _browserRestoreBlocked = true;
    _browserRestoreRetryAt = null;
    _browserBoundToken = null;
    final controller = _browserSessionFor(this);
    if (controller == null) return;
    try {
      await controller.logout().timeout(_browserSessionLogoutTimeout);
    } catch (_) {
      // Best effort: local sign-out proceeds regardless.
    }
  }

  /// True while this tab's bearer was issued or restored by a browser session.
  bool get browserSessionBearerActive => _browserSessionIsBound(this);

  /// Test seam: installs a controller and whether this build counts as web.
  @visibleForTesting
  void debugSetBrowserSessionForTesting(
    BrowserSessionController? controller, {
    bool Function()? isWeb,
  }) {
    _debugSetBrowserSession(this, controller, isWeb);
  }
}
