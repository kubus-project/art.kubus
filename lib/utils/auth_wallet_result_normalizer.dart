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

Future<NormalizedWalletAuthResult> normalizeWalletAuthResult({
  required Object? routeResult,
  required BackendApiService api,
  String? fallbackWalletAddress,
  bool hadAuthBeforeOpen = false,
}) async {
  final fallbackWallet = _clean(fallbackWalletAddress);
  final authTokenExists = _clean(api.getAuthToken()).isNotEmpty;
  final currentAuthWallet = _clean(api.getCurrentAuthWalletAddress());

  void logResult(String result) {
    if (!kDebugMode) return;
    AppConfig.debugPrint(
      'AuthWalletResultNormalizer: routeResultType=${routeResult.runtimeType}, '
      'routeResultIsMap=${routeResult is Map}, '
      'authTokenExists=$authTokenExists, '
      'currentAuthWalletExists=${currentAuthWallet.isNotEmpty}, '
      'fallbackWalletExists=${fallbackWallet.isNotEmpty}, '
      'hadAuthBeforeOpen=$hadAuthBeforeOpen, '
      'result=$result',
    );
  }

  if (routeResult is Map) {
    final map = _stringKeyedMap(routeResult);
    final failureReason = _explicitFailureReason(map);
    if (failureReason != null) {
      logResult('failure');
      return NormalizedWalletAuthResult.failed(failureReason);
    }

    final walletAddress = _firstNonEmpty([
      _extractWalletAddress(map),
      currentAuthWallet,
      fallbackWallet,
    ]);
    if (!_hasAuthEvidence(map, walletAddress: walletAddress)) {
      logResult('failure');
      return const NormalizedWalletAuthResult.failed(
        'Wallet authentication result did not include user, token, or wallet information',
      );
    }
    final payload = _standardAuthPayload(
      map,
      walletAddress: walletAddress,
    );
    logResult('success');
    return NormalizedWalletAuthResult.success(
      payload,
      walletAddress: walletAddress.isEmpty ? null : walletAddress,
    );
  }

  if (routeResult != null) {
    logResult('failure');
    return NormalizedWalletAuthResult.failed(
      'Unexpected wallet authentication result: ${routeResult.runtimeType}',
    );
  }

  if (authTokenExists) {
    try {
      final profile = await api.getMyProfile();
      final profileData = profile['data'];
      if (profile['success'] == true && profileData is Map) {
        final profileMap = _stringKeyedMap(profileData);
        final walletAddress = _firstNonEmpty([
          _extractWalletAddress(profileMap),
          currentAuthWallet,
          fallbackWallet,
        ]);
        logResult('success');
        return NormalizedWalletAuthResult.success(
          _standardAuthPayload(
            <String, dynamic>{
              'data': {'user': profileMap}
            },
            walletAddress: walletAddress,
          ),
          walletAddress: walletAddress.isEmpty ? null : walletAddress,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint(
          'AuthWalletResultNormalizer: getMyProfile failed; using wallet evidence when available (${e.runtimeType})',
        );
      }
    }

    final walletAddress = _firstNonEmpty([currentAuthWallet, fallbackWallet]);
    if (walletAddress.isNotEmpty) {
      logResult('success');
      return NormalizedWalletAuthResult.success(
        _walletOnlyPayload(walletAddress),
        walletAddress: walletAddress,
      );
    }
  }

  final walletAddress = _firstNonEmpty([currentAuthWallet, fallbackWallet]);
  if (walletAddress.isNotEmpty) {
    logResult('success');
    return NormalizedWalletAuthResult.success(
      _walletOnlyPayload(walletAddress),
      walletAddress: walletAddress,
    );
  }

  logResult('cancel');
  return const NormalizedWalletAuthResult.cancelled();
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

Map<String, dynamic> _walletOnlyPayload(String walletAddress) {
  return <String, dynamic>{
    'data': <String, dynamic>{
      'user': <String, dynamic>{'walletAddress': walletAddress},
    },
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

bool _hasAuthEvidence(
  Map<String, dynamic> source, {
  required String walletAddress,
}) {
  if (walletAddress.trim().isNotEmpty) return true;

  final data = source['data'] is Map
      ? _stringKeyedMap(source['data'] as Map)
      : <String, dynamic>{};
  final user = data['user'] is Map
      ? _stringKeyedMap(data['user'] as Map)
      : source['user'] is Map
          ? _stringKeyedMap(source['user'] as Map)
          : <String, dynamic>{};
  final profile = source['profile'] is Map
      ? _stringKeyedMap(source['profile'] as Map)
      : <String, dynamic>{};

  return _clean(source['token']).isNotEmpty ||
      _clean(source['authToken']).isNotEmpty ||
      _clean(source['accessToken']).isNotEmpty ||
      _looksLikeUserData(user) ||
      _looksLikeUserData(profile) ||
      _looksLikeUserData(data);
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
