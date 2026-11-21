import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result class of one browser-session call. Only [BrowserSessionOutcome.success]
/// carries a session; every other outcome leaves the caller signed out (or, for
/// [BrowserSessionOutcome.unavailable], with its current in-memory state).
enum BrowserSessionOutcome {
  success,

  /// 404: the feature is off on this backend. Never retried.
  disabled,

  /// 401: no usable browser session (or the login token is too old / invalid).
  invalid,

  /// 403 BROWSER_SESSION_NOT_ELIGIBLE: continue without a browser session.
  notEligible,

  /// 429: back off before the next attempt.
  rateLimited,

  /// 503, network failure, timeout or a malformed success body. The caller
  /// cannot know whether a rotation committed, so it must not retry silently.
  unavailable,

  /// 403 origin/header, 405, 415 or any other status: a deployment or client bug.
  rejected,
}

class BrowserSessionResult {
  const BrowserSessionResult._(
    this.outcome, {
    this.statusCode,
    this.errorCode,
    this.body,
  });

  /// A successful result carrying [body] (login-shaped for issue and restore).
  factory BrowserSessionResult.success(
    Map<String, dynamic> body, {
    int? statusCode,
  }) =>
      BrowserSessionResult._(
        BrowserSessionOutcome.success,
        statusCode: statusCode,
        body: body,
      );

  /// A non-success result for [outcome]. Used by implementations and tests.
  factory BrowserSessionResult.failure(
    BrowserSessionOutcome outcome, {
    int? statusCode,
    String? errorCode,
  }) {
    assert(outcome != BrowserSessionOutcome.success);
    return BrowserSessionResult._(
      outcome,
      statusCode: statusCode,
      errorCode: errorCode,
    );
  }

  /// Result for a transport failure or any call that could not complete.
  const BrowserSessionResult.unavailable()
      : outcome = BrowserSessionOutcome.unavailable,
        statusCode = null,
        errorCode = null,
        body = null;

  final BrowserSessionOutcome outcome;
  final int? statusCode;
  final String? errorCode;

  /// Decoded success body, login-shaped: `data.token`, `data.user`,
  /// `data.browserSession`. Null unless [isSuccess].
  final Map<String, dynamic>? body;

  bool get isSuccess => outcome == BrowserSessionOutcome.success;

  /// The `data` object of a successful response.
  Map<String, dynamic>? get payload {
    final value = body?['data'];
    return value is Map<String, dynamic> ? value : null;
  }
}

/// The three browser-session endpoints. Implementations never throw: every
/// failure is reported as a [BrowserSessionResult].
abstract class BrowserSessionApi {
  /// Exchanges a fresh email-login token for a session-bound bearer (201).
  Future<BrowserSessionResult> issue({required String loginToken});

  /// Rotates the session cookie and returns a new bearer (200). Cookie only.
  Future<BrowserSessionResult> restore();

  /// Revokes the session family and clears the cookie (200). Cookie only.
  Future<BrowserSessionResult> logout();
}

/// HTTP implementation. [client] must be the credentialed client reserved for
/// these calls; [endpointUri] resolves `/api/auth/browser-session/<endpoint>`.
class HttpBrowserSessionApi implements BrowserSessionApi {
  HttpBrowserSessionApi({
    required http.Client client,
    required Uri Function(String endpoint) endpointUri,
  })  : _client = client,
        _endpointUri = endpointUri;

  /// Custom header that makes every call non-simple (CSRF check on the server).
  static const String sessionHeader = 'X-Kubus-Browser-Session';

  final http.Client _client;
  final Uri Function(String endpoint) _endpointUri;

  @override
  Future<BrowserSessionResult> issue({required String loginToken}) {
    return _post(
      'issue',
      bearer: loginToken,
      successStatus: 201,
      expectsSession: true,
    );
  }

  @override
  Future<BrowserSessionResult> restore() {
    return _post('restore', successStatus: 200, expectsSession: true);
  }

  @override
  Future<BrowserSessionResult> logout() {
    return _post('logout', successStatus: 200, expectsSession: false);
  }

  Future<BrowserSessionResult> _post(
    String endpoint, {
    required int successStatus,
    required bool expectsSession,
    String? bearer,
  }) async {
    final http.Response response;
    try {
      // Do not wrap cookie-changing fetches in Future.timeout: Dart would
      // abandon the wait while the browser request could still apply Set-Cookie.
      response = await _client.post(
        _endpointUri(endpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          sessionHeader: '1',
          if (bearer != null && bearer.trim().isNotEmpty)
            'Authorization': 'Bearer ${bearer.trim()}',
        },
        body: '{}',
      );
    } catch (_) {
      return const BrowserSessionResult.unavailable();
    }
    return _interpret(
      response,
      successStatus: successStatus,
      expectsSession: expectsSession,
    );
  }

  BrowserSessionResult _interpret(
    http.Response response, {
    required int successStatus,
    required bool expectsSession,
  }) {
    final status = response.statusCode;
    final decoded = _decodeObject(response.body);
    final errorCode = decoded?['errorCode']?.toString();

    if (status == successStatus) {
      if (!expectsSession) {
        return BrowserSessionResult._(
          BrowserSessionOutcome.success,
          statusCode: status,
          body: decoded ?? const <String, dynamic>{},
        );
      }
      final data = decoded?['data'];
      final token = data is Map<String, dynamic> ? data['token'] : null;
      if (token is! String || token.trim().isEmpty) {
        return BrowserSessionResult._(
          BrowserSessionOutcome.unavailable,
          statusCode: status,
        );
      }
      return BrowserSessionResult._(
        BrowserSessionOutcome.success,
        statusCode: status,
        body: decoded,
      );
    }

    final outcome = switch (status) {
      404 => BrowserSessionOutcome.disabled,
      401 => BrowserSessionOutcome.invalid,
      403 when errorCode == 'BROWSER_SESSION_NOT_ELIGIBLE' =>
        BrowserSessionOutcome.notEligible,
      403 => BrowserSessionOutcome.rejected,
      429 => BrowserSessionOutcome.rateLimited,
      final int code when code >= 500 => BrowserSessionOutcome.unavailable,
      _ => BrowserSessionOutcome.rejected,
    };
    return BrowserSessionResult._(
      outcome,
      statusCode: status,
      errorCode: errorCode,
    );
  }

  static Map<String, dynamic>? _decodeObject(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
