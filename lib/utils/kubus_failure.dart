import 'dart:async';

import 'package:http/http.dart' as http;

import '../services/backend_api_service.dart';

/// Product error taxonomy. Each kind has its own copy and recovery action
/// (see `KubusStateView`); screens never show a raw exception string.
enum KubusFailureKind {
  /// The request left the device but failed or timed out in transit.
  network,

  /// The device has no route to the network (DNS/unreachable).
  offline,

  /// The backend answered with a 5xx or an upstream timeout.
  server,

  /// The session is missing or expired (401).
  authentication,

  /// Signed in, but not allowed (403).
  permission,

  /// The subject does not exist or is no longer public (404/410).
  notFound,

  /// The request was rejected as invalid (400/409/422).
  validation,

  /// Too many requests (429).
  rateLimit,

  /// Wallet missing, disconnected, locked or on the wrong network.
  wallet,

  /// The feature or device capability is not available here.
  unsupported,

  /// Anything we cannot classify truthfully.
  unknown,
}

/// Classifies any thrown object into a [KubusFailureKind].
///
/// Pure and side-effect free; screens pass the caught error and render the
/// matching state. Unknown shapes fall back to [KubusFailureKind.unknown]
/// rather than guessing a cause.
KubusFailureKind classifyKubusFailure(Object? error) {
  if (error == null) return KubusFailureKind.unknown;
  if (error is KubusFailureKind) return error;
  if (error is BackendApiRequestException) {
    return kubusFailureKindForStatus(error.statusCode, body: error.body);
  }
  if (error is TimeoutException) return KubusFailureKind.network;
  if (error is UnsupportedError || error is UnimplementedError) {
    return KubusFailureKind.unsupported;
  }
  final text = error.toString().toLowerCase();
  if (_offlineMarkers.any(text.contains)) return KubusFailureKind.offline;
  if (error is http.ClientException || _networkMarkers.any(text.contains)) {
    return KubusFailureKind.network;
  }
  if (_walletMarkers.any(text.contains)) return KubusFailureKind.wallet;
  return KubusFailureKind.unknown;
}

/// Maps an HTTP status (0 = transport failure) to a failure kind.
KubusFailureKind kubusFailureKindForStatus(int statusCode, {String? body}) {
  if (statusCode == 0) {
    final text = (body ?? '').toLowerCase();
    if (_offlineMarkers.any(text.contains)) return KubusFailureKind.offline;
    return KubusFailureKind.network;
  }
  if (statusCode == 401) return KubusFailureKind.authentication;
  if (statusCode == 403) return KubusFailureKind.permission;
  if (statusCode == 404 || statusCode == 410) return KubusFailureKind.notFound;
  if (statusCode == 429) return KubusFailureKind.rateLimit;
  if (statusCode == 400 || statusCode == 409 || statusCode == 422) {
    return KubusFailureKind.validation;
  }
  if (statusCode == 501) return KubusFailureKind.unsupported;
  if (statusCode >= 500) return KubusFailureKind.server;
  return KubusFailureKind.unknown;
}

const List<String> _offlineMarkers = <String>[
  'failed host lookup',
  'network is unreachable',
  'no address associated',
  'no internet',
  'internet connection appears to be offline',
  'err_internet_disconnected',
];

const List<String> _networkMarkers = <String>[
  'socketexception',
  'connection refused',
  'connection reset',
  'connection closed',
  'xmlhttprequest error',
  'failed to fetch',
  'handshakeexception',
  'timed out',
];

const List<String> _walletMarkers = <String>[
  'no wallet',
  'wallet not connected',
  'wallet is locked',
  'signer',
  'wrong network',
  'user rejected',
];
