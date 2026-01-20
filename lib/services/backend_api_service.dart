import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/art_marker.dart';
import '../models/artwork.dart';
import '../models/artwork_comment.dart';
import '../models/community_group.dart';
import '../models/event.dart';
import '../models/exhibition.dart';
import '../models/collab_member.dart';
import '../models/collab_invite.dart';
import '../community/community_interactions.dart';
import '../utils/wallet_utils.dart';
import '../utils/search_suggestions.dart';
import '../utils/media_url_resolver.dart';
import 'share/share_types.dart';
import '../config/config.dart';
import 'storage_config.dart';
import 'user_action_logger.dart';
import 'auth_session_coordinator.dart';
import 'http_client_factory.dart';
import 'telemetry/kubus_client_context.dart';

/// Backend API Service
/// 
/// Provides a centralized interface for all backend API calls.
/// Handles authentication, error handling, and data transformation.
/// 
/// Endpoints:
/// - User/Profile: Register, login, profile management
/// - AR Markers: Geospatial queries, CRUD operations
/// - Artworks: Discovery, interactions, filtering
/// - Community: Posts, likes, shares, comments
/// - Storage: File uploads with metadata

/// Exception that preserves HTTP status for callers that want to implement
/// graceful fallback/backoff behavior (e.g. polling endpoints).
class BackendApiRequestException implements Exception {
  final int statusCode;
  final String path;
  final String? body;

  const BackendApiRequestException({
    required this.statusCode,
    required this.path,
    this.body,
  });

  @override
  String toString() {
    final trimmedBody = (body ?? '').trim();
    if (trimmedBody.isEmpty) return 'BackendApiRequestException($statusCode $path)';
    return 'BackendApiRequestException($statusCode $path): $trimmedBody';
  }
}

/// Minimal contract for artwork endpoints used by providers.
///
/// Providers depend on this interface to allow deterministic unit tests without
/// binding to a real HTTP server.
abstract class ArtworkBackendApi {
  Future<List<Artwork>> getArtworks({
    String? category,
    bool? arEnabled,
    int page = 1,
    int limit = 20,
    String? walletAddress,
    bool includePrivateForWallet = false,
  });

  Future<Artwork> getArtwork(String artworkId);
  Future<Artwork?> updateArtwork(String artworkId, Map<String, dynamic> updates);
  Future<Artwork?> publishArtwork(String artworkId);
  Future<Artwork?> unpublishArtwork(String artworkId);
  Future<int?> likeArtwork(String artworkId);
  Future<int?> unlikeArtwork(String artworkId);
  Future<int?> discoverArtworkWithCount(String artworkId);
  Future<int?> recordArtworkView(String artworkId);

  Future<List<ArtworkComment>> getArtworkComments({
    required String artworkId,
    int page = 1,
    int limit = 50,
  });

  Future<ArtworkComment> createArtworkComment({
    required String artworkId,
    required String content,
    String? parentCommentId,
  });

  Future<ArtworkComment> editArtworkComment({
    required String commentId,
    required String content,
  });

  Future<int?> deleteArtworkComment(String commentId);
  Future<int?> likeComment(String commentId);
  Future<int?> unlikeComment(String commentId);
}

/// Minimal contract for profile endpoints used by providers.
abstract class ProfileBackendApi {
  String get baseUrl;

  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  });

  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress);
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> profileData);

  Future<Map<String, dynamic>> updateProfile(String walletAddress, Map<String, dynamic> updates);

  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  });

  Future<void> followUser(String walletAddress);
  Future<void> unfollowUser(String walletAddress);
  Future<bool> isFollowing(String walletAddress);

  Future<Map<String, dynamic>?> getDAOReview({required String idOrWallet});
}

/// Minimal contract for marker endpoints used by providers.
abstract class MarkerBackendApi {
  String? getAuthToken();
  Future<List<ArtMarker>> getMyArtMarkers();
  Future<ArtMarker?> createArtMarkerRecord(Map<String, dynamic> payload);
  Future<ArtMarker?> updateArtMarkerRecord(String markerId, Map<String, dynamic> updates);
  Future<bool> deleteArtMarkerRecord(String markerId);
}

class BackendApiService implements ArtworkBackendApi, ProfileBackendApi, MarkerBackendApi {
  static final BackendApiService _instance = BackendApiService._internal();
  factory BackendApiService() => _instance;
  BackendApiService._internal() {
    // Ensure a single, consistent HTTP client across the app.
    // On Flutter Web, this enables credentialed requests (cookies) when needed.
    _client = createPlatformHttpClient();
  }

  http.Client _client = http.Client();
  AuthSessionCoordinator? _authCoordinator;

  // Used only for diagnostic logging; the actual behavior is determined by the
  // platform client returned by [createPlatformHttpClient()].
  bool get _webCredentialsExpected => kIsWeb;

  @override
  final String baseUrl = AppConfig.baseApiUrl;
  String? _authToken;
  String? _authWalletCanonical;
  String? _preferredWalletCanonical;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Future<void>? _authInitFuture;
  final Map<String, DateTime> _rateLimitResets = {};
  final Map<String, DateTime> _debugLogThrottle = <String, DateTime>{};

  bool? _exhibitionsApiAvailable;
  bool? _institutionsApiAvailable;
  bool? _eventsApiAvailable;

  bool? get exhibitionsApiAvailable => _exhibitionsApiAvailable;
  bool? get institutionsApiAvailable => _institutionsApiAvailable;
  bool? get eventsApiAvailable => _eventsApiAvailable;

  void bindAuthCoordinator(AuthSessionCoordinator coordinator) {
    _authCoordinator = coordinator;
  }

