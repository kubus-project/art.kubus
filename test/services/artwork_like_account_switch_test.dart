import 'dart:async';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/artwork_comment.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:art_kubus/utils/wallet_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// A backend that remembers what the server holds: which artworks exist and
/// which ones this account likes. A like the outbox queues never reaches it.
class _ServerApi implements ArtworkBackendApi {
  /// Artworks the server serves by id.
  final Map<String, Artwork> served = <String, Artwork>{};

  /// Artworks listed for a wallet, keyed by canonical wallet.
  final Map<String, List<Artwork>> walletArtworks = <String, List<Artwork>>{};

  /// Set to hold the wallet listing open until the test completes it.
  Completer<List<Artwork>>? walletGate;

  final Set<String> likedOnServer = <String>{};
  final List<String> likeCalls = <String>[];
  final List<String> getCalls = <String>[];
  final List<String> walletCalls = <String>[];

  Object? likeError;

  /// Simulates an offline write: the request is queued and no body returns.
  bool likeQueued = false;

  @override
  Future<int?> likeArtwork(String artworkId) async {
    likeCalls.add(artworkId);
    final error = likeError;
    if (error != null) throw error;
    if (likeQueued) return null;
    likedOnServer.add(artworkId);
    return 6;
  }

  @override
  Future<int?> unlikeArtwork(String artworkId) =>
      throw UnimplementedError('unlike is not used here');

  @override
  Future<Artwork> getArtwork(String artworkId) async {
    getCalls.add(artworkId);
    final artwork = served[artworkId];
    if (artwork == null) throw StateError('no artwork $artworkId');
    return artwork.copyWith(
      isLikedByCurrentUser: likedOnServer.contains(artworkId),
    );
  }

  @override
  Future<List<Artwork>> getArtworks({
    String? category,
    bool? arEnabled,
    int page = 1,
    int limit = 20,
    String? walletAddress,
    bool includePrivateForWallet = false,
    List<String>? ids,
  }) async {
    if (ids != null) {
      return ids
          .map((id) => served[id])
          .whereType<Artwork>()
          .toList(growable: false);
    }
    if (walletAddress != null) {
      final key = WalletUtils.canonical(walletAddress);
      walletCalls.add(key);
      final gate = walletGate;
      walletGate = null;
      final listed = gate != null
          ? await gate.future
          : (walletArtworks[key] ?? const <Artwork>[]);
      return listed
          .where((artwork) => artwork.isPublic || includePrivateForWallet)
          .toList(growable: false);
    }
    return served.values.where((artwork) => artwork.isPublic).toList();
  }

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
  String id = 'art-1',
  String? walletAddress,
  bool isPublic = true,
  bool liked = false,
  bool favorite = false,
  int likesCount = 5,
  ArtworkStatus status = ArtworkStatus.undiscovered,
  DateTime? discoveredAt,
  String? discoveryUserId,
  int discoveryCount = 0,
}) =>
    Artwork(
      id: id,
      title: 'Harbour Light',
      artist: 'Artist',
      description: 'Description',
      position: const LatLng(46.0511, 14.5051),
      rewards: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      walletAddress: walletAddress,
      isPublic: isPublic,
      likesCount: likesCount,
      isLikedByCurrentUser: liked,
      isFavoriteByCurrentUser: favorite,
      status: status,
      discoveredAt: discoveredAt,
      discoveryUserId: discoveryUserId,
      discoveryCount: discoveryCount,
    );

/// A server that serves the public artwork `art-1`, not yet liked.
_ServerApi _server() => _ServerApi()..served['art-1'] = _artwork();

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

