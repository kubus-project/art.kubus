import 'dart:async';

import 'package:art_kubus/community/art_discovery.dart';
import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/exhibition.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/providers/community_art_discovery_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

final DateTime _now = DateTime.utc(2026, 10, 11, 12);

CommunityPost _post(String id, {String wallet = 'w', double? distanceKm}) =>
    CommunityPost(
      id: id,
      authorIdentityData: ProfileIdentityData.fromCompactAuthor(
        {
          'displayName': 'N$wallet',
          'username': wallet,
          'walletAddress': wallet
        },
        fallbackLabel: 'x',
      ),
      content: 'post $id',
      timestamp: _now.subtract(const Duration(hours: 2)),
      distanceKm: distanceKm,
    );

Artwork _art(String id) => Artwork(
      id: id,
      walletAddress: 'artist-$id',
      title: 'Art $id',
      artist: 'artist-$id',
      description: '',
      position: const LatLng(0, 0),
      rewards: 0,
      createdAt: _now.subtract(const Duration(days: 2)),
    );

const _mapLocation = ArtDiscoveryLocation(
  latitude: 46.05,
  longitude: 14.5,
  source: ArtDiscoveryLocationSource.mapCenter,
);

class _Rig {
  _Rig({
    this.artFeedByRadius = const <double, int>{},
    this.publicPosts = 0,
    this.artworks = 0,
    this.map,
    this.selected,
    this.device,
    this.saved,
    this.failArtFeed = false,
    this.failPublic = false,
    this.failArtworks = false,
    this.signals = ArtDiscoverySignals.none,
  });

  final Map<double, int> artFeedByRadius;
  final int publicPosts;
  final int artworks;
  final ArtDiscoveryLocation? map;
  final ArtDiscoveryLocation? selected;
  final ArtDiscoveryLocation? device;
  final ArtDiscoveryLocation? saved;
  final bool failArtFeed;
  final bool failPublic;
  final bool failArtworks;
  final ArtDiscoverySignals signals;

  final List<double> radiiAsked = <double>[];
  final List<bool> devicePrompts = <bool>[];
  ArtDiscoveryLocation? savedWrite;

  ArtDiscoverySources get sources => ArtDiscoverySources(
        artFeed: (lat, lng, radius, {int limit = 30}) async {
          radiiAsked.add(radius);
          if (failArtFeed) throw StateError('art feed down');
          final n = artFeedByRadius[radius] ?? 0;
          return [
            for (var i = 0; i < n; i++)
              _post('near-$radius-$i', wallet: 'n$i', distanceKm: 1),
          ];
        },
        publicPosts: ({int limit = 30}) async {
          if (failPublic) throw StateError('public down');
          return [
            for (var i = 0; i < publicPosts; i++)
              _post('pub-$i', wallet: 'p$i'),
          ];
        },
        artworks: () async {
          if (failArtworks) throw StateError('artworks down');
          return [for (var i = 0; i < artworks; i++) _art('art-$i')];
        },
        exhibitions: (location, radius) async => const <Exhibition>[],
        signals: () async => signals,
        selectedArea: () => selected,
        mapCenter: () => map,
        deviceLocation: ({required bool prompt}) async {
          devicePrompts.add(prompt);
          return device;
        },
        savedLocation: () async => saved,
        saveLocation: (l) async => savedWrite = l,
        now: () => _now,
      );
}

