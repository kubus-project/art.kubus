import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_keys.dart';
import '../models/ar_marker.dart';
import '../models/artwork.dart';
import '../community/community_interactions.dart';

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

  /// Set authentication token for API requests
  void setAuthToken(String token) {
    _authToken = token;
    debugPrint('BackendApiService: Auth token set');
  }

  /// Load auth token from secure storage
  Future<void> loadAuthToken() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token != null && token.isNotEmpty) {
        _authToken = token;
        debugPrint('BackendApiService: Auth token loaded from secure storage');
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
  }

  /// Get common headers for API requests
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
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
        if (data['token'] != null) {
          final token = data['token'] as String;
          setAuthToken(token);
          // Store token in secure storage
          try {
            await _secureStorage.write(key: 'jwt_token', value: token);
            debugPrint('JWT token stored in secure storage');
          } catch (e) {
            debugPrint('Error storing JWT token: $e');
          }
        }
        return data;
      } else {
        throw Exception('Login failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error logging in: $e');
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

  /// Update user profile
  /// PUT /api/users/:userId
  Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: _getHeaders(),
        body: jsonEncode(updates),
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/profiles/$walletAddress'),
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        // Log raw response for debugging parsing issues
        debugPrint('BackendApiService.getProfileByWallet: response body: ${response.body}');
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final profile = data['data'] as Map<String, dynamic>;
        debugPrint('BackendApiService.getProfileByWallet: parsed profile keys: ${profile.keys.toList()}');
        return profile;
      } else if (response.statusCode == 404) {
        throw Exception('Profile not found');
      } else {
        throw Exception('Failed to get profile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting profile by wallet: $e');
      rethrow;
    }
  }

  /// Create or update profile
  /// POST /api/profiles
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> profileData) async {
    const int maxRetries = 3;
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/profiles'),
          headers: _getHeaders(includeAuth: false),
          body: jsonEncode(profileData),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['token'] != null) {
            setAuthToken(data['token'] as String);
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

  /// Get nearby AR markers (geospatial query)
  /// GET /api/ar-markers?lat=&lng=&radius=
  Future<List<ARMarker>> getNearbyMarkers({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/ar-markers').replace(queryParameters: {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radiusKm.toString(),
      });

      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final markers = data['markers'] as List<dynamic>;
        return markers.map((json) => _arMarkerFromBackendJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get markers: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting nearby markers: $e');
      rethrow;
    }
  }

  /// Create a new AR marker
  /// POST /api/ar-markers
  Future<ARMarker> createARMarker({
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
        Uri.parse('$baseUrl/api/ar-markers'),
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
        return _arMarkerFromBackendJson(data['marker'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to create marker: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error creating AR marker: $e');
      rethrow;
    }
  }

  /// Increment marker views
  /// POST /api/ar-markers/:id/view
  Future<void> incrementMarkerViews(String markerId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/ar-markers/$markerId/view'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error incrementing marker views: $e');
    }
  }

  /// Increment marker interactions
  /// POST /api/ar-markers/:id/interact
  Future<void> incrementMarkerInteractions(String markerId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/ar-markers/$markerId/interact'),
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
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final artworks = data['artworks'] as List<dynamic>;
        return artworks.map((json) => _artworkFromBackendJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get artworks: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting artworks: $e');
      rethrow;
    }
  }

  /// Get single artwork by ID
  /// GET /api/artworks/:id
  Future<Artwork> getArtwork(String artworkId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/artworks/$artworkId'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _artworkFromBackendJson(data['artwork'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get artwork: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting artwork: $e');
      rethrow;
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
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (arOnly != null) queryParams['arOnly'] = arOnly.toString();
      if (authorWallet != null) queryParams['authorWallet'] = authorWallet;

      final uri = Uri.parse('$baseUrl/api/community/posts').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final posts = data['data'] as List<dynamic>;
        return posts.map((json) => _communityPostFromBackendJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get posts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting community posts: $e');
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
        return _communityPostFromBackendJson(data['data'] as Map<String, dynamic>);
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
  Future<void> likePost(String postId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/community/posts/$postId/like'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error liking post: $e');
    }
  }

  /// Share a post
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

  /// Unlike a post
  /// DELETE /api/community/posts/:id/like
  Future<void> unlikePost(String postId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/community/posts/$postId/like'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error unliking post: $e');
    }
  }

  /// Create a comment on a post
  /// POST /api/community/posts/:id/comments
  Future<Comment> createComment({
    required String postId,
    required String content,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/community/posts/$postId/comments'),
        headers: _getHeaders(),
        body: jsonEncode({
          'content': content,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _commentFromBackendJson(data['comment'] as Map<String, dynamic>);
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
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/community/posts/$postId/comments')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final comments = data['comments'] as List<dynamic>;
        return comments.map((json) => _commentFromBackendJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get comments: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting comments: $e');
      rethrow;
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
  Future<void> likeComment(String commentId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/community/comments/$commentId/like'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error liking comment: $e');
    }
  }

  /// Unlike a comment
  /// DELETE /api/community/comments/:id/like
  Future<void> unlikeComment(String commentId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/community/comments/$commentId/like'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error unliking comment: $e');
    }
  }

  // ==================== Follow Endpoints ====================

  /// Follow a user
  /// POST /api/users/:id/follow
  Future<void> followUser(String userId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/users/$userId/follow'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error following user: $e');
      rethrow;
    }
  }

  /// Unfollow a user
  /// DELETE /api/users/:id/follow
  Future<void> unfollowUser(String userId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/users/$userId/follow'),
        headers: _getHeaders(),
      );
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
      rethrow;
    }
  }

  /// Get user's followers
  /// GET /api/users/:id/followers
  Future<List<Map<String, dynamic>>> getFollowers({
    required String userId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/users/$userId/followers')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['followers'] as List<dynamic>)
            .map((json) => json as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to get followers: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting followers: $e');
      rethrow;
    }
  }

  /// Get users that a user is following
  /// GET /api/users/:id/following
  Future<List<Map<String, dynamic>>> getFollowing({
    required String userId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/api/users/$userId/following')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['following'] as List<dynamic>)
            .map((json) => json as Map<String, dynamic>)
            .toList();
      } else {
        throw Exception('Failed to get following: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting following: $e');
      rethrow;
    }
  }

  /// Check if current user is following a user
  /// GET /api/users/:id/is-following
  Future<bool> isFollowing(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId/is-following'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['isFollowing'] as bool;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('Error checking follow status: $e');
      return false;
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
  /// Returns empty list if endpoint is not available yet (404)
  Future<List<Map<String, dynamic>>> getDAOProposals() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dao/proposals'),
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['proposals'] ?? data['data'] ?? []) as List;
        return List<Map<String, dynamic>>.from(list);
      } else if (response.statusCode == 404) {
        // Endpoint not available yet on backend
        return [];
      } else {
        throw Exception('Failed to get DAO proposals: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting DAO proposals: $e');
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

  /// List votes for a proposal or all votes
  /// GET /api/dao/proposals/:id/votes or /api/dao/votes
  Future<List<Map<String, dynamic>>> getDAOVotes({String? proposalId}) async {
    try {
      final uri = proposalId == null
          ? Uri.parse('$baseUrl/api/dao/votes')
          : Uri.parse('$baseUrl/api/dao/proposals/$proposalId/votes');
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
        final list = (data['transactions'] ?? data['data'] ?? []) as List;
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
            if (data.containsKey('url') && (data['url'] as String).isNotEmpty) uploadedUrl = data['url'] as String;
            else if (data.containsKey('ipfsUrl') && (data['ipfsUrl'] as String).isNotEmpty) uploadedUrl = data['ipfsUrl'] as String;
            else if (data.containsKey('httpUrl') && (data['httpUrl'] as String).isNotEmpty) uploadedUrl = data['httpUrl'] as String;
            else if (data.containsKey('fileUrl') && (data['fileUrl'] as String).isNotEmpty) uploadedUrl = data['fileUrl'] as String;
            else if (data.containsKey('path') && (data['path'] as String).isNotEmpty) uploadedUrl = data['path'] as String;
          } catch (_) {
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
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      
      if (walletAddress != null) {
        queryParams['walletAddress'] = walletAddress;
      }

      final uri = Uri.parse('$baseUrl/api/collections').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _getHeaders(includeAuth: false));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final collections = jsonData['data'] as List<dynamic>;
        return collections.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to fetch collections: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching collections: $e');
      return [];
    }
  }

  /// Get collection by ID with artworks
  /// GET /api/collections/:id
  Future<Map<String, dynamic>> getCollection(String collectionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/collections/$collectionId'),
        headers: _getHeaders(includeAuth: false),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return jsonData['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Failed to fetch collection: ${response.statusCode}');
      }
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
}

