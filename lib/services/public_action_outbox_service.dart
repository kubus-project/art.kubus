import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import 'http_client_factory.dart';
import 'public_fallback_service.dart';
import 'solana_wallet_service.dart';
import 'telemetry/telemetry_uuid.dart';

Map<String, dynamic> _normalizeQueuedActionPayload(dynamic raw) {
  if (raw is! Map) {
    return const <String, dynamic>{};
  }

  final keys = raw.keys.map((entry) => entry.toString()).toList()..sort();
  final normalized = <String, dynamic>{};
  for (final key in keys) {
    normalized[key] = _normalizeQueuedActionJsonValue(raw[key]);
  }
  return normalized;
}

dynamic _normalizeQueuedActionJsonValue(dynamic value) {
  if (value is Map) {
    return _normalizeQueuedActionPayload(value);
  }
  if (value is List) {
    return value.map(_normalizeQueuedActionJsonValue).toList(growable: false);
  }
  return value;
}

class PublicActionDraftPayload {
  const PublicActionDraftPayload({
    required this.actionType,
    required this.entityType,
    required this.entityId,
    this.payload = const <String, dynamic>{},
  });

  final String actionType;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> payload;
}

class PublicQueuedActionRecord {
  const PublicQueuedActionRecord({
    required this.clientActionId,
    required this.walletAddress,
    required this.actionType,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    required this.payload,
    required this.signature,
    required this.publicKey,
  });

  final String clientActionId;
  final String walletAddress;
  final String actionType;
  final String entityType;
  final String entityId;
  final String createdAt;
  final Map<String, dynamic> payload;
  final String signature;
  final String publicKey;

