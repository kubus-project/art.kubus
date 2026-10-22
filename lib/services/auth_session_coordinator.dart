import 'dart:convert';

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

  /// True when the backend reported that the signed-in account is suspended.
  /// Re-authenticating cannot repair this, so the coordinator must end the
  /// session instead of prompting for a new one.
  bool get isAccountInactive =>
      AccountInactiveSignal.isRestResponse(statusCode: statusCode, body: body);
}

/// How the backend reports a suspended (inactive) account. Only the explicit
/// codes count: a plain 403 is a permission decision on one resource and must
/// never end the session.
class AccountInactiveSignal {
  const AccountInactiveSignal._();

  /// REST: `403 {"errorCode":"ACCOUNT_INACTIVE"}`; socket event-time
  /// `auth:error` payloads carry the same value under `code`.
  static const String errorCode = 'ACCOUNT_INACTIVE';

  /// Socket handshake middleware rejection (`connect_error`, `data.code`).
  static const String socketHandshakeCode = 'SOCKET_AUTH_INACTIVE';

  /// The exact message both socket rejections carry. It is only a fallback for
  /// a client that hands over text instead of the structured payload.
  static const String suspendedMessage = 'Account access is suspended';

  /// Whether a Socket.IO `connect_error` / `auth:error` argument names an
  /// inactive account. The server sends `{message, data: {code}}` (a decoded
  /// Map); a client may instead surface a JSON string, a one-element list, an
  /// Error-like object exposing `.data` / `.message`, or just the message text.
  static bool isSocketError(Object? error) {
    if (error == null) return false;
    if (error is Map || error is List) return isPayload(error);
    if (error is String) {
      final text = error.trim();
      if (text.isEmpty) return false;
      if (text.startsWith('{') || text.startsWith('[')) {
        try {
          if (isPayload(jsonDecode(text))) return true;
        } catch (_) {}
      }
      return text.contains(suspendedMessage);
    }
    final dynamic dynamicError = error;
    try {
      if (isSocketError(dynamicError.data as Object?)) return true;
    } catch (_) {}
    try {
      if (isSocketError(dynamicError.message as Object?)) return true;
    } catch (_) {}
    return isSocketError(error.toString());
  }

  static bool isRestResponse({required int statusCode, String? body}) {
    if (statusCode != 403) return false;
    final raw = (body ?? '').trim();
    if (raw.isEmpty) return false;
    try {
      return isPayload(jsonDecode(raw));
    } catch (_) {
      return false;
    }
  }

  /// Whether a decoded REST body or socket payload names an inactive account.
  /// Accepts the REST shape (`errorCode`), the socket `auth:error` shape
  /// (`code`) and the `connect_error` shape (`data.code`).
  static bool isPayload(Object? payload) {
    if (payload is List && payload.isNotEmpty) {
      return isPayload(payload.first);
    }
    if (payload is! Map) return false;
    for (final key in const ['errorCode', 'code']) {
      final value = payload[key];
      if (value == errorCode || value == socketHandshakeCode) return true;
    }
    final nested = payload['data'];
    return nested is Map && isPayload(nested);
  }
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
