import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/artwork_comment.dart';
import 'package:art_kubus/models/pending_action_intent.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/block_list_service.dart';
import 'package:art_kubus/services/pending_action_executor.dart';
import 'package:art_kubus/services/settings_service.dart';
import 'package:art_kubus/utils/wallet_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// A backend that remembers what the server holds. A like the outbox queues
/// never reaches it. A public read carries no viewer state, as the backend
/// only reports the viewer's like and bookmark for an authenticated request.
class _ServerApi implements ArtworkBackendApi {
  /// Artworks the server serves by id.
  final Map<String, Artwork> served = <String, Artwork>{};

  /// Artworks listed for a wallet, keyed by canonical wallet.
  final Map<String, List<Artwork>> walletArtworks = <String, List<Artwork>>{};

  /// Comments the server serves for an artwork.
  final List<ArtworkComment> comments = <ArtworkComment>[];

  /// Each gate holds the next call of its kind open until it is completed.
  Completer<List<Artwork>>? walletGate;
  Completer<Artwork>? getGate;
  Completer<void>? unlikeGate;
  Completer<List<ArtworkComment>>? commentsGate;

  final Set<String> likedOnServer = <String>{};
  final List<String> likeCalls = <String>[];
  final List<String> unlikeCalls = <String>[];
  final List<String> getCalls = <String>[];
  final List<String> walletCalls = <String>[];

  Object? likeError;
  Object? unlikeError;

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
  Future<int?> unlikeArtwork(String artworkId) async {
    unlikeCalls.add(artworkId);
    final gate = unlikeGate;
    unlikeGate = null;
    if (gate != null) await gate.future;
    final error = unlikeError;
    if (error != null) throw error;
    likedOnServer.remove(artworkId);
    return 4;
  }

  @override
  Future<Artwork> getArtwork(String artworkId) async {
    getCalls.add(artworkId);
    final gate = getGate;
    getGate = null;
    if (gate != null) return gate.future;
    final artwork = served[artworkId];
    if (artwork == null) throw StateError('no artwork $artworkId');
    return artwork.copyWith(
      isLikedByCurrentUser: false,
      isFavoriteByCurrentUser: false,
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
    return served.values
        .where((artwork) => artwork.isPublic)
        .toList(growable: false);
  }

  @override
  Future<List<ArtworkComment>> getArtworkComments({
    required String artworkId,
    int page = 1,
    int limit = 50,
  }) async {
    final gate = commentsGate;
    commentsGate = null;
    if (gate != null) return gate.future;
    return List<ArtworkComment>.of(comments);
  }

  @override
  Future<int?> recordArtworkView(String artworkId) async => null;

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

ArtworkComment _comment() => ArtworkComment(
      id: 'comment-1',
      artworkId: 'art-1',
      userId: 'WalletAAA',
      userName: 'Visitor',
      content: 'Hello',
      createdAt: DateTime.utc(2026, 1, 1),
      isLikedByCurrentUser: true,
    );

/// A server that serves the public artwork `art-1`, not yet liked.
_ServerApi _server() => _ServerApi()..served['art-1'] = _artwork();

/// An unsigned token whose payload carries the given claims.
String _token(Map<String, Object> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part(<String, Object>{'alg': 'none'})}.${part(claims)}.sig';
}

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
      preserveWallet: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AccountIdentity.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
    // Every test starts as a guest with an empty block list in memory.
    await AccountIdentity.notifyChanged();
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
        'a confirmed like is confirmed by the like response alone, with no '
        'read-back', () async {
      final api = _server();
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[_artwork()]);

      final result = await _confirmLike(artworks);

