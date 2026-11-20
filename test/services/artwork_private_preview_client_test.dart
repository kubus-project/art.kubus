import 'dart:async';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/artwork_private_preview_client.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _artworkId = '11111111-1111-4111-8111-111111111111';
const _ownerPath = '/api/artworks/$_artworkId/media/cover';

Artwork _privateArtwork({ArtworkMediaPreviewDescriptor? descriptor}) => Artwork(
      id: _artworkId,
      title: 'Private artwork',
      artist: 'Artist',
      description: '',
      position: const LatLng(0, 0),
      rewards: 0,
      createdAt: DateTime.utc(2026),
      isPublic: false,
      mediaPreview: descriptor,
    );

class _FakePreviewApi implements ArtworkPrivatePreviewApi {
  _FakePreviewApi(this.artwork);

  Artwork artwork;
  int detailCalls = 0;
  int byteCalls = 0;
  String? requestedPath;
  Future<Artwork> Function()? onDetail;
  Future<List<int>> Function()? onBytes;

  @override
  Future<Artwork> getArtworkDetailWithMediaPreview(String artworkId) async {
    detailCalls += 1;
    return onDetail?.call() ?? artwork;
  }

  @override
  Future<List<int>> getArtworkPrivateMediaBytes({
    required String artworkId,
    required String slot,
    required String descriptorPath,
  }) async {
    byteCalls += 1;
    requestedPath = descriptorPath;
    return onBytes?.call() ?? <int>[1, 2, 3];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.setAccountKey('preview-owner');
  });

  tearDown(() {
    AccountIdentity.setAccountKey('');
  });

  test(
    'owner and collaborator descriptors request only their bound bearer path',
    () async {
      for (final account in ['preview-owner', 'preview-collaborator']) {
        AccountIdentity.setAccountKey(account);
        final descriptor = ArtworkMediaPreviewDescriptor(
          auth: 'bearer',
          cover: _ownerPath,
          gallery: const <String?>['/api/artworks/$_artworkId/media/gallery-0'],
          poap: null,
        );
        final api = _FakePreviewApi(_privateArtwork(descriptor: descriptor));
        final client = ArtworkPrivatePreviewClient(
          api: api,
          listenForIdentityChanges: false,
        );

        expect(
          await client.loadBytes(
            artworkId: _artworkId,
            slot: 'cover',
            isPublic: false,
            knownDescriptor: descriptor,
          ),
          <int>[1, 2, 3],
        );
        expect(api.requestedPath, _ownerPath);
        expect(api.detailCalls, 0);
        expect(api.byteCalls, 1);
        client.dispose();
      }
    },
  );

  test('public artwork never requests private media bytes', () async {
    final api = _FakePreviewApi(_privateArtwork());
    final client = ArtworkPrivatePreviewClient(
      api: api,
      listenForIdentityChanges: false,
    );

    await expectLater(
      client.loadBytes(artworkId: _artworkId, slot: 'cover', isPublic: true),
      throwsStateError,
    );
    expect(api.detailCalls, 0);
    expect(api.byteCalls, 0);
    client.dispose();
  });

  test(
      'an explicit null descriptor is authoritative and skips both detail retry and bytes',
      () async {
    final api = _FakePreviewApi(_privateArtwork());
    final client = ArtworkPrivatePreviewClient(
      api: api,
      listenForIdentityChanges: false,
    );

    await expectLater(
      client.loadBytes(
        artworkId: _artworkId,
        slot: 'cover',
        isPublic: false,
        descriptorProvided: true,
      ),
      throwsStateError,
    );
    expect(api.detailCalls, 0);
    expect(api.byteCalls, 0);
    client.dispose();
  });

  test(
    'descriptor subject mismatch fails before a bearer byte request',
    () async {
      final descriptor = ArtworkMediaPreviewDescriptor(
        auth: 'bearer',
        cover: '/api/artworks/other-id/media/cover',
        gallery: const [],
        poap: null,
      );
      final api = _FakePreviewApi(_privateArtwork(descriptor: descriptor));
      final client = ArtworkPrivatePreviewClient(
        api: api,
        listenForIdentityChanges: false,
      );

      await expectLater(
        client.loadBytes(
          artworkId: _artworkId,
          slot: 'cover',
          isPublic: false,
          knownDescriptor: descriptor,
        ),
        throwsStateError,
      );
      expect(api.byteCalls, 0);
      client.dispose();
    },
  );

  test(
    'an account change rejects a late descriptor and skips the byte request',
    () async {
      final descriptorFuture = Completer<Artwork>();
      final descriptor = ArtworkMediaPreviewDescriptor(
        auth: 'bearer',
        cover: _ownerPath,
        gallery: const [],
        poap: null,
      );
      final api = _FakePreviewApi(_privateArtwork(descriptor: descriptor))
        ..onDetail = () => descriptorFuture.future;
      final client = ArtworkPrivatePreviewClient(api: api);

      final pending = client.loadBytes(
        artworkId: _artworkId,
        slot: 'cover',
        isPublic: false,
      );
      AccountIdentity.setAccountKey('preview-other-account');
      await AccountIdentity.notifyChanged();
      descriptorFuture.complete(_privateArtwork(descriptor: descriptor));

      await expectLater(pending, throwsStateError);
      expect(api.byteCalls, 0);
      expect(client.descriptorCacheSize, 0);
      client.dispose();
    },
  );
}
