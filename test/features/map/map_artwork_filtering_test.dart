import 'package:art_kubus/features/map/filters/map_filter_state.dart';
import 'package:art_kubus/features/map/shared/map_artwork_filtering.dart';
import 'package:art_kubus/features/map/shared/map_marker_filtering.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Artwork _artwork(
  String id, {
  LatLng position = const LatLng(46.0569, 14.5058),
  String title = '',
  String artist = '',
  String category = 'General',
  List<String> tags = const <String>[],
  ArtworkStatus status = ArtworkStatus.undiscovered,
  bool arEnabled = false,
  bool isFavoriteByCurrentUser = false,
}) {
  return Artwork(
    id: id,
    title: title.isEmpty ? 'Artwork $id' : title,
    artist: artist.isEmpty ? 'Artist $id' : artist,
    description: 'Description $id',
    position: position,
    category: category,
    tags: tags,
    status: status,
    arEnabled: arEnabled,
    isFavoriteByCurrentUser: isFavoriteByCurrentUser,
    rewards: 0,
    createdAt: DateTime(2025, 1, 1),
  );
}

ArtMarker _linkedMarker(
  String artworkId, {
  ArtMarkerType type = ArtMarkerType.artwork,
  LatLng position = const LatLng(46.0569, 14.5058),
}) {
  return ArtMarker(
    id: 'marker-$artworkId-${type.name}',
    artworkId: artworkId,
    name: 'Marker $artworkId',
    description: '',
    position: position,
    type: type,
    createdAt: DateTime(2025, 1, 1),
    createdBy: 'tester',
  );
}

KubusMapFilterContext _context({
  KubusMapFilterState? state,
  String query = '',
  LatLng? basePosition,
  bool strictNearMeWithoutBase = false,
}) {
  return KubusMapFilterContext(
    state: state ?? KubusMapFilterState.defaults(),
    query: query,
    basePosition: basePosition,
    strictNearMeWithoutBase: strictNearMeWithoutBase,
  );
}

List<String> _ids(List<Artwork> artworks) =>
    artworks.map((artwork) => artwork.id).toList()..sort();

