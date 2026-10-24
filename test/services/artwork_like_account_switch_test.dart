import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/artwork_comment.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Records artwork like requests and can be told to fail them.
class _LikeRecordingApi implements ArtworkBackendApi {
  final List<String> likeCalls = <String>[];
  Object? likeError;
  int? likeReturn = 1;

  @override
  Future<int?> likeArtwork(String artworkId) async {
    likeCalls.add(artworkId);
    final error = likeError;
    if (error != null) throw error;
    return likeReturn;
  }

  @override
  Future<int?> unlikeArtwork(String artworkId) =>
      throw UnimplementedError('unlike is not used here');

  @override
  Future<Artwork> getArtwork(String artworkId) =>
      throw StateError('artwork $artworkId must be seeded, not fetched');

  @override
  Future<List<Artwork>> getArtworks({
    String? category,
    bool? arEnabled,
    int page = 1,
    int limit = 20,
    String? walletAddress,
    bool includePrivateForWallet = false,
    List<String>? ids,
  }) =>
      throw UnimplementedError();

  @override
  Future<Artwork?> updateArtwork(
          String artworkId, Map<String, dynamic> updates) =>
      throw UnimplementedError();

  @override
  Future<Artwork?> publishArtwork(String artworkId) =>
      throw UnimplementedError();

  @override
  Future<Artwork?> unpublishArtwork(String artworkId) =>
      throw UnimplementedError();

  @override
  Future<int?> discoverArtworkWithCount(String artworkId) =>
      throw UnimplementedError();

  @override
  Future<int?> recordArtworkView(String artworkId) =>
      throw UnimplementedError();

  @override
  Future<List<ArtworkComment>> getArtworkComments({
    required String artworkId,
    int page = 1,
    int limit = 50,
  }) =>
      throw UnimplementedError();

  @override
  Future<ArtworkComment> createArtworkComment({
    required String artworkId,
    required String content,
    String? parentCommentId,
  }) =>
      throw UnimplementedError();

  @override
  Future<ArtworkComment> editArtworkComment({
    required String commentId,
    required String content,
  }) =>
      throw UnimplementedError();

  @override
  Future<int?> deleteArtworkComment(String commentId) =>
      throw UnimplementedError();

  @override
  Future<int?> likeComment(String commentId) => throw UnimplementedError();

  @override
  Future<int?> unlikeComment(String commentId) => throw UnimplementedError();
}

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);
}

Artwork _artwork({
  bool liked = false,
  bool favorite = false,
  int likesCount = 5,
}) =>
    Artwork(
      id: 'art-1',
      title: 'Harbour Light',
      artist: 'Artist',
      description: 'Description',
      position: const LatLng(46.0511, 14.5051),
      rewards: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      likesCount: likesCount,
      isLikedByCurrentUser: liked,
      isFavoriteByCurrentUser: favorite,
    );

PendingActionIntent _artworkLike() => PendingActionIntent.create(
      actionType: PendingActionType.like,
      targetType: PendingActionTargetType.artwork,
      targetId: 'art-1',
      returnRoute: '/artwork/art-1',
      sourceScreen: 'artwork_detail',
    )!;

Future<PendingActionExecutionResult> _confirmLike(
  ArtworkProvider artworks,
) =>
    const PendingActionExecutor().execute(
      intent: _artworkLike(),
      artworkProvider: artworks,
      savedItemsProvider: SavedItemsProvider(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  group('clearAccountScopedState', () {
    test('drops the viewer-relative flags and keeps public artwork data', () {
      final api = _LikeRecordingApi();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[
        _artwork(liked: true, favorite: true),
      ]);

      artworks.clearAccountScopedState();

      final cleared = artworks.getArtworkById('art-1')!;
      expect(cleared.isLikedByCurrentUser, isFalse);
      expect(cleared.isFavoriteByCurrentUser, isFalse);
      expect(cleared.title, 'Harbour Light');
      expect(cleared.likesCount, 5);
      expect(artworks.artworks.single.isLikedByCurrentUser, isFalse);
    });
  });

  group('like confirmed after an account switch', () {
    test('logout clears the ending account likes and bookmarks', () async {
      final api = _LikeRecordingApi();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[
        _artwork(liked: true, favorite: true),
      ]);

      await SettingsService.logout(
        walletProvider: _Wallet(),
        backendApi: BackendApiService(),
        artworkProvider: artworks,
        preserveWallet: true,
      );

      final cleared = artworks.getArtworkById('art-1')!;
      expect(cleared.isLikedByCurrentUser, isFalse);
      expect(cleared.isFavoriteByCurrentUser, isFalse);
    });

    test('the next account like issues exactly one backend like', () async {
      final api = _LikeRecordingApi();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[
        _artwork(liked: true),
      ]);

      await SettingsService.logout(
        walletProvider: _Wallet(),
        backendApi: BackendApiService(),
        artworkProvider: artworks,
        preserveWallet: true,
      );
      final result = await _confirmLike(artworks);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(api.likeCalls, <String>['art-1']);
      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isTrue);
    });

    test(
        'a stale cached like still reaches the server, never completes '
        'without a write', () async {
      final api = _LikeRecordingApi();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[
        _artwork(liked: true),
      ]);

      final result = await _confirmLike(artworks);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(api.likeCalls, <String>['art-1']);
    });

    test('a rejected backend like is reported failed and rolled back',
        () async {
      final api = _LikeRecordingApi()..likeError = Exception('network down');
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[_artwork()]);

      final result = await _confirmLike(artworks);

      expect(result.outcome, PendingActionOutcome.failed);
      expect(api.likeCalls, <String>['art-1']);
      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isFalse);
      expect(artworks.getArtworkById('art-1')!.likesCount, 5);
    });

    test('a confirmed like on an already liked cache keeps the count',
        () async {
      final api = _LikeRecordingApi()..likeReturn = null;
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[_artwork(liked: true)]);

      final ok = await artworks.setLiked('art-1', true, confirmOnServer: true);

      expect(ok, isTrue);
      expect(api.likeCalls, <String>['art-1']);
      expect(artworks.getArtworkById('art-1')!.likesCount, 5);
    });

    test('an ordinary like on a matching cache is still a no-op', () async {
      final api = _LikeRecordingApi();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[_artwork(liked: true)]);

      final ok = await artworks.setLiked('art-1', true);

      expect(ok, isTrue);
      expect(api.likeCalls, isEmpty);
    });
  });
}