void main() {
  test('a dense neighbourhood stays at the first radius', () async {
    final rig = _Rig(map: _mapLocation, artFeedByRadius: {3: 8});
    final provider = CommunityArtDiscoveryProvider();
    await provider.refresh(rig.sources);
    expect(rig.radiiAsked, [3]);
    expect(provider.radiusKm, 3);
    expect(provider.location?.source, ArtDiscoveryLocationSource.mapCenter);
  });

  test('a sparse neighbourhood widens until it has enough', () async {
    final rig = _Rig(map: _mapLocation, artFeedByRadius: {3: 0, 15: 2, 60: 7});
    final provider = CommunityArtDiscoveryProvider();
    await provider.refresh(rig.sources);
    expect(rig.radiiAsked, [3, 15, 60]);
    expect(provider.radiusKm, 60);
  });

  test('empty local results do not empty the tab', () async {
    final rig = _Rig(
      map: _mapLocation,
      publicPosts: 3,
      artworks: 4,
      artFeedByRadius: const {},
    );
    final provider = CommunityArtDiscoveryProvider();
    await provider.refresh(rig.sources);
    expect(rig.radiiAsked, kArtDiscoveryRadiiKm);
    expect(provider.allItems, isNotEmpty);
    expect(provider.error, isNull);
    expect(
      provider.allItems.map((i) => i.reason),
      isNot(contains(ArtDiscoveryReason.nearby)),
      reason: 'nothing local was found, so nothing is called nearby',
    );
  });

  test('without a location the feed is public discovery and asks no area',
      () async {
    final rig = _Rig(publicPosts: 2, artworks: 2);
    final provider = CommunityArtDiscoveryProvider();
    await provider.refresh(rig.sources);
    expect(rig.radiiAsked, isEmpty);
    expect(provider.location, isNull);
    expect(provider.allItems, hasLength(4));
  });

  group('location resolution', () {
    const selected = ArtDiscoveryLocation(
      latitude: 1,
      longitude: 1,
      source: ArtDiscoveryLocationSource.selected,
    );
    const device = ArtDiscoveryLocation(
      latitude: 2,
      longitude: 2,
      source: ArtDiscoveryLocationSource.device,
    );
    const saved = ArtDiscoveryLocation(
      latitude: 3,
      longitude: 3,
      source: ArtDiscoveryLocationSource.saved,
    );

    test('a chosen area wins over everything', () async {
      final rig = _Rig(selected: selected, map: _mapLocation, device: device);
      final p = CommunityArtDiscoveryProvider();
      await p.refresh(rig.sources);
      expect(p.location?.source, ArtDiscoveryLocationSource.selected);
      expect(rig.devicePrompts, isEmpty);
    });

    test('then the map, without ever prompting for the device', () async {
      final rig = _Rig(map: _mapLocation, device: device, saved: saved);
      final p = CommunityArtDiscoveryProvider();
      await p.refresh(rig.sources);
      expect(p.location?.source, ArtDiscoveryLocationSource.mapCenter);
      expect(rig.devicePrompts, isEmpty);
    });

    test('then the device, asked quietly unless the visitor chose to',
        () async {
      final rig = _Rig(device: device, saved: saved);
      final p = CommunityArtDiscoveryProvider();
      await p.refresh(rig.sources);
      expect(p.location?.source, ArtDiscoveryLocationSource.device);
      expect(rig.devicePrompts, [false]);

      final rig2 = _Rig(device: device, saved: saved);
      await CommunityArtDiscoveryProvider()
          .refresh(rig2.sources, promptForLocation: true);
      expect(rig2.devicePrompts, [true]);
    });

    test('then the last saved area, and never invents one', () async {
      final rig = _Rig(saved: saved);
      final p = CommunityArtDiscoveryProvider();
      await p.refresh(rig.sources);
      expect(p.location?.source, ArtDiscoveryLocationSource.saved);

      final none = CommunityArtDiscoveryProvider();
      await none.refresh(_Rig().sources);
      expect(none.location, isNull);
    });

    test('a location that was used is remembered', () async {
      final rig = _Rig(map: _mapLocation);
      await CommunityArtDiscoveryProvider().refresh(rig.sources);
      await Future<void>.delayed(Duration.zero);
      expect(rig.savedWrite?.latitude, 46.05);
    });
  });

  group('failures', () {
    test('one failing source only removes its own entries', () async {
      final rig = _Rig(
        publicPosts: 3,
        failArtworks: true,
        map: _mapLocation,
        artFeedByRadius: {3: 7},
      );
      final provider = CommunityArtDiscoveryProvider();
      await provider.refresh(rig.sources);
      expect(provider.allItems.where((i) => i.kind == ArtDiscoveryKind.post),
          isNotEmpty);
      expect(provider.error, isNull);
    });

    test('everything failing is an error, not an empty tab', () async {
      final rig = _Rig(
        map: _mapLocation,
        failArtFeed: true,
        failPublic: true,
        failArtworks: true,
      );
      final provider = CommunityArtDiscoveryProvider();
      await provider.refresh(rig.sources);
      expect(provider.allItems, isEmpty);
      expect(provider.error, isNotNull);
      expect(provider.loading, isFalse);
    });

    test('nothing to show and nothing failed is a plain empty feed', () async {
      final provider = CommunityArtDiscoveryProvider();
      await provider.refresh(_Rig().sources);
      expect(provider.allItems, isEmpty);
      expect(provider.error, isNull);
      expect(provider.loaded, isTrue);
    });
  });

  test('pagination reveals a stable ranked list page by page', () async {
    final rig = _Rig(publicPosts: 20, artworks: 10);
    final provider = CommunityArtDiscoveryProvider(pageSize: 12);
    await provider.refresh(rig.sources);
    expect(provider.items, hasLength(12));
    expect(provider.hasMore, isTrue);
    final firstPage = provider.items.map((i) => i.key).toList();

    provider.loadMore();
    expect(provider.items, hasLength(24));
    expect(provider.items.take(12).map((i) => i.key), firstPage,
        reason: 'earlier entries never move');
    provider.loadMore();
    expect(provider.items, hasLength(30));
    expect(provider.hasMore, isFalse);
  });

  test('a deleted post leaves the feed and does not return on refresh',
      () async {
    final rig = _Rig(publicPosts: 3);
    final provider = CommunityArtDiscoveryProvider();
    await provider.refresh(rig.sources);
    expect(provider.allItems.any((i) => i.id == 'pub-1'), isTrue);

    provider.removePost('pub-1');
    expect(provider.allItems.any((i) => i.id == 'pub-1'), isFalse);

    await provider.refresh(rig.sources);
    expect(provider.allItems.any((i) => i.id == 'pub-1'), isFalse);
  });

  test('a newer refresh supersedes a slower older one', () async {
    final slow = Completer<List<CommunityPost>>();
    var call = 0;
    final base = _Rig(publicPosts: 1).sources;
    final sources = ArtDiscoverySources(
      artFeed: base.artFeed,
      publicPosts: ({int limit = 30}) {
        call += 1;
        return call == 1 ? slow.future : Future.value([_post('fresh')]);
      },
      artworks: base.artworks,
      exhibitions: base.exhibitions,
      signals: base.signals,
      selectedArea: base.selectedArea,
      mapCenter: base.mapCenter,
      deviceLocation: base.deviceLocation,
      savedLocation: base.savedLocation,
      saveLocation: base.saveLocation,
      now: base.now,
    );
    final provider = CommunityArtDiscoveryProvider();
    final first = provider.refresh(sources);
    await provider.refresh(sources);
    slow.complete([_post('stale')]);
    await first;
    expect(provider.allItems.map((i) => i.id), ['fresh']);
  });
}
