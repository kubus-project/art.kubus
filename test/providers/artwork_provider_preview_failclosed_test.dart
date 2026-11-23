import 'dart:async';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/artwork_private_preview_client.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Artwork _artwork(String id) => Artwork(
      id: id,
      title: 'Work $id',
      artist: 'Artist',
      description: '',
      position: const LatLng(0, 0),
      rewards: 0,
      createdAt: DateTime(2026),
    );

/// Authenticated preview read fails with [previewError]; the unauthenticated
/// public read would succeed with a (possibly stale) public document.
class _FailingPreviewApi
    implements
        ArtworkBackendApi,
        ArtworkPrivatePreviewApi,
        ArtworkCurrentMediaApi {
  _FailingPreviewApi(this.previewError);
  final Object previewError;
  Object? guestError;
  Artwork? currentDetail;
  bool? currentPermissionOverride;
  List<Artwork>? listedArtworks;
  bool mediaAllowed = true;
  int publicReads = 0;
  int currentReads = 0;
  final List<String> calls = <String>[];

  @override
  Future<Artwork> getArtworkDetailWithMediaPreview(String artworkId) {
    calls.add('preview');
    return Future<Artwork>.error(previewError);
  }

  @override
  int get authSessionEpoch => 0;

  @override
  Future<ArtworkCurrentMediaDetail> getArtworkCurrentMediaDetail(
    String identifier, {
    required bool includeAuth,
  }) async {
    calls.add('current:$includeAuth');
    currentReads += 1;
    final error = includeAuth &&
            AccountIdentity.accountKey.isNotEmpty &&
            currentDetail == null
        ? previewError
        : guestError;
    if (error != null) throw error;
    final currentArtwork = currentDetail ?? _artwork(identifier);
    final allowed = currentPermissionOverride ??
        (mediaAllowed && currentArtwork.canUsePublicMedia);
    return ArtworkCurrentMediaDetail(
      artwork: currentArtwork.copyWith(currentPublicMediaAllowed: allowed),
      publicMediaAllowed: allowed,
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
    bool mine = false,
    String? authorProfileId,
  }) async =>
      listedArtworks ?? const <Artwork>[];

  @override
  Future<Artwork> getArtwork(String artworkId) async {
    calls.add('public');
    publicReads += 1;
    return _artwork(artworkId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SuccessfulPreviewApi extends _FailingPreviewApi {
  _SuccessfulPreviewApi(super.previewError, this.detail) {
    currentDetail = detail;
  }

  final Artwork detail;

  @override
  Future<Artwork> getArtworkDetailWithMediaPreview(String artworkId) async {
    calls.add('preview');
    return detail;
  }

  @override
  Future<ArtworkCurrentMediaDetail> getArtworkCurrentMediaDetail(
    String identifier, {
    required bool includeAuth,
  }) async {
    calls.add('current:$includeAuth');
    return ArtworkCurrentMediaDetail(
      artwork: detail,
      publicMediaAllowed: detail.canUsePublicMedia,
    );
  }
}

class _DelayedCurrentMediaApi extends _FailingPreviewApi {
  _DelayedCurrentMediaApi() : super(StateError('unused'));

  final Completer<ArtworkCurrentMediaDetail> pending =
      Completer<ArtworkCurrentMediaDetail>();

  @override
  Future<ArtworkCurrentMediaDetail> getArtworkCurrentMediaDetail(
    String identifier, {
    required bool includeAuth,
  }) =>
      pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AccountIdentity.setAccountKey('account-a'));
  tearDown(() => AccountIdentity.setAccountKey(''));

  test('transient preview failure never falls back to a public document',
      () async {
    for (final error in <Object>[
      StateError('network down'),
      const BackendApiRequestException(
          statusCode: 503, path: '/api/artworks/a1'),
      const BackendApiRequestException(
          statusCode: 404, path: '/api/artworks/a1'),
    ]) {
      final api = _FailingPreviewApi(error);
      final provider = ArtworkProvider(backendApi: api);
      provider.addOrUpdateArtwork(_artwork('a1'));

      expect(await provider.refreshArtworkDetailMetadata('a1'), isNull);
      await expectLater(
          ArtworkProvider(backendApi: api).fetchArtworkIfNeeded('a2'),
          throwsA(anything));
      expect(api.publicReads, 0, reason: '$error');
      expect(api.currentReads, 2, reason: '$error');
    }
  });

  for (final status in <int>[401, 403]) {
    test('an expired session ($status) retries current detail once as guest',
        () async {
      final api = _FailingPreviewApi(BackendApiRequestException(
          statusCode: status, path: '/api/artworks/a1'));
      final provider = ArtworkProvider(backendApi: api);
      provider.addOrUpdateArtwork(_artwork('a1'));

      expect(await provider.refreshArtworkDetailMetadata('a1'), isNotNull);
      expect(api.calls, <String>['current:true', 'current:false']);
      expect(api.publicReads, 0);
    });
  }

  test('current-media denial never falls through to ordinary public detail',
      () async {
    final api = _FailingPreviewApi(const BackendApiRequestException(
        statusCode: 401, path: '/api/artworks/a1'))
      ..mediaAllowed = false;
    final provider = ArtworkProvider(backendApi: api);
    provider.addOrUpdateArtwork(_artwork('a1'));

    expect(await provider.refreshArtworkDetailMetadata('a1'), isNull);
    expect(api.calls, <String>['current:true', 'current:false']);
    expect(api.publicReads, 0);
  });

  test('current detail outage after session rejection does not read snapshots',
      () async {
    final api = _FailingPreviewApi(const BackendApiRequestException(
        statusCode: 403, path: '/api/artworks/a1'))
      ..guestError = const BackendApiRequestException(
          statusCode: 503, path: '/api/artworks/a1?currentMedia=true');
    final provider = ArtworkProvider(backendApi: api);
    provider.addOrUpdateArtwork(_artwork('a1'));

    expect(await provider.refreshArtworkDetailMetadata('a1'), isNull);
    expect(api.calls, <String>['current:true', 'current:false']);
    expect(api.publicReads, 0);
  });

  test('guest detail uses only current-media transport', () async {
    AccountIdentity.setAccountKey('');
    final api = _FailingPreviewApi(StateError('unused'));
    final provider = ArtworkProvider(backendApi: api);

    expect(await provider.fetchArtworkIfNeeded('a1'), isNotNull);
    expect(api.calls, <String>['current:true']);
  });

  test(
      'authenticated private preview keeps its descriptor flow without public gate',
      () async {
    const descriptor = ArtworkMediaPreviewDescriptor(
      auth: 'bearer',
      cover: '/api/artworks/a1/media/cover',
      gallery: <String?>[],
      poap: null,
    );
    final api = _SuccessfulPreviewApi(
      StateError('unused'),
      _artwork('a1').copyWith(isPublic: false, mediaPreview: descriptor),
    );
    final provider = ArtworkProvider(backendApi: api);
    provider.addOrUpdateArtwork(_artwork('a1'));

    final refreshed = await provider.refreshArtworkDetailMetadata('a1');

    expect(refreshed?.isPublic, isFalse);
    expect(refreshed?.mediaPreview?.pathFor('cover'), descriptor.cover);
    expect(api.calls, <String>['current:true']);
  });

  test('authenticated current public detail is committed directly', () async {
    final api = _SuccessfulPreviewApi(StateError('unused'), _artwork('a1'));
    final provider = ArtworkProvider(backendApi: api);
    provider.addOrUpdateArtwork(_artwork('a1'));

    expect(await provider.refreshArtworkDetailMetadata('a1'), isNotNull);
    expect(api.calls, <String>['current:true']);
    expect(api.publicReads, 0);
  });

  test('late current detail from account A is dropped after switching to B',
      () async {
    final api = _DelayedCurrentMediaApi();
    final provider = ArtworkProvider(backendApi: api);
    provider.addOrUpdateArtwork(_artwork('a1'));
    final pending = provider.refreshArtworkDetailMetadata('a1');
    await Future<void>.delayed(Duration.zero);

    AccountIdentity.setAccountKey('account-b');
    AccountIdentity.notifyListenersChanged();
    api.pending.complete(ArtworkCurrentMediaDetail(
      artwork: _artwork('a1').copyWith(title: 'Account A response'),
      publicMediaAllowed: true,
    ));

    expect(await pending, isNull);
    expect(provider.getArtworkById('a1')?.title, 'Work a1');
  });

  test(
      'held current detail survives list and wallet refreshes without new URLs',
      () async {
    final held = _artwork('a1').copyWith(
      isPublic: true,
      isActive: true,
      editorialState: 'approved',
      currentPublicMediaAllowed: false,
      imageUrl: 'https://images.example.test/current-held.jpg',
      galleryUrls: const <String>[
        'https://images.example.test/current-held-gallery.jpg',
      ],
    );
    final api = _FailingPreviewApi(StateError('unused'))
      ..currentDetail = held
      ..currentPermissionOverride = false;
    final provider = ArtworkProvider(backendApi: api)..addOrUpdateArtwork(held);

    final verified = await provider.refreshArtworkDetailMetadata('a1');
    expect(verified?.canUsePublicMedia, isFalse);

    final listCopy = Artwork.fromMap(<String, dynamic>{
      ...held.toMap(),
      'imageUrl': 'https://images.example.test/untrusted-list.jpg',
      'galleryUrls': <String>[
        'https://images.example.test/untrusted-list-gallery.jpg',
      ],
    });
    api.listedArtworks = <Artwork>[listCopy];
    await provider.loadArtworks(refresh: true);
    var current = provider.getArtworkById('a1')!;
    expect(current.imageUrl, held.imageUrl);
    expect(current.galleryUrls, held.galleryUrls);
    expect(current.canUsePublicMedia, isFalse);

    await provider.loadArtworksForWallet(
      '0xabc',
      force: true,
      includePrivateForWallet: true,
    );
    current = provider.getArtworkById('a1')!;
    expect(current.imageUrl, held.imageUrl);
    expect(current.galleryUrls, held.galleryUrls);
    expect(current.canUsePublicMedia, isFalse);
  });

  test('untrusted replacement cannot reuse allow; fresh current detail can',
      () async {
    final trusted = _artwork('a1').copyWith(
      isPublic: true,
      isActive: true,
      editorialState: 'approved',
      imageUrl: 'https://images.example.test/current-original.jpg',
    );
    final api = _FailingPreviewApi(StateError('unused'))
      ..currentDetail = trusted
      ..currentPermissionOverride = true;
    final provider = ArtworkProvider(backendApi: api)
      ..addOrUpdateArtwork(trusted);
    expect(
        (await provider.refreshArtworkDetailMetadata('a1'))?.canUsePublicMedia,
        isTrue);

    api.listedArtworks = <Artwork>[
      Artwork.fromMap(<String, dynamic>{
        ...trusted.toMap(),
        'imageUrl': 'https://images.example.test/untrusted-replacement.jpg',
      }),
    ];
    await provider.loadArtworks(refresh: true);
    var current = provider.getArtworkById('a1')!;
    expect(current.imageUrl, trusted.imageUrl);
    expect(current.canUsePublicMedia, isTrue);

    final fresh = Artwork.fromMap(<String, dynamic>{
      ...trusted.toMap(),
      'imageUrl': 'https://images.example.test/fresh-current.jpg',
    });
    api.currentDetail = fresh;
    await provider.refreshArtworkDetailMetadata('a1');
    current = provider.getArtworkById('a1')!;
    expect(current.imageUrl, fresh.imageUrl);
    expect(current.canUsePublicMedia, isTrue);
  });

  test('account B list and wallet rows stay denied until B current detail',
      () async {
    final heldByA = _artwork('a1').copyWith(
      isPublic: true,
      isActive: true,
      editorialState: 'approved',
      imageUrl: 'https://images.example.test/account-a-held.jpg',
    );
    final api = _FailingPreviewApi(StateError('unused'))
      ..currentDetail = heldByA
      ..currentPermissionOverride = false;
    final provider = ArtworkProvider(backendApi: api)
      ..addOrUpdateArtwork(heldByA);
    expect(
      (await provider.refreshArtworkDetailMetadata('a1'))?.canUsePublicMedia,
      isFalse,
    );

    AccountIdentity.setAccountKey('account-b');
    AccountIdentity.notifyListenersChanged();
    final bListRow = Artwork.fromMap(<String, dynamic>{
      ...heldByA.toMap(),
      'imageUrl': 'https://images.example.test/account-b-list.jpg',
      'galleryUrls': <String>[
        'https://images.example.test/account-b-list-gallery.jpg',
      ],
    });
    api.listedArtworks = <Artwork>[bListRow];
    await provider.loadArtworks(refresh: true);
    await provider.loadArtworksForWallet(
      '0xabc',
      force: true,
      includePrivateForWallet: true,
    );
    var current = provider.getArtworkById('a1')!;
    expect(current.canUsePublicMedia, isFalse);
    expect(current.imageUrl, bListRow.imageUrl);

    final privatePreviewClient = ArtworkPrivatePreviewClient(
      api: api,
      listenForIdentityChanges: false,
    );
    expect(current.mediaPreview, isNull);
    expect(current.mediaPreviewProvided, isTrue);
    await expectLater(
      privatePreviewClient.loadBytes(
        artworkId: current.id,
        slot: 'cover',
        isPublic: current.canUsePublicMedia,
        knownDescriptor: current.mediaPreview,
        descriptorProvided: current.mediaPreviewProvided,
      ),
      throwsA(isA<StateError>()),
    );
    expect(api.calls, <String>['current:true']);
    privatePreviewClient.dispose();

    final freshB = Artwork.fromMap(<String, dynamic>{
      ...bListRow.toMap(),
      'imageUrl': 'https://images.example.test/account-b-current.jpg',
    });
    api.currentDetail = freshB;
    api.currentPermissionOverride = true;
    expect(
      (await provider.refreshArtworkDetailMetadata('a1'))?.canUsePublicMedia,
      isTrue,
    );
    current = provider.getArtworkById('a1')!;
    expect(current.imageUrl, freshB.imageUrl);
    provider.dispose();
  });
}
