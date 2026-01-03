import 'dart:async';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/artwork_comment.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeArtworkApi implements ArtworkBackendApi {
  _FakeArtworkApi({required Completer<ArtworkComment> createCompleter})
      : _createCompleter = createCompleter;

  final Completer<ArtworkComment> _createCompleter;
  ArtworkComment? _created;

  void setCreated(ArtworkComment comment) => _created = comment;

  @override
  Future<ArtworkComment> createArtworkComment({
    required String artworkId,
    required String content,
    String? parentCommentId,
  }) async {
    final created = await _createCompleter.future;
    _created = created;
    return created;
  }

  @override
  Future<List<ArtworkComment>> getArtworkComments({
    required String artworkId,
    int page = 1,
    int limit = 50,
  }) async {
    final created = _created;
    return created == null ? <ArtworkComment>[] : <ArtworkComment>[created];
  }

  @override
  Future<List<Artwork>> getArtworks({
    String? category,
    bool? arEnabled,
    int page = 1,
    int limit = 20,
    String? walletAddress,
    bool includePrivateForWallet = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<Artwork> getArtwork(String artworkId) => throw UnimplementedError();

  @override
  Future<Artwork?> updateArtwork(String artworkId, Map<String, dynamic> updates) =>
      throw UnimplementedError();

  @override
  Future<Artwork?> publishArtwork(String artworkId) => throw UnimplementedError();

  @override
  Future<Artwork?> unpublishArtwork(String artworkId) => throw UnimplementedError();

  @override
  Future<int?> likeArtwork(String artworkId) => throw UnimplementedError();

  @override
  Future<int?> unlikeArtwork(String artworkId) => throw UnimplementedError();

  @override
  Future<int?> discoverArtworkWithCount(String artworkId) => throw UnimplementedError();

  @override
  Future<int?> recordArtworkView(String artworkId) => throw UnimplementedError();

  @override
  Future<ArtworkComment> editArtworkComment({required String commentId, required String content}) =>
      throw UnimplementedError();

  @override
  Future<int?> deleteArtworkComment(String commentId) => throw UnimplementedError();

  @override
  Future<int?> likeComment(String commentId) => throw UnimplementedError();

  @override
  Future<int?> unlikeComment(String commentId) => throw UnimplementedError();
}

class _FakeProfileApi implements ProfileBackendApi {
  Map<String, dynamic>? lastPayload;

  @override
  String get baseUrl => AppConfig.baseApiUrl;

  @override
  Future<Map<String, dynamic>> saveProfile(Map<String, dynamic> profileData) async {
    lastPayload = profileData;
    final wallet = (profileData['walletAddress'] ?? '').toString();
    final now = DateTime.now().toUtc().toIso8601String();
    return <String, dynamic>{
      'id': 'profile_$wallet',
      'walletAddress': wallet,
      'username': (profileData['username'] ?? 'user_test').toString(),
      'displayName': (profileData['displayName'] ?? 'Test User').toString(),
      'bio': (profileData['bio'] ?? '').toString(),
      'avatar': (profileData['avatar'] ?? '').toString(),
      'coverImage': (profileData['coverImage'] ?? '').toString(),
      'social': profileData['social'] is Map<String, dynamic> ? profileData['social'] : <String, dynamic>{},
      'isArtist': profileData['isArtist'] == true,
      'isInstitution': profileData['isInstitution'] == true,
      if (profileData['artistInfo'] is Map<String, dynamic>) 'artistInfo': profileData['artistInfo'],
      'createdAt': now,
      'updatedAt': now,
    };
  }

  @override
  Future<Map<String, dynamic>> registerWallet({required String walletAddress, String? username}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> getProfileByWallet(String walletAddress) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> updateProfile(String walletAddress, Map<String, dynamic> updates) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> uploadAvatarToProfile({
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
    Map<String, String>? metadata,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> followUser(String walletAddress) => throw UnimplementedError();

  @override
  Future<void> unfollowUser(String walletAddress) => throw UnimplementedError();

  @override
  Future<bool> isFollowing(String walletAddress) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getDAOReview({required String idOrWallet}) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('ArtworkProvider.addComment updates list and count immediately', () async {
    final createCompleter = Completer<ArtworkComment>();
    final api = _FakeArtworkApi(createCompleter: createCompleter);
    final provider = ArtworkProvider(backendApi: api);

    const artworkId = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
    provider.addOrUpdateArtwork(
      Artwork(
        id: artworkId,
        title: 'Test Artwork',
        artist: 'Artist',
        description: 'Desc',
        position: const LatLng(0, 0),
        rewards: 0,
        createdAt: DateTime.now(),
      ),
    );

    final future = provider.addComment(artworkId, 'Hello provider', 'wallet_1', 'Tester');
    await Future<void>.delayed(Duration.zero);

    expect(provider.getComments(artworkId), isNotEmpty);
    expect(provider.getComments(artworkId).first.content, 'Hello provider');
    expect(provider.getArtworkById(artworkId)!.commentsCount, 1);

    final created = ArtworkComment(
      id: 'server_1',
      artworkId: artworkId,
      userId: 'wallet_1',
      userName: 'Tester',
      content: 'Hello provider',
      createdAt: DateTime.now().subtract(const Duration(seconds: 1)),
    );
    createCompleter.complete(created);
    await future;

    final comments = provider.getComments(artworkId);
    expect(comments, isNotEmpty);
    expect(comments.first.id, 'server_1');
    expect(provider.getArtworkById(artworkId)!.commentsCount, 1);
  });

  test('ProfileProvider.saveProfile persists fieldOfWork + yearsActive', () async {
    final api = _FakeProfileApi();
    final provider = ProfileProvider(apiService: api);
    await provider.initialize();

    const wallet = 'wallet_2';
    final ok = await provider.saveProfile(
      walletAddress: wallet,
      username: 'tester',
      displayName: 'Tester',
      isArtist: true,
      fieldOfWork: const ['AR', 'Sculpture'],
      yearsActive: 7,
      reloadStats: false,
    );

    expect(ok, isTrue);
    expect(api.lastPayload, isNotNull);
    expect(api.lastPayload!['artistInfo'], isA<Map<String, dynamic>>());
    expect((api.lastPayload!['artistInfo'] as Map<String, dynamic>)['specialty'], ['AR', 'Sculpture']);
    expect((api.lastPayload!['artistInfo'] as Map<String, dynamic>)['yearsActive'], 7);

    final profile = provider.currentUser;
    expect(profile, isNotNull);
    expect(profile!.artistInfo, isNotNull);
    expect(profile.artistInfo!.specialty, ['AR', 'Sculpture']);
    expect(profile.artistInfo!.yearsActive, 7);
  });
}
