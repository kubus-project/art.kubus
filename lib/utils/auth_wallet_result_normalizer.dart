import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../services/backend_api_service.dart';

class NormalizedWalletAuthResult {
  const NormalizedWalletAuthResult.success(
    this.payload, {
    this.walletAddress,
  }) : reason = null;

  const NormalizedWalletAuthResult.cancelled()
      : payload = null,
        walletAddress = null,
        reason = null;

  const NormalizedWalletAuthResult.failed(this.reason)
      : payload = null,
        walletAddress = null;

  final Map<String, dynamic>? payload;
  final String? walletAddress;
  final String? reason;

  bool get isSuccess => payload != null;
  bool get isCancelled => payload == null && reason == null;
  bool get isFailure => reason != null;
}

const String _noTokenFailureReason =
    'Wallet sign-in did not produce a backend session. '
    'Please try again — no transaction was sent.';

/// Normalizes the result of a wallet connect/sign-in flow into an auth
/// outcome.
///
/// Backend JWT is the only authority for authentication. Success requires:
///  * the route result to carry a session token
///    (`token` / `accessToken` / `authToken`, also nested under `data`,
///    `auth` or `session`), which is persisted onto [api]; or
///  * [api] already holding a token that the wallet flow just persisted,
///    in which case `/api/profiles/me` must confirm the session.
///
/// A wallet address, a connected signer, or local wallet prefs are NEVER
/// sufficient — wallet-only results fail so the caller shows a retry state
/// instead of routing into the authenticated shell without a JWT.
Future<NormalizedWalletAuthResult> normalizeWalletAuthResult({
  required Object? routeResult,
  required BackendApiService api,
  String? fallbackWalletAddress,
  bool hadAuthBeforeOpen = false,
}) async {
  final fallbackWallet = _clean(fallbackWalletAddress);
  final apiToken = _clean(api.getAuthToken());
  final currentAuthWallet = _clean(api.getCurrentAuthWalletAddress());

  void logResult(String result, {String? detail}) {
    if (!kDebugMode) return;
    AppConfig.debugPrint(
      'AuthWalletResultNormalizer: routeResultType=${routeResult.runtimeType}, '
      'routeResultIsMap=${routeResult is Map}, '
      'authTokenExists=${apiToken.isNotEmpty}, '
      'currentAuthWalletExists=${currentAuthWallet.isNotEmpty}, '
      'fallbackWalletExists=${fallbackWallet.isNotEmpty}, '
      'hadAuthBeforeOpen=$hadAuthBeforeOpen, '
      'result=$result${detail == null ? '' : ', detail=$detail'}',
    );
  }

  if (routeResult is Map) {
    final map = _stringKeyedMap(routeResult);
    final failureReason = _explicitFailureReason(map);
    if (failureReason != null) {
      logResult('failure', detail: 'explicit-failure');
      return NormalizedWalletAuthResult.failed(failureReason);
    }

    final payloadToken = _extractToken(map);
    final walletAddress = _firstNonEmpty([
      _extractWalletAddress(map),
      currentAuthWallet,
      fallbackWallet,
    ]);

    if (payloadToken.isNotEmpty) {
      // The wallet flow returned a session token: persist it so
      // getAuthToken()/Authorization headers see it immediately.
      if (payloadToken != apiToken) {
        try {
          await api.setAuthToken(payloadToken);
        } catch (e) {
          if (kDebugMode) {
            AppConfig.debugPrint(
              'AuthWalletResultNormalizer: token persistence failed (${e.runtimeType})',
            );
          }
        }
        final refreshToken = _extractRefreshToken(map);
        if (refreshToken.isNotEmpty) {
          try {
            await api.setRefreshToken(refreshToken);
          } catch (_) {}
        }
      }
      logResult('success', detail: 'payload-token');
      return NormalizedWalletAuthResult.success(
        _standardAuthPayload(map, walletAddress: walletAddress),
        walletAddress: walletAddress.isEmpty ? null : walletAddress,
      );
    }

    // No token in the payload. A backend token persisted by the wallet flow
    // itself (challenge/sign/login) is the only other acceptable evidence,
    // and it must be able to load /api/profiles/me.
    if (apiToken.isNotEmpty) {
      final verified = await _verifyTokenWithProfile(api, logResult);
      if (verified != null) {
        final mergedWallet = _firstNonEmpty([
          _extractWalletAddress(map),
          _walletFromMap(verified),
          currentAuthWallet,
          fallbackWallet,
        ]);
        logResult('success', detail: 'api-token-verified');
        return NormalizedWalletAuthResult.success(
          _standardAuthPayload(
            <String, dynamic>{
              ...map,
              'data': <String, dynamic>{
                if (map['data'] is Map) ..._stringKeyedMap(map['data'] as Map),
                'user': <String, dynamic>{
                  ...verified,
                  if (map['data'] is Map &&
                      (map['data'] as Map)['user'] is Map)
                    ..._stringKeyedMap((map['data'] as Map)['user'] as Map),
                },
              },
            },
            walletAddress: mergedWallet,
          ),
          walletAddress: mergedWallet.isEmpty ? null : mergedWallet,
        );
      }
      logResult('failure', detail: 'api-token-unverified');
      return const NormalizedWalletAuthResult.failed(_noTokenFailureReason);
    }

    logResult('failure', detail: 'wallet-only-result');
    return const NormalizedWalletAuthResult.failed(_noTokenFailureReason);
  }

  if (routeResult != null) {
    logResult('failure', detail: 'unexpected-type');
    return NormalizedWalletAuthResult.failed(
      'Unexpected wallet authentication result: ${routeResult.runtimeType}',
    );
  }

  // The flow closed without a result. If the app already had a session before
  // the wallet flow opened, nothing new was authenticated — treat as cancel.
  if (hadAuthBeforeOpen) {
    logResult('cancel', detail: 'had-auth-before-open');
    return const NormalizedWalletAuthResult.cancelled();
  }

  // A token that appeared during the flow (persisted by wallet login) is
  // acceptable only when /api/profiles/me confirms it.
  if (apiToken.isNotEmpty) {
    final verified = await _verifyTokenWithProfile(api, logResult);
    if (verified != null) {
      final walletAddress = _firstNonEmpty([
        _walletFromMap(verified),
        currentAuthWallet,
        fallbackWallet,
      ]);
      logResult('success', detail: 'null-result-api-token-verified');
      return NormalizedWalletAuthResult.success(
        <String, dynamic>{
          'data': <String, dynamic>{
            'user': <String, dynamic>{
              ...verified,
              if (walletAddress.isNotEmpty) 'walletAddress': walletAddress,
            },
          },
        },
        walletAddress: walletAddress.isEmpty ? null : walletAddress,
      );
    }
    logResult('failure', detail: 'null-result-api-token-unverified');
    return const NormalizedWalletAuthResult.failed(_noTokenFailureReason);
  }

  logResult('cancel');
  return const NormalizedWalletAuthResult.cancelled();
}