// Helper functions for model conversions
ARMarker _arMarkerFromBackendJson(Map<String, dynamic> json) {
  return ARMarker(
    id: json['id'] as String,
    name: json['title'] as String,
    description: json['description'] as String? ?? '',
    position: LatLng(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    ),
    artworkId: json['artworkId'] as String? ?? '',
    modelCID: json['modelCID'] as String?,
    modelURL: json['modelURL'] as String?,
    storageProvider: StorageProvider.values.firstWhere(
      (e) => e.name == json['storageProvider'],
      orElse: () => StorageProvider.ipfs,
    ),
    viewCount: json['views'] as int? ?? 0,
    interactionCount: json['interactions'] as int? ?? 0,
    createdAt: json['createdAt'] != null 
      ? DateTime.parse(json['createdAt'] as String)
      : DateTime.now(),
    createdBy: json['createdBy'] as String? ?? 'system',
  );
}

Artwork _artworkFromBackendJson(Map<String, dynamic> json) {
  return Artwork(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    description: json['description'] as String? ?? '',
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
    category: json['category'] as String? ?? 'General',
    model3DURL: json['model3DURL'] as String?,
    model3DCID: json['model3DCID'] as String?,
    arEnabled: json['arEnabled'] as bool? ?? false,
    arMarkerId: json['arMarkerId'] as String?,
    createdAt: json['createdAt'] != null 
      ? DateTime.parse(json['createdAt'] as String)
      : DateTime.now(),
    tags: json['tags'] != null 
      ? (json['tags'] as List<dynamic>).map((e) => e as String).toList()
      : [],
    likesCount: json['likesCount'] as int? ?? 0,
    commentsCount: json['commentsCount'] as int? ?? 0,
    viewsCount: json['viewsCount'] as int? ?? 0,
    discoveryCount: json['discoveryCount'] as int? ?? 0,
  );
}

CommunityPost _communityPostFromBackendJson(Map<String, dynamic> json) {
  // Extract nested author object if present
  final author = json['author'] as Map<String, dynamic>?;
  // Extract nested stats object if present
  final stats = json['stats'] as Map<String, dynamic>?;
  
  return CommunityPost(
    id: json['id'] as String,
    authorId: json['authorId'] as String? ?? json['walletAddress'] as String? ?? json['userId'] as String? ?? 'unknown',
    authorName: author?['username'] as String? ?? author?['display_name'] as String? ?? json['username'] as String? ?? json['authorName'] as String? ?? 'Anonymous',
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
  return Comment(
    id: json['id'] as String,
    authorId: json['authorId'] as String? ?? json['userId'] as String? ?? 'unknown',
    authorName: json['username'] as String? ?? json['authorName'] as String? ?? 'Anonymous',
    content: json['content'] as String,
    timestamp: json['createdAt'] != null 
      ? DateTime.parse(json['createdAt'] as String)
      : (json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now()),
    likeCount: json['likes'] as int? ?? json['likeCount'] as int? ?? 0,
    isLiked: json['isLiked'] as bool? ?? false,
  );
}
