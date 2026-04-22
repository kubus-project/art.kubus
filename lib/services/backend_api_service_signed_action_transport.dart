part of 'backend_api_service.dart';

bool _backendApiShouldQueuePublicActionAfterFailure(
  BackendApiService service, {
  http.Response? response,
  Object? error,
}) {
  if (service._publicFallbackService.mode == AppRuntimeMode.ipfsFallback) {
    return true;
  }

  if (response != null) {
    return service._isTransientWriteStatusCode(response.statusCode);
  }

  final status = error == null ? null : service._tryParseRequestFailedStatus(error);
  if (status != null) {
    return service._isTransientWriteStatusCode(status);
  }

  return error != null;
}

Future<void> _backendApiQueuePublicAction(
  BackendApiService service, {
  required String actionType,
  required String entityType,
  required String entityId,
  Map<String, dynamic> payload = const <String, dynamic>{},
}) async {
  await service._publicActionOutboxService.enqueueSignedAction(
    PublicActionDraftPayload(
      actionType: actionType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
    ),
  );
}

String _backendApiQueueUnavailableMessage(String entityType) {
  switch (entityType.trim().toLowerCase()) {
    case 'artwork':
      return 'Artwork actions are unavailable while the app is running on public snapshot fallback.';
    case 'post':
      return 'Post actions are unavailable while the app is running on public snapshot fallback.';
    case 'profile':
      return 'Follow actions are unavailable while the app is running on public snapshot fallback.';
    default:
      return 'This action is unavailable while the app is running on public snapshot fallback.';
  }
}

void _backendApiThrowIfIpfsFallbackUnavailable(
  BackendApiService service,
  String featureLabel,
) {
  if (service._publicFallbackService.mode != AppRuntimeMode.ipfsFallback) {
    return;
  }
  throw Exception(
    '$featureLabel is unavailable while the app is running on public snapshot fallback.',
  );
}

Map<String, dynamic>? _backendApiDecodeResponseMap(http.Response response) {
  if (response.body.isEmpty) {
    return null;
  }

  final decoded = jsonDecode(response.body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return null;
}

int? _backendApiTryIntValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool? _backendApiTryBoolValue(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (const <String>['true', '1', 'yes', 'y', 'on'].contains(normalized)) {
      return true;
    }
    if (const <String>['false', '0', 'no', 'n', 'off'].contains(normalized)) {
      return false;
    }
  }
  if (value is num) {
    return value != 0;
  }
  return null;
}

int? _backendApiExtractIntFromResponse(
  http.Response response,
  List<String> keys,
) {
  final decoded = _backendApiDecodeResponseMap(response);
  if (decoded == null) {
    return null;
  }

  final candidates = <Map<String, dynamic>>[
    decoded,
    if (decoded['data'] is Map<String, dynamic>)
      decoded['data'] as Map<String, dynamic>,
    if (decoded['data'] is Map) Map<String, dynamic>.from(decoded['data'] as Map),
  ];

  for (final candidate in candidates) {
    for (final key in keys) {
      final value = _backendApiTryIntValue(candidate[key]);
      if (value != null) {
        return value;
      }
    }
  }

  return null;
}

Future<http.Response?> _backendApiSendQueueablePublicAction(
  BackendApiService service, {
  required String method,
  required String path,
  required String actionType,
  required String entityType,
  required String entityId,
  String? walletAddress,
  Map<String, dynamic> payload = const <String, dynamic>{},
  Object? body,
  Encoding? encoding,
  bool isIdempotent = false,
}) async {
  if (service._publicFallbackService.mode == AppRuntimeMode.ipfsFallback) {
    if (!service._publicActionOutboxService.canQueueSignedActions) {
      throw Exception(_backendApiQueueUnavailableMessage(entityType));
    }
    await _backendApiQueuePublicAction(
      service,
      actionType: actionType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
    );
    return null;
  }

  try {
    await service._ensureAuthBeforeRequest(walletAddress: walletAddress);
  } catch (error) {
    if (kDebugMode) {
      AppConfig.debugPrint(
        'BackendApiService: auth prep for $entityType:$actionType failed: $error',
      );
    }
  }

  http.Response? response;
  Object? error;
  try {
    response = await service._sendWriteWithFailover(
      method,
      path,
      includeAuth: true,
      headers: service._getHeaders(),
      body: body,
      encoding: encoding,
      isIdempotent: isIdempotent,
    );
  } catch (caughtError) {
    error = caughtError;
  }

  if (response != null && service._isSuccessStatus(response.statusCode)) {
    return response;
  }

  if (_backendApiShouldQueuePublicActionAfterFailure(
    service,
    response: response,
    error: error,
  )) {
    if (!service._publicActionOutboxService.canQueueSignedActions) {
      if (error != null) {
        throw error;
      }
      throw BackendApiRequestException(
        statusCode: response?.statusCode ?? 0,
        path: path,
        body: response?.body ?? '',
      );
    }
    await _backendApiQueuePublicAction(
      service,
      actionType: actionType,
      entityType: entityType,
      entityId: entityId,
      payload: payload,
    );
    return response;
  }

  if (error != null) {
    throw error;
  }

  throw BackendApiRequestException(
    statusCode: response?.statusCode ?? 0,
    path: path,
    body: response?.body ?? '',
  );
}

class BackendSignedActionTransport {
  const BackendSignedActionTransport(this._service);

  final BackendApiService _service;

  bool hasWalletSignedSessionFor(String walletAddress) {
    final token = (_service.getAuthToken() ?? '').trim();
    final currentWallet = (_service.getCurrentAuthWalletAddress() ?? '').trim();
    if (token.isEmpty || !WalletUtils.equals(currentWallet, walletAddress)) {
      return false;
    }
    return _service.getCurrentAuthLevel() == BackendAuthLevel.walletSigned;
  }

  Future<WalletAuthChallengeDto> requestWalletChallenge(
    String walletAddress,
  ) {
    return _service.requestWalletAuthChallenge(walletAddress);
  }

  Future<AuthSessionPayload> ensureWalletSignedSession({
    required String walletAddress,
    required Future<String> Function(String message) signMessage,
  }) {
    return _service.ensureSessionForActiveSigner(
      walletAddress: walletAddress,
      signMessage: signMessage,
    );
  }

  Future<bool> issueDebugWalletToken(String walletAddress) {
    return _service.issueDebugTokenForWallet(walletAddress);
  }
}