/// Returns the `/api/profiles/me` user map when the current token works,
/// or null when the backend rejects/cannot confirm the session.
Future<Map<String, dynamic>?> _verifyTokenWithProfile(
  BackendApiService api,
  void Function(String result, {String? detail}) logResult,
) async {
  try {
    final profile = await api.getMyProfile();
    final profileData = profile['data'];
    if (profile['success'] == true && profileData is Map) {
      return _stringKeyedMap(profileData);
    }
  } catch (e) {
    if (kDebugMode) {
      AppConfig.debugPrint(
        'AuthWalletResultNormalizer: getMyProfile verification failed (${e.runtimeType})',
      );
    }
  }
  return null;
}

String? _explicitFailureReason(Map<String, dynamic> map) {
  final success = map['success'];
  final error = _clean(map['error'] ?? map['message']);
  final errorCode = _clean(map['errorCode'] ?? map['error_code']);
  final code = _clean(map['code']);
  if (success == false) {
    return _firstNonEmpty([
      error,
      errorCode,
      _failureCodeReason(code),
      'Wallet authentication failed',
    ]);
  }
  if (error.isNotEmpty || errorCode.isNotEmpty) {
    return _firstNonEmpty([error, errorCode, 'Wallet authentication failed']);
  }
  final codeReason = _failureCodeReason(code);
  return codeReason.isEmpty ? null : codeReason;
}