  /// Hint the API layer about the currently active wallet.
  ///
  /// This is important on web/desktop where tokens can be persisted across
  /// sessions and the connected wallet may change; marker CRUD endpoints are
  /// ownership-gated and will return 403 when the token belongs to a different
  /// wallet.
  void setPreferredWalletAddress(String? walletAddress) {
    final canonical = WalletUtils.canonical(walletAddress);
    _preferredWalletCanonical = canonical.isEmpty ? null : canonical;

    // Best-effort persistence so cold-start auth can re-issue correctly.
    final raw = (walletAddress ?? '').trim();
    if (raw.isEmpty) return;
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(PreferenceKeys.walletAddress, raw);
      } catch (_) {
        // Ignore persistence failures.
      }
    }());
  }

  Map<String, dynamic>? _tryDecodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final parsed = jsonDecode(decoded);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return null;
  }

  String? _tryExtractWalletFromToken(String? token) {
    final t = (token ?? '').trim();
    if (t.isEmpty) return null;
    final payload = _tryDecodeJwtPayload(t);
    if (payload == null) return null;

    // Try common claim keys across backend variants.
    final candidates = <Object?>[
      payload['walletAddress'],
      payload['wallet_address'],
      payload['wallet'],
      payload['user_id'],
      payload['id'],
      payload['sub'],
    ];
    for (final c in candidates) {
      final s = (c ?? '').toString();
      final canonical = WalletUtils.canonical(s);
      if (canonical.isNotEmpty) return canonical;
    }
    return null;
  }

  @visibleForTesting
  void setHttpClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  void setAuthTokenForTesting(String? token) {
    _authToken = token;
  }

  void _debugLogThrottled(
    String key,
    String message, {
    Duration throttle = const Duration(seconds: 8),
  }) {
    if (!kDebugMode) return;
    final now = DateTime.now();
    final lastAt = _debugLogThrottle[key];
    if (lastAt != null && now.difference(lastAt) < throttle) return;
    _debugLogThrottle[key] = now;
    AppConfig.debugPrint(message);
  }

  bool _isExhibitionsPath(Uri uri) {
    final path = uri.path;
    return path.startsWith('/api/exhibitions') || path.contains('/api/exhibitions/');
  }

  bool _isExhibitionsRootPath(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length < 2) return false;
    return segments[0] == 'api' && segments[1] == 'exhibitions' && segments.length == 2;
  }

  int? _tryParseRequestFailedStatus(Object error) {
    // _fetchJson throws Exception('Request failed: <code>')
    final message = error.toString();
    final match = RegExp(r'Request failed: (\d{3})').firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  String _rateLimitKey(String method, Uri uri) => '${method.toUpperCase()} ${uri.path}';

  bool _isRateLimited(String key) {
    final resetAt = _rateLimitResets[key];
    if (resetAt == null) return false;
    if (resetAt.isBefore(DateTime.now())) {
      _rateLimitResets.remove(key);
      return false;
    }
    return true;
  }

  void _markRateLimited(String key, http.Response response, {int defaultWindowMs = 60000}) {
    int windowMs = defaultWindowMs;
    try {
      if (response.headers['retry-after'] != null) {
        final retry = int.tryParse(response.headers['retry-after']!);
        if (retry != null) {
          windowMs = retry * 1000;
        }
      }
      if (response.body.isNotEmpty) {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          final fromBody = parsed['windowMs'] ?? parsed['window_ms'] ?? parsed['retryAfterMs'] ?? parsed['retry_after_ms'];
          if (fromBody is num) {
            windowMs = fromBody.toInt();
          }
        }
      }
    } catch (_) {}
    final resetAt = DateTime.now().add(Duration(milliseconds: windowMs));
    _rateLimitResets[key] = resetAt;
    _debugLogThrottled(
      'rate_limit_set:$key',
      'BackendApiService: rate limit set for $key until $resetAt (window ${windowMs}ms)',
      throttle: const Duration(seconds: 20),
    );
  }

  String _rateLimitMessage(String key) {
    final resetAt = _rateLimitResets[key];
    if (resetAt == null) return 'Rate limit exceeded. Please retry shortly.';
    final remaining = resetAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Rate limit exceeded. Please retry shortly.';
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    final human = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    return 'Rate limit exceeded. Please retry in ~$human.';
  }

  /// Ensure auth token is loaded. If token missing and wallet provided,
  /// attempt a token issuance for that wallet and persist it.
  Future<void> ensureAuthLoaded({String? walletAddress}) async {
    // Fast path when token already present
    if ((_authToken ?? '').isNotEmpty) {
      return;
    }
    // Await any inflight initialization first
    if (_authInitFuture != null) {
      await _authInitFuture!;
      if ((_authToken ?? '').isNotEmpty) {
        return;
      }
    }
    // Run initialization (allowed to retry when token still missing)
    _authInitFuture = _doAuthInit(walletAddress, forceWalletIssuance: true);
    await _authInitFuture;
  }

  Future<void> _doAuthInit(String? walletAddress, {bool forceWalletIssuance = false}) async {
    try {
      await loadAuthToken();
      final hasToken = (_authToken ?? '').isNotEmpty;
      final shouldIssueForWallet = (!hasToken) &&
          (forceWalletIssuance || (walletAddress != null && walletAddress.isNotEmpty));
      if (shouldIssueForWallet && walletAddress != null && walletAddress.isNotEmpty) {
        // Prefer the real auth flow.
        // NOTE: /api/profiles/issue-token is debug-only (API key/admin gated) and
        // should not be used for client auto-auth in production.
        try {
          await registerWallet(
            walletAddress: walletAddress,
            username: 'user_${walletAddress.substring(0, walletAddress.length >= 8 ? 8 : walletAddress.length)}',
          );
          await loadAuthToken();
        } catch (e) {
          if (kDebugMode) {
            AppConfig.debugPrint('BackendApiService._doAuthInit: registerWallet failed: $e');
          }
        }
      }
    } finally {
      _authInitFuture = null;
    }
  }

  /// Ensure we have token loaded; if missing, attempt to issue using a stored wallet.
  Future<void> _ensureAuthWithStoredWallet() async {
    // If token already loaded, nothing to do
    if ((_authToken ?? '').isNotEmpty) return;
    // Try to load token from storage
    await loadAuthToken();
    if ((_authToken ?? '').isNotEmpty) return;
    // No token: check for stored wallet and try issuance
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedWallet = prefs.getString('wallet_address') ?? prefs.getString('wallet') ?? prefs.getString('walletAddress') ?? prefs.getString('user_id');
      if (storedWallet != null && storedWallet.isNotEmpty) {
        _preferredWalletCanonical = WalletUtils.canonical(storedWallet);
        // Attempt to obtain a real JWT for the wallet.
        // This is idempotent server-side (returns token for existing users too).
        try {
          await registerWallet(
            walletAddress: storedWallet,
            username: 'user_${storedWallet.substring(0, storedWallet.length >= 8 ? 8 : storedWallet.length)}',
          );
          await loadAuthToken();
        } catch (e) {
          if (kDebugMode) {
            AppConfig.debugPrint('BackendApiService: registerWallet failed for stored wallet: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint('BackendApiService: _ensureAuthWithStoredWallet failed: $e');
      }
    }
  }

  Future<void> _ensureAuthBeforeRequest({String? walletAddress}) async {
    // Determine which wallet we should be authenticated as.
    //
    // SECURITY: Never auto-issue or switch auth tokens for an arbitrary
    // wallet passed in from a *read* path (e.g. viewing someone else's
    // profile). The only wallet we should authenticate as on the client is
    // the user's own connected/preferred wallet.
    //
    // Rule:
    // - If we have a preferred wallet, we only honor walletAddress when it
    //   matches that preferred wallet.
    // - If we do NOT have a preferred wallet yet (cold start), we can honor
    //   walletAddress (used by explicit sign-in/connect flows).
    final preferredCanonical = (_preferredWalletCanonical ?? '').trim();
    final requestedCanonical = WalletUtils.canonical(walletAddress);
    final canHonorRequested = requestedCanonical.isNotEmpty &&
        (preferredCanonical.isEmpty || requestedCanonical == preferredCanonical);
    final desiredCanonical = canHonorRequested
        ? requestedCanonical
        : (preferredCanonical.isNotEmpty ? preferredCanonical : requestedCanonical);

    if (preferredCanonical.isNotEmpty &&
        requestedCanonical.isNotEmpty &&
        requestedCanonical != preferredCanonical) {
      _debugLogThrottled(
        'ignored_wallet_mismatch',
        'BackendApiService: ignoring requested wallet for auth (mismatch with preferred wallet)',
        throttle: const Duration(seconds: 20),
      );
    }

    // If we already have a token but it's for a different wallet, re-issue.
    if ((_authToken ?? '').isNotEmpty && desiredCanonical.isNotEmpty) {
      _authWalletCanonical ??= _tryExtractWalletFromToken(_authToken);
      final currentCanonical = _authWalletCanonical ?? '';
      if (currentCanonical.isNotEmpty && currentCanonical != desiredCanonical) {
        _debugLogThrottled(
          'auth_wallet_mismatch',
          'BackendApiService: auth token wallet mismatch, re-issuing token',
          throttle: const Duration(seconds: 15),
        );
        // Clear existing token before requesting a token for the desired wallet.
        await clearAuth();
        try {
          await registerWallet(
            walletAddress: walletAddress ?? desiredCanonical,
            username: 'user_${(walletAddress ?? desiredCanonical).substring(0, (walletAddress ?? desiredCanonical).length >= 8 ? 8 : (walletAddress ?? desiredCanonical).length)}',
          );
          await loadAuthToken();
        } catch (e) {
          AppConfig.debugPrint('BackendApiService: token re-issue failed: $e');
        }
      }
    }

    if ((_authToken ?? '').isNotEmpty) return;
    await _ensureAuthWithStoredWallet();
    if ((_authToken ?? '').isNotEmpty) return;
    // Only attempt issuance for the desired wallet (which is either the
    // preferred wallet or, on cold start, an explicitly requested wallet).
    final desiredRaw = desiredCanonical;
    if (desiredRaw.isNotEmpty) {
      try {
        await ensureAuthLoaded(walletAddress: desiredRaw);
      } catch (e) {
        AppConfig.debugPrint('BackendApiService: ensureAuthLoaded for $desiredRaw failed: $e');
      }
    }
  }

  /// Set authentication token for API requests
  Future<void> setAuthToken(String token) async {
    _authToken = token;
    _authWalletCanonical = _tryExtractWalletFromToken(token);
    AppConfig.debugPrint('BackendApiService: Auth token set (in-memory)');
    // Persist token to secure storage and shared preferences (web fallback)
    try {
      await _secureStorage
          .write(key: 'jwt_token', value: token)
          .timeout(const Duration(milliseconds: 800));
      AppConfig.debugPrint('BackendApiService: Auth token written to secure storage');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService: failed to write secure storage token: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      AppConfig.debugPrint('BackendApiService: Auth token written to SharedPreferences fallback');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService: failed to write prefs token: $e');
    }
  }

  /// Load auth token from secure storage
  Future<void> loadAuthToken() async {
    try {
      String? token;
      try {
        token = await _secureStorage
            .read(key: 'jwt_token')
            .timeout(const Duration(milliseconds: 800));
      } catch (e) {
        AppConfig.debugPrint('BackendApiService: secure storage read failed: $e');
      }

      // Fallback to SharedPreferences (useful for web builds where secure storage may not persist)
      if (token == null || token.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          // Try a few known keys for backward compatibility
          token = prefs.getString('jwt_token') ?? prefs.getString('token') ?? prefs.getString('auth_token') ?? prefs.getString('authToken');
          if (token != null && token.isNotEmpty) {
            AppConfig.debugPrint('BackendApiService: Auth token loaded from SharedPreferences fallback');
          }
        } catch (e) {
          AppConfig.debugPrint('BackendApiService: SharedPreferences fallback failed: $e');
        }
      }
      if (token != null && token.isNotEmpty) {
        _authToken = token;
        _authWalletCanonical = _tryExtractWalletFromToken(token);
        AppConfig.debugPrint('BackendApiService: Auth token loaded (in-memory)');
        // Attempt to decode exp field for debug information
        try {
          final parts = token.split('.');
          if (parts.length >= 2) {
            final payload = base64Url.normalize(parts[1]);
            final decoded = utf8.decode(base64Url.decode(payload));
            final map = jsonDecode(decoded) as Map<String, dynamic>;
            if (map.containsKey('exp')) {
              final exp = (map['exp'] as num).toInt();
              final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              final secsLeft = exp - now;
              AppConfig.debugPrint('BackendApiService: token expiry in $secsLeft seconds');
            }
          }
        } catch (e) {
          AppConfig.debugPrint('BackendApiService: failed to decode token expiry: $e');
        }
      } else {
        AppConfig.debugPrint('BackendApiService: No stored auth token found');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService: Error loading auth token: $e');
    }
  }

  /// Clear authentication
  Future<void> clearAuth() async {
    _authToken = null;
    _authWalletCanonical = null;
    _authCoordinator?.reset();
    try {
      await _secureStorage
          .delete(key: 'jwt_token')
          .timeout(const Duration(milliseconds: 800));
      AppConfig.debugPrint('BackendApiService: Auth cleared from secure storage');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService: Error clearing auth token: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      AppConfig.debugPrint('BackendApiService: Auth cleared from SharedPreferences');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService: Error clearing prefs auth token: $e');
    }
  }

  /// Get common headers for API requests
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    headers.addAll(KubusClientContext.instance.headers);

    if (includeAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  Map<String, String> _applyAuthHeader(
    Map<String, String> headers, {
    required bool includeAuth,
  }) {
    if (!includeAuth) return headers;
    final token = (_authToken ?? '').trim();
    if (token.isEmpty) {
      headers.remove('Authorization');
      return headers;
    }

    // Always refresh the Authorization header from the current in-memory token.
    // This matters for re-auth retries: callers often pass a precomputed headers
    // map (containing an expired token). If we keep it, retries will keep
    // sending the stale token even after a successful re-auth.
    headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  bool _looksLikeTokenErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (!lower.contains('token') && !lower.contains('auth')) return false;
    return lower.contains('expired') ||
        lower.contains('invalid') ||
        lower.contains('authentication required') ||
        lower.contains('unauthorized');
  }

  bool _isAuthFailureStatus({
    required int statusCode,
    required String? responseBody,
  }) {
    if (statusCode == 401) return true;
    if (statusCode != 403) return false;

    final body = (responseBody ?? '').trim();
    // Some deployments return a bare 403 with an empty body for invalid/expired
    // tokens. Treat this as an auth failure so the session re-auth flow can
    // repair the token.
    if (body.isEmpty) return true;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final msg = (decoded['error'] ?? decoded['message'] ?? decoded['detail'] ?? '').toString();
        if (msg.trim().isEmpty) return false;
        return _looksLikeTokenErrorMessage(msg) || msg.toLowerCase().trim() == 'forbidden';
      }
      if (decoded is String) {
        final normalized = decoded.toLowerCase().trim();
        return _looksLikeTokenErrorMessage(decoded) || normalized == 'forbidden';
      }
    } catch (_) {
      final normalized = body.toLowerCase().trim();
      return _looksLikeTokenErrorMessage(body) || normalized == 'forbidden';
    }

    return false;
  }

  Future<http.Response> _request(
    String method,
    Uri uri, {
    bool includeAuth = true,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool isIdempotent = false,
    Duration timeout = AppConfig.requestTimeout,
    bool retriedAfterReauth = false,
  }) async {
    if (includeAuth && _authCoordinator != null && _authCoordinator!.isResolving) {
      final settled = await _authCoordinator!.waitForResolution();
      if (settled != null && !settled.isSuccess) {
        throw BackendApiRequestException(
          statusCode: 401,
          path: uri.path,
          body: settled.message,
        );
      }
    }

    final resolvedHeaders = _applyAuthHeader(
      Map<String, String>.from(headers ?? _getHeaders(includeAuth: includeAuth)),
      includeAuth: includeAuth,
    );

    // Minimal, scoped HTTP tracing for debugging auth/403 issues on web.
    // Guarded by AppConfig.enableNetworkLogging and only logs marker endpoints
    // to avoid noisy console output.
    final shouldTrace = AppConfig.enableNetworkLogging &&
        kDebugMode &&
        (uri.path.startsWith('/api/art-markers') || uri.path.contains('/api/art-markers/'));
    if (shouldTrace) {
      final hasAuthHeader = resolvedHeaders.containsKey('Authorization');
      final authWallet = _authWalletCanonical ?? _tryExtractWalletFromToken(_authToken) ?? '';
      final preferredWallet = _preferredWalletCanonical ?? '';
      AppConfig.networkLog(method.toUpperCase(), uri.toString(), data: {
        'authHeader': hasAuthHeader,
        'includeAuth': includeAuth,
        'webCredentialsExpected': _webCredentialsExpected,
        'tokenWallet': authWallet,
        'preferredWallet': preferredWallet,
      });
    }

    final http.Response response;
    switch (method.toUpperCase()) {
      case 'GET':
        response = await _client.get(uri, headers: resolvedHeaders).timeout(timeout);
        break;
      case 'POST':
        response = await _client.post(uri, headers: resolvedHeaders, body: body, encoding: encoding).timeout(timeout);
        break;
      case 'PUT':
        response = await _client.put(uri, headers: resolvedHeaders, body: body, encoding: encoding).timeout(timeout);
        break;
      case 'PATCH':
        response = await _client.patch(uri, headers: resolvedHeaders, body: body, encoding: encoding).timeout(timeout);
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: resolvedHeaders, body: body, encoding: encoding).timeout(timeout);
        break;
      default:
        throw ArgumentError('Unsupported method: $method');
    }

    if (shouldTrace) {
      final snippet = response.body.length <= 240 ? response.body : response.body.substring(0, 240);
      AppConfig.networkLog('RESP', uri.toString(), data: {
        'status': response.statusCode,
        'bodySnippet': snippet,
      });
    }

    final coordinator = _authCoordinator;
    final isAuthFailure = includeAuth &&
        coordinator != null &&
        AppConfig.isFeatureEnabled('rePromptLoginOnExpiry') &&
        _isAuthFailureStatus(statusCode: response.statusCode, responseBody: response.body);

    if (!isAuthFailure) return response;

    if (retriedAfterReauth) {
      return response;
    }

    final result = await coordinator.handleAuthFailure(
      AuthFailureContext(
        statusCode: response.statusCode,
        method: method.toUpperCase(),
        path: uri.path,
        body: response.body,
      ),
    );

    // Treat 401/403 as safe-to-retry once: servers must not perform side effects
    // when rejecting a request for auth reasons.
    final canRetry = true;
    if (result.isSuccess && canRetry) {
      if ((_authToken ?? '').isEmpty) {
        await loadAuthToken();
      }
      return _request(
        method,
        uri,
        includeAuth: includeAuth,
        headers: headers,
        body: body,
        encoding: encoding,
        isIdempotent: isIdempotent,
        timeout: timeout,
        retriedAfterReauth: true,
      );
    }

    return response;
  }

  Future<http.Response> _get(
    Uri uri, {
    bool includeAuth = true,
    Map<String, String>? headers,
    Duration timeout = AppConfig.requestTimeout,
  }) {
    return _request(
      'GET',
      uri,
      includeAuth: includeAuth,
      headers: headers,
      isIdempotent: true,
      timeout: timeout,
    );
  }

  Future<http.Response> _post(
    Uri uri, {
    bool includeAuth = true,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool isIdempotent = false,
    Duration timeout = AppConfig.requestTimeout,
  }) {
    return _request(
      'POST',
      uri,
      includeAuth: includeAuth,
      headers: headers,
      body: body,
      encoding: encoding,
      isIdempotent: isIdempotent,
      timeout: timeout,
    );
  }

  Future<http.Response> _put(
    Uri uri, {
    bool includeAuth = true,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool isIdempotent = false,
    Duration timeout = AppConfig.requestTimeout,
  }) {
    return _request(
      'PUT',
      uri,
      includeAuth: includeAuth,
      headers: headers,
      body: body,
      encoding: encoding,
      isIdempotent: isIdempotent,
      timeout: timeout,
    );
  }

  Future<http.Response> _patch(
    Uri uri, {
    bool includeAuth = true,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool isIdempotent = false,
    Duration timeout = AppConfig.requestTimeout,
  }) {
    return _request(
      'PATCH',
      uri,
      includeAuth: includeAuth,
      headers: headers,
      body: body,
      encoding: encoding,
      isIdempotent: isIdempotent,
      timeout: timeout,
    );
  }

  Future<http.Response> _delete(
    Uri uri, {
    bool includeAuth = true,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool isIdempotent = false,
    Duration timeout = AppConfig.requestTimeout,
  }) {
    return _request(
      'DELETE',
      uri,
      includeAuth: includeAuth,
      headers: headers,
      body: body,
      encoding: encoding,
      isIdempotent: isIdempotent,
      timeout: timeout,
    );
  }

  Future<http.Response> _sendMultipart(
    http.MultipartRequest Function() requestFactory, {
    bool includeAuth = true,
    Duration timeout = AppConfig.requestTimeout,
    bool retriedAfterReauth = false,
  }) async {
    if (includeAuth && _authCoordinator != null && _authCoordinator!.isResolving) {
      final settled = await _authCoordinator!.waitForResolution();
      if (settled != null && !settled.isSuccess) {
        final request = requestFactory();
        throw BackendApiRequestException(
          statusCode: 401,
          path: request.url.path,
          body: settled.message,
        );
      }
    }

    final request = requestFactory();
    final baseHeaders = <String, String>{
      'Accept': 'application/json',
      ...request.headers,
    };
    request.headers
      ..clear()
      ..addAll(_applyAuthHeader(baseHeaders, includeAuth: includeAuth));

    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);

    final coordinator = _authCoordinator;
    final isAuthFailure = includeAuth &&
        coordinator != null &&
        AppConfig.isFeatureEnabled('rePromptLoginOnExpiry') &&
        _isAuthFailureStatus(statusCode: response.statusCode, responseBody: response.body);

    if (!isAuthFailure) return response;
    if (retriedAfterReauth) return response;

    final result = await coordinator.handleAuthFailure(
      AuthFailureContext(
        statusCode: response.statusCode,
        method: request.method,
        path: request.url.path,
        body: response.body,
      ),
    );

    if (!result.isSuccess) return response;
    if ((_authToken ?? '').isEmpty) {
      await loadAuthToken();
    }

    return _sendMultipart(
      requestFactory,
      includeAuth: includeAuth,
      timeout: timeout,
      retriedAfterReauth: true,
    );
  }

  Future<void> _persistTokenFromResponse(Map<String, dynamic> body) async {
    final token = body['data'] != null && body['data']['token'] != null
        ? body['data']['token'] as String
        : body['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await setAuthToken(token);
      try {
        await _secureStorage.write(key: 'jwt_token', value: token);
      } catch (_) {}
    }
  }

  bool _isSuccessStatus(int statusCode) => statusCode >= 200 && statusCode < 300;

  Uri _withOrbitSource(Uri uri) {
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['source'] = 'orbit';
    return uri.replace(queryParameters: qp);
  }

  Future<Map<String, dynamic>> _fetchJson(
    Uri uri, {
    bool includeAuth = true,
    bool allowOrbitFallback = false,
  }) async {
    final key = _rateLimitKey('GET', uri);
    if (_isRateLimited(key)) {
      final message = _rateLimitMessage(key);
      _debugLogThrottled(
        'rate_limit_skip:$key',
        'BackendApiService: skipping $key because of active rate limit',
        throttle: const Duration(seconds: 20),
      );
      throw Exception(message);
    }

    final headers = _getHeaders(includeAuth: includeAuth);
    http.Response? primaryResponse;
    try {
      primaryResponse = await _request(
        'GET',
        uri,
        includeAuth: includeAuth,
        headers: headers,
        isIdempotent: true,
      );
      if (_isSuccessStatus(primaryResponse.statusCode)) {
        if (_isExhibitionsPath(uri)) {
          _exhibitionsApiAvailable = true;
        }
        return jsonDecode(primaryResponse.body) as Map<String, dynamic>;
      }
      if (primaryResponse.statusCode == 429) {
        _markRateLimited(key, primaryResponse, defaultWindowMs: 900000);
        throw Exception(_rateLimitMessage(key));
      }

      if (_isExhibitionsRootPath(uri) &&
          (primaryResponse.statusCode == 404 ||
              primaryResponse.statusCode == 405 ||
              primaryResponse.statusCode == 501)) {
        _exhibitionsApiAvailable = false;
      }

      _debugLogThrottled(
        'fetch_json_status:${uri.path}:${primaryResponse.statusCode}',
        'BackendApiService: ${uri.path} failed with status ${primaryResponse.statusCode}',
      );
      if (!allowOrbitFallback) {
        throw Exception('Request failed: ${primaryResponse.statusCode}');
      }
    } catch (e) {
      if (primaryResponse?.statusCode == 429) {
        rethrow; // Do not attempt Orbit fallback when rate limited.
      }
      if (!allowOrbitFallback) {
        _debugLogThrottled(
          'fetch_json_error:${uri.path}',
          'BackendApiService: request error for ${uri.path}: $e',
        );
        rethrow;
      }
      _debugLogThrottled(
        'fetch_json_fallback_error:${uri.path}',
        'BackendApiService: primary request error for ${uri.path}, trying Orbit fallback -> $e',
      );
    }

    if (!allowOrbitFallback) {
      throw Exception('Request failed for ${uri.toString()}');
    }

    final fallbackUri = _withOrbitSource(uri);
    final fallbackResponse = await _request(
      'GET',
      fallbackUri,
      includeAuth: includeAuth,
      headers: headers,
      isIdempotent: true,
    );
    if (_isSuccessStatus(fallbackResponse.statusCode)) {
      final data = jsonDecode(fallbackResponse.body) as Map<String, dynamic>;
      data['source'] = data['source'] ?? 'orbitdb';
      return data;
    }
    if (fallbackResponse.statusCode == 429) {
      _markRateLimited(key, fallbackResponse, defaultWindowMs: 900000);
      throw Exception(_rateLimitMessage(key));
    }
    _debugLogThrottled(
      'fetch_json_orbit_failed:${fallbackUri.path}:${fallbackResponse.statusCode}',
      'BackendApiService: Orbit fallback failed ${fallbackResponse.statusCode} for ${fallbackUri.path}',
    );
    throw Exception('Orbit fallback failed: ${fallbackResponse.statusCode}');
  }

  /// Normalize search suggestion payloads from various backend shapes into a
  /// stable list of maps with keys: `label`, `subtitle`, `id`, `type`, `lat`, `lng`.
  ///
  /// Accepts raw JSON that may be a List, a Map with `data`/`results` keys,
  /// or a single item map. The normalization is defensive to support multiple
  /// backend response shapes used across endpoints.
  List<Map<String, dynamic>> normalizeSearchSuggestions(dynamic raw) {
    return normalizeSearchSuggestionsPayload(raw);
  }

  // ==================== User/Profile Endpoints ====================

  /// Create a new user profile with wallet
  /// POST /api/profiles (uses saveProfile)
  Future<Map<String, dynamic>> createProfile({
    required String walletAddress,
    required String publicKey,
    String? username,
    String? email,
  }) async {
    // Use saveProfile which calls /api/profiles and doesn't require email/password
    return await saveProfile({
      'walletAddress': walletAddress,
      if (username != null) 'username': username,
      'displayName': username ?? 'User ${walletAddress.substring(0, 8)}',
      'bio': '',
      'isArtist': false,
    });
  }

  /// Register a wallet-based user via auth endpoint
  /// POST /api/auth/register { walletAddress, username? }
  /// On success stores returned JWT token for subsequent authenticated calls.
  @override
  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  }) async {
    try {
      // Keep preferred wallet in sync with successful auth issuance.
      setPreferredWalletAddress(walletAddress);
      final body = {
        'walletAddress': walletAddress,
        if (username != null) 'username': username,
      };
      final response = await _post(
        Uri.parse('$baseUrl/api/auth/register'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _persistTokenFromResponse(data);
        return data;
      } else {
        throw Exception('Register failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.registerWallet failed: $e');
      rethrow;
    }
  }

  /// Login with wallet signature
  /// POST /api/auth/login
  Future<Map<String, dynamic>> loginWithWallet({
    required String walletAddress,
    required String signature,
    required String message,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/auth/login'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({
          'walletAddress': walletAddress,
          'signature': signature,
          'message': message,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _persistTokenFromResponse(data);
        return data;
      } else {
        throw Exception('Login failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.loginWithWallet failed: $e');
      rethrow;
    }
  }

  /// Register with email + password
  /// POST /api/auth/register/email
  Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String password,
    String? username,
    String? walletAddress,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/register/email');
      final key = _rateLimitKey('POST', uri);
      if (_isRateLimited(key)) {
        throw Exception(_rateLimitMessage(key));
      }
      final body = {
        'email': email,
        'password': password,
        if (username != null && username.isNotEmpty) 'username': username,
        if (walletAddress != null && walletAddress.isNotEmpty) 'walletAddress': walletAddress,
      };
      final response = await _post(
        uri,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _persistTokenFromResponse(data);
        return data;
      }
      if (response.statusCode == 429) {
        _markRateLimited(key, response, defaultWindowMs: 900000);
        throw Exception(_rateLimitMessage(key));
      }
      if (response.statusCode == 404) {
        throw Exception('Email registration endpoint not available on the backend (received 404). Ensure the server is updated and ENABLE_EMAIL_AUTH=true.');
      }
      throw BackendApiRequestException(statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.registerWithEmail failed: $e');
      rethrow;
    }
  }

  /// Login with email + password
  /// POST /api/auth/login/email
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/login/email');
      final key = _rateLimitKey('POST', uri);
      if (_isRateLimited(key)) {
        throw Exception(_rateLimitMessage(key));
      }
      final response = await _post(
        uri,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        await _persistTokenFromResponse(data);
        return data;
      }
      if (response.statusCode == 429) {
        _markRateLimited(key, response, defaultWindowMs: 900000);
        throw Exception(_rateLimitMessage(key));
      }
      throw BackendApiRequestException(statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.loginWithEmail failed: $e');
      rethrow;
    }
  }

  /// Resend email verification link
  /// POST /api/auth/resend-verification { email }
  Future<Map<String, dynamic>> resendEmailVerification({required String email}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/resend-verification');
      final key = _rateLimitKey('POST', uri);
      if (_isRateLimited(key)) {
        throw Exception(_rateLimitMessage(key));
      }
      final response = await _post(
        uri,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 429) {
        _markRateLimited(key, response, defaultWindowMs: 900000);
        throw Exception(_rateLimitMessage(key));
      }
      throw BackendApiRequestException(statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.resendEmailVerification failed: $e');
      rethrow;
    }
  }

  /// Verify email
  /// POST /api/auth/verify-email { token }
  Future<Map<String, dynamic>> verifyEmail({required String token}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/verify-email');
      final key = _rateLimitKey('POST', uri);
      if (_isRateLimited(key)) {
        throw Exception(_rateLimitMessage(key));
      }
      final response = await _post(
        uri,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'token': token}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 429) {
        _markRateLimited(key, response, defaultWindowMs: 900000);
        throw Exception(_rateLimitMessage(key));
      }
      throw BackendApiRequestException(statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.verifyEmail failed: $e');
      rethrow;
    }
  }

  /// Request password reset (always returns 200 when enabled)
  /// POST /api/auth/forgot-password { email }
  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/forgot-password');
      final key = _rateLimitKey('POST', uri);
      if (_isRateLimited(key)) {
        throw Exception(_rateLimitMessage(key));
      }
      final response = await _post(
        uri,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'email': email}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 429) {
        _markRateLimited(key, response, defaultWindowMs: 900000);
        throw Exception(_rateLimitMessage(key));
      }
      throw BackendApiRequestException(statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.forgotPassword failed: $e');
      rethrow;
    }
  }

  /// Reset password with token (single-use)
  /// POST /api/auth/reset-password { token, newPassword }
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/reset-password');
      final key = _rateLimitKey('POST', uri);
      if (_isRateLimited(key)) {
        throw Exception(_rateLimitMessage(key));
      }
      final response = await _post(
        uri,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'token': token, 'newPassword': newPassword}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 429) {
        _markRateLimited(key, response, defaultWindowMs: 900000);
        throw Exception(_rateLimitMessage(key));
      }
      throw BackendApiRequestException(statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.resetPassword failed: $e');
      rethrow;
    }
  }

  /// Login with Google idToken (verified server-side)
  /// POST /api/auth/login/google
  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    String? email,
    String? username,
    String? walletAddress,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/login/google');
      final key = _rateLimitKey('POST', uri);
      if (_isRateLimited(key)) {
        throw Exception(_rateLimitMessage(key));
      }
      final body = {
        'idToken': idToken,
        if (email != null && email.isNotEmpty) 'email': email,
        if (username != null && username.isNotEmpty) 'username': username,
        if (walletAddress != null && walletAddress.isNotEmpty) 'walletAddress': walletAddress,
      };
      final response = await _post(
        uri,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _persistTokenFromResponse(data);
        return data;
      }
      if (response.statusCode == 429) {
        _markRateLimited(key, response, defaultWindowMs: 900000);
        // Persist retry window so the app can skip hitting the endpoint until cooldown ends.
        try {
          final prefs = await SharedPreferences.getInstance();
          final resetAt = _rateLimitResets[key];
          if (resetAt != null) {
            await prefs.setInt('rate_limit_auth_google_until', resetAt.millisecondsSinceEpoch);
          }
        } catch (_) {}
        throw Exception(_rateLimitMessage(key));
      }
      if (response.statusCode == 404) {
        throw Exception('Google login endpoint not available on the backend (received 404). Ensure the server is updated and ENABLE_GOOGLE_AUTH=true with GOOGLE_CLIENT_ID configured.');
      }
      throw Exception('Google login failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.loginWithGoogle failed: $e');
      rethrow;
    }
  }

  /// Get user profile by ID
  /// GET /api/users/:userId
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get profile: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getUserProfile failed: $e');
      rethrow;
    }
  }

  /// Get authenticated user's email preferences
  /// GET /api/users/me/preferences
  Future<Map<String, dynamic>> getMyEmailPreferences() async {
    try {
      final uri = Uri.parse('$baseUrl/api/users/me/preferences');
      final response = await _get(uri, headers: _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) {
        throw Exception('Email preferences endpoint not available on the backend (received 404). Ensure the server is updated.');
      }
      throw BackendApiRequestException(statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getMyEmailPreferences failed: $e');
      rethrow;
    }
  }

  /// Update authenticated user's email preferences
  /// PATCH /api/users/me/preferences
  Future<Map<String, dynamic>> updateMyEmailPreferences(Map<String, dynamic> preferences) async {
    try {
      final uri = Uri.parse('$baseUrl/api/users/me/preferences');
      final response = await _patch(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(preferences),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) {
        throw Exception('Email preferences endpoint not available on the backend (received 404). Ensure the server is updated.');
      }
      throw BackendApiRequestException(statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.updateMyEmailPreferences failed: $e');
      rethrow;
    }
  }

  // ==================== Chat / Messaging Helpers (wrappers used by providers) ====================

  /// Return current in-memory auth token (may be null)
  @override
  String? getAuthToken() => _authToken;

  /// Get current authenticated profile
  /// GET /api/profiles/me
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/profiles/me'),
        headers: _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getMyProfile failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Issue a short-lived backend token for a wallet (used for socket auth)
  /// POST /api/profiles/issue-token { walletAddress }
  Future<bool> issueTokenForWallet(String walletAddress) async {
    try {
      final resp = await _post(
        Uri.parse('$baseUrl/api/profiles/issue-token'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'walletAddress': walletAddress}),
      );
      AppConfig.debugPrint('BackendApiService.issueTokenForWallet: status=${resp.statusCode}');
      AppConfig.debugPrint('BackendApiService.issueTokenForWallet: bodyLen=${resp.body.length}');
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = body['token'] as String? ?? body['data']?['token'] as String?;
        AppConfig.debugPrint('BackendApiService.issueTokenForWallet: tokenPresent=${token != null && token.isNotEmpty}');
        if (token != null && token.isNotEmpty) {
          await setAuthToken(token);
          try {
            await _secureStorage.write(key: 'jwt_token', value: token);
          } catch (e) {
            AppConfig.debugPrint('BackendApiService.issueTokenForWallet: failed to persist token: $e');
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.issueTokenForWallet failed: $e');
      return false;
    }
  }

  /// Fetch list of conversations (lightweight)
  /// GET /api/messages
  Future<Map<String, dynamic>> fetchConversations() async {
    try {
      // Ensure we attempt to load persisted token before every protected call
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      AppConfig.debugPrint('BackendApiService.fetchConversations: authToken present=${_authToken != null && _authToken!.isNotEmpty}');
      final response = await _get(Uri.parse('$baseUrl/api/messages'), headers: _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.fetchConversations failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch messages for a conversation
  /// GET /api/messages/:conversationId/messages
  Future<Map<String, dynamic>> fetchMessages(String conversationId, {int page = 1, int limit = 50}) async {
    try {
      // Ensure we attempt to load persisted token before every protected call (and attempt issuance for stored wallet if missing)
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      AppConfig.debugPrint('BackendApiService.fetchMessages: conversationId=$conversationId authToken present=${_authToken != null && _authToken!.isNotEmpty}');
      final uri = Uri.parse('$baseUrl/api/messages/$conversationId/messages').replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });
      final response = await _get(uri, headers: _getHeaders());
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.fetchMessages failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Send a message to a conversation (JSON)
  /// POST /api/messages/:conversationId/messages { message, data, replyToId }
  Future<Map<String, dynamic>> sendMessage(String conversationId, String message, {Map<String, dynamic>? data, String? replyToId}) async {
    try {
      final body = <String, dynamic>{'message': message};
      if (data != null) body['data'] = data;
      if (replyToId != null && replyToId.isNotEmpty) {
        body['replyToId'] = replyToId;
      }
      final response = await _post(
        Uri.parse('$baseUrl/api/messages/$conversationId/messages'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'status': response.statusCode, 'body': response.body};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.sendMessage failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch conversation members
  /// GET /api/messages/:conversationId/members
  Future<Map<String, dynamic>> fetchConversationMembers(String conversationId) async {
    try {
      // Ensure persisted token is loaded and token issuance attempted once (use stored wallet fallback)
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _get(Uri.parse('$baseUrl/api/messages/$conversationId/members'), headers: _getHeaders());
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 429) {
        AppConfig.debugPrint('BackendApiService.fetchConversationMembers: 429 Too Many Requests for $conversationId');
        return {'success': false, 'status': 429, 'retryAfter': response.headers['retry-after']};
      }
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.fetchConversationMembers failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload a message attachment by posting multipart to the messages endpoint
  Future<Map<String, dynamic>> uploadMessageAttachment(String conversationId, List<int> bytes, String filename, String contentType) async {
    try {
      final uri = Uri.parse('$baseUrl/api/messages/$conversationId/messages');
      final placeholder = filename.isNotEmpty ? 'Attachment • $filename' : 'Shared an attachment';
      http.MultipartRequest buildRequest() {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll({'Accept': 'application/json'});
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
            contentType: MediaType.parse(contentType),
          ),
        );
        request.fields['message'] = placeholder;
        request.fields['content'] = placeholder;
        return request;
      }

      final resp = await _sendMultipart(buildRequest, includeAuth: true);
      if (resp.statusCode == 200 || resp.statusCode == 201) return jsonDecode(resp.body) as Map<String, dynamic>;
      return {'success': false, 'status': resp.statusCode, 'body': resp.body};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.uploadMessageAttachment failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create a conversation
  /// POST /api/messages { title, members }
  Future<Map<String, dynamic>> createConversation({String? title, bool isGroup = false, List<String>? members}) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/messages'),
        headers: _getHeaders(),
        body: jsonEncode({'title': title, 'members': members ?? [], 'isGroup': isGroup}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createConversation failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload conversation avatar (attempt common endpoints)
  Future<Map<String, dynamic>> uploadConversationAvatar(String conversationId, List<int> bytes, String filename, String contentType) async {
    try {
      // Try conversation-specific avatar endpoint first
      var uri = Uri.parse('$baseUrl/api/conversations/$conversationId/avatar');
      http.MultipartRequest buildPrimary() {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll({'Accept': 'application/json'});
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
            contentType: MediaType.parse(contentType),
          ),
        );
        return request;
      }

      var resp = await _sendMultipart(buildPrimary, includeAuth: true);
      if (resp.statusCode == 200 || resp.statusCode == 201) return jsonDecode(resp.body) as Map<String, dynamic>;

      // Fallback to messages-based endpoint
      uri = Uri.parse('$baseUrl/api/messages/$conversationId/avatar');
      http.MultipartRequest buildFallback() {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll({'Accept': 'application/json'});
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
            contentType: MediaType.parse(contentType),
          ),
        );
        return request;
      }

      resp = await _sendMultipart(buildFallback, includeAuth: true);
      if (resp.statusCode == 200 || resp.statusCode == 201) return jsonDecode(resp.body) as Map<String, dynamic>;

      return {'success': false, 'status': resp.statusCode, 'body': resp.body};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.uploadConversationAvatar failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Add a member to conversation
  Future<Map<String, dynamic>> addConversationMember(String conversationId, String walletAddress) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/messages/$conversationId/members'),
        headers: _getHeaders(),
        body: jsonEncode({'walletAddress': walletAddress}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.addConversationMember failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Remove a member from conversation (best-effort)
  Future<Map<String, dynamic>> removeConversationMember(String conversationId, String walletOrUsername) async {
    try {
      // Try a DELETE endpoint first (may not exist on server)
      final uri = Uri.parse('$baseUrl/api/messages/$conversationId/members');
      final response = await _delete(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({'walletAddress': walletOrUsername, 'username': walletOrUsername}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) return {'success': true};

      // Fallback: call a removal helper endpoint (non-standard)
      final fallback = await _post(
        Uri.parse('$baseUrl/api/messages/$conversationId/members/remove'),
        headers: _getHeaders(),
        body: jsonEncode({'walletAddress': walletOrUsername}),
      );
      if (fallback.statusCode == 200 || fallback.statusCode == 201) return jsonDecode(fallback.body) as Map<String, dynamic>;

      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.removeConversationMember failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Transfer conversation ownership (best-effort)
  Future<Map<String, dynamic>> transferConversationOwner(String conversationId, String newOwnerWallet) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/messages/$conversationId/transfer-owner'),
        headers: _getHeaders(),
        body: jsonEncode({'newOwnerWallet': newOwnerWallet}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.transferConversationOwner failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark conversation as read
  Future<Map<String, dynamic>> markConversationRead(String conversationId) async {
    try {
      final response = await _put(Uri.parse('$baseUrl/api/messages/$conversationId/read'), headers: _getHeaders());
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.markConversationRead failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark a specific message as read
  Future<Map<String, dynamic>> markMessageRead(String conversationId, String messageId) async {
    try {
      final response = await _put(Uri.parse('$baseUrl/api/messages/$conversationId/messages/$messageId/read'), headers: _getHeaders());
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.markMessageRead failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> renameConversation(String conversationId, String newTitle) async {
    try {
      final response = await _patch(
        Uri.parse('$baseUrl/api/messages/$conversationId/rename'),
        headers: _getHeaders(),
        body: jsonEncode({'title': newTitle}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to rename conversation: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to rename conversation: $e');
    }
  }

  /// Update user profile (preferences / metadata)
  /// POST /api/profiles
  @override
  Future<Map<String, dynamic>> updateProfile(
    String walletAddress,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final payload = {
        'walletAddress': walletAddress,
        ...updates,
      };
      final response = await _post(
        Uri.parse('$baseUrl/api/profiles'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.updateProfile failed: $e');
      rethrow;
    }
  }

  // ==================== Profile/Artists API (New) ====================

  /// Get profile by wallet address
  /// GET /api/profiles/:walletAddress
  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) async {
    try {
      // Public read: do NOT attempt to auto-issue/auth-switch for the wallet
      // being viewed.
      // Avoid making pointless network calls when wallet is a known placeholder
      final normalized = WalletUtils.normalize(walletAddress);
      if (normalized.isEmpty || ['unknown', 'anonymous', 'n/a', 'none'].contains(normalized.toLowerCase())) {
        throw Exception('Profile not found');
      }
      final uri = Uri.parse('$baseUrl/api/profiles/$walletAddress');
      final dynamic data = await _fetchJson(uri, includeAuth: false, allowOrbitFallback: true);
      final raw = data['data'] ?? data;
      if (raw is Map<String, dynamic>) {
        AppConfig.debugPrint('BackendApiService.getProfileByWallet: parsed profile keys: ${raw.keys.toList()}');
        return raw;
      }
      throw Exception('Invalid profile payload');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getProfileByWallet failed: $e');
      rethrow;
    }
  }

  /// Fetch multiple profiles in a single batch call
  /// POST /api/profiles/batch { wallets: [wallet1,wallet2] }
  Future<Map<String, dynamic>> getProfilesBatch(List<String> wallets) async {
    try {
      if (wallets.isEmpty) return {'success': true, 'data': <dynamic>[]};
      await _ensureAuthBeforeRequest();
      final response = await _post(
        Uri.parse('$baseUrl/api/profiles/batch'),
        headers: _getHeaders(),
        body: jsonEncode({'wallets': wallets}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'status': response.statusCode, 'body': response.body};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getProfilesBatch failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch multiple presence records in a single batch call
  /// POST /api/presence/batch { wallets: [wallet1,wallet2] }
  Future<Map<String, dynamic>> getPresenceBatch(List<String> wallets) async {
    try {
      if (wallets.isEmpty) return {'success': true, 'data': <dynamic>[]};
      final response = await _post(
        Uri.parse('$baseUrl/api/presence/batch'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'wallets': wallets}),
        timeout: const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'status': response.statusCode, 'body': response.body};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getPresenceBatch failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Record a last-visited subject (best-effort; server enforces privacy and may return 204).
  /// POST /api/presence/visit { type, id }
  Future<Map<String, dynamic>> recordPresenceVisit({
    required String type,
    required String id,
    String? walletAddress,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final response = await _post(
        Uri.parse('$baseUrl/api/presence/visit'),
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode({'type': type, 'id': id}),
        timeout: const Duration(seconds: 8),
      );

      if (response.statusCode == 204) {
        return {'success': true, 'stored': false};
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'stored': true,
          'data': data['data'] ?? data,
        };
      }
      return {'success': false, 'status': response.statusCode, 'body': response.body};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.recordPresenceVisit failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Keep the authenticated user's presence lastSeen timestamp fresh.
  /// POST /api/presence/ping
  Future<Map<String, dynamic>> pingPresence({String? walletAddress}) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final response = await _post(
        Uri.parse('$baseUrl/api/presence/ping'),
        headers: _getHeaders(includeAuth: true),
        timeout: const Duration(seconds: 8),
      );

      if (response.statusCode == 204) {
        return {'success': true};
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'status': response.statusCode, 'body': response.body};
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.pingPresence failed: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Find a profile by username (helper built on top of the search endpoint)
  Future<Map<String, dynamic>?> findProfileByUsername(String username) async {
    final sanitized = username.trim().replaceFirst(RegExp(r'^@+'), '');
    if (sanitized.isEmpty) return null;
    try {
      final response = await search(query: sanitized, type: 'profiles', limit: 10, page: 1);
      if (response['success'] != true) return null;
      final normalizedTarget = sanitized.toLowerCase();
      final resultsPayload = response['results'];
      List<dynamic> profiles = const [];
      if (resultsPayload is Map<String, dynamic>) {
        profiles = (resultsPayload['profiles'] as List<dynamic>? ?? const []);
      } else if (response['profiles'] is List) {
        profiles = response['profiles'] as List<dynamic>;
      }
      if (profiles.isEmpty && response['data'] is List) {
        profiles = response['data'] as List<dynamic>;
      }
      for (final entry in profiles) {
        if (entry is! Map<String, dynamic>) continue;
        final rawUsername = (entry['username'] ?? entry['walletAddress'] ?? entry['wallet_address'] ?? entry['wallet'])?.toString() ?? '';
        if (rawUsername.isEmpty) continue;
        final normalized = rawUsername.replaceFirst(RegExp(r'^@+'), '').toLowerCase();
        if (normalized == normalizedTarget) {
          return entry;
        }
      }
      // No exact match found; fallback to first profile result if available
      if (profiles.isNotEmpty && profiles.first is Map<String, dynamic>) {
        return profiles.first as Map<String, dynamic>;
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.findProfileByUsername failed: $e');
    }
    return null;
  }

  /// Create or update profile
  /// POST /api/profiles
  @override
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> profileData) async {
    // Backend requires authentication (verifyToken). Make sure we have a token
    // available before attempting to save.
    final walletAddress = (profileData['walletAddress'] ?? profileData['wallet_address'])?.toString();
    await _ensureAuthBeforeRequest(walletAddress: walletAddress);

    const int maxRetries = 3;
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        if (kDebugMode) {
          debugPrint('BackendApiService.saveProfile: POST /api/profiles payload: ${jsonEncode(profileData)}');
        }
        final uri = Uri.parse('$baseUrl/api/profiles');
        final response = await _post(
          uri,
          headers: _getHeaders(includeAuth: true),
          body: jsonEncode(profileData),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          // Some legacy backends used to return a token. Keep support.
          if (data['token'] is String && (data['token'] as String).isNotEmpty) {
            await setAuthToken(data['token'] as String);
            if (kDebugMode) {
              debugPrint('BackendApiService.saveProfile: token received and stored from profile creation');
            }
          }

          final payload = data['data'] ?? data;
          if (payload is Map<String, dynamic>) {
            return payload;
          }
          // Defensive: sometimes data can be wrapped differently.
          return Map<String, dynamic>.from(payload as dynamic);
        }

        if (response.statusCode == 429) {
          // Too many requests - check Retry-After header
          final retryAfter = response.headers['retry-after'];
          final waitSeconds = int.tryParse(retryAfter ?? '') ?? (2 << (attempt - 1));
          if (attempt < maxRetries) {
            AppConfig.debugPrint('BackendApiService.saveProfile: 429 retry in $waitSeconds seconds (attempt $attempt)');
            await Future.delayed(Duration(seconds: waitSeconds));
            continue;
          } else {
            throw Exception('Too many requests (429). Please wait and try again later.');
          }
        }

        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      } catch (e) {
        if (e is BackendApiRequestException && (e.statusCode == 401 || e.statusCode == 403)) {
          rethrow;
        }
        // If we've exhausted retries, rethrow
        if (attempt >= maxRetries) {
          AppConfig.debugPrint('BackendApiService.saveProfile failed (final): $e');
          rethrow;
        }

        // If this was a transient error, wait briefly and retry
        final backoff = 1 << (attempt - 1);
        AppConfig.debugPrint('BackendApiService.saveProfile transient error, retrying in $backoff seconds: $e');
        await Future.delayed(Duration(seconds: backoff));
      }
    }
  }

  /// List artists
  /// GET /api/profiles/artists/list
  Future<List<Map<String, dynamic>>> listArtists({
    bool? verified,
    bool? featured,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (verified != null) queryParams['verified'] = verified.toString();
      if (featured != null) queryParams['featured'] = featured.toString();

      final uri = Uri.parse('$baseUrl/api/profiles/artists/list').replace(queryParameters: queryParams);
      final response = await _get(uri, includeAuth: false, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] as List);
      } else {
        throw Exception('Failed to list artists: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.listArtists failed: $e');
      rethrow;
    }
  }

  /// Get artist artworks
  /// GET /api/profiles/:walletAddress/artworks
  Future<List<Map<String, dynamic>>> getArtistArtworks(
    String walletAddress, {
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/api/profiles/$walletAddress/artworks').replace(queryParameters: queryParams);
      final response = await _get(uri, includeAuth: false, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] as List);
      } else {
        throw Exception('Failed to get artist artworks: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getArtistArtworks failed: $e');
      rethrow;
    }
  }

  /// Get user stats
  /// GET /api/profiles/:walletAddress/stats
  Future<Map<String, dynamic>> getUserStats(String walletAddress) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/profiles/$walletAddress/stats'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get user stats: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getUserStats failed: $e');
      rethrow;
    }
  }

  /// Get canonical stats snapshot
  /// GET /api/stats/:entityType/:entityId
  Future<Map<String, dynamic>> getStatsSnapshot({
    required String entityType,
    required String entityId,
    List<String> metrics = const [],
    String scope = 'public',
    String? groupBy,
  }) async {
    try {
      // Snapshot is public, but include auth when available (private stats allowed for owners).
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      final queryParams = <String, String>{};
      if (metrics.isNotEmpty) queryParams['metrics'] = metrics.join(',');
      if (scope.trim().isNotEmpty) queryParams['scope'] = scope.trim();
      if (groupBy != null && groupBy.trim().isNotEmpty) queryParams['groupBy'] = groupBy.trim();

      final encodedId = Uri.encodeComponent(entityId);
      final uri = Uri.parse('$baseUrl/api/stats/$entityType/$encodedId')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await _get(
        uri,
        headers: _getHeaders(includeAuth: true),
        timeout: const Duration(seconds: 12),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'];
          if (data is Map<String, dynamic>) return data;
        }
        throw Exception('Unexpected stats snapshot payload');
      }

      throw Exception('Failed to get stats snapshot (${response.statusCode})');
    } catch (e) {
      if (kDebugMode) {
        AppConfig.debugPrint('BackendApiService.getStatsSnapshot failed: $e');
      }
      rethrow;
    }
  }

  /// Get canonical stats series (graph-ready)
  /// GET /api/stats/:entityType/:entityId/series
  Future<Map<String, dynamic>> getStatsSeries({
    required String entityType,
    required String entityId,
    required String metric,
    String bucket = 'day',
    String timeframe = '30d',
    String? from,
    String? to,
    String? groupBy,
    String scope = 'public',
  }) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      final queryParams = <String, String>{
        'metric': metric,
        'bucket': bucket,
      };
      if (timeframe.trim().isNotEmpty) queryParams['timeframe'] = timeframe.trim();
      if (from != null && from.trim().isNotEmpty) queryParams['from'] = from.trim();
      if (to != null && to.trim().isNotEmpty) queryParams['to'] = to.trim();
      if (groupBy != null && groupBy.trim().isNotEmpty) queryParams['groupBy'] = groupBy.trim();
      if (scope.trim().isNotEmpty) queryParams['scope'] = scope.trim();

      final encodedId = Uri.encodeComponent(entityId);
      final uri = Uri.parse('$baseUrl/api/stats/$entityType/$encodedId/series')
          .replace(queryParameters: queryParams);
      final response = await _get(
        uri,
        headers: _getHeaders(includeAuth: true),
        timeout: const Duration(seconds: 20),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'];
          if (data is Map<String, dynamic>) return data;
        }
        throw Exception('Unexpected stats series payload');
      }

      throw Exception('Failed to get stats series (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getStatsSeries failed: $e');
      rethrow;
    }
  }

  // ==================== Mock Data API (New) ====================

  /// Get mock artworks (development/testing)
  /// GET /api/mock/artworks
  Future<List<Map<String, dynamic>>> getMockArtworks() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/mock/artworks'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] as List);
      } else if (response.statusCode == 403) {
        throw Exception('Mock data disabled on server');
      } else {
        throw Exception('Failed to get mock artworks: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getMockArtworks failed: $e');
      rethrow;
    }
  }

  /// Get mock community posts (development/testing)
  /// GET /api/mock/community-posts
  Future<List<Map<String, dynamic>>> getMockCommunityPosts() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/mock/community-posts'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] as List);
      } else if (response.statusCode == 403) {
        throw Exception('Mock data disabled on server');
      } else {
        throw Exception('Failed to get mock posts: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getMockCommunityPosts failed: $e');
      rethrow;
    }
  }

  // ==================== AR Marker Endpoints ====================

  /// Get nearby art markers (geospatial query)
  /// GET /api/art-markers?lat=&lng=&radius=
  Future<List<ArtMarker>> getNearbyArtMarkers({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int? limit,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final qp = <String, String>{
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radiusKm.toString(),
        if (limit != null) 'limit': limit.toString(),
      };
      final uri = Uri.parse('$baseUrl/api/art-markers').replace(queryParameters: qp);

      final dynamic data = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: true);
      final List<dynamic> markerList;
      if (data is List) {
        markerList = data;
      } else if (data is Map<String, dynamic>) {
        final dynamic maybeList = data['data'] ?? data['markers'] ?? data['artMarkers'];
        markerList = maybeList is List ? maybeList : const [];
      } else {
        markerList = const [];
      }
      return markerList
          .map((json) => _artMarkerFromBackendJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getNearbyArtMarkers failed: $e');
      rethrow;
    }
  }

  /// Get art markers that are inside a viewport/bounds.
  ///
  /// Used by map travel mode so we fetch what's visible (instead of a massive radius).
  /// GET /api/art-markers?lat=&lng=&minLat=&maxLat=&minLng=&maxLng=&limit=
  Future<List<ArtMarker>> getArtMarkersInBounds({
    required double latitude,
    required double longitude,
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int? limit,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final qp = <String, String>{
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'minLat': minLat.toString(),
        'maxLat': maxLat.toString(),
        'minLng': minLng.toString(),
        'maxLng': maxLng.toString(),
        if (limit != null) 'limit': limit.toString(),
      };
      final uri = Uri.parse('$baseUrl/api/art-markers').replace(queryParameters: qp);

      final dynamic data = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: true);
      final List<dynamic> markerList;
      if (data is List) {
        markerList = data;
      } else if (data is Map<String, dynamic>) {
        final dynamic maybeList = data['data'] ?? data['markers'] ?? data['artMarkers'];
        markerList = maybeList is List ? maybeList : const [];
      } else {
        markerList = const [];
      }

      return markerList
          .map((json) => _artMarkerFromBackendJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getArtMarkersInBounds failed: $e');
      rethrow;
    }
  }

  /// Get single art marker by ID
  /// GET /api/art-markers/:id
  Future<ArtMarker?> getArtMarker(String markerId) async {
    final id = markerId.trim();
    if (id.isEmpty) return null;

    try {
      // Markers can be public (optional auth). Include auth when available,
      // but do not hard-fail if the user is not signed in yet.
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      final uri = Uri.parse('$baseUrl/api/art-markers/$id');
      final dynamic data = await _fetchJson(
        uri,
        includeAuth: true,
        allowOrbitFallback: true,
      );

      final dynamic payload = data is Map<String, dynamic>
          ? (data['data'] ?? data['marker'] ?? data['artMarker'] ?? data)
          : data;

      if (payload is Map<String, dynamic>) {
        return _artMarkerFromBackendJson(payload);
      }

      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getArtMarker failed: $e');
      return null;
    }
  }

  /// Get markers owned by the authenticated user (includes drafts/private)
  /// GET /api/art-markers/mine
  @override
  Future<List<ArtMarker>> getMyArtMarkers() async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/art-markers/mine');
      final response = await _get(
        uri,
        headers: _getHeaders(),
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        final dynamic payload = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded['markers'] ?? decoded) : decoded;
        final List<dynamic> markerList = payload is List ? payload : const <dynamic>[];
        return markerList
            .whereType<Map<String, dynamic>>()
            .map(_artMarkerFromBackendJson)
            .toList(growable: false);
      }

      throw Exception('Failed to load markers: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendeApiService.getMyArtMarkers failed: $e');
      rethrow;
    }
  }

  /// Create a marker record (server assigns ownership).
  /// POST /api/art-markers
  @override
  Future<ArtMarker?> createArtMarkerRecord(Map<String, dynamic> payload) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/art-markers');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(payload),
        timeout: const Duration(seconds: 15),
      );

      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final marker = decoded['data'] ?? decoded['marker'] ?? decoded['artMarker'] ?? decoded;
          if (marker is Map<String, dynamic>) {
            return _artMarkerFromBackendJson(marker);
          }
        }
        return null;
      }

      throw Exception('Failed to create marker: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createArtMarkerRecord failed: $e');
      rethrow;
    }
  }

  /// Update a marker record.
  /// PUT /api/art-markers/:id
  @override
  Future<ArtMarker?> updateArtMarkerRecord(String markerId, Map<String, dynamic> updates) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/art-markers/$markerId');
      final response = await _put(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(updates),
        timeout: const Duration(seconds: 15),
      );

      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final marker = decoded['data'] ?? decoded['marker'] ?? decoded['artMarker'] ?? decoded;
          if (marker is Map<String, dynamic>) {
            return _artMarkerFromBackendJson(marker);
          }
        }
        return null;
      }

      throw Exception('Failed to update marker: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.updateArtMarkerRecord failed: $e');
      rethrow;
    }
  }

  /// Delete a marker record.
  /// DELETE /api/art-markers/:id
  @override
  Future<bool> deleteArtMarkerRecord(String markerId) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/art-markers/$markerId');
      final response = await _delete(
        uri,
        headers: _getHeaders(),
        timeout: const Duration(seconds: 15),
      );
      // Treat deletes as idempotent: if the marker is already gone (404/410),
      // we still want to evict it locally to avoid UI "resurrection".
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      if (response.statusCode == 404 || response.statusCode == 410) return true;

      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteArtMarkerRecord failed: $e');
      rethrow;
    }
  }

  /// Create a new art marker
  /// POST /api/art-markers
  Future<ArtMarker> createArtMarker({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required String modelCID,
    String? modelURL,
    String? artworkId,
    String storageProvider = 'ipfs',
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/art-markers'),
        headers: _getHeaders(),
        body: jsonEncode({
          'title': title,
          'description': description,
          'latitude': latitude,
          'longitude': longitude,
          'modelCID': modelCID,
          if (modelURL != null) 'modelURL': modelURL,
          if (artworkId != null) 'artworkId': artworkId,
          'storageProvider': storageProvider,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = (data['data'] ?? data['marker'] ?? data['artMarker']) as Map<String, dynamic>;
        return _artMarkerFromBackendJson(payload);
      } else {
        throw Exception('Failed to create marker: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createArtMarker failed: $e');
      rethrow;
    }
  }

  /// Increment marker views
  /// POST /api/art-markers/:id/view
  Future<void> incrementMarkerViews(String markerId) async {
    try {
      await _post(
        Uri.parse('$baseUrl/api/art-markers/$markerId/view'),
        headers: _getHeaders(),
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.incrementMarkerViews failed: $e');
    }
  }

  /// Increment marker interactions
  /// POST /api/art-markers/:id/interact
  Future<void> incrementMarkerInteractions(String markerId) async {
    try {
      await _post(
        Uri.parse('$baseUrl/api/art-markers/$markerId/interact'),
        headers: _getHeaders(),
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.incrementMarkerInteractions failed: $e');
    }
  }

  // ==================== Artwork Endpoints ====================

  /// Get artworks with filters
  /// GET /api/artworks
  @override
  Future<List<Artwork>> getArtworks({
    String? category,
    bool? arEnabled,
    int page = 1,
    int limit = 20,
    String? walletAddress,
    bool includePrivateForWallet = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (arEnabled != null) queryParams['arEnabled'] = arEnabled.toString();
      final hasWalletFilter = walletAddress != null && walletAddress.isNotEmpty;
      if (hasWalletFilter) {
        queryParams['wallet'] = walletAddress;
        if (includePrivateForWallet) {
          queryParams['publicOnly'] = 'false';
        }
      }

      final uri = Uri.parse('$baseUrl/api/artworks').replace(queryParameters: queryParams);
      final data = await _fetchJson(
        uri,
        includeAuth: includePrivateForWallet && hasWalletFilter,
        allowOrbitFallback: true,
      );
      final dynamic listCandidate = data['artworks'] ?? data['data'] ?? data['items'];
      final List<dynamic> artworks = listCandidate is List ? listCandidate : <dynamic>[];
      return artworks.map((json) => _artworkFromBackendJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getArtworks failed: $e');
      rethrow;
    }
  }

  /// Get single artwork by ID
  /// GET /api/artworks/:id
  @override
  Future<Artwork> getArtwork(String artworkId) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/artworks/$artworkId');
      final data = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: true);
      final payload = data['artwork'] ?? data['data'] ?? data;
      if (payload is Map<String, dynamic>) {
        return _artworkFromBackendJson(payload);
      }
      throw Exception('Invalid artwork payload');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getArtwork failed: $e');
      rethrow;
    }
  }

  /// Update an artwork
  /// PUT /api/artworks/:id
  @override
  Future<Artwork?> updateArtwork(String artworkId, Map<String, dynamic> updates) async {
    try {
      await _ensureAuthWithStoredWallet();
      final uri = Uri.parse('$baseUrl/api/artworks/$artworkId');
      final response = await _put(uri, headers: _getHeaders(), body: jsonEncode(updates));
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded['artwork'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            return _artworkFromBackendJson(payload);
          }
        }
        return null;
      }
      throw Exception('Failed to update artwork: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.updateArtwork failed: $e');
      rethrow;
    }
  }

  /// Publish an artwork
  /// POST /api/artworks/:id/publish
  @override
  Future<Artwork?> publishArtwork(String artworkId) async {
    try {
      await _ensureAuthWithStoredWallet();
      final uri = Uri.parse('$baseUrl/api/artworks/$artworkId/publish');
      final response = await _post(uri, headers: _getHeaders());
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded['artwork'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            return _artworkFromBackendJson(payload);
          }
        }
        return null;
      }
      throw Exception('Failed to publish artwork: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.publishArtwork failed: $e');
      rethrow;
    }
  }

  /// Unpublish an artwork
  /// POST /api/artworks/:id/unpublish
  @override
  Future<Artwork?> unpublishArtwork(String artworkId) async {
    try {
      await _ensureAuthWithStoredWallet();
      final uri = Uri.parse('$baseUrl/api/artworks/$artworkId/unpublish');
      final response = await _post(uri, headers: _getHeaders());
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded['artwork'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            return _artworkFromBackendJson(payload);
          }
        }
        return null;
      }
      throw Exception('Failed to unpublish artwork: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unpublishArtwork failed: $e');
      rethrow;
    }
  }

  /// Soft-delete (deactivate) an artwork
  /// DELETE /api/artworks/:id
  Future<bool> deleteArtwork(String artworkId) async {
    try {
      await _ensureAuthWithStoredWallet();
      final uri = Uri.parse('$baseUrl/api/artworks/$artworkId');
      final response = await _delete(uri, headers: _getHeaders());
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) return true;
      throw Exception('Failed to delete artwork: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteArtwork failed: $e');
      rethrow;
    }
  }

  /// Create a new artwork record (cover/model should be uploaded separately)
  /// POST /api/artworks
  Future<Artwork?> createArtworkRecord({
    required String title,
    required String description,
    required String imageUrl,
    required String walletAddress,
    String? artistName,
    String category = 'General',
    List<String> tags = const [],
    bool isPublic = true,
    bool enableAR = false,
    String? modelUrl,
    String? modelCid,
    double arScale = 1,
    bool mintAsNFT = false,
    double? price,
    double? royaltyPercent,
    Map<String, dynamic>? metadata,
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);

      final body = {
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'walletAddress': walletAddress,
        if (artistName != null && artistName.isNotEmpty) 'artistName': artistName,
        'category': category,
        'tags': tags,
        'isPublic': isPublic,
        'isAREnabled': enableAR,
        if (modelUrl != null) 'model3DURL': modelUrl,
        if (modelCid != null) 'model3DCID': modelCid,
        'arScale': arScale,
        'isNFT': mintAsNFT,
        if (royaltyPercent != null) 'royaltyPercent': royaltyPercent,
        if (price != null) 'price': price,
        'currency': 'KUB8',
        if (locationName != null && locationName.isNotEmpty) 'locationName': locationName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (metadata != null) 'metadata': metadata,
      };

      final response = await _post(
        Uri.parse('$baseUrl/api/artworks'),
        headers: _getHeaders(),
        body: jsonEncode(body),
        isIdempotent: true,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.body.isEmpty) {
          return null;
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = data['data'] ?? data['artwork'] ?? data;
        if (payload is Map<String, dynamic>) {
          return _artworkFromBackendJson(payload);
        }
        return null;
      } else {
        throw Exception('Failed to create artwork: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createArtworkRecord failed: $e');
      return null;
    }
  }

  /// Record artwork discovery
  /// POST /api/artworks/:id/discover
  Future<void> discoverArtwork(String artworkId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      await _post(
        Uri.parse('$baseUrl/api/artworks/$artworkId/discover'),
        headers: _getHeaders(),
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.discoverArtwork failed: $e');
    }
  }

  /// Like an artwork
  /// POST /api/artworks/:id/like
  @override
  Future<int?> likeArtwork(String artworkId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/artworks/$artworkId/like'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          final data = payload['data'] as Map<String, dynamic>? ?? payload;
          return data['likesCount'] as int?;
        }
        return null;
      }
      throw Exception('Failed to like artwork (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.likeArtwork failed: $e');
      rethrow;
    }
  }

  /// Unlike an artwork
  /// DELETE /api/artworks/:id/like
  @override
  Future<int?> unlikeArtwork(String artworkId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _delete(
        Uri.parse('$baseUrl/api/artworks/$artworkId/like'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          final data = payload['data'] as Map<String, dynamic>? ?? payload;
          return data['likesCount'] as int?;
        }
        return null;
      }
      throw Exception('Failed to unlike artwork (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unlikeArtwork failed: $e');
      rethrow;
    }
  }

  /// Record a view for an artwork
  /// POST /api/artworks/:id/view
  @override
  Future<int?> recordArtworkView(String artworkId) async {
    try {
      // Views are allowed anonymously, but include auth when available
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/artworks/$artworkId/view'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          final data = payload['data'] as Map<String, dynamic>? ?? payload;
          return data['viewsCount'] as int?;
        }
        return null;
      }
      throw Exception('Failed to record artwork view (${response.statusCode})');
    } catch (e) {
      // View counting should be non-fatal for the UI.
      AppConfig.debugPrint('BackendApiService.recordArtworkView failed: $e');
      return null;
    }
  }

  /// Record a view for an event
  /// POST /api/events/:id/view
  Future<void> recordEventView(String eventId, {String? source}) async {
    try {
      // Views are allowed anonymously, but include auth when available.
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      final uri = Uri.parse('$baseUrl/api/events/$eventId/view').replace(
        queryParameters: (source != null && source.trim().isNotEmpty)
            ? <String, String>{'source': source.trim()}
            : null,
      );

      final response = await _post(uri, headers: _getHeaders(includeAuth: true));
      if (response.statusCode == 200) return;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.recordEventView failed: $e');
    }
  }

  /// Record a view for an exhibition
  /// POST /api/exhibitions/:id/view
  Future<void> recordExhibitionView(String exhibitionId, {String? source}) async {
    try {
      // Views are allowed anonymously, but include auth when available.
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/view').replace(
        queryParameters: (source != null && source.trim().isNotEmpty)
            ? <String, String>{'source': source.trim()}
            : null,
      );

      final response = await _post(uri, headers: _getHeaders(includeAuth: true));
      if (response.statusCode == 200) return;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.recordExhibitionView failed: $e');
    }
  }

  /// Get comments for an artwork
  /// GET /api/artworks/:id/comments
  @override
  Future<List<ArtworkComment>> getArtworkComments({
    required String artworkId,
    int page = 1,
    int limit = 50,
  }) async {
    // Public, but include auth if available so backend can return isLikedByCurrentUser.
    try { await _ensureAuthWithStoredWallet(); } catch (_) {}
    final uri = Uri.parse('$baseUrl/api/artworks/$artworkId/comments').replace(queryParameters: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    final response = await _get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final raw = payload['data'] as List<dynamic>? ?? <dynamic>[];
        return raw.whereType<Map<String, dynamic>>().map(ArtworkComment.fromMap).toList();
      }
      return <ArtworkComment>[];
    }

    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  }

  /// Create a comment for an artwork
  /// POST /api/artworks/:id/comments
  @override
  Future<ArtworkComment> createArtworkComment({
    required String artworkId,
    required String content,
    String? parentCommentId,
  }) async {
    await _ensureAuthBeforeRequest();
    final uri = Uri.parse('$baseUrl/api/artworks/$artworkId/comments');
    final response = await _post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode({
        'content': content,
        if (parentCommentId != null && parentCommentId.trim().isNotEmpty)
          'parentCommentId': parentCommentId.trim(),
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final data = payload['data'] as Map<String, dynamic>? ?? payload;
        return ArtworkComment.fromMap(data);
      }
      throw Exception('Unexpected createArtworkComment payload: ${response.body}');
    }

    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  }

  /// Edit an artwork comment
  /// PATCH /api/artworks/comments/:commentId
  @override
  Future<ArtworkComment> editArtworkComment({
    required String commentId,
    required String content,
  }) async {
    try { await _ensureAuthWithStoredWallet(); } catch (_) {}
    final uri = Uri.parse('$baseUrl/api/artworks/comments/$commentId');
    final response = await _patch(
      uri,
      headers: _getHeaders(),
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final data = payload['data'] as Map<String, dynamic>? ?? payload;
        return ArtworkComment.fromMap(data);
      }
      throw Exception('Unexpected editArtworkComment payload: ${response.body}');
    }

    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  }

  /// Delete an artwork comment
  /// DELETE /api/artworks/comments/:commentId
  /// Returns updated commentsCount when provided by backend.
  @override
  Future<int?> deleteArtworkComment(String commentId) async {
    try { await _ensureAuthWithStoredWallet(); } catch (_) {}
    final uri = Uri.parse('$baseUrl/api/artworks/comments/$commentId');
    final response = await _delete(uri, headers: _getHeaders());
    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        return payload['commentsCount'] as int?;
      }
      return null;
    }
    throw BackendApiRequestException(
      statusCode: response.statusCode,
      path: uri.path,
      body: response.body,
    );
  }

  /// Discover an artwork and return updated discovery count if available.
  /// POST /api/artworks/:id/discover
  @override
  Future<int?> discoverArtworkWithCount(String artworkId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/artworks/$artworkId/discover'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          final data = payload['data'] as Map<String, dynamic>? ?? payload;
          return data['discoveryCount'] as int?;
        }
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.discoverArtworkWithCount failed: $e');
      return null;
    }
  }

  // ==================== Community Endpoints ====================

  /// Get community posts
  /// GET /api/community/posts
  Future<List<CommunityPost>> getCommunityPosts({
    int page = 1,
    int limit = 20,
    bool? arOnly,
    String? authorWallet,
    bool? followingOnly,
    String? tag,
    String? sort,
  }) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (arOnly != null) queryParams['arOnly'] = arOnly.toString();
      if (authorWallet != null) queryParams['authorWallet'] = authorWallet;
      if (followingOnly != null) queryParams['followingOnly'] = followingOnly.toString();
      if (tag != null && tag.trim().isNotEmpty) {
        final normalizedTag = tag.replaceFirst(RegExp(r'^#+'), '').trim();
        if (normalizedTag.isNotEmpty) {
          queryParams['tag'] = normalizedTag;
        }
      }
      if (sort != null && sort.trim().isNotEmpty) {
        final normalizedSort = sort.trim().toLowerCase();
        if (normalizedSort == 'popularity' || normalizedSort == 'popular' || normalizedSort == 'recent') {
          queryParams['sort'] = normalizedSort == 'popular' ? 'popularity' : normalizedSort;
        }
      }

      final uri = Uri.parse('$baseUrl/api/community/posts').replace(queryParameters: queryParams);
      final allowFallback = followingOnly != true;
      final data = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: allowFallback);
      final posts = data['data'] as List<dynamic>? ?? <dynamic>[];
      return posts.map((json) => _communityPostFromBackendJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      _debugLogThrottled(
        'get_community_posts:error',
        'BackendApiService: getCommunityPosts failed: $e',
      );
      rethrow;
    }
  }

  /// Get trending community tags (real tag counts from community_posts.tags)
  /// GET /api/community/tags/trending
  Future<List<Map<String, dynamic>>> getTrendingCommunityTags({
    int limit = 12,
    int timeframeDays = 30,
    bool preferOrbit = false,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'timeframe': timeframeDays.toString(),
      };
      if (preferOrbit) {
        queryParams['source'] = 'orbit';
      }

      final uri = Uri.parse('$baseUrl/api/community/tags/trending')
          .replace(queryParameters: queryParams);
      final data = await _fetchJson(uri, includeAuth: false, allowOrbitFallback: false);
      final list = (data['data'] ?? data['tags'] ?? data['results']) as List<dynamic>?;
      if (list == null) return const [];
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      _debugLogThrottled(
        'get_trending_community_tags:error',
        'BackendApiService: getTrendingCommunityTags failed: $e',
      );
      return const [];
    }
  }

  /// Get a single community post by id
  /// GET /api/community/posts/:id
  Future<CommunityPost> getCommunityPostById(String postId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/community/posts/$postId');
      final data = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: true);
      final payload = data['data'] ?? data;
      if (payload is Map<String, dynamic>) {
        return _communityPostFromBackendJson(payload);
      }
      throw Exception('Unexpected post payload');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getCommunityPostById failed: $e');
      rethrow;
    }
  }

  /// Create a community post
  /// POST /api/community/posts
  Future<CommunityPost> createCommunityPost({
    required String content,
    String? imageUrl,
    List<String>? mediaUrls,
    List<String>? mediaCids,
    String? artworkId,
    String? subjectType,
    String? subjectId,
    String? postType,
    String category = 'post',
    List<String>? tags,
    List<String>? mentions,
    CommunityLocation? location,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) async {
    try {
      final aggregatedMedia = <String>[];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        aggregatedMedia.add(imageUrl);
      }
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        aggregatedMedia.addAll(mediaUrls.where((url) => url.trim().isNotEmpty));
      }

      final requestBody = _buildCommunityPostPayload(
        content: content,
        category: category,
        mediaUrls: aggregatedMedia.isEmpty ? null : aggregatedMedia,
        mediaCids: mediaCids,
        artworkId: artworkId,
        subjectType: subjectType,
        subjectId: subjectId,
        postType: postType,
        tags: tags,
        mentions: mentions,
        location: location,
        locationName: locationName,
        locationLat: locationLat,
        locationLng: locationLng,
      );
      
      final response = await _post(
        Uri.parse('$baseUrl/api/community/posts'),
        headers: _getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final createdPost = _communityPostFromBackendJson(data['data'] as Map<String, dynamic>);
        try {
          await UserActionLogger.logPostCreated(
            postId: createdPost.id,
            content: createdPost.content,
            mediaUrls: aggregatedMedia.isNotEmpty
                ? aggregatedMedia
                : (createdPost.imageUrl != null ? <String>[createdPost.imageUrl!] : null),
          );
        } catch (e) {
          AppConfig.debugPrint('UserActionLogger.logPostCreated failed: $e');
        }
        return createdPost;
      } else {
        throw Exception('Failed to create post: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createCommunityPost failed: $e');
      rethrow;
    }
  }

  /// Update a community post
  /// PUT /api/community/posts/:id
  Future<void> updateCommunityPost({
    required String postId,
    required String content,
    required List<String> mediaUrls,
    List<String>? mediaCids,
    String? subjectType,
    String? subjectId,
    String? artworkId,
    bool includeSubject = false,
  }) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      final shouldIncludeSubject =
          includeSubject || subjectType != null || subjectId != null || artworkId != null;

      final response = await _put(
        Uri.parse('$baseUrl/api/community/posts/$postId'),
        headers: _getHeaders(),
        body: jsonEncode({
          'content': content,
          'mediaUrls': mediaUrls,
          if (mediaCids != null) 'mediaCids': mediaCids,
          if (shouldIncludeSubject) 'subjectType': subjectType?.trim(),
          if (shouldIncludeSubject) 'subjectId': subjectId?.trim(),
          if (shouldIncludeSubject) 'artworkId': artworkId?.trim(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update post: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (_) {
      rethrow;
    }
  }

  /// Delete a community post
  /// DELETE /api/community/posts/:id
  Future<void> deleteCommunityPost(String postId) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      final response = await _delete(
        Uri.parse('$baseUrl/api/community/posts/$postId'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to delete post: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (_) {
      rethrow;
    }
  }

  /// Like a post
  /// POST /api/community/posts/:id/like
  Future<int?> likePost(String postId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/community/posts/$postId/like'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data['likesCount'] as int? : null;
      }
      throw Exception('Failed to like post (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.likePost failed: $e');
      rethrow;
    }
  }

  /// Share a post (increment share counter)
  /// POST /api/community/posts/:id/share
  Future<void> sharePost(String postId) async {
    try {
      await _post(
        Uri.parse('$baseUrl/api/community/posts/$postId/share'),
        headers: _getHeaders(),
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.sharePost failed: $e');
    }
  }

  /// Create a repost with optional comment
  /// POST /api/community/posts/repost
  Future<CommunityPost> createRepost({
    required String originalPostId,
    String? content,
  }) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/community/posts/repost'),
        headers: _getHeaders(),
        body: jsonEncode({
          'originalPostId': originalPostId,
          if (content != null && content.isNotEmpty) 'content': content,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _communityPostFromBackendJson(data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to create repost: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createRepost failed: $e');
      rethrow;
    }
  }

  /// Load art-centric feed filtered by geolocation
  Future<List<CommunityPost>> getCommunityArtFeed({
    required double latitude,
    required double longitude,
    double radiusKm = 3,
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final params = <String, String>{
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radiusKm': radiusKm.toStringAsFixed(2),
        'limit': limit.toString(),
        'page': page.toString(),
      };
      final uri = Uri.parse('$baseUrl/api/community/art-feed').replace(queryParameters: params);
      final data = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final posts = data['data'] as List<dynamic>? ?? <dynamic>[];
      return posts
          .map((json) => _communityPostFromBackendJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final status = _tryParseRequestFailedStatus(e);
      // Older deployments may not implement /api/community/art-feed yet.
      // Treat as "feature unavailable" instead of a hard error.
      if (status == 404 || status == 501 || status == 503) {
        if (kDebugMode) {
          debugPrint('BackendApiService: art feed unavailable (HTTP $status)');
        }
        return <CommunityPost>[];
      }
      _debugLogThrottled(
        'get_community_art_feed:error',
        'BackendApiService: getCommunityArtFeed failed: $e',
      );
      rethrow;
    }
  }

  /// List community groups with pagination/search
  Future<List<CommunityGroupSummary>> listCommunityGroups({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      };
      final uri = Uri.parse('$baseUrl/api/groups').replace(queryParameters: queryParams);
      final jsonData = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final dynamic payload = jsonData['data'] ?? jsonData['groups'] ?? jsonData['results'];
      final List<dynamic> rows;
      if (payload is List) {
        rows = payload;
      } else if (payload is Map<String, dynamic> && payload['data'] is List) {
        rows = payload['data'] as List<dynamic>;
      } else {
        rows = <dynamic>[];
      }
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_communityGroupSummaryFromJson)
          .toList();
    } catch (e) {
      final status = _tryParseRequestFailedStatus(e);
      // Older deployments may not implement /api/groups yet, or the DB schema may be missing.
      // Treat as "feature unavailable" instead of surfacing as a hard error.
      if (status == 404 || status == 501 || status == 503) {
        if (kDebugMode) {
          debugPrint('BackendApiService: community groups unavailable (HTTP $status)');
        }
        return <CommunityGroupSummary>[];
      }
      AppConfig.debugPrint('BackendApiService.listCommunityGroups failed: $e');
      rethrow;
    }
  }

  /// Create a community group
  Future<CommunityGroupSummary?> createCommunityGroup({
    required String name,
    String? description,
    bool isPublic = true,
    String? coverImage,
  }) async {
    try {
      final body = {
        'name': name,
        if (description != null) 'description': description,
        'isPublic': isPublic,
        if (coverImage != null && coverImage.isNotEmpty) 'coverImage': coverImage,
      };
      final response = await _post(
        Uri.parse('$baseUrl/api/groups'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final payload = decoded['data'] ?? decoded['group'] ?? decoded;
        if (payload is Map<String, dynamic>) {
          return _communityGroupSummaryFromJson(payload);
        }
        return null;
      }
      throw Exception('Failed to create group: ${response.statusCode}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createCommunityGroup failed: $e');
      rethrow;
    }
  }

  /// Join a community group
  Future<CommunityGroupSummary?> joinCommunityGroup(String groupId) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/groups/$groupId/join'),
        headers: _getHeaders(),
        isIdempotent: true,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final payload = decoded['data'];
        if (payload is Map<String, dynamic>) {
          return _communityGroupSummaryFromJson(payload);
        }
        return null;
      }
      throw Exception('Failed to join group: ${response.statusCode}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.joinCommunityGroup failed: $e');
      rethrow;
    }
  }

  /// Leave a community group
  Future<CommunityGroupSummary?> leaveCommunityGroup(String groupId) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/groups/$groupId/leave'),
        headers: _getHeaders(),
        isIdempotent: true,
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final payload = decoded['data'];
        if (payload is Map<String, dynamic>) {
          return _communityGroupSummaryFromJson(payload);
        }
        return null;
      }
      throw Exception('Failed to leave group: ${response.statusCode}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.leaveCommunityGroup failed: $e');
      rethrow;
    }
  }

  /// Fetch posts for a specific group
  Future<List<CommunityPost>> getGroupPosts(
    String groupId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      // Public-ish, but include auth when available for personalized fields (likes, follows).
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final qp = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      final uri = Uri.parse('$baseUrl/api/groups/$groupId/posts').replace(queryParameters: qp);
      final data = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final posts = data['data'] as List<dynamic>? ?? <dynamic>[];
      return posts
          .map((json) => _communityPostFromBackendJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getGroupPosts failed: $e');
      rethrow;
    }
  }

  /// Create a post inside a group
  Future<CommunityPost> createGroupPost(
    String groupId, {
    required String content,
    String? imageUrl,
    List<String>? mediaUrls,
    List<String>? mediaCids,
    String? artworkId,
    String? subjectType,
    String? subjectId,
    String? postType,
    String category = 'post',
    List<String>? tags,
    List<String>? mentions,
    CommunityLocation? location,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final aggregatedMedia = <String>[];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        aggregatedMedia.add(imageUrl);
      }
      if (mediaUrls != null && mediaUrls.isNotEmpty) {
        aggregatedMedia.addAll(mediaUrls.where((url) => url.trim().isNotEmpty));
      }

      final body = _buildCommunityPostPayload(
        content: content,
        category: category,
        mediaUrls: aggregatedMedia.isEmpty ? null : aggregatedMedia,
        mediaCids: mediaCids,
        artworkId: artworkId,
        subjectType: subjectType,
        subjectId: subjectId,
        postType: postType,
        tags: tags,
        mentions: mentions,
        location: location,
        locationName: locationName,
        locationLat: locationLat,
        locationLng: locationLng,
      );

      final response = await _post(
        Uri.parse('$baseUrl/api/groups/$groupId/posts'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final payload = decoded['data'] ?? decoded['post'] ?? decoded;
        if (payload is Map<String, dynamic>) {
          final created = _communityPostFromBackendJson(payload);
          try {
            await UserActionLogger.logPostCreated(
              postId: created.id,
              content: created.content,
              mediaUrls: aggregatedMedia.isNotEmpty
                  ? aggregatedMedia
                  : (created.imageUrl != null ? <String>[created.imageUrl!] : null),
            );
          } catch (e) {
            AppConfig.debugPrint('BackendApiService.createGroupPost: UserActionLogger failed: $e');
          }
          return created;
        }
        throw Exception('Unexpected group post payload');
      }
      throw Exception('Failed to create group post: ${response.statusCode} - ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createGroupPost failed: $e');
      rethrow;
    }
  }

  /// Resolve community post subject previews in a batch.
  /// POST /api/community/subjects/resolve
  Future<List<Map<String, dynamic>>> resolveCommunitySubjects({
    required List<Map<String, String>> subjects,
  }) async {
    if (subjects.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/community/subjects/resolve'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'subjects': subjects}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['data'] ?? data['subjects'] ?? []) as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      }
      throw Exception('Failed to resolve subjects: ${response.statusCode}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.resolveCommunitySubjects failed: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  /// Share a post via direct message
  /// POST /api/community/messages/share
  Future<void> sharePostViaDM({
    required String postId,
    required String recipientWallet,
    String? message,
  }) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/community/messages/share'),
        headers: _getHeaders(),
        body: jsonEncode({
          'postId': postId,
          'recipientWallet': recipientWallet,
          if (message != null && message.isNotEmpty) 'message': message,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to share post via DM: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.sharePostViaDM failed: $e');
      rethrow;
    }
  }

  /// Share any entity via direct message.
  ///
  /// - Posts: uses the dedicated `postId` flow so chat UIs can render rich cards.
  /// - Other entities: sends a link + metadata (backend accepts `share` payload).
  Future<void> shareEntityViaDM({
    required String recipientWallet,
    required String message,
    required ShareTarget target,
    required String url,
  }) async {
    if (target.type == ShareEntityType.post) {
      await sharePostViaDM(
        postId: target.shareId,
        recipientWallet: recipientWallet,
        message: message,
      );
      return;
    }

    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/community/messages/share'),
        headers: _getHeaders(),
        body: jsonEncode({
          'recipientWallet': recipientWallet,
          if (message.isNotEmpty) 'message': message,
          'share': {
            'entityType': target.type.analyticsTargetType,
            'entityId': target.shareId,
            'url': url,
            if ((target.title ?? '').trim().isNotEmpty) 'title': target.title,
          },
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to share via DM: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.shareEntityViaDM failed: $e');
      rethrow;
    }
  }

  /// Get list of users who reposted a post
  /// GET /api/community/posts/:id/reposts
  Future<List<Map<String, dynamic>>> getPostReposts({
    required String postId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/community/posts/$postId/reposts?page=$page&limit=$limit'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reposts = (data['data'] as List?) ?? [];
        return reposts.map((r) => r as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to get reposts: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getPostReposts failed: $e');
      rethrow;
    }
  }

  /// Delete a repost (unrepost)
  /// DELETE /api/community/posts/:id/repost
  Future<void> deleteRepost(String repostId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _delete(
        Uri.parse('$baseUrl/api/community/posts/$repostId/repost'),
        headers: _getHeaders(),
        isIdempotent: true,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete repost: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteRepost failed: $e');
      rethrow;
    }
  }

  /// Track analytics event
  /// POST /api/community/analytics/event
  Future<void> trackAnalyticsEvent({
    required String eventType,
    String? postId,
    String? targetType,
    String? targetId,
    String? eventCategory,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/community/analytics/event'),
        headers: _getHeaders(),
        body: jsonEncode({
          'eventType': eventType,
          if (postId != null) 'postId': postId,
          if (targetType != null) 'targetType': targetType,
          if (targetId != null) 'targetId': targetId,
          if (eventCategory != null) 'eventCategory': eventCategory,
          if (metadata != null) 'metadata': metadata,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        AppConfig.debugPrint('BackendApiService.trackAnalyticsEvent failed (${response.statusCode})');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.trackAnalyticsEvent failed: $e');
      // Don't rethrow - analytics failures shouldn't break user experience
    }
  }

  /// Unlike a post
  /// DELETE /api/community/posts/:id/like
  Future<int?> unlikePost(String postId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _delete(
        Uri.parse('$baseUrl/api/community/posts/$postId/like'),
        headers: _getHeaders(),
        isIdempotent: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data['likesCount'] as int? : null;
      }
      throw Exception('Failed to unlike post (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unlikePost failed: $e');
      rethrow;
    }
  }

  /// Create a comment on a post
  /// POST /api/community/posts/:id/comments
  Future<Comment> createComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/community/posts/$postId/comments'),
        headers: _getHeaders(),
        body: jsonEncode({
          'content': content,
          if (parentCommentId != null) 'parentCommentId': parentCommentId,
        }),
      );

      if (response.statusCode == 201) {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          final commentJson = parsed['comment'] ?? parsed['data'] ?? parsed['result'] ?? parsed['payload'];
          if (commentJson is Map<String, dynamic>) {
            return _commentFromBackendJson(commentJson);
          }
          // Some endpoints may return the comment fields at root level
          if (parsed.containsKey('id') && parsed.containsKey('content')) {
            return _commentFromBackendJson(parsed);
          }
        }
        throw Exception('Unexpected response when creating comment: ${response.body}');
      } else {
        throw Exception('Failed to create comment: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('BackendApiService.createComment failed: $e');
      }
      rethrow;
    }
  }

  /// Edit a comment on a post
  /// PATCH /api/community/comments/:id
  Future<Comment> editComment({
    required String commentId,
    required String content,
  }) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/community/comments/$commentId');
      final response = await _patch(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          final commentJson = parsed['comment'] ?? parsed['data'] ?? parsed['result'] ?? parsed['payload'];
          if (commentJson is Map<String, dynamic>) {
            return _commentFromBackendJson(commentJson);
          }
          if (parsed.containsKey('id') && parsed.containsKey('content')) {
            return _commentFromBackendJson(parsed);
          }
        }
        throw Exception('Unexpected response when editing comment: ${response.body}');
      }

      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.editComment failed: $e');
      rethrow;
    }
  }

  /// Get comments for a post
  /// GET /api/community/posts/:id/comments
  Future<List<Comment>> getComments({
    required String postId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      // Ensure auth loaded once (safe for public endpoints)
      try { await ensureAuthLoaded(); } catch (_) {}
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/community/posts/$postId/comments')
          .replace(queryParameters: queryParams);
      final response = await _get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          final raw = parsed['comments'] ?? parsed['data'] ?? parsed['result'] ?? parsed['payload'] ?? [];
          if (raw is List) {
            final flat = raw
                .whereType<Map<String, dynamic>>()
                .map(_commentFromBackendJson)
                .toList();

            // Batch fetch profiles for comment authors to fill missing name/avatar if possible
            try {
              final Set<String> wallets = {};
              for (final c in flat) {
                final candidate = (c.authorWallet ?? c.authorId).trim();
                if (candidate.isEmpty) continue;
                final normalized = WalletUtils.canonical(candidate);
                if (normalized.isEmpty) continue;
                if (['unknown', 'anonymous', 'n/a', 'none'].contains(normalized)) continue;
                wallets.add(normalized);
              }

              if (wallets.isNotEmpty) {
                final profilesResp = await getProfilesBatch(wallets.toList());
                final Map<String, Map<String, dynamic>> profilesByWallet = {};
                if (profilesResp['success'] == true && profilesResp['data'] is List) {
                  final profilesList = profilesResp['data'] as List<dynamic>;
                  for (final p in profilesList.whereType<Map<String, dynamic>>()) {
                    final walletKey = WalletUtils.canonical((p['walletAddress'] ?? p['wallet'] ?? p['wallet_address'] ?? p['publicKey'] ?? p['public_key'])?.toString() ?? '');
                    if (walletKey.isNotEmpty) profilesByWallet[walletKey] = p;
                  }
                }

                // For any remaining candidates not found by wallet batch, try GET /api/users/:userId
                final missing = wallets.where((w) => !profilesByWallet.containsKey(w)).toList();
                for (final candidate in missing) {
                  try {
                    final profileResp = await getUserProfile(candidate);
                    if (profileResp.isNotEmpty) {
                      final walletKey = WalletUtils.canonical((profileResp['walletAddress'] ?? profileResp['wallet'] ?? profileResp['wallet_address'] ?? profileResp['publicKey'] ?? profileResp['public_key'])?.toString() ?? '');
                      final key = walletKey.isNotEmpty ? walletKey : WalletUtils.canonical(candidate);
                      profilesByWallet[key] = profileResp;
                    }
                  } catch (e) {
                    // ignore 404s or failures for non-wallet ids
                  }
                }

                for (int i = 0; i < flat.length; i++) {
                  final c = flat[i];
                  final walletKey = WalletUtils.canonical(c.authorWallet ?? c.authorId);
                  if (walletKey.isEmpty) continue;
                  final profile = profilesByWallet[walletKey];
                  if (profile == null) continue;
                  try {
                    final profileDisplayName = profile['displayName'] as String? ?? profile['display_name'] as String?;
                    final profileUsername = profile['username'] as String? ?? profile['walletAddress'] as String? ?? profile['wallet'] as String?;
                    final avatarCandidate = profile['avatar'] as String? ?? profile['profileImage'] as String? ?? profile['profile_image'] as String? ?? profile['avatarUrl'] as String? ?? profile['avatar_url'] as String?;
                    final normalizedAvatar = MediaUrlResolver.resolve(avatarCandidate);
                    
                    // Determine best display name: prioritize displayName, then username, then fallback to existing
                    final bestDisplayName = (profileDisplayName != null && profileDisplayName.trim().isNotEmpty)
                        ? profileDisplayName.trim()
                        : ((profileUsername != null && profileUsername.trim().isNotEmpty) 
                            ? profileUsername.trim() 
                            : c.authorName);
                    
                    final updated = c.copyWith(
                      authorAvatar: normalizedAvatar,
                      authorUsername: profileUsername ?? c.authorUsername,
                      authorName: bestDisplayName,
                      authorId: (profile['walletAddress'] ?? profile['wallet'] ?? profile['id'] ?? profile['userId'] ?? c.authorId)?.toString(),
                      authorWallet: (profile['walletAddress'] ?? profile['wallet'] ?? profile['wallet_address'] ?? profile['publicKey'] ?? profile['public_key'])?.toString(),
                    );
                    flat[i] = updated;
                  } catch (e) {
                    // ignore per-item enrichment errors
                  }
                }
              }
            } catch (e) {
              // ignore enrichment failures
            }
            return _nestComments(flat);
          }
          return <Comment>[];
        }
        return <Comment>[];
      } else {
        return <Comment>[];
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getComments failed: $e');
      return <Comment>[];
    }
  }

  /// Delete a comment
  /// DELETE /api/community/comments/:id
  Future<void> deleteComment(String commentId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      await _delete(
        Uri.parse('$baseUrl/api/community/comments/$commentId'),
        headers: _getHeaders(),
        isIdempotent: true,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteComment failed: $e');
      rethrow;
    }
  }

  /// Like a comment
  /// POST /api/community/comments/:id/like
  @override
  Future<int?> likeComment(String commentId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _post(
        Uri.parse('$baseUrl/api/community/comments/$commentId/like'),
        headers: _getHeaders(),
        isIdempotent: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data['likesCount'] as int? : null;
      }
      throw Exception('Failed to like comment (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.likeComment failed: $e');
      rethrow;
    }
  }

  /// Unlike a comment
  /// DELETE /api/community/comments/:id/like
  @override
  Future<int?> unlikeComment(String commentId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await _delete(
        Uri.parse('$baseUrl/api/community/comments/$commentId/like'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data['likesCount'] as int? : null;
      }
      throw Exception('Failed to unlike comment (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unlikeComment failed: $e');
      rethrow;
    }
  }

  /// Get users who liked a post
  Future<List<CommunityLikeUser>> getPostLikes(String postId, {int limit = 50, int offset = 0}) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/community/posts/$postId/likes').replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await _get(uri, headers: _getHeaders());
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic> && payload['data'] is List) {
          final list = payload['data'] as List<dynamic>;
          return list
              .whereType<Map<String, dynamic>>()
              .map(_communityLikeUserFromBackendJson)
              .toList();
        }
        return <CommunityLikeUser>[];
      }
      throw Exception('Failed to fetch post likes (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getPostLikes failed: $e');
      rethrow;
    }
  }

  /// Get users who liked a comment
  Future<List<CommunityLikeUser>> getCommentLikes(String commentId, {int limit = 50, int offset = 0}) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/community/comments/$commentId/likes').replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await _get(uri, headers: _getHeaders());
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic> && payload['data'] is List) {
          final list = payload['data'] as List<dynamic>;
          return list
              .whereType<Map<String, dynamic>>()
              .map(_communityLikeUserFromBackendJson)
              .toList();
        }
        return <CommunityLikeUser>[];
      }
      throw Exception('Failed to fetch comment likes (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getCommentLikes failed: $e');
      rethrow;
    }
  }

  // ==================== Follow Endpoints ====================

  /// Follow a user
  /// POST /api/community/follow/:walletAddress
  @override
  Future<void> followUser(String walletAddress) async {
    final encoded = Uri.encodeComponent(walletAddress);
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/community/follow/$encoded');
      final response = await _post(uri, headers: _getHeaders(), isIdempotent: true);

      if (!_isSuccessStatus(response.statusCode)) {
        final body = response.body.isNotEmpty ? response.body : 'No response body';
        throw Exception('Failed to follow user (${response.statusCode}): $body');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.followUser failed: $e');
      rethrow;
    }
  }

  /// Unfollow a user
  /// DELETE /api/community/follow/:walletAddress
  @override
  Future<void> unfollowUser(String walletAddress) async {
    final encoded = Uri.encodeComponent(walletAddress);
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/community/follow/$encoded');
      final response = await _delete(uri, headers: _getHeaders(), isIdempotent: true);

      if (!_isSuccessStatus(response.statusCode)) {
        final body = response.body.isNotEmpty ? response.body : 'No response body';
        throw Exception('Failed to unfollow user (${response.statusCode}): $body');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unfollowUser failed: $e');
      rethrow;
    }
  }

  /// Get user's followers
  /// GET /api/community/followers/:walletAddress
  Future<List<Map<String, dynamic>>> getFollowers({
    required String walletAddress,
    int page = 1,
    int limit = 50,
  }) async {
    final int safeLimit = limit.clamp(1, 200).toInt();
    final int safePage = page.clamp(1, 1000000).toInt();
    final int offset = (safePage - 1) * safeLimit;
    final encoded = Uri.encodeComponent(walletAddress);

    try {
      final queryParams = <String, String>{
        'limit': safeLimit.toString(),
        'offset': offset.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/community/followers/$encoded')
          .replace(queryParameters: queryParams);
      final response = await _get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          final raw = payload['data'] ?? payload['followers'] ?? payload['result'] ?? payload['payload'] ?? [];
          if (raw is List) {
            return raw.whereType<Map<String, dynamic>>().toList();
          }
        }
        return <Map<String, dynamic>>[];
      } else {
        throw Exception('Failed to get followers: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getFollowers failed: $e');
      rethrow;
    }
  }

  /// Get users that a user is following
  /// GET /api/community/following/:walletAddress
  Future<List<Map<String, dynamic>>> getFollowing({
    required String walletAddress,
    int page = 1,
    int limit = 50,
  }) async {
    final int safeLimit = limit.clamp(1, 200).toInt();
    final int safePage = page.clamp(1, 1000000).toInt();
    final int offset = (safePage - 1) * safeLimit;
    final encoded = Uri.encodeComponent(walletAddress);

    try {
      final queryParams = <String, String>{
        'limit': safeLimit.toString(),
        'offset': offset.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/community/following/$encoded')
          .replace(queryParameters: queryParams);
      final response = await _get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          final raw = payload['data'] ?? payload['following'] ?? payload['result'] ?? payload['payload'] ?? [];
          if (raw is List) {
            return raw.whereType<Map<String, dynamic>>().toList();
          }
        }
        return <Map<String, dynamic>>[];
      } else {
        throw Exception('Failed to get following: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getFollowing failed: $e');
      rethrow;
    }
  }

  /// Check if current user is following a user
  /// GET /api/community/follow/:walletAddress/status
  @override
  Future<bool> isFollowing(String walletAddress) async {
    final encoded = Uri.encodeComponent(walletAddress);
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/community/follow/$encoded/status');
      final response = await _get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['isFollowing'] as bool? ?? false;
      }

      if (response.statusCode == 404) {
        throw Exception('User not found when checking follow status');
      }

      throw Exception('Failed to check follow status (${response.statusCode})');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.isFollowing failed: $e');
      rethrow;
    }
  }

  // ==================== Reports / Moderation ====================

  /// Submit a user-generated report.
  /// POST /api/reports
  Future<Map<String, dynamic>> submitReport({
    required String targetType,
    String? targetId,
    String? targetTextId,
    required String reason,
    String? details,
  }) async {
    try {
      await _ensureAuthBeforeRequest();

      final payload = <String, dynamic>{
        'targetType': targetType.trim(),
        'reason': reason.trim(),
      };

      final normalizedTargetId = (targetId ?? '').trim();
      if (normalizedTargetId.isNotEmpty) {
        payload['targetId'] = normalizedTargetId;
      }

      final normalizedTargetTextId = (targetTextId ?? '').trim();
      if (normalizedTargetTextId.isNotEmpty) {
        payload['targetTextId'] = normalizedTargetTextId;
      }

      final normalizedDetails = (details ?? '').trim();
      if (normalizedDetails.isNotEmpty) {
        payload['details'] = normalizedDetails;
      }

      final response = await _post(
        Uri.parse('$baseUrl/api/reports'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
        isIdempotent: false,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'];
          if (data is Map<String, dynamic>) {
            return data;
          }
          return <String, dynamic>{};
        }
        return <String, dynamic>{};
      }

      final body = response.body.isNotEmpty ? response.body : 'No response body';
      throw Exception('Failed to submit report (${response.statusCode}): $body');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.submitReport failed: $e');
      rethrow;
    }
  }

  /// Create a support ticket
  /// POST /api/support/tickets
  Future<Map<String, dynamic>> createSupportTicket({
    required String subject,
    required String message,
    String? email,
  }) async {
    try {
      final payload = <String, dynamic>{
        'subject': subject.trim(),
        'message': message.trim(),
      };
      final emailTrimmed = (email ?? '').trim();
      if (emailTrimmed.isNotEmpty) {
        payload['email'] = emailTrimmed;
      }

      final response = await _post(
        Uri.parse('$baseUrl/api/support/tickets'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
        isIdempotent: false,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'];
          if (data is Map<String, dynamic>) {
            return data;
          }
        }
        return <String, dynamic>{};
      }

      final body = response.body.isNotEmpty ? response.body : 'No response body';
      throw Exception('Failed to create support ticket (${response.statusCode}): $body');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createSupportTicket failed: $e');
      rethrow;
    }
  }

  // ==================== NFT Endpoints ====================

  /// Create an NFT series
  /// POST /api/nfts/series
  Future<Map<String, dynamic>> createNFTSeries({
    required String artworkId,
    required String name,
    required String description,
    required int totalSupply,
    required String rarity,
    required String type,
    required double mintPrice,
    String? imageUrl,
    String? animationUrl,
    Map<String, dynamic>? metadata,
    bool requiresARInteraction = false,
    double? royaltyPercentage,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/nfts/series'),
        headers: _getHeaders(),
        body: jsonEncode({
          'artworkId': artworkId,
          'name': name,
          'description': description,
          'totalSupply': totalSupply,
          'rarity': rarity,
          'type': type,
          'mintPrice': mintPrice,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (animationUrl != null) 'animationUrl': animationUrl,
          if (metadata != null) 'metadata': metadata,
          'requiresARInteraction': requiresARInteraction,
          if (royaltyPercentage != null) 'royaltyPercentage': royaltyPercentage,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to create NFT series: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createNFTSeries failed: $e');
      rethrow;
    }
  }

  /// Mint an NFT from a series
  /// POST /api/nfts/mint
  Future<Map<String, dynamic>> mintNFT({
    required String seriesId,
    required String transactionHash,
    Map<String, dynamic>? properties,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/nfts/mint'),
        headers: _getHeaders(),
        body: jsonEncode({
          'seriesId': seriesId,
          'transactionHash': transactionHash,
          if (properties != null) 'properties': properties,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to mint NFT: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.mintNFT failed: $e');
      rethrow;
    }
  }

  /// Get NFT series by artwork ID
  /// GET /api/nfts/series/artwork/:artworkId
  Future<Map<String, dynamic>?> getNFTSeriesByArtwork(String artworkId) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/nfts/series/artwork/$artworkId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['series'] as Map<String, dynamic>?;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to get NFT series: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getNFTSeriesByArtwork failed: $e');
      return null;
    }
  }

  /// Get user's minted NFTs
  /// GET /api/nfts/user/:userId
  Future<List<Map<String, dynamic>>> getUserNFTs({
    required String userId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/nfts/user/$userId')
          .replace(queryParameters: queryParams);
      final response = await _get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['nfts'] as List<dynamic>)
            .map((json) => json as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to get user NFTs: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getUserNFTs failed: $e');
      rethrow;
    }
  }

  /// List NFT for sale
  /// POST /api/nfts/:id/list
  Future<void> listNFT({
    required String nftId,
    required double price,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/nfts/$nftId/list'),
        headers: _getHeaders(),
        body: jsonEncode({
          'price': price,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to list NFT: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.listNFT failed: $e');
      rethrow;
    }
  }

  /// Buy an NFT
  /// POST /api/nfts/:id/buy
  Future<Map<String, dynamic>> buyNFT({
    required String nftId,
    required String transactionHash,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/nfts/$nftId/buy'),
        headers: _getHeaders(),
        body: jsonEncode({
          'transactionHash': transactionHash,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to buy NFT: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.buyNFT failed: $e');
      rethrow;
    }
  }

  /// Get listed NFTs (marketplace)
  /// GET /api/nfts/marketplace
  Future<List<Map<String, dynamic>>> getMarketplaceNFTs({
    int page = 1,
    int limit = 20,
    String? rarity,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (rarity != null) queryParams['rarity'] = rarity;
      if (type != null) queryParams['type'] = type;

      final uri = Uri.parse('$baseUrl/api/nfts/marketplace')
          .replace(queryParameters: queryParams);
      final response = await _get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['nfts'] as List<dynamic>)
            .map((json) => json as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to get marketplace NFTs: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getMarketplaceNFTs failed: $e');
      rethrow;
    }
  }

  // ==================== Achievement Endpoints ====================

  /// Get user achievements
  /// GET /api/users/:userId/achievements
  /// Get user's unlocked achievements and progress
  /// GET /api/achievements/user/:walletAddress
  Future<Map<String, dynamic>> getUserAchievements(String walletAddress) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/achievements/user/$walletAddress'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get user achievements: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getUserAchievements failed: $e');
      return {
        'success': false,
        'unlocked': [],
        'progress': [],
        'totalTokens': 0,
      };
    }
  }

  /// Unlock an achievement
  /// POST /api/achievements/unlock
  Future<Map<String, dynamic>> unlockAchievement({
    required String achievementType,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/achievements/unlock'),
        headers: _getHeaders(),
        body: jsonEncode({
          'achievementType': achievementType,
          if (data != null) 'data': data,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to unlock achievement: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unlockAchievement failed: $e');
      rethrow;
    }
  }

  // ==================== DAO Endpoints (Provisional) ====================

  /// List DAO proposals
  /// GET /api/dao/proposals
  Future<List<Map<String, dynamic>>> getDAOProposals({int limit = 50, int offset = 0, String? status}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/dao/proposals').replace(
        queryParameters: <String, String>{
          'limit': '$limit',
          'offset': '$offset',
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      final response = await _get(uri, includeAuth: false, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['data'] ?? data['proposals'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to get DAO proposals: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getDAOProposals failed: $e');
      return [];
    }
  }

  /// Create a DAO proposal
  /// POST /api/dao/proposals
  Future<Map<String, dynamic>?> createDAOProposal({
    required String walletAddress,
    required String title,
    required String description,
    required String type,
    int votingPeriodDays = 7,
    double supportRequired = 0.5,
    double quorumRequired = 0.1,
    List<String>? supportingDocuments,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final response = await _post(
        Uri.parse('$baseUrl/api/dao/proposals'),
        headers: _getHeaders(),
        body: jsonEncode({
          'title': title,
          'description': description,
          'type': type,
          'votingPeriodDays': votingPeriodDays,
          'supportRequired': supportRequired,
          'quorumRequired': quorumRequired,
          if (supportingDocuments != null) 'supportingDocuments': supportingDocuments,
          if (metadata != null) 'metadata': metadata,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = data['data'] ?? data['proposal'] ?? data;
        return payload is Map<String, dynamic> ? payload : null;
      } else {
        throw Exception('Failed to create proposal: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createDAOProposal failed: $e');
      rethrow;
    }
  }

  /// List votes for a proposal or all votes
  /// GET /api/dao/proposals/:id/votes or /api/dao/votes
  Future<List<Map<String, dynamic>>> getDAOVotes({String? proposalId, int limit = 100, int offset = 0}) async {
    try {
      final uri = proposalId == null
          ? Uri.parse('$baseUrl/api/dao/votes').replace(queryParameters: {
              'limit': '$limit',
              'offset': '$offset',
            })
          : Uri.parse('$baseUrl/api/dao/proposals/$proposalId/votes').replace(queryParameters: {
              'limit': '$limit',
              'offset': '$offset',
            });
      final response = await _get(uri, includeAuth: false, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['votes'] ?? data['data'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to get DAO votes: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getDAOVotes failed: $e');
      return [];
    }
  }

  /// Submit a DAO vote
  /// POST /api/dao/proposals/:id/votes
  Future<Map<String, dynamic>?> submitDAOVote({
    required String proposalId,
    required String walletAddress,
    required String choice,
    double? votingPower,
    String? reason,
    String? txHash,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final response = await _post(
        Uri.parse('$baseUrl/api/dao/proposals/$proposalId/votes'),
        headers: _getHeaders(),
        body: jsonEncode({
          'choice': choice,
          if (votingPower != null) 'votingPower': votingPower,
          if (reason != null) 'reason': reason,
          if (txHash != null) 'txHash': txHash,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['data'] as Map<String, dynamic>? ?? data;
      } else {
        throw Exception('Failed to submit DAO vote: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.submitDAOVote failed: $e');
      rethrow;
    }
  }

  /// List DAO delegates
  /// GET /api/dao/delegates
  Future<List<Map<String, dynamic>>> getDAODelegates() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/dao/delegates'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['delegates'] ?? data['data'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to get DAO delegates: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getDAODelegates failed: $e');
      return [];
    }
  }

  /// Delegate voting power
  /// POST /api/dao/delegations
  Future<Map<String, dynamic>?> delegateVotingPower({
    required String delegateId,
    required String walletAddress,
    double? votingPower,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final response = await _post(
        Uri.parse('$baseUrl/api/dao/delegations'),
        headers: _getHeaders(),
        body: jsonEncode({
          'delegateId': delegateId,
          if (votingPower != null) 'votingPower': votingPower,
          if (metadata != null) 'metadata': metadata,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['data'] as Map<String, dynamic>? ?? data;
      } else {
        throw Exception('Failed to delegate voting power: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.delegateVotingPower failed: $e');
      rethrow;
    }
  }

  /// List DAO treasury/governance transactions
  /// GET /api/dao/transactions
  Future<List<Map<String, dynamic>>> getDAOTransactions() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/dao/transactions'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['data'] ?? data['transactions'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to get DAO transactions: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getDAOTransactions failed: $e');
      return [];
    }
  }

  /// Submit a DAO review/application
  /// POST /api/dao/reviews
  Future<Map<String, dynamic>?> submitDAOReview({
    required String walletAddress,
    required String portfolioUrl,
    required String medium,
    required String statement,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final uri = Uri.parse('$baseUrl/api/dao/reviews');
      final body = jsonEncode({
        'portfolioUrl': portfolioUrl,
        'medium': medium,
        'statement': statement,
        if (title != null && title.isNotEmpty) 'title': title,
        if (metadata != null) 'metadata': metadata,
      });

      final response = await _post(uri, headers: _getHeaders(), body: body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.body.isEmpty) return null;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = data['data'] ?? data['review'] ?? data;
        return payload is Map<String, dynamic> ? payload : null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to submit DAO review: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.submitDAOReview failed: $e');
      return null;
    }
  }

  /// List DAO reviews
  /// GET /api/dao/reviews
  Future<List<Map<String, dynamic>>> getDAOReviews({int limit = 50, int offset = 0}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/dao/reviews')
          .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'});
      final response = await _get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['data'] ?? data['reviews'] ?? data['items'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404) {
        return [];
      } else if (response.statusCode >= 500) {
        AppConfig.debugPrint('BackendApiService.getDAOReviews: backend returned ${response.statusCode}, returning empty list');
        return [];
      } else {
        throw Exception('Failed to get DAO reviews: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getDAOReviews failed: $e');
      return [];
    }
  }

  /// Get a single DAO review by id or wallet address
  /// GET /api/dao/reviews/:id
  @override
  Future<Map<String, dynamic>?> getDAOReview({required String idOrWallet}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/dao/reviews/$idOrWallet');
      final response = await _get(uri, headers: _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['data'] ?? data['review'] ?? data) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to get DAO review: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getDAOReview failed: $e');
      return null;
    }
  }

  /// Decide on a DAO review (approve/reject/pending)
  /// POST /api/dao/reviews/:id/decision
  Future<Map<String, dynamic>?> decideDAOReview({
    required String idOrWallet,
    required String status,
    String? reviewerNotes,
    String? walletAddress,
  }) async {
    try {
      if (walletAddress != null && walletAddress.isNotEmpty) {
        await ensureAuthLoaded(walletAddress: walletAddress);
      }
      final uri = Uri.parse('$baseUrl/api/dao/reviews/$idOrWallet/decision');
      final body = jsonEncode({
        'status': status,
        if (reviewerNotes != null) 'reviewerNotes': reviewerNotes,
      });
      final response = await _post(uri, headers: _getHeaders(), body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = data['data'] ?? data['review'] ?? data;
        return payload is Map<String, dynamic> ? payload : null;
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        throw Exception('Not authorized to decide on this review');
      } else if (response.statusCode == 404) {
        throw Exception('Review not found');
      } else if (response.statusCode == 503) {
        throw Exception('Review decisions are currently disabled');
      } else {
        throw Exception('Failed to update review: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.decideDAOReview failed: $e');
      rethrow;
    }
  }

  // ==================== Institution & Events (Provisional) ====================

  /// List institutions
  /// GET /api/institutions
  Future<List<Map<String, dynamic>>> listInstitutions({int limit = 50, int offset = 0}) async {
    try {
      if (_institutionsApiAvailable == false) return [];
      final uri = Uri.parse('$baseUrl/api/institutions').replace(queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      });
      final response = await _get(uri, includeAuth: false, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        _institutionsApiAvailable = true;
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['institutions'] ?? data['data'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404 || response.statusCode == 400) {
        // Some deployments do not expose these provisional endpoints.
        _institutionsApiAvailable = false;
        return [];
      } else {
        throw Exception('Failed to list institutions: ${response.statusCode}');
      }
    } catch (e) {
      // Treat missing/unstable endpoints as optional; avoid noisy logs in release builds.
      AppConfig.debugPrint('BackendApiService.listInstitutions failed: $e');
      return [];
    }
  }

  /// Get institution by id
  /// GET /api/institutions/:id
  Future<Map<String, dynamic>?> getInstitution(String id) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/institutions/$id'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['institution'] ?? data['data']) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to get institution: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getInstitution failed: $e');
      return null;
    }
  }

  /// List events
  ///
  /// - Primary backend: GET /api/events
  /// - Legacy/fallback: GET /api/institutions/:id/events (may not exist on all deployments)
  ///
  /// Returns a list of event JSON maps (not typed) to preserve backward compatibility
  /// with older parts of the app.
  Future<List<Map<String, dynamic>>> listEvents({
    String? institutionId,
    bool? upcoming,
    String? from,
    String? to,
    double? lat,
    double? lng,
    double? radiusKm,
    String? hostUserId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      if (_eventsApiAvailable == false) return [];
      final base = institutionId == null
          ? '$baseUrl/api/events'
          : '$baseUrl/api/institutions/$institutionId/events';
      final query = <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      };
      if (upcoming != null) query['upcoming'] = '$upcoming';
      if (from != null && from.trim().isNotEmpty) query['from'] = from.trim();
      if (to != null && to.trim().isNotEmpty) query['to'] = to.trim();
      if (lat != null) query['lat'] = lat.toString();
      if (lng != null) query['lng'] = lng.toString();
      if (radiusKm != null) query['radiusKm'] = radiusKm.toString();
      if (hostUserId != null && hostUserId.trim().isNotEmpty) query['hostUserId'] = hostUserId.trim();
      final uri = Uri.parse(base).replace(queryParameters: query);
      // Optional auth: include token when present so backend can return `myRole`.
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final response = await _get(uri, headers: _getHeaders(includeAuth: true));

      if (response.statusCode == 200) {
        _eventsApiAvailable = true;
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final dynamic data = decoded['data'] ?? decoded;
          // New envelope: { success: true, data: { events: [...] } }
          if (data is Map<String, dynamic>) {
            final list = (data['events'] ?? data['items'] ?? data['results'] ?? const []) as dynamic;
            if (list is List) return List<Map<String, dynamic>>.from(list);
          }
          // Legacy: { events: [...] } or { data: [...] }
          final list = decoded['events'] ?? (decoded['data'] is List ? decoded['data'] : null);
          if (list is List) return List<Map<String, dynamic>>.from(list);
        }
        return [];
      } else if (response.statusCode == 404) {
        _eventsApiAvailable = false;
        return [];
      } else if (response.statusCode == 400 && institutionId == null) {
        // Some deployments use page-based pagination rather than offset.
        final page = (offset ~/ (limit <= 0 ? 1 : limit)) + 1;
        final retryQuery = <String, String>{
          'limit': '$limit',
          'page': '$page',
        };
        if (upcoming != null) retryQuery['upcoming'] = '$upcoming';
        if (from != null && from.trim().isNotEmpty) retryQuery['from'] = from.trim();
        if (to != null && to.trim().isNotEmpty) retryQuery['to'] = to.trim();
        if (lat != null) retryQuery['lat'] = lat.toString();
        if (lng != null) retryQuery['lng'] = lng.toString();
        if (radiusKm != null) retryQuery['radiusKm'] = radiusKm.toString();
        if (hostUserId != null && hostUserId.trim().isNotEmpty) retryQuery['hostUserId'] = hostUserId.trim();
        final retryUri = Uri.parse('$baseUrl/api/events').replace(queryParameters: retryQuery);
        final retryRes = await _get(retryUri, headers: _getHeaders(includeAuth: true));
        if (retryRes.statusCode == 200) {
          _eventsApiAvailable = true;
          final decoded = jsonDecode(retryRes.body);
          if (decoded is Map<String, dynamic>) {
            final dynamic data = decoded['data'] ?? decoded;
            if (data is Map<String, dynamic>) {
              final list = (data['events'] ?? data['items'] ?? data['results'] ?? const []) as dynamic;
              if (list is List) return List<Map<String, dynamic>>.from(list);
            }
            final list = decoded['events'] ?? (decoded['data'] is List ? decoded['data'] : null);
            if (list is List) return List<Map<String, dynamic>>.from(list);
          }
          return [];
        }

        // Still not usable.
        _eventsApiAvailable = false;
        return [];
      } else {
        throw Exception('Failed to list events: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.listEvents failed: $e');
      return [];
    }
  }

  /// Get a single event
  /// GET /api/events/:id
  Future<KubusEvent?> getEvent(String id) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/events/$id');
      final decoded = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final payload = decoded['data'] ?? decoded;
      final eventRaw = (payload is Map<String, dynamic>) ? (payload['event'] ?? payload['data'] ?? payload) : null;
      if (eventRaw is Map<String, dynamic>) {
        return KubusEvent.fromJson(eventRaw);
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getEvent failed: $e');
      rethrow;
    }
  }

  /// Create an event
  /// POST /api/events
  Future<KubusEvent?> createEvent(Map<String, dynamic> payload) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/events');
      final response = await _post(uri, headers: _getHeaders(), body: jsonEncode(payload));
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] ?? decoded;
          final eventRaw = data is Map<String, dynamic> ? (data['event'] ?? data) : null;
          if (eventRaw is Map<String, dynamic>) return KubusEvent.fromJson(eventRaw);
        }
        return null;
      }
      throw Exception('Failed to create event: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createEvent failed: $e');
      rethrow;
    }
  }

  /// Update an event
  /// PUT /api/events/:id
  Future<KubusEvent?> updateEvent(String id, Map<String, dynamic> updates) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/events/$id');
      final response = await _put(uri, headers: _getHeaders(), body: jsonEncode(updates), isIdempotent: true);
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] ?? decoded;
          final eventRaw = data is Map<String, dynamic> ? (data['event'] ?? data) : null;
          if (eventRaw is Map<String, dynamic>) return KubusEvent.fromJson(eventRaw);
        }
        return null;
      }
      throw Exception('Failed to update event: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.updateEvent failed: $e');
      rethrow;
    }
  }

  /// Delete an event
  /// DELETE /api/events/:id
  Future<bool> deleteEvent(String id) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/events/$id');
      final response = await _delete(uri, headers: _getHeaders(), isIdempotent: true);
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) return true;
      throw Exception('Failed to delete event: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteEvent failed: $e');
      rethrow;
    }
  }

  /// List exhibitions for an event
  /// GET /api/events/:id/exhibitions
  Future<List<Exhibition>> listEventExhibitions(String eventId, {int limit = 50, int offset = 0}) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/events/$eventId/exhibitions').replace(queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      });
      final decoded = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final payload = decoded['data'] ?? decoded;
      if (payload is Map<String, dynamic>) {
        final list = payload['exhibitions'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(Exhibition.fromJson)
              .toList();
        }
      }
      return const [];
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.listEventExhibitions failed: $e');
      rethrow;
    }
  }

  // ==================== Exhibitions (Events v2) ====================

  /// List exhibitions
  /// GET /api/exhibitions
  Future<List<Exhibition>> listExhibitions({
    String? eventId,
    bool? mine,
    String? from,
    String? to,
    double? lat,
    double? lng,
    double? radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final qp = <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      };
      if (eventId != null && eventId.trim().isNotEmpty) qp['eventId'] = eventId.trim();
      if (mine == true) qp['mine'] = 'true';
      if (from != null && from.trim().isNotEmpty) qp['from'] = from.trim();
      if (to != null && to.trim().isNotEmpty) qp['to'] = to.trim();
      if (lat != null) qp['lat'] = lat.toString();
      if (lng != null) qp['lng'] = lng.toString();
      if (radiusKm != null) qp['radiusKm'] = radiusKm.toString();
      final uri = Uri.parse('$baseUrl/api/exhibitions').replace(queryParameters: qp);
      final decoded = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final payload = decoded['data'] ?? decoded;
      if (payload is Map<String, dynamic>) {
        final list = payload['exhibitions'] ?? payload['items'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(Exhibition.fromJson)
              .toList();
        }
      }
      return const [];
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.listExhibitions failed: $e');
      rethrow;
    }
  }

  /// Get exhibition by id
  /// GET /api/exhibitions/:id
  Future<Exhibition?> getExhibition(String id) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/exhibitions/$id');
      final decoded = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final payload = decoded['data'] ?? decoded;
      final exhibitionRaw = (payload is Map<String, dynamic>) ? (payload['exhibition'] ?? payload['data'] ?? payload) : null;
      if (exhibitionRaw is Map<String, dynamic>) {
        return Exhibition.fromJson(exhibitionRaw);
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getExhibition failed: $e');
      rethrow;
    }
  }

  /// Create exhibition
  /// POST /api/exhibitions
  Future<Exhibition?> createExhibition(Map<String, dynamic> payload) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/exhibitions');
      final response = await _post(uri, headers: _getHeaders(), body: jsonEncode(payload));
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] ?? decoded;
          final exhibitionRaw = data is Map<String, dynamic> ? (data['exhibition'] ?? data) : null;
          if (exhibitionRaw is Map<String, dynamic>) return Exhibition.fromJson(exhibitionRaw);
        }
        return null;
      }
      throw Exception('Failed to create exhibition: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createExhibition failed: $e');
      rethrow;
    }
  }

  /// Update exhibition
  /// PUT /api/exhibitions/:id
  Future<Exhibition?> updateExhibition(String id, Map<String, dynamic> updates) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/exhibitions/$id');
      final response = await _put(uri, headers: _getHeaders(), body: jsonEncode(updates), isIdempotent: true);
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] ?? decoded;
          final exhibitionRaw = data is Map<String, dynamic> ? (data['exhibition'] ?? data) : null;
          if (exhibitionRaw is Map<String, dynamic>) return Exhibition.fromJson(exhibitionRaw);
        }
        return null;
      }
      throw Exception('Failed to update exhibition: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.updateExhibition failed: $e');
      rethrow;
    }
  }

  /// Delete exhibition
  /// DELETE /api/exhibitions/:id
  Future<bool> deleteExhibition(String id) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/exhibitions/$id');
      final response = await _delete(uri, headers: _getHeaders(), isIdempotent: true);
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) return true;
      throw Exception('Failed to delete exhibition: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteExhibition failed: $e');
      rethrow;
    }
  }

  /// Link artworks to an exhibition
  /// POST /api/exhibitions/:id/artworks { artworkIds: [...] }
  Future<Map<String, dynamic>> linkExhibitionArtworks(String exhibitionId, List<String> artworkIds) async {
    await _ensureAuthBeforeRequest();
    final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/artworks');
    final response = await _post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode({'artworkIds': artworkIds}),
      isIdempotent: true,
    );
    if (_isSuccessStatus(response.statusCode)) {
      return response.body.isNotEmpty ? (jsonDecode(response.body) as Map<String, dynamic>) : {'success': true};
    }
    throw Exception('Failed to link exhibition artworks: ${response.statusCode} ${response.body}');
  }

  /// Unlink a single artwork from an exhibition
  /// DELETE /api/exhibitions/:id/artworks/:artworkId
  Future<Map<String, dynamic>> unlinkExhibitionArtwork(String exhibitionId, String artworkId) async {
    await _ensureAuthBeforeRequest();
    final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/artworks/$artworkId');
    final response = await _delete(uri, headers: _getHeaders(), isIdempotent: true);
    if (_isSuccessStatus(response.statusCode)) {
      return response.body.isNotEmpty ? (jsonDecode(response.body) as Map<String, dynamic>) : {'success': true};
    }
    throw Exception('Failed to unlink exhibition artwork: ${response.statusCode} ${response.body}');
  }

  /// Link markers to an exhibition
  /// POST /api/exhibitions/:id/markers { markerIds: [...] }
  Future<Map<String, dynamic>> linkExhibitionMarkers(String exhibitionId, List<String> markerIds) async {
    await _ensureAuthBeforeRequest();
    final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/markers');
    final response = await _post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode({'markerIds': markerIds}),
      isIdempotent: true,
    );
    if (_isSuccessStatus(response.statusCode)) {
      return response.body.isNotEmpty ? (jsonDecode(response.body) as Map<String, dynamic>) : {'success': true};
    }
    throw Exception('Failed to link exhibition markers: ${response.statusCode} ${response.body}');
  }

  /// Unlink a single marker from an exhibition
  /// DELETE /api/exhibitions/:id/markers/:markerId
  Future<Map<String, dynamic>> unlinkExhibitionMarker(String exhibitionId, String markerId) async {
    await _ensureAuthBeforeRequest();
    final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/markers/$markerId');
    final response = await _delete(uri, headers: _getHeaders(), isIdempotent: true);
    if (_isSuccessStatus(response.statusCode)) {
      return response.body.isNotEmpty ? (jsonDecode(response.body) as Map<String, dynamic>) : {'success': true};
    }
    throw Exception('Failed to unlink exhibition marker: ${response.statusCode} ${response.body}');
  }

  /// Fetch exhibition POAP status
  /// GET /api/exhibitions/:id/poap
  Future<ExhibitionPoapStatus?> getExhibitionPoap(String exhibitionId) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/poap');
      final decoded = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final payload = decoded['data'] ?? decoded;
      if (payload is Map<String, dynamic>) {
        return ExhibitionPoapStatus.fromJson(payload);
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getExhibitionPoap failed: $e');
      rethrow;
    }
  }

  /// Claim exhibition POAP
  /// POST /api/exhibitions/:id/poap/claim
  Future<ExhibitionPoapStatus?> claimExhibitionPoap(String exhibitionId) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/poap/claim');
      final response = await _post(uri, headers: _getHeaders());
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (_isSuccessStatus(response.statusCode)) {
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            return ExhibitionPoapStatus.fromJson(payload);
          }
        }
        return null;
      }
      throw Exception('Failed to claim exhibition POAP: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.claimExhibitionPoap failed: $e');
      rethrow;
    }
  }

  // ==================== Collaboration ====================

  /// Invite a collaborator
  /// POST /api/collab/:entityType/:entityId/invites { invited, role }
  Future<CollabInvite?> inviteCollaborator(
    String entityType,
    String entityId,
    String invitedIdentifier,
    String role,
  ) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/collab/$entityType/$entityId/invites');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({'invited': invitedIdentifier, 'role': role}),
      );
      final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (_isSuccessStatus(response.statusCode)) {
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded;
          final inviteRaw = payload is Map<String, dynamic> ? (payload['invite'] ?? payload) : null;
          if (inviteRaw is Map<String, dynamic>) return CollabInvite.fromJson(inviteRaw);
        }
        return null;
      }
      throw Exception('Failed to invite collaborator: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.inviteCollaborator failed: $e');
      rethrow;
    }
  }

  /// List collaborators for an entity
  /// GET /api/collab/:entityType/:entityId/members
  Future<List<CollabMember>> listCollaborators(String entityType, String entityId) async {
    try {
      // optional auth
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/collab/$entityType/$entityId/members');
      final decoded = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final payload = decoded['data'] ?? decoded;
      if (payload is Map<String, dynamic>) {
        final list = payload['members'] ?? payload['data'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(CollabMember.fromJson)
              .toList();
        }
      }
      return const [];
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.listCollaborators failed: $e');
      rethrow;
    }
  }

  /// List invites for current user
  /// GET /api/collab/invites
  Future<List<CollabInvite>> listMyCollabInvites() async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/collab/invites');
      final response = await _get(uri, headers: _getHeaders(includeAuth: true));
      if (_isSuccessStatus(response.statusCode)) {
        final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : const <String, dynamic>{};
        final payload = decoded is Map<String, dynamic> ? (decoded['data'] ?? decoded) : null;
        if (payload is Map<String, dynamic>) {
          final list = payload['invites'] ?? payload['data'];
          if (list is List) {
            return list
                .whereType<Map<String, dynamic>>()
                .map(CollabInvite.fromJson)
                .toList();
          }
        }
        return const [];
      }
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Accept an invite
  /// POST /api/collab/invites/:inviteId/accept
  Future<bool> acceptInvite(String inviteId) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/collab/invites/$inviteId/accept');
      final response = await _post(uri, headers: _getHeaders(), isIdempotent: true);
      if (_isSuccessStatus(response.statusCode)) return true;
      throw Exception('Failed to accept invite: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.acceptInvite failed: $e');
      rethrow;
    }
  }

  /// Decline an invite
  /// POST /api/collab/invites/:inviteId/decline
  Future<bool> declineInvite(String inviteId) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/collab/invites/$inviteId/decline');
      final response = await _post(uri, headers: _getHeaders(), isIdempotent: true);
      if (_isSuccessStatus(response.statusCode)) return true;
      throw Exception('Failed to decline invite: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.declineInvite failed: $e');
      rethrow;
    }
  }

  /// Update collaborator role
  /// PATCH /api/collab/:entityType/:entityId/members/:memberUserId
  Future<bool> updateCollaboratorRole(String entityType, String entityId, String memberUserId, String role) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/collab/$entityType/$entityId/members/$memberUserId');
      final response = await _patch(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({'role': role}),
        isIdempotent: true,
      );
      if (_isSuccessStatus(response.statusCode)) return true;
      throw Exception('Failed to update collaborator role: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.updateCollaboratorRole failed: $e');
      rethrow;
    }
  }

  /// Remove a collaborator
  /// DELETE /api/collab/:entityType/:entityId/members/:memberUserId
  Future<bool> removeCollaborator(String entityType, String entityId, String memberUserId) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/collab/$entityType/$entityId/members/$memberUserId');
      final response = await _delete(uri, headers: _getHeaders(), isIdempotent: true);
      if (_isSuccessStatus(response.statusCode)) return true;
      throw Exception('Failed to remove collaborator: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.removeCollaborator failed: $e');
      rethrow;
    }
  }

  /// Get all available achievements
  /// GET /api/achievements
  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/achievements'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['achievements'] ?? []);
      } else {
        throw Exception('Failed to get achievements: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getAchievements failed: $e');
      return [];
    }
  }

  /// Update achievement progress
  /// POST /api/achievements/progress
  Future<Map<String, dynamic>> updateAchievementProgress({
    required String achievementId,
    required int progress,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/achievements/progress'),
        headers: _getHeaders(),
        isIdempotent: true,
        body: jsonEncode({
          'achievementId': achievementId,
          'progress': progress,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to update achievement progress: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.updateAchievementProgress failed: $e');
      rethrow;
    }
  }

  /// Get achievement statistics for a user
  /// GET /api/achievements/stats/:walletAddress
  Future<Map<String, dynamic>> getAchievementStats(String walletAddress) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/achievements/stats/$walletAddress'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['stats'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get achievement stats: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getAchievementStats failed: $e');
      return {
        'total': 0,
        'unlocked': 0,
        'totalTokens': 0,
        'byRarity': [],
        'recent': [],
      };
    }
  }

  /// Get achievement leaderboard
  /// GET /api/achievements/leaderboard
  Future<List<Map<String, dynamic>>> getAchievementLeaderboard({
    int limit = 10,
    String type = 'tokens',
  }) async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/achievements/leaderboard?limit=$limit&type=$type'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
      } else {
        throw Exception('Failed to get leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getAchievementLeaderboard failed: $e');
      return [];
    }
  }

  // ==================== Storage Endpoints ====================

  /// Upload a file to backend storage
  /// POST /api/upload
  Future<Map<String, dynamic>> uploadFile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
    String? walletAddress,
  }) async {
    // Ensure uploads include auth so the backend accepts and attributes them.
    await _ensureAuthBeforeRequest(walletAddress: walletAddress);
    const int maxRetries = 3;
    int attempt = 0;
      while (true) {
        attempt++;
        try {
          http.MultipartRequest buildRequest() {
            final request = http.MultipartRequest(
              'POST',
              Uri.parse('$baseUrl/api/upload'),
            );

            request.headers.addAll(_getHeaders());
            request.files.add(
              http.MultipartFile.fromBytes(
                'file',
                fileBytes,
                filename: fileName,
              ),
            );

            request.fields['fileType'] = fileType;
            request.fields['targetStorage'] = 'http'; // Use HTTP storage instead of hybrid/IPFS
            if (metadata != null) {
              request.fields['metadata'] = jsonEncode(metadata);
            }

            return request;
          }

          final response = await _sendMultipart(buildRequest, includeAuth: true);

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;

          // Backend returns { success:true, message:'', data: { filename, size, mimetype, ...result } }
          final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
              : (body['data'] != null ? Map<String, dynamic>.from(body['data']) : {});

          // Try to determine the best URL for the uploaded file
          String? uploadedUrl;
          try {
            if (data.containsKey('url') && (data['url'] as String).isNotEmpty) {
              uploadedUrl = data['url'] as String;
            } else if (data.containsKey('ipfsUrl') && (data['ipfsUrl'] as String).isNotEmpty) {
              uploadedUrl = data['ipfsUrl'] as String;
            } else if (data.containsKey('httpUrl') && (data['httpUrl'] as String).isNotEmpty) {
              uploadedUrl = data['httpUrl'] as String;
            } else if (data.containsKey('fileUrl') && (data['fileUrl'] as String).isNotEmpty) {
              uploadedUrl = data['fileUrl'] as String;
            } else if (data.containsKey('path') && (data['path'] as String).isNotEmpty) {
              uploadedUrl = data['path'] as String;
            }
          } catch (_) {
            uploadedUrl = null;
          }

          // Return structured result including computed uploadedUrl for easy consumption
          return {
            'raw': body,
            'data': data,
            'uploadedUrl': uploadedUrl,
          };
        }

        if (response.statusCode == 429) {
          final retryAfter = response.headers['retry-after'];
          final waitSeconds = int.tryParse(retryAfter ?? '') ?? (2 << (attempt - 1));
          if (attempt < maxRetries) {
            _debugLogThrottled(
              'uploadFile:429',
              'BackendApiService.uploadFile: received 429, retrying in ${waitSeconds}s (attempt $attempt/$maxRetries)',
            );
            await Future.delayed(Duration(seconds: waitSeconds));
            continue;
          } else {
            throw Exception('Too many requests (429) while uploading file.');
          }
        }

        throw Exception('Failed to upload file: ${response.statusCode}');
      } catch (e) {
        if (attempt >= maxRetries) {
          _debugLogThrottled(
            'uploadFile:error:final',
            'BackendApiService.uploadFile: error (final): $e',
          );
          rethrow;
        }
        final backoff = 1 << (attempt - 1);
        _debugLogThrottled(
          'uploadFile:error:retry',
          'BackendApiService.uploadFile: transient error, retrying in ${backoff}s (attempt $attempt/$maxRetries): $e',
        );
        await Future.delayed(Duration(seconds: backoff));
      }
    }
  }

  /// Upload avatar specifically to profile avatars endpoint
  /// POST /api/profiles/avatars
  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) async {
    _debugLogThrottled(
      'uploadAvatarToProfile:start',
      'BackendApiService.uploadAvatarToProfile: starting upload (fileName=$fileName, fileType=$fileType, bytes=${fileBytes.length})',
    );
    
    const int maxRetries = 3;
    int attempt = 0;
    while (true) {
      attempt++;
      _debugLogThrottled(
        'uploadAvatarToProfile:attempt',
        'BackendApiService.uploadAvatarToProfile: attempt $attempt/$maxRetries',
      );
      try {
        final uri = Uri.parse('$baseUrl/api/profiles/avatars');
        _debugLogThrottled('uploadAvatarToProfile:url', 'BackendApiService.uploadAvatarToProfile: POST $uri');
        
        http.MultipartRequest buildRequest() {
          final request = http.MultipartRequest('POST', uri);

          // include auth header if set
          request.headers.addAll(_getHeaders());
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: fileName,
              contentType: MediaType.parse(fileType),
            ),
          );

          request.fields['fileType'] = fileType;
          if (metadata != null) request.fields['metadata'] = jsonEncode(metadata);
          return request;
        }

        final response = await _sendMultipart(buildRequest, includeAuth: true);
        _debugLogThrottled(
          'uploadAvatarToProfile:status',
          'BackendApiService.uploadAvatarToProfile: status=${response.statusCode} bodyLen=${response.body.length}',
        );

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
              : (body['data'] != null ? Map<String, dynamic>.from(body['data']) : {});

          String? uploadedUrl;
          try {
            // Backend returns avatar URL in data.avatar field
            if (data.containsKey('avatar') && data['avatar'] != null && (data['avatar'] as String).isNotEmpty) {
              uploadedUrl = data['avatar'] as String;
            } else if (data.containsKey('url') && (data['url'] as String).isNotEmpty) {
              uploadedUrl = data['url'] as String;
            } else if (data.containsKey('ipfsUrl') && (data['ipfsUrl'] as String).isNotEmpty) {
              uploadedUrl = data['ipfsUrl'] as String;
            } else if (data.containsKey('httpUrl') && (data['httpUrl'] as String).isNotEmpty) {
              uploadedUrl = data['httpUrl'] as String;
            } else if (data.containsKey('fileUrl') && (data['fileUrl'] as String).isNotEmpty) {
              uploadedUrl = data['fileUrl'] as String;
            } else if (data.containsKey('path') && (data['path'] as String).isNotEmpty) {
              uploadedUrl = data['path'] as String;
            }
          } catch (_) {
            uploadedUrl = null;
          }

          _debugLogThrottled(
            'uploadAvatarToProfile:done',
            'BackendApiService.uploadAvatarToProfile: upload complete (uploadedUrl=${uploadedUrl ?? 'null'})',
          );
          return {
            'raw': body,
            'data': data,
            'uploadedUrl': uploadedUrl,
          };
        }

        if (response.statusCode == 429) {
          final retryAfter = response.headers['retry-after'];
          final waitSeconds = int.tryParse(retryAfter ?? '') ?? (2 << (attempt - 1));
          if (attempt < maxRetries) {
            _debugLogThrottled(
              'uploadAvatarToProfile:429',
              'BackendApiService.uploadAvatarToProfile: received 429, retrying in ${waitSeconds}s (attempt $attempt/$maxRetries)',
            );
            await Future.delayed(Duration(seconds: waitSeconds));
            continue;
          } else {
            throw Exception('Too many requests (429) while uploading avatar.');
          }
        }

        throw Exception('Failed to upload avatar: ${response.statusCode} ${response.body}');
      } catch (e, stackTrace) {
        if (attempt >= maxRetries) {
          _debugLogThrottled(
            'uploadAvatarToProfile:error:final',
            'BackendApiService.uploadAvatarToProfile: error (final): $e\n$stackTrace',
            throttle: const Duration(seconds: 1),
          );
          rethrow;
        }
        final backoff = 1 << (attempt - 1);
        _debugLogThrottled(
          'uploadAvatarToProfile:error:retry',
          'BackendApiService.uploadAvatarToProfile: transient error, retrying in ${backoff}s (attempt $attempt/$maxRetries): $e',
        );
        await Future.delayed(Duration(seconds: backoff));
      }
    }
  }

  // ==================== Health Check ====================

  /// Send telemetry/analytics event to backend
  /// POST /api/telemetry (best-effort; backend may ignore)
  Future<void> sendTelemetryEvent(String eventName, Map<String, dynamic>? params) async {
    try {
      final uri = Uri.parse('$baseUrl/api/telemetry');
      final body = jsonEncode({'event': eventName, 'params': params ?? {}});
      final response = await _post(
        uri,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: body,
        isIdempotent: true,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      // Non-fatal: ignore telemetry failures
      AppConfig.debugPrint('BackendApiService.sendTelemetryEvent: status ${response.statusCode}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.sendTelemetryEvent failed: $e');
    }
  }

  /// Ingest app client telemetry in batches (best-effort; non-blocking).
  ///
  /// POST /api/analytics/app
  Future<http.Response?> postAppTelemetry(String jsonBody) async {
    try {
      final uri = Uri.parse('$baseUrl/api/analytics/app');
      final response = await _post(
        uri,
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        body: jsonBody,
        isIdempotent: true,
        timeout: const Duration(seconds: 6),
      );
      return response;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.postAppTelemetry failed: $e');
      return null;
    }
  }

  /// Check backend health
  /// GET /health
  Future<bool> checkHealth() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/health'),
        includeAuth: false,
        headers: _getHeaders(includeAuth: false),
        timeout: const Duration(seconds: 5),
      );

      return response.statusCode == 200;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.checkHealth failed: $e');
      return false;
    }
  }

  // ==================== Collections Endpoints ====================

  /// Get user's collections
  /// GET /api/collections?walletAddress=xxx
  Future<List<Map<String, dynamic>>> getCollections({
    String? walletAddress,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final requestedWallet = (walletAddress ?? '').trim();

      // Collections are generally public for other users. Only include auth
      // when the request is for the currently signed-in wallet (or when the
      // caller is implicitly requesting "my collections" by omitting a wallet).
        final requestedCanonical = WalletUtils.canonical(requestedWallet);
        final preferredCanonical = WalletUtils.canonical(_preferredWalletCanonical ?? '');
        final isForPreferredWallet = requestedCanonical.isNotEmpty &&
          preferredCanonical.isNotEmpty &&
          requestedCanonical == preferredCanonical;
      final isImplicitSelfRequest = requestedWallet.isEmpty;

      final includeAuth = isImplicitSelfRequest || isForPreferredWallet;
      if (includeAuth) {
        if (isForPreferredWallet) {
          // Guarded: will not auth-switch/issue for arbitrary wallets.
          await _ensureAuthBeforeRequest(walletAddress: requestedWallet);
        } else {
          // Best effort: try to load existing auth for stored wallet, but don't
          // force issuing tokens for view-only flows.
          try {
            await _ensureAuthWithStoredWallet();
          } catch (_) {}
        }
      }
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (requestedWallet.isNotEmpty) {
        queryParams['walletAddress'] = requestedWallet;
      }

      final uri = Uri.parse('$baseUrl/api/collections').replace(queryParameters: queryParams);
      final jsonData = await _fetchJson(
        uri,
        includeAuth: includeAuth,
        allowOrbitFallback: true,
      );

      final rawData = jsonData['data'];
      if (rawData is List) {
        return rawData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (rawData is Map<String, dynamic> && rawData['data'] is List) {
        return (rawData['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      throw Exception('Unexpected collections response shape');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getCollections failed: $e');
      return [];
    }
  }

  /// Get collection by ID with artworks
  /// GET /api/collections/:id
  Future<Map<String, dynamic>> getCollection(String collectionId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/collections/$collectionId');
      final jsonData = await _fetchJson(
        uri,
        includeAuth: true,
        allowOrbitFallback: true,
      );

      final data = jsonData['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }

      throw Exception('Unexpected collection response shape');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getCollection failed: $e');
      rethrow;
    }
  }

  /// Create new collection
  /// POST /api/collections
  Future<Map<String, dynamic>> createCollection({
    required String name,
    String? description,
    bool isPublic = true,
    String? thumbnailUrl,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/collections'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          if (description != null) 'description': description,
          'isPublic': isPublic,
          if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return jsonData['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to create collection: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createCollection failed: $e');
      rethrow;
    }
  }

  /// Update collection
  /// PUT /api/collections/:id
  Future<Map<String, dynamic>> updateCollection({
    required String collectionId,
    String? name,
    String? description,
    bool? isPublic,
    String? thumbnailUrl,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final payload = <String, dynamic>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (isPublic != null) 'isPublic': isPublic,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      };

      final response = await _put(
        Uri.parse('$baseUrl/api/collections/$collectionId'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
        isIdempotent: true,
      );

      if (response.statusCode == 200) {
        final jsonData = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        if (jsonData is Map<String, dynamic>) {
          final data = jsonData['data'];
          if (data is Map<String, dynamic>) {
            return data;
          }
          return jsonData;
        }
        return const <String, dynamic>{};
      }
      throw Exception('Failed to update collection: ${response.statusCode} ${response.body}');
    } catch (e) {
      rethrow;
    }
  }

  /// Delete collection
  /// DELETE /api/collections/:id
  Future<void> deleteCollection(String collectionId) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/api/collections/$collectionId'),
        headers: _getHeaders(),
        isIdempotent: true,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete collection: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteCollection failed: $e');
      rethrow;
    }
  }

  /// Add artwork to collection
  /// POST /api/collections/:id/artworks
  Future<void> addArtworkToCollection({
    required String collectionId,
    required String artworkId,
    String? notes,
  }) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/collections/$collectionId/artworks'),
        headers: _getHeaders(),
        isIdempotent: true,
        body: jsonEncode({
          'artworkId': artworkId,
          if (notes != null) 'notes': notes,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add artwork to collection: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.addArtworkToCollection failed: $e');
      rethrow;
    }
  }

  /// Remove artwork from collection
  /// DELETE /api/collections/:id/artworks/:artworkId
  Future<void> removeArtworkFromCollection({
    required String collectionId,
    required String artworkId,
  }) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/api/collections/$collectionId/artworks/$artworkId'),
        headers: _getHeaders(),
        isIdempotent: true,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove artwork from collection: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.removeArtworkFromCollection failed: $e');
      rethrow;
    }
  }

  // ==================== Notifications Endpoints ====================

  /// Get user notifications
  /// GET /api/notifications
  Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    int limit = 50,
    bool unreadOnly = false,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'unreadOnly': unreadOnly.toString(),
      };
      
      if (type != null) {
        queryParams['type'] = type;
      }

      final uri = Uri.parse('$baseUrl/api/notifications').replace(queryParameters: queryParams);
      final response = await _get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final notifications = jsonData['data'] as List<dynamic>;
        return notifications.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getNotifications failed: $e');
      return [];
    }
  }

  /// Get unread notification count
  /// GET /api/notifications/unread-count
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await _get(
        Uri.parse('$baseUrl/api/notifications/unread-count'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return jsonData['unreadCount'] as int? ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getUnreadNotificationCount failed: $e');
      return 0;
    }
  }

  /// Mark notification as read
  /// PUT /api/notifications/:id/read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
        headers: _getHeaders(),
        isIdempotent: true,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.markNotificationAsRead failed: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read
  /// PUT /api/notifications/read-all
  Future<void> markAllNotificationsAsRead() async {
    try {
      final response = await _put(
        Uri.parse('$baseUrl/api/notifications/read-all'),
        headers: _getHeaders(),
        isIdempotent: true,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark all notifications as read: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.markAllNotificationsAsRead failed: $e');
      rethrow;
    }
  }

  /// Delete notification
  /// DELETE /api/notifications/:id
  Future<void> deleteNotification(String notificationId) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/api/notifications/$notificationId'),
        headers: _getHeaders(),
        isIdempotent: true,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete notification: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteNotification failed: $e');
      rethrow;
    }
  }

  /// Delete the current user's off-chain account data (profile + community content).
  /// DELETE /api/profiles/me
  Future<void> deleteMyAccountData({String? walletAddress}) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final response = await _delete(
        Uri.parse('$baseUrl/api/profiles/me'),
        headers: _getHeaders(),
        isIdempotent: true,
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete account data: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteMyAccountData failed: $e');
      rethrow;
    }
  }

  // ==================== Search Endpoints ====================

  /// Universal search
  /// GET /api/search?q=xxx&type=all
  Future<Map<String, dynamic>> search({
    required String query,
    String type = 'all', // all, profiles, artworks, institutions, collections, posts
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, String>{
        'q': query,
        'type': type,
        'limit': limit.toString(),
        'page': page.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/search').replace(queryParameters: queryParams);
      final response = await _get(uri, includeAuth: false, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.search failed: $e');
      return {
        'success': false,
        'query': query,
        'totalResults': 0,
        'results': {},
      };
    }
  }

  /// Get search suggestions (autocomplete)
  /// GET /api/search/suggestions?q=xxx
  Future<List<Map<String, dynamic>>> getSearchSuggestions({
    required String query,
    int limit = 10,
  }) async {
    try {
      final queryParams = <String, String>{
        'q': query,
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/search/suggestions').replace(queryParameters: queryParams);
      final key = _rateLimitKey('GET', uri);
      if (_isRateLimited(key)) {
        throw Exception(_rateLimitMessage(key));
      }

      final headers = _getHeaders(includeAuth: true);
      dynamic data;

      Future<dynamic> tryFetch(Uri target) async {
        final response = await _get(target, headers: headers, includeAuth: true);
        if (_isSuccessStatus(response.statusCode)) {
          return jsonDecode(response.body);
        }
        if (response.statusCode == 429) {
          _markRateLimited(key, response, defaultWindowMs: 900000);
          throw Exception(_rateLimitMessage(key));
        }
        return null;
      }

      // Primary request (may return List or Map)
      data = await tryFetch(uri);

      // Orbit fallback when primary fails or returns empty
      if (data == null) {
        final fallbackUri = _withOrbitSource(uri);
        data = await tryFetch(fallbackUri);
      }

      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      if (data is Map<String, dynamic>) {
        final dynamic suggestions = data['suggestions'] ?? data['data'] ?? data['results'];
        if (suggestions is List) {
          return suggestions.whereType<Map<String, dynamic>>().toList();
        }
      }
      AppConfig.debugPrint('BackendApiService.getSearchSuggestions: unexpected payload for "$query"');
      return const [];
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getSearchSuggestions failed for "$query": $e');
      return const [];
    }
  }

  /// Get trending search terms
  /// GET /api/search/trending
  Future<List<Map<String, dynamic>>> getTrendingSearches({int limit = 10}) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/search/trending').replace(queryParameters: queryParams);
      final response = await _get(uri, includeAuth: false, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final trending = jsonData['trending'] as List<dynamic>;
        return trending.map((e) => e as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getTrendingSearches failed: $e');
      return [];
    }
  }

  // ==================== Message Reactions ====================

  /// Add a reaction to a message
  /// POST /api/conversations/:conversationId/messages/:messageId/reactions
  Future<void> addMessageReaction(String conversationId, String messageId, String emoji) async {
    try {
      final response = await _post(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages/$messageId/reactions'),
        headers: _getHeaders(),
        isIdempotent: true,
        body: jsonEncode({'emoji': emoji}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add reaction: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.addMessageReaction failed: $e');
      rethrow;
    }
  }

  /// Remove a reaction from a message
  /// DELETE /api/conversations/:conversationId/messages/:messageId/reactions
  Future<void> removeMessageReaction(String conversationId, String messageId, String emoji) async {
    try {
      final response = await _delete(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages/$messageId/reactions'),
        headers: _getHeaders(),
        body: jsonEncode({'emoji': emoji}),
        isIdempotent: true,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove reaction: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.removeMessageReaction failed: $e');
      rethrow;
    }
  }
}

// Helper functions for model conversions
ArtMarker _artMarkerFromBackendJson(Map<String, dynamic> json) {
  String? stringVal(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  final mergedMeta = _mergeMarkerMetadata(json);
  final subjectType = stringVal(
    json['subjectType'] ??
        json['subject_type'] ??
        mergedMeta?['subjectType'] ??
        mergedMeta?['subject_type'],
  )?.toLowerCase();
  final subjectId = stringVal(
    json['subjectId'] ??
        json['subject_id'] ??
        mergedMeta?['subjectId'] ??
        mergedMeta?['subject_id'],
  );
  final markerType = stringVal(
    json['markerType'] ??
        json['type'] ??
        json['category'] ??
        mergedMeta?['markerType'] ??
        mergedMeta?['type'],
  )?.toLowerCase();

  // Expand artwork ID resolution beyond bare `artworkId` to include common metadata fallbacks.
  String? artworkId = stringVal(json['artworkId'] ?? json['artwork_id']);
  if (artworkId == null || artworkId.isEmpty) {
    final metaArtwork = mergedMeta ?? {};
    artworkId = stringVal(metaArtwork['linkedArtworkId'] ??
        metaArtwork['linked_artwork_id'] ??
        metaArtwork['artworkId'] ??
        metaArtwork['artwork_id']);
  }
  final allowSubjectIdAsArtworkId = subjectId != null &&
      subjectId.isNotEmpty &&
      ((subjectType != null && subjectType.contains('artwork')) ||
          ((subjectType == null || subjectType.isEmpty) &&
              (markerType != null && markerType.contains('artwork'))));
  if ((artworkId == null || artworkId.isEmpty) && allowSubjectIdAsArtworkId) {
    artworkId = subjectId;
  }
  if ((artworkId == null || artworkId.isEmpty) && json['artwork'] is Map<String, dynamic>) {
    artworkId = stringVal((json['artwork'] as Map<String, dynamic>)['id']);
  }

  final normalized = <String, dynamic>{
    'id': json['id'] ?? json['_id'] ?? '',
    'name': json['name'] ?? json['title'] ?? json['label'] ?? '',
    'description': json['description'] ?? json['summary'] ?? '',
    'latitude': (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
    'longitude': (json['longitude'] ?? json['lng'] ?? 0).toDouble(),
    'artworkId': artworkId,
    'modelCID': json['modelCID'] ?? json['model_cid'],
    'modelURL': json['modelURL'] ?? json['model_url'],
    'storageProvider': json['storageProvider'] ?? json['storage_provider'] ?? 'hybrid',
    'scale': (json['scale'] ?? 1.0).toDouble(),
    'rotation': json['rotation'],
    'enableAnimation': json['enableAnimation'] ?? json['animate'] ?? false,
    'animationName': json['animationName'] ?? json['animation_name'],
    'enablePhysics': json['enablePhysics'] ?? false,
    'enableInteraction': json['enableInteraction'] ?? true,
    'metadata': mergedMeta,
    'tags': json['tags'],
    'category': json['category'] ?? json['markerType'] ?? json['type'] ?? 'General',
    'createdAt': json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String(),
    'updatedAt': json['updatedAt'] ?? json['updated_at'],
    'createdBy': json['createdBy'] ?? json['created_by'] ?? 'system',
    'viewCount': json['viewCount'] ?? json['views'] ?? 0,
    'interactionCount': json['interactionCount'] ?? json['interactions'] ?? 0,
    'activationRadius': json['activationRadius'] ?? json['activation_radius'] ?? 50.0,
    'requiresProximity': json['requiresProximity'] ?? json['requires_proximity'] ?? true,
    'isPublic': json['isPublic'] ?? json['is_public'] ?? true,
    'isActive': json['isActive'] ?? json['is_active'] ?? true,
    'markerType': json['markerType'] ?? json['type'],
  };

  return ArtMarker.fromMap(normalized);
}

Map<String, dynamic>? _mergeMarkerMetadata(Map<String, dynamic> json) {
  Map<String, dynamic>? metadata;

  void merge(dynamic source) {
    if (source is Map<String, dynamic>) {
      metadata ??= <String, dynamic>{};
      metadata!.addAll(source);
    } else if (source is Map) {
      metadata ??= <String, dynamic>{};
      metadata!.addAll(Map<String, dynamic>.from(source));
    }
  }

  merge(json['metadata']);
  merge(json['meta']);
  merge(json['marker_data'] ?? json['markerData']);

  final subjectType = json['subjectType'] ?? json['subject_type'];
  final subjectId = json['subjectId'] ?? json['subject_id'];
  final subjectTitle = json['subjectTitle'] ?? json['subject_title'];
  final subjectLabel = json['subjectLabel'] ?? json['subject_label'];
  final subjectCategory = json['subjectCategory'] ?? json['subject_category'];
  if (subjectType != null &&
      (metadata?['subjectType'] ?? metadata?['subject_type']) == null) {
    merge({'subjectType': subjectType});
  }
  if (subjectId != null &&
      (metadata?['subjectId'] ?? metadata?['subject_id']) == null) {
    merge({'subjectId': subjectId});
  }
  if (subjectTitle != null &&
      (metadata?['subjectTitle'] ?? metadata?['subject_title']) == null) {
    merge({'subjectTitle': subjectTitle});
  }
  if (subjectLabel != null &&
      (metadata?['subjectLabel'] ?? metadata?['subject_label']) == null) {
    merge({'subjectLabel': subjectLabel});
  }
  if (subjectCategory != null &&
      (metadata?['subjectCategory'] ?? metadata?['subject_category']) == null) {
    merge({'subjectCategory': subjectCategory});
  }

  final artworkPreview = json['artwork'];
  if (artworkPreview is Map) {
    merge({'artwork': artworkPreview});
  }

  return metadata;
}

Artwork _artworkFromBackendJson(Map<String, dynamic> json) {
  String stringVal(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

  String? nullableString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  double? doubleVal(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  int? intVal(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  bool? boolVal(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['true', '1', 'yes', 'y', 'on'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n', 'off'].contains(normalized)) return false;
    }
    return null;
  }

  DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      // Assume milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  Map<String, double>? normalizeRotation(dynamic raw) {
    Map<String, double>? convert(Map source) {
      final result = <String, double>{};
      source.forEach((key, value) {
        final parsed = doubleVal(value);
        if (parsed != null) {
          result[key.toString()] = parsed;
        }
      });
      return result.isEmpty ? null : result;
    }

    if (raw is Map<String, dynamic>) {
      return convert(raw);
    }
    if (raw is Map) {
      return convert(raw.cast<dynamic, dynamic>().map((key, value) => MapEntry(key.toString(), value)));
    }
    return null;
  }

  Map<String, dynamic> extractMetadata() {
    final metadata = <String, dynamic>{};
    void addMeta(String key, dynamic value) {
      if (value == null) return;
      metadata[key] = value;
    }

    if (json['metadata'] is Map<String, dynamic>) {
      metadata.addAll(json['metadata'] as Map<String, dynamic>);
    }

    addMeta('walletAddress', json['walletAddress'] ?? json['wallet_address']);
    addMeta('creatorId', json['creatorId'] ?? json['creator_id']);
    addMeta('creators', json['creators'] ?? json['artists'] ?? json['collaborators'] ?? json['contributors']);
    addMeta(
      'creatorWallets',
      json['creatorWallets'] ?? json['creatorWalletAddresses'] ?? json['walletAddresses'] ?? json['wallets'],
    );
    addMeta('locationName', json['locationName']);
    addMeta('nft', json['nft']);
    addMeta('price', json['price']);
    addMeta('currency', json['currency']);
    addMeta('isForSale', json['isForSale']);
    addMeta('imageCID', json['imageCID'] ?? json['image_cid']);

    return metadata;
  }

  String? pickString(List<dynamic> candidates) {
    for (final candidate in candidates) {
      final value = nullableString(candidate);
      if (value != null) return value;
    }
    return null;
  }

  final stats = json['stats'] as Map<String, dynamic>?;
  final locationJson = json['location'] as Map<String, dynamic>?;

  final id = stringVal(json['id'] ?? json['_id'] ?? '');
  final title = stringVal(json['title'] ?? json['name'] ?? '');
  final artist = stringVal(
    json['artist'] ??
    json['artistName'] ??
    json['artist_name'] ??
    json['walletAddress'] ??
    json['wallet_address'] ??
    'Unknown Artist',
  );

  final rawImage = pickString([
    json['imageUrl'],
    json['imageURL'],
    json['image_url'],
    json['coverUrl'],
    json['coverURL'],
    json['cover_url'],
    json['coverImage'],
    json['cover_image'],
    json['coverImageUrl'],
    json['cover_image_url'],
    json['mediaUrl'],
    json['media_url'],
  ]);

  final arAsset = (json['arAsset'] ?? json['ar_asset']) as Map<String, dynamic>?;
  final rawModelUrl = pickString([
    json['model3DURL'],
    json['model3dURL'],
    json['model3dUrl'],
    json['model_url'],
    json['modelURL'],
    json['model_3d_url'],
    arAsset?['url'],
    arAsset?['modelUrl'],
  ]);
  final modelUrl = MediaUrlResolver.resolve(rawModelUrl);
  final modelCid = pickString([
    json['model3DCID'],
    json['model3dCID'],
    json['model3dCid'],
    json['model_cid'],
    json['model_3d_cid'],
    arAsset?['cid'],
  ]);

  final latCandidate = doubleVal(json['latitude'] ?? json['lat']);
  final lngCandidate = doubleVal(json['longitude'] ?? json['lng']);
  final locationLat = locationJson != null
      ? doubleVal(locationJson['lat'] ?? locationJson['latitude'])
      : null;
  final locationLng = locationJson != null
      ? doubleVal(locationJson['lng'] ?? locationJson['longitude'])
      : null;
  final hasLocation =
      (latCandidate != null && lngCandidate != null) || (locationLat != null && locationLng != null);
  double lat = latCandidate ?? locationLat ?? 0.0;
  double lng = lngCandidate ?? locationLng ?? 0.0;

  final likesCount = intVal(json['likesCount']) ??
      intVal(json['likes']) ??
      intVal(json['likes_count']) ??
      intVal(stats?['likes']) ??
      intVal(stats?['likesCount']) ??
      0;

  final commentsCount = intVal(json['commentsCount']) ??
      intVal(json['comments']) ??
      intVal(json['comments_count']) ??
      intVal(stats?['comments']) ??
      intVal(stats?['commentsCount']) ??
      0;

  final viewsCount = intVal(json['viewsCount']) ??
      intVal(json['viewCount']) ??
      intVal(json['views']) ??
      intVal(stats?['views']) ??
      intVal(stats?['viewCount']) ??
      0;

  final discoveryCount = intVal(json['discoveryCount']) ??
      intVal(json['discoveries']) ??
      intVal(stats?['discoveries']) ??
      0;

  final resolvedTags = () {
    final rawTags = json['tags'];
    if (rawTags is List) {
      return rawTags.map((e) => e.toString()).toList();
    }
    if (rawTags is String && rawTags.isNotEmpty) {
      return rawTags
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }
    return <String>[];
  }();

  final metadata = extractMetadata();
  metadata['hasLocation'] = hasLocation;
  final imageCid = pickString([
    json['imageCID'],
    json['image_cid'],
    metadata['imageCID'],
    metadata['image_cid'],
    json['cid'],
  ]);
  final normalizedImageUrl = MediaUrlResolver.resolve(rawImage) ?? StorageConfig.resolveUrl(imageCid);
  final arScale = doubleVal(json['arScale'] ?? json['ar_scale'] ?? arAsset?['scale']);
  final arRotation = normalizeRotation(
    json['arRotation'] ??
        json['ar_rotation'] ??
        json['rotation'] ??
        arAsset?['rotation'],
  );

  final markerIdCandidate = nullableString(
    json['arMarkerId'] ?? json['markerId'] ?? json['marker_id'],
  );

  final walletAddress = nullableString(json['walletAddress'] ?? json['wallet_address']);
  final isPublic = boolVal(json['isPublic'] ?? json['is_public']) ?? true;
  final isActive = boolVal(json['isActive'] ?? json['is_active']) ?? true;
  final isForSale = boolVal(json['isForSale'] ?? json['is_for_sale']) ?? false;
  final price = doubleVal(json['price']);
  final currency = nullableString(json['currency']);
  final createdAt =
      parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now();
  final updatedAt = parseDate(json['updatedAt'] ?? json['updated_at']);

  return Artwork(
    id: id,
    walletAddress: walletAddress,
    title: title,
    artist: artist,
    description: stringVal(json['description'] ?? json['summary'] ?? '', ''),
    imageUrl: normalizedImageUrl,
    position: LatLng(lat, lng),
    rewards: json['rewards'] as int? ?? intVal(json['reward']) ?? 10,
    category: stringVal(json['category'] ?? json['collection'], 'General'),
    model3DURL: modelUrl,
    model3DCID: modelCid,
    arEnabled: boolVal(json['arEnabled']) ??
        boolVal(json['isAREnabled']) ??
        boolVal(json['isArEnabled']) ??
        boolVal(json['is_ar_enabled']) ??
        (arAsset != null),
    arMarkerId: markerIdCandidate,
    arScale: arScale,
    arRotation: arRotation,
    arEnableAnimation: boolVal(
      json['arEnableAnimation'] ??
          json['enableAnimation'] ??
          json['animationEnabled'] ??
          arAsset?['enableAnimation'],
    ),
    arAnimationName: nullableString(
      json['arAnimationName'] ??
          json['animationName'] ??
          arAsset?['animation'],
    ),
    isPublic: isPublic,
    isActive: isActive,
    isForSale: isForSale,
    price: price,
    currency: currency,
    createdAt: createdAt,
    updatedAt: updatedAt,
    discoveredAt: parseDate(json['discoveredAt']),
    discoveryUserId: nullableString(json['discoveryUserId']),
    tags: resolvedTags,
    likesCount: likesCount,
    commentsCount: commentsCount,
    viewsCount: viewsCount,
    discoveryCount: discoveryCount,
    isLikedByCurrentUser: boolVal(json['isLikedByCurrentUser'] ?? json['isLiked']) ?? false,
    isFavoriteByCurrentUser:
        boolVal(json['isFavoriteByCurrentUser'] ?? json['isFavorited']) ?? false,
    metadata: metadata.isEmpty ? null : metadata,
  );
}



CommunityLikeUser _communityLikeUserFromBackendJson(Map<String, dynamic> json) {
  final wallet = json['walletAddress'] as String? ?? json['wallet_address'] as String?;

  final username = json['username'] as String?;
  final displayName = json['displayName'] as String?
      ?? json['display_name'] as String?
      ?? username
      ?? (wallet != null && wallet.length >= 8 ? wallet.substring(0, 8) : 'User');
  final avatarCandidate = json['avatar'] as String?
      ?? json['avatarUrl'] as String?
      ?? json['avatar_url'] as String?;

  DateTime? likedAt;
  final likedAtRaw = json['likedAt'] ?? json['liked_at'];
  if (likedAtRaw is String) {
    likedAt = DateTime.tryParse(likedAtRaw);
  }

  return CommunityLikeUser(
    userId: (json['userId'] ?? json['user_id'] ?? json['id'] ?? 'unknown').toString(),
    walletAddress: wallet,
    displayName: displayName,
    username: username,
    avatarUrl: MediaUrlResolver.resolve(avatarCandidate),
    likedAt: likedAt,
  );
}


Map<String, dynamic> _buildCommunityPostPayload({
  required String content,
  String category = 'post',
  List<String>? mediaUrls,
  List<String>? mediaCids,
  String? artworkId,
  String? subjectType,
  String? subjectId,
  String? postType,
  List<String>? tags,
  List<String>? mentions,
  CommunityLocation? location,
  String? locationName,
  double? locationLat,
  double? locationLng,
}) {
  final payload = <String, dynamic>{
    'content': content,
    'category': category,
    if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
    if (mediaCids != null && mediaCids.isNotEmpty) 'mediaCids': mediaCids,
    if (artworkId != null) 'artworkId': artworkId,
    if (subjectType != null && subjectType.trim().isNotEmpty) 'subjectType': subjectType.trim(),
    if (subjectId != null && subjectId.trim().isNotEmpty) 'subjectId': subjectId.trim(),
    if (postType != null) 'postType': postType,
    if (tags != null && tags.isNotEmpty) 'tags': tags,
    if (mentions != null && mentions.isNotEmpty) 'mentions': mentions,
  };

  final hasLocationData = location != null ||
      locationLat != null ||
      locationLng != null ||
      (locationName != null && locationName.isNotEmpty);

  if (hasLocationData) {
    final effectiveLocation = location ??
        CommunityLocation(
          name: locationName,
          lat: locationLat,
          lng: locationLng,
        );

    final locPayload = <String, dynamic>{
      if (effectiveLocation.name != null && effectiveLocation.name!.isNotEmpty)
        'name': effectiveLocation.name,
      if (effectiveLocation.lat != null) 'lat': effectiveLocation.lat,
      if (effectiveLocation.lng != null) 'lng': effectiveLocation.lng,
    };
    if (locPayload.isNotEmpty) {
      payload['location'] = locPayload;
    }

    final resolvedName = (locationName != null && locationName.isNotEmpty)
        ? locationName
        : effectiveLocation.name;
    if (resolvedName != null && resolvedName.isNotEmpty) {
      payload['locationName'] = resolvedName;
    }
    final resolvedLat = locationLat ?? effectiveLocation.lat;
    if (resolvedLat != null) {
      payload['locationLat'] = resolvedLat;
    }
    final resolvedLng = locationLng ?? effectiveLocation.lng;
    if (resolvedLng != null) {
      payload['locationLng'] = resolvedLng;
    }
  }

  return payload;
}
CommunityPost _communityPostFromBackendJson(Map<String, dynamic> json) {
  // Extract nested author object if present - can be a map or a string (wallet address)
  final authorRaw = json['author'];
  final author = authorRaw is Map<String, dynamic> ? authorRaw : null;
  final normalizedAuthor = author ?? <String, dynamic>{};
  // Extract nested stats object if present
  final stats = json['stats'] as Map<String, dynamic>?;
  final authorDisplayName = author?['displayName'] as String? ?? author?['display_name'] as String? ?? json['displayName'] as String?;
  final rawUsername = author?['username'] as String? ?? json['authorUsername'] as String? ?? json['username'] as String?;
  final resolvedAuthorName = (authorDisplayName != null && authorDisplayName.trim().isNotEmpty)
      ? authorDisplayName.trim()
      : ((rawUsername != null && rawUsername.trim().isNotEmpty) ? rawUsername.trim() : (json['authorName'] as String?) ?? 'Anonymous');
  final avatarCandidate = author?['avatar'] as String?
      ?? author?['profileImage'] as String?
      ?? json['authorAvatar'] as String?;
  
  // Determine author wallet (if available separately from authorId)
  final authorWalletCandidate = normalizedAuthor['walletAddress'] as String?
      ?? normalizedAuthor['wallet_address'] as String?
      ?? normalizedAuthor['wallet'] as String?
      ?? json['walletAddress'] as String?
      ?? json['wallet'] as String?
      ?? (authorRaw is String ? authorRaw : null);

  bool authorIsArtistFlag = communityBool(
    normalizedAuthor['isArtist'] ??
        normalizedAuthor['is_artist'] ??
        json['authorIsArtist'] ??
        json['author_is_artist'],
  );
  bool authorIsInstitutionFlag = communityBool(
    normalizedAuthor['isInstitution'] ??
        normalizedAuthor['is_institution'] ??
        json['authorIsInstitution'] ??
        json['author_is_institution'],
  );
  final roleHint = (normalizedAuthor['role'] ??
          normalizedAuthor['type'] ??
          json['authorRole'] ?? '')
      .toString()
      .toLowerCase();
  if (roleHint.contains('institution') ||
      roleHint.contains('museum') ||
      roleHint.contains('gallery')) {
    authorIsInstitutionFlag = true;
  }
  if (roleHint.contains('artist') || roleHint.contains('creator')) {
    authorIsArtistFlag = true;
  }

  final dynamic mediaPayload = json['mediaUrls'] ?? json['media_urls'];
  final List<String> mediaUrls = mediaPayload is List
      ? mediaPayload
          .map((entry) => entry?.toString())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toList()
      : <String>[];

  final mentionsPayload = json['mentions'] ?? json['mentionHandles'];
  final List<String> mentions = mentionsPayload is List
      ? mentionsPayload.map((entry) => entry?.toString()).whereType<String>().toList()
      : <String>[];

  final String resolvedCategory = (json['category'] as String?)?.toLowerCase() ?? 'post';

  CommunityLocation? locationMeta;
  final locationJson = json['location'];
  if (locationJson is Map<String, dynamic>) {
    final latCandidate = locationJson['lat'] ?? locationJson['latitude'];
    final lngCandidate = locationJson['lng'] ?? locationJson['longitude'];
    if (locationJson['name'] != null || latCandidate != null || lngCandidate != null) {
      locationMeta = CommunityLocation(
        name: locationJson['name']?.toString(),
        lat: (latCandidate is num) ? latCandidate.toDouble() : double.tryParse(latCandidate?.toString() ?? ''),
        lng: (lngCandidate is num) ? lngCandidate.toDouble() : double.tryParse(lngCandidate?.toString() ?? ''),
      );
    }
  } else if (json['locationName'] != null || json['location_name'] != null || json['location_lat'] != null || json['locationLng'] != null) {
    final latCandidate = json['locationLat'] ?? json['location_lat'];
    final lngCandidate = json['locationLng'] ?? json['location_lng'];
    locationMeta = CommunityLocation(
      name: (json['locationName'] ?? json['location_name'])?.toString(),
      lat: (latCandidate is num) ? latCandidate.toDouble() : double.tryParse(latCandidate?.toString() ?? ''),
      lng: (lngCandidate is num) ? lngCandidate.toDouble() : double.tryParse(lngCandidate?.toString() ?? ''),
    );
  }

  CommunityGroupReference? groupRef;
  final groupJson = json['group'];
  if (groupJson is Map<String, dynamic>) {
    final groupId = (groupJson['id'] ?? groupJson['groupId'] ?? groupJson['group_id'])?.toString();
    if (groupId != null && groupId.isNotEmpty) {
      final groupName = (groupJson['name'] ?? groupJson['groupName'])?.toString() ?? 'Community Group';
      groupRef = CommunityGroupReference(
        id: groupId,
        name: groupName,
        slug: groupJson['slug']?.toString(),
        coverImage: groupJson['coverImage']?.toString() ?? groupJson['cover_image']?.toString(),
        description: groupJson['description']?.toString(),
      );
    }
  } else {
    final fallbackGroupId = (json['groupId'] ?? json['group_id'])?.toString();
    if (fallbackGroupId != null && fallbackGroupId.isNotEmpty) {
      groupRef = CommunityGroupReference(
        id: fallbackGroupId,
        name: (json['groupName'] ?? json['group_name'] ?? 'Community Group').toString(),
        slug: json['groupSlug']?.toString() ?? json['group_slug']?.toString(),
        coverImage: json['groupCover']?.toString() ?? json['group_cover']?.toString(),
        description: json['groupDescription']?.toString() ?? json['group_description']?.toString(),
      );
    }
  }

  CommunityArtworkReference? artworkRef;
  final artworkJson = json['artwork'];
  if (artworkJson is Map<String, dynamic>) {
    final artworkId =
        (artworkJson['id'] ?? artworkJson['artworkId'] ?? artworkJson['artwork_id'])
            ?.toString();
    if (artworkId != null && artworkId.isNotEmpty) {
      final artworkImage = artworkJson['imageUrl']?.toString() ??
          artworkJson['image_url']?.toString() ??
          artworkJson['artworkImage']?.toString() ??
          artworkJson['artwork_image']?.toString() ??
          artworkJson['artworkImageUrl']?.toString() ??
          artworkJson['artwork_image_url']?.toString();
      final artworkTitle = (artworkJson['title'] ??
              artworkJson['artworkTitle'] ??
              artworkJson['artwork_title'] ??
              'Artwork')
          .toString();
      artworkRef = CommunityArtworkReference(
        id: artworkId,
        title: artworkTitle,
        imageUrl: artworkImage,
      );
    }
  } else {
    final fallbackArtworkId =
        (json['artworkId'] ?? json['artwork_id'])?.toString();
    if (fallbackArtworkId != null && fallbackArtworkId.isNotEmpty) {
      artworkRef = CommunityArtworkReference(
        id: fallbackArtworkId,
        title:
            (json['artworkTitle'] ?? json['artwork_title'] ?? 'Artwork').toString(),
        imageUrl: json['artworkImage']?.toString() ??
            json['artwork_image']?.toString() ??
            json['artworkImageUrl']?.toString() ??
            json['artwork_image_url']?.toString(),
      );
    }
  }

  final rawSubjectType =
      (json['subjectType'] ?? json['subject_type'])?.toString();
  final rawSubjectId =
      (json['subjectId'] ?? json['subject_id'])?.toString();
  String? resolvedSubjectType = rawSubjectType?.trim();
  String? resolvedSubjectId = rawSubjectId?.trim();
  if ((resolvedSubjectType == null || resolvedSubjectType.isEmpty) &&
      artworkRef != null) {
    resolvedSubjectType = 'artwork';
    resolvedSubjectId = artworkRef.id;
  } else if ((resolvedSubjectType ?? '').toLowerCase().contains('artwork') &&
      (resolvedSubjectId == null || resolvedSubjectId.isEmpty)) {
    final fallbackArtworkId =
        (json['artworkId'] ?? json['artwork_id'])?.toString();
    resolvedSubjectId = fallbackArtworkId?.trim().isNotEmpty == true
        ? fallbackArtworkId?.trim()
        : artworkRef?.id;
  }

  // Parse original post for reposts
  CommunityPost? originalPost;
  final originalPostPayload =
      json['originalPost'] ?? json['original_post'];
  if (originalPostPayload is Map) {
    final nested = Map<String, dynamic>.from(originalPostPayload);
    nested.remove('originalPost');
    nested.remove('original_post');
    try {
      originalPost = _communityPostFromBackendJson(nested);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService: Failed to parse nested original post: $e');
    }
  }

  final postTypeValue =
      (json['postType'] ?? json['post_type'] ?? json['type'])?.toString();
  final originalPostId =
      (json['originalPostId'] ?? json['original_post_id'])?.toString();

  return CommunityPost(
    id: json['id'] as String,
    authorId: json['authorId'] as String? ?? json['walletAddress'] as String? ?? json['userId'] as String? ?? 'unknown',
    authorWallet: authorWalletCandidate,
    authorName: resolvedAuthorName,
    authorAvatar: MediaUrlResolver.resolve(avatarCandidate),
    authorUsername: rawUsername,
    content: json['content'] as String,
    imageUrl: json['imageUrl'] as String? ?? (mediaUrls.isNotEmpty ? mediaUrls.first : null),
    mediaUrls: mediaUrls,
    timestamp: json['createdAt'] != null 
      ? DateTime.parse(json['createdAt'] as String)
      : (json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now()),
    tags: json['tags'] != null 
      ? (json['tags'] as List<dynamic>).map((e) => e.toString()).toList()
      : [],
    mentions: mentions,
    category: resolvedCategory,
    location: locationMeta,
    group: groupRef,
    groupId: (json['groupId'] as String?) ?? (json['group_id'] as String?) ?? groupRef?.id,
    artwork: artworkRef,
    subjectType: resolvedSubjectType,
    subjectId: resolvedSubjectId,
    distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? (json['distance_km'] as num?)?.toDouble(),
    postType: postTypeValue,
    originalPostId: originalPostId,
    originalPost: originalPost,
    likeCount: stats?['likes'] as int? ?? json['likes'] as int? ?? json['likeCount'] as int? ?? 0,
    shareCount: stats?['shares'] as int? ?? json['shares'] as int? ?? json['shareCount'] as int? ?? 0,
    commentCount: stats?['comments'] as int? ?? json['comments'] as int? ?? json['commentCount'] as int? ?? 0,
    viewCount: stats?['views'] as int? ?? json['views'] as int? ?? json['viewCount'] as int? ?? 0,
    isLiked: json['isLiked'] as bool? ?? false,
    isBookmarked: json['isBookmarked'] as bool? ?? false,
    isFollowing: json['isFollowing'] as bool? ?? false,
    authorIsArtist: authorIsArtistFlag,
    authorIsInstitution: authorIsInstitutionFlag,
  );
}

GroupPostPreview? _groupPostPreviewFromJson(dynamic raw) {
  if (raw is! Map<String, dynamic>) {
    return null;
  }
  final id = (raw['id'] ?? raw['postId'] ?? raw['post_id'])?.toString();
  if (id == null || id.isEmpty) {
    return null;
  }
  DateTime? createdAt;
  final createdAtRaw = raw['createdAt'] ?? raw['created_at'];
  if (createdAtRaw is String) {
    createdAt = DateTime.tryParse(createdAtRaw);
  }
  return GroupPostPreview(
    id: id,
    content: raw['content']?.toString(),
    createdAt: createdAt,
  );
}

CommunityGroupSummary _communityGroupSummaryFromJson(Map<String, dynamic> json) {
  final id = (json['id'] ?? json['groupId'] ?? json['group_id'])?.toString();
  if (id == null || id.isEmpty) {
    throw Exception('Invalid group payload: missing id');
  }
  GroupPostPreview? latestPost;
  if (json['latestPost'] is Map<String, dynamic>) {
    latestPost = _groupPostPreviewFromJson(json['latestPost']);
  } else if (json['latest_post_id'] != null) {
    latestPost = _groupPostPreviewFromJson({
      'id': json['latest_post_id'],
      'content': json['latest_post_content'],
      'createdAt': json['latest_post_created_at'],
    });
  }

  return CommunityGroupSummary(
    id: id,
    name: (json['name'] ?? 'Community Group').toString(),
    slug: json['slug']?.toString(),
    description: json['description']?.toString(),
    coverImage: MediaUrlResolver.resolve(
      json['coverImage']?.toString() ?? json['cover_image']?.toString(),
    ),
    isPublic: json['isPublic'] as bool? ?? json['is_public'] as bool? ?? true,
    ownerWallet: (json['ownerWallet'] ?? json['owner_wallet'] ?? '').toString(),
    memberCount: (json['memberCount'] as num?)?.toInt() ??
        (json['member_count'] as num?)?.toInt() ??
        (json['member_count_cached'] as num?)?.toInt() ??
        0,
    isMember: json['isMember'] as bool? ?? json['is_member'] as bool? ?? false,
    isOwner: json['isOwner'] as bool? ?? json['is_owner'] as bool? ?? false,
    latestPost: latestPost,
  );
}

Comment _commentFromBackendJson(Map<String, dynamic> json) {
  // Normalize any nested author object - can be a map or a string (wallet address)
  final authorRaw = json['author'];
  final author = authorRaw is Map<String, dynamic> ? authorRaw : null;
  final normalizedAuthor = author ?? <String, dynamic>{};

  // Try common wallet field names in the author object
  final authorWallet = normalizedAuthor['walletAddress'] as String?
      ?? normalizedAuthor['wallet_address'] as String?
      ?? normalizedAuthor['wallet'] as String?;
  // Fallback when the author is a raw string (like a wallet address)
  String? authorRawWalletFallback;
  if (authorRaw is String && authorRaw.isNotEmpty) authorRawWalletFallback = authorRaw;
  final rootAuthorWallet = json['authorWallet'] as String? ?? json['author_wallet'] as String? ?? json['createdByWallet'] as String? ?? json['created_by_wallet'] as String?;
  final resolvedAuthorWallet = authorWallet ?? rootAuthorWallet ?? authorRawWalletFallback;

  // Expand the fallback set for author id similar to community posts
    final authorId = json['authorId'] as String?
      ?? json['author_id']?.toString()
      ?? normalizedAuthor['id'] as String?
      ?? normalizedAuthor['walletAddress'] as String?
      ?? json['walletAddress'] as String?
      ?? json['wallet_address'] as String?
      ?? json['wallet'] as String?
      ?? json['userId'] as String?
      ?? json['user_id']?.toString()
      ?? resolvedAuthorWallet
      ?? 'unknown';

  // Display name and username fallbacks
  final authorDisplayName = normalizedAuthor['displayName'] as String?
      ?? normalizedAuthor['display_name'] as String?
      ?? json['displayName'] as String?
      ?? json['authorDisplayName'] as String?;
  final rootAuthorDisplayName = json['userDisplayName'] as String? ?? json['display_name'] as String? ?? json['author_name'] as String?;

  final rawUsername = normalizedAuthor['username'] as String?
      ?? json['authorUsername'] as String?
      ?? json['authorName'] as String?
      ?? json['username'] as String?;

    final authorName = (authorDisplayName != null && authorDisplayName.trim().isNotEmpty)
      ? authorDisplayName.trim()
      : ((rawUsername != null && rawUsername.trim().isNotEmpty) ? rawUsername.trim() : (json['authorName'] as String?) ?? 'Anonymous');
    final resolvedAuthorName = (authorName != 'Anonymous' && authorName.trim().isNotEmpty) ? authorName : (rootAuthorDisplayName?.trim() ?? authorName);

  // Avatar candidate: check common fields used by the backend
    final avatarCandidate = normalizedAuthor['avatar'] as String?
      ?? normalizedAuthor['avatarUrl'] as String?
      ?? normalizedAuthor['avatar_url'] as String?
      ?? normalizedAuthor['profile_image'] as String?
      ?? normalizedAuthor['profileImage'] as String?
      ?? json['authorAvatar'] as String?
      ?? json['avatar'] as String?;

  final authorUsername = json['authorUsername'] as String?
      ?? normalizedAuthor['username'] as String?
      ?? rawUsername;

  final originalContent = (json['originalText'] ?? json['original_content'] ?? json['originalContent'])?.toString();
  DateTime? editedAt;
  final editedRaw = json['editedAt'] ?? json['edited_at'] ?? json['editedAtUtc'];
  if (editedRaw != null) {
    try {
      editedAt = DateTime.parse(editedRaw.toString());
    } catch (_) {
      editedAt = null;
    }
  }

  return Comment(
  id: (json['id'] ?? '').toString(),
  authorId: authorId,
  authorName: resolvedAuthorName,
  authorAvatar: MediaUrlResolver.resolve(avatarCandidate),
  authorUsername: authorUsername,
  authorWallet: resolvedAuthorWallet ?? authorId,
  parentCommentId: json['parentCommentId'] as String? ?? json['parent_comment_id']?.toString(),
  originalContent: (originalContent != null && originalContent.trim().isNotEmpty) ? originalContent : null,
  editedAt: editedAt,
  content: json['content'] as String,
    timestamp: json['createdAt'] != null 
      ? DateTime.parse(json['createdAt'] as String)
      : (json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now()),
    likeCount: json['likes'] as int? ?? json['likeCount'] as int? ?? json['likesCount'] as int? ?? 0,
    isLiked: json['isLiked'] as bool? ?? false,
    replies: <Comment>[],
  );
}

List<Comment> _nestComments(List<Comment> comments) {
  if (comments.isEmpty) return <Comment>[];
  final Map<String, Comment> byId = {
    for (final comment in comments) comment.id: comment,
  };
  final List<Comment> roots = [];

  for (final comment in comments) {
    final parentId = comment.parentCommentId;
    if (parentId == null || parentId.isEmpty) {
      roots.add(comment);
      continue;
    }
    final parent = byId[parentId];
    if (parent == null) {
      roots.add(comment);
      continue;
    }
    parent.replies = [...parent.replies, comment];
  }

  return roots;
}