void main() {
  group('MapArtworkFiltering.filter', () {
    final near = _artwork('near');
    final far = _artwork(
      'far',
      position: const LatLng(47.0569, 15.5058),
    );
    final invalid = _artwork('invalid', position: const LatLng(0, 0));

    test('defaults keep valid artworks when marker metadata is unavailable',
        () {
      final result = MapArtworkFiltering.filter(
        artworks: <Artwork>[near, far, invalid],
        markers: const <ArtMarker>[],
        context: _context(),
      );

      expect(_ids(result), <String>['far', 'near']);
    });

    test('content layers use valid linked markers when markers are loaded', () {
      final eventArtwork = _artwork('event');
      final result = MapArtworkFiltering.filter(
        artworks: <Artwork>[near, eventArtwork, far],
        markers: <ArtMarker>[
          _linkedMarker(near.id),
          _linkedMarker(eventArtwork.id, type: ArtMarkerType.event),
        ],
        context: _context(
          state: KubusMapFilterState(
            visibleContentLayers: const <ArtMarkerType>{ArtMarkerType.event},
          ),
        ),
      );

      expect(_ids(result), <String>['event']);
    });

    test('an artwork remains visible when any linked marker layer is visible',
        () {
      final result = MapArtworkFiltering.filter(
        artworks: <Artwork>[near],
        markers: <ArtMarker>[
          _linkedMarker(near.id),
          _linkedMarker(near.id, type: ArtMarkerType.event),
        ],
        context: _context(
          state: KubusMapFilterState(
            visibleContentLayers: const <ArtMarkerType>{ArtMarkerType.event},
          ),
        ),
      );

      expect(_ids(result), <String>['near']);
    });

    test('query composes across title, artist, category, and tags', () {
      final titled = _artwork('titled', title: 'Copper wave');
      final artist = _artwork('artist', artist: 'Copper Studio');
      final category = _artwork('category', category: 'Copperwork');
      final tagged = _artwork('tagged', tags: const <String>['copper']);

      final result = MapArtworkFiltering.filter(
        artworks: <Artwork>[titled, artist, category, tagged, near],
        markers: const <ArtMarker>[],
        context: _context(query: ' COPPER '),
      );

      expect(_ids(result), _ids([titled, artist, category, tagged]));
    });

    test('current viewport and travel ignore the near-me radius', () {
      for (final scope in <KubusMapScope>[
        KubusMapScope.currentViewport,
        KubusMapScope.travel,
      ]) {
        final result = MapArtworkFiltering.filter(
          artworks: <Artwork>[near, far],
          markers: const <ArtMarker>[],
          context: _context(
            state: KubusMapFilterState(
              scope: scope,
              nearMeRadiusKm: 1,
            ),
            basePosition: near.position,
          ),
        );

        expect(_ids(result), <String>['far', 'near'], reason: scope.name);
      }
    });

    test('near-me honors radius and strict missing-base behavior', () {
      final state = KubusMapFilterState(
        scope: KubusMapScope.nearMe,
        nearMeRadiusKm: 1,
      );
      final aroundBase = MapArtworkFiltering.filter(
        artworks: <Artwork>[near, far],
        markers: const <ArtMarker>[],
        context: _context(state: state, basePosition: near.position),
      );
      final permissive = MapArtworkFiltering.filter(
        artworks: <Artwork>[near, far],
        markers: const <ArtMarker>[],
        context: _context(state: state),
      );
      final strict = MapArtworkFiltering.filter(
        artworks: <Artwork>[near, far],
        markers: const <ArtMarker>[],
        context: _context(state: state, strictNearMeWithoutBase: true),
      );

      expect(_ids(aroundBase), <String>['near']);
      expect(_ids(permissive), <String>['far', 'near']);
      expect(strict, isEmpty);
    });

    test('discovery status is mutually exclusive', () {
      final undiscovered = _artwork('undiscovered');
      final discovered = _artwork(
        'discovered',
        status: ArtworkStatus.discovered,
      );
      final favorite = _artwork('favorite', status: ArtworkStatus.favorite);

      final discoveredResult = MapArtworkFiltering.filter(
        artworks: <Artwork>[undiscovered, discovered, favorite],
        markers: const <ArtMarker>[],
        context: _context(
          state: KubusMapFilterState(
            discoveryStatus: KubusMapDiscoveryStatus.discovered,
          ),
        ),
      );
      final undiscoveredResult = MapArtworkFiltering.filter(
        artworks: <Artwork>[undiscovered, discovered, favorite],
        markers: const <ArtMarker>[],
        context: _context(
          state: KubusMapFilterState(
            discoveryStatus: KubusMapDiscoveryStatus.undiscovered,
          ),
        ),
      );

      expect(_ids(discoveredResult), <String>['discovered', 'favorite']);
      expect(_ids(undiscoveredResult), <String>['undiscovered']);
    });

    test('AR-only and favorites-only compose independently', () {
      final both = _artwork(
        'both',
        arEnabled: true,
        isFavoriteByCurrentUser: true,
      );
      final arOnly = _artwork('ar', arEnabled: true);
      final favoriteOnly = _artwork(
        'favorite',
        isFavoriteByCurrentUser: true,
      );
      final favoriteStatus = _artwork(
        'favorite-status',
        arEnabled: true,
        status: ArtworkStatus.favorite,
      );

      final result = MapArtworkFiltering.filter(
        artworks: <Artwork>[both, arOnly, favoriteOnly, favoriteStatus],
        markers: const <ArtMarker>[],
        context: _context(
          state: KubusMapFilterState(arOnly: true, favoritesOnly: true),
        ),
      );

      expect(_ids(result), <String>['both', 'favorite-status']);
    });

    test('all independent dimensions compose simultaneously', () {
      final match = _artwork(
        'match',
        title: 'Blue sculpture',
        status: ArtworkStatus.discovered,
        arEnabled: true,
        isFavoriteByCurrentUser: true,
      );
      final wrongQuery = _artwork(
        'wrong-query',
        title: 'Red sculpture',
        status: ArtworkStatus.discovered,
        arEnabled: true,
        isFavoriteByCurrentUser: true,
      );
      final wrongRadius = _artwork(
        'wrong-radius',
        title: 'Blue sculpture',
        position: far.position,
        status: ArtworkStatus.discovered,
        arEnabled: true,
        isFavoriteByCurrentUser: true,
      );
      final wrongDiscovery = _artwork(
        'wrong-discovery',
        title: 'Blue sculpture',
        arEnabled: true,
        isFavoriteByCurrentUser: true,
      );
      final wrongAr = _artwork(
        'wrong-ar',
        title: 'Blue sculpture',
        status: ArtworkStatus.discovered,
        isFavoriteByCurrentUser: true,
      );
      final wrongFavorite = _artwork(
        'wrong-favorite',
        title: 'Blue sculpture',
        status: ArtworkStatus.discovered,
        arEnabled: true,
      );
      final wrongLayer = _artwork(
        'wrong-layer',
        title: 'Blue sculpture',
        status: ArtworkStatus.discovered,
        arEnabled: true,
        isFavoriteByCurrentUser: true,
      );
      final artworks = <Artwork>[
        match,
        wrongQuery,
        wrongRadius,
        wrongDiscovery,
        wrongAr,
        wrongFavorite,
        wrongLayer,
      ];
      final markers = <ArtMarker>[
        for (final artwork in artworks)
          _linkedMarker(
            artwork.id,
            type: artwork.id == wrongLayer.id
                ? ArtMarkerType.event
                : ArtMarkerType.artwork,
          ),
      ];

      final result = MapArtworkFiltering.filter(
        artworks: artworks,
        markers: markers,
        context: _context(
          state: KubusMapFilterState(
            scope: KubusMapScope.nearMe,
            nearMeRadiusKm: 1,
            discoveryStatus: KubusMapDiscoveryStatus.discovered,
            arOnly: true,
            favoritesOnly: true,
            visibleContentLayers: const <ArtMarkerType>{
              ArtMarkerType.artwork,
            },
          ),
          query: 'blue',
          basePosition: match.position,
        ),
      );

      expect(_ids(result), <String>['match']);
    });
  });
}