String _failureCodeReason(String code) {
  final normalized = code.trim().toLowerCase();
  if (normalized.isEmpty) return '';
  const failures = [
    'error',
    'failed',
    'failure',
    'denied',
    'rejected',
    'unauthorized',
    'forbidden',
    'invalid',
  ];
  if (failures.any(normalized.contains)) return code;
  return '';
}

String _extractToken(Map<String, dynamic> source) {
  final data =
      source['data'] is Map ? _stringKeyedMap(source['data'] as Map) : null;
  final auth =
      source['auth'] is Map ? _stringKeyedMap(source['auth'] as Map) : null;
  final session = source['session'] is Map
      ? _stringKeyedMap(source['session'] as Map)
      : null;
  return _firstNonEmpty([
    _clean(source['token']),
    _clean(source['accessToken']),
    _clean(source['authToken']),
    if (data != null) _clean(data['token']),
    if (data != null) _clean(data['accessToken']),
    if (data != null) _clean(data['authToken']),
    if (auth != null) _clean(auth['token']),
    if (session != null) _clean(session['token']),
  ]);
}

String _extractRefreshToken(Map<String, dynamic> source) {
  final data =
      source['data'] is Map ? _stringKeyedMap(source['data'] as Map) : null;
  return _firstNonEmpty([
    _clean(source['refreshToken']),
    _clean(source['refresh_token']),
    if (data != null) _clean(data['refreshToken']),
    if (data != null) _clean(data['refresh_token']),
  ]);
}

Map<String, dynamic> _standardAuthPayload(
  Map<String, dynamic> source, {
  required String walletAddress,
}) {
  final data = source['data'] is Map
      ? _stringKeyedMap(source['data'] as Map)
      : <String, dynamic>{};
  final profile = source['profile'] is Map
      ? _stringKeyedMap(source['profile'] as Map)
      : <String, dynamic>{};

  final user = <String, dynamic>{};
  if (data['user'] is Map) {
    user.addAll(_stringKeyedMap(data['user'] as Map));
  } else if (source['user'] is Map) {
    user.addAll(_stringKeyedMap(source['user'] as Map));
  } else if (profile.isNotEmpty) {
    user.addAll(profile);
  } else if (_looksLikeUserData(data)) {
    user.addAll(data);
  }

  if (walletAddress.isNotEmpty) {
    user['walletAddress'] = walletAddress;
  }

  final normalizedData = <String, dynamic>{
    ...data,
    'user': user,
  };

  return <String, dynamic>{
    ...source,
    'data': normalizedData,
  };
}

bool _looksLikeUserData(Map<String, dynamic> map) {
  return [
    'id',
    'userId',
    'walletAddress',
    'wallet_address',
    'address',
    'username',
    'displayName',
    'email',
  ].any(map.containsKey);
}

String _extractWalletAddress(Map<String, dynamic> source) {
  final data =
      source['data'] is Map ? _stringKeyedMap(source['data'] as Map) : null;
  final user = data?['user'] is Map
      ? _stringKeyedMap(data!['user'] as Map)
      : source['user'] is Map
          ? _stringKeyedMap(source['user'] as Map)
          : null;
  final profile = source['profile'] is Map
      ? _stringKeyedMap(source['profile'] as Map)
      : null;

  return _firstNonEmpty([
    if (user != null) _walletFromMap(user),
    if (data != null) _walletFromMap(data),
    if (profile != null) _walletFromMap(profile),
    _walletFromMap(source),
  ]);
}

String _walletFromMap(Map<String, dynamic> map) {
  return _firstNonEmpty([
    _clean(map['walletAddress']),
    _clean(map['wallet_address']),
    _clean(map['wallet']),
    _clean(map['address']),
  ]);
}

Map<String, dynamic> _stringKeyedMap(Map source) {
  return <String, dynamic>{
    for (final entry in source.entries) entry.key.toString(): entry.value,
  };
}

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _clean(Object? value) => (value ?? '').toString().trim();
