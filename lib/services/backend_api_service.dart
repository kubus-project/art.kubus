import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/art_marker.dart';
import '../models/promotion.dart';
import '../models/artwork.dart';
import '../models/artwork_comment.dart';
import '../models/community_group.dart';
import '../models/event.dart';
import '../models/exhibition.dart';
import '../models/attestation.dart';
import '../models/collab_member.dart';
import '../models/collab_invite.dart';
import '../models/street_art_claim.dart';
import '../community/community_interactions.dart';
import '../utils/wallet_utils.dart';
import '../utils/search_suggestions.dart';
import '../utils/media_url_resolver.dart';
import 'share/share_types.dart';
import '../config/config.dart';
import 'encrypted_wallet_backup_service.dart';
import 'public_action_outbox_service.dart';
import 'public_fallback_service.dart';
import 'storage_config.dart';
import 'user_action_logger.dart';
import 'auth_gating_service.dart';
import 'auth_session_coordinator.dart';
import 'http_client_factory.dart';
import 'media_upload_optimizer.dart';
import 'telemetry/kubus_client_context.dart';

part 'backend_api_service_auth_helpers.dart';
part 'backend_api_service_auth_account_helpers.dart';
part 'backend_api_service_auth_transport.dart';
part 'backend_api_service_domain_transports.dart';
part 'backend_api_service_recovery_transport.dart';
part 'backend_api_service_public_object_transport.dart';
part 'backend_api_service_signed_action_transport.dart';
part 'backend_api_service_dao_transport.dart';
part 'backend_api_service_wallet_settlement_transport.dart';
part 'backend_api_service_collectibles_attestations_transport.dart';
part 'backend_api_service_messages.dart';
part 'backend_api_service_profile_helpers.dart';
part 'backend_api_service_parsers.dart';
part 'backend_api_service_upload_helpers.dart';

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
    if (trimmedBody.isEmpty) {
      return 'BackendApiRequestException($statusCode $path)';
    }
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
  Future<Artwork?> updateArtwork(
      String artworkId, Map<String, dynamic> updates);
  Future<Artwork?> publishArtwork(String artworkId);
  Future<Artwork?> unpublishArtwork(String artworkId);
  Future<int?> likeArtwork(String artworkId);
  Future<int?> unlikeArtwork(String artworkId);
  Future<int?> discoverArtworkWithCount(String artworkId);
  Future<void> bookmarkArtwork(String artworkId);
  Future<void> unbookmarkArtwork(String artworkId);
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

  Future<Map<String, dynamic>> updateProfile(
      String walletAddress, Map<String, dynamic> updates);

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
  Future<ArtMarker?> updateArtMarkerRecord(
      String markerId, Map<String, dynamic> updates);
  Future<bool> deleteArtMarkerRecord(String markerId);
  Future<StreetArtClaim> submitStreetArtClaim({
    required String markerId,
    required String reason,
    String? evidenceUrl,
    String? claimantProfileName,
  });
  Future<List<StreetArtClaim>> getStreetArtClaims(String markerId);
  Future<StreetArtClaim?> reviewStreetArtClaim({
    required String markerId,
    required String claimId,
    required StreetArtClaimReviewAction action,
    String? note,
  });
}

enum AuthSignInMethod {
  unknown,
  email,
  google,
  wallet,
}

String _authSignInMethodToStorageValue(AuthSignInMethod method) {
  switch (method) {
    case AuthSignInMethod.email:
      return 'email';
    case AuthSignInMethod.google:
      return 'google';
    case AuthSignInMethod.wallet:
      return 'wallet';
    case AuthSignInMethod.unknown:
      return '';
  }
}

AuthSignInMethod _authSignInMethodFromStorageValue(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'email':
      return AuthSignInMethod.email;
    case 'google':
      return AuthSignInMethod.google;
    case 'wallet':
      return AuthSignInMethod.wallet;
    default:
      return AuthSignInMethod.unknown;
  }
}

