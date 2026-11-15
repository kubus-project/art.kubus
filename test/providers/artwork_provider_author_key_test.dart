import 'dart:async';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/artwork_author_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Records every `getArtworks` call so tests can assert the exact request.
class _RecordingArtworkApi implements ArtworkBackendApi {
  final calls = <Map<String, Object?>>[];
  FutureOr<List<Artwork>> Function(Map<String, Object?> call)? respond;
  Completer<List<Artwork>>? gate;

  @override
  Future<List<Artwork>> getArtworks({
    String? category,
    bool? arEnabled,
    int page = 1,
    int limit = 20,
    String? walletAddress,
    bool includePrivateForWallet = false,
    List<String>? ids,
    bool mine = false,
    String? authorProfileId,
  }) async {
    final call = <String, Object?>{
      'category': category,
      'arEnabled': arEnabled,
      'page': page,
      'limit': limit,
      'walletAddress': walletAddress,
      'includePrivateForWallet': includePrivateForWallet,
      'ids': ids,
      'mine': mine,
      'authorProfileId': authorProfileId,
    };
    calls.add(call);
    final pending = gate;
    if (pending != null) return pending.future;
    return await respond?.call(call) ?? const <Artwork>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

Artwork _artwork({
  required String id,
  String? walletAddress,
  bool isPublic = true,
}) =>
    Artwork(
      id: id,
      title: 'Work $id',
      artist: 'Artist',
      description: 'Description',
      position: const LatLng(46.0511, 14.5051),
      rewards: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      walletAddress: walletAddress,
      isPublic: isPublic,
    );

void main() {
  group('ArtworkAuthorKey.resolve', () {
    test('wallet wins when the account has one', () {
      final key = ArtworkAuthorKey.resolve(
        walletAddress: '  0xAbC  ',
        accountId: 'acct-1',
      );
      expect(key, isNotNull);
      expect(key!.isWallet, isTrue);
      expect(key.wallet, '0xAbC');
      expect(key.accountId, isNull);
    });

    test('walletless account is keyed by its account id', () {
      final key = ArtworkAuthorKey.resolve(
        walletAddress: '   ',
        accountId: ' acct-1 ',
      );
      expect(key, isNotNull);
      expect(key!.isWallet, isFalse);
      expect(key.accountId, 'acct-1');
      expect(key.cacheKey, 'account:acct-1');
    });

    test('keeps canonical profile id distinct from its account id', () {
      final key = ArtworkAuthorKey.resolve(
        accountId: '40000000-0000-4000-8000-000000000010',
        profileId: '10000000-0000-4000-8000-000000000010',
      );
      expect(key, isNotNull);
      expect(key!.accountId, '40000000-0000-4000-8000-000000000010');
      expect(key.profileId, '10000000-0000-4000-8000-000000000010');
      expect(key.cacheKey, contains('account:40000000'));
      expect(key.cacheKey, contains('profile:10000000'));
    });

    test('no wallet and no account id resolves to null', () {
      expect(
        ArtworkAuthorKey.resolve(walletAddress: null, accountId: ' '),
        isNull,
      );
    });

    test('wallet operation key keeps its historical name', () {
      final key = ArtworkAuthorKey.resolve(walletAddress: '0xAbC')!;
      expect(key.loadOperationKey, 'load_artworks_wallet_0xAbC');
    });
  });

  group('ArtworkProvider.loadArtworksForAuthor', () {
    test('wallet account sends the unchanged wallet-keyed request', () async {
      final api = _RecordingArtworkApi()
        ..respond = (_) => [
              _artwork(id: 'w1', walletAddress: '0xAbC'),
            ];
      final provider = ArtworkProvider(backendApi: api);
      addTearDown(provider.dispose);

      final key = ArtworkAuthorKey.resolve(walletAddress: '0xAbC')!;
      await provider.loadArtworksForAuthor(key);

      // Exactly the request loadArtworksForWallet has always made.
      expect(api.calls, hasLength(1));
      expect(api.calls.single, {
        'category': null,
        'arEnabled': null,
        'page': 1,
        'limit': 100,
        'walletAddress': '0xAbC',
        'includePrivateForWallet': true,
        'ids': null,
        'mine': false,
        'authorProfileId': null,
      });
      expect(
        provider.artworksForAuthor(key).map((a) => a.id),
        ['w1'],
      );
    });

    test('walletless account lists its own artworks with mine=true', () async {
      final api = _RecordingArtworkApi()
        ..respond = (_) => [
              _artwork(id: 'own-1'),
              _artwork(id: 'own-2'),
            ];
      final provider = ArtworkProvider(backendApi: api);
      addTearDown(provider.dispose);

      final key = ArtworkAuthorKey.resolve(accountId: 'acct-1')!;
      expect(provider.artworksForAuthor(key), isEmpty);

      await provider.loadArtworksForAuthor(key);

      expect(api.calls, hasLength(1));
      expect(api.calls.single['mine'], isTrue);
      expect(api.calls.single['walletAddress'], isNull);
      expect(api.calls.single['limit'], 100);
      expect(
        provider.artworksForAuthor(key).map((a) => a.id).toSet(),
        {'own-1', 'own-2'},
      );
      expect(
          provider.artworks.map((a) => a.id), containsAll(['own-1', 'own-2']));

      // Cached per account: a second non-forced load does not re-request.
      await provider.loadArtworksForAuthor(key);
      expect(api.calls, hasLength(1));

      await provider.loadArtworksForAuthor(key, force: true);
      expect(api.calls, hasLength(2));
    });

    test('own walletless author combines private owned and public imported art',
        () async {
      final api = _RecordingArtworkApi()
        ..respond = (call) {
          if (call['mine'] == true) {
            return [_artwork(id: 'own-private', isPublic: false)];
          }
          if (call['authorProfileId'] ==
              '10000000-0000-4000-8000-000000000010') {
            return [
              _artwork(
                  id: 'imported-author-work', walletAddress: 'uploader-wallet'),
              _artwork(id: 'secondary-author-work'),
            ];
          }
          return const <Artwork>[];
        };
      final provider = ArtworkProvider(backendApi: api);
      addTearDown(provider.dispose);
      final key = ArtworkAuthorKey.resolve(
        accountId: '40000000-0000-4000-8000-000000000010',
        profileId: '10000000-0000-4000-8000-000000000010',
      )!;

      await provider.loadArtworksForAuthor(key);

      expect(api.calls, hasLength(2));
      expect(api.calls.where((call) => call['mine'] == true), hasLength(1));
      expect(api.calls.where((call) => call['authorProfileId'] != null),
          hasLength(1));
      expect(
        provider.artworksForAuthor(key).map((artwork) => artwork.id).toSet(),
        {'own-private', 'imported-author-work', 'secondary-author-work'},
      );
    });

    test('keeps own mine results when public author scope is unsupported',
        () async {
      final api = _RecordingArtworkApi()
        ..respond = (call) {
          if (call['mine'] == true) return [_artwork(id: 'private-mine')];
          return Future<List<Artwork>>.error(
            StateError('authorProfileId filter unsupported'),
          );
        };
      final provider = ArtworkProvider(backendApi: api);
      addTearDown(provider.dispose);
      final key = ArtworkAuthorKey.resolve(
        accountId: '40000000-0000-4000-8000-000000000010',
        profileId: '10000000-0000-4000-8000-000000000010',
      )!;

      await provider.loadArtworksForAuthor(key);

      expect(api.calls, hasLength(2));
      expect(provider.artworksForAuthor(key).map((work) => work.id),
          ['private-mine']);
      expect(provider.authorListErrorFor(key), contains('unsupported'));
    });

    test('switching accounts never shows the previous account artworks',
        () async {
      final api = _RecordingArtworkApi();
      final provider = ArtworkProvider(backendApi: api);
      addTearDown(provider.dispose);

      final accountA = ArtworkAuthorKey.resolve(accountId: 'acct-a')!;
      final accountB = ArtworkAuthorKey.resolve(accountId: 'acct-b')!;

      api.respond = (_) => [_artwork(id: 'a-1')];
      await provider.loadArtworksForAuthor(accountA);
      expect(provider.artworksForAuthor(accountA).map((a) => a.id), ['a-1']);

      // Account B has not loaded yet: A's artworks must not leak through.
      expect(provider.artworksForAuthor(accountB), isEmpty);

      api.respond = (_) => [_artwork(id: 'b-1')];
      await provider.loadArtworksForAuthor(accountB);
      expect(provider.artworksForAuthor(accountB).map((a) => a.id), ['b-1']);
      expect(provider.artworksForAuthor(accountA).map((a) => a.id), ['a-1']);

      // Sign-out / account change drops the ending session's cached lists.
      provider.clearAccountScopedState();
      expect(provider.artworksForAuthor(accountA), isEmpty);
      expect(provider.artworksForAuthor(accountB), isEmpty);
      expect(
        provider.artworks.where((a) => a.id == 'a-1' || a.id == 'b-1'),
        isEmpty,
      );
    });

    test('a response that lands after an account change is discarded',
        () async {
      final api = _RecordingArtworkApi()..gate = Completer();
      final provider = ArtworkProvider(backendApi: api);
      addTearDown(provider.dispose);

      final accountA = ArtworkAuthorKey.resolve(accountId: 'acct-a')!;
      final load = provider.loadArtworksForAuthor(accountA);

      provider.clearAccountScopedState();
      api.gate!.complete([_artwork(id: 'a-late')]);
      await load;

      expect(provider.artworksForAuthor(accountA), isEmpty);
      expect(provider.artworks.any((a) => a.id == 'a-late'), isFalse);
    });

    test('an unsupported public author filter is an error, not empty success',
        () async {
      final api = _RecordingArtworkApi()
        ..respond = (call) {
          if (call['authorProfileId'] != null) {
            throw UnsupportedError('filter echo missing');
          }
          return const <Artwork>[];
        };
      final provider = ArtworkProvider(backendApi: api);
      addTearDown(provider.dispose);
      final key = ArtworkAuthorKey.resolve(
        profileId: '10000000-0000-4000-8000-000000000010',
      )!;

      await provider.loadArtworksForAuthor(key);

      expect(provider.authorListErrorFor(key), isNotNull);
      expect(provider.artworksForAuthor(key), isEmpty);
    });
  });
}