  factory PublicQueuedActionRecord.fromJson(Map<String, dynamic> json) {
    return PublicQueuedActionRecord(
      clientActionId: (json['clientActionId'] ?? '').toString().trim(),
      walletAddress: (json['walletAddress'] ?? '').toString().trim(),
      actionType: (json['actionType'] ?? '').toString().trim(),
      entityType: (json['entityType'] ?? '').toString().trim(),
      entityId: (json['entityId'] ?? '').toString().trim(),
      createdAt: (json['createdAt'] ?? '').toString().trim(),
      payload: _normalizeQueuedActionPayload(json['payload']),
      signature: (json['signature'] ?? '').toString().trim(),
      publicKey: (json['publicKey'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clientActionId': clientActionId,
      'walletAddress': walletAddress,
      'actionType': actionType,
      'entityType': entityType,
      'entityId': entityId,
      'createdAt': createdAt,
      'payload': _normalizeQueuedActionPayload(payload),
      'signature': signature,
      'publicKey': publicKey,
    };
  }
}

class PublicActionFlushResultRecord {
  const PublicActionFlushResultRecord({
    required this.sentCount,
    required this.removedCount,
    required this.remainingCount,
    this.results = const <Map<String, dynamic>>[],
  });

  final int sentCount;
  final int removedCount;
  final int remainingCount;
  final List<Map<String, dynamic>> results;
}

class PublicActionOutboxService extends ChangeNotifier {
  PublicActionOutboxService._internal()
      : _client = createPlatformHttpClient(),
        _fallbackService = PublicFallbackService() {
    _lastSeenMode = _fallbackService.mode;
    _fallbackService.addListener(_handleModeChanged);
  }

  static final PublicActionOutboxService _instance =
      PublicActionOutboxService._internal();

  factory PublicActionOutboxService() => _instance;

  static const String _queueKeyPrefix = 'public_action_outbox_v1_';
  static const int _maxBatchSize = 50;

  final PublicFallbackService _fallbackService;
  http.Client _client;
  SolanaWalletService? _walletService;
  String? Function()? _walletAddressResolver;
  Future<void>? _initializeFuture;
  Future<PublicActionFlushResultRecord>? _flushFuture;
  AppRuntimeMode _lastSeenMode = AppRuntimeMode.live;
  int _queuedActionCount = 0;

  int get queuedActionCount => _queuedActionCount;
  AppRuntimeMode get lastSeenMode => _lastSeenMode;

  Future<void> initialize() {
    final existing = _initializeFuture;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _initializeFuture = completer.future;

    () async {
      try {
        await _refreshQueuedActionCount();
        _scheduleFlushIfWritable();
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
        _initializeFuture = null;
      }
    }();

    return completer.future;
  }

  void bindSigner({
    required SolanaWalletService walletService,
    required String? Function() walletAddressResolver,
  }) {
    _walletService = walletService;
    _walletAddressResolver = walletAddressResolver;
  }

  Future<PublicQueuedActionRecord> enqueueSignedAction(
    PublicActionDraftPayload draft,
  ) async {
    await initialize();
    _assertSupported(draft.actionType, draft.entityType);
    final entityId = draft.entityId.trim();
    if (entityId.isEmpty) {
      throw Exception('Queued public actions require a non-empty entityId.');
    }

    final signer = _walletService;
    if (signer == null || !signer.hasActiveKeyPair) {
      throw Exception('Wallet signer unavailable for queued public actions.');
    }

    final signerWallet = (signer.activePublicKey ?? '').trim();
    final resolvedWallet =
        ((_walletAddressResolver?.call() ?? '').trim()).ifEmpty(signerWallet);
    if (signerWallet.isEmpty || resolvedWallet.isEmpty) {
      throw Exception('Wallet signer unavailable for queued public actions.');
    }
    if (signerWallet != resolvedWallet) {
      throw Exception(
        'Current wallet and signing key must match for queued public actions.',
      );
    }

    final normalizedActionType = draft.actionType.trim().toLowerCase();
    final normalizedEntityType = draft.entityType.trim().toLowerCase();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    final payload = _normalizePayload(draft.payload);
    final clientActionId = TelemetryUuid.v4();
    final message = _stableJsonEncode(<String, dynamic>{
      'actionType': normalizedActionType,
      'clientActionId': clientActionId,
      'createdAt': createdAt,
      'entityId': entityId,
      'entityType': normalizedEntityType,
      'payload': payload,
      'walletAddress': resolvedWallet,
    });
    final signature = await signer.signMessageBase64(
      base64Encode(utf8.encode(message)),
    );

    final record = PublicQueuedActionRecord(
      clientActionId: clientActionId,
      walletAddress: resolvedWallet,
      actionType: normalizedActionType,
      entityType: normalizedEntityType,
      entityId: entityId,
      createdAt: createdAt,
      payload: payload,
      signature: signature,
      publicKey: signerWallet,
    );

    final queue = await _loadQueueForWallet(record.walletAddress);
    queue.add(record);
    queue.sort(
      (left, right) => left.createdAt.compareTo(right.createdAt),
    );
    await _persistQueue(record.walletAddress, queue);
    await _refreshQueuedActionCount();
    notifyListeners();
    return record;
  }

  Future<PublicActionFlushResultRecord> flush() async {
    if (_fallbackService.mode == AppRuntimeMode.ipfsFallback) {
      return PublicActionFlushResultRecord(
        sentCount: 0,
        removedCount: 0,
        remainingCount: _queuedActionCount,
      );
    }

    final existing = _flushFuture;
    if (existing != null) return existing;

    final completer = Completer<PublicActionFlushResultRecord>();
    _flushFuture = completer.future;

    () async {
      var sentCount = 0;
      var removedCount = 0;
      final aggregatedResults = <Map<String, dynamic>>[];

      try {
        await initialize();
        final prefs = await SharedPreferences.getInstance();
        final walletKeys = prefs
            .getKeys()
            .where((key) => key.startsWith(_queueKeyPrefix))
            .toList(growable: false)
          ..sort();

        for (final key in walletKeys) {
          final walletAddress = key.substring(_queueKeyPrefix.length);
          var queue = await _loadQueueForWallet(walletAddress);
          if (queue.isEmpty) {
            continue;
          }

          final attemptedActionIds = <String>{};

          while (queue.isNotEmpty) {
            final batch = queue
                .where((entry) =>
                    !attemptedActionIds.contains(entry.clientActionId))
                .take(_maxBatchSize)
                .toList(growable: false);
            if (batch.isEmpty) {
              break;
            }

            attemptedActionIds.addAll(
              batch.map((entry) => entry.clientActionId),
            );

            final results = await _postActionBatch(batch);
            if (results == null) {
              final remainingCount = await _refreshQueuedActionCount();
              completer.complete(
                PublicActionFlushResultRecord(
                  sentCount: sentCount,
                  removedCount: removedCount,
                  remainingCount: remainingCount,
                  results: aggregatedResults,
                ),
              );
              _flushFuture = null;
              return;
            }

            aggregatedResults.addAll(results);
            sentCount += batch.length;
            final removableIds = results
                .where((entry) {
                  final status =
                      (entry['status'] ?? '').toString().trim().toLowerCase();
                  return status == 'applied' ||
                      status == 'duplicate' ||
                      status == 'rejected';
                })
                .map((entry) =>
                    (entry['clientActionId'] ?? '').toString().trim())
                .where((value) => value.isNotEmpty)
                .toSet();

            if (removableIds.isEmpty) {
              continue;
            }

            final beforeLength = queue.length;
            queue = queue
                .where((entry) => !removableIds.contains(entry.clientActionId))
                .toList(growable: false);
            removedCount += beforeLength - queue.length;
            await _persistQueue(walletAddress, queue);
          }
        }

        final remainingCount = await _refreshQueuedActionCount();
        completer.complete(
          PublicActionFlushResultRecord(
            sentCount: sentCount,
            removedCount: removedCount,
            remainingCount: remainingCount,
            results: aggregatedResults,
          ),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _flushFuture = null;
      }
    }();

    return completer.future;
  }

  void bindHttpClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _client = createPlatformHttpClient();
    _walletService = null;
    _walletAddressResolver = null;
    _queuedActionCount = 0;
    _lastSeenMode = _fallbackService.mode;
    notifyListeners();
  }

  Future<List<PublicQueuedActionRecord>> _loadQueueForWallet(
    String walletAddress,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_queueKeyPrefix$walletAddress') ??
        const <String>[];
    return raw
        .map((entry) {
          try {
            final decoded = jsonDecode(entry);
            if (decoded is! Map) {
              return null;
            }
            return PublicQueuedActionRecord.fromJson(
              Map<String, dynamic>.from(decoded),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<PublicQueuedActionRecord>()
        .toList(growable: true);
  }

  Future<void> _persistQueue(
    String walletAddress,
    List<PublicQueuedActionRecord> queue,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_queueKeyPrefix$walletAddress';
    if (queue.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setStringList(
      key,
      queue.map((entry) => jsonEncode(entry.toJson())).toList(growable: false),
    );
  }

  Future<List<Map<String, dynamic>>?> _postActionBatch(
    List<PublicQueuedActionRecord> batch,
  ) async {
    Object? lastError;

    for (final baseUrl in _fallbackService.preferredWriteBaseUrls) {
      try {
        final response = await _client
            .post(
              Uri.parse(
                '${_normalizeBaseUrl(baseUrl)}/api/public-sync/actions',
              ),
              headers: const <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'actions': batch
                    .map((entry) => entry.toJson())
                    .toList(growable: false),
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = Exception(
            'Public action replay failed (${response.statusCode})',
          );
          continue;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['results'] is List) {
          _fallbackService.recordBackendSuccess(baseUrl: baseUrl);
          return (decoded['results'] as List)
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList(growable: false);
        }
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      AppConfig.debugPrint(
        'PublicActionOutboxService.flush failed: $lastError',
      );
      _fallbackService.recordDualBackendFailure();
    }
    return null;
  }

  Future<int> _refreshQueuedActionCount() async {
    final prefs = await SharedPreferences.getInstance();
    final total = prefs
        .getKeys()
        .where((key) => key.startsWith(_queueKeyPrefix))
        .map((key) => prefs.getStringList(key)?.length ?? 0)
        .fold<int>(0, (sum, value) => sum + value);
    _queuedActionCount = total;
    return total;
  }

  void _assertSupported(String actionType, String entityType) {
    final normalizedAction = actionType.trim().toLowerCase();
    final normalizedEntity = entityType.trim().toLowerCase();

    const supported = <String>{
      'artwork:like',
      'artwork:unlike',
      'artwork:bookmark',
      'artwork:unbookmark',
      'artwork:discover',
      'post:like',
      'post:unlike',
      'post:bookmark',
      'post:unbookmark',
      'profile:follow',
      'profile:unfollow',
    };

    if (!supported.contains('$normalizedEntity:$normalizedAction')) {
      throw Exception(
        'Unsupported queued action: $normalizedEntity:$normalizedAction',
      );
    }
  }

  void _handleModeChanged() {
    final currentMode = _fallbackService.mode;
    final modeChanged = _lastSeenMode != currentMode;
    _lastSeenMode = currentMode;

    _scheduleFlushIfWritable();
    if (modeChanged) {
      notifyListeners();
    }
  }

  void _scheduleFlushIfWritable() {
    if (_queuedActionCount <= 0 ||
        _fallbackService.mode == AppRuntimeMode.ipfsFallback) {
      return;
    }
    unawaited(flush());
  }

  static Map<String, dynamic> _normalizePayload(dynamic raw) {
    if (raw is! Map) {
      return const <String, dynamic>{};
    }

    final keys = raw.keys.map((entry) => entry.toString()).toList()..sort();
    final normalized = <String, dynamic>{};
    for (final key in keys) {
      final value = raw[key];
      normalized[key] = _normalizeJsonValue(value);
    }
    return normalized;
  }

  static dynamic _normalizeJsonValue(dynamic value) {
    if (value is Map) {
      return _normalizePayload(value);
    }
    if (value is List) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    return value;
  }

  static String _stableJsonEncode(dynamic value) {
    return jsonEncode(_normalizeJsonValue(value));
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}

extension on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : trim();
  }
}