class BackendApiService
    implements ArtworkBackendApi, ProfileBackendApi, MarkerBackendApi {
  static final BackendApiService _instance = BackendApiService._internal();
  factory BackendApiService() => _instance;
  BackendApiService._internal() {
    // Ensure a single, consistent HTTP client across the app.
    // On Flutter Web, this enables credentialed requests (cookies) when needed.
    _client = createPlatformHttpClient();
  }

  http.Client _client = http.Client();
  AuthSessionCoordinator? _authCoordinator;
  MediaUploadOptimizer _mediaUploadOptimizer = const MediaUploadOptimizer();

  // Used only for diagnostic logging; the actual behavior is determined by the
  // platform client returned by [createPlatformHttpClient()].
  bool get _webCredentialsExpected => kIsWeb;

  @override
  final String baseUrl = AppConfig.baseApiUrl;
  final PublicFallbackService _publicFallbackService = PublicFallbackService();
  final PublicActionOutboxService _publicActionOutboxService =
      PublicActionOutboxService();
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

    // Prefer explicit wallet claims first.
    for (final key in const ['walletAddress', 'wallet_address', 'wallet']) {
      final raw = (payload[key] ?? '').toString();
      final canonical = WalletUtils.canonical(raw);
      if (canonical.isNotEmpty) return canonical;
    }

    // Backward compatibility: only use id/sub claims when value actually
    // looks like a wallet to avoid treating UUIDs as wallet addresses.
    for (final key in const ['user_id', 'id', 'sub']) {
      final raw = (payload[key] ?? '').toString();
      final canonical = WalletUtils.canonical(raw);
      if (canonical.isEmpty) continue;
      if (WalletUtils.looksLikeWallet(canonical)) {
        return canonical;
      }
    }
    return null;
  }

  AuthSignInMethod inferSignInMethodFromClaims([Map<String, dynamic>? claims]) {
    final resolvedClaims = claims ?? getCurrentAuthTokenClaims();
    if (resolvedClaims == null) return AuthSignInMethod.unknown;

    final provider = (resolvedClaims['authProvider'] ??
            resolvedClaims['auth_provider'] ??
            resolvedClaims['provider'] ??
            resolvedClaims['signInMethod'] ??
            resolvedClaims['signin_method'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (provider.contains('google')) {
      return AuthSignInMethod.google;
    }
    if (provider.contains('email') || provider.contains('password')) {
      return AuthSignInMethod.email;
    }
    if (provider.contains('wallet') || provider.contains('solana')) {
      return AuthSignInMethod.wallet;
    }

    final email = (resolvedClaims['email'] ??
            resolvedClaims['emailAddress'] ??
            resolvedClaims['email_address'] ??
            '')
        .toString()
        .trim();
    if (email.isNotEmpty) return AuthSignInMethod.email;

    final wallet = getCurrentAuthWalletAddress();
    if ((wallet ?? '').isNotEmpty) return AuthSignInMethod.wallet;

    return AuthSignInMethod.unknown;
  }

  Future<void> setLastSignInMethod(AuthSignInMethod method) async {
    final value = _authSignInMethodToStorageValue(method);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value.isEmpty) {
        await prefs.remove(PreferenceKeys.authLastSignInMethodV1);
      } else {
        await prefs.setString(PreferenceKeys.authLastSignInMethodV1, value);
      }
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.setLastSignInMethod failed: $e');
    }
  }

  Future<AuthSignInMethod> getLastSignInMethod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _authSignInMethodFromStorageValue(
        prefs.getString(PreferenceKeys.authLastSignInMethodV1),
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getLastSignInMethod failed: $e');
      return AuthSignInMethod.unknown;
    }
  }

  Future<AuthSignInMethod> resolveLastSignInMethod({
    bool inferFromToken = true,
  }) async {
    final stored = await getLastSignInMethod();
    if (stored != AuthSignInMethod.unknown || !inferFromToken) {
      return stored;
    }
    final inferred = inferSignInMethodFromClaims();
    if (inferred != AuthSignInMethod.unknown) {
      await setLastSignInMethod(inferred);
    }
    return inferred;
  }

  @visibleForTesting
  void setHttpClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  void setMediaUploadOptimizerForTesting(MediaUploadOptimizer optimizer) {
    _mediaUploadOptimizer = optimizer;
  }

  @visibleForTesting
  void setAuthTokenForTesting(String? token) {
    _authToken = token;
    _authWalletCanonical = _tryExtractWalletFromToken(token);
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

  bool get _hasInitializedBinding {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isExhibitionsPath(Uri uri) {
    final path = uri.path;
    return path.startsWith('/api/exhibitions') ||
        path.contains('/api/exhibitions/');
  }

  bool _isExhibitionsRootPath(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length < 2) return false;
    return segments[0] == 'api' &&
        segments[1] == 'exhibitions' &&
        segments.length == 2;
  }

  int? _tryParseRequestFailedStatus(Object error) {
    // _fetchJson throws Exception('Request failed: <code>')
    final message = error.toString();
    final match = RegExp(r'Request failed: (\d{3})').firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  String _rateLimitKey(String method, Uri uri) =>
      '${method.toUpperCase()} ${uri.path}';

  bool _isRateLimited(String key) {
    final resetAt = _rateLimitResets[key];
    if (resetAt == null) return false;
    if (resetAt.isBefore(DateTime.now())) {
      _rateLimitResets.remove(key);
      return false;
    }
    return true;
  }

  void _markRateLimited(String key, http.Response response,
      {int defaultWindowMs = 60000}) {
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
          final fromBody = parsed['windowMs'] ??
              parsed['window_ms'] ??
              parsed['retryAfterMs'] ??
              parsed['retry_after_ms'];
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
    if (remaining.isNegative) {
      return 'Rate limit exceeded. Please retry shortly.';
    }
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    final human = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    return 'Rate limit exceeded. Please retry in ~$human.';
  }

  /// Ensure an existing backend account session is loaded.
  ///
  /// This restores JWT state only. It does not create/register an account and
  /// never implies local or external signer restoration.
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
    // Run initialization (allowed to retry when token still missing).
    // Deliberately session-only: signer-backed login is handled by
    // ensureSessionForActiveSigner in the auth transport part.
    _authInitFuture = _doAuthInit(walletAddress);
    await _authInitFuture;
  }

  Future<void> _doAuthInit(String? walletAddress) async {
    try {
      await loadAuthToken();
    } finally {
      _authInitFuture = null;
    }
  }

  /// Ensure stored session state is loaded.
  ///
  /// This intentionally does not issue or register a token for a stored wallet.
  /// Wallet-root account bootstrap is explicit, and signer-backed login must
  /// go through the challenge/sign/login flow.
  Future<void> _ensureAuthWithStoredWallet() async {
    // If token already loaded, nothing to do
    if ((_authToken ?? '').isNotEmpty) return;
    // Try to load token from storage
    await loadAuthToken();
    if ((_authToken ?? '').isNotEmpty) return;
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
        (preferredCanonical.isEmpty ||
            requestedCanonical == preferredCanonical);
    final desiredCanonical = canHonorRequested
        ? requestedCanonical
        : (preferredCanonical.isNotEmpty
            ? preferredCanonical
            : requestedCanonical);

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
        // Clear the mismatched account token. Re-authentication must be
        // performed explicitly through wallet signature or linked auth.
        await clearAuth();
      }
    }

    if ((_authToken ?? '').isNotEmpty) return;
    await _ensureAuthWithStoredWallet();
    if ((_authToken ?? '').isNotEmpty) return;
    await ensureAuthLoaded(walletAddress: desiredCanonical);
  }

  /// Set authentication token for API requests
  Future<void> setAuthToken(String token) async {
    _authToken = token;
    _authWalletCanonical = _tryExtractWalletFromToken(token);
    AppConfig.debugPrint('BackendApiService: Auth token set (in-memory)');
    if (!_hasInitializedBinding) {
      AppConfig.debugPrint(
        'BackendApiService: skipping auth token persistence (binding not initialized)',
      );
      return;
    }
    // Persist token to secure storage and shared preferences (web fallback)
    try {
      await _secureStorage
          .write(key: 'jwt_token', value: token)
          .timeout(const Duration(milliseconds: 800));
      AppConfig.debugPrint(
          'BackendApiService: Auth token written to secure storage');
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService: failed to write secure storage token: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setBool(PreferenceKeys.hasCompletedAuthOnboarding, true);
      AppConfig.debugPrint(
          'BackendApiService: Auth token written to SharedPreferences fallback');
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService: failed to write prefs token: $e');
    }
  }

  Future<void> setRefreshToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    if (!_hasInitializedBinding) {
      AppConfig.debugPrint(
        'BackendApiService: skipping refresh token persistence (binding not initialized)',
      );
      return;
    }
    try {
      await _secureStorage
          .write(key: 'refresh_token', value: trimmed)
          .timeout(const Duration(milliseconds: 800));
      AppConfig.debugPrint(
          'BackendApiService: Refresh token written to secure storage');
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService: failed to write refresh token: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refresh_token', trimmed);
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService: failed to write refresh token to prefs: $e');
    }
  }

  Future<void> _loadRefreshTokenFromStorage() async {
    String? refreshToken;
    try {
      refreshToken = await _secureStorage
          .read(key: 'refresh_token')
          .timeout(const Duration(milliseconds: 800));
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService: refresh token secure storage read failed: $e');
    }

    if (refreshToken == null || refreshToken.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        refreshToken = AuthGatingService.readStoredRefreshToken(prefs);
      } catch (e) {
        AppConfig.debugPrint(
            'BackendApiService: refresh token prefs read failed: $e');
      }
    }

    if (refreshToken != null && refreshToken.trim().isNotEmpty) {}
  }

  Future<bool> refreshAuthTokenFromStorage() async {
    // The backend does not expose /api/auth/refresh. Keep this compatibility
    // shim non-transport so older call sites cannot accidentally depend on a
    // missing route or infer signer restoration from stored session state.
    await _loadRefreshTokenFromStorage();
    AppConfig.debugPrint(
      'BackendApiService.refreshAuthTokenFromStorage: refresh transport is not configured',
    );
    return false;
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
        AppConfig.debugPrint(
            'BackendApiService: secure storage read failed: $e');
      }

      // Fallback to SharedPreferences (useful for web builds where secure storage may not persist)
      if (token == null || token.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          // Try known access token keys for backward compatibility
          token = AuthGatingService.readStoredAccessToken(prefs);
          if (token != null && token.isNotEmpty) {
            AppConfig.debugPrint(
                'BackendApiService: Auth token loaded from SharedPreferences fallback');
          }
        } catch (e) {
          AppConfig.debugPrint(
              'BackendApiService: SharedPreferences fallback failed: $e');
        }
      }
      if (token != null && token.isNotEmpty) {
        if (AuthGatingService.isAccessTokenValid(token)) {
          _authToken = token;
          _authWalletCanonical = _tryExtractWalletFromToken(token);
          await resolveLastSignInMethod();
          AppConfig.debugPrint(
              'BackendApiService: Auth token loaded (in-memory)');
        } else {
          _authToken = null;
          _authWalletCanonical = null;
          AppConfig.debugPrint(
              'BackendApiService: Stored auth token is expired; ignoring');
        }
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
              AppConfig.debugPrint(
                  'BackendApiService: token expiry in $secsLeft seconds');
            }
          }
        } catch (e) {
          AppConfig.debugPrint(
              'BackendApiService: failed to decode token expiry: $e');
        }
      } else {
        AppConfig.debugPrint('BackendApiService: No stored auth token found');
      }

      await _loadRefreshTokenFromStorage();
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
      await _secureStorage
          .delete(key: 'refresh_token')
          .timeout(const Duration(milliseconds: 800));
      AppConfig.debugPrint(
          'BackendApiService: Auth cleared from secure storage');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService: Error clearing auth token: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in AuthGatingService.accessTokenKeys) {
        await prefs.remove(key);
      }
      for (final key in AuthGatingService.refreshTokenKeys) {
        await prefs.remove(key);
      }
      await prefs.remove(PreferenceKeys.authLastSignInMethodV1);
      AppConfig.debugPrint(
          'BackendApiService: Auth cleared from SharedPreferences');
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService: Error clearing prefs auth token: $e');
    }
  }

  /// Loads a stored backend account session without issuing a new account token
  /// for an arbitrary wallet.
  ///
  /// This never restores signer authority. Callers that need wallet-proofed
  /// authority must upgrade through ensureSessionForActiveSigner.
  Future<bool> restoreExistingSession({bool allowRefresh = true}) async {
    try {
      await loadAuthToken();
      final token = (_authToken ?? '').trim();
      if (token.isNotEmpty && AuthGatingService.isAccessTokenValid(token)) {
        return true;
      }

      if (!allowRefresh) return false;

      final prefs = await SharedPreferences.getInstance();
      final sessionStatus = AuthGatingService.evaluateStoredSession(
        prefs: prefs,
      );
      if (sessionStatus != StoredSessionStatus.refreshRequired) {
        return false;
      }

      return false;
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.restoreExistingSession failed: $e',
      );
      return false;
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
        final msg =
            (decoded['error'] ?? decoded['message'] ?? decoded['detail'] ?? '')
                .toString();
        if (msg.trim().isEmpty) return false;
        // IMPORTANT:
        // 403 is commonly used for *authorization* (valid session but not allowed),
        // such as "only view your own achievements" endpoints. Treating every
        // "Forbidden" as an auth failure causes spurious re-auth prompts when
        // browsing other users' public content.
        //
        // Only treat 403 as an auth failure when the body indicates a token/auth
        // issue (or when the body is empty, handled above).
        return _looksLikeTokenErrorMessage(msg);
      }
      if (decoded is String) {
        return _looksLikeTokenErrorMessage(decoded);
      }
    } catch (_) {
      return _looksLikeTokenErrorMessage(body);
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
    bool allowImplicitBackendFailover = true,
    Set<String>? attemptedBackendOrigins,
  }) async {
    final attemptedOrigins = Set<String>.from(
      attemptedBackendOrigins ?? const <String>{},
    );
    final currentOrigin = _uriOriginKey(uri);
    if (currentOrigin != null) {
      attemptedOrigins.add(currentOrigin);
    }

    if (includeAuth &&
        _authCoordinator != null &&
        _authCoordinator!.isResolving) {
      final settled = await _authCoordinator!.waitForResolution();
      if (settled != null && !settled.isSuccess) {
        throw BackendApiRequestException(
          statusCode: 401,
          path: uri.path,
          body: settled.message,
        );
      }
    }

    if (includeAuth) {
      final token = (_authToken ?? '').trim();
      final needsSessionRestore =
          token.isEmpty || !AuthGatingService.isAccessTokenValid(token);
      if (needsSessionRestore) {
        try {
          await restoreExistingSession();
        } catch (_) {
          // Fall through and let the request/auth-coordinator path decide.
        }
      }
    }

    final resolvedHeaders = _applyAuthHeader(
      Map<String, String>.from(
          headers ?? _getHeaders(includeAuth: includeAuth)),
      includeAuth: includeAuth,
    );

    // Minimal, scoped HTTP tracing for debugging auth/403 issues on web.
    // Guarded by AppConfig.enableNetworkLogging and only logs marker endpoints
    // to avoid noisy console output.
    final shouldTrace = AppConfig.enableNetworkLogging &&
        kDebugMode &&
        (uri.path.startsWith('/api/art-markers') ||
            uri.path.contains('/api/art-markers/'));
    if (shouldTrace) {
      final hasAuthHeader = resolvedHeaders.containsKey('Authorization');
      final authWallet =
          _authWalletCanonical ?? _tryExtractWalletFromToken(_authToken) ?? '';
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
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response =
              await _client.get(uri, headers: resolvedHeaders).timeout(timeout);
          break;
        case 'POST':
          response = await _client
              .post(uri,
                  headers: resolvedHeaders, body: body, encoding: encoding)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri,
                  headers: resolvedHeaders, body: body, encoding: encoding)
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await _client
              .patch(uri,
                  headers: resolvedHeaders, body: body, encoding: encoding)
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri,
                  headers: resolvedHeaders, body: body, encoding: encoding)
              .timeout(timeout);
          break;
        default:
          throw ArgumentError('Unsupported method: $method');
      }
    } catch (error) {
      if (allowImplicitBackendFailover && _isFallbackEligibleReadError(error)) {
        final failoverUri = _nextImplicitFailoverUri(
          uri,
          method: method,
          attemptedOrigins: attemptedOrigins,
        );
        if (failoverUri != null) {
          return _request(
            method,
            failoverUri,
            includeAuth: includeAuth,
            headers: headers,
            body: body,
            encoding: encoding,
            isIdempotent: isIdempotent,
            timeout: timeout,
            retriedAfterReauth: retriedAfterReauth,
            allowImplicitBackendFailover: allowImplicitBackendFailover,
            attemptedBackendOrigins: attemptedOrigins,
          );
        }
      }
      rethrow;
    }

    if (shouldTrace) {
      final snippet = response.body.length <= 240
          ? response.body
          : response.body.substring(0, 240);
      AppConfig.networkLog('RESP', uri.toString(), data: {
        'status': response.statusCode,
        'bodySnippet': snippet,
      });
    }

    final coordinator = _authCoordinator;
    final isAuthFailure = includeAuth &&
        coordinator != null &&
        AppConfig.isFeatureEnabled('rePromptLoginOnExpiry') &&
        _isAuthFailureStatus(
            statusCode: response.statusCode, responseBody: response.body);

    if (!isAuthFailure) {
      if (_isSuccessStatus(response.statusCode)) {
        final successfulBaseUrl = _configuredBaseUrlForUri(uri);
        if (successfulBaseUrl != null) {
          _publicFallbackService.recordBackendSuccess(
            baseUrl: successfulBaseUrl,
          );
        }
      }

      if (allowImplicitBackendFailover &&
          _shouldImplicitFailoverOnStatus(method, response.statusCode)) {
        final failoverUri = _nextImplicitFailoverUri(
          uri,
          method: method,
          attemptedOrigins: attemptedOrigins,
        );
        if (failoverUri != null) {
          return _request(
            method,
            failoverUri,
            includeAuth: includeAuth,
            headers: headers,
            body: body,
            encoding: encoding,
            isIdempotent: isIdempotent,
            timeout: timeout,
            retriedAfterReauth: retriedAfterReauth,
            allowImplicitBackendFailover: allowImplicitBackendFailover,
            attemptedBackendOrigins: attemptedOrigins,
          );
        }
      }

      return response;
    }

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
        allowImplicitBackendFailover: allowImplicitBackendFailover,
        attemptedBackendOrigins: attemptedOrigins,
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
    bool allowImplicitBackendFailover = true,
    Set<String>? attemptedBackendOrigins,
  }) async {
    final attemptedOrigins = Set<String>.from(
      attemptedBackendOrigins ?? const <String>{},
    );

    if (includeAuth &&
        _authCoordinator != null &&
        _authCoordinator!.isResolving) {
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
    final currentOrigin = _uriOriginKey(request.url);
    if (currentOrigin != null) {
      attemptedOrigins.add(currentOrigin);
    }
    final baseHeaders = <String, String>{
      'Accept': 'application/json',
      ...request.headers,
    };
    request.headers
      ..clear()
      ..addAll(_applyAuthHeader(baseHeaders, includeAuth: includeAuth));

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } catch (error) {
      if (allowImplicitBackendFailover && _isFallbackEligibleReadError(error)) {
        final failoverUri = _nextImplicitFailoverUri(
          request.url,
          method: request.method,
          attemptedOrigins: attemptedOrigins,
        );
        if (failoverUri != null) {
          return _sendMultipart(
            () {
              final retryRequest = requestFactory();
              final rewritten = http.MultipartRequest(
                retryRequest.method,
                failoverUri,
              );
              rewritten.headers.addAll(retryRequest.headers);
              rewritten.fields.addAll(retryRequest.fields);
              rewritten.files.addAll(retryRequest.files);
              return rewritten;
            },
            includeAuth: includeAuth,
            timeout: timeout,
            retriedAfterReauth: retriedAfterReauth,
            allowImplicitBackendFailover: allowImplicitBackendFailover,
            attemptedBackendOrigins: attemptedOrigins,
          );
        }
      }
      rethrow;
    }

    if (_isSuccessStatus(response.statusCode)) {
      final successfulBaseUrl = _configuredBaseUrlForUri(request.url);
      if (successfulBaseUrl != null) {
        _publicFallbackService.recordBackendSuccess(baseUrl: successfulBaseUrl);
      }
    }

    if (allowImplicitBackendFailover &&
        _shouldImplicitFailoverOnStatus(request.method, response.statusCode)) {
      final failoverUri = _nextImplicitFailoverUri(
        request.url,
        method: request.method,
        attemptedOrigins: attemptedOrigins,
      );
      if (failoverUri != null) {
        return _sendMultipart(
          () {
            final retryRequest = requestFactory();
            final rewritten = http.MultipartRequest(
              retryRequest.method,
              failoverUri,
            );
            rewritten.headers.addAll(retryRequest.headers);
            rewritten.fields.addAll(retryRequest.fields);
            rewritten.files.addAll(retryRequest.files);
            return rewritten;
          },
          includeAuth: includeAuth,
          timeout: timeout,
          retriedAfterReauth: retriedAfterReauth,
          allowImplicitBackendFailover: allowImplicitBackendFailover,
          attemptedBackendOrigins: attemptedOrigins,
        );
      }
    }

    final coordinator = _authCoordinator;
    final isAuthFailure = includeAuth &&
        coordinator != null &&
        AppConfig.isFeatureEnabled('rePromptLoginOnExpiry') &&
        _isAuthFailureStatus(
            statusCode: response.statusCode, responseBody: response.body);

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
      allowImplicitBackendFailover: allowImplicitBackendFailover,
      attemptedBackendOrigins: attemptedOrigins,
    );
  }

  Future<void> _persistTokenFromResponse(Map<String, dynamic> body) async {
    await _backendApiPersistTokenFromResponse(this, body);
  }

  Map<String, dynamic> _responsePayload(Map<String, dynamic> body) {
    return _backendApiResponsePayload(body);
  }

  Map<String, dynamic>? _mapOrNull(Object? value) {
    return _backendApiMapOrNull(value);
  }

  Future<void> _persistSecureAccountStatus({
    required bool hasEmail,
    required bool hasPassword,
    required String? email,
    required bool emailVerified,
    required bool emailAuthEnabled,
  }) async {
    await _backendApiPersistSecureAccountStatus(
      hasEmail: hasEmail,
      hasPassword: hasPassword,
      email: email,
      emailVerified: emailVerified,
      emailAuthEnabled: emailAuthEnabled,
    );
  }

  Map<String, dynamic> _normalizeSecurityStatusMap(
    Map<String, dynamic> data,
  ) {
    return _backendApiNormalizeSecurityStatusMap(data);
  }

  Future<Map<String, dynamic>> getCachedSecureAccountStatus() async {
    return _backendApiGetCachedSecureAccountStatus(this);
  }

  Future<void> syncSecureAccountStatusFromResponse(
    Map<String, dynamic> body, {
    bool fetchIfMissing = true,
  }) async {
    await _backendApiSyncSecureAccountStatusFromResponse(
      this,
      body,
      fetchIfMissing: fetchIfMissing,
    );
  }

  bool _isSuccessStatus(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  Uri _withOrbitSource(Uri uri) {
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['source'] = 'orbit';
    return uri.replace(queryParameters: qp);
  }

  Future<Map<String, dynamic>> _fetchJson(
    Uri uri, {
    bool includeAuth = true,
    bool allowOrbitFallback = false,
    bool allowImplicitBackendFailover = true,
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
        allowImplicitBackendFailover: allowImplicitBackendFailover,
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
      allowImplicitBackendFailover: allowImplicitBackendFailover,
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

  String _normalizeApiBaseUrl(String rawBaseUrl) {
    final trimmed = rawBaseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri _buildApiUri(
    String rawBaseUrl,
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.parse('${_normalizeApiBaseUrl(rawBaseUrl)}$path')
        .replace(queryParameters: queryParameters);
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    switch (uri.scheme.toLowerCase()) {
      case 'https':
        return 443;
      case 'http':
        return 80;
      default:
        return -1;
    }
  }

  String? _uriOriginKey(Uri uri) {
    final scheme = uri.scheme.toLowerCase().trim();
    final host = uri.host.toLowerCase().trim();
    if (scheme.isEmpty || host.isEmpty) return null;
    return '$scheme://$host:${_effectivePort(uri)}';
  }

  Uri _baseUrlOriginUri(String rawBaseUrl) {
    return Uri.parse(_normalizeApiBaseUrl(rawBaseUrl));
  }

  bool _isConfiguredBackendUri(Uri uri) {
    final origin = _uriOriginKey(uri);
    if (origin == null) return false;
    return origin == _uriOriginKey(_baseUrlOriginUri(AppConfig.baseApiUrl)) ||
        origin == _uriOriginKey(_baseUrlOriginUri(AppConfig.standbyApiUrl));
  }

  String? _configuredBaseUrlForUri(Uri uri) {
    final origin = _uriOriginKey(uri);
    if (origin == null) return null;

    if (origin == _uriOriginKey(_baseUrlOriginUri(AppConfig.baseApiUrl))) {
      return AppConfig.baseApiUrl;
    }
    if (origin == _uriOriginKey(_baseUrlOriginUri(AppConfig.standbyApiUrl))) {
      return AppConfig.standbyApiUrl;
    }
    return null;
  }

  Uri _rewriteUriBase(Uri originalUri, String rawBaseUrl) {
    final baseUri = _baseUrlOriginUri(rawBaseUrl);
    return Uri(
      scheme: baseUri.scheme,
      userInfo: baseUri.userInfo,
      host: baseUri.host,
      port: baseUri.hasPort ? baseUri.port : null,
      path: originalUri.path,
      query: originalUri.hasQuery ? originalUri.query : null,
      fragment: originalUri.hasFragment ? originalUri.fragment : null,
    );
  }

  Iterable<String> _implicitFailoverCandidates(String method) {
    return method.toUpperCase() == 'GET'
        ? _publicFallbackService.preferredReadBaseUrls
        : _publicFallbackService.preferredWriteBaseUrls;
  }

  bool _shouldImplicitFailoverOnStatus(String method, int statusCode) {
    if (method.toUpperCase() == 'GET') {
      return const <int>{500, 502, 503, 504, 522, 523, 524, 530}
          .contains(statusCode);
    }
    return _isTransientWriteStatusCode(statusCode);
  }

  Uri? _nextImplicitFailoverUri(
    Uri originalUri, {
    required String method,
    required Set<String> attemptedOrigins,
  }) {
    if (!_isConfiguredBackendUri(originalUri)) {
      return null;
    }

    for (final candidateBaseUrl in _implicitFailoverCandidates(method)) {
      final candidateOriginUri = _baseUrlOriginUri(candidateBaseUrl);
      final candidateOrigin = _uriOriginKey(candidateOriginUri);
      if (candidateOrigin == null ||
          attemptedOrigins.contains(candidateOrigin)) {
        continue;
      }
      return _rewriteUriBase(originalUri, candidateBaseUrl);
    }

    return null;
  }

  Future<Map<String, dynamic>> _fetchJsonFromBaseUrl(
    String rawBaseUrl,
    String path, {
    Map<String, String>? queryParameters,
    bool includeAuth = true,
    bool allowOrbitFallback = false,
  }) {
    return _fetchJson(
      _buildApiUri(
        rawBaseUrl,
        path,
        queryParameters: queryParameters,
      ),
      includeAuth: includeAuth,
      allowOrbitFallback: allowOrbitFallback,
      allowImplicitBackendFailover: false,
    );
  }

  bool _isFallbackEligibleReadError(Object error) {
    final status = _tryParseRequestFailedStatus(error);
    if (status == null) {
      final message = error.toString().toLowerCase();
      return message.contains('timeout') ||
          message.contains('timed out') ||
          message.contains('socketexception') ||
          message.contains('clientexception') ||
          message.contains('failed host lookup') ||
          message.contains('connection closed') ||
          message.contains('network') ||
          message.contains('cors');
    }

    // Only treat gateway/outage-style responses as failover triggers.
    // Generic 500 application errors should not move the app into public
    // snapshot mode when the primary API is still the source of truth.
    return const <int>{502, 503, 504, 522, 523, 524, 530}.contains(status);
  }

  Future<R> _performPublicRead<R>({
    required Future<R> Function(String baseUrl) liveRead,
    required Future<R> Function() snapshotRead,
    bool allowSnapshot = true,
  }) async {
    Object? lastFallbackEligibleError;

    if (_publicFallbackService.mode != AppRuntimeMode.ipfsFallback) {
      for (final candidateBaseUrl
          in _publicFallbackService.preferredReadBaseUrls) {
        try {
          final result = await liveRead(candidateBaseUrl);
          _publicFallbackService.recordBackendSuccess(
              baseUrl: candidateBaseUrl);
          return result;
        } catch (error) {
          if (!_isFallbackEligibleReadError(error)) {
            rethrow;
          }
          lastFallbackEligibleError = error;
        }
      }

      _publicFallbackService.recordDualBackendFailure();
    }

    if (allowSnapshot) {
      try {
        return await snapshotRead();
      } catch (snapshotError) {
        if (lastFallbackEligibleError != null) {
          throw lastFallbackEligibleError;
        }
        rethrow;
      }
    }

    if (lastFallbackEligibleError != null) {
      throw lastFallbackEligibleError;
    }
    throw Exception('Public read failed');
  }

  Future<List<Map<String, dynamic>>> _loadSnapshotDatasetMaps(
    String datasetKey,
  ) async {
    final records = await _publicFallbackService.loadDatasetArray(datasetKey);
    return records
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  bool _isTransientWriteStatusCode(int statusCode) {
    return statusCode >= 500;
  }

  Future<http.Response?> _sendWriteWithFailover(
    String method,
    String path, {
    bool includeAuth = true,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool isIdempotent = false,
    Duration timeout = AppConfig.requestTimeout,
  }) async {
    http.Response? lastResponse;
    Object? lastError;

    for (final candidateBaseUrl
        in _publicFallbackService.preferredWriteBaseUrls) {
      final uri = _buildApiUri(candidateBaseUrl, path);
      try {
        final response = await _request(
          method,
          uri,
          includeAuth: includeAuth,
          headers: headers,
          body: body,
          encoding: encoding,
          isIdempotent: isIdempotent,
          timeout: timeout,
          allowImplicitBackendFailover: false,
        );
        if (_isSuccessStatus(response.statusCode)) {
          _publicFallbackService.recordBackendSuccess(
              baseUrl: candidateBaseUrl);
          return response;
        }
        if (!_isTransientWriteStatusCode(response.statusCode)) {
          return response;
        }
        lastResponse = response;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    return lastResponse;
  }

  Future<http.Response> _sendAuthRequestWithFailover(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    bool includeAuth = false,
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool isIdempotent = false,
    Duration timeout = AppConfig.requestTimeout,
  }) async {
    http.Response? lastResponse;
    Object? lastError;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final normalizedMethod = method.toUpperCase();
    final candidateBaseUrls = normalizedMethod == 'GET'
        ? _publicFallbackService.preferredReadBaseUrls
        : _publicFallbackService.preferredWriteBaseUrls;

    for (final candidateBaseUrl in candidateBaseUrls) {
      final uri = _buildApiUri(
        candidateBaseUrl,
        normalizedPath,
        queryParameters: queryParameters,
      );
      try {
        final response = await _request(
          normalizedMethod,
          uri,
          includeAuth: includeAuth,
          headers: headers,
          body: body,
          encoding: encoding,
          isIdempotent: isIdempotent || normalizedMethod == 'GET',
          timeout: timeout,
          allowImplicitBackendFailover: false,
        );
        if (_isSuccessStatus(response.statusCode)) {
          _publicFallbackService.recordBackendSuccess(
            baseUrl: candidateBaseUrl,
          );
          return response;
        }
        if (!_isTransientWriteStatusCode(response.statusCode)) {
          return response;
        }
        lastResponse = response;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    if (lastResponse != null) {
      return lastResponse;
    }

    throw BackendApiRequestException(
      statusCode: 0,
      path: normalizedPath,
      body: '',
    );
  }

  void _throwIfIpfsFallbackUnavailable(String featureLabel) =>
      _backendApiThrowIfIpfsFallbackUnavailable(this, featureLabel);

  Map<String, dynamic>? _decodeResponseMap(http.Response response) =>
      _backendApiDecodeResponseMap(response);

  Map<String, dynamic>? _extractResponseEntityMap(
    dynamic payload, {
    Iterable<String> preferredKeys = const <String>[],
  }) {
    if (payload is Map<String, dynamic>) {
      for (final key in preferredKeys) {
        final extracted = _extractResponseEntityMap(
          payload[key],
          preferredKeys: preferredKeys,
        );
        if (extracted != null) return extracted;
      }

      for (final alias in const <String>[
        'data',
        'item',
        'result',
        'payload',
        'entity',
      ]) {
        final extracted = _extractResponseEntityMap(
          payload[alias],
          preferredKeys: preferredKeys,
        );
        if (extracted != null) return extracted;
      }

      if (payload.containsKey('id')) {
        return payload;
      }

      for (final nested in payload.values) {
        final extracted = _extractResponseEntityMap(
          nested,
          preferredKeys: preferredKeys,
        );
        if (extracted != null) return extracted;
      }
      return null;
    }

    if (payload is Map) {
      return _extractResponseEntityMap(
        Map<String, dynamic>.from(payload),
        preferredKeys: preferredKeys,
      );
    }

    if (payload is List) {
      for (final item in payload) {
        final extracted = _extractResponseEntityMap(
          item,
          preferredKeys: preferredKeys,
        );
        if (extracted != null) return extracted;
      }
    }

    return null;
  }

  Map<String, dynamic>? _extractSuccessfulEntityMap(
    http.Response response, {
    Iterable<String> preferredKeys = const <String>[],
  }) {
    if (!_isSuccessStatus(response.statusCode)) return null;
    if (response.body.isEmpty) return null;

    final decoded = _decodeResponseMap(response);
    if (decoded == null) return null;

    return _extractResponseEntityMap(
          decoded,
          preferredKeys: preferredKeys,
        ) ??
        decoded;
  }

  bool? _tryBoolValue(dynamic value) => _backendApiTryBoolValue(value);

  int? _extractIntFromResponse(http.Response response, List<String> keys) =>
      _backendApiExtractIntFromResponse(response, keys);

  Future<http.Response?> _sendQueueablePublicAction({
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
  }) =>
      _backendApiSendQueueablePublicAction(
        this,
        method: method,
        path: path,
        actionType: actionType,
        entityType: entityType,
        entityId: entityId,
        walletAddress: walletAddress,
        payload: payload,
        body: body,
        encoding: encoding,
        isIdempotent: isIdempotent,
      );

  /// Normalize search suggestion payloads from various backend shapes into a
  /// stable list of maps with keys: `label`, `subtitle`, `id`, `type`, `lat`, `lng`.
  ///
  /// Accepts raw JSON that may be a List, a Map with `data`/`results` keys,
  /// or a single item map. The normalization is defensive to support multiple
  /// backend response shapes used across endpoints.
  List<Map<String, dynamic>> normalizeSearchSuggestions(dynamic raw) {
    return normalizeSearchSuggestionsPayload(raw);
  }

  /// Fetch backend server version from health endpoint.
  ///
  /// Returns null when unavailable/unreachable and never throws.
  Future<String?> fetchServerVersion({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      return await _performPublicRead<String?>(
        liveRead: (candidateBaseUrl) async {
          final response = await _get(
            _buildApiUri(candidateBaseUrl, '/health'),
            includeAuth: false,
            headers: _getHeaders(includeAuth: false),
            timeout: timeout,
          );
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception('Request failed: ${response.statusCode}');
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map) {
            return null;
          }
          final map = Map<String, dynamic>.from(decoded);
          final rawVersion = (map['version'] ?? '').toString().trim();
          return rawVersion.isEmpty ? null : rawVersion;
        },
        snapshotRead: () async => null,
        allowSnapshot: false,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.fetchServerVersion failed: $e');
      return null;
    }
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

  /// Bootstrap a wallet-root user/profile via auth endpoint.
  ///
  /// This does not prove signer authority and does not persist the returned
  /// bootstrap token as the app session. Use ensureSessionForActiveSigner for
  /// challenge/sign/login when a signer is available.
  /// POST /api/auth/register { walletAddress, username? }
  @override
  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  }) =>
      _backendApiRegisterWallet(
        this,
        walletAddress: walletAddress,
        username: username,
      );

  /// Login with wallet signature
  /// POST /api/auth/login
  Future<Map<String, dynamic>> loginWithWallet({
    required String walletAddress,
    required String signature,
    required String message,
  }) =>
      _backendApiLoginWithWallet(
        this,
        walletAddress: walletAddress,
        signature: signature,
        message: message,
      );

  /// Register with email + password.
  ///
  /// Any walletAddress included here is advisory only. Email auth establishes a
  /// backend account session, not signer authority.
  /// POST /api/auth/register/email
  Future<Map<String, dynamic>> registerWithEmail({
    required String email,
    required String password,
    String? username,
    String? displayName,
    String? walletAddress,
    bool includeAuth = false,
  }) =>
      _backendApiRegisterWithEmail(
        this,
        email: email,
        password: password,
        username: username,
        displayName: displayName,
        walletAddress: walletAddress,
        includeAuth: includeAuth,
      );

  /// Login with email + password.
  ///
  /// This restores backend account state only. Wallet-signed authority still
  /// requires ensureSessionForActiveSigner.
  /// POST /api/auth/login/email
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) =>
      _backendApiLoginWithEmail(
        this,
        email: email,
        password: password,
      );

  /// Resend email verification link
  /// POST /api/auth/resend-verification { email }
  Future<Map<String, dynamic>> _resendEmailVerificationRequest({
    required String email,
    required bool includeAuth,
  }) =>
      _backendApiResendEmailVerificationRequest(
        this,
        email: email,
        includeAuth: includeAuth,
      );

  Future<Map<String, dynamic>> resendEmailVerification(
          {required String email}) =>
      _resendEmailVerificationRequest(
        email: email,
        includeAuth: false,
      );

  Future<Map<String, dynamic>> resendEmailVerificationForCurrentAccount({
    String? email,
  }) =>
      _resendEmailVerificationRequest(
        email: email ?? '',
        includeAuth: true,
      );

  /// Check whether an email has been verified.
  /// GET /api/auth/email-status?email=...
  Future<Map<String, dynamic>> getEmailVerificationStatus(
          {required String email}) =>
      _backendApiGetEmailVerificationStatus(
        this,
        email: email,
      );

  /// Return email/password credential status for the authenticated account.
  /// GET /api/auth/account-security-status
  Future<Map<String, dynamic>> getAccountSecurityStatus() =>
      _backendApiGetAccountSecurityStatus(this);

  Future<void> syncSecureAccountStatusToPrefs() =>
      _backendApiSyncSecureAccountStatusToPrefs(this);

  /// Add a password to the currently authenticated account.
  /// POST /api/auth/account-security/password { password }
  Future<Map<String, dynamic>> addPasswordToCurrentAccount({
    required String password,
  }) =>
      _backendApiAddPasswordToCurrentAccount(
        this,
        password: password,
      );

  /// Verify email
  /// POST /api/auth/verify-email { token }
  Future<Map<String, dynamic>> verifyEmail({required String token}) =>
      _backendApiVerifyEmail(this, token: token);

  /// Request password reset (always returns 200 when enabled)
  /// POST /api/auth/forgot-password { email }
  Future<Map<String, dynamic>> forgotPassword({required String email}) =>
      _backendApiForgotPassword(this, email: email);

  /// Reset password with token (single-use)
  /// POST /api/auth/reset-password { token, newPassword }
  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      _backendApiResetPassword(
        this,
        token: token,
        newPassword: newPassword,
      );

  /// Login with Google idToken (verified server-side).
  ///
  /// Google auth is a linked backend account method. It must not be treated as
  /// signer restoration or wallet-proofed authority.
  /// POST /api/auth/login/google
  Future<Map<String, dynamic>> loginWithGoogle({
    String? idToken,
    String? code,
    String? email,
    String? username,
    String? walletAddress,
    String? displayName,
  }) =>
      _backendApiLoginWithGoogle(
        this,
        idToken: idToken,
        code: code,
        email: email,
        username: username,
        walletAddress: walletAddress,
        displayName: displayName,
      );

  /// Deprecated compatibility bridge.
  ///
  /// This surface is intentionally no longer the canonical way to link wallet
  /// identity. Prefer challenge/sign/login for any wallet-proofed session.
  Future<Map<String, dynamic>> bindAuthenticatedWallet(String walletAddress) =>
      _backendApiBindAuthenticatedWallet(this, walletAddress);

  Future<EncryptedWalletBackupDefinition?> getEncryptedWalletBackup({
    String? walletAddress,
  }) =>
      _backendApiGetEncryptedWalletBackup(
        this,
        walletAddress: walletAddress,
      );

  Future<EncryptedWalletBackupDefinition> putEncryptedWalletBackup(
    EncryptedWalletBackupDefinition definition,
  ) =>
      _backendApiPutEncryptedWalletBackup(
        this,
        definition,
      );

  Future<void> deleteEncryptedWalletBackup({String? walletAddress}) =>
      _backendApiDeleteEncryptedWalletBackup(
        this,
        walletAddress: walletAddress,
      );

  Future<Map<String, dynamic>> getWalletBackupPasskeyRegistrationOptions({
    required String walletAddress,
    String? nickname,
  }) =>
      _backendApiGetWalletBackupPasskeyRegistrationOptions(
        this,
        walletAddress: walletAddress,
        nickname: nickname,
      );

  Future<Map<String, dynamic>> verifyWalletBackupPasskeyRegistration({
    required String walletAddress,
    required Map<String, dynamic> responsePayload,
    String? nickname,
  }) =>
      _backendApiVerifyWalletBackupPasskeyRegistration(
        this,
        walletAddress: walletAddress,
        responsePayload: responsePayload,
        nickname: nickname,
      );

  Future<Map<String, dynamic>> getWalletBackupPasskeyAuthOptions({
    required String walletAddress,
  }) =>
      _backendApiGetWalletBackupPasskeyAuthOptions(
        this,
        walletAddress: walletAddress,
      );

  Future<Map<String, dynamic>> verifyWalletBackupPasskeyAuth({
    required String walletAddress,
    required Map<String, dynamic> responsePayload,
  }) =>
      _backendApiVerifyWalletBackupPasskeyAuth(
        this,
        walletAddress: walletAddress,
        responsePayload: responsePayload,
      );

  Future<void> emitWalletBackupEvent({
    required String walletAddress,
    required String eventType,
  }) =>
      _backendApiEmitWalletBackupEvent(
        this,
        walletAddress: walletAddress,
        eventType: eventType,
      );

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
        throw Exception(
            'Email preferences endpoint not available on the backend (received 404). Ensure the server is updated.');
      }
      throw BackendApiRequestException(
          statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.getMyEmailPreferences failed: $e');
      rethrow;
    }
  }

  /// Update authenticated user's email preferences
  /// PATCH /api/users/me/preferences
  Future<Map<String, dynamic>> updateMyEmailPreferences(
      Map<String, dynamic> preferences) async {
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
        throw Exception(
            'Email preferences endpoint not available on the backend (received 404). Ensure the server is updated.');
      }
      throw BackendApiRequestException(
          statusCode: response.statusCode, path: uri.path, body: response.body);
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.updateMyEmailPreferences failed: $e');
      rethrow;
    }
  }

  // ==================== Chat / Messaging Helpers (wrappers used by providers) ====================

  /// Return current in-memory auth token (may be null)
  @override
  String? getAuthToken() => _authToken;

  /// Returns decoded JWT claims for the current in-memory auth token.
  /// Returns null when token is missing or malformed.
  Map<String, dynamic>? getCurrentAuthTokenClaims() {
    final token = (_authToken ?? '').trim();
    if (token.isEmpty) return null;
    return _tryDecodeJwtPayload(token);
  }

  /// Returns normalized email claim from current auth token, if present.
  String? getCurrentAuthEmail() {
    final claims = getCurrentAuthTokenClaims();
    if (claims == null) return null;
    final email =
        (claims['email'] ?? claims['emailAddress'] ?? '').toString().trim();
    return email.isEmpty ? null : email.toLowerCase();
  }

  /// Returns wallet claim from current auth token, if present.
  /// This only reads explicit wallet claims and intentionally ignores `id/sub`.
  String? getCurrentAuthWalletAddress() {
    final claims = getCurrentAuthTokenClaims();
    if (claims == null) return null;
    final wallet = (claims['walletAddress'] ??
            claims['wallet_address'] ??
            claims['wallet'] ??
            '')
        .toString()
        .trim();
    return wallet.isEmpty ? null : wallet;
  }

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

  /// Fetch list of conversations (lightweight)
  /// GET /api/messages
  Future<Map<String, dynamic>> fetchConversations() =>
      _backendApiFetchConversationsImpl(this);

  /// Fetch messages for a conversation
  /// GET /api/messages/:conversationId/messages
  Future<Map<String, dynamic>> fetchMessages(String conversationId,
          {int page = 1, int limit = 50}) =>
      _backendApiFetchMessagesImpl(
        this,
        conversationId,
        page: page,
        limit: limit,
      );

  /// Send a message to a conversation (JSON)
  /// POST /api/messages/:conversationId/messages { message, data, replyToId }
  Future<Map<String, dynamic>> sendMessage(
          String conversationId, String message,
          {Map<String, dynamic>? data, String? replyToId}) =>
      _backendApiSendMessageImpl(
        this,
        conversationId,
        message,
        data: data,
        replyToId: replyToId,
      );

  /// Fetch conversation members
  /// GET /api/messages/:conversationId/members
  Future<Map<String, dynamic>> fetchConversationMembers(
          String conversationId) =>
      _backendApiFetchConversationMembersImpl(this, conversationId);

  /// Upload a message attachment by posting multipart to the messages endpoint
  Future<Map<String, dynamic>> uploadMessageAttachment(String conversationId,
          List<int> bytes, String filename, String contentType,
          {bool compress = true,
          UploadCompressionPolicy? compressionPolicy,
          void Function(UploadCompressionProgress progress)?
              onCompressionProgress}) =>
      _backendApiUploadMessageAttachmentImpl(
        this,
        conversationId,
        bytes,
        filename,
        contentType,
        compress: compress,
        compressionPolicy: compressionPolicy,
        onCompressionProgress: onCompressionProgress,
      );

  /// Create a conversation
  /// POST /api/messages { title, members }
  Future<Map<String, dynamic>> createConversation(
          {String? title, bool isGroup = false, List<String>? members}) =>
      _backendApiCreateConversationImpl(
        this,
        title: title,
        isGroup: isGroup,
        members: members,
      );

  /// Upload conversation avatar (attempt common endpoints)
  Future<Map<String, dynamic>> uploadConversationAvatar(String conversationId,
          List<int> bytes, String filename, String contentType,
          {bool compress = true,
          UploadCompressionPolicy? compressionPolicy,
          void Function(UploadCompressionProgress progress)?
              onCompressionProgress}) =>
      _backendApiUploadConversationAvatarImpl(
        this,
        conversationId,
        bytes,
        filename,
        contentType,
        compress: compress,
        compressionPolicy: compressionPolicy,
        onCompressionProgress: onCompressionProgress,
      );

  /// Add a member to conversation
  Future<Map<String, dynamic>> addConversationMember(
          String conversationId, String walletAddress) =>
      _backendApiAddConversationMemberImpl(
        this,
        conversationId,
        walletAddress,
      );

  /// Remove a member from conversation (best-effort)
  Future<Map<String, dynamic>> removeConversationMember(
          String conversationId, String walletOrUsername) =>
      _backendApiRemoveConversationMemberImpl(
        this,
        conversationId,
        walletOrUsername,
      );

  /// Transfer conversation ownership (best-effort)
  Future<Map<String, dynamic>> transferConversationOwner(
          String conversationId, String newOwnerWallet) =>
      _backendApiTransferConversationOwnerImpl(
        this,
        conversationId,
        newOwnerWallet,
      );

  /// Mark conversation as read
  Future<Map<String, dynamic>> markConversationRead(String conversationId) =>
      _backendApiMarkConversationReadImpl(this, conversationId);

  /// Mark a specific message as read
  Future<Map<String, dynamic>> markMessageRead(
          String conversationId, String messageId) =>
      _backendApiMarkMessageReadImpl(this, conversationId, messageId);

  Future<Map<String, dynamic>> renameConversation(
          String conversationId, String newTitle) =>
      _backendApiRenameConversationImpl(this, conversationId, newTitle);

  Future<Map<String, dynamic>> deleteConversation(String conversationId) =>
      _backendApiDeleteConversationImpl(this, conversationId);

  /// Update user profile (preferences / metadata)
  /// POST /api/profiles
  @override
  Future<Map<String, dynamic>> updateProfile(
    String walletAddress,
    Map<String, dynamic> updates,
  ) =>
      _backendApiUpdateProfileImpl(this, walletAddress, updates);

  // ==================== Profile/Artists API (New) ====================

  /// Get profile by wallet address
  /// GET /api/profiles/:walletAddress
  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) =>
      _backendApiGetProfileByWalletImpl(this, walletAddress);

  /// Get wallet-scoped collectible ownership index
  /// GET /api/profiles/:walletAddress/collectibles
  Future<Map<String, dynamic>> getWalletCollectibleIndex(
          String walletAddress) =>
      _backendApiGetWalletCollectibleIndex(this, walletAddress);

  /// Fetch multiple profiles in a single batch call
  /// POST /api/profiles/batch { wallets: [wallet1,wallet2] }
  Future<Map<String, dynamic>> getProfilesBatch(List<String> wallets) =>
      _backendApiGetProfilesBatchImpl(this, wallets);

  /// Fetch multiple presence records in a single batch call
  /// POST /api/presence/batch { wallets: [wallet1,wallet2] }
  Future<Map<String, dynamic>> getPresenceBatch(List<String> wallets) =>
      _backendApiGetPresenceBatchImpl(this, wallets);

  /// Record a last-visited subject (best-effort; server enforces privacy and may return 204).
  /// POST /api/presence/visit { type, id }
  Future<Map<String, dynamic>> recordPresenceVisit({
    required String type,
    required String id,
    String? walletAddress,
  }) =>
      _backendApiRecordPresenceVisitImpl(
        this,
        type: type,
        id: id,
        walletAddress: walletAddress,
      );

  /// Keep the authenticated user's presence lastSeen timestamp fresh.
  /// POST /api/presence/ping
  Future<Map<String, dynamic>> pingPresence({String? walletAddress}) =>
      _backendApiPingPresenceImpl(this, walletAddress: walletAddress);

  /// Find a profile by username (helper built on top of the search endpoint)
  Future<Map<String, dynamic>?> findProfileByUsername(String username) =>
      _backendApiFindProfileByUsernameImpl(this, username);

  /// Create or update profile
  /// POST /api/profiles
  @override
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> profileData) =>
      _backendApiSaveProfileImpl(this, profileData);

  /// List artists
  /// GET /api/profiles/artists/list
  Future<List<Map<String, dynamic>>> listArtists({
    bool? verified,
    int limit = 50,
    int offset = 0,
  }) =>
      _backendApiListArtistsImpl(
        this,
        verified: verified,
        limit: limit,
        offset: offset,
      );

  // ===========================================================================
  // PROMOTION RATE CARDS (New Dynamic Pricing System)
  // ===========================================================================

  /// Get rate cards for dynamic pricing.
  /// GET /api/app/promotion-rate-cards?entityType=artwork|profile
  Future<List<PromotionRateCard>> getPromotionRateCards({
    required PromotionEntityType entityType,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/app/promotion-rate-cards').replace(
        queryParameters: <String, String>{
          'entityType': entityType.apiValue,
        },
      );
      final dynamic data = await _fetchJson(
        uri,
        includeAuth: true,
        allowOrbitFallback: false,
      );
      final List<dynamic> list = (() {
        if (data is List) return data;
        if (data is Map<String, dynamic>) {
          final payload = data['data'] ?? data['rateCards'];
          if (payload is List) return payload;
        }
        return const <dynamic>[];
      })();
      return list
          .whereType<Map>()
          .map((e) => PromotionRateCard.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.getPromotionRateCards failed: $e');
      rethrow;
    }
  }

  /// Check slot availability for a rate card.
  /// GET /api/app/promotion-slot-availability?rateCardId=...&startDate=...&endDate=...
  Future<SlotAvailability> getSlotAvailability({
    required String rateCardId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final params = <String, String>{
        'rateCardId': rateCardId,
      };
      if (startDate != null) {
        params['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        params['endDate'] = endDate.toIso8601String();
      }
      final uri =
          Uri.parse('$baseUrl/api/app/promotion-slot-availability').replace(
        queryParameters: params,
      );
      final dynamic data = await _fetchJson(
        uri,
        includeAuth: true,
        allowOrbitFallback: false,
      );
      if (data is Map<String, dynamic>) {
        final payload = data['data'] ?? data;
        return SlotAvailability.fromJson(
          payload is Map<String, dynamic> ? payload : <String, dynamic>{},
        );
      }
      throw Exception('Invalid slot availability response');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getSlotAvailability failed: $e');
      rethrow;
    }
  }

  /// Get alternative dates when a slot is unavailable.
  /// GET /api/app/promotion-alternative-dates?rateCardId=...&slotIndex=...&startDate=...&durationDays=...
  Future<AlternativeDatesResponse> getAlternativeDates({
    required String rateCardId,
    required int slotIndex,
    required DateTime startDate,
    required int durationDays,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri =
          Uri.parse('$baseUrl/api/app/promotion-alternative-dates').replace(
        queryParameters: <String, String>{
          'rateCardId': rateCardId,
          'slotIndex': slotIndex.toString(),
          'startDate': startDate.toIso8601String(),
          'durationDays': durationDays.toString(),
        },
      );
      final dynamic data = await _fetchJson(
        uri,
        includeAuth: true,
        allowOrbitFallback: false,
      );
      if (data is Map<String, dynamic>) {
        final payload = data['data'] ?? data;
        return AlternativeDatesResponse.fromJson(
          payload is Map<String, dynamic> ? payload : <String, dynamic>{},
        );
      }
      throw Exception('Invalid alternative dates response');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getAlternativeDates failed: $e');
      rethrow;
    }
  }

  /// Calculate a price quote for a promotion.
  /// POST /api/app/promotion-price-quote
  Future<PriceQuote> calculatePriceQuote({
    required String rateCardId,
    required int durationDays,
    int? slotIndex,
    DateTime? startDate,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/app/promotion-price-quote');
      final payload = <String, dynamic>{
        'rateCardId': rateCardId,
        'durationDays': durationDays,
        if (slotIndex != null) 'slotIndex': slotIndex,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
      };
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'] ?? decoded;
        return PriceQuote.fromJson(
          data is Map<String, dynamic> ? data : <String, dynamic>{},
        );
      }
      throw Exception('Invalid price quote response');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.calculatePriceQuote failed: $e');
      rethrow;
    }
  }

  /// Cancel a promotion request.
  /// POST /api/app/promotion-requests/:id/cancel
  Future<CancellationResult> cancelPromotionRequest({
    required String requestId,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri =
          Uri.parse('$baseUrl/api/app/promotion-requests/$requestId/cancel');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: '{}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'] ?? decoded;
        return CancellationResult.fromJson(
          data is Map<String, dynamic> ? data : <String, dynamic>{},
        );
      }
      throw Exception('Invalid cancellation response');
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.cancelPromotionRequest failed: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // END PROMOTION RATE CARDS
  // ===========================================================================

  /// Create an app promotion request using rate cards.
  /// POST /api/app/promotion-requests
  Future<PromotionRequestSubmission> createPromotionRequest({
    required String targetEntityId,
    required PromotionEntityType entityType,
    required String rateCardId,
    required int durationDays,
    required PromotionPaymentMethod paymentMethod,
    int? slotIndex,
    DateTime? startDate,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/app/promotion-requests');
      final payload = <String, dynamic>{
        'targetEntityId': targetEntityId,
        'entityType': entityType.apiValue,
        'rateCardId': rateCardId,
        'durationDays': durationDays,
        'paymentMethod': paymentMethod.apiValue,
        if (slotIndex != null) 'slotIndex': slotIndex,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
      };
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(payload),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return PromotionRequestSubmission.fromJson(decoded);
      }
      throw Exception('Invalid promotion request response payload');
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.createPromotionRequest failed: $e');
      rethrow;
    }
  }

  /// Get my promotion requests.
  /// GET /api/app/promotion-requests/me
  Future<List<PromotionRequest>> getMyPromotionRequests() async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/app/promotion-requests/me');
      final dynamic data = await _fetchJson(
        uri,
        includeAuth: true,
        allowOrbitFallback: false,
      );
      final List<dynamic> list = (() {
        if (data is List) return data;
        if (data is Map<String, dynamic>) {
          final payload = data['data'] ?? data['requests'];
          if (payload is List) return payload;
        }
        return const <dynamic>[];
      })();
      return list
          .whereType<Map>()
          .map((e) => PromotionRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.getMyPromotionRequests failed: $e');
      rethrow;
    }
  }

  /// Public backend-ranked home rails.
  /// GET /api/public/home-rails?locale=en|sl
  Future<HomeRailsResponse> getPublicHomeRails({
    String locale = 'en',
    int? limitPerRail,
  }) async {
    try {
      final query = <String, String>{'locale': locale};
      if (limitPerRail != null) {
        query['limit'] = limitPerRail.toString();
      }
      final uri = Uri.parse('$baseUrl/api/public/home-rails').replace(
        queryParameters: query,
      );
      final dynamic data = await _fetchJson(
        uri,
        includeAuth: false,
        allowOrbitFallback: true,
      );
      if (data is Map<String, dynamic>) {
        return HomeRailsResponse.fromJson(data);
      }
      if (data is Map) {
        return HomeRailsResponse.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Invalid home rails response');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getPublicHomeRails failed: $e');
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

      final uri = Uri.parse('$baseUrl/api/profiles/$walletAddress/artworks')
          .replace(queryParameters: queryParams);
      final response = await _get(uri,
          includeAuth: false, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] as List);
      } else {
        throw Exception(
            'Failed to get artist artworks: ${response.statusCode}');
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
      if (groupBy != null && groupBy.trim().isNotEmpty) {
        queryParams['groupBy'] = groupBy.trim();
      }

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
      if (timeframe.trim().isNotEmpty) {
        queryParams['timeframe'] = timeframe.trim();
      }
      if (from != null && from.trim().isNotEmpty) {
        queryParams['from'] = from.trim();
      }
      if (to != null && to.trim().isNotEmpty) queryParams['to'] = to.trim();
      if (groupBy != null && groupBy.trim().isNotEmpty) {
        queryParams['groupBy'] = groupBy.trim();
      }
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
      return await _performPublicRead<List<ArtMarker>>(
        liveRead: (candidateBaseUrl) async {
          final data = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/art-markers',
            queryParameters: qp,
            includeAuth: true,
            allowOrbitFallback: true,
          );
          final dynamic maybeList =
              data['data'] ?? data['markers'] ?? data['artMarkers'];
          final List<dynamic> markerList =
              maybeList is List ? maybeList : const <dynamic>[];
          return markerList
              .map(
                (json) =>
                    _artMarkerFromBackendJson(json as Map<String, dynamic>),
              )
              .toList(growable: false);
        },
        snapshotRead: () async {
          const distance = Distance();
          final center = LatLng(latitude, longitude);
          var markers = (await _loadSnapshotDatasetMaps('markers'))
              .map(_artMarkerFromBackendJson)
              .where((marker) {
            final isPublic =
                _tryBoolValue(marker.metadata?['isPublic']) ?? marker.isPublic;
            if (!isPublic) {
              return false;
            }
            final distanceKm = distance.as(
              LengthUnit.Kilometer,
              center,
              marker.position,
            );
            return distanceKm <= radiusKm;
          }).toList(growable: false);
          if (limit != null && markers.length > limit) {
            markers = markers.sublist(0, limit);
          }
          return markers;
        },
      );
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
      return await _performPublicRead<List<ArtMarker>>(
        liveRead: (candidateBaseUrl) async {
          final data = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/art-markers',
            queryParameters: qp,
            includeAuth: true,
            allowOrbitFallback: true,
          );
          final dynamic maybeList =
              data['data'] ?? data['markers'] ?? data['artMarkers'];
          final List<dynamic> markerList =
              maybeList is List ? maybeList : const <dynamic>[];

          return markerList
              .map(
                (json) =>
                    _artMarkerFromBackendJson(json as Map<String, dynamic>),
              )
              .toList(growable: false);
        },
        snapshotRead: () async {
          bool withinBounds(ArtMarker marker) {
            final lat = marker.position.latitude;
            final lng = marker.position.longitude;
            if (lat < minLat || lat > maxLat) {
              return false;
            }
            if (minLng <= maxLng) {
              return lng >= minLng && lng <= maxLng;
            }
            return lng >= minLng || lng <= maxLng;
          }

          var markers = (await _loadSnapshotDatasetMaps('markers'))
              .map(_artMarkerFromBackendJson)
              .where(withinBounds)
              .toList(growable: false);
          if (limit != null && markers.length > limit) {
            markers = markers.sublist(0, limit);
          }
          return markers;
        },
      );
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.getArtMarkersInBounds failed: $e');
      rethrow;
    }
  }

  /// Get single art marker by ID
  /// GET /api/art-markers/:id
  Future<ArtMarker?> getArtMarker(
    String markerId, {
    bool allowOrbitFallback = true,
  }) async {
    final id = markerId.trim();
    if (id.isEmpty) return null;

    try {
      // Markers can be public (optional auth). Include auth when available,
      // but do not hard-fail if the user is not signed in yet.
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      return await _performPublicRead<ArtMarker?>(
        liveRead: (candidateBaseUrl) async {
          final data = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/art-markers/$id',
            includeAuth: true,
            allowOrbitFallback: allowOrbitFallback,
          );

          final payload =
              data['data'] ?? data['marker'] ?? data['artMarker'] ?? data;
          if (payload is Map<String, dynamic>) {
            return _artMarkerFromBackendJson(payload);
          }
          if (payload is Map) {
            return _artMarkerFromBackendJson(
              Map<String, dynamic>.from(payload),
            );
          }
          return null;
        },
        snapshotRead: () async {
          final markers = await _loadSnapshotDatasetMaps('markers');
          for (final entry in markers) {
            if ((entry['id'] ?? '').toString().trim() == id) {
              return _artMarkerFromBackendJson(entry);
            }
          }
          return null;
        },
      );
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
        final decoded =
            response.body.isNotEmpty ? jsonDecode(response.body) : null;
        final dynamic payload = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded['markers'] ?? decoded)
            : decoded;
        final List<dynamic> markerList =
            payload is List ? payload : const <dynamic>[];
        return markerList
            .whereType<Map<String, dynamic>>()
            .map(_artMarkerFromBackendJson)
            .toList(growable: false);
      }

      throw Exception(
          'Failed to load markers: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendeApiService.getMyArtMarkers failed: $e');
      rethrow;
    }
  }

  /// Create a marker record (server assigns ownership).
  /// POST /api/art-markers
  @override
  Future<ArtMarker?> createArtMarkerRecord(Map<String, dynamic> payload) async {
    _throwIfIpfsFallbackUnavailable('Marker publishing');
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/art-markers');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(payload),
        timeout: const Duration(seconds: 15),
      );

      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final marker = decoded['data'] ??
              decoded['marker'] ??
              decoded['artMarker'] ??
              decoded;
          if (marker is Map<String, dynamic>) {
            return _artMarkerFromBackendJson(marker);
          }
        }
        return null;
      }

      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.createArtMarkerRecord failed: $e');
      rethrow;
    }
  }

  /// Update a marker record.
  /// PUT /api/art-markers/:id
  @override
  Future<ArtMarker?> updateArtMarkerRecord(
      String markerId, Map<String, dynamic> updates) async {
    _throwIfIpfsFallbackUnavailable('Marker editing');
    bool markerReflectsUpdates(
        ArtMarker marker, Map<String, dynamic> requested) {
      final requestedName = requested['name'] ?? requested['title'];
      if (requestedName != null && marker.name != requestedName.toString()) {
        return false;
      }

      if (requested.containsKey('description')) {
        final expected = (requested['description'] ?? '').toString();
        if (marker.description != expected) return false;
      }

      if (requested.containsKey('category')) {
        final expected = (requested['category'] ?? '').toString();
        if (expected.isNotEmpty && marker.category != expected) return false;
      }

      if (requested.containsKey('isPublic') &&
          marker.isPublic != (requested['isPublic'] == true)) {
        return false;
      }

      if (requested.containsKey('isActive') &&
          marker.isActive != (requested['isActive'] == true)) {
        return false;
      }

      final latRaw = requested['latitude'] ??
          requested['lat'] ??
          requested['position']?['lat'];
      final lngRaw = requested['longitude'] ??
          requested['lng'] ??
          requested['position']?['lng'];
      final expectedLat = latRaw is num
          ? latRaw.toDouble()
          : double.tryParse(latRaw?.toString() ?? '');
      final expectedLng = lngRaw is num
          ? lngRaw.toDouble()
          : double.tryParse(lngRaw?.toString() ?? '');

      if (expectedLat != null &&
          (marker.position.latitude - expectedLat).abs() > 0.000001) {
        return false;
      }
      if (expectedLng != null &&
          (marker.position.longitude - expectedLng).abs() > 0.000001) {
        return false;
      }

      return true;
    }

    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/art-markers/$markerId');
      final response = await _put(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(updates),
        timeout: const Duration(seconds: 15),
      );

      if (!_isSuccessStatus(response.statusCode)) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      }

      if (kDebugMode) {
        debugPrint(
          'BackendApiService.updateArtMarkerRecord: status=${response.statusCode} bodyLength=${response.body.length}',
        );
      }

      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            bool looksLikeMarkerMap(Map<String, dynamic> map) {
              final hasId = (map['id'] ?? '').toString().trim().isNotEmpty;
              final hasNameOrTitle = (map['name'] ?? map['title'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty;
              final hasCoords = map.containsKey('latitude') ||
                  map.containsKey('lat') ||
                  map['position'] is Map;
              return hasId && (hasNameOrTitle || hasCoords);
            }

            final candidate =
                decoded['data'] ?? decoded['marker'] ?? decoded['artMarker'];
            if (candidate is Map<String, dynamic>) {
              final marker = _artMarkerFromBackendJson(candidate);
              if (markerReflectsUpdates(marker, updates)) {
                return marker;
              }
            }

            if (looksLikeMarkerMap(decoded)) {
              final marker = _artMarkerFromBackendJson(decoded);
              if (markerReflectsUpdates(marker, updates)) {
                return marker;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'BackendApiService.updateArtMarkerRecord: response parse failed, falling back to GET: $e',
            );
          }
        }
      }

      final refreshed = await getArtMarker(
        markerId,
        allowOrbitFallback: false,
      );
      if (kDebugMode && refreshed == null) {
        debugPrint(
          'BackendApiService.updateArtMarkerRecord: successful PUT but GET fallback returned null for marker $markerId',
        );
      }
      if (refreshed != null && !markerReflectsUpdates(refreshed, updates)) {
        throw BackendApiRequestException(
          statusCode: 409,
          path: uri.path,
          body:
              'Marker update verification failed: response does not match requested changes',
        );
      }
      return refreshed;
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.updateArtMarkerRecord failed: $e');
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
      AppConfig.debugPrint(
          'BackendApiService.deleteArtMarkerRecord failed: $e');
      rethrow;
    }
  }

  /// Submit a street-art ownership claim for a marker.
  /// POST /api/art-markers/:id/claims
  @override
  Future<StreetArtClaim> submitStreetArtClaim({
    required String markerId,
    required String reason,
    String? evidenceUrl,
    String? claimantProfileName,
  }) async {
    _throwIfIpfsFallbackUnavailable('Street art claims');

    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/art-markers/$markerId/claims');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(<String, dynamic>{
          'reason': reason,
          if (evidenceUrl != null && evidenceUrl.trim().isNotEmpty)
            'evidenceUrl': evidenceUrl.trim(),
          if (claimantProfileName != null &&
              claimantProfileName.trim().isNotEmpty)
            'claimantProfileName': claimantProfileName.trim(),
        }),
        timeout: const Duration(seconds: 20),
      );

      if (!_isSuccessStatus(response.statusCode)) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      }

      final decoded = _decodeResponseMap(response);
      final payload = decoded == null
          ? null
          : (decoded['data'] ?? decoded['claim'] ?? decoded);
      if (payload is Map<String, dynamic>) {
        return StreetArtClaim.fromJson(payload);
      }
      if (payload is Map) {
        return StreetArtClaim.fromJson(Map<String, dynamic>.from(payload));
      }

      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.submitStreetArtClaim failed: $e');
      rethrow;
    }
  }

  /// List street-art claims visible to the requester for a marker.
  /// GET /api/art-markers/:id/claims
  @override
  Future<List<StreetArtClaim>> getStreetArtClaims(String markerId) async {
    _throwIfIpfsFallbackUnavailable('Street art claims');

    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/art-markers/$markerId/claims');
      final response = await _get(
        uri,
        headers: _getHeaders(),
        timeout: const Duration(seconds: 15),
      );

      if (!_isSuccessStatus(response.statusCode)) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      }

      final decoded = _decodeResponseMap(response);
      final payload = decoded == null
          ? null
          : (decoded['data'] ?? decoded['claims'] ?? decoded['results']);
      final claimList = payload is List ? payload : const <dynamic>[];

      return claimList
          .whereType<Map<String, dynamic>>()
          .map(StreetArtClaim.fromJson)
          .toList(growable: false);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getStreetArtClaims failed: $e');
      rethrow;
    }
  }

  /// Review an existing street-art claim.
  /// PATCH /api/art-markers/:id/claims/:claimId
  @override
  Future<StreetArtClaim?> reviewStreetArtClaim({
    required String markerId,
    required String claimId,
    required StreetArtClaimReviewAction action,
    String? note,
  }) async {
    _throwIfIpfsFallbackUnavailable('Street art claims');

    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse(
        '$baseUrl/api/art-markers/$markerId/claims/$claimId',
      );
      final response = await _patch(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(<String, dynamic>{
          'action': action.apiValue,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        }),
        timeout: const Duration(seconds: 20),
      );

      if (!_isSuccessStatus(response.statusCode)) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      }

      final decoded = _decodeResponseMap(response);
      final payload = decoded == null
          ? null
          : (decoded['data'] ?? decoded['claim'] ?? decoded);
      if (payload is Map<String, dynamic>) {
        return StreetArtClaim.fromJson(payload);
      }
      if (payload is Map) {
        return StreetArtClaim.fromJson(Map<String, dynamic>.from(payload));
      }

      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.reviewStreetArtClaim failed: $e');
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
        final payload = (data['data'] ?? data['marker'] ?? data['artMarker'])
            as Map<String, dynamic>;
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

  /// Create a short-lived attendance challenge token for a marker.
  /// GET /api/attendance/challenge?markerId=...
  Future<Map<String, dynamic>> getAttendanceChallenge({
    required String markerId,
    String? walletAddress,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);

      final uri =
          Uri.parse('$baseUrl/api/attestations/attendance/challenge').replace(
        queryParameters: <String, String>{'markerId': markerId.trim()},
      );
      final response = await _get(uri, headers: _getHeaders());
      if (response.statusCode == 404 || response.statusCode == 400) {
        final fallbackUri = Uri.parse('$baseUrl/api/attendance/challenge')
            .replace(
                queryParameters: <String, String>{'markerId': markerId.trim()});
        final fallback = await _get(fallbackUri, headers: _getHeaders());
        if (fallback.statusCode == 200) {
          return jsonDecode(fallback.body) as Map<String, dynamic>;
        }
        throw BackendApiRequestException(
          statusCode: fallback.statusCode,
          path: fallbackUri.path,
          body: fallback.body,
        );
      }
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.getAttendanceChallenge failed: $e');
      rethrow;
    }
  }

  /// Exchange a signed scan handoff token for a short-lived claim proof.
  /// POST /api/attestations/scan-proofs
  Future<Map<String, dynamic>> createScanClaimProof({
    required String markerId,
    required String subjectType,
    required String subjectId,
    required String proofSource,
    required String handoffToken,
    String? walletAddress,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final uri = Uri.parse('$baseUrl/api/attestations/scan-proofs');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({
          'markerId': markerId.trim(),
          'subjectType': subjectType.trim(),
          'subjectId': subjectId.trim(),
          'proofSource': proofSource.trim(),
          'handoffToken': handoffToken.trim(),
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createScanClaimProof failed: $e');
      rethrow;
    }
  }

  /// Confirm marker attendance (idempotent).
  /// POST /api/attendance/confirm
  Future<Map<String, dynamic>> confirmAttendance({
    required String markerId,
    required String challengeToken,
    required Map<String, dynamic> clientLocation,
    String? walletAddress,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final uri = Uri.parse('$baseUrl/api/attestations/attendance/confirm');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({
          'markerId': markerId.trim(),
          'challengeToken': challengeToken,
          'clientLocation': clientLocation,
        }),
      );

      if (response.statusCode == 404 || response.statusCode == 400) {
        final fallbackUri = Uri.parse('$baseUrl/api/attendance/confirm');
        final fallbackResponse = await _post(
          fallbackUri,
          headers: _getHeaders(),
          body: jsonEncode({
            'markerId': markerId.trim(),
            'challengeToken': challengeToken,
            'clientLocation': clientLocation,
          }),
        );

        if (fallbackResponse.statusCode == 200) {
          return jsonDecode(fallbackResponse.body) as Map<String, dynamic>;
        }

        throw BackendApiRequestException(
          statusCode: fallbackResponse.statusCode,
          path: fallbackUri.path,
          body: fallbackResponse.body,
        );
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.confirmAttendance failed: $e');
      rethrow;
    }
  }

  /// Get unified attestation graph for current user.
  /// GET /api/attestations/me
  Future<List<UnifiedAttestation>> getMyAttestations({
    int limit = 100,
    String? walletAddress,
  }) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final safeLimit = limit.clamp(1, 250);
      final uri = Uri.parse('$baseUrl/api/attestations/me').replace(
        queryParameters: <String, String>{
          'limit': '$safeLimit',
        },
      );
      final response = await _get(uri, headers: _getHeaders());
      if (response.statusCode != 200) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final payload = decoded['data'] ?? decoded;
      if (payload is! Map<String, dynamic>) return const <UnifiedAttestation>[];
      final raw = payload['attestations'];
      if (raw is! List) return const <UnifiedAttestation>[];
      return raw
          .whereType<Map>()
          .map((entry) =>
              UnifiedAttestation.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getMyAttestations failed: $e');
      return const <UnifiedAttestation>[];
    }
  }

  /// Claim an exhibition participation attestation (POAP-backed when configured).
  /// POST /api/attestations/exhibitions/:id/claim
  Future<UnifiedAttestation?> claimExhibitionAttestation(
    String exhibitionId, {
    String? attendanceMarkerId,
    String? claimProofToken,
    String? proofSource,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse(
          '$baseUrl/api/attestations/exhibitions/$exhibitionId/claim');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({
          if ((attendanceMarkerId ?? '').trim().isNotEmpty)
            'attendanceMarkerId': attendanceMarkerId!.trim(),
          if ((claimProofToken ?? '').trim().isNotEmpty)
            'claimProofToken': claimProofToken!.trim(),
          if ((proofSource ?? '').trim().isNotEmpty)
            'proofSource': proofSource!.trim(),
        }),
      );
      if (response.statusCode != 200) {
        throw BackendApiRequestException(
          statusCode: response.statusCode,
          path: uri.path,
          body: response.body,
        );
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final payload = decoded['data'] ?? decoded;
      if (payload is! Map<String, dynamic>) return null;
      final attestations = payload['attestations'];
      if (attestations is List && attestations.isNotEmpty) {
        final first = attestations.first;
        if (first is Map) {
          return UnifiedAttestation.fromJson(
            Map<String, dynamic>.from(first),
          );
        }
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.claimExhibitionAttestation failed: $e');
      rethrow;
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
      AppConfig.debugPrint(
          'BackendApiService.incrementMarkerInteractions failed: $e');
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

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

      return await _performPublicRead<List<Artwork>>(
        liveRead: (candidateBaseUrl) async {
          final data = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/artworks',
            queryParameters: queryParams,
            includeAuth: true,
            allowOrbitFallback: true,
          );
          final dynamic listCandidate =
              data['artworks'] ?? data['data'] ?? data['items'];
          final List<dynamic> artworks =
              listCandidate is List ? listCandidate : <dynamic>[];
          return artworks
              .map((json) =>
                  parseArtworkFromBackendJson(json as Map<String, dynamic>))
              .toList(growable: false);
        },
        snapshotRead: () async {
          if (includePrivateForWallet) {
            throw Exception(
              'Private artwork data is unavailable in public snapshot fallback.',
            );
          }

          final snapshots = await _loadSnapshotDatasetMaps('artworks');
          var filtered = snapshots.where((entry) {
            if (category != null &&
                entry['category']?.toString().trim().toLowerCase() !=
                    category.trim().toLowerCase()) {
              return false;
            }

            if (arEnabled != null) {
              final snapshotArEnabled =
                  _tryBoolValue(entry['arEnabled'] ?? entry['is_ar_enabled']) ??
                      false;
              if (snapshotArEnabled != arEnabled) {
                return false;
              }
            }

            if (hasWalletFilter) {
              final candidateWallet = WalletUtils.canonical(
                entry['walletAddress'] ??
                    entry['wallet_address'] ??
                    entry['wallet'],
              );
              if (candidateWallet != WalletUtils.canonical(walletAddress)) {
                return false;
              }
            }

            return _tryBoolValue(entry['isPublic'] ?? entry['is_public']) ??
                true;
          }).toList(growable: false);

          final start = ((page - 1) * limit).clamp(0, filtered.length).toInt();
          final end = (start + limit).clamp(0, filtered.length).toInt();
          filtered = filtered.sublist(start, end);

          return filtered
              .map(parseArtworkFromBackendJson)
              .toList(growable: false);
        },
      );
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
      return await _performPublicRead<Artwork>(
        liveRead: (candidateBaseUrl) async {
          final data = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/artworks/$artworkId',
            includeAuth: true,
            allowOrbitFallback: true,
          );
          final payload = data['artwork'] ?? data['data'] ?? data;
          if (payload is Map<String, dynamic>) {
            return parseArtworkFromBackendJson(payload);
          }
          throw Exception('Invalid artwork payload');
        },
        snapshotRead: () async {
          final artworks = await _loadSnapshotDatasetMaps('artworks');
          for (final entry in artworks) {
            if ((entry['id'] ?? '').toString().trim() == artworkId.trim()) {
              return parseArtworkFromBackendJson(entry);
            }
          }
          throw Exception('Artwork not found');
        },
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getArtwork failed: $e');
      rethrow;
    }
  }

  /// Update an artwork
  /// PUT /api/artworks/:id
  @override
  Future<Artwork?> updateArtwork(
      String artworkId, Map<String, dynamic> updates) async {
    try {
      await _ensureAuthWithStoredWallet();
      final uri = Uri.parse('$baseUrl/api/artworks/$artworkId');
      final response =
          await _put(uri, headers: _getHeaders(), body: jsonEncode(updates));
      if (response.statusCode == 200) {
        final payload = _extractSuccessfulEntityMap(
          response,
          preferredKeys: const <String>['artwork'],
        );
        if (payload != null) {
          return parseArtworkFromBackendJson(payload);
        }
        try {
          return await getArtwork(artworkId);
        } catch (_) {
          // If the backend returned a successful status but an unexpected
          // payload shape, keep the UI from reporting a false failure.
        }
        return null;
      }
      throw Exception(
          'Failed to update artwork: ${response.statusCode} ${response.body}');
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
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded['artwork'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            return parseArtworkFromBackendJson(payload);
          }
        }
        try {
          return await getArtwork(artworkId);
        } catch (_) {
          // Keep successful publish operations from surfacing a false failure
          // when the backend returns an empty or non-standard success body.
        }
        return null;
      }
      throw Exception(
          'Failed to publish artwork: ${response.statusCode} ${response.body}');
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
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded['artwork'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            return parseArtworkFromBackendJson(payload);
          }
        }
        try {
          return await getArtwork(artworkId);
        } catch (_) {
          // Keep successful unpublish operations from surfacing a false failure
          // when the backend returns an empty or non-standard success body.
        }
        return null;
      }
      throw Exception(
          'Failed to unpublish artwork: ${response.statusCode} ${response.body}');
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
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        return true;
      }
      throw Exception(
          'Failed to delete artwork: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteArtwork failed: $e');
      rethrow;
    }
  }

  /// Approximate network fee estimate for UX surfaces.
  /// GET /api/fees/estimate?network=...&action=...
  Future<Map<String, dynamic>?> estimateFees({
    required String network,
    required String action,
  }) async {
    final normalizedNetwork = network.trim();
    final normalizedAction = action.trim();
    if (normalizedNetwork.isEmpty || normalizedAction.isEmpty) return null;

    try {
      final uri =
          Uri.parse('$baseUrl/api/fees/estimate').replace(queryParameters: {
        'network': normalizedNetwork,
        'action': normalizedAction,
      });
      final response = await _get(uri, headers: _getHeaders());
      if (response.statusCode != 200) return null;
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.estimateFees failed: $e');
      return null;
    }
  }

  /// Fetch AR config + linked artwork content (public when artwork is public).
  /// GET /api/ar/:arConfigId/content
  Future<Map<String, dynamic>?> getArContent(
      {required String arConfigId}) async {
    final id = arConfigId.trim();
    if (id.isEmpty) return null;

    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/ar/$id/content');
      final response = await _get(uri, headers: _getHeaders());
      if (response.statusCode != 200) return null;
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) return data;
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getArContent failed: $e');
      return null;
    }
  }

  /// Auto-generate a printable AR marker for an artwork.
  /// POST /api/ar/:artworkId/marker/autogenerate
  Future<Map<String, dynamic>?> autogenerateArMarker({
    required String artworkId,
    required String walletAddress,
    String? subjectColor,
    int? markerSizePx,
    bool regenerate = false,
  }) async {
    final id = artworkId.trim();
    if (id.isEmpty) return null;

    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final uri = Uri.parse('$baseUrl/api/ar/$id/marker/autogenerate');
      final body = <String, dynamic>{
        if (subjectColor != null && subjectColor.trim().isNotEmpty)
          'subjectColor': subjectColor.trim(),
        if (markerSizePx != null) 'markerSizePx': markerSizePx,
        if (regenerate) 'regenerate': true,
      };

      final response = await _post(uri,
          headers: _getHeaders(),
          body: jsonEncode(body),
          isIdempotent: !regenerate);
      if (response.statusCode != 200) return null;
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) return data;
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.autogenerateArMarker failed: $e');
      return null;
    }
  }

  /// Upload a user-provided printable AR marker for an artwork.
  /// POST /api/ar/:artworkId/marker/upload (multipart: file)
  Future<Map<String, dynamic>?> uploadArMarker({
    required String artworkId,
    required String walletAddress,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final id = artworkId.trim();
    final safeName = fileName.trim().isEmpty ? 'marker.png' : fileName.trim();
    if (id.isEmpty) return null;
    if (fileBytes.isEmpty) return null;

    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final uri = Uri.parse('$baseUrl/api/ar/$id/marker/upload');
      http.MultipartRequest buildRequest() {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(_getHeaders());
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            fileBytes,
            filename: safeName,
            contentType: MediaType('image', 'png'),
          ),
        );
        return request;
      }

      final response = await _sendMultipart(buildRequest, includeAuth: true);
      if (response.statusCode != 200) return null;
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) return data;
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.uploadArMarker failed: $e');
      return null;
    }
  }

  /// Update an existing AR config record.
  /// PUT /api/ar/:arConfigId
  Future<Map<String, dynamic>?> updateArConfig({
    required String arConfigId,
    required String walletAddress,
    String? status,
    Map<String, dynamic>? markerMeta,
  }) async {
    final id = arConfigId.trim();
    if (id.isEmpty) return null;

    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final uri = Uri.parse('$baseUrl/api/ar/$id');
      final body = <String, dynamic>{
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (markerMeta != null) 'markerMeta': markerMeta,
      };
      final response = await _put(uri,
          headers: _getHeaders(), body: jsonEncode(body), isIdempotent: true);
      if (response.statusCode != 200) return null;
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        final data = decoded['data'];
        if (data is Map<String, dynamic>) return data;
      }
      return null;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.updateArConfig failed: $e');
      return null;
    }
  }

  /// Create a new artwork record (cover/model should be uploaded separately)
  /// POST /api/artworks
  Future<Artwork?> createArtworkRecord({
    required String title,
    required String description,
    required String imageUrl,
    required String walletAddress,
    String? imageCid,
    String? artistName,
    String category = 'General',
    List<String> tags = const [],
    List<String> galleryUrls = const [],
    List<Map<String, dynamic>>? galleryMeta,
    bool isPublic = true,
    bool enableAR = false,
    String? modelUrl,
    String? modelCid,
    double arScale = 1,
    bool mintAsNFT = false,
    double? price,
    double? royaltyPercent,
    ArtworkPoapMode poapMode = ArtworkPoapMode.none,
    bool poapEnabled = false,
    String? poapEventId,
    String? poapClaimUrl,
    String? poapTitle,
    String? poapDescription,
    String? poapImageUrl,
    DateTime? poapValidFrom,
    DateTime? poapValidTo,
    int poapRewardAmount = 1,
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
        if (imageCid != null) 'imageCid': imageCid,
        'walletAddress': walletAddress,
        if (artistName != null && artistName.isNotEmpty)
          'artistName': artistName,
        'category': category,
        'tags': tags,
        if (galleryUrls.isNotEmpty) 'galleryUrls': galleryUrls,
        if (galleryMeta != null && galleryMeta.isNotEmpty)
          'galleryMeta': galleryMeta,
        'isPublic': isPublic,
        'isAREnabled': enableAR,
        if (modelUrl != null) 'model3DURL': modelUrl,
        if (modelCid != null) 'model3DCID': modelCid,
        'arScale': arScale,
        'isNFT': mintAsNFT,
        if (royaltyPercent != null) 'royaltyPercent': royaltyPercent,
        if (price != null) 'price': price,
        'currency': 'KUB8',
        if (poapMode != ArtworkPoapMode.none) 'poapMode': poapMode.apiValue,
        if (poapMode != ArtworkPoapMode.none || poapEnabled)
          'poapEnabled': (poapMode != ArtworkPoapMode.none) || poapEnabled,
        if ((poapMode != ArtworkPoapMode.none || poapEnabled) &&
            poapEventId != null &&
            poapEventId.trim().isNotEmpty)
          'poapEventId': poapEventId.trim(),
        if ((poapMode != ArtworkPoapMode.none || poapEnabled) &&
            poapClaimUrl != null &&
            poapClaimUrl.trim().isNotEmpty)
          'poapClaimUrl': poapClaimUrl.trim(),
        if ((poapMode != ArtworkPoapMode.none || poapEnabled) &&
            poapTitle != null &&
            poapTitle.trim().isNotEmpty)
          'poapTitle': poapTitle.trim(),
        if ((poapMode != ArtworkPoapMode.none || poapEnabled) &&
            poapDescription != null &&
            poapDescription.trim().isNotEmpty)
          'poapDescription': poapDescription.trim(),
        if ((poapMode != ArtworkPoapMode.none || poapEnabled) &&
            poapImageUrl != null &&
            poapImageUrl.trim().isNotEmpty)
          'poapImageUrl': poapImageUrl.trim(),
        if ((poapMode != ArtworkPoapMode.none || poapEnabled) &&
            poapRewardAmount > 0)
          'poapRewardAmount': poapRewardAmount,
        if ((poapMode != ArtworkPoapMode.none || poapEnabled) &&
            poapValidFrom != null)
          'poapValidFrom': poapValidFrom.toUtc().toIso8601String(),
        if ((poapMode != ArtworkPoapMode.none || poapEnabled) &&
            poapValidTo != null)
          'poapValidTo': poapValidTo.toUtc().toIso8601String(),
        if (locationName != null && locationName.isNotEmpty)
          'locationName': locationName,
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
        final payload = _extractSuccessfulEntityMap(
          response,
          preferredKeys: const <String>['artwork'],
        );
        if (payload is Map<String, dynamic>) {
          return parseArtworkFromBackendJson(payload);
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
      final response = await _sendQueueablePublicAction(
        method: 'POST',
        path: '/api/artworks/$artworkId/like',
        actionType: 'like',
        entityType: 'artwork',
        entityId: artworkId,
        isIdempotent: true,
      );
      if (response == null || !_isSuccessStatus(response.statusCode)) {
        return null;
      }
      return _extractIntFromResponse(response, const <String>['likesCount']);
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
      final response = await _sendQueueablePublicAction(
        method: 'DELETE',
        path: '/api/artworks/$artworkId/like',
        actionType: 'unlike',
        entityType: 'artwork',
        entityId: artworkId,
        isIdempotent: true,
      );
      if (response == null || !_isSuccessStatus(response.statusCode)) {
        return null;
      }
      return _extractIntFromResponse(response, const <String>['likesCount']);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unlikeArtwork failed: $e');
      rethrow;
    }
  }

  /// Bookmark an artwork
  /// POST /api/artworks/:id/bookmark
  @override
  Future<void> bookmarkArtwork(String artworkId) async {
    try {
      await _sendQueueablePublicAction(
        method: 'POST',
        path: '/api/artworks/$artworkId/bookmark',
        actionType: 'bookmark',
        entityType: 'artwork',
        entityId: artworkId,
        isIdempotent: true,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.bookmarkArtwork failed: $e');
      rethrow;
    }
  }

  /// Remove artwork bookmark
  /// DELETE /api/artworks/:id/bookmark
  @override
  Future<void> unbookmarkArtwork(String artworkId) async {
    try {
      await _sendQueueablePublicAction(
        method: 'DELETE',
        path: '/api/artworks/$artworkId/bookmark',
        actionType: 'unbookmark',
        entityType: 'artwork',
        entityId: artworkId,
        isIdempotent: true,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unbookmarkArtwork failed: $e');
      rethrow;
    }
  }

  /// Record a view for an artwork
  /// POST /api/artworks/:id/view
  @override
  Future<int?> recordArtworkView(String artworkId) async {
    try {
      // Views are allowed anonymously, but include auth when available
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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

      final response =
          await _post(uri, headers: _getHeaders(includeAuth: true));
      if (response.statusCode == 200) return;
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.recordEventView failed: $e');
    }
  }

  /// Record a view for an exhibition
  /// POST /api/exhibitions/:id/view
  Future<void> recordExhibitionView(String exhibitionId,
      {String? source}) async {
    try {
      // Views are allowed anonymously, but include auth when available.
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      final uri =
          Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/view').replace(
        queryParameters: (source != null && source.trim().isNotEmpty)
            ? <String, String>{'source': source.trim()}
            : null,
      );

      final response =
          await _post(uri, headers: _getHeaders(includeAuth: true));
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
    try {
      await _ensureAuthWithStoredWallet();
    } catch (_) {}
    final uri = Uri.parse('$baseUrl/api/artworks/$artworkId/comments')
        .replace(queryParameters: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    final response = await _get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      if (payload is Map<String, dynamic>) {
        final raw = payload['data'] as List<dynamic>? ?? <dynamic>[];
        return raw
            .whereType<Map<String, dynamic>>()
            .map(ArtworkComment.fromMap)
            .toList();
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
    _throwIfIpfsFallbackUnavailable('Artwork comments');
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
      throw Exception(
          'Unexpected createArtworkComment payload: ${response.body}');
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
    try {
      await _ensureAuthWithStoredWallet();
    } catch (_) {}
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
      throw Exception(
          'Unexpected editArtworkComment payload: ${response.body}');
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
    try {
      await _ensureAuthWithStoredWallet();
    } catch (_) {}
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
      final response = await _sendQueueablePublicAction(
        method: 'POST',
        path: '/api/artworks/$artworkId/discover',
        actionType: 'discover',
        entityType: 'artwork',
        entityId: artworkId,
        isIdempotent: true,
      );
      if (response == null || !_isSuccessStatus(response.statusCode)) {
        return null;
      }
      return _extractIntFromResponse(
        response,
        const <String>['discoveryCount'],
      );
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.discoverArtworkWithCount failed: $e');
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
    String? surface,
    String? tag,
    String? sort,
  }) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (arOnly != null) queryParams['arOnly'] = arOnly.toString();
      if (authorWallet != null) queryParams['authorWallet'] = authorWallet;
      if (followingOnly != null) {
        queryParams['followingOnly'] = followingOnly.toString();
      }
      if (surface != null && surface.trim().isNotEmpty) {
        queryParams['surface'] = surface.trim().toLowerCase();
      }
      if (tag != null && tag.trim().isNotEmpty) {
        final normalizedTag = tag.replaceFirst(RegExp(r'^#+'), '').trim();
        if (normalizedTag.isNotEmpty) {
          queryParams['tag'] = normalizedTag;
        }
      }
      if (sort != null && sort.trim().isNotEmpty) {
        final normalizedSort = sort.trim().toLowerCase();
        if (normalizedSort == 'hybrid' ||
            normalizedSort == 'popularity' ||
            normalizedSort == 'popular' ||
            normalizedSort == 'recent') {
          queryParams['sort'] =
              normalizedSort == 'popular' ? 'popularity' : normalizedSort;
        }
      }

      final allowFallback = followingOnly != true;
      return await _performPublicRead<List<CommunityPost>>(
        liveRead: (candidateBaseUrl) async {
          final data = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/community/posts',
            queryParameters: queryParams,
            includeAuth: true,
            allowOrbitFallback: allowFallback,
          );
          final posts = data['data'] as List<dynamic>? ?? <dynamic>[];
          return posts
              .map((json) =>
                  _communityPostFromBackendJson(json as Map<String, dynamic>))
              .toList(growable: false);
        },
        snapshotRead: () async {
          if (!allowFallback) {
            throw Exception(
              'Following feed is unavailable in public snapshot fallback.',
            );
          }

          final snapshots = await _loadSnapshotDatasetMaps('communityFeed');
          var posts =
              snapshots.map(_communityPostFromBackendJson).where((post) {
            if (arOnly == true &&
                post.category.toLowerCase() != 'art' &&
                post.artwork == null) {
              return false;
            }
            if (authorWallet != null &&
                authorWallet.trim().isNotEmpty &&
                WalletUtils.canonical(post.authorWallet) !=
                    WalletUtils.canonical(authorWallet)) {
              return false;
            }
            if (tag != null && tag.trim().isNotEmpty) {
              final normalizedTag =
                  tag.replaceFirst(RegExp(r'^#+'), '').trim().toLowerCase();
              if (normalizedTag.isEmpty) {
                return true;
              }
              return post.tags
                  .map((entry) => entry.toLowerCase())
                  .contains(normalizedTag);
            }
            return true;
          }).toList(growable: false);

          final normalizedSort = (sort ?? '').trim().toLowerCase();
          if (normalizedSort == 'hybrid' ||
              normalizedSort == 'popularity' ||
              normalizedSort == 'popular') {
            posts.sort((left, right) {
              final leftScore =
                  left.likeCount + left.commentCount + left.shareCount;
              final rightScore =
                  right.likeCount + right.commentCount + right.shareCount;
              return rightScore.compareTo(leftScore);
            });
          } else {
            posts.sort(
                (left, right) => right.timestamp.compareTo(left.timestamp));
          }

          final start = ((page - 1) * limit).clamp(0, posts.length).toInt();
          final end = (start + limit).clamp(0, posts.length).toInt();
          return posts.sublist(start, end);
        },
        allowSnapshot: allowFallback,
      );
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
      final data =
          await _fetchJson(uri, includeAuth: false, allowOrbitFallback: false);
      final list =
          (data['data'] ?? data['tags'] ?? data['results']) as List<dynamic>?;
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      return await _performPublicRead<CommunityPost>(
        liveRead: (candidateBaseUrl) async {
          final data = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/community/posts/$postId',
            includeAuth: true,
            allowOrbitFallback: true,
          );
          final payload = data['data'] ?? data;
          if (payload is Map<String, dynamic>) {
            return _communityPostFromBackendJson(payload);
          }
          throw Exception('Unexpected post payload');
        },
        snapshotRead: () async {
          final snapshots = await _loadSnapshotDatasetMaps('communityFeed');
          for (final entry in snapshots) {
            if ((entry['id'] ?? '').toString().trim() == postId.trim()) {
              return _communityPostFromBackendJson(entry);
            }
          }
          throw Exception('Post not found');
        },
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getCommunityPostById failed: $e');
      rethrow;
    }
  }

  /// Batch-hydrate interaction state for visible community entities.
  /// The backend-authenticated result is authoritative; callers may keep a
  /// short-lived optimistic overlay while the request is in flight.
  Future<CommunityInteractionStateBatch> getCommunityInteractionStates({
    Iterable<String> postIds = const <String>[],
    Iterable<String> commentIds = const <String>[],
    Iterable<String> artworkIds = const <String>[],
  }) async {
    final normalizedPostIds = postIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(100)
        .toList(growable: false);
    final normalizedCommentIds = commentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(100)
        .toList(growable: false);
    final normalizedArtworkIds = artworkIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(100)
        .toList(growable: false);

    if (normalizedPostIds.isEmpty &&
        normalizedCommentIds.isEmpty &&
        normalizedArtworkIds.isEmpty) {
      return const CommunityInteractionStateBatch();
    }

    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      final queryParams = <String, String>{
        if (normalizedPostIds.isNotEmpty)
          'postIds': normalizedPostIds.join(','),
        if (normalizedCommentIds.isNotEmpty)
          'commentIds': normalizedCommentIds.join(','),
        if (normalizedArtworkIds.isNotEmpty)
          'artworkIds': normalizedArtworkIds.join(','),
      };

      final data = await _fetchJson(
        Uri.parse('$baseUrl/api/community/interactions/state')
            .replace(queryParameters: queryParams),
        includeAuth: true,
      );
      final payload = data['data'] ?? data;
      if (payload is Map<String, dynamic>) {
        return CommunityInteractionStateBatch.fromJson(payload);
      }
      return const CommunityInteractionStateBatch();
    } catch (e) {
      AppConfig.debugPrint(
        'BackendApiService.getCommunityInteractionStates failed: $e',
      );
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
    _throwIfIpfsFallbackUnavailable('Posting');
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
        final createdPost =
            _communityPostFromBackendJson(data['data'] as Map<String, dynamic>);
        try {
          await UserActionLogger.logPostCreated(
            postId: createdPost.id,
            content: createdPost.content,
            mediaUrls: aggregatedMedia.isNotEmpty
                ? aggregatedMedia
                : (createdPost.imageUrl != null
                    ? <String>[createdPost.imageUrl!]
                    : null),
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

      final shouldIncludeSubject = includeSubject ||
          subjectType != null ||
          subjectId != null ||
          artworkId != null;

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
      final response = await _sendQueueablePublicAction(
        method: 'POST',
        path: '/api/community/posts/$postId/like',
        actionType: 'like',
        entityType: 'post',
        entityId: postId,
        isIdempotent: true,
      );
      if (response == null || !_isSuccessStatus(response.statusCode)) {
        return null;
      }
      return _extractIntFromResponse(response, const <String>['likesCount']);
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.likePost failed: $e');
      rethrow;
    }
  }

  /// Bookmark a public post
  /// POST /api/community/posts/:id/bookmark
  Future<void> bookmarkPost(String postId) async {
    try {
      await _sendQueueablePublicAction(
        method: 'POST',
        path: '/api/community/posts/$postId/bookmark',
        actionType: 'bookmark',
        entityType: 'post',
        entityId: postId,
        isIdempotent: true,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.bookmarkPost failed: $e');
      rethrow;
    }
  }

  /// Remove public post bookmark
  /// DELETE /api/community/posts/:id/bookmark
  Future<void> unbookmarkPost(String postId) async {
    try {
      await _sendQueueablePublicAction(
        method: 'DELETE',
        path: '/api/community/posts/$postId/bookmark',
        actionType: 'unbookmark',
        entityType: 'post',
        entityId: postId,
        isIdempotent: true,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unbookmarkPost failed: $e');
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
        return _communityPostFromBackendJson(
            data['data'] as Map<String, dynamic>);
      } else {
        throw Exception(
            'Failed to create repost: ${response.statusCode} - ${response.body}');
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
    String sort = 'hybrid',
  }) async {
    try {
      final params = <String, String>{
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radiusKm': radiusKm.toStringAsFixed(2),
        'limit': limit.toString(),
        'page': page.toString(),
        'sort': sort.trim().toLowerCase(),
      };
      final uri = Uri.parse('$baseUrl/api/community/art-feed')
          .replace(queryParameters: params);
      final data =
          await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final posts = data['data'] as List<dynamic>? ?? <dynamic>[];
      return posts
          .map((json) =>
              _communityPostFromBackendJson(json as Map<String, dynamic>))
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      };
      final uri = Uri.parse('$baseUrl/api/groups')
          .replace(queryParameters: queryParams);
      final jsonData =
          await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final dynamic payload =
          jsonData['data'] ?? jsonData['groups'] ?? jsonData['results'];
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
          debugPrint(
              'BackendApiService: community groups unavailable (HTTP $status)');
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
        if (coverImage != null && coverImage.isNotEmpty)
          'coverImage': coverImage,
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final qp = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      final uri = Uri.parse('$baseUrl/api/groups/$groupId/posts')
          .replace(queryParameters: qp);
      final data =
          await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
      final posts = data['data'] as List<dynamic>? ?? <dynamic>[];
      return posts
          .map((json) =>
              _communityPostFromBackendJson(json as Map<String, dynamic>))
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
    _throwIfIpfsFallbackUnavailable('Posting');
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
                  : (created.imageUrl != null
                      ? <String>[created.imageUrl!]
                      : null),
            );
          } catch (e) {
            AppConfig.debugPrint(
                'BackendApiService.createGroupPost: UserActionLogger failed: $e');
          }
          return created;
        }
        throw Exception('Unexpected group post payload');
      }
      throw Exception(
          'Failed to create group post: ${response.statusCode} - ${response.body}');
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
        return list.whereType<Map<String, dynamic>>().toList(growable: false);
      }
      throw Exception('Failed to resolve subjects: ${response.statusCode}');
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.resolveCommunitySubjects failed: $e');
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
        throw Exception(
            'Failed to share post via DM: ${response.statusCode} - ${response.body}');
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
        throw Exception(
            'Failed to share via DM: ${response.statusCode} - ${response.body}');
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
        Uri.parse(
            '$baseUrl/api/community/posts/$postId/reposts?page=$page&limit=$limit'),
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final response = await _delete(
        Uri.parse('$baseUrl/api/community/posts/$repostId/repost'),
        headers: _getHeaders(),
        isIdempotent: true,
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to delete repost: ${response.statusCode} - ${response.body}');
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
        AppConfig.debugPrint(
            'BackendApiService.trackAnalyticsEvent failed (${response.statusCode})');
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
      final response = await _sendQueueablePublicAction(
        method: 'DELETE',
        path: '/api/community/posts/$postId/like',
        actionType: 'unlike',
        entityType: 'post',
        entityId: postId,
        isIdempotent: true,
      );
      if (response == null || !_isSuccessStatus(response.statusCode)) {
        return null;
      }
      return _extractIntFromResponse(response, const <String>['likesCount']);
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
    _throwIfIpfsFallbackUnavailable('Comments');
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
          final commentJson = parsed['comment'] ??
              parsed['data'] ??
              parsed['result'] ??
              parsed['payload'];
          if (commentJson is Map<String, dynamic>) {
            return _commentFromBackendJson(commentJson);
          }
          // Some endpoints may return the comment fields at root level
          if (parsed.containsKey('id') && parsed.containsKey('content')) {
            return _commentFromBackendJson(parsed);
          }
        }
        throw Exception(
            'Unexpected response when creating comment: ${response.body}');
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/community/comments/$commentId');
      final response = await _patch(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          final commentJson = parsed['comment'] ??
              parsed['data'] ??
              parsed['result'] ??
              parsed['payload'];
          if (commentJson is Map<String, dynamic>) {
            return _commentFromBackendJson(commentJson);
          }
          if (parsed.containsKey('id') && parsed.containsKey('content')) {
            return _commentFromBackendJson(parsed);
          }
        }
        throw Exception(
            'Unexpected response when editing comment: ${response.body}');
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
      try {
        await ensureAuthLoaded();
      } catch (_) {}
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
          final raw = parsed['comments'] ??
              parsed['data'] ??
              parsed['result'] ??
              parsed['payload'] ??
              [];
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
                if (['unknown', 'anonymous', 'n/a', 'none']
                    .contains(normalized)) {
                  continue;
                }
                wallets.add(normalized);
              }

              if (wallets.isNotEmpty) {
                final profilesResp = await getProfilesBatch(wallets.toList());
                final Map<String, Map<String, dynamic>> profilesByWallet = {};
                if (profilesResp['success'] == true &&
                    profilesResp['data'] is List) {
                  final profilesList = profilesResp['data'] as List<dynamic>;
                  for (final p
                      in profilesList.whereType<Map<String, dynamic>>()) {
                    final walletKey = WalletUtils.canonical(
                        (p['walletAddress'] ??
                                    p['wallet'] ??
                                    p['wallet_address'] ??
                                    p['publicKey'] ??
                                    p['public_key'])
                                ?.toString() ??
                            '');
                    if (walletKey.isNotEmpty) profilesByWallet[walletKey] = p;
                  }
                }

                // For any remaining candidates not found by wallet batch, try GET /api/users/:userId
                final missing = wallets
                    .where((w) => !profilesByWallet.containsKey(w))
                    .toList();
                for (final candidate in missing) {
                  try {
                    final profileResp = await getUserProfile(candidate);
                    if (profileResp.isNotEmpty) {
                      final walletKey = WalletUtils.canonical(
                          (profileResp['walletAddress'] ??
                                      profileResp['wallet'] ??
                                      profileResp['wallet_address'] ??
                                      profileResp['publicKey'] ??
                                      profileResp['public_key'])
                                  ?.toString() ??
                              '');
                      final key = walletKey.isNotEmpty
                          ? walletKey
                          : WalletUtils.canonical(candidate);
                      profilesByWallet[key] = profileResp;
                    }
                  } catch (e) {
                    // ignore 404s or failures for non-wallet ids
                  }
                }

                for (int i = 0; i < flat.length; i++) {
                  final c = flat[i];
                  final walletKey =
                      WalletUtils.canonical(c.authorWallet ?? c.authorId);
                  if (walletKey.isEmpty) continue;
                  final profile = profilesByWallet[walletKey];
                  if (profile == null) continue;
                  try {
                    final profileDisplayName =
                        profile['displayName'] as String? ??
                            profile['display_name'] as String?;
                    final profileUsername = profile['username'] as String? ??
                        profile['walletAddress'] as String? ??
                        profile['wallet'] as String?;
                    final avatarCandidate = profile['avatar'] as String? ??
                        profile['profileImage'] as String? ??
                        profile['profile_image'] as String? ??
                        profile['avatarUrl'] as String? ??
                        profile['avatar_url'] as String?;
                    final normalizedAvatar =
                        MediaUrlResolver.resolve(avatarCandidate);

                    // Determine best display name: prioritize displayName, then username, then fallback to existing
                    final bestDisplayName = (profileDisplayName != null &&
                            profileDisplayName.trim().isNotEmpty)
                        ? profileDisplayName.trim()
                        : ((profileUsername != null &&
                                profileUsername.trim().isNotEmpty)
                            ? profileUsername.trim()
                            : c.authorName);

                    final updated = c.copyWith(
                      authorAvatar: normalizedAvatar,
                      authorUsername: profileUsername ?? c.authorUsername,
                      authorName: bestDisplayName,
                      authorId: (profile['walletAddress'] ??
                              profile['wallet'] ??
                              profile['id'] ??
                              profile['userId'] ??
                              c.authorId)
                          ?.toString(),
                      authorWallet: (profile['walletAddress'] ??
                              profile['wallet'] ??
                              profile['wallet_address'] ??
                              profile['publicKey'] ??
                              profile['public_key'])
                          ?.toString(),
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
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
  Future<List<CommunityLikeUser>> getPostLikes(String postId,
      {int limit = 50, int offset = 0}) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/community/posts/$postId/likes')
          .replace(queryParameters: {
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
  Future<List<CommunityLikeUser>> getCommentLikes(String commentId,
      {int limit = 50, int offset = 0}) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/community/comments/$commentId/likes')
          .replace(queryParameters: {
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

  FollowMutationRecord _followMutationRecordFromResponse(
    http.Response? response, {
    required bool fallbackIsFollowing,
    String? fallbackTargetWallet,
  }) {
    final decoded = _backendApiDecodeJsonMap(response?.body);
    return FollowMutationRecord.fromJson(
      decoded,
      fallbackIsFollowing: fallbackIsFollowing,
      fallbackTargetWallet: fallbackTargetWallet,
    );
  }

  /// Follow a user
  /// POST /api/community/follow/:walletAddress
  Future<FollowMutationRecord?> followUserWithResponse(
    String walletAddress,
  ) async {
    final encoded = Uri.encodeComponent(walletAddress);
    final canonicalTarget = WalletUtils.canonical(walletAddress);
    try {
      final response = await _sendQueueablePublicAction(
        method: 'POST',
        path: '/api/community/follow/$encoded',
        actionType: 'follow',
        entityType: 'profile',
        entityId: walletAddress,
        isIdempotent: true,
      );
      if (response == null) {
        return FollowMutationRecord.fallback(
          isFollowing: true,
          targetWallet: canonicalTarget,
        );
      }
      return _followMutationRecordFromResponse(
        response,
        fallbackIsFollowing: true,
        fallbackTargetWallet: canonicalTarget,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.followUser failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> followUser(String walletAddress) async {
    await followUserWithResponse(walletAddress);
  }

  /// Unfollow a user
  /// DELETE /api/community/follow/:walletAddress
  Future<FollowMutationRecord?> unfollowUserWithResponse(
    String walletAddress,
  ) async {
    final encoded = Uri.encodeComponent(walletAddress);
    final canonicalTarget = WalletUtils.canonical(walletAddress);
    try {
      final response = await _sendQueueablePublicAction(
        method: 'DELETE',
        path: '/api/community/follow/$encoded',
        actionType: 'unfollow',
        entityType: 'profile',
        entityId: walletAddress,
        isIdempotent: true,
      );
      if (response == null) {
        return FollowMutationRecord.fallback(
          isFollowing: false,
          targetWallet: canonicalTarget,
        );
      }
      return _followMutationRecordFromResponse(
        response,
        fallbackIsFollowing: false,
        fallbackTargetWallet: canonicalTarget,
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.unfollowUser failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> unfollowUser(String walletAddress) async {
    await unfollowUserWithResponse(walletAddress);
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
          final raw = payload['data'] ??
              payload['followers'] ??
              payload['result'] ??
              payload['payload'] ??
              [];
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
          final raw = payload['data'] ??
              payload['following'] ??
              payload['result'] ??
              payload['payload'] ??
              [];
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
        final decoded = _backendApiDecodeJsonMap(response.body);
        if (decoded == null) {
          final normalized = response.body.trim().toLowerCase();
          if (normalized == 'true') return true;
          if (normalized == 'false') return false;
          return false;
        }
        final followRecord = FollowMutationRecord.fromJson(
          decoded,
          fallbackIsFollowing: false,
          fallbackTargetWallet: WalletUtils.canonical(walletAddress),
        );
        return followRecord.isFollowing;
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

      final body =
          response.body.isNotEmpty ? response.body : 'No response body';
      throw Exception(
          'Failed to submit report (${response.statusCode}): $body');
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

      final body =
          response.body.isNotEmpty ? response.body : 'No response body';
      throw Exception(
          'Failed to create support ticket (${response.statusCode}): $body');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createSupportTicket failed: $e');
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
        throw Exception(
            'Failed to get user achievements: ${response.statusCode}');
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
  Future<List<Map<String, dynamic>>> getDAOProposals({
    int limit = 50,
    int offset = 0,
    String? status,
  }) =>
      _backendApiGetDAOProposals(
        this,
        limit: limit,
        offset: offset,
        status: status,
      );

  /// Create a DAO proposal
  /// POST /api/dao/proposals
  Future<Map<String, dynamic>?> createDAOProposal({
    required Map<String, dynamic> envelope,
  }) =>
      _backendApiCreateDAOProposal(this, envelope: envelope);

  /// List votes for a proposal or all votes
  /// GET /api/dao/proposals/:id/votes or /api/dao/votes
  Future<List<Map<String, dynamic>>> getDAOVotes({
    String? proposalId,
    int limit = 100,
    int offset = 0,
  }) =>
      _backendApiGetDAOVotes(
        this,
        proposalId: proposalId,
        limit: limit,
        offset: offset,
      );

  /// Submit a DAO vote
  /// POST /api/dao/proposals/:id/votes
  Future<Map<String, dynamic>?> submitDAOVote({
    required String proposalId,
    required Map<String, dynamic> envelope,
  }) =>
      _backendApiSubmitDAOVote(
        this,
        proposalId: proposalId,
        envelope: envelope,
      );

  /// List DAO delegates
  /// GET /api/dao/delegates
  Future<List<Map<String, dynamic>>> getDAODelegates() =>
      _backendApiGetDAODelegates(this);

  /// Delegate voting power
  /// POST /api/dao/delegations
  Future<Map<String, dynamic>?> delegateVotingPower({
    required String delegateId,
    required Map<String, dynamic> envelope,
  }) =>
      _backendApiDelegateVotingPower(
        this,
        delegateId: delegateId,
        envelope: envelope,
      );

  /// List DAO treasury/governance transactions
  /// GET /api/dao/transactions
  Future<List<Map<String, dynamic>>> getDAOTransactions() =>
      _backendApiGetDAOTransactions(this);

  /// Submit a DAO review/application
  /// POST /api/dao/reviews
  Future<Map<String, dynamic>?> submitDAOReview({
    required Map<String, dynamic> envelope,
  }) =>
      _backendApiSubmitDAOReview(this, envelope: envelope);

  /// List DAO reviews
  /// GET /api/dao/reviews
  Future<List<Map<String, dynamic>>> getDAOReviews({
    int limit = 50,
    int offset = 0,
  }) =>
      _backendApiGetDAOReviews(
        this,
        limit: limit,
        offset: offset,
      );

  /// Get a single DAO review by id or wallet address
  /// GET /api/dao/reviews/:id
  @override
  Future<Map<String, dynamic>?> getDAOReview({required String idOrWallet}) =>
      _backendApiGetDAOReview(this, idOrWallet: idOrWallet);

  /// Decide on a DAO review (approve/reject/pending)
  /// POST /api/dao/reviews/:id/decision
  Future<Map<String, dynamic>?> decideDAOReview({
    required String idOrWallet,
    required Map<String, dynamic> envelope,
  }) =>
      _backendApiDecideDAOReview(
        this,
        idOrWallet: idOrWallet,
        envelope: envelope,
      );

  // ==================== Institution & Events (Provisional) ====================

  /// List institutions
  /// GET /api/institutions
  Future<List<Map<String, dynamic>>> listInstitutions(
      {int limit = 50, int offset = 0}) async {
    try {
      if (_institutionsApiAvailable == false) return [];
      final uri =
          Uri.parse('$baseUrl/api/institutions').replace(queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      });
      final response = await _get(uri,
          includeAuth: false, headers: _getHeaders(includeAuth: false));

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
      if (hostUserId != null && hostUserId.trim().isNotEmpty) {
        query['hostUserId'] = hostUserId.trim();
      }
      // Optional auth: include token when present so backend can return `myRole`.
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      return await _performPublicRead<List<Map<String, dynamic>>>(
        liveRead: (candidateBaseUrl) async {
          final base = institutionId == null
              ? '${_normalizeApiBaseUrl(candidateBaseUrl)}/api/events'
              : '${_normalizeApiBaseUrl(candidateBaseUrl)}/api/institutions/$institutionId/events';
          final uri = Uri.parse(base).replace(queryParameters: query);
          final response =
              await _get(uri, headers: _getHeaders(includeAuth: true));

          if (response.statusCode == 200) {
            _eventsApiAvailable = true;
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              final dynamic data = decoded['data'] ?? decoded;
              if (data is Map<String, dynamic>) {
                final list = (data['events'] ??
                    data['items'] ??
                    data['results'] ??
                    const []) as dynamic;
                if (list is List) return List<Map<String, dynamic>>.from(list);
              }
              final list = decoded['events'] ??
                  (decoded['data'] is List ? decoded['data'] : null);
              if (list is List) return List<Map<String, dynamic>>.from(list);
            }
            return [];
          }

          if (response.statusCode == 404) {
            _eventsApiAvailable = false;
            return [];
          }

          if (response.statusCode == 400 && institutionId == null) {
            final page = (offset ~/ (limit <= 0 ? 1 : limit)) + 1;
            final retryQuery = <String, String>{
              'limit': '$limit',
              'page': '$page',
            };
            if (upcoming != null) retryQuery['upcoming'] = '$upcoming';
            if (from != null && from.trim().isNotEmpty) {
              retryQuery['from'] = from.trim();
            }
            if (to != null && to.trim().isNotEmpty) {
              retryQuery['to'] = to.trim();
            }
            if (lat != null) retryQuery['lat'] = lat.toString();
            if (lng != null) retryQuery['lng'] = lng.toString();
            if (radiusKm != null) retryQuery['radiusKm'] = radiusKm.toString();
            if (hostUserId != null && hostUserId.trim().isNotEmpty) {
              retryQuery['hostUserId'] = hostUserId.trim();
            }
            final retryUri = _buildApiUri(candidateBaseUrl, '/api/events',
                queryParameters: retryQuery);
            final retryRes =
                await _get(retryUri, headers: _getHeaders(includeAuth: true));
            if (retryRes.statusCode == 200) {
              _eventsApiAvailable = true;
              final decoded = jsonDecode(retryRes.body);
              if (decoded is Map<String, dynamic>) {
                final dynamic data = decoded['data'] ?? decoded;
                if (data is Map<String, dynamic>) {
                  final list = (data['events'] ??
                      data['items'] ??
                      data['results'] ??
                      const []) as dynamic;
                  if (list is List) {
                    return List<Map<String, dynamic>>.from(list);
                  }
                }
                final list = decoded['events'] ??
                    (decoded['data'] is List ? decoded['data'] : null);
                if (list is List) {
                  return List<Map<String, dynamic>>.from(list);
                }
              }
              return [];
            }

            _eventsApiAvailable = false;
            return [];
          }

          throw Exception('Request failed: ${response.statusCode}');
        },
        snapshotRead: () async {
          var events = await _loadSnapshotDatasetMaps('events');
          events = events.where((entry) {
            if (hostUserId != null &&
                hostUserId.trim().isNotEmpty &&
                (entry['hostUserId'] ?? entry['host_user_id'] ?? '')
                        .toString()
                        .trim() !=
                    hostUserId.trim()) {
              return false;
            }

            if (upcoming == true) {
              final startsAt = DateTime.tryParse(
                (entry['startsAt'] ?? entry['starts_at'] ?? '').toString(),
              );
              if (startsAt != null && startsAt.isBefore(DateTime.now())) {
                return false;
              }
            }

            if (institutionId != null &&
                institutionId.trim().isNotEmpty &&
                (entry['institutionId'] ?? entry['institution_id'] ?? '')
                        .toString()
                        .trim() !=
                    institutionId.trim()) {
              return false;
            }

            return true;
          }).toList(growable: false);

          final start = offset.clamp(0, events.length).toInt();
          final end = (start + limit).clamp(0, events.length).toInt();
          return events.sublist(start, end);
        },
      );
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
      return await _performPublicRead<KubusEvent?>(
        liveRead: (candidateBaseUrl) async {
          final decoded = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/events/$id',
            includeAuth: true,
            allowOrbitFallback: false,
          );
          final payload = decoded['data'] ?? decoded;
          final eventRaw = (payload is Map<String, dynamic>)
              ? (payload['event'] ?? payload['data'] ?? payload)
              : null;
          if (eventRaw is Map<String, dynamic>) {
            return KubusEvent.fromJson(eventRaw);
          }
          return null;
        },
        snapshotRead: () async {
          final events = await _loadSnapshotDatasetMaps('events');
          for (final entry in events) {
            if ((entry['id'] ?? '').toString().trim() == id.trim()) {
              return KubusEvent.fromJson(entry);
            }
          }
          return null;
        },
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getEvent failed: $e');
      rethrow;
    }
  }

  /// Create an event
  /// POST /api/events
  Future<KubusEvent?> createEvent(Map<String, dynamic> payload) async {
    _throwIfIpfsFallbackUnavailable('Event publishing');
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/events');
      final response =
          await _post(uri, headers: _getHeaders(), body: jsonEncode(payload));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final eventRaw = _extractSuccessfulEntityMap(
          response,
          preferredKeys: const <String>['event'],
        );
        if (eventRaw != null) {
          return KubusEvent.fromJson(eventRaw);
        }
        return null;
      }
      throw Exception(
          'Failed to create event: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createEvent failed: $e');
      rethrow;
    }
  }

  /// Update an event
  /// PUT /api/events/:id
  Future<KubusEvent?> updateEvent(
      String id, Map<String, dynamic> updates) async {
    _throwIfIpfsFallbackUnavailable('Event editing');
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/events/$id');
      final response = await _put(uri,
          headers: _getHeaders(),
          body: jsonEncode(updates),
          isIdempotent: true);
      if (response.statusCode == 200) {
        final eventRaw = _extractSuccessfulEntityMap(
          response,
          preferredKeys: const <String>['event'],
        );
        if (eventRaw != null) {
          return KubusEvent.fromJson(eventRaw);
        }
        try {
          return await getEvent(id);
        } catch (_) {
          // Keep save flows from surfacing a false failure if the update
          // succeeded but the response payload shape was unexpected.
        }
        return null;
      }
      throw Exception(
          'Failed to update event: ${response.statusCode} ${response.body}');
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
      final response =
          await _delete(uri, headers: _getHeaders(), isIdempotent: true);
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        return true;
      }
      throw Exception(
          'Failed to delete event: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteEvent failed: $e');
      rethrow;
    }
  }

  /// List exhibitions for an event
  /// GET /api/events/:id/exhibitions
  Future<List<Exhibition>> listEventExhibitions(String eventId,
      {int limit = 50, int offset = 0}) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/events/$eventId/exhibitions')
          .replace(queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      });
      final decoded =
          await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
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
      if (eventId != null && eventId.trim().isNotEmpty) {
        qp['eventId'] = eventId.trim();
      }
      if (mine == true) qp['mine'] = 'true';
      if (from != null && from.trim().isNotEmpty) qp['from'] = from.trim();
      if (to != null && to.trim().isNotEmpty) qp['to'] = to.trim();
      if (lat != null) qp['lat'] = lat.toString();
      if (lng != null) qp['lng'] = lng.toString();
      if (radiusKm != null) qp['radiusKm'] = radiusKm.toString();
      return await _performPublicRead<List<Exhibition>>(
        liveRead: (candidateBaseUrl) async {
          final decoded = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/exhibitions',
            queryParameters: qp,
            includeAuth: true,
            allowOrbitFallback: false,
          );
          final payload = decoded['data'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            final list = payload['exhibitions'] ?? payload['items'];
            if (list is List) {
              return list
                  .whereType<Map<String, dynamic>>()
                  .map(Exhibition.fromJson)
                  .toList(growable: false);
            }
          }
          return const <Exhibition>[];
        },
        snapshotRead: () async {
          var exhibitions = (await _loadSnapshotDatasetMaps('exhibitions'))
              .map(Exhibition.fromJson)
              .where((entry) {
            if (eventId != null &&
                eventId.trim().isNotEmpty &&
                (entry.eventId ?? '').trim() != eventId.trim()) {
              return false;
            }
            return true;
          }).toList(growable: false);

          final start = offset.clamp(0, exhibitions.length).toInt();
          final end = (start + limit).clamp(0, exhibitions.length).toInt();
          return exhibitions.sublist(start, end);
        },
      );
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
      return await _performPublicRead<Exhibition?>(
        liveRead: (candidateBaseUrl) async {
          final decoded = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/exhibitions/$id',
            includeAuth: true,
            allowOrbitFallback: false,
          );
          final payload = decoded['data'] ?? decoded;
          final exhibitionRaw = (payload is Map<String, dynamic>)
              ? (payload['exhibition'] ?? payload['data'] ?? payload)
              : null;
          if (exhibitionRaw is Map<String, dynamic>) {
            return Exhibition.fromJson(exhibitionRaw);
          }
          return null;
        },
        snapshotRead: () async {
          final exhibitions = await _loadSnapshotDatasetMaps('exhibitions');
          for (final entry in exhibitions) {
            if ((entry['id'] ?? '').toString().trim() == id.trim()) {
              return Exhibition.fromJson(entry);
            }
          }
          return null;
        },
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getExhibition failed: $e');
      rethrow;
    }
  }

  /// Create exhibition
  /// POST /api/exhibitions
  Future<Exhibition?> createExhibition(Map<String, dynamic> payload) async {
    _throwIfIpfsFallbackUnavailable('Exhibition publishing');
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/exhibitions');
      final response =
          await _post(uri, headers: _getHeaders(), body: jsonEncode(payload));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final exhibitionRaw = _extractSuccessfulEntityMap(
          response,
          preferredKeys: const <String>['exhibition'],
        );
        if (exhibitionRaw != null) {
          return Exhibition.fromJson(exhibitionRaw);
        }
        return null;
      }
      throw Exception(
          'Failed to create exhibition: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.createExhibition failed: $e');
      rethrow;
    }
  }

  /// Update exhibition
  /// PUT /api/exhibitions/:id
  Future<Exhibition?> updateExhibition(
      String id, Map<String, dynamic> updates) async {
    _throwIfIpfsFallbackUnavailable('Exhibition editing');
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/exhibitions/$id');
      if (kDebugMode && AppConfig.enableNetworkLogging) {
        final cover = updates['coverUrl'] ??
            updates['cover_url'] ??
            updates['coverImageUrl'] ??
            updates['cover_image_url'];
        if (cover != null) {
          AppConfig.networkLog(
            'PUT',
            uri.toString(),
            data: <String, dynamic>{
              'coverUrl': cover,
            },
          );
        }
      }
      final response = await _put(uri,
          headers: _getHeaders(),
          body: jsonEncode(updates),
          isIdempotent: true);
      if (response.statusCode == 200) {
        final exhibitionRaw = _extractSuccessfulEntityMap(
          response,
          preferredKeys: const <String>['exhibition'],
        );
        if (exhibitionRaw != null) {
          return Exhibition.fromJson(exhibitionRaw);
        }
        try {
          return await getExhibition(id);
        } catch (_) {
          // A successful update should still behave like success even if the
          // backend returned a slightly unexpected response envelope.
        }
        return null;
      }
      throw Exception(
          'Failed to update exhibition: ${response.statusCode} ${response.body}');
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
      final response =
          await _delete(uri, headers: _getHeaders(), isIdempotent: true);
      if (response.statusCode == 200 || response.statusCode == 204) return true;
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        return true;
      }
      throw Exception(
          'Failed to delete exhibition: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.deleteExhibition failed: $e');
      rethrow;
    }
  }

  /// Link artworks to an exhibition
  /// POST /api/exhibitions/:id/artworks { artworkIds: [...] }
  Future<Map<String, dynamic>> linkExhibitionArtworks(
      String exhibitionId, List<String> artworkIds) async {
    await _ensureAuthBeforeRequest();
    final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/artworks');
    final response = await _post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode({'artworkIds': artworkIds}),
      isIdempotent: true,
    );
    if (_isSuccessStatus(response.statusCode)) {
      return response.body.isNotEmpty
          ? (jsonDecode(response.body) as Map<String, dynamic>)
          : {'success': true};
    }
    throw Exception(
        'Failed to link exhibition artworks: ${response.statusCode} ${response.body}');
  }

  /// Unlink a single artwork from an exhibition
  /// DELETE /api/exhibitions/:id/artworks/:artworkId
  Future<Map<String, dynamic>> unlinkExhibitionArtwork(
      String exhibitionId, String artworkId) async {
    await _ensureAuthBeforeRequest();
    final uri =
        Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/artworks/$artworkId');
    final response =
        await _delete(uri, headers: _getHeaders(), isIdempotent: true);
    if (_isSuccessStatus(response.statusCode)) {
      return response.body.isNotEmpty
          ? (jsonDecode(response.body) as Map<String, dynamic>)
          : {'success': true};
    }
    throw Exception(
        'Failed to unlink exhibition artwork: ${response.statusCode} ${response.body}');
  }

  /// Link markers to an exhibition
  /// POST /api/exhibitions/:id/markers { markerIds: [...] }
  Future<Map<String, dynamic>> linkExhibitionMarkers(
      String exhibitionId, List<String> markerIds) async {
    await _ensureAuthBeforeRequest();
    final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/markers');
    final response = await _post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode({'markerIds': markerIds}),
      isIdempotent: true,
    );
    if (_isSuccessStatus(response.statusCode)) {
      return response.body.isNotEmpty
          ? (jsonDecode(response.body) as Map<String, dynamic>)
          : {'success': true};
    }
    throw Exception(
        'Failed to link exhibition markers: ${response.statusCode} ${response.body}');
  }

  /// Unlink a single marker from an exhibition
  /// DELETE /api/exhibitions/:id/markers/:markerId
  Future<Map<String, dynamic>> unlinkExhibitionMarker(
      String exhibitionId, String markerId) async {
    await _ensureAuthBeforeRequest();
    final uri =
        Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/markers/$markerId');
    final response =
        await _delete(uri, headers: _getHeaders(), isIdempotent: true);
    if (_isSuccessStatus(response.statusCode)) {
      return response.body.isNotEmpty
          ? (jsonDecode(response.body) as Map<String, dynamic>)
          : {'success': true};
    }
    throw Exception(
        'Failed to unlink exhibition marker: ${response.statusCode} ${response.body}');
  }

  /// Fetch exhibition POAP status
  /// GET /api/exhibitions/:id/poap
  Future<ExhibitionPoapStatus?> getExhibitionPoap(String exhibitionId) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri = Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/poap');
      final decoded =
          await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
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
  Future<ExhibitionPoapStatus?> claimExhibitionPoap(
    String exhibitionId, {
    String? attendanceMarkerId,
    String? claimProofToken,
    String? proofSource,
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri =
          Uri.parse('$baseUrl/api/exhibitions/$exhibitionId/poap/claim');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({
          if ((attendanceMarkerId ?? '').trim().isNotEmpty)
            'attendanceMarkerId': attendanceMarkerId!.trim(),
          if ((claimProofToken ?? '').trim().isNotEmpty)
            'claimProofToken': claimProofToken!.trim(),
          if ((proofSource ?? '').trim().isNotEmpty)
            'proofSource': proofSource!.trim(),
        }),
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      if (_isSuccessStatus(response.statusCode)) {
        if (decoded is Map<String, dynamic>) {
          final payload = decoded['data'] ?? decoded;
          if (payload is Map<String, dynamic>) {
            return ExhibitionPoapStatus.fromJson(payload);
          }
        }
        return null;
      }
      throw BackendApiRequestException(
        statusCode: response.statusCode,
        path: uri.path,
        body: response.body,
      );
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
      final uri =
          Uri.parse('$baseUrl/api/collab/$entityType/$entityId/invites');
      final response = await _post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({'invited': invitedIdentifier, 'role': role}),
      );
      if (_isSuccessStatus(response.statusCode)) {
        final inviteRaw = _extractSuccessfulEntityMap(
          response,
          preferredKeys: const <String>['invite'],
        );
        if (inviteRaw != null) {
          return CollabInvite.fromJson(inviteRaw);
        }
        return null;
      }
      throw Exception(
          'Failed to invite collaborator: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.inviteCollaborator failed: $e');
      rethrow;
    }
  }

  /// List collaborators for an entity
  /// GET /api/collab/:entityType/:entityId/members
  Future<List<CollabMember>> listCollaborators(
      String entityType, String entityId) async {
    try {
      // optional auth
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}
      final uri =
          Uri.parse('$baseUrl/api/collab/$entityType/$entityId/members');
      final decoded =
          await _fetchJson(uri, includeAuth: true, allowOrbitFallback: false);
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
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : const <String, dynamic>{};
        final payload = decoded is Map<String, dynamic>
            ? (decoded['data'] ?? decoded)
            : null;
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
      final response =
          await _post(uri, headers: _getHeaders(), isIdempotent: true);
      if (_isSuccessStatus(response.statusCode)) return true;
      throw Exception(
          'Failed to accept invite: ${response.statusCode} ${response.body}');
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
      final response =
          await _post(uri, headers: _getHeaders(), isIdempotent: true);
      if (_isSuccessStatus(response.statusCode)) return true;
      throw Exception(
          'Failed to decline invite: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.declineInvite failed: $e');
      rethrow;
    }
  }

  /// Update collaborator role
  /// PATCH /api/collab/:entityType/:entityId/members/:memberUserId
  Future<bool> updateCollaboratorRole(String entityType, String entityId,
      String memberUserId, String role) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse(
          '$baseUrl/api/collab/$entityType/$entityId/members/$memberUserId');
      final response = await _patch(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({'role': role}),
        isIdempotent: true,
      );
      if (_isSuccessStatus(response.statusCode)) return true;
      throw Exception(
          'Failed to update collaborator role: ${response.statusCode} ${response.body}');
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.updateCollaboratorRole failed: $e');
      rethrow;
    }
  }

  /// Remove a collaborator
  /// DELETE /api/collab/:entityType/:entityId/members/:memberUserId
  Future<bool> removeCollaborator(
      String entityType, String entityId, String memberUserId) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse(
          '$baseUrl/api/collab/$entityType/$entityId/members/$memberUserId');
      final response =
          await _delete(uri, headers: _getHeaders(), isIdempotent: true);
      if (_isSuccessStatus(response.statusCode)) return true;
      throw Exception(
          'Failed to remove collaborator: ${response.statusCode} ${response.body}');
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
        throw Exception(
            'Failed to update achievement progress: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.updateAchievementProgress failed: $e');
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
        throw Exception(
            'Failed to get achievement stats: ${response.statusCode}');
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
        Uri.parse(
            '$baseUrl/api/achievements/leaderboard?limit=$limit&type=$type'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
      } else {
        throw Exception('Failed to get leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.getAchievementLeaderboard failed: $e');
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
    bool compress = true,
    UploadCompressionPolicy? compressionPolicy,
    void Function(UploadCompressionProgress progress)? onCompressionProgress,
  }) async {
    return _backendApiUploadFileImpl(
      this,
      fileBytes: fileBytes,
      fileName: fileName,
      fileType: fileType,
      metadata: metadata,
      walletAddress: walletAddress,
      compress: compress,
      compressionPolicy: compressionPolicy,
      onCompressionProgress: onCompressionProgress,
    );
  }

  /// Upload a marker cover image and return the best available storage URL.
  Future<String?> uploadMarkerCoverImage({
    required List<int> fileBytes,
    required String fileName,
    String fileType = 'image',
    String? walletAddress,
    String source = 'map_marker',
    bool compress = true,
    UploadCompressionPolicy? compressionPolicy,
    void Function(UploadCompressionProgress progress)? onCompressionProgress,
  }) async {
    return _backendApiUploadMarkerCoverImageImpl(
      this,
      fileBytes: fileBytes,
      fileName: fileName,
      fileType: fileType,
      walletAddress: walletAddress,
      source: source,
      compress: compress,
      compressionPolicy: compressionPolicy,
      onCompressionProgress: onCompressionProgress,
    );
  }

  /// Upload avatar specifically to profile avatars endpoint
  /// POST /api/profiles/avatars
  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
    bool compress = true,
    UploadCompressionPolicy? compressionPolicy,
    void Function(UploadCompressionProgress progress)? onCompressionProgress,
  }) async {
    return _backendApiUploadAvatarToProfileImpl(
      this,
      fileBytes: fileBytes,
      fileName: fileName,
      fileType: fileType,
      metadata: metadata,
      compress: compress,
      compressionPolicy: compressionPolicy,
      onCompressionProgress: onCompressionProgress,
    );
  }

  // ==================== Health Check ====================

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
      final preferredCanonical =
          WalletUtils.canonical(_preferredWalletCanonical ?? '');
      final isForPreferredWallet = requestedCanonical.isNotEmpty &&
          preferredCanonical.isNotEmpty &&
          requestedCanonical == preferredCanonical;
      final isImplicitSelfRequest = requestedWallet.isEmpty;
      final snapshotWalletFilter = requestedWallet.isNotEmpty
          ? requestedWallet
          : (isImplicitSelfRequest
              ? (_preferredWalletCanonical ?? _authWalletCanonical ?? '')
              : '');

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

      return await _performPublicRead<List<Map<String, dynamic>>>(
        liveRead: (candidateBaseUrl) async {
          final jsonData = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/collections',
            queryParameters: queryParams,
            includeAuth: includeAuth,
            allowOrbitFallback: true,
          );

          final rawData = jsonData['data'];
          if (rawData is List) {
            return rawData
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(growable: false);
          }
          if (rawData is Map<String, dynamic> && rawData['data'] is List) {
            return (rawData['data'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(growable: false);
          }
          throw Exception('Unexpected collections response shape');
        },
        snapshotRead: () async {
          if (isImplicitSelfRequest && snapshotWalletFilter.isEmpty) {
            return const <Map<String, dynamic>>[];
          }

          var collections = await _loadSnapshotDatasetMaps('collections');
          if (snapshotWalletFilter.isNotEmpty) {
            final canonicalRequested =
                WalletUtils.canonical(snapshotWalletFilter);
            collections = collections.where((entry) {
              final candidate = WalletUtils.canonical(
                entry['walletAddress'] ??
                    entry['wallet_address'] ??
                    entry['ownerWalletAddress'] ??
                    entry['owner_wallet_address'],
              );
              return candidate == canonicalRequested;
            }).toList(growable: false);
          }

          final start =
              ((page - 1) * limit).clamp(0, collections.length).toInt();
          final end = (start + limit).clamp(0, collections.length).toInt();
          return collections.sublist(start, end);
        },
      );
    } catch (e) {
      AppConfig.debugPrint('BackendApiService.getCollections failed: $e');
      return [];
    }
  }

  /// Get collection by ID with artworks
  /// GET /api/collections/:id
  Future<Map<String, dynamic>> getCollection(String collectionId) async {
    try {
      try {
        await _ensureAuthWithStoredWallet();
      } catch (_) {}

      return await _performPublicRead<Map<String, dynamic>>(
        liveRead: (candidateBaseUrl) async {
          final jsonData = await _fetchJsonFromBaseUrl(
            candidateBaseUrl,
            '/api/collections/$collectionId',
            includeAuth: true,
            allowOrbitFallback: true,
          );

          final data = jsonData['data'];
          if (data is Map<String, dynamic>) {
            return data;
          }
          if (data is Map) {
            return Map<String, dynamic>.from(data);
          }
          throw Exception('Unexpected collection response shape');
        },
        snapshotRead: () async {
          final collections = await _loadSnapshotDatasetMaps('collections');
          for (final entry in collections) {
            if ((entry['id'] ?? '').toString().trim() == collectionId.trim()) {
              return entry;
            }
          }
          throw Exception('Collection not found');
        },
      );
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
    _throwIfIpfsFallbackUnavailable('Collection publishing');
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
        final payload = _extractSuccessfulEntityMap(
              response,
              preferredKeys: const <String>['collection'],
            ) ??
            _decodeResponseMap(response) ??
            const <String, dynamic>{};
        return payload;
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
    _throwIfIpfsFallbackUnavailable('Collection editing');
    try {
      await _ensureAuthBeforeRequest();
      final payload = <String, dynamic>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (isPublic != null) 'isPublic': isPublic,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      };

      if (kDebugMode &&
          AppConfig.enableNetworkLogging &&
          payload.containsKey('thumbnailUrl')) {
        AppConfig.networkLog(
          'PUT',
          '$baseUrl/api/collections/$collectionId',
          data: <String, dynamic>{
            'thumbnailUrl': payload['thumbnailUrl'],
          },
        );
      }

      final response = await _put(
        Uri.parse('$baseUrl/api/collections/$collectionId'),
        headers: _getHeaders(),
        body: jsonEncode(payload),
        isIdempotent: true,
      );

      if (response.statusCode == 200) {
        final payload = _extractSuccessfulEntityMap(
              response,
              preferredKeys: const <String>['collection'],
            ) ??
            _decodeResponseMap(response) ??
            const <String, dynamic>{};
        return payload;
      }
      throw Exception(
          'Failed to update collection: ${response.statusCode} ${response.body}');
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
        throw Exception(
            'Failed to add artwork to collection: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.addArtworkToCollection failed: $e');
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
        throw Exception(
            'Failed to remove artwork from collection: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.removeArtworkFromCollection failed: $e');
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

      final uri = Uri.parse('$baseUrl/api/notifications')
          .replace(queryParameters: queryParams);
      final response = await _get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final notifications = jsonData['data'] as List<dynamic>;
        return notifications.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception(
            'Failed to fetch notifications: ${response.statusCode}');
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
      AppConfig.debugPrint(
          'BackendApiService.getUnreadNotificationCount failed: $e');
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
        throw Exception(
            'Failed to mark notification as read: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.markNotificationAsRead failed: $e');
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
        throw Exception(
            'Failed to mark all notifications as read: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.markAllNotificationsAsRead failed: $e');
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
        throw Exception(
            'Failed to delete notification: ${response.statusCode}');
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
        throw Exception(
            'Failed to delete account data: ${response.statusCode}');
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
    String type =
        'all', // all, profiles, artworks, institutions, collections, posts
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

      final uri = Uri.parse('$baseUrl/api/search')
          .replace(queryParameters: queryParams);
      final response = await _get(uri,
          includeAuth: false, headers: _getHeaders(includeAuth: false));

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

      final uri = Uri.parse('$baseUrl/api/search/suggestions')
          .replace(queryParameters: queryParams);
      final key = _rateLimitKey('GET', uri);
      if (_isRateLimited(key)) {
        throw Exception(_rateLimitMessage(key));
      }

      final headers = _getHeaders(includeAuth: true);
      dynamic data;

      Future<dynamic> tryFetch(Uri target) async {
        final response =
            await _get(target, headers: headers, includeAuth: true);
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
        final dynamic suggestions =
            data['suggestions'] ?? data['data'] ?? data['results'];
        if (suggestions is List) {
          return suggestions.whereType<Map<String, dynamic>>().toList();
        }
      }
      AppConfig.debugPrint(
          'BackendApiService.getSearchSuggestions: unexpected payload for "$query"');
      return const [];
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.getSearchSuggestions failed for "$query": $e');
      return const [];
    }
  }

  /// Get trending search terms
  /// GET /api/search/trending
  Future<List<Map<String, dynamic>>> getTrendingSearches(
      {int limit = 10}) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/search/trending')
          .replace(queryParameters: queryParams);
      final response = await _get(uri,
          includeAuth: false, headers: _getHeaders(includeAuth: false));

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
  /// POST /api/messages/:conversationId/messages/:messageId/reactions
  Future<void> addMessageReaction(
      String conversationId, String messageId, String emoji) async {
    try {
      final response = await _post(
        Uri.parse(
            '$baseUrl/api/messages/$conversationId/messages/$messageId/reactions'),
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
  /// DELETE /api/messages/:conversationId/messages/:messageId/reactions
  Future<void> removeMessageReaction(
      String conversationId, String messageId, String emoji) async {
    try {
      final response = await _delete(
        Uri.parse(
            '$baseUrl/api/messages/$conversationId/messages/$messageId/reactions'),
        headers: _getHeaders(),
        body: jsonEncode({'emoji': emoji}),
        isIdempotent: true,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove reaction: ${response.statusCode}');
      }
    } catch (e) {
      AppConfig.debugPrint(
          'BackendApiService.removeMessageReaction failed: $e');
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

  double doubleVal(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return fallback;
    final parsed = double.tryParse(s);
    return parsed ?? fallback;
  }

  int intVal(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return fallback;
    final parsed = int.tryParse(s);
    return parsed ?? fallback;
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
  if ((artworkId == null || artworkId.isEmpty) &&
      json['artwork'] is Map<String, dynamic>) {
    artworkId = stringVal((json['artwork'] as Map<String, dynamic>)['id']);
  }

  final normalized = <String, dynamic>{
    'id': json['id'] ?? json['_id'] ?? '',
    'name': json['name'] ?? json['title'] ?? json['label'] ?? '',
    'description': json['description'] ?? json['summary'] ?? '',
    'latitude': doubleVal(json['latitude'] ?? json['lat'], 0.0),
    'longitude': doubleVal(json['longitude'] ?? json['lng'], 0.0),
    'artworkId': artworkId,
    'modelCID': json['modelCID'] ?? json['model_cid'],
    'modelURL': json['modelURL'] ?? json['model_url'],
    'storageProvider':
        json['storageProvider'] ?? json['storage_provider'] ?? 'hybrid',
    'scale': doubleVal(json['scale'], 1.0),
    'rotation': json['rotation'],
    'enableAnimation': json['enableAnimation'] ?? json['animate'] ?? false,
    'animationName': json['animationName'] ?? json['animation_name'],
    'enablePhysics': json['enablePhysics'] ?? false,
    'enableInteraction': json['enableInteraction'] ?? true,
    'metadata': mergedMeta,
    'tags': json['tags'],
    'category':
        json['category'] ?? json['markerType'] ?? json['type'] ?? 'General',
    'createdAt': json['createdAt'] ??
        json['created_at'] ??
        DateTime.now().toIso8601String(),
    'updatedAt': json['updatedAt'] ?? json['updated_at'],
    'createdBy': json['createdBy'] ?? json['created_by'] ?? 'system',
    'viewCount': intVal(json['viewCount'] ?? json['views'], 0),
    'interactionCount':
        intVal(json['interactionCount'] ?? json['interactions'], 0),
    'activationRadius':
        doubleVal(json['activationRadius'] ?? json['activation_radius'], 50.0),
    'requiresProximity':
        json['requiresProximity'] ?? json['requires_proximity'] ?? true,
    'isPublic': json['isPublic'] ?? json['is_public'] ?? true,
    'isActive': json['isActive'] ?? json['is_active'] ?? true,
    'markerType': json['markerType'] ?? json['type'],
    'promotion': PromotionMetadata.readFrom(
      json,
      fallbackMaps: <Map<String, dynamic>?>[mergedMeta],
    ).toJson(),
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
  if (json['promotion'] is Map) {
    merge({'promotion': json['promotion']});
  }

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

Artwork parseArtworkFromBackendJson(Map<String, dynamic> json) {
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
      return convert(raw
          .cast<dynamic, dynamic>()
          .map((key, value) => MapEntry(key.toString(), value)));
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
    addMeta(
        'creators',
        json['creators'] ??
            json['artists'] ??
            json['collaborators'] ??
            json['contributors']);
    addMeta(
      'creatorWallets',
      json['creatorWallets'] ??
          json['creatorWalletAddresses'] ??
          json['walletAddresses'] ??
          json['wallets'],
    );
    addMeta(
      'creator_name_byline',
      json['creator_name_byline'] ??
          json['creatorNameByline'] ??
          json['creator_byline'] ??
          json['creatorByline'] ??
          json['artist_name_byline'] ??
          json['artistNameByline'] ??
          json['artist_byline'] ??
          json['artistByline'],
    );
    addMeta('locationName', json['locationName']);
    addMeta('nft', json['nft']);
    addMeta('price', json['price']);
    addMeta('currency', json['currency']);
    addMeta('isForSale', json['isForSale']);
    addMeta('imageCID', json['imageCID'] ?? json['image_cid']);
    addMeta('publicRef', json['publicRef'] ?? json['public_ref']);
    addMeta(
        'canonicalSource', json['canonicalSource'] ?? json['canonical_source']);
    addMeta('publicManifestCid',
        json['publicManifestCid'] ?? json['public_manifest_cid']);
    addMeta('publicRecordCid',
        json['publicRecordCid'] ?? json['public_record_cid']);
    addMeta(
        'publicRegistry', json['publicRegistry'] ?? json['public_registry']);
    addMeta('cidRegistry', json['cidRegistry'] ?? json['cid_registry']);
    addMeta('poap', json['poap']);
    addMeta('promotion', json['promotion']);

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

  final nftJson = json['nft'] is Map<String, dynamic>
      ? (json['nft'] as Map<String, dynamic>)
      : (json['nft'] is Map
          ? Map<String, dynamic>.from(json['nft'] as Map)
          : null);

  final arAsset =
      (json['arAsset'] ?? json['ar_asset']) as Map<String, dynamic>?;
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
  final hasLocation = (latCandidate != null && lngCandidate != null) ||
      (locationLat != null && locationLng != null);
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
  final normalizedImageUrl = MediaUrlResolver.resolveDisplayUrl(rawImage) ??
      MediaUrlResolver.resolveDisplayUrl(imageCid) ??
      StorageConfig.resolveUrl(imageCid);
  final arScale =
      doubleVal(json['arScale'] ?? json['ar_scale'] ?? arAsset?['scale']);
  final arRotation = normalizeRotation(
    json['arRotation'] ??
        json['ar_rotation'] ??
        json['rotation'] ??
        arAsset?['rotation'],
  );

  final markerIdCandidate = nullableString(
    json['arMarkerId'] ?? json['markerId'] ?? json['marker_id'],
  );

  final arConfigId = nullableString(
    json['arConfigId'] ??
        json['ar_config_id'] ??
        (json['arConfig'] is Map<String, dynamic>
            ? (json['arConfig'] as Map<String, dynamic>)['id']
            : null) ??
        (json['ar_config'] is Map<String, dynamic>
            ? (json['ar_config'] as Map<String, dynamic>)['id']
            : null),
  );

  final arStatusRaw = nullableString(json['arStatus'] ?? json['ar_status']);
  final arStatus = ArtworkArStatusApi.fromApiValue(arStatusRaw);

  List<String> parseStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return <String>[];
      if (trimmed.startsWith('[')) {
        try {
          final parsed = jsonDecode(trimmed);
          if (parsed is List) {
            return parsed
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (_) {}
      }
      return trimmed
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  final galleryUrls = parseStringList(
    json['galleryUrls'] ??
        json['gallery_urls'] ??
        json['gallery'] ??
        json['mediaGallery'],
  ).map((u) => MediaUrlResolver.resolveDisplayUrl(u) ?? u).toList();

  List<Map<String, dynamic>> parseGalleryMeta(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const <Map<String, dynamic>>[];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
        }
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
    return const <Map<String, dynamic>>[];
  }

  final galleryMeta =
      parseGalleryMeta(json['galleryMeta'] ?? json['gallery_meta']);

  final poapJson = json['poap'] is Map<String, dynamic>
      ? (json['poap'] as Map<String, dynamic>)
      : (json['poap'] is Map
          ? Map<String, dynamic>.from(json['poap'] as Map)
          : null);
  final poapModeRaw = pickString([
    json['poapMode'],
    json['poap_mode'],
    poapJson?['mode'],
    poapJson?['poapMode'],
  ]);
  final poapMode = ArtworkPoapModeApi.fromApiValue(poapModeRaw);
  final poapEnabled = boolVal(poapJson?['enabled'] ??
          json['poapEnabled'] ??
          json['poap_enabled']) ??
      (poapMode != ArtworkPoapMode.none);
  final poapEventId = pickString([
    poapJson?['eventId'],
    poapJson?['event_id'],
    json['poapEventId'],
    json['poap_event_id'],
  ]);
  final poapClaimUrl = pickString([
    poapJson?['claimUrl'],
    poapJson?['claim_url'],
    json['poapClaimUrl'],
    json['poap_claim_url'],
  ]);
  final poapValidFrom = parseDate(poapJson?['validFrom'] ??
      poapJson?['valid_from'] ??
      json['poapValidFrom'] ??
      json['poap_valid_from']);
  final poapValidTo = parseDate(poapJson?['validTo'] ??
      poapJson?['valid_to'] ??
      json['poapValidTo'] ??
      json['poap_valid_to']);
  final poapRewardAmount = intVal(poapJson?['rewardAmount'] ??
      poapJson?['reward_amount'] ??
      json['poapRewardAmount'] ??
      json['poap_reward_amount']);
  final poapTitle = pickString([
    poapJson?['title'],
    poapJson?['poapTitle'],
    json['poapTitle'],
    json['poap_title'],
  ]);
  final poapDescription = pickString([
    poapJson?['description'],
    poapJson?['poapDescription'],
    json['poapDescription'],
    json['poap_description'],
  ]);
  final poapImageRaw = pickString([
    poapJson?['imageUrl'],
    poapJson?['image_url'],
    poapJson?['poapImageUrl'],
    json['poapImageUrl'],
    json['poap_image_url'],
  ]);
  final poapImageUrl = poapImageRaw != null
      ? (MediaUrlResolver.resolveDisplayUrl(poapImageRaw) ?? poapImageRaw)
      : null;

  final walletAddress =
      nullableString(json['walletAddress'] ?? json['wallet_address']);
  final isPublic = boolVal(json['isPublic'] ?? json['is_public']) ?? true;
  final isActive = boolVal(json['isActive'] ?? json['is_active']) ?? true;
  final isForSale = boolVal(json['isForSale'] ?? json['is_for_sale']) ?? false;
  final price = doubleVal(json['price']);
  final currency = nullableString(json['currency']);
  final isNft = boolVal(
        json['isNft'] ?? json['is_nft'] ?? nftJson,
      ) ??
      (nftJson != null);
  final nftMintAddress = pickString([
    json['nftMintAddress'],
    json['nft_mint_address'],
    nftJson?['mintAddress'],
    nftJson?['mint_address'],
  ]);
  final nftMetadataUri = pickString([
    json['nftMetadataUri'],
    json['nft_metadata_uri'],
    nftJson?['metadataUri'],
    nftJson?['metadata_uri'],
    nftJson?['uri'],
  ]);
  final createdAt =
      parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now();
  final updatedAt = parseDate(json['updatedAt'] ?? json['updated_at']);
  final discoveredAt = parseDate(json['discoveredAt'] ?? json['discovered_at']);
  final discoveryUserId =
      nullableString(json['discoveryUserId'] ?? json['discovery_user_id']);
  final isFavoriteByCurrentUser =
      boolVal(json['isFavoriteByCurrentUser'] ?? json['isFavorited']) ?? false;
  final discoveredFlag = boolVal(
        json['isDiscovered'] ?? json['discovered'] ?? json['is_discovered'],
      ) ??
      false;

  ArtworkStatus status = ArtworkStatus.undiscovered;
  final statusRaw = nullableString(
    json['status'] ?? json['artworkStatus'] ?? json['artwork_status'],
  );
  if (statusRaw != null) {
    final normalized =
        statusRaw.toLowerCase().trim().replaceAll(RegExp(r'[^a-z]'), '');

    if (normalized == 'favorite' || normalized == 'favourite') {
      status = ArtworkStatus.favorite;
    } else if (normalized == 'undiscovered' || normalized == 'notdiscovered') {
      status = ArtworkStatus.undiscovered;
    } else if (normalized == 'discovered' || normalized == 'discover') {
      status = ArtworkStatus.discovered;
    } else if (normalized.contains('favorite')) {
      status = ArtworkStatus.favorite;
    } else if (normalized.contains('undiscover') ||
        normalized.contains('notdiscover')) {
      status = ArtworkStatus.undiscovered;
    } else if (normalized.contains('discover')) {
      status = ArtworkStatus.discovered;
    }
  }
  if (isFavoriteByCurrentUser) {
    status = ArtworkStatus.favorite;
  } else if (status != ArtworkStatus.favorite &&
      (discoveredFlag || discoveredAt != null)) {
    status = ArtworkStatus.discovered;
  }
  final promotion = PromotionMetadata.readFrom(
    json,
    fallbackMaps: <Map<String, dynamic>?>[metadata],
  );

  return Artwork(
    id: id,
    walletAddress: walletAddress,
    title: title,
    artist: artist,
    description: stringVal(json['description'] ?? json['summary'] ?? '', ''),
    imageUrl: normalizedImageUrl,
    galleryUrls: galleryUrls,
    galleryMeta: galleryMeta,
    position: LatLng(lat, lng),
    status: status,
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
    arConfigId: arConfigId,
    arStatus: arStatus,
    arScale: arScale,
    arRotation: arRotation,
    arEnableAnimation: boolVal(
      json['arEnableAnimation'] ??
          json['enableAnimation'] ??
          json['animationEnabled'] ??
          arAsset?['enableAnimation'],
    ),
    arAnimationName: nullableString(
      json['arAnimationName'] ?? json['animationName'] ?? arAsset?['animation'],
    ),
    isPublic: isPublic,
    isActive: isActive,
    isForSale: isForSale,
    price: price,
    currency: currency,
    isNft: isNft,
    nftMintAddress: nftMintAddress,
    nftMetadataUri: nftMetadataUri,
    createdAt: createdAt,
    updatedAt: updatedAt,
    discoveredAt: discoveredAt,
    discoveryUserId: discoveryUserId,
    tags: resolvedTags,
    likesCount: likesCount,
    commentsCount: commentsCount,
    viewsCount: viewsCount,
    discoveryCount: discoveryCount,
    isLikedByCurrentUser:
        boolVal(json['isLikedByCurrentUser'] ?? json['isLiked']) ?? false,
    isFavoriteByCurrentUser: isFavoriteByCurrentUser,
    poapMode: poapMode,
    poapEnabled: poapEnabled,
    poapEventId: poapEventId,
    poapClaimUrl: poapClaimUrl,
    poapValidFrom: poapValidFrom,
    poapValidTo: poapValidTo,
    poapRewardAmount: poapRewardAmount,
    poapTitle: poapTitle,
    poapDescription: poapDescription,
    poapImageUrl: poapImageUrl,
    metadata: metadata.isEmpty ? null : metadata,
    promotion: promotion,
  );
}

CommunityLikeUser _communityLikeUserFromBackendJson(Map<String, dynamic> json) {
  return _backendApiCommunityLikeUserFromBackendJson(json);
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
  return _backendApiBuildCommunityPostPayload(
    content: content,
    category: category,
    mediaUrls: mediaUrls,
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
}

CommunityPost _communityPostFromBackendJson(Map<String, dynamic> json) {
  return _backendApiCommunityPostFromBackendJson(json);
}

GroupPostPreview? _groupPostPreviewFromJson(dynamic raw) {
  return _backendApiGroupPostPreviewFromJson(raw);
}

CommunityGroupSummary _communityGroupSummaryFromJson(
    Map<String, dynamic> json) {
  return _backendApiCommunityGroupSummaryFromJson(json);
}

Comment _commentFromBackendJson(Map<String, dynamic> json) {
  return _backendApiCommentFromBackendJson(json);
}

List<Comment> _nestComments(List<Comment> comments) {
  return _backendApiNestComments(comments);
}
