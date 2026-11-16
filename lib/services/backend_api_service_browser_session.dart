part of 'backend_api_service.dart';

// Web browser-session restoration (CONTRACT-BROWSER-SESSION-20261116).
//
// Web only: on native every function here returns at once and no browser-session
// endpoint is called. The bearer stays in this tab's memory (AuthCredentialStore
// web mode). The cookie is HttpOnly and held by the browser; this code never reads,
// stores or logs it. Persisted account hints remain hints, never authority.

const String _browserSessionApiPath = '/api/auth/browser-session';
const Duration _browserSessionStartWait = Duration(seconds: 15);

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

/// Web, before a sign-in that does not start a browser session (wallet, Google,
/// passkey, registration) commits its bearer: revokes the browser session, so a
/// reload cannot restore an earlier email account. Sends /logout only (cookie
/// only, no bearer); never /issue or /restore. The request is bounded:
/// new sign-in proceeds only after confirmed revocation or a disabled endpoint
/// with no active session-bound bearer. A response without a bearer is no
/// sign-in and revokes nothing.
Future<void> _browserSessionEndForSignIn(
  BackendApiService service,
  Map<String, dynamic> body,
) async {
  if (_browserSessionFor(service) == null) return;
  if (_browserSessionTokenOf(body) == null) return;
  if (!await service.endBrowserSessionForLogout(
    requireConfirmation: true,
  )) {
    throw StateError('Could not end the previous browser session');
  }
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
  // End any previous account's cookie before exchanging the new identity.
  // A failed confirmation means the new bearer must not be committed.
  if (!await service.endBrowserSessionForLogout(requireConfirmation: true)) {
    throw StateError('Could not end the previous browser session');
  }
  // A new sign-in ends any block left by an earlier sign-out or refusal.
  service._browserRestoreBlocked = false;
  service._browserSessionRestoreUnavailable = false;

  final result = await controller.issue(loginToken: loginToken);
  final payload = result.payload;
  if (!result.isSuccess || payload == null) {
    // Issuance can fail after the server has rotated the cookie. Confirm a
    // cookie-only logout before falling back to the tab-local login bearer.
    if (!await service.endBrowserSessionForLogout(requireConfirmation: true)) {
      throw StateError('Browser session issuance could not be safely revoked');
    }
    return loginBody;
  }
  if (expectedEpoch != service._authSessionEpoch) {
    // A sign-out or newer sign-in won while the request was in flight. The
    // controller serializes the following logout behind issue.
    await service.endBrowserSessionForLogout();
    return loginBody;
  }
  final issuedToken = _browserSessionTokenOf(payload);
  if (issuedToken == null) {
    if (!await service.endBrowserSessionForLogout(requireConfirmation: true)) {
      throw StateError('Malformed browser session could not be safely revoked');
    }
    return loginBody;
  }
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
  await _browserSessionHandleRefusal(service, result, expectedEpoch: epoch);
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
    service._browserSessionRestoreUnavailable = false;
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
  BrowserSessionResult result, {
  required int expectedEpoch,
}) async {
  if (expectedEpoch != service._authSessionEpoch) return;
  switch (result.outcome) {
    case BrowserSessionOutcome.unavailable:
    case BrowserSessionOutcome.rateLimited:
      // A transport failure may have lost a successful rotation response.
      // Do not replay it automatically; expose a settled recovery state and
      // require an explicit sign-in flow, which revokes before changing account.
      service._browserRestoreBlocked = true;
      service._browserSessionRestoreUnavailable = true;
      service._browserRestoreRetryAt = null;
    case BrowserSessionOutcome.invalid:
      // Expired, revoked, replayed or closed: the server ended the session.
      service._browserRestoreBlocked = true;
      if (expectedEpoch == service._authSessionEpoch &&
          _browserSessionIsBound(service)) {
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
Future<bool> _browserSessionRestoreIfDue(BackendApiService service) async {
  if (_browserSessionFor(service) == null) return false;
  if (service._browserRestoreBlocked) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(PreferenceKeys.browserSessionPendingLogoutV1) == true) {
      await service.endBrowserSessionForLogout();
      return false;
    }
  } catch (_) {
    // Storage uncertainty never authorizes restoring a browser cookie.
    return false;
  }
  final retryAt = service._browserRestoreRetryAt;
  if (retryAt != null && DateTime.now().isBefore(retryAt)) {
    return false;
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
  final sentClaims = service._tryDecodeJwtPayload(sent);
  final currentClaims = service._tryDecodeJwtPayload(current);
  if (sentClaims == null ||
      currentClaims == null ||
      sentClaims['bsid'] == null ||
      sentClaims['bsid'] != currentClaims['bsid'] ||
      sentClaims['id'] == null ||
      sentClaims['id'] != currentClaims['id'] ||
      current != service._browserBoundToken) {
    return false;
  }
  // Only a token rotation within the same bound family may retry. A 401 is
  // produced before protected route execution, so the original operation was
  // not accepted; unrelated credential changes are never replayed.
  if (sent != current) return true;
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
  service._browserSessionRestoreUnavailable = false;
}

extension BackendApiBrowserSession on BackendApiService {
  /// Web: settles a browser-session restore before the first routing decision so
  /// a slow response is not mistaken for a guest session. A timed-out or
  /// ambiguous result is shown as unavailable and cannot be silently replayed.
  /// Resolves to false on native or a settled refusal.
  Future<bool> restoreBrowserSessionForStart({
    Duration waitLimit = _browserSessionStartWait,
  }) async {
    if (_browserSessionFor(this) == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(PreferenceKeys.browserSessionPendingLogoutV1) == true) {
        // A prior tab cleared local auth but could not confirm cookie revocation.
        // Retry cookie-only logout before any restore can re-admit that account.
        if (!await endBrowserSessionForLogout()) {
          _browserSessionRestoreUnavailable = true;
          return false;
        }
        return false;
      }
      // Do not classify a still-running restore as guest. A settled unavailable
      // response is shown in discovery with a sign-in action; it is never
      // silently replayed because cookie rotation may have committed.
      final restore = restoreExistingSession(allowRefresh: false);
      try {
        return await restore.timeout(waitLimit);
      } on TimeoutException {
        // Future.timeout does not cancel the browser request. Keep its
        // cross-tab lock held, invalidate the captured generation so a late
        // result cannot adopt, and let the unavailable UI route to sign-in;
        // sign-in must wait for a cookie-only logout behind this operation.
        _browserRestoreBlocked = true;
        _browserSessionRestoreUnavailable = true;
        _browserRestoreRetryAt = null;
        _authSessionEpoch += 1;
        return false;
      }
    } catch (_) {
      _browserRestoreBlocked = true;
      _browserSessionRestoreUnavailable = true;
      return false;
    }
  }

  /// Sign-out, web only: persists non-secret retry intent and revokes the browser
  /// session. The underlying cookie operation remains serialized until settled;
  /// a UI caller may bound only how long it waits for this result.
  Future<bool> endBrowserSessionForLogout({
    bool requireConfirmation = false,
  }) async {
    final controller = _browserSessionFor(this);
    if (controller == null) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PreferenceKeys.browserSessionPendingLogoutV1, true);
    } catch (_) {
      // Without durable retry state, do not report a failed logout as complete.
    }
    if (!requireConfirmation) {
      _browserRestoreBlocked = true;
      _browserRestoreRetryAt = null;
      _browserBoundToken = null;
    }
    BrowserSessionResult result;
    try {
      // Keeping the cross-tab lock until the transport settles prevents a late
      // issue/restore response from changing the cookie after logout returns.
      result = await controller.logout();
    } catch (_) {
      result = const BrowserSessionResult.unavailable();
    }
    final confirmedRevocation = result.isSuccess;
    // Preserve the legacy sign-in path when the feature is disabled and this
    // tab has no bound bearer, but retain the durable marker: an HttpOnly cookie
    // from an earlier deployment may still exist and become restorable later.
    final legacyDisabled = requireConfirmation &&
        result.outcome == BrowserSessionOutcome.disabled &&
        !_browserSessionIsBound(this);
    final revoked = confirmedRevocation || legacyDisabled;
    if (requireConfirmation && !revoked) return false;
    _browserRestoreBlocked = true;
    _browserRestoreRetryAt = null;
    _browserBoundToken = null;
    if (confirmedRevocation) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(PreferenceKeys.browserSessionPendingLogoutV1);
      } catch (_) {}
    }
    return revoked;
  }

  /// True while this tab's bearer was issued or restored by a browser session.
  bool get browserSessionBearerActive => _browserSessionIsBound(this);

  /// Startup settled without proving the cookie session. The caller may show a
  /// recoverable sign-in prompt; automatic restore is blocked for this tab.
  bool get browserSessionRestoreUnavailable =>
      _browserSessionRestoreUnavailable;

  /// Test seam: installs a controller and whether this build counts as web.
  @visibleForTesting
  void debugSetBrowserSessionForTesting(
    BrowserSessionController? controller, {
    bool Function()? isWeb,
  }) {
    _debugSetBrowserSession(this, controller, isWeb);
  }
}
