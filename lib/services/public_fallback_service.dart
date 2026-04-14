import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import 'http_client_factory.dart';
import 'storage_config.dart';

enum AppRuntimeMode {
  live,
  standby,
  ipfsFallback,
}

class BackendWritableStatusRecord {
  const BackendWritableStatusRecord({
    required this.baseUrl,
    required this.reachable,
    required this.writable,
    required this.databaseRole,
    required this.checkedAt,
    this.preferredWriteBaseUrl,
    this.preferredReadBaseUrl,
    this.nodeApiBaseUrl,
    this.peerApiBaseUrl,
    this.switchRecommended = false,
    this.switchReason,
    this.statusCode,
    this.error,
  });

  final String baseUrl;
  final bool reachable;
  final bool writable;
  final String databaseRole;
  final DateTime checkedAt;
  final String? preferredWriteBaseUrl;
  final String? preferredReadBaseUrl;
  final String? nodeApiBaseUrl;
  final String? peerApiBaseUrl;
  final bool switchRecommended;
  final String? switchReason;
  final int? statusCode;
  final String? error;
}

class PublicSnapshotDatasetRecord {
  const PublicSnapshotDatasetRecord({
    required this.cid,
    this.generatedAt,
  });

  final String cid;
  final DateTime? generatedAt;

