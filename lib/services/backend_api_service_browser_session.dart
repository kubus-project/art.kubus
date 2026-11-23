part of 'backend_api_service.dart';

// Web browser-session restoration (CONTRACT-BROWSER-SESSION-20261116).
//
// Web only: on native every function here returns at once and no browser-session
// endpoint is called. The bearer stays in this tab's memory (AuthCredentialStore
// web mode). The cookie is HttpOnly and held by the browser; this code never reads,
// stores or logs it. Persisted account hints remain hints, never authority.
//
// Waits are bounded for the user, never for the transport: a bounded caller stops
// waiting, but the browser request keeps the cross-tab lock until it settles, and
// a result that arrives after its caller stopped waiting is never adopted.

const String _browserSessionApiPath = '/api/auth/browser-session';
const Duration _browserSessionStartWait = Duration(seconds: 15);
// After a failed owed-logout attempt during restore, the next attempt waits.
const Duration _browserLogoutRetryBackoff = Duration(seconds: 30);

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

/// One cookie restore in flight in this tab. Callers share its browser request
/// and its single commit. Once a caller stops waiting the flight is abandoned,
/// and its result belongs to no account: nobody adopts it.
class _BrowserRestoreFlight {
  _BrowserRestoreFlight(this.result);

  final Future<BrowserSessionResult> result;
  Future<bool>? adoption;
  bool abandoned = false;
}

/// Runs [operation] for at most [wait]. The operation is never cancelled; only
/// the caller stops waiting. Returns null on timeout.
Future<T?> _browserSessionBounded<T>(Future<T> operation, Duration wait) async {
  try {
    return await operation.timeout(wait);
  } on TimeoutException {
    return null;
  }
}

/// The shared logout marker, in preferences: every tab of the origin sees it.
/// It holds no credential, only the fact that a revocation is owed.
class _PreferencesLogoutIntentStore implements BrowserSessionLogoutIntentStore {
  static const String _key = PreferenceKeys.browserSessionPendingLogoutV1;

  @override
  Future<bool> writePendingLogout({bool sharedMarkerWritten = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
      // Read back from storage, not from this tab's cache.
      await prefs.reload();
      return prefs.getBool(_key) == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> readDependsOnSharedMarker() async => false;

  @override
  Future<bool?> readPendingLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Another tab may have confirmed the revocation and removed the marker since
      // this tab's cache loaded. A stale cached marker must never authorize a logout.
      await prefs.reload();
      return prefs.getBool(_key) == true;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      // Read back from storage, not from this tab's cache.
      await prefs.reload();
      return prefs.getBool(_key) == null;
    } catch (_) {
      return false;
    }
  }
}

enum _LogoutIntentState { none, owed, unreadable }

BrowserSessionLogoutIntentStore _sharedLogoutStore(BackendApiService service) =>
    service._browserLogoutPrimaryStore ??= _PreferencesLogoutIntentStore();

BrowserSessionLogoutIntentStore _tabLogoutStore(BackendApiService service) =>
    service._browserLogoutFallbackStore ??=
        createBrowserSessionLogoutIntentStore();

/// Writes the logout marker to both stores and verifies it. Durable when at least
/// one store reads it back. Otherwise the intent stays unwritten in this tab and
/// is retried before the next restore decision.
Future<bool> _writeLogoutIntent(BackendApiService service) async {
  final shared = await _sharedLogoutStore(service).writePendingLogout();
  // The tab marker records whether the shared one was written: only a tab
  // marker that is the sole record may outlive the shared marker.
  final tab = await _tabLogoutStore(service)
      .writePendingLogout(sharedMarkerWritten: shared);
  final durable = shared || tab;
  service._browserLogoutIntentUnwritten = !durable;
  return durable;
}

Future<void> _clearLogoutIntent(BackendApiService service) async {
  await _sharedLogoutStore(service).clear();
  await _tabLogoutStore(service).clear();
}

