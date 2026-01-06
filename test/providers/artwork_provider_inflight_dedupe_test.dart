import 'dart:async';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/artwork_comment.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _FakeArtworkApi implements ArtworkBackendApi {
  int getArtworkCalls = 0;
  Completer<Artwork>? completer;

  @override
  Future<Artwork> getArtwork(String artworkId) {
    getArtworkCalls += 1;
    final c = completer;
    if (c != null) return c.future;
    throw StateError('completer not set');
  }

  // Unused endpoints for these tests.
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
  Future<ArtworkComment> editArtworkComment({required String commentId, required String content}) =>
      throw UnimplementedError();

  @override
  Future<int?> deleteArtworkComment(String commentId) => throw UnimplementedError();

  @override
  Future<int?> likeComment(String commentId) => throw UnimplementedError();

  @override
  Future<int?> unlikeComment(String commentId) => throw UnimplementedError();
}

void main() {
  test('ArtworkProvider.fetchArtworkIfNeeded dedupes in-flight getArtwork calls', () async {
    final api = _FakeArtworkApi()..completer = Completer<Artwork>();
    final provider = ArtworkProvider(backendApi: api);

    final f1 = provider.fetchArtworkIfNeeded('a1');
    final f2 = provider.fetchArtworkIfNeeded('a1');

    expect(api.getArtworkCalls, 1);

    api.completer!.complete(
      Artwork(
        id: 'a1',
        title: 'Test',
        artist: 'Artist',
        description: 'Desc',
        position: const LatLng(0, 0),
        rewards: 0,
        createdAt: DateTime.utc(2025, 1, 1),
      ),
    );

    final results = await Future.wait([f1, f2]);
    expect(results.first?.id, 'a1');
    expect(results.last?.id, 'a1');

    // Subsequent call should hit local cache, not backend.
    final f3 = await provider.fetchArtworkIfNeeded('a1');
    expect(f3?.id, 'a1');
    expect(api.getArtworkCalls, 1);
  });
}