      expect(result.outcome, PendingActionOutcome.completed);
      expect(api.likeCalls, <String>['art-1']);
      expect(api.getCalls, isEmpty);
    });

    test(
        'a public read never reports the viewer like, so a read-back could '
        'not confirm one', () async {
      final api = _server();
      await api.likeArtwork('art-1');

      final read = await api.getArtwork('art-1');

      expect(api.likedOnServer, contains('art-1'));
      expect(read.isLikedByCurrentUser, isFalse);
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

  group('writes already in flight when the account changes', () {
    test(
        'an unlike that fails after the switch does not restore the ending '
        'account like', () async {
      final api = _server()..likedOnServer.add('art-1');
      final artworks = ArtworkProvider(backendApi: api);
      artworks.seedArtworksForTesting(<Artwork>[_artwork(liked: true)]);
      final gate = Completer<void>();
      api.unlikeGate = gate;

      final pending = artworks.setLiked('art-1', false);
      await _logout(artworks);
      api.unlikeError = Exception('unauthorized');
      gate.complete();

      expect(await pending, isFalse);
      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isFalse);
    });

    test('a comment list that lands after the switch is discarded', () async {
      final api = _server();
      final gate = Completer<List<ArtworkComment>>();
      api.commentsGate = gate;
      final artworks = ArtworkProvider(backendApi: api);

      final load = artworks.loadComments('art-1');
      await _logout(artworks);
      gate.complete(<ArtworkComment>[_comment()]);
      await load;

      expect(artworks.getComments('art-1'), isEmpty);
    });

    test('a refresh that lands after the switch is not cached', () async {
      final api = _server();
      final gate = Completer<Artwork>();
      api.getGate = gate;
      final artworks = ArtworkProvider(backendApi: api);

      final refresh = artworks.refreshArtwork('art-private');
      await _logout(artworks);
      gate.complete(_artwork(
        id: 'art-private',
        walletAddress: 'WALLETAAA',
        isPublic: false,
      ));

      expect(await refresh, isNull);
      expect(artworks.getArtworkById('art-private'), isNull);
    });

    test('a view recorded before the switch is not written after it', () async {
      final artworks = ArtworkProvider(backendApi: _server());
      artworks.seedArtworksForTesting(<Artwork>[_artwork()]);

      final pending = artworks.incrementViewCount('art-1');
      await _logout(artworks);
      await pending;

      expect(artworks.viewHistoryEntries, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('artwork_view_history_v1'), isNull);
    });

    test('a run that finishes after a switch does not clear a newer run flag',
        () async {
      final api = _server();
      final first = Completer<Artwork>();
      final second = Completer<Artwork>();
      api.getGate = first;
      final artworks = ArtworkProvider(backendApi: api);

      final oldRun = artworks.refreshArtwork('art-1');
      await _logout(artworks);
      api.getGate = second;
      final newRun = artworks.refreshArtwork('art-1');
      expect(artworks.isLoading('refresh_artwork_art-1'), isTrue);

      first.complete(_artwork());
      await oldRun;
      expect(artworks.isLoading('refresh_artwork_art-1'), isTrue);

      second.complete(_artwork());
      await newRun;
      expect(artworks.isLoading('refresh_artwork_art-1'), isFalse);
    });
  });

  group('every identity change clears the ending account', () {
    test('the identity listener runs at the change, before any await',
        () async {
      var calls = 0;
      void listener() => calls += 1;
      AccountIdentity.addListener(listener);
      addTearDown(() => AccountIdentity.removeListener(listener));

      final pending = BackendApiService().clearAuth();

      expect(calls, 1);
      await pending;
      expect(calls, 1);
    });

    test(
        'clearAuth alone (a wallet mismatch or a deleted account) clears the '
        'artwork state', () async {
      final artworks = ArtworkProvider(backendApi: _server());
      artworks.seedArtworksForTesting(<Artwork>[
        _artwork(liked: true, favorite: true),
      ]);

      await BackendApiService().clearAuth();

      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isFalse);
      expect(
          artworks.getArtworkById('art-1')!.isFavoriteByCurrentUser, isFalse);
    });

    test('a token for another account clears the ending account state',
        () async {
      final api = BackendApiService();
      await api.setAuthToken(
        _token(<String, Object>{'walletAddress': 'WalletAAA', 'user_id': 'a'}),
      );
      final artworks = ArtworkProvider(backendApi: _server());
      artworks.seedArtworksForTesting(<Artwork>[_artwork(liked: true)]);

      await api.setAuthToken(
        _token(<String, Object>{'walletAddress': 'WalletBBB', 'user_id': 'b'}),
      );

      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isFalse);
    });

    test('a token for the same account keeps the artwork state', () async {
      final api = BackendApiService();
      final token = _token(<String, Object>{
        'walletAddress': 'WalletCCC',
        'user_id': 'c',
      });
      await api.setAuthToken(token);
      final artworks = ArtworkProvider(backendApi: _server());
      artworks.seedArtworksForTesting(<Artwork>[_artwork(liked: true)]);

      await api.setAuthToken(token);

      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isTrue);
    });

    test('disconnecting the wallet clears the ending account state', () async {
      final artworks = ArtworkProvider(backendApi: _server());
      artworks.seedArtworksForTesting(<Artwork>[_artwork(liked: true)]);

      await _Wallet().disconnectWallet().catchError((_) {});

      expect(artworks.getArtworkById('art-1')!.isLikedByCurrentUser, isFalse);
    });

    test('a disposed provider stops listening to identity changes', () {
      final before = AccountIdentity.listenerCount;
      final artworks = ArtworkProvider(backendApi: _server());
      expect(AccountIdentity.listenerCount, before + 1);

      artworks.dispose();

      expect(AccountIdentity.listenerCount, before);
    });
  });

  group('device-level account keys', () {
    const purgedKeys = <String>[
      'artwork_view_history_v1',
      'collectibles_v1',
      'collectible_series_v1',
      'institutions_v1',
      'institution_events_v1',
      'event_registrations_v1_event-1',
    ];

    test('an identity change purges them and keeps unrelated preferences',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'artwork_view_history_v1': '[]',
        'collectibles_v1': '[]',
        'collectible_series_v1': '[]',
        'institutions_v1': '[]',
        'institution_events_v1': '[]',
        'event_registrations_v1_event-1': '[]',
        'theme_mode': 'dark',
      });

      await AccountIdentity.notifyChanged();

      final prefs = await SharedPreferences.getInstance();
      for (final key in purgedKeys) {
        expect(prefs.containsKey(key), isFalse, reason: '$key survived');
      }
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('sign-out purges them too', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'artwork_view_history_v1': '[]',
        'collectibles_v1': '[]',
      });

      await _logout(ArtworkProvider(backendApi: _server()));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('artwork_view_history_v1'), isFalse);
      expect(prefs.containsKey('collectibles_v1'), isFalse);
    });
  });

  group('blocks and reports are kept per account', () {
    const walletX = 'WalletXXX';
    final tokenA = _token(<String, Object>{
      'walletAddress': 'WalletAAA',
      'user_id': 'user-a',
    });
    final tokenB = _token(<String, Object>{
      'walletAddress': 'WalletBBB',
      'user_id': 'user-b',
    });

    test('a block made by A is not seen by B, and is back for A on return',
        () async {
      final api = BackendApiService();
      final blocks = BlockListService();
      await api.setAuthToken(tokenA);
      await blocks.blockWallet(walletX);
      expect(await blocks.isWalletBlocked(walletX), isTrue);

      await api.setAuthToken(tokenB);
      expect(await blocks.isWalletBlocked(walletX), isFalse);

      await api.setAuthToken(tokenA);
      expect(await blocks.isWalletBlocked(walletX), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('blocked_wallets_v1.user-a'), contains(walletX));
      expect(prefs.containsKey('blocked_wallets_v1.user-b'), isFalse);
    });

    test('sign-out keeps the blocks, and a returning account gets them back',
        () async {
      final api = BackendApiService();
      final blocks = BlockListService();
      await api.setAuthToken(tokenA);
      await blocks.blockWallet(walletX);

      await api.clearAuth();
      expect(await blocks.isWalletBlocked(walletX), isFalse);

      await api.setAuthToken(tokenA);
      expect(await blocks.isWalletBlocked(walletX), isTrue);
    });

    test("a guest's blocks last for the session and never reach an account",
        () async {
      final api = BackendApiService();
      final blocks = BlockListService();
      await api.clearAuth();
      await blocks.blockWallet(walletX);
      expect(await blocks.isWalletBlocked(walletX), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.startsWith('blocked_wallets_v1')),
        isEmpty,
      );

      await api.setAuthToken(tokenA);
      expect(await blocks.isWalletBlocked(walletX), isFalse);
    });

    test(
        'blocks written before accounts were scoped go to the first account '
        'that signs in', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'blocked_wallets_v1': '["$walletX"]',
      });
      final api = BackendApiService();
      final blocks = BlockListService();

      await api.setAuthToken(tokenA);
      expect(await blocks.isWalletBlocked(walletX), isTrue);

      await api.setAuthToken(tokenB);
      expect(await blocks.isWalletBlocked(walletX), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('blocked_wallets_v1'), isFalse);
      expect(prefs.getString('blocked_wallets_v1.user-a'), contains(walletX));
    });

    test('reported posts follow the same rule: adopted once, then per account',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'reported_posts': <String>['post-1|spam|1'],
      });
      final api = BackendApiService();

      await api.setAuthToken(tokenA);
      await AccountIdentity.adoptLegacyRecords('user-a');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('reported_posts.user-a'),
        <String>['post-1|spam|1'],
      );
      expect(prefs.containsKey('reported_posts'), isFalse);

      await api.setAuthToken(tokenB);
      await AccountIdentity.adoptLegacyRecords('user-b');
      expect(prefs.containsKey('reported_posts.user-b'), isFalse);

      expect(
        AccountIdentity.scopedKey('reported_posts', accountKey: 'user-b'),
        'reported_posts.user-b',
      );
      expect(
        AccountIdentity.scopedKey('reported_posts', accountKey: ''),
        isNull,
      );
    });
  });
}