/// Whether a logout is owed. The shared marker makes it owed. A tab marker does
/// too, unless it was written alongside a shared marker that is now gone (stale).
/// An unreadable shared store is unreadable, which never authorizes a restore.
Future<_LogoutIntentState> _readLogoutIntent(BackendApiService service) async {
  final shared = await _sharedLogoutStore(service).readPendingLogout();
  if (shared == true) return _LogoutIntentState.owed;
  final tabStore = _tabLogoutStore(service);
  final tab = await tabStore.readPendingLogout();
  if (tab == true) {
    if (!await tabStore.readDependsOnSharedMarker()) {
      return _LogoutIntentState.owed;
    }
    // Written alongside a shared marker that is gone: another tab confirmed
    // the revocation, so this marker is stale. Acting on it would revoke
    // whatever account that tab signed in since.
    if (shared == false) {
      await tabStore.clear();
      return _LogoutIntentState.none;
    }
    // Shared unreadable: no verdict, so neither owed nor cleared.
  }
  if (shared == null) return _LogoutIntentState.unreadable;
  return _LogoutIntentState.none;
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
  // A failed or unsettled confirmation means the new bearer must not be committed.
  if (!await service.endBrowserSessionForLogout(requireConfirmation: true)) {
    throw StateError('Could not end the previous browser session');
  }
  // A new sign-in ends any block left by an earlier sign-out or refusal.
  service._browserRestoreBlocked = false;
  service._browserSessionRestoreUnavailable = false;

  final result = await _browserSessionBounded(
    controller.issue(loginToken: loginToken),
    service._browserSessionOperationWait,
  );
  if (result == null) {
    // The issue is still inside the cross-tab lock and may yet set a cookie.
    // Refuse restores now, before the revocation's marker write has landed: a
    // restore queued behind the issue must not run. A revocation queued behind
    // it ends whatever it starts; nothing is adopted.
    service._browserRestoreBlocked = true;
    unawaited(
      service.endBrowserSessionForLogout().catchError((Object _) => false),
    );
    throw StateError('Browser session start did not settle');
  }
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
    // A sign-out or newer sign-in won while the request was in flight.
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

/// The restore flight for this tab, joining the one in flight when present.
_BrowserRestoreFlight _browserSessionRestoreFlight(BackendApiService service) {
  final existing = service._browserRestoreFlight;
  if (existing != null) return existing;
  final controller = _browserSessionFor(service);
  final result = controller == null
      ? Future<BrowserSessionResult>.value(
          BrowserSessionResult.failure(BrowserSessionOutcome.disabled),
        )
      : controller.restore();
  final flight = _BrowserRestoreFlight(result);
  service._browserRestoreFlight = flight;
  return flight;
}

/// Frees the flight slot, but only while it still holds [flight].
void _releaseBrowserRestoreFlight(
  BackendApiService service,
  _BrowserRestoreFlight flight,
) {
  if (identical(service._browserRestoreFlight, flight)) {
    service._browserRestoreFlight = null;
  }
}

/// Restores the browser session for one caller. The caller waits at most the
/// restore bound. The flight commits its bearer once, and the slot stays
/// claimed until that commit settles, so a caller that starts during the commit
/// joins it instead of making a second restore. Every caller then checks the
/// restored identity against its own expectation, and against the current
/// bearer, before it reports success.
Future<bool> _browserSessionRestoreOnce(
  BackendApiService service, {
  String? expectedBrowserSessionToken,
}) async {
  final epoch = service._authSessionEpoch;
  final flight = _browserSessionRestoreFlight(service);
  final result = await _browserSessionBounded(
    flight.result,
    service._browserSessionRestoreWait,
  );
  if (result == null) {
    // Stop waiting: the late result is never adopted. The cookie may have been
    // rotated, so the tab does not replay the restore and shows a settled state.
    flight.abandoned = true;
    _releaseBrowserRestoreFlight(service, flight);
    await _browserSessionHandleRefusal(
      service,
      const BrowserSessionResult.unavailable(),
      expectedEpoch: epoch,
    );
    return false;
  }
  if (!result.isSuccess) {
    _releaseBrowserRestoreFlight(service, flight);
    await _browserSessionHandleRefusal(service, result, expectedEpoch: epoch);
    return false;
  }
  final body = result.body;
  final restoredToken = body == null ? null : _browserSessionTokenOf(body);
  if (body == null || restoredToken == null) {
    _releaseBrowserRestoreFlight(service, flight);
    return false;
  }
  final expected = expectedBrowserSessionToken;
  if (expected != null &&
      !_browserSessionSameIdentity(service, expected, restoredToken)) {
    _releaseBrowserRestoreFlight(service, flight);
    await _browserSessionRejectMismatchedRestore(
      service,
      expected,
      expectedEpoch: epoch,
    );
    return false;
  }
  if (flight.abandoned) {
    _releaseBrowserRestoreFlight(service, flight);
    return false;
  }
  try {
    final adopted = await (flight.adoption ??= _browserSessionAdopt(
      service,
      body,
      expectedEpoch: epoch,
    ));
    if (!adopted) return false;
    if (expected == null) return true;
    // Joined flights adopt once; a later account change must still refuse this one.
    return _browserSessionSameIdentity(
      service,
      expected,
      (service._authToken ?? '').trim(),
    );
  } finally {
    _releaseBrowserRestoreFlight(service, flight);
  }
}

bool _browserSessionSameIdentity(
  BackendApiService service,
  String expectedToken,
  String restoredToken,
) {
  final expected = service._tryDecodeJwtPayload(expectedToken);
  final restored = service._tryDecodeJwtPayload(restoredToken);
  final expectedId = expected?['id'];
  final expectedFamily = expected?['bsid'];
  return expectedId != null &&
      expectedFamily is String &&
      expectedFamily.isNotEmpty &&
      restored?['id'] == expectedId &&
      restored?['bsid'] == expectedFamily;
}

Future<void> _browserSessionRejectMismatchedRestore(
  BackendApiService service,
  String expectedToken, {
  required int expectedEpoch,
}) async {
  if (expectedEpoch != service._authSessionEpoch) return;
  service._browserRestoreBlocked = true;
  service._browserSessionRestoreUnavailable = true;
  service._browserRestoreRetryAt = null;
  if ((service._authToken ?? '').trim() == expectedToken) {
    // Remove this tab's stale identity only. The cookie may belong to a newer
    // account in another tab, so never call the cookie-only logout here.
    try {
      await service.clearAuth();
    } catch (_) {}
  }
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
/// A logout owed to the server is settled first, and never followed by a restore.
Future<bool> _browserSessionRestoreIfDue(
  BackendApiService service, {
  String? expectedBrowserSessionToken,
}) async {
  if (_browserSessionFor(service) == null) return false;
  // A marker that could not be written is retried once per decision.
  if (service._browserLogoutIntentUnwritten) {
    await _writeLogoutIntent(service);
  }
  final retryAt = service._browserRestoreRetryAt;
  final backingOff = retryAt != null && DateTime.now().isBefore(retryAt);
  switch (await _readLogoutIntent(service)) {
    case _LogoutIntentState.owed:
      // A revocation is owed: settle it (bounded) and restore nothing. A blocked
      // tab still settles it, but not on every request: a failed attempt backs
      // off, so the owed revocation never becomes a wait on each call.
      if (backingOff) return false;
      final end = await service._endBrowserSessionForLogout(
        requireConfirmation: false,
      );
      if (!end.revoked) {
        service._browserSessionRestoreUnavailable = true;
      }
      // A feature that is off (404) keeps the marker owed for re-enable and is
      // not a revocation, so it backs off like a failed attempt. Otherwise every
      // request without a bearer would POST /logout again.
      if (!end.revoked || end.disabled) {
        service._browserRestoreRetryAt =
            DateTime.now().add(_browserLogoutRetryBackoff);
      }
      return false;
    case _LogoutIntentState.unreadable:
      // Storage uncertainty never authorizes restoring a browser cookie.
      service._browserRestoreBlocked = true;
      service._browserSessionRestoreUnavailable = true;
      return false;
    case _LogoutIntentState.none:
      break;
  }
  if (service._browserRestoreBlocked) return false;
  if (backingOff) return false;
  return _browserSessionRestoreOnce(
    service,
    expectedBrowserSessionToken: expectedBrowserSessionToken,
  );
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
  // The restore is checked against the originating account and family, before
  // it is committed or retried. A different account is refused, never replayed.
  // A blocked tab, or a logout still owed to the server, never restores here.
  if (service._browserRestoreBlocked) return false;
  if (await _readLogoutIntent(service) != _LogoutIntentState.none) return false;
  return _browserSessionRestoreOnce(
    service,
    expectedBrowserSessionToken: sent,
  );
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
  service._browserSessionRestoreWait = const Duration(seconds: 15);
  service._browserSessionOperationWait = const Duration(seconds: 5);
  service._browserLogoutPrimaryStore = null;
  service._browserLogoutFallbackStore = null;
  service._browserLogoutIntentSeq = 0;
  service._browserLogoutIntentUnwritten = false;
  service._browserLogoutUnconfirmed = false;
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
    final restore = restoreExistingSession(allowRefresh: false);
    try {
      return await restore.timeout(waitLimit);
    } on TimeoutException {
      // Future.timeout does not cancel the browser request. Keep its
      // cross-tab lock held, abandon the flight so a late result cannot adopt,
      // and let the unavailable UI route to sign-in. Sign-in waits behind the
      // same lock.
      _browserRestoreFlight?.abandoned = true;
      _browserRestoreBlocked = true;
      _browserSessionRestoreUnavailable = true;
      _browserRestoreRetryAt = null;
      _authSessionEpoch += 1;
      return false;
    } catch (_) {
      _browserRestoreBlocked = true;
      _browserSessionRestoreUnavailable = true;
      return false;
    }
  }

  /// Sign-out, web only: persists the logout intent and revokes the browser
  /// session. Resolves within the operation bound. Returns true only for a
  /// confirmed revocation (or a feature that is off with no bound bearer). When
  /// the revocation has not settled, the intent stays owed and the late result
  /// is recorded when it arrives; it never claims the server operation was
  /// cancelled.
  Future<bool> endBrowserSessionForLogout({
    bool requireConfirmation = false,
  }) async =>
      (await _endBrowserSessionForLogout(
        requireConfirmation: requireConfirmation,
      ))
          .revoked;

  /// [endBrowserSessionForLogout], also reporting whether the feature is off on
  /// the server (`disabled`). A disabled feature is not a revocation.
  Future<({bool revoked, bool disabled})> _endBrowserSessionForLogout({
    required bool requireConfirmation,
  }) async {
    final controller = _browserSessionFor(this);
    if (controller == null) return (revoked: true, disabled: false);
    // The intent is written before the revocation starts, so a reload or another
    // tab sees it owed. Only the newest intent may clear the markers.
    final generation = ++_browserLogoutIntentSeq;
    final epoch = _authSessionEpoch;
    await _writeLogoutIntent(this);
    if (!requireConfirmation) {
      _browserRestoreBlocked = true;
      _browserRestoreRetryAt = null;
      _browserBoundToken = null;
    }
    // The revocation holds the cross-tab lock until it settles, so a late issue
    // or restore response cannot set a cookie after logout returns.
    final settled = controller
        .logout()
        .then((result) => _settleLogoutIntent(this, generation, result));
    final result = await _browserSessionBounded(
          settled,
          _browserSessionOperationWait,
        ) ??
        const BrowserSessionResult.unavailable();
    if (!result.isSuccess &&
        result.outcome != BrowserSessionOutcome.disabled &&
        generation == _browserLogoutIntentSeq) {
      // Unsettled or refused: the revocation stays owed, and the tab says so.
      _browserLogoutUnconfirmed = true;
    }
    final disabled = result.outcome == BrowserSessionOutcome.disabled;
    final legacyDisabled = disabled && !_browserSessionIsBound(this);
    final revoked = result.isSuccess || legacyDisabled;
    if (requireConfirmation && !revoked) {
      return (revoked: false, disabled: disabled);
    }
    if (_authSessionEpoch == epoch) {
      _browserRestoreBlocked = true;
      _browserRestoreRetryAt = null;
      _browserBoundToken = null;
    }
    return (revoked: revoked, disabled: disabled);
  }

  /// True while this tab's bearer was issued or restored by a browser session.
  bool get browserSessionBearerActive => _browserSessionIsBound(this);

  /// Startup settled without proving the cookie session. The caller may show a
  /// recoverable sign-in prompt; automatic restore is blocked for this tab.
  bool get browserSessionRestoreUnavailable =>
      _browserSessionRestoreUnavailable;

  /// True while a logout is owed to the server and has not been confirmed. The
  /// tab must say so; it must not present the session as ended.
  bool get browserSessionLogoutUnresolved => _browserLogoutUnconfirmed;

  /// Test seam: installs a controller and whether this build counts as web.
  @visibleForTesting
  void debugSetBrowserSessionForTesting(
    BrowserSessionController? controller, {
    bool Function()? isWeb,
  }) {
    _debugSetBrowserSession(this, controller, isWeb);
  }

  /// Test seam: bounds for restore and for sign-in, logout and issue waits.
  @visibleForTesting
  void debugSetBrowserSessionWaitsForTesting({
    Duration? restore,
    Duration? operation,
  }) {
    _browserSessionRestoreWait = restore ?? _browserSessionRestoreWait;
    _browserSessionOperationWait = operation ?? _browserSessionOperationWait;
  }

  /// Test seam: the shared marker and the tab-scoped fallback. Null restores
  /// the defaults.
  @visibleForTesting
  void debugSetBrowserSessionLogoutIntentStoresForTesting({
    BrowserSessionLogoutIntentStore? primary,
    BrowserSessionLogoutIntentStore? fallback,
  }) {
    _browserLogoutPrimaryStore = primary;
    _browserLogoutFallbackStore = fallback;
  }

  /// Test seam: a page reload. Tab memory is lost; the stores, which model
  /// shared and tab-session storage, keep what they hold.
  @visibleForTesting
  void debugSimulateTabReloadForTesting() {
    _authToken = null;
    _credentialTargetToken = null;
    _browserBoundToken = null;
    _browserRestoreFlight = null;
    _browserRestoreRetryAt = null;
    _browserRestoreBlocked = false;
    _browserSessionRestoreUnavailable = false;
    _browserLogoutIntentUnwritten = false;
    _browserLogoutUnconfirmed = false;
  }
}

/// Runs when a revocation settles, whether or not a caller still waits. A
/// confirmed revocation of the newest intent clears the markers. A failed one
/// keeps the logout unconfirmed. Older intents never change either state.
Future<BrowserSessionResult> _settleLogoutIntent(
  BackendApiService service,
  int generation,
  BrowserSessionResult result,
) async {
  final newest = generation == service._browserLogoutIntentSeq;
  if (result.isSuccess) {
    if (newest) {
      service._browserLogoutUnconfirmed = false;
      // Checked synchronously above: any newer intent is issued after this
      // clear, so its marker survives it.
      await _clearLogoutIntent(service);
    }
  } else if (newest && result.outcome != BrowserSessionOutcome.disabled) {
    // A disabled feature leaves the marker for re-enable and cannot restore.
    service._browserLogoutUnconfirmed = true;
  }
  return result;
}
