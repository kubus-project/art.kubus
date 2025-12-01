import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_keys.dart';
import '../models/art_marker.dart';
import '../models/artwork.dart';
import '../community/community_interactions.dart';
import '../utils/wallet_utils.dart';
import '../utils/search_suggestions.dart';
import 'user_action_logger.dart';

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
class BackendApiService {
  static final BackendApiService _instance = BackendApiService._internal();
  factory BackendApiService() => _instance;
  BackendApiService._internal();

  final String baseUrl = ApiKeys.backendUrl;
  String? _authToken;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _authInitialized = false;
  Future<void>? _authInitFuture;
  final Map<String, DateTime> _rateLimitResets = {};

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
    debugPrint('BackendApiService: rate limit set for $key until $resetAt (window ${windowMs}ms)');
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

  /// Ensure auth token is loaded once. If token missing and wallet provided,
  /// attempt a single token issuance for that wallet and persist it.
  Future<void> ensureAuthLoaded({String? walletAddress}) async {
    if (_authInitialized) return;
    if (_authInitFuture != null) return _authInitFuture!;
    _authInitFuture = _doAuthInit(walletAddress);
    await _authInitFuture;
  }

  Future<void> _doAuthInit(String? walletAddress) async {
    try {
      await loadAuthToken();
      if ((_authToken == null || _authToken!.isEmpty) && walletAddress != null && walletAddress.isNotEmpty) {
        // Try to issue a token once for the provided wallet
        try {
          final issued = await issueTokenForWallet(walletAddress);
          if (issued) {
            await loadAuthToken();
          } else {
            debugPrint('BackendApiService._doAuthInit: issueTokenForWallet returned false for $walletAddress');
          }
        } catch (e) {
          debugPrint('BackendApiService._doAuthInit: issueTokenForWallet threw: $e');
        }
      }
    } finally {
      _authInitialized = true;
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
        debugPrint('BackendApiService: Attempting token issuance for stored wallet: $storedWallet');
        try {
          await ensureAuthLoaded(walletAddress: storedWallet);
        } catch (e) {
          debugPrint('BackendApiService: ensureAuthLoaded failed for stored wallet: $e');
        }
      }
    } catch (e) {
      debugPrint('BackendApiService: _ensureAuthWithStoredWallet failed: $e');
    }
  }

  Future<void> _ensureAuthBeforeRequest({String? walletAddress}) async {
    if ((_authToken ?? '').isNotEmpty) return;
    await _ensureAuthWithStoredWallet();
    if ((_authToken ?? '').isNotEmpty) return;
    if (walletAddress != null && walletAddress.isNotEmpty) {
      try {
        await ensureAuthLoaded(walletAddress: walletAddress);
      } catch (e) {
        debugPrint('BackendApiService: ensureAuthLoaded for $walletAddress failed: $e');
      }
    }
  }

  /// Set authentication token for API requests
  Future<void> setAuthToken(String token) async {
    _authToken = token;
    debugPrint('BackendApiService: Auth token set (in-memory)');
    // Persist token to secure storage and shared preferences (web fallback)
    try {
      await _secureStorage.write(key: 'jwt_token', value: token);
      debugPrint('BackendApiService: Auth token written to secure storage');
    } catch (e) {
      debugPrint('BackendApiService: failed to write secure storage token: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      debugPrint('BackendApiService: Auth token written to SharedPreferences fallback');
    } catch (e) {
      debugPrint('BackendApiService: failed to write prefs token: $e');
    }
  }

  /// Load auth token from secure storage
  Future<void> loadAuthToken() async {
    try {
      String? token;
      try {
        token = await _secureStorage.read(key: 'jwt_token');
      } catch (e) {
        debugPrint('BackendApiService: secure storage read failed: $e');
      }

      // Fallback to SharedPreferences (useful for web builds where secure storage may not persist)
      if (token == null || token.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          // Try a few known keys for backward compatibility
          token = prefs.getString('jwt_token') ?? prefs.getString('token') ?? prefs.getString('auth_token') ?? prefs.getString('authToken');
          if (token != null && token.isNotEmpty) debugPrint('BackendApiService: Auth token loaded from SharedPreferences fallback');
        } catch (e) {
          debugPrint('BackendApiService: SharedPreferences fallback failed: $e');
        }
      }
      if (token != null && token.isNotEmpty) {
        _authToken = token;
        debugPrint('BackendApiService: Auth token loaded (in-memory)');
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
              debugPrint('BackendApiService: token expiry in $secsLeft seconds');
            }
          }
        } catch (e) {
          debugPrint('BackendApiService: failed to decode token expiry: $e');
        }
      } else {
        debugPrint('BackendApiService: No stored auth token found');
      }
    } catch (e) {
      debugPrint('BackendApiService: Error loading auth token: $e');
    }
  }

  /// Clear authentication
  Future<void> clearAuth() async {
    _authToken = null;
    try {
      await _secureStorage.delete(key: 'jwt_token');
      debugPrint('BackendApiService: Auth cleared from secure storage');
    } catch (e) {
      debugPrint('BackendApiService: Error clearing auth token: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      debugPrint('BackendApiService: Auth cleared from SharedPreferences');
    } catch (e) {
      debugPrint('BackendApiService: Error clearing prefs auth token: $e');
    }
  }

  /// Get common headers for API requests
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
      // Avoid printing the token, but log that Authorization header will be included
      debugPrint('BackendApiService._getHeaders: Authorization header present');
    } else if (includeAuth) {
      debugPrint('BackendApiService._getHeaders: Authorization header NOT present — ensure BackendApiService.loadAuthToken() was called earlier');
    }

    return headers;
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
      debugPrint('BackendApiService: skipping $key because of active rate limit');
      throw Exception(message);
    }

    final headers = _getHeaders(includeAuth: includeAuth);
    http.Response? primaryResponse;
    try {
      primaryResponse = await http.get(uri, headers: headers);
      if (_isSuccessStatus(primaryResponse.statusCode)) {
        return jsonDecode(primaryResponse.body) as Map<String, dynamic>;
      }
      if (primaryResponse.statusCode == 429) {
        _markRateLimited(key, primaryResponse, defaultWindowMs: 900000);
        throw Exception(_rateLimitMessage(key));
      }
      debugPrint('BackendApiService: ${uri.path} failed with status ${primaryResponse.statusCode}');
      if (!allowOrbitFallback) {
        throw Exception('Request failed: ${primaryResponse.statusCode}');
      }
    } catch (e) {
      if (primaryResponse?.statusCode == 429) {
        rethrow; // Do not attempt Orbit fallback when rate limited.
      }
      if (!allowOrbitFallback) {
        debugPrint('BackendApiService: request error for ${uri.path}: $e');
        rethrow;
      }
      debugPrint('BackendApiService: primary request error for ${uri.path}, trying Orbit fallback -> $e');
    }

    if (!allowOrbitFallback) {
      throw Exception('Request failed for ${uri.toString()}');
    }

    final fallbackUri = _withOrbitSource(uri);
    final fallbackResponse = await http.get(fallbackUri, headers: headers);
    if (_isSuccessStatus(fallbackResponse.statusCode)) {
      final data = jsonDecode(fallbackResponse.body) as Map<String, dynamic>;
      data['source'] = data['source'] ?? 'orbitdb';
      return data;
    }
    if (fallbackResponse.statusCode == 429) {
      _markRateLimited(key, fallbackResponse, defaultWindowMs: 900000);
      throw Exception(_rateLimitMessage(key));
    }
    debugPrint('BackendApiService: Orbit fallback failed ${fallbackResponse.statusCode} for ${fallbackUri.path}');
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
  Future<Map<String, dynamic>> registerWallet({
    required String walletAddress,
    String? username,
  }) async {
    try {
      final body = {
        'walletAddress': walletAddress,
        if (username != null) 'username': username,
      };
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
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
      debugPrint('Error in registerWallet: $e');
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
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
      debugPrint('Error logging in: $e');
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
      final response = await http.post(
        uri,
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
      throw Exception('Email registration failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error in registerWithEmail: $e');
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
      final response = await http.post(
        uri,
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
      throw Exception('Email login failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error logging in with email: $e');
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
      final response = await http.post(
        uri,
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
      debugPrint('Error logging in with Google: $e');
      rethrow;
    }
  }

  /// Get user profile by ID
  /// GET /api/users/:userId
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get profile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting profile: $e');
      rethrow;
    }
  }

  // ==================== Chat / Messaging Helpers (wrappers used by providers) ====================

  /// Return current in-memory auth token (may be null)
  String? getAuthToken() => _authToken;

  /// Get current authenticated profile
  /// GET /api/profiles/me
  Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/profiles/me'), headers: _getHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'data': data['data'] ?? data};
      }
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error in getMyProfile: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Issue a short-lived backend token for a wallet (used for socket auth)
  /// POST /api/profiles/issue-token { walletAddress }
  Future<bool> issueTokenForWallet(String walletAddress) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/profiles/issue-token'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'walletAddress': walletAddress}),
      );
      debugPrint('BackendApiService.issueTokenForWallet: status=${resp.statusCode}');
      debugPrint('BackendApiService.issueTokenForWallet: bodyLen=${resp.body.length}');
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = body['token'] as String? ?? body['data']?['token'] as String?;
        debugPrint('BackendApiService.issueTokenForWallet: tokenPresent=${token != null && token.isNotEmpty}');
        if (token != null && token.isNotEmpty) {
          await setAuthToken(token);
          try {
            await _secureStorage.write(key: 'jwt_token', value: token);
          } catch (e) {
            debugPrint('issueTokenForWallet: failed to persist token: $e');
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error issuing token for wallet: $e');
      return false;
    }
  }

  /// Fetch list of conversations (lightweight)
  /// GET /api/messages
  Future<Map<String, dynamic>> fetchConversations() async {
    try {
      // Ensure we attempt to load persisted token before every protected call
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      debugPrint('BackendApiService.fetchConversations: authToken present=${_authToken != null && _authToken!.isNotEmpty}');
      final response = await http.get(Uri.parse('$baseUrl/api/messages'), headers: _getHeaders());
      // If unauthorized, try once more after reloading persisted token (short-lived tokens can expire)
      if (response.statusCode == 401) {
        debugPrint('BackendApiService.fetchConversations: 401 received, retrying after reload of auth token');
        try { await loadAuthToken(); } catch (_) {}
        try { await _ensureAuthWithStoredWallet(); } catch (_) {}
        final retryResp = await http.get(Uri.parse('$baseUrl/api/messages'), headers: _getHeaders());
        if (retryResp.statusCode == 200) {
          return jsonDecode(retryResp.body) as Map<String, dynamic>;
        }
        return {'success': false, 'status': retryResp.statusCode};
      }
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch messages for a conversation
  /// GET /api/messages/:conversationId/messages
  Future<Map<String, dynamic>> fetchMessages(String conversationId, {int page = 1, int limit = 50}) async {
    try {
      // Ensure we attempt to load persisted token before every protected call (and attempt issuance for stored wallet if missing)
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      debugPrint('BackendApiService.fetchMessages: conversationId=$conversationId authToken present=${_authToken != null && _authToken!.isNotEmpty}');
      final uri = Uri.parse('$baseUrl/api/messages/$conversationId/messages').replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });
      final response = await http.get(uri, headers: _getHeaders());
      if (response.statusCode == 401) {
        debugPrint('BackendApiService.fetchMessages: 401 received, retrying after auth reload');
        try { await loadAuthToken(); } catch (_) {}
        try { await _ensureAuthWithStoredWallet(); } catch (_) {}
        final retryResp = await http.get(uri, headers: _getHeaders());
        if (retryResp.statusCode == 200) return jsonDecode(retryResp.body) as Map<String, dynamic>;
        return {'success': false, 'status': retryResp.statusCode};
      }
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error fetching messages: $e');
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/$conversationId/messages'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'status': response.statusCode, 'body': response.body};
    } catch (e) {
      debugPrint('Error sending message: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetch conversation members
  /// GET /api/messages/:conversationId/members
  Future<Map<String, dynamic>> fetchConversationMembers(String conversationId) async {
    try {
      // Ensure persisted token is loaded and token issuance attempted once (use stored wallet fallback)
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await http.get(Uri.parse('$baseUrl/api/messages/$conversationId/members'), headers: _getHeaders());
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 429) {
        debugPrint('BackendApiService.fetchConversationMembers: 429 Too Many Requests for $conversationId');
        return {'success': false, 'status': 429, 'retryAfter': response.headers['retry-after']};
      }
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error fetching conversation members: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload a message attachment by posting multipart to the messages endpoint
  Future<Map<String, dynamic>> uploadMessageAttachment(String conversationId, List<int> bytes, String filename, String contentType) async {
    try {
      final uri = Uri.parse('$baseUrl/api/messages/$conversationId/messages');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getHeaders());
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: MediaType.parse(contentType)));
      final placeholder = filename.isNotEmpty ? 'Attachment • $filename' : 'Shared an attachment';
      request.fields['message'] = placeholder;
      request.fields['content'] = placeholder;
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200 || resp.statusCode == 201) return jsonDecode(resp.body) as Map<String, dynamic>;
      return {'success': false, 'status': resp.statusCode, 'body': resp.body};
    } catch (e) {
      debugPrint('Error uploading message attachment: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Create a conversation
  /// POST /api/messages { title, members }
  Future<Map<String, dynamic>> createConversation({String? title, bool isGroup = false, List<String>? members}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages'),
        headers: _getHeaders(),
        body: jsonEncode({'title': title, 'members': members ?? [], 'isGroup': isGroup}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload conversation avatar (attempt common endpoints)
  Future<Map<String, dynamic>> uploadConversationAvatar(String conversationId, List<int> bytes, String filename, String contentType) async {
    try {
      // Try conversation-specific avatar endpoint first
      var uri = Uri.parse('$baseUrl/api/conversations/$conversationId/avatar');
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getHeaders());
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: MediaType.parse(contentType)));
      var streamed = await request.send();
      var resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200 || resp.statusCode == 201) return jsonDecode(resp.body) as Map<String, dynamic>;

      // Fallback to messages-based endpoint
      uri = Uri.parse('$baseUrl/api/messages/$conversationId/avatar');
      request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_getHeaders());
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: MediaType.parse(contentType)));
      streamed = await request.send();
      resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200 || resp.statusCode == 201) return jsonDecode(resp.body) as Map<String, dynamic>;

      return {'success': false, 'status': resp.statusCode, 'body': resp.body};
    } catch (e) {
      debugPrint('Error uploading conversation avatar: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Add a member to conversation
  Future<Map<String, dynamic>> addConversationMember(String conversationId, String walletAddress) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/$conversationId/members'),
        headers: _getHeaders(),
        body: jsonEncode({'walletAddress': walletAddress}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error adding conversation member: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Remove a member from conversation (best-effort)
  Future<Map<String, dynamic>> removeConversationMember(String conversationId, String walletOrUsername) async {
    try {
      // Try a DELETE endpoint first (may not exist on server)
      final uri = Uri.parse('$baseUrl/api/messages/$conversationId/members');
      final response = await http.delete(uri, headers: _getHeaders(), body: jsonEncode({'walletAddress': walletOrUsername, 'username': walletOrUsername}));
      if (response.statusCode == 200 || response.statusCode == 204) return {'success': true};

      // Fallback: call a removal helper endpoint (non-standard)
      final fallback = await http.post(Uri.parse('$baseUrl/api/messages/$conversationId/members/remove'), headers: _getHeaders(), body: jsonEncode({'walletAddress': walletOrUsername}));
      if (fallback.statusCode == 200 || fallback.statusCode == 201) return jsonDecode(fallback.body) as Map<String, dynamic>;

      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error removing conversation member: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Transfer conversation ownership (best-effort)
  Future<Map<String, dynamic>> transferConversationOwner(String conversationId, String newOwnerWallet) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/$conversationId/transfer-owner'),
        headers: _getHeaders(),
        body: jsonEncode({'newOwnerWallet': newOwnerWallet}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error transferring conversation owner: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark conversation as read
  Future<Map<String, dynamic>> markConversationRead(String conversationId) async {
    try {
      final response = await http.put(Uri.parse('$baseUrl/api/messages/$conversationId/read'), headers: _getHeaders());
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error marking conversation read: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Mark a specific message as read
  Future<Map<String, dynamic>> markMessageRead(String conversationId, String messageId) async {
    try {
      final response = await http.put(Uri.parse('$baseUrl/api/messages/$conversationId/messages/$messageId/read'), headers: _getHeaders());
      if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      debugPrint('Error marking message read: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> renameConversation(String conversationId, String newTitle) async {
    try {
      final response = await http.patch(
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
  Future<Map<String, dynamic>> updateProfile(
    String walletAddress,
    Map<String, dynamic> updates,
  ) async {
    try {
      try {
        await ensureAuthLoaded(walletAddress: walletAddress);
      } catch (_) {}
      final payload = {
        'walletAddress': walletAddress,
        ...updates,
      };
      final response = await http.post(
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
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  // ==================== Profile/Artists API (New) ====================

  /// Get profile by wallet address
  /// GET /api/profiles/:walletAddress
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) async {
    try {
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      // Avoid making pointless network calls when wallet is a known placeholder
      final normalized = WalletUtils.normalize(walletAddress);
      if (normalized.isEmpty || ['unknown', 'anonymous', 'n/a', 'none'].contains(normalized.toLowerCase())) {
        throw Exception('Profile not found');
      }
      final uri = Uri.parse('$baseUrl/api/profiles/$walletAddress');
      final dynamic data = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: true);
      final raw = data['data'] ?? data;
      if (raw is Map<String, dynamic>) {
        debugPrint('BackendApiService.getProfileByWallet: parsed profile keys: ${raw.keys.toList()}');
        return raw;
      }
      throw Exception('Invalid profile payload');
    } catch (e) {
      debugPrint('Error getting profile by wallet: $e');
      rethrow;
    }
  }

  /// Fetch multiple profiles in a single batch call
  /// POST /api/profiles/batch { wallets: [wallet1,wallet2] }
  Future<Map<String, dynamic>> getProfilesBatch(List<String> wallets) async {
    try {
      if (wallets.isEmpty) return {'success': true, 'data': <dynamic>[]};
      await _ensureAuthBeforeRequest();
      final response = await http.post(
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
      debugPrint('Error in getProfilesBatch: $e');
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
      debugPrint('BackendApiService.findProfileByUsername error: $e');
    }
    return null;
  }

  /// Create or update profile
  /// POST /api/profiles
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> profileData) async {
    const int maxRetries = 3;
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        debugPrint('BackendApiService.saveProfile: POST /api/profiles payload: ${jsonEncode(profileData)}');
        final response = await http.post(
          Uri.parse('$baseUrl/api/profiles'),
          headers: _getHeaders(includeAuth: false),
          body: jsonEncode(profileData),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['token'] != null) {
            await setAuthToken(data['token'] as String);
            debugPrint('JWT token received and stored from profile creation');
          }
          return data['data'] as Map<String, dynamic>;
        }

        if (response.statusCode == 429) {
          // Too many requests - check Retry-After header
          final retryAfter = response.headers['retry-after'];
          final waitSeconds = int.tryParse(retryAfter ?? '') ?? (2 << (attempt - 1));
          if (attempt < maxRetries) {
            debugPrint('saveProfile received 429, retrying in $waitSeconds seconds (attempt $attempt)');
            await Future.delayed(Duration(seconds: waitSeconds));
            continue;
          } else {
            throw Exception('Too many requests (429). Please wait and try again later.');
          }
        }

        throw Exception('Failed to save profile: ${response.statusCode} ${response.body}');
      } catch (e) {
        // If we've exhausted retries, rethrow
        if (attempt >= maxRetries) {
          debugPrint('Error saving profile (final): $e');
          rethrow;
        }

        // If this was a transient error, wait briefly and retry
        final backoff = 1 << (attempt - 1);
        debugPrint('saveProfile transient error, retrying in $backoff seconds: $e');
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
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] as List);
      } else {
        throw Exception('Failed to list artists: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error listing artists: $e');
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
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['data'] as List);
      } else {
        throw Exception('Failed to get artist artworks: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting artist artworks: $e');
      rethrow;
    }
  }

  /// Get user stats
  /// GET /api/profiles/:walletAddress/stats
  Future<Map<String, dynamic>> getUserStats(String walletAddress) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profiles/$walletAddress/stats'),
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get user stats: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting user stats: $e');
      rethrow;
    }
  }

  // ==================== Mock Data API (New) ====================

  /// Get mock artworks (development/testing)
  /// GET /api/mock/artworks
  Future<List<Map<String, dynamic>>> getMockArtworks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/mock/artworks'),
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
      debugPrint('Error getting mock artworks: $e');
      rethrow;
    }
  }

  /// Get mock community posts (development/testing)
  /// GET /api/mock/community-posts
  Future<List<Map<String, dynamic>>> getMockCommunityPosts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/mock/community-posts'),
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
      debugPrint('Error getting mock community posts: $e');
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
  }) async {
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/art-markers').replace(queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radiusKm.toString(),
      });

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
      debugPrint('Error getting nearby markers: $e');
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
      final response = await http.post(
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
      debugPrint('Error creating AR marker: $e');
      rethrow;
    }
  }

  /// Increment marker views
  /// POST /api/art-markers/:id/view
  Future<void> incrementMarkerViews(String markerId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/art-markers/$markerId/view'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error incrementing marker views: $e');
    }
  }

  /// Increment marker interactions
  /// POST /api/art-markers/:id/interact
  Future<void> incrementMarkerInteractions(String markerId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/art-markers/$markerId/interact'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error incrementing marker interactions: $e');
    }
  }

  // ==================== Artwork Endpoints ====================

  /// Get artworks with filters
  /// GET /api/artworks
  Future<List<Artwork>> getArtworks({
    String? category,
    bool? arEnabled,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (category != null) queryParams['category'] = category;
      if (arEnabled != null) queryParams['arEnabled'] = arEnabled.toString();

      final uri = Uri.parse('$baseUrl/api/artworks').replace(queryParameters: queryParams);
      final data = await _fetchJson(uri, includeAuth: false, allowOrbitFallback: true);
      final dynamic listCandidate = data['artworks'] ?? data['data'] ?? data['items'];
      final List<dynamic> artworks = listCandidate is List ? listCandidate : <dynamic>[];
      return artworks.map((json) => _artworkFromBackendJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error getting artworks: $e');
      rethrow;
    }
  }

  /// Get single artwork by ID
  /// GET /api/artworks/:id
  Future<Artwork> getArtwork(String artworkId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/artworks/$artworkId');
      final data = await _fetchJson(uri, allowOrbitFallback: true);
      final payload = data['artwork'] ?? data['data'] ?? data;
      if (payload is Map<String, dynamic>) {
        return _artworkFromBackendJson(payload);
      }
      throw Exception('Invalid artwork payload');
    } catch (e) {
      debugPrint('Error getting artwork: $e');
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
        if (metadata != null) 'metadata': metadata,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/artworks'),
        headers: _getHeaders(),
        body: jsonEncode(body),
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
      debugPrint('Error creating artwork record: $e');
      return null;
    }
  }

  /// Record artwork discovery
  /// POST /api/artworks/:id/discover
  Future<void> discoverArtwork(String artworkId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/artworks/$artworkId/discover'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error recording artwork discovery: $e');
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

      final uri = Uri.parse('$baseUrl/api/community/posts').replace(queryParameters: queryParams);
      final allowFallback = followingOnly != true;
      final data = await _fetchJson(uri, includeAuth: true, allowOrbitFallback: allowFallback);
      final posts = data['data'] as List<dynamic>? ?? <dynamic>[];
      return posts.map((json) => _communityPostFromBackendJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error getting community posts: $e');
      rethrow;
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
      debugPrint('Error getting community post by id: $e');
      rethrow;
    }
  }

  /// Create a community post
  /// POST /api/community/posts
  Future<CommunityPost> createCommunityPost({
    required String content,
    String? imageUrl,
    List<String>? mediaUrls,
    String? artworkId,
    String? postType,
  }) async {
    try {
      final requestBody = {
        'content': content,
        if (imageUrl != null) 'mediaUrls': [imageUrl],
        if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
        if (artworkId != null) 'artworkId': artworkId,
        if (postType != null) 'postType': postType,
      };
      
      debugPrint('Creating post with body: $requestBody');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts'),
        headers: _getHeaders(),
        body: jsonEncode(requestBody),
      );
      
      debugPrint('Create post response status: ${response.statusCode}');
      debugPrint('Create post response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final createdPost = _communityPostFromBackendJson(data['data'] as Map<String, dynamic>);
        try {
          await UserActionLogger.logPostCreated(
            postId: createdPost.id,
            content: createdPost.content,
            mediaUrls: mediaUrls ??
                (createdPost.imageUrl != null ? <String>[createdPost.imageUrl!] : null),
          );
        } catch (e) {
          debugPrint('UserActionLogger.logPostCreated failed: $e');
        }
        return createdPost;
      } else {
        throw Exception('Failed to create post: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      rethrow;
    }
  }

  /// Like a post
  /// POST /api/community/posts/:id/like
  Future<int?> likePost(String postId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts/$postId/like'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data['likesCount'] as int? : null;
      }
      throw Exception('Failed to like post (${response.statusCode})');
    } catch (e) {
      debugPrint('Error liking post: $e');
      rethrow;
    }
  }

  /// Share a post (increment share counter)
  /// POST /api/community/posts/:id/share
  Future<void> sharePost(String postId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/community/posts/$postId/share'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error sharing post: $e');
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
      final response = await http.post(
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
      debugPrint('Error creating repost: $e');
      rethrow;
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
      final response = await http.post(
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
      debugPrint('Error sharing post via DM: $e');
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
      final response = await http.get(
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
      debugPrint('Error getting reposts: $e');
      rethrow;
    }
  }

  /// Delete a repost (unrepost)
  /// DELETE /api/community/posts/:id/repost
  Future<void> deleteRepost(String repostId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await http.delete(
        Uri.parse('$baseUrl/api/community/posts/$repostId/repost'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete repost: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error deleting repost: $e');
      rethrow;
    }
  }

  /// Track analytics event
  /// POST /api/community/analytics/event
  Future<void> trackAnalyticsEvent({
    required String eventType,
    String? postId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/analytics/event'),
        headers: _getHeaders(),
        body: jsonEncode({
          'eventType': eventType,
          if (postId != null) 'postId': postId,
          if (metadata != null) 'metadata': metadata,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint('Failed to track analytics event: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error tracking analytics event: $e');
      // Don't rethrow - analytics failures shouldn't break user experience
    }
  }

  /// Unlike a post
  /// DELETE /api/community/posts/:id/like
  Future<int?> unlikePost(String postId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await http.delete(
        Uri.parse('$baseUrl/api/community/posts/$postId/like'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data['likesCount'] as int? : null;
      }
      throw Exception('Failed to unlike post (${response.statusCode})');
    } catch (e) {
      debugPrint('Error unliking post: $e');
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
      final response = await http.post(
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
      debugPrint('Error creating comment: $e');
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
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body);
        debugPrint('🔍 getComments: Raw response body type: ${parsed.runtimeType}');
        if (parsed is Map<String, dynamic>) {
          final raw = parsed['comments'] ?? parsed['data'] ?? parsed['result'] ?? parsed['payload'] ?? [];
          debugPrint('🔍 getComments: Found ${(raw as List?)?.length ?? 0} comments in response');
          if (raw is List && raw.isNotEmpty) {
            debugPrint('🔍 getComments: First comment sample: ${raw.first}');
          }
          if (raw is List) {
            final flat = raw
                .whereType<Map<String, dynamic>>()
                .map(_commentFromBackendJson)
                .toList();
            debugPrint('🔍 getComments: Parsed ${flat.length} comments initially');
            if (flat.isNotEmpty) {
              final first = flat.first;
              debugPrint('🔍 First parsed comment: id=${first.id}, name="${first.authorName}", avatar="${first.authorAvatar}", wallet="${first.authorWallet}"');
            }

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
                debugPrint('BackendApiService.getComments: attempting to batch-fetch profiles for ${wallets.length} authors');
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

                int filled = 0;
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
                    final normalizedAvatar = _normalizeBackendAvatarUrl(avatarCandidate);
                    
                    // Determine best display name: prioritize displayName, then username, then fallback to existing
                    final bestDisplayName = (profileDisplayName != null && profileDisplayName.trim().isNotEmpty)
                        ? profileDisplayName.trim()
                        : ((profileUsername != null && profileUsername.trim().isNotEmpty) 
                            ? profileUsername.trim() 
                            : c.authorName);
                    
                    debugPrint('   Profile enrichment for comment ${c.id}: displayName=$profileDisplayName, username=$profileUsername, bestName=$bestDisplayName, avatar=$avatarCandidate');
                    
                    final updated = c.copyWith(
                      authorAvatar: normalizedAvatar,
                      authorUsername: profileUsername ?? c.authorUsername,
                      authorName: bestDisplayName,
                      authorId: (profile['walletAddress'] ?? profile['wallet'] ?? profile['id'] ?? profile['userId'] ?? c.authorId)?.toString(),
                      authorWallet: (profile['walletAddress'] ?? profile['wallet'] ?? profile['wallet_address'] ?? profile['publicKey'] ?? profile['public_key'])?.toString(),
                    );
                    flat[i] = updated;
                    filled++;
                  } catch (e) {
                    debugPrint('   Profile enrichment error for comment ${c.id}: $e');
                  }
                }
                debugPrint('BackendApiService.getComments: filled $filled comment author profiles from ${profilesByWallet.length} profile results');
                if (flat.isNotEmpty) {
                  final first = flat.first;
                  debugPrint('🔍 After enrichment, first comment: id=${first.id}, name="${first.authorName}", avatar="${first.authorAvatar}"');
                }
              }
            } catch (e) {
              debugPrint('BackendApiService.getComments: profile batch fetch error: $e');
            }
            return _nestComments(flat);
          }
          debugPrint('BackendApiService.getComments: unexpected payload for comments, returning empty list');
          return <Comment>[];
        }
        debugPrint('BackendApiService.getComments: response body not a JSON object, returning empty list');
        return <Comment>[];
      } else {
        debugPrint('BackendApiService.getComments: non-200 status ${response.statusCode}, returning empty list');
        return <Comment>[];
      }
    } catch (e) {
      debugPrint('Error getting comments: $e');
      return <Comment>[];
    }
  }

  /// Delete a comment
  /// DELETE /api/community/comments/:id
  Future<void> deleteComment(String commentId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/community/comments/$commentId'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      rethrow;
    }
  }

  /// Like a comment
  /// POST /api/community/comments/:id/like
  Future<int?> likeComment(String commentId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/comments/$commentId/like'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data['likesCount'] as int? : null;
      }
      throw Exception('Failed to like comment (${response.statusCode})');
    } catch (e) {
      debugPrint('Error liking comment: $e');
      rethrow;
    }
  }

  /// Unlike a comment
  /// DELETE /api/community/comments/:id/like
  Future<int?> unlikeComment(String commentId) async {
    try {
      try { await _ensureAuthWithStoredWallet(); } catch (_) {}
      final response = await http.delete(
        Uri.parse('$baseUrl/api/community/comments/$commentId/like'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is Map<String, dynamic> ? data['likesCount'] as int? : null;
      }
      throw Exception('Failed to unlike comment (${response.statusCode})');
    } catch (e) {
      debugPrint('Error unliking comment: $e');
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

      final response = await http.get(uri, headers: _getHeaders());
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
      debugPrint('Error fetching post likes: $e');
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

      final response = await http.get(uri, headers: _getHeaders());
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
      debugPrint('Error fetching comment likes: $e');
      rethrow;
    }
  }

  // ==================== Follow Endpoints ====================

  /// Follow a user
  /// POST /api/community/follow/:walletAddress
  Future<void> followUser(String walletAddress) async {
    final encoded = Uri.encodeComponent(walletAddress);
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/community/follow/$encoded');
      http.Response response = await http.post(uri, headers: _getHeaders());

      if (response.statusCode == 401) {
        debugPrint('BackendApiService.followUser: received 401, retrying after refreshing token');
        try {
          await loadAuthToken();
        } catch (_) {}
        await _ensureAuthBeforeRequest();
        response = await http.post(uri, headers: _getHeaders());
      }

      if (!_isSuccessStatus(response.statusCode)) {
        final body = response.body.isNotEmpty ? response.body : 'No response body';
        throw Exception('Failed to follow user (${response.statusCode}): $body');
      }
    } catch (e) {
      debugPrint('Error following user: $e');
      rethrow;
    }
  }

  /// Unfollow a user
  /// DELETE /api/community/follow/:walletAddress
  Future<void> unfollowUser(String walletAddress) async {
    final encoded = Uri.encodeComponent(walletAddress);
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/community/follow/$encoded');
      http.Response response = await http.delete(uri, headers: _getHeaders());

      if (response.statusCode == 401) {
        debugPrint('BackendApiService.unfollowUser: received 401, retrying after refreshing token');
        try {
          await loadAuthToken();
        } catch (_) {}
        await _ensureAuthBeforeRequest();
        response = await http.delete(uri, headers: _getHeaders());
      }

      if (!_isSuccessStatus(response.statusCode)) {
        final body = response.body.isNotEmpty ? response.body : 'No response body';
        throw Exception('Failed to unfollow user (${response.statusCode}): $body');
      }
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
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
      final response = await http.get(uri, headers: _getHeaders());

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
      debugPrint('Error getting followers: $e');
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
      final response = await http.get(uri, headers: _getHeaders());

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
      debugPrint('Error getting following: $e');
      rethrow;
    }
  }

  /// Check if current user is following a user
  /// GET /api/community/follow/:walletAddress/status
  Future<bool> isFollowing(String walletAddress) async {
    final encoded = Uri.encodeComponent(walletAddress);
    try {
      await _ensureAuthBeforeRequest();
      final uri = Uri.parse('$baseUrl/api/community/follow/$encoded/status');
      http.Response response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 401) {
        debugPrint('BackendApiService.isFollowing: received 401, retrying after refreshing token');
        try {
          await loadAuthToken();
        } catch (_) {}
        await _ensureAuthBeforeRequest();
        response = await http.get(uri, headers: _getHeaders());
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['isFollowing'] as bool? ?? false;
      }

      if (response.statusCode == 404) {
        throw Exception('User not found when checking follow status');
      }

      throw Exception('Failed to check follow status (${response.statusCode})');
    } catch (e) {
      debugPrint('Error checking follow status: $e');
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
      final response = await http.post(
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
      debugPrint('Error creating NFT series: $e');
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
      final response = await http.post(
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
      debugPrint('Error minting NFT: $e');
      rethrow;
    }
  }

  /// Get NFT series by artwork ID
  /// GET /api/nfts/series/artwork/:artworkId
  Future<Map<String, dynamic>?> getNFTSeriesByArtwork(String artworkId) async {
    try {
      final response = await http.get(
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
      debugPrint('Error getting NFT series: $e');
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
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['nfts'] as List<dynamic>)
            .map((json) => json as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to get user NFTs: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting user NFTs: $e');
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
      final response = await http.post(
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
      debugPrint('Error listing NFT: $e');
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
      final response = await http.post(
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
      debugPrint('Error buying NFT: $e');
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
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['nfts'] as List<dynamic>)
            .map((json) => json as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to get marketplace NFTs: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting marketplace NFTs: $e');
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/achievements/user/$walletAddress'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get user achievements: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting user achievements: $e');
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
      final response = await http.post(
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
      debugPrint('Error unlocking achievement: $e');
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
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

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
      debugPrint('Error getting DAO proposals: $e');
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
      final response = await http.post(
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
      debugPrint('Error creating DAO proposal: $e');
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
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

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
      debugPrint('Error getting DAO votes: $e');
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
      final response = await http.post(
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
      debugPrint('Error submitting DAO vote: $e');
      rethrow;
    }
  }

  /// List DAO delegates
  /// GET /api/dao/delegates
  Future<List<Map<String, dynamic>>> getDAODelegates() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dao/delegates'),
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
      debugPrint('Error getting DAO delegates: $e');
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
      final response = await http.post(
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
      debugPrint('Error delegating voting power: $e');
      rethrow;
    }
  }

  /// List DAO treasury/governance transactions
  /// GET /api/dao/transactions
  Future<List<Map<String, dynamic>>> getDAOTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dao/transactions'),
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
      debugPrint('Error getting DAO transactions: $e');
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/dao/reviews'),
        headers: _getHeaders(),
        body: jsonEncode({
          'portfolioUrl': portfolioUrl,
          'medium': medium,
          'statement': statement,
          if (title != null && title.isNotEmpty) 'title': title,
          if (metadata != null) 'metadata': metadata,
        }),
      );

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
      debugPrint('Error submitting DAO review: $e');
      return null;
    }
  }

  /// List DAO reviews
  /// GET /api/dao/reviews
  Future<List<Map<String, dynamic>>> getDAOReviews({int limit = 50, int offset = 0}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/dao/reviews')
          .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'});
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['data'] ?? data['reviews'] ?? data['items'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404) {
        return [];
      } else if (response.statusCode >= 500) {
        debugPrint('getDAOReviews: backend returned ${response.statusCode}, returning empty list');
        return [];
      } else {
        throw Exception('Failed to get DAO reviews: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting DAO reviews: $e');
      return [];
    }
  }

  // ==================== Institution & Events (Provisional) ====================

  /// List institutions
  /// GET /api/institutions
  Future<List<Map<String, dynamic>>> listInstitutions({int limit = 50, int offset = 0}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/institutions').replace(queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      });
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['institutions'] ?? data['data'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to list institutions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error listing institutions: $e');
      return [];
    }
  }

  /// Get institution by id
  /// GET /api/institutions/:id
  Future<Map<String, dynamic>?> getInstitution(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/institutions/$id'),
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
      debugPrint('Error getting institution: $e');
      return null;
    }
  }

  /// List events (optionally filtered by institution)
  /// GET /api/events or /api/institutions/:id/events
  Future<List<Map<String, dynamic>>> listEvents({String? institutionId, bool? upcoming, int limit = 50, int offset = 0}) async {
    try {
      final base = institutionId == null
          ? '$baseUrl/api/events'
          : '$baseUrl/api/institutions/$institutionId/events';
      final query = <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      };
      if (upcoming != null) query['upcoming'] = '$upcoming';
      final uri = Uri.parse(base).replace(queryParameters: query);
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['events'] ?? data['data'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to list events: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error listing events: $e');
      return [];
    }
  }

  /// Get all available achievements
  /// GET /api/achievements
  Future<List<Map<String, dynamic>>> getAchievements() async {
    try {
      final response = await http.get(
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
      debugPrint('Error getting achievements: $e');
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/achievements/progress'),
        headers: _getHeaders(),
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
      debugPrint('Error updating achievement progress: $e');
      rethrow;
    }
  }

  /// Get achievement statistics for a user
  /// GET /api/achievements/stats/:walletAddress
  Future<Map<String, dynamic>> getAchievementStats(String walletAddress) async {
    try {
      final response = await http.get(
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
      debugPrint('Error getting achievement stats: $e');
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
      final response = await http.get(
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
      debugPrint('Error getting leaderboard: $e');
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
  }) async {
    const int maxRetries = 3;
    int attempt = 0;
    while (true) {
      attempt++;
      try {
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

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

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
            } else if (data.containsKey('ipfsUrl') && (data['ipfsUrl'] as String).isNotEmpty) {uploadedUrl = data['ipfsUrl'] as String;
              uploadedUrl = data['ipfsUrl'] as String;
            } else if (data.containsKey('httpUrl') && (data['httpUrl'] as String).isNotEmpty) {uploadedUrl = data['httpUrl'] as String;
            } else if (data.containsKey('fileUrl') && (data['fileUrl'] as String).isNotEmpty) {uploadedUrl = data['fileUrl'] as String;
            } else if (data.containsKey('path') && (data['path'] as String).isNotEmpty) {uploadedUrl = data['path'] as String;
          }} catch (_) {
            uploadedUrl = null;
          }

          // Log raw response for debugging
          debugPrint('BackendApiService.uploadFile: response body: ${jsonEncode(body)}');

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
            debugPrint('uploadFile received 429, retrying in $waitSeconds seconds (attempt $attempt)');
            await Future.delayed(Duration(seconds: waitSeconds));
            continue;
          } else {
            throw Exception('Too many requests (429) while uploading file.');
          }
        }

        throw Exception('Failed to upload file: ${response.statusCode}');
      } catch (e) {
        if (attempt >= maxRetries) {
          debugPrint('Error uploading file (final): $e');
          rethrow;
        }
        final backoff = 1 << (attempt - 1);
        debugPrint('uploadFile transient error, retrying in $backoff seconds: $e');
        await Future.delayed(Duration(seconds: backoff));
      }
    }
  }

  /// Upload avatar specifically to profile avatars endpoint
  /// POST /api/profiles/avatars
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) async {
    debugPrint('🌐 BackendApiService.uploadAvatarToProfile START');
    debugPrint('   baseUrl: $baseUrl');
    debugPrint('   fileName: $fileName');
    debugPrint('   fileType: $fileType');
    debugPrint('   fileBytes length: ${fileBytes.length}');
    debugPrint('   metadata: $metadata');
    
    const int maxRetries = 3;
    int attempt = 0;
    while (true) {
      attempt++;
      debugPrint('   Attempt $attempt of $maxRetries');
      try {
        final uri = Uri.parse('$baseUrl/api/profiles/avatars');
        debugPrint('   POST URL: $uri');
        
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

        debugPrint('   Sending request...');
        final streamedResponse = await request.send();
        debugPrint('   Response received, status: ${streamedResponse.statusCode}');
        final response = await http.Response.fromStream(streamedResponse);
        debugPrint('   Response body length: ${response.body.length}');

        if (response.statusCode == 200) {
          debugPrint('   ✅ Upload successful (200)');
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(body['data'] as Map<String, dynamic>)
              : (body['data'] != null ? Map<String, dynamic>.from(body['data']) : {});

          String? uploadedUrl;
          try {
            // Backend returns avatar URL in data.avatar field
            if (data.containsKey('avatar') && data['avatar'] != null && (data['avatar'] as String).isNotEmpty) {
              uploadedUrl = data['avatar'] as String;
              debugPrint('   Found data.avatar: $uploadedUrl');
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

          debugPrint('BackendApiService.uploadAvatarToProfile: response body: ${jsonEncode(body)}');
          debugPrint('BackendApiService.uploadAvatarToProfile: extracted uploadedUrl: $uploadedUrl');
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
            debugPrint('uploadAvatarToProfile received 429, retrying in $waitSeconds seconds (attempt $attempt)');
            await Future.delayed(Duration(seconds: waitSeconds));
            continue;
          } else {
            throw Exception('Too many requests (429) while uploading avatar.');
          }
        }

        debugPrint('   ❌ Upload failed with status: ${response.statusCode}');
        debugPrint('   Response body: ${response.body}');
        throw Exception('Failed to upload avatar: ${response.statusCode} ${response.body}');
      } catch (e, stackTrace) {
        debugPrint('   ❌ Exception during upload: $e');
        if (attempt >= maxRetries) {
          debugPrint('Error uploading avatar (final): $e');
          debugPrint('Stack trace: $stackTrace');
          rethrow;
        }
        final backoff = 1 << (attempt - 1);
        debugPrint('uploadAvatarToProfile transient error, retrying in $backoff seconds: $e');
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
      final response = await http.post(uri, headers: _getHeaders(), body: body);
      if (response.statusCode >= 200 && response.statusCode < 300) return;
      // Non-fatal: ignore telemetry failures
      debugPrint('Telemetry event post returned ${response.statusCode}');
    } catch (e) {
      debugPrint('Error sending telemetry event: $e');
    }
  }

  /// Check backend health
  /// GET /health
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Backend health check failed: $e');
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
      await _ensureAuthBeforeRequest(walletAddress: walletAddress);
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (walletAddress != null) {
        queryParams['walletAddress'] = walletAddress;
      }

      final uri = Uri.parse('$baseUrl/api/collections').replace(queryParameters: queryParams);
      final jsonData = await _fetchJson(
        uri,
        includeAuth: true,
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
      debugPrint('Error fetching collections: $e');
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
        includeAuth: false,
        allowOrbitFallback: true,
      );

      final data = jsonData['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }

      throw Exception('Unexpected collection response shape');
    } catch (e) {
      debugPrint('Error fetching collection: $e');
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
      final response = await http.post(
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
      debugPrint('Error creating collection: $e');
      rethrow;
    }
  }

  /// Delete collection
  /// DELETE /api/collections/:id
  Future<void> deleteCollection(String collectionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/collections/$collectionId'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete collection: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting collection: $e');
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/collections/$collectionId/artworks'),
        headers: _getHeaders(),
        body: jsonEncode({
          'artworkId': artworkId,
          if (notes != null) 'notes': notes,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add artwork to collection: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error adding artwork to collection: $e');
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
      final response = await http.delete(
        Uri.parse('$baseUrl/api/collections/$collectionId/artworks/$artworkId'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove artwork from collection: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error removing artwork from collection: $e');
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
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final notifications = jsonData['data'] as List<dynamic>;
        return notifications.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  /// Get unread notification count
  /// GET /api/notifications/unread-count
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await http.get(
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
      debugPrint('Error fetching unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  /// PUT /api/notifications/:id/read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark notification as read: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read
  /// PUT /api/notifications/read-all
  Future<void> markAllNotificationsAsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/notifications/read-all'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to mark all notifications as read: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Delete notification
  /// DELETE /api/notifications/:id
  Future<void> deleteNotification(String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/notifications/$notificationId'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete notification: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
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
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error performing search: $e');
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
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final suggestions = jsonData['suggestions'] as List<dynamic>;
        return suggestions.map((e) => e as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching search suggestions: $e');
      return [];
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
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final trending = jsonData['trending'] as List<dynamic>;
        return trending.map((e) => e as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching trending searches: $e');
      return [];
    }
  }

  // ==================== Message Reactions ====================

  /// Add a reaction to a message
  /// POST /api/conversations/:conversationId/messages/:messageId/reactions
  Future<void> addMessageReaction(String conversationId, String messageId, String emoji) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages/$messageId/reactions'),
        headers: _getHeaders(),
        body: jsonEncode({'emoji': emoji}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add reaction: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error adding message reaction: $e');
      rethrow;
    }
  }

  /// Remove a reaction from a message
  /// DELETE /api/conversations/:conversationId/messages/:messageId/reactions
  Future<void> removeMessageReaction(String conversationId, String messageId, String emoji) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/conversations/$conversationId/messages/$messageId/reactions'),
        headers: _getHeaders(),
        body: jsonEncode({'emoji': emoji}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove reaction: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error removing message reaction: $e');
      rethrow;
    }
  }
}

// Helper functions for model conversions
ArtMarker _artMarkerFromBackendJson(Map<String, dynamic> json) {
  final normalized = <String, dynamic>{
    'id': json['id'] ?? json['_id'] ?? '',
    'name': json['name'] ?? json['title'] ?? json['label'] ?? '',
    'description': json['description'] ?? json['summary'] ?? '',
    'latitude': (json['latitude'] ?? json['lat'] ?? 0).toDouble(),
    'longitude': (json['longitude'] ?? json['lng'] ?? 0).toDouble(),
    'artworkId': json['artworkId'] ?? json['artwork_id'],
    'modelCID': json['modelCID'] ?? json['model_cid'],
    'modelURL': json['modelURL'] ?? json['model_url'],
    'storageProvider': json['storageProvider'] ?? json['storage_provider'] ?? 'hybrid',
    'scale': (json['scale'] ?? 1.0).toDouble(),
    'rotation': json['rotation'],
    'enableAnimation': json['enableAnimation'] ?? json['animate'] ?? false,
    'animationName': json['animationName'] ?? json['animation_name'],
    'enablePhysics': json['enablePhysics'] ?? false,
    'enableInteraction': json['enableInteraction'] ?? true,
    'metadata': json['metadata'] ?? json['meta'],
    'tags': json['tags'],
    'category': json['category'] ?? json['markerType'] ?? json['type'] ?? 'General',
    'createdAt': json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String(),
    'createdBy': json['createdBy'] ?? json['created_by'] ?? 'system',
    'viewCount': json['viewCount'] ?? json['views'] ?? 0,
    'interactionCount': json['interactionCount'] ?? json['interactions'] ?? 0,
    'activationRadius': json['activationRadius'] ?? json['activation_radius'] ?? 50.0,
    'requiresProximity': json['requiresProximity'] ?? json['requires_proximity'] ?? true,
    'isPublic': json['isPublic'] ?? json['is_public'] ?? true,
    'markerType': json['markerType'] ?? json['type'],
  };

  return ArtMarker.fromMap(normalized);
}

Artwork _artworkFromBackendJson(Map<String, dynamic> json) {
  String stringVal(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

  final id = stringVal(json['id'] ?? json['_id'] ?? '');
  final title = stringVal(json['title'] ?? json['name'] ?? '');
  final artist = stringVal(
    json['artist'] ??
    json['artistName'] ??
    json['walletAddress'] ??
    json['wallet_address'] ??
    'Unknown Artist',
  );

  return Artwork(
    id: id,
    title: title,
    artist: artist,
    description: stringVal(json['description'], ''),
    imageUrl: json['imageUrl'] as String?,
    position: LatLng(
      (json['latitude'] as num?)?.toDouble() ?? 0.0,
      (json['longitude'] as num?)?.toDouble() ?? 0.0,
    ),
    rarity: ArtworkRarity.values.firstWhere(
      (e) => e.name == json['rarity'],
      orElse: () => ArtworkRarity.common,
    ),
    rewards: json['rewards'] as int? ?? 10,
    category: stringVal(json['category'], 'General'),
    model3DURL: json['model3DURL'] as String? ?? json['model_3d_url'] as String?,
    model3DCID: json['model3DCID'] as String? ?? json['model_3d_cid'] as String?,
    arEnabled: json['arEnabled'] as bool? ?? json['isAREnabled'] as bool? ?? false,
    arMarkerId: json['arMarkerId'] as String?,
    createdAt: json['createdAt'] != null 
      ? DateTime.parse(json['createdAt'] as String)
      : DateTime.now(),
    tags: json['tags'] != null 
      ? (json['tags'] as List<dynamic>).map((e) => e.toString()).toList()
      : [],
    likesCount: json['likesCount'] as int? ?? 0,
    commentsCount: json['commentsCount'] as int? ?? 0,
    viewsCount: json['viewsCount'] as int? ?? 0,
    discoveryCount: json['discoveryCount'] as int? ?? 0,
  );
}

String? _normalizeBackendAvatarUrl(String? raw) {
  if (raw == null) return null;
  var candidate = raw.trim();
  if (candidate.isEmpty) return null;
  try {
    if (candidate.startsWith('ipfs://')) {
      final cid = candidate.replaceFirst('ipfs://', '');
      return 'https://ipfs.io/ipfs/$cid';
    }
    if (candidate.startsWith('//')) {
      return 'https:$candidate';
    }
    if (candidate.startsWith('/')) {
      final base = ApiKeys.backendUrl.replaceAll(RegExp(r'/$'), '');
      return '$base$candidate';
    }
    if (candidate.startsWith('api/')) {
      final base = ApiKeys.backendUrl.replaceAll(RegExp(r'/$'), '');
      return '$base/$candidate';
    }
  } catch (_) {}
  return candidate;
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
    avatarUrl: _normalizeBackendAvatarUrl(avatarCandidate),
    likedAt: likedAt,
  );
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

  // Parse original post for reposts
  CommunityPost? originalPost;
  if (json['originalPost'] != null && json['originalPost'] is Map<String, dynamic>) {
    final origJson = json['originalPost'] as Map<String, dynamic>;
    final origAuthor = origJson['author'] as Map<String, dynamic>?;
    
    originalPost = CommunityPost(
      id: origJson['id'] as String,
      authorId: origJson['walletAddress'] as String? ?? 'unknown',
      authorWallet: origJson['walletAddress'] as String?,
      authorName: origAuthor?['displayName'] as String? ?? origAuthor?['username'] as String? ?? 'Anonymous',
      authorAvatar: _normalizeBackendAvatarUrl(origAuthor?['avatar'] as String?),
      authorUsername: origAuthor?['username'] as String?,
      content: origJson['content'] as String,
      imageUrl: origJson['mediaUrls'] != null && (origJson['mediaUrls'] as List).isNotEmpty 
          ? (origJson['mediaUrls'] as List).first as String? 
          : null,
      timestamp: origJson['createdAt'] != null 
          ? DateTime.parse(origJson['createdAt'] as String)
          : DateTime.now(),
    );
  }

  return CommunityPost(
    id: json['id'] as String,
    authorId: json['authorId'] as String? ?? json['walletAddress'] as String? ?? json['userId'] as String? ?? 'unknown',
    authorWallet: authorWalletCandidate,
    authorName: resolvedAuthorName,
    authorAvatar: _normalizeBackendAvatarUrl(avatarCandidate),
    authorUsername: rawUsername,
    content: json['content'] as String,
    imageUrl: json['imageUrl'] as String? ?? 
              (json['mediaUrls'] != null && (json['mediaUrls'] as List).isNotEmpty 
                ? (json['mediaUrls'] as List).first as String? 
                : null),
    timestamp: json['createdAt'] != null 
      ? DateTime.parse(json['createdAt'] as String)
      : (json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now()),
    tags: json['tags'] != null 
      ? (json['tags'] as List<dynamic>).map((e) => e as String).toList()
      : [],
    postType: json['postType'] as String?,
    originalPostId: json['originalPostId'] as String?,
    originalPost: originalPost,
    likeCount: stats?['likes'] as int? ?? json['likes'] as int? ?? json['likeCount'] as int? ?? 0,
    shareCount: stats?['shares'] as int? ?? json['shares'] as int? ?? json['shareCount'] as int? ?? 0,
    commentCount: stats?['comments'] as int? ?? json['comments'] as int? ?? json['commentCount'] as int? ?? 0,
    viewCount: stats?['views'] as int? ?? json['views'] as int? ?? json['viewCount'] as int? ?? 0,
    isLiked: json['isLiked'] as bool? ?? false,
    isBookmarked: json['isBookmarked'] as bool? ?? false,
    isFollowing: json['isFollowing'] as bool? ?? false,
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

  try {
    debugPrint('BackendApiService._commentFromBackendJson parsed: id=${json['id']}, authorId=$authorId, authorWallet=$resolvedAuthorWallet, authorName=$resolvedAuthorName, avatarCandidate=$avatarCandidate');
  } catch (_) {}
  return Comment(
  id: (json['id'] ?? '').toString(),
  authorId: authorId,
  authorName: resolvedAuthorName,
  authorAvatar: _normalizeBackendAvatarUrl(avatarCandidate),
  authorUsername: authorUsername,
  authorWallet: resolvedAuthorWallet ?? authorId,
  parentCommentId: json['parentCommentId'] as String? ?? json['parent_comment_id']?.toString(),
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