  factory PublicSnapshotDatasetRecord.fromJson(Map<String, dynamic> json) {
    return PublicSnapshotDatasetRecord(
      cid: (json['cid'] ?? '').toString().trim(),
      generatedAt: DateTime.tryParse((json['generatedAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cid': cid,
      if (generatedAt != null) 'generatedAt': generatedAt!.toIso8601String(),
    };
  }
}

class PublicSnapshotRegistryRecord {
  const PublicSnapshotRegistryRecord({
    required this.version,
    required this.generatedAt,
    required this.datasets,
  });

  final String version;
  final DateTime? generatedAt;
  final Map<String, PublicSnapshotDatasetRecord> datasets;

  factory PublicSnapshotRegistryRecord.fromJson(Map<String, dynamic> json) {
    final rawDatasets = json['datasets'];
    final datasets = <String, PublicSnapshotDatasetRecord>{};

    if (rawDatasets is Map) {
      for (final entry in rawDatasets.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value;
        if (key.isEmpty || value is! Map) continue;
        final dataset = PublicSnapshotDatasetRecord.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (dataset.cid.isEmpty) continue;
        datasets[key] = dataset;
      }
    }

    return PublicSnapshotRegistryRecord(
      version: (json['version'] ?? '').toString().trim(),
      generatedAt: DateTime.tryParse((json['generatedAt'] ?? '').toString()),
      datasets: datasets,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      if (generatedAt != null) 'generatedAt': generatedAt!.toIso8601String(),
      'datasets': datasets.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

class PublicFallbackService extends ChangeNotifier {
  PublicFallbackService._internal()
      : _client = createPlatformHttpClient(),
        _mode = AppRuntimeMode.live;

  static final PublicFallbackService _instance =
      PublicFallbackService._internal();

  factory PublicFallbackService() => _instance;

  static const Set<String> requiredDatasetKeys = <String>{
    'artworks',
    'profiles',
    'collections',
    'markers',
    'events',
    'exhibitions',
    'communityFeed',
  };

  static const String _registryCacheKey = 'public_snapshot_registry_cache_v1';
  static const String _registryRawCacheKey =
      'public_snapshot_registry_raw_cache_v1';
  static const String _datasetRawCachePrefix =
      'public_snapshot_dataset_raw_cache_v1_';
  static const String _datasetCidCachePrefix =
      'public_snapshot_dataset_cid_cache_v1_';

  http.Client _client;
  AppRuntimeMode _mode;
  Timer? _healthTimer;
  bool _isAppForeground = true;
  Duration? _healthMonitorInterval;
  final Random _healthMonitorJitter = Random();
  Future<void>? _initializeFuture;
  Future<void>? _refreshHealthFuture;
  bool _initialized = false;
  int _consecutiveDualFailures = 0;
  int _consecutiveRecoverySuccesses = 0;
  BackendWritableStatusRecord? _primaryStatus;
  BackendWritableStatusRecord? _standbyStatus;
  DateTime? _lastStandbyProbeAt;
  PublicSnapshotRegistryRecord? _registryCache;
  final Map<String, List<dynamic>> _datasetCache = <String, List<dynamic>>{};
  final Map<String, String> _datasetCidCache = <String, String>{};

  AppRuntimeMode get mode => _mode;
  bool get isIpfsFallbackMode => _mode == AppRuntimeMode.ipfsFallback;
  int get consecutiveDualFailures => _consecutiveDualFailures;
  int get consecutiveRecoverySuccesses => _consecutiveRecoverySuccesses;
  BackendWritableStatusRecord? get primaryStatus => _primaryStatus;
  BackendWritableStatusRecord? get standbyStatus => _standbyStatus;

  List<String> get preferredReadBaseUrls {
    if (_mode == AppRuntimeMode.standby) {
      return <String>[AppConfig.standbyApiUrl, AppConfig.baseApiUrl];
    }
    return <String>[AppConfig.baseApiUrl, AppConfig.standbyApiUrl];
  }

  List<String> get preferredWriteBaseUrls => preferredReadBaseUrls;

  Future<void> initialize() {
    final existing = _initializeFuture;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _initializeFuture = completer.future;

    () async {
      try {
        if (!_initialized) {
          await _hydrateCaches();
          _startHealthMonitor();
          _initialized = true;
        }
        await refreshBackendMode();
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
        _initializeFuture = null;
      }
    }();

    return completer.future;
  }

  void setAppForeground(bool isForeground) {
    if (_isAppForeground == isForeground) return;
    _isAppForeground = isForeground;
    _startHealthMonitor(forceRestart: true);
    if (isForeground) {
      unawaited(refreshBackendMode());
    }
  }

  Future<void> refreshBackendMode() async {
    final existing = _refreshHealthFuture;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _refreshHealthFuture = completer.future;

    () async {
      try {
        final primary = await _fetchWritableStatus(AppConfig.baseApiUrl);
        final shouldProbeStandby = _shouldProbeStandbyNow(primary: primary);
        final standby = shouldProbeStandby
            ? await _fetchWritableStatus(AppConfig.standbyApiUrl)
            : _standbyStatus;

        _primaryStatus = primary;
        _standbyStatus = standby;
        if (shouldProbeStandby) {
          _lastStandbyProbeAt = DateTime.now().toUtc();
        }

        final hintedMode = _resolveHintedMode(
          primary: _primaryStatus!,
          standby: _standbyStatus ??
              BackendWritableStatusRecord(
                baseUrl: AppConfig.standbyApiUrl,
                reachable: false,
                writable: false,
                databaseRole: 'unavailable',
                checkedAt: DateTime.now().toUtc(),
                error: shouldProbeStandby
                    ? null
                    : 'standby probe skipped while primary healthy',
              ),
        );
        final writableMode = _resolveWritableMode(
          primary: _primaryStatus!,
          standby: _standbyStatus ??
              BackendWritableStatusRecord(
                baseUrl: AppConfig.standbyApiUrl,
                reachable: false,
                writable: false,
                databaseRole: 'unavailable',
                checkedAt: DateTime.now().toUtc(),
                error: shouldProbeStandby
                    ? null
                    : 'standby probe skipped while primary healthy',
              ),
        );
        final preferredMode = hintedMode ?? writableMode;

        if (preferredMode != null) {
          _consecutiveDualFailures = 0;
          if (_mode == AppRuntimeMode.ipfsFallback) {
            if (hintedMode != null) {
              _consecutiveRecoverySuccesses = 0;
              _setMode(preferredMode);
            } else {
              _consecutiveRecoverySuccesses += 1;
              if (_consecutiveRecoverySuccesses >=
                  AppConfig.backendRecoverySuccessThreshold) {
                _setMode(preferredMode);
              }
            }
          } else {
            _consecutiveRecoverySuccesses = 0;
            _setMode(preferredMode);
          }
        } else {
          _consecutiveRecoverySuccesses = 0;
          recordDualBackendFailure(notify: false);
        }
        notifyListeners();
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
        _refreshHealthFuture = null;
      }
    }();

    return completer.future;
  }

  void recordBackendSuccess({required String baseUrl}) {
    _consecutiveDualFailures = 0;

    final nextMode = _resolveModeFromSuccessfulBaseUrl(baseUrl);
    if (nextMode == null) {
      _consecutiveRecoverySuccesses = 0;
      return;
    }

    if (_mode == AppRuntimeMode.ipfsFallback) {
      _consecutiveRecoverySuccesses += 1;
      if (_consecutiveRecoverySuccesses >=
          AppConfig.backendRecoverySuccessThreshold) {
        _setMode(nextMode);
      }
    } else {
      _consecutiveRecoverySuccesses = 0;
      _setMode(nextMode);
    }
  }

  void recordDualBackendFailure({bool notify = true}) {
    _consecutiveRecoverySuccesses = 0;
    _consecutiveDualFailures += 1;
    if (_consecutiveDualFailures >= AppConfig.backendOutageFailureThreshold) {
      _setMode(AppRuntimeMode.ipfsFallback, notify: false);
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<PublicSnapshotRegistryRecord?> loadRegistry({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _registryCache != null) {
      return _registryCache;
    }

    if (!forceRefresh) {
      final cached = await _readRegistryFromPrefs();
      if (cached != null) {
        _registryCache = cached.record;
        return _registryCache;
      }
    }

    final candidateUrls =
        StorageConfig.resolveAllUrls(AppConfig.publicSnapshotRegistryUrl);
    if (candidateUrls.isEmpty) {
      return _registryCache;
    }

    Object? lastError;
    for (final candidateUrl in candidateUrls) {
      try {
        final response = await _client.get(
          Uri.parse(candidateUrl),
          headers: const <String, String>{
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          continue;
        }

        final registry = PublicSnapshotRegistryRecord.fromJson(
            Map<String, dynamic>.from(decoded));
        if (!_hasRequiredDatasets(registry)) {
          continue;
        }

        _registryCache = registry;
        await _persistRegistry(registry, response.body);
        return registry;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      AppConfig.debugPrint(
        'PublicFallbackService.loadRegistry failed across all gateways: $lastError',
      );
    }

    return _registryCache;
  }

  Future<List<dynamic>> loadDatasetArray(
    String datasetKey, {
    bool forceRefresh = false,
  }) async {
    final normalizedKey = datasetKey.trim();
    if (normalizedKey.isEmpty) {
      return const <dynamic>[];
    }

    final cachedItems = _datasetCache[normalizedKey];

    if (!forceRefresh && _datasetCache.containsKey(normalizedKey)) {
      return List<dynamic>.from(_datasetCache[normalizedKey]!);
    }

    final registry = await loadRegistry(forceRefresh: forceRefresh);
    final datasetRecord = registry?.datasets[normalizedKey];
    final expectedCid = datasetRecord?.cid;

    if (!forceRefresh) {
      final cached = await _readDatasetFromPrefs(normalizedKey);
      if (cached != null &&
          (expectedCid == null || expectedCid == cached.cachedCid)) {
        _datasetCache[normalizedKey] = List<dynamic>.from(cached.items);
        _datasetCidCache[normalizedKey] = cached.cachedCid;
        return List<dynamic>.from(cached.items);
      }
    }

    if (datasetRecord == null || datasetRecord.cid.isEmpty) {
      return const <dynamic>[];
    }

    final candidateUrls =
        StorageConfig.resolveAllUrls('ipfs://${datasetRecord.cid}');
    if (candidateUrls.isEmpty) {
      return const <dynamic>[];
    }

    Object? lastError;
    for (final candidateUrl in candidateUrls) {
      try {
        final response = await _client.get(
          Uri.parse(candidateUrl),
          headers: const <String, String>{
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }

        final decoded = jsonDecode(response.body);
        final List<dynamic> items;
        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map && decoded['data'] is List) {
          items = List<dynamic>.from(decoded['data'] as List);
        } else {
          continue;
        }

        _datasetCache[normalizedKey] = List<dynamic>.from(items);
        _datasetCidCache[normalizedKey] = datasetRecord.cid;
        await _persistDataset(
          normalizedKey,
          datasetRecord.cid,
          response.body,
        );
        return List<dynamic>.from(items);
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      AppConfig.debugPrint(
        'PublicFallbackService.loadDatasetArray($normalizedKey) failed across all gateways: $lastError',
      );
    }

    return cachedItems == null
        ? const <dynamic>[]
        : List<dynamic>.from(cachedItems);
  }

  void bindHttpClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    _initialized = false;
    _mode = AppRuntimeMode.live;
    _consecutiveDualFailures = 0;
    _consecutiveRecoverySuccesses = 0;
    _primaryStatus = null;
    _standbyStatus = null;
    _lastStandbyProbeAt = null;
    _registryCache = null;
    _datasetCache.clear();
    _datasetCidCache.clear();
    _client = createPlatformHttpClient();
    notifyListeners();
  }

  Duration _computeHealthMonitorInterval() {
    Duration atLeastConfigured(Duration candidate) {
      final configured = AppConfig.backendModeHealthCheckInterval;
      return candidate < configured ? configured : candidate;
    }

    if (_mode == AppRuntimeMode.ipfsFallback) {
      return atLeastConfigured(_isAppForeground
          ? const Duration(seconds: 40)
          : const Duration(seconds: 120));
    }

    if (_isAppForeground) {
      return atLeastConfigured(const Duration(seconds: 75));
    }

    return atLeastConfigured(const Duration(seconds: 240));
  }

  Duration _standbyProbeIntervalWhenPrimaryHealthy() {
    if (_isAppForeground) {
      return const Duration(minutes: 6);
    }
    return const Duration(minutes: 12);
  }

  bool _shouldProbeStandbyNow({
    required BackendWritableStatusRecord primary,
  }) {
    if (_isSameBaseUrl(AppConfig.baseApiUrl, AppConfig.standbyApiUrl)) {
      return false;
    }

    if (_standbyStatus == null) {
      return true;
    }

    if (!primary.reachable || !primary.writable) {
      return true;
    }

    if (_mode != AppRuntimeMode.live) {
      return true;
    }

    final lastProbeAt = _lastStandbyProbeAt ?? _standbyStatus?.checkedAt;
    if (lastProbeAt == null) {
      return true;
    }

    final elapsed = DateTime.now().toUtc().difference(lastProbeAt);
    return elapsed >= _standbyProbeIntervalWhenPrimaryHealthy();
  }

  void _startHealthMonitor({bool forceRestart = false}) {
    final targetInterval = _computeHealthMonitorInterval();
    if (!forceRestart &&
        _healthTimer != null &&
        _healthMonitorInterval == targetInterval) {
      return;
    }

    _healthTimer?.cancel();
    _healthMonitorInterval = targetInterval;

    final maxJitterMs = (targetInterval.inMilliseconds ~/ 5).clamp(2000, 12000);
    final jitterMs = _healthMonitorJitter.nextInt(maxJitterMs);
    final effectiveInterval = targetInterval + Duration(milliseconds: jitterMs);
    _healthTimer = Timer.periodic(effectiveInterval, (_) {
      unawaited(refreshBackendMode());
    });
  }

  Future<void> _hydrateCaches() async {
    final cachedRegistry = await _readRegistryFromPrefs();
    if (cachedRegistry != null) {
      _registryCache = cachedRegistry.record;
    }
  }

  Future<BackendWritableStatusRecord> _fetchWritableStatus(
      String baseUrl) async {
    final localCheckedAt = DateTime.now().toUtc();
    final uri = Uri.parse('${_normalizeBaseUrlValue(baseUrl)}/health/writable');
    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      Map<String, dynamic>? payload;
      if (response.body.trim().isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      }

      final databaseRole =
          (payload?['databaseRole'] ?? payload?['role'] ?? 'unavailable')
              .toString()
              .trim()
              .toLowerCase();
      final checkedAt = DateTime.tryParse(
            (payload?['checkedAt'] ?? '').toString(),
          )?.toUtc() ??
          localCheckedAt;
      final writable = response.statusCode == 200 &&
          (payload?['writable'] == null || payload?['writable'] == true);
      final reachable = response.statusCode == 200 ||
          (response.statusCode == 503 && databaseRole.isNotEmpty);
      final preferredWriteBaseUrl =
          _normalizeOptionalBaseUrl(payload?['preferredWriteBaseUrl']);
      final preferredReadBaseUrl =
          _normalizeOptionalBaseUrl(payload?['preferredReadBaseUrl']);
      final nodeApiBaseUrl = _normalizeOptionalBaseUrl(
        payload?['nodeApiBaseUrl'] ?? payload?['apiBaseUrl'],
      );
      final peerApiBaseUrl = _normalizeOptionalBaseUrl(
        payload?['peerApiBaseUrl'] ?? payload?['fallbackApiBaseUrl'],
      );
      final switchRecommended = _parseBoolFlag(payload?['switchRecommended']);
      final switchReason = (payload?['switchReason'] ?? '').toString().trim();

      return BackendWritableStatusRecord(
        baseUrl: baseUrl,
        reachable: reachable,
        writable: writable,
        databaseRole: databaseRole.isEmpty ? 'unavailable' : databaseRole,
        checkedAt: checkedAt,
        preferredWriteBaseUrl: preferredWriteBaseUrl,
        preferredReadBaseUrl: preferredReadBaseUrl,
        nodeApiBaseUrl: nodeApiBaseUrl,
        peerApiBaseUrl: peerApiBaseUrl,
        switchRecommended: switchRecommended,
        switchReason: switchReason.isEmpty ? null : switchReason,
        statusCode: response.statusCode,
        error: payload?['error']?.toString(),
      );
    } catch (error) {
      return BackendWritableStatusRecord(
        baseUrl: baseUrl,
        reachable: false,
        writable: false,
        databaseRole: 'unavailable',
        checkedAt: localCheckedAt,
        error: error.toString(),
      );
    }
  }

  AppRuntimeMode? _resolveHintedMode({
    required BackendWritableStatusRecord primary,
    required BackendWritableStatusRecord standby,
  }) {
    final preferredTargets = <String>[];

    for (final status in <BackendWritableStatusRecord>[primary, standby]) {
      final preferred = status.preferredWriteBaseUrl;
      if (preferred == null || preferred.isEmpty) {
        continue;
      }

      if (status.switchRecommended) {
        preferredTargets.insert(0, preferred);
      } else {
        preferredTargets.add(preferred);
      }
    }

    for (final preferred in preferredTargets) {
      if (_isSameBaseUrl(preferred, AppConfig.baseApiUrl) &&
          primary.reachable &&
          primary.writable) {
        return AppRuntimeMode.live;
      }

      if (_isSameBaseUrl(preferred, AppConfig.standbyApiUrl) &&
          standby.reachable &&
          standby.writable) {
        return AppRuntimeMode.standby;
      }
    }

    return null;
  }

  AppRuntimeMode? _resolveWritableMode({
    required BackendWritableStatusRecord primary,
    required BackendWritableStatusRecord standby,
  }) {
    if (primary.reachable && primary.writable) {
      return AppRuntimeMode.live;
    }
    if (standby.reachable && standby.writable) {
      return AppRuntimeMode.standby;
    }
    return null;
  }

  AppRuntimeMode? _resolveModeFromSuccessfulBaseUrl(String baseUrl) {
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (normalizedBaseUrl == _normalizeBaseUrl(AppConfig.baseApiUrl)) {
      return AppRuntimeMode.live;
    }
    if (normalizedBaseUrl == _normalizeBaseUrl(AppConfig.standbyApiUrl) &&
        _standbyStatus?.writable == true) {
      return AppRuntimeMode.standby;
    }
    return null;
  }

  bool _hasRequiredDatasets(PublicSnapshotRegistryRecord registry) {
    return requiredDatasetKeys.every(registry.datasets.containsKey);
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  String? _normalizeOptionalBaseUrl(dynamic baseUrl) {
    final raw = (baseUrl ?? '').toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    return _normalizeBaseUrl(raw);
  }

  bool _parseBoolFlag(dynamic rawValue) {
    if (rawValue is bool) {
      return rawValue;
    }

    if (rawValue is num) {
      return rawValue != 0;
    }

    if (rawValue is String) {
      final normalized = rawValue.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'y' ||
          normalized == 'on';
    }

    return false;
  }

  bool _isSameBaseUrl(String? left, String right) {
    if (left == null || left.trim().isEmpty) {
      return false;
    }
    return _normalizeBaseUrl(left) == _normalizeBaseUrl(right);
  }

  String _normalizeBaseUrlValue(String baseUrl) => _normalizeBaseUrl(baseUrl);

  void _setMode(AppRuntimeMode nextMode, {bool notify = true}) {
    if (_mode == nextMode) {
      if (notify) {
        notifyListeners();
      }
      return;
    }
    _mode = nextMode;
    _startHealthMonitor(forceRestart: true);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _persistRegistry(
    PublicSnapshotRegistryRecord registry,
    String rawJson,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_registryCacheKey, jsonEncode(registry.toJson()));
    await prefs.setString(_registryRawCacheKey, rawJson);
  }

  Future<_RegistryCacheRecord?> _readRegistryFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_registryRawCacheKey);
    final encoded = prefs.getString(_registryCacheKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return null;
      }
      final registry = PublicSnapshotRegistryRecord.fromJson(
          Map<String, dynamic>.from(decoded));
      if (!_hasRequiredDatasets(registry)) {
        return null;
      }
      return _RegistryCacheRecord(
        record: registry,
        rawJson: rawJson ?? encoded,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistDataset(
    String datasetKey,
    String cid,
    String rawJson,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_datasetRawCachePrefix$datasetKey', rawJson);
    await prefs.setString('$_datasetCidCachePrefix$datasetKey', cid);
  }

  Future<_DatasetCacheRecord?> _readDatasetFromPrefs(String datasetKey) async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString('$_datasetRawCachePrefix$datasetKey');
    final cachedCid = prefs.getString('$_datasetCidCachePrefix$datasetKey');
    if (rawJson == null || rawJson.trim().isEmpty || cachedCid == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return _DatasetCacheRecord(
          cachedCid: cachedCid,
          items: List<dynamic>.from(decoded),
        );
      }
      if (decoded is Map && decoded['data'] is List) {
        return _DatasetCacheRecord(
          cachedCid: cachedCid,
          items: List<dynamic>.from(decoded['data'] as List),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class _RegistryCacheRecord {
  const _RegistryCacheRecord({
    required this.record,
    required this.rawJson,
  });

  final PublicSnapshotRegistryRecord record;
  final String rawJson;
}

class _DatasetCacheRecord {
  const _DatasetCacheRecord({
    required this.cachedCid,
    required this.items,
  });

  final String cachedCid;
  final List<dynamic> items;
}
