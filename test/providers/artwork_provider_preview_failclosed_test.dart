import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
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
    implements ArtworkBackendApi, ArtworkPrivatePreviewApi {
  _FailingPreviewApi(this.previewError);
  final Object previewError;
  int publicReads = 0;

  @override
  Future<Artwork> getArtworkDetailWithMediaPreview(String artworkId) =>
      Future<Artwork>.error(previewError);

  @override
  Future<Artwork> getArtwork(String artworkId) async {
    publicReads += 1;
    return _artwork(artworkId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
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
    }
  });

  test('an expired session (401/403) still reads the public document',
      () async {
    final api = _FailingPreviewApi(const BackendApiRequestException(
        statusCode: 401, path: '/api/artworks/a1'));
    final provider = ArtworkProvider(backendApi: api);
    provider.addOrUpdateArtwork(_artwork('a1'));

    expect(await provider.refreshArtworkDetailMetadata('a1'), isNotNull);
    expect(api.publicReads, 1);
  });
}