Future<void> _logout(ArtworkProvider artworks) => SettingsService.logout(
      walletProvider: _Wallet(),
      backendApi: BackendApiService(),
      artworkProvider: artworks,
      preserveWallet: true,
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
      final artworks = ArtworkProvider(backendApi: _server());
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

    test(
        'discovery state of the viewer is cleared, the public discovery count '
        'stays', () {
      final artworks = ArtworkProvider(backendApi: _server());
      artworks.seedArtworksForTesting(<Artwork>[
        _artwork(
          status: ArtworkStatus.discovered,
          discoveredAt: DateTime.utc(2026, 2, 1),
          discoveryUserId: 'WalletAAA',
          discoveryCount: 3,
        ),
      ]);

      artworks.clearAccountScopedState();

      final cleared = artworks.getArtworkById('art-1')!;
      expect(cleared.status, ArtworkStatus.undiscovered);
      expect(cleared.isDiscovered, isFalse);
      expect(cleared.discoveredAt, isNull);
      expect(cleared.discoveryUserId, isNull);
      expect(cleared.discoveryCount, 3);
    });
  });

  group('the ending account private and wallet-scoped artworks', () {
    test('are not listed or served after the switch to the next account',
        () async {
      final api = _server()
        ..walletArtworks['WALLETAAA'] = <Artwork>[
          _artwork(
            id: 'art-private',
            walletAddress: 'WALLETAAA',
            isPublic: false,
          ),
        ];
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[
        ...api.served.values,
      ]);
      await artworks.loadArtworksForWallet(
        'WALLETAAA',
        includePrivateForWallet: true,
      );
      expect(artworks.getArtworkById('art-private'), isNotNull);

      await _logout(artworks);

      expect(artworks.getArtworkById('art-private'), isNull);
      expect(
        artworks.artworks.map((artwork) => artwork.id),
        isNot(contains('art-private')),
      );
      expect(artworks.getArtworkById('art-1'), isNotNull);

      // The next account's wallet is listed from the server, and the ending
      // account's wallet set is not reused: it was dropped with the session.
      await artworks.loadArtworksForWallet(
        'WALLETBBB',
        includePrivateForWallet: true,
      );
      expect(api.walletCalls, <String>['WALLETAAA', 'WALLETBBB']);
      expect(artworks.getArtworkById('art-private'), isNull);

      await artworks.loadArtworksForWallet(
        'WALLETAAA',
        includePrivateForWallet: true,
      );
      expect(api.walletCalls.last, 'WALLETAAA');
    });

    test('a wallet listing still in flight cannot land after the switch',
        () async {
      final api = _server();
      final gate = Completer<List<Artwork>>();
      api.walletGate = gate;
      final artworks = ArtworkProvider(backendApi: api);

      final load = artworks.loadArtworksForWallet(
        'WALLETAAA',
        includePrivateForWallet: true,
      );
      await _logout(artworks);
      gate.complete(<Artwork>[
        _artwork(
          id: 'art-private',
          walletAddress: 'WALLETAAA',
          isPublic: false,
        ),
      ]);
      await load;

      expect(artworks.getArtworkById('art-private'), isNull);
      expect(
        artworks.artworks.map((artwork) => artwork.id),
        isNot(contains('art-private')),
      );
    });
  });

  group('view history of the ending account', () {
    test('is removed on logout and does not come back', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'artwork_view_history_v1': <String>[
          '{"artworkId":"art-1","viewedAt":"2026-01-01T00:00:00.000Z"}',
        ],
      });
      final artworks = ArtworkProvider(backendApi: _server());
      await artworks.ensureHistoryLoaded();
      expect(artworks.viewHistoryEntries, hasLength(1));

      await _logout(artworks);

      expect(artworks.viewHistoryEntries, isEmpty);
      await artworks.ensureHistoryLoaded();
      expect(artworks.viewHistoryEntries, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('artwork_view_history_v1'), isNull);
    });
  });

  group('like confirmed after an account switch', () {
    test('logout clears the ending account likes and bookmarks', () async {
      final artworks = ArtworkProvider(backendApi: _server());
      artworks.seedArtworksForTesting(<Artwork>[
        _artwork(liked: true, favorite: true),
      ]);

      await _logout(artworks);

      final cleared = artworks.getArtworkById('art-1')!;
      expect(cleared.isLikedByCurrentUser, isFalse);
      expect(cleared.isFavoriteByCurrentUser, isFalse);
    });

    test('the next account like issues exactly one backend like', () async {
      final api = _server();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[
        _artwork(liked: true),
      ]);

      await _logout(artworks);
      final result = await _confirmLike(artworks);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(api.likeCalls, <String>['art-1']);
      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isTrue);
    });

    test(
        'a stale cached like still reaches the server, never completes '
        'without a write', () async {
      final api = _server();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[
        _artwork(liked: true),
      ]);

      final result = await _confirmLike(artworks);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(api.likeCalls, <String>['art-1']);
      expect(api.likedOnServer, contains('art-1'));
    });

    test('a queued offline like is not completed; the action stays retryable',
        () async {
      final api = _server()..likeQueued = true;
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[_artwork()]);

      final queued = await _confirmLike(artworks);

      expect(queued.outcome, PendingActionOutcome.failed);
      expect(api.likeCalls, <String>['art-1']);
      expect(api.likedOnServer, isEmpty);
      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isFalse);

      api.likeQueued = false;
      final retried = await _confirmLike(artworks);

      expect(retried.outcome, PendingActionOutcome.completed);
      expect(api.likeCalls, <String>['art-1', 'art-1']);
      expect(api.likedOnServer, contains('art-1'));
    });

    test('a rejected backend like is reported failed and rolled back',
        () async {
      final api = _server()..likeError = Exception('network down');
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[_artwork()]);

      final result = await _confirmLike(artworks);

      expect(result.outcome, PendingActionOutcome.failed);
      expect(api.likeCalls, <String>['art-1']);
      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isFalse);
      expect(artworks.getArtworkById('art-1')!.likesCount, 5);
    });

    test('a confirmed like on an already liked cache takes the server count',
        () async {
      final api = _server();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[_artwork(liked: true)]);

      final ok = await artworks.setLiked('art-1', true, confirmOnServer: true);

      expect(ok, isTrue);
      expect(api.likeCalls, <String>['art-1']);
      expect(artworks.getArtworkById('art-1')!.likesCount, 6);
    });

    test('an ordinary like on a matching cache is still a no-op', () async {
      final api = _server();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[_artwork(liked: true)]);

      final ok = await artworks.setLiked('art-1', true);

      expect(ok, isTrue);
      expect(api.likeCalls, isEmpty);
    });
  });
}
